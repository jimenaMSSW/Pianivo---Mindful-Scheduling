import json
import logging
from datetime import datetime, timedelta
from django.conf import settings
from django.shortcuts import render, get_object_or_404, redirect
from django.http import HttpResponse, JsonResponse
from django.views.decorators.csrf import csrf_exempt, csrf_protect
from django.views.decorators.http import require_GET, require_POST
from django.contrib.auth.decorators import login_required
from django.utils import timezone
from django.db.models import Q
from django.core.serializers.json import DjangoJSONEncoder
from django.core.exceptions import PermissionDenied, ImproperlyConfigured
from django_ratelimit.decorators import ratelimit

from core.firebase import firebase_status
from core.models import AppNotification, Business, Appointment, Employee, Conversation, Message, Payment, OwnerSubscription, WaitlistEntry

logger = logging.getLogger(__name__)

# --- HELPER FUNCTIONS ---

def root_redirect(request):
    if not request.user.is_authenticated:
        return redirect('login')
    if request.user.owned_businesses.exists():
        return redirect('owner:owner_dashboard')
    if hasattr(request.user, 'employee_profile'):
        return redirect('employee_dashboard')
    return redirect('book')

def whoami(request):
    return JsonResponse({
        "user": request.user.username if request.user.is_authenticated else "Anonymous",
        "subdomain": getattr(request, "subdomain", "None"),
    })

def get_calendar_events(appointments):
    events = []
    for a in appointments:
        conv_id = a.conversation.id if hasattr(a, 'conversation') and a.conversation else None
        emp_name = "Unassigned"
        if a.employee and a.employee.user:
            emp_name = a.employee.user.username

        events.append({
            "id": str(a.id),
            "title": a.customer_name,
            "start": a.start_time.isoformat(),
            "end": a.end_time.isoformat() if a.end_time else None,
            "extendedProps": {
                "status": a.status.lower(),
                "conversation_id": conv_id,
                "employee_name": emp_name
            },
            "backgroundColor": "#27ae60" if a.status.lower() == "confirmed" else "#d97706",
            "borderColor": "transparent",
            "textColor": "#ffffff",
        })
    return json.dumps(events, cls=DjangoJSONEncoder)

def parse_client_datetime(value):
    parsed = datetime.fromisoformat(value.replace('Z', '+00:00'))
    if timezone.is_naive(parsed):
        return timezone.make_aware(parsed)
    return parsed

def get_public_business(request, data=None):
    data = data or {}
    business_code = (data.get("business_code") or request.GET.get("business_code") or "").strip()
    if business_code:
        business = Business.objects.filter(subdomain__iexact=business_code).first()
        if business:
            return business
    business_slug = data.get("business_slug") or getattr(request, "subdomain", None)
    if business_slug:
        business = Business.objects.filter(slug=business_slug).first()
        if business:
            return business
    return Business.objects.first()

def require_stripe():
    if not settings.STRIPE_SECRET_KEY or not settings.STRIPE_PUBLISHABLE_KEY:
        raise ImproperlyConfigured("Stripe keys are missing. Set STRIPE_SECRET_KEY and STRIPE_PUBLISHABLE_KEY.")
    try:
        import stripe
    except ImportError as exc:
        raise ImproperlyConfigured("The stripe package is not installed.") from exc
    stripe.api_key = settings.STRIPE_SECRET_KEY
    return stripe

def subscription_status_from_checkout(session):
    subscription = session.get("subscription")
    if isinstance(subscription, dict):
        return subscription.get("status") or session.get("status") or "unknown"
    return session.get("status") or "unknown"

def cents_from_decimal(value, default=0):
    try:
        amount = float(value)
    except (TypeError, ValueError):
        return default
    return max(0, int(round(amount * 100)))

def deposit_policy_for_request(business, data):
    service_total_amount = max(0, int(data.get("service_total_amount") or data.get("amount") or 0))
    requested_deposit_percentage = int(float(data.get("deposit_percentage") or 0))
    query_deposit_enabled = str(data.get("deposit_enabled", "")).lower() in {"1", "true", "yes"}

    deposit_enabled = bool(getattr(business, "requires_deposit", False)) or query_deposit_enabled
    configured_percentage = getattr(business, "deposit_percentage", 0) or requested_deposit_percentage
    deposit_percentage = min(100, max(0, int(configured_percentage)))
    deposit_amount = round(service_total_amount * deposit_percentage / 100) if deposit_enabled else 0
    amount_to_charge = deposit_amount if deposit_enabled and deposit_amount > 0 else service_total_amount

    return service_total_amount, amount_to_charge, deposit_amount

def employee_from_request(business, data):
    employee_id = data.get("employee_id")
    employee_name = (data.get("employee_name") or "").strip()
    if employee_id:
        return Employee.objects.filter(id=employee_id, business=business).first()
    if employee_name:
        return Employee.objects.filter(user__username__iexact=employee_name, business=business).first()
    return None

def employee_has_conflict(employee, start_time, end_time):
    if employee is None:
        return False
    return Appointment.objects.filter(
        employee=employee,
        start_time__lt=end_time,
        end_time__gt=start_time,
    ).filter(
        Q(status__in=["confirmed", "completed"]) | Q(payments__status="succeeded")
    ).distinct().exists()

def business_has_conflict(business, start_time, end_time):
    return Appointment.objects.filter(
        business=business,
        start_time__lt=end_time,
        end_time__gt=start_time,
    ).filter(
        Q(status__in=["confirmed", "completed"]) | Q(payments__status="succeeded")
    ).distinct().exists()

def employee_earnings_amount(business, employee, payment_amount):
    if employee is None:
        return 0
    if getattr(business, "employees_keep_own_client_profits", False):
        return payment_amount
    commission = min(100, max(0, int(getattr(employee, "commission_percentage", 0) or 0)))
    return round(payment_amount * commission / 100)

def create_app_notification(audience, title, message, business=None, recipient_name=""):
    return AppNotification.objects.create(
        audience=audience,
        recipient_name=recipient_name,
        business=business,
        title=title,
        message=message,
    )

def retained_deposit_for(payment):
    if payment.deposit_amount <= 0 or not payment.appointment:
        return 0
    cutoff = payment.appointment.start_time - timedelta(hours=24)
    if timezone.now() >= cutoff:
        return min(payment.deposit_amount, payment.amount)
    return 0

# --- OWNER VIEWS ---

@login_required
def owner_dashboard(request):
    business = Business.objects.filter(owner=request.user).first()
    if not business:
        return render(request, 'owner/no_business.html')

    appointments = Appointment.objects.filter(business=business).order_by('start_time').select_related('conversation', 'employee__user')
    employees = Employee.objects.filter(business=business).select_related('user')

    context = {
        'user_business': business,
        'appointments': appointments,
        'employees': employees,
        'events_json': get_calendar_events(appointments),
        'selected_employee': None,
    }
    return render(request, 'owner/dashboard.html', context)

@login_required
def employee_schedule_view(request, employee_id):
    business = Business.objects.filter(owner=request.user).first()
    if not business:
        return render(request, 'owner/no_business.html')

    employee = get_object_or_404(Employee, id=employee_id, business=business)
    appointments = Appointment.objects.filter(
        business=business,
        employee=employee
    ).order_by('start_time').select_related('conversation', 'employee__user')
    employees = Employee.objects.filter(business=business).select_related('user')

    context = {
        'user_business': business,
        'appointments': appointments,
        'employees': employees,
        'selected_employee': employee,
        'events_json': get_calendar_events(appointments),
    }
    return render(request, 'owner/dashboard.html', context)

@require_POST
@login_required
def toggle_permissions(request):
    business = Business.objects.filter(owner=request.user).first()
    if not business:
        return JsonResponse({"error": "No business found"}, status=404)
    business.employees_can_manage_appointments = not business.employees_can_manage_appointments
    business.save()
    return JsonResponse({"success": True, "enabled": business.employees_can_manage_appointments})

@require_POST
@login_required
def get_or_create_conversation(request, appointment_id):
    appointment = get_object_or_404(Appointment, id=appointment_id)
    if appointment.business.owner != request.user:
        raise PermissionDenied()
    conversation, created = Conversation.objects.get_or_create(appointment=appointment)
    return JsonResponse({"success": True, "conversation_id": conversation.id})

@require_POST
@login_required
def add_appointment(request):
    business = Business.objects.filter(owner=request.user).first()
    try:
        data = json.loads(request.body)
        start = parse_client_datetime(data.get("start_time"))
        end = parse_client_datetime(data.get("end_time"))
        appointment = Appointment.objects.create(
            business=business,
            customer_name=data.get("customer_name"),
            start_time=start,
            end_time=end,
            status="pending"
        )
        Conversation.objects.get_or_create(appointment=appointment)
        return JsonResponse({"success": True})
    except Exception as e:
        return JsonResponse({"error": str(e)}, status=400)

@require_POST
@login_required
def reschedule_appointment(request, appointment_id):
    appointment = get_object_or_404(Appointment, id=appointment_id, business__owner=request.user)
    try:
        data = json.loads(request.body)
        appointment.start_time = parse_client_datetime(data.get("start_time"))
        appointment.end_time = parse_client_datetime(data.get("end_time"))
        appointment.save()
        return JsonResponse({"success": True})
    except Exception as e:
        return JsonResponse({"error": str(e)}, status=400)

@require_POST
@login_required
def confirm_appointment(request, appointment_id):
    appointment = get_object_or_404(Appointment, id=appointment_id, business__owner=request.user)
    appointment.confirm()
    return JsonResponse({"success": True})

@require_POST
@login_required
def reject_appointment(request, appointment_id):
    appointment = get_object_or_404(Appointment, id=appointment_id, business__owner=request.user)
    appointment.reject()
    return JsonResponse({"success": True})

@require_POST
@login_required
def owner_delete_appointment(request, appointment_id):
    appointment = get_object_or_404(Appointment, id=appointment_id, business__owner=request.user)
    appointment.delete()
    return JsonResponse({"success": True})

# --- MESSAGES API ---

@login_required
def api_get_messages(request):
    conversation_id = request.GET.get("conversation")
    messages = Message.objects.filter(conversation_id=conversation_id).order_by("timestamp")
    data = [{"sender": m.sender.username, "content": m.content, "timestamp": m.timestamp.isoformat()} for m in messages]
    return JsonResponse(data, safe=False)

@require_POST
@login_required
def api_send_message(request):
    data = json.loads(request.body)
    Message.objects.create(
        conversation_id=data.get("conversation"),
        sender=request.user,
        content=data.get("content")
    )
    return JsonResponse({"success": True})

# --- PUBLIC BOOKING AND PAYMENTS ---

@csrf_protect
@ratelimit(key='ip', rate='5/m', block=True)
def book_appointment(request):
    if request.method == "POST":
        try:
            data = json.loads(request.body)
            business = get_public_business(request, data)
            if business is None:
                return JsonResponse({"error": "No business is configured yet."}, status=404)
            appointment = Appointment.objects.create(
                customer_name=data.get("customer_name"),
                customer_email=data.get("customer_email"),
                business=business,
                start_time=parse_client_datetime(data.get("start_time")),
                end_time=parse_client_datetime(data.get("end_time")),
                status="pending"
            )
            Conversation.objects.get_or_create(appointment=appointment)
            return JsonResponse({"success": True, "appointment_id": appointment.id}, status=201)
        except Exception as e:
            return JsonResponse({"error": str(e)}, status=400)

    business = get_public_business(request)
    return render(request, 'core/book_appointment.html', {
        "business": business,
        "stripe_publishable_key": settings.STRIPE_PUBLISHABLE_KEY,
        "stripe_ready": bool(settings.STRIPE_SECRET_KEY and settings.STRIPE_PUBLISHABLE_KEY),
        "default_amount": "50.00",
        "currency": settings.STRIPE_CURRENCY.upper(),
    })

@require_POST
@csrf_protect
@ratelimit(key='ip', rate='10/m', block=True)
def create_payment_intent(request):
    try:
        stripe = require_stripe()
        data = json.loads(request.body)
        service_total_amount = int(data.get("service_total_amount") or data.get("amount") or 0)
        amount = service_total_amount
        if service_total_amount < 50:
            return JsonResponse({"error": "Amount must be at least 50 cents."}, status=400)

        business = get_public_business(request, data)
        if business is None:
            return JsonResponse({"error": "No business is configured yet."}, status=404)

        customer_name = data.get("customer_name", "").strip()
        customer_email = data.get("customer_email", "").strip() or None
        if not customer_name:
            return JsonResponse({"error": "Customer name is required."}, status=400)

        service_total_amount, amount, deposit_amount = deposit_policy_for_request(business, data)
        if amount < 50:
            return JsonResponse({"error": "Payment amount must be at least 50 cents."}, status=400)

        appointment = None
        employee = None
        if data.get("start_time") and data.get("end_time"):
            start_time = parse_client_datetime(data.get("start_time"))
            end_time = parse_client_datetime(data.get("end_time"))
            employee = employee_from_request(business, data)
            if employee_has_conflict(employee, start_time, end_time):
                return JsonResponse({
                    "error": "That employee already has an appointment at this time. Please choose another time or join the waitlist."
                }, status=409)
            if employee is None and business_has_conflict(business, start_time, end_time):
                return JsonResponse({
                    "error": "That time is unavailable. Please choose another time or join the waitlist."
                }, status=409)

            appointment = Appointment.objects.create(
                customer_name=customer_name,
                customer_email=customer_email,
                business=business,
                employee=employee,
                start_time=start_time,
                end_time=end_time,
                status="pending"
            )
            appointment.employee_earnings_amount = employee_earnings_amount(business, employee, amount)
            appointment.save(update_fields=["employee_earnings_amount"])
            Conversation.objects.get_or_create(appointment=appointment)
            create_app_notification(
                "business",
                "New Booking Started",
                f"{customer_name} started booking an appointment.",
                business=business,
            )

        intent = stripe.PaymentIntent.create(
            amount=amount,
            currency=settings.STRIPE_CURRENCY,
            payment_method_types=["card", "klarna"],
            receipt_email=customer_email,
            metadata={
                "business_id": str(business.id),
                "appointment_id": str(appointment.id) if appointment else "",
                "customer_name": customer_name,
                "service_total_amount": str(service_total_amount),
                "deposit_amount": str(deposit_amount),
            },
        )
        earnings_amount = employee_earnings_amount(business, employee, amount)
        Payment.objects.create(
            business=business,
            appointment=appointment,
            customer_name=customer_name,
            customer_email=customer_email,
            amount=amount,
            service_total_amount=service_total_amount,
            deposit_amount=deposit_amount,
            employee_earnings_amount=earnings_amount,
            currency=settings.STRIPE_CURRENCY,
            status=intent.status,
            stripe_payment_intent_id=intent.id,
        )
        return JsonResponse({
            "client_secret": intent.client_secret,
            "publishable_key": settings.STRIPE_PUBLISHABLE_KEY,
            "payment_intent_id": intent.id,
            "appointment_id": appointment.id if appointment else None,
            "amount": amount,
            "service_total_amount": service_total_amount,
            "deposit_amount": deposit_amount,
        })
    except ImproperlyConfigured as exc:
        return JsonResponse({"error": str(exc)}, status=503)
    except Exception as exc:
        logger.exception("PaymentIntent creation failed")
        return JsonResponse({"error": str(exc)}, status=400)

@require_POST
@csrf_exempt
@ratelimit(key='ip', rate='10/m', block=True)
def create_waitlist_entry(request):
    try:
        data = json.loads(request.body or "{}")
        business = get_public_business(request, data)
        if business is None:
            return JsonResponse({"error": "No business is configured yet."}, status=404)

        customer_name = data.get("customer_name", "").strip()
        service_name = data.get("service_name", "").strip()
        start_time_value = data.get("preferred_start_time") or data.get("start_time")
        if not customer_name or not service_name or not start_time_value:
            return JsonResponse({"error": "Customer name, service, and preferred time are required."}, status=400)

        entry = WaitlistEntry.objects.create(
            business=business,
            customer_name=customer_name,
            customer_email=data.get("customer_email", "").strip() or None,
            service_name=service_name,
            preferred_start_time=parse_client_datetime(start_time_value),
        )
        create_app_notification(
            "business",
            "New Waitlist Request",
            f"{customer_name} joined the waitlist for {service_name}.",
            business=business,
        )
        return JsonResponse({"success": True, "waitlist_id": entry.id}, status=201)
    except Exception as exc:
        logger.exception("Waitlist entry creation failed")
        return JsonResponse({"error": str(exc)}, status=400)

@require_POST
@csrf_exempt
@ratelimit(key='ip', rate='10/m', block=True)
def cancel_paid_appointment(request, appointment_id):
    try:
        stripe = require_stripe()
        data = json.loads(request.body or "{}")
        payment_intent_id = (data.get("payment_intent_id") or "").strip()
        customer_email = (data.get("customer_email") or "").strip().lower()

        appointment = get_object_or_404(Appointment, id=appointment_id)
        payment_query = Payment.objects.filter(appointment=appointment)
        if payment_intent_id:
            payment_query = payment_query.filter(stripe_payment_intent_id=payment_intent_id)
        payment = payment_query.order_by("-created_at").first()

        if not payment:
            appointment.status = "cancelled"
            appointment.save(update_fields=["status"])
            create_app_notification(
                "business",
                "Appointment Canceled",
                f"{appointment.customer_name}'s appointment was canceled. No Stripe payment was attached.",
                business=appointment.business,
            )
            return JsonResponse({
                "success": True,
                "appointment_status": appointment.status,
                "payment_status": "none",
                "refund_status": "not_refunded",
                "refunded_amount": 0,
                "retained_deposit_amount": 0,
            })

        if payment.customer_email and payment.customer_email.lower() != customer_email:
            return JsonResponse({"error": "This payment does not match the booking email."}, status=403)

        if payment.refund_status in {"succeeded", "pending", "canceled_before_capture", "deposit_retained"}:
            appointment.status = "cancelled"
            appointment.save(update_fields=["status"])
            create_app_notification(
                "business",
                "Appointment Already Canceled",
                f"{appointment.customer_name}'s appointment already has refund status {payment.refund_status}.",
                business=appointment.business,
            )
            return JsonResponse({
                "success": True,
                "appointment_status": appointment.status,
                "payment_status": payment.status,
                "refund_status": payment.refund_status,
                "refunded_amount": payment.refunded_amount,
                "retained_deposit_amount": payment.retained_deposit_amount,
            })

        intent = stripe.PaymentIntent.retrieve(payment.stripe_payment_intent_id)
        status = intent.get("status") or payment.status
        retained_deposit = retained_deposit_for(payment)
        refund_amount = max(0, payment.amount - retained_deposit)

        if status in {"requires_payment_method", "requires_confirmation", "requires_action", "processing"}:
            canceled_intent = stripe.PaymentIntent.cancel(payment.stripe_payment_intent_id)
            payment.status = canceled_intent.get("status") or "canceled"
            payment.refund_status = "canceled_before_capture"
            payment.refunded_amount = 0
        elif status == "succeeded" and refund_amount > 0:
            refund = stripe.Refund.create(
                payment_intent=payment.stripe_payment_intent_id,
                amount=refund_amount,
                reason="requested_by_customer",
                metadata={
                    "appointment_id": str(appointment.id),
                    "retained_deposit_amount": str(retained_deposit),
                },
            )
            payment.status = status
            payment.refund_status = refund.get("status") or "refund_created"
            payment.refunded_amount = refund_amount
        elif status == "succeeded":
            payment.status = status
            payment.refund_status = "deposit_retained"
            payment.refunded_amount = 0
        else:
            payment.status = status
            payment.refund_status = "not_refunded"

        payment.retained_deposit_amount = retained_deposit
        payment.save()

        appointment.status = "cancelled"
        appointment.save(update_fields=["status"])
        if payment.refund_status == "deposit_retained":
            refund_message = f"Deposit retained: {payment.retained_deposit_amount} cents."
        elif payment.refunded_amount > 0:
            refund_message = f"Refund issued: {payment.refunded_amount} cents."
        else:
            refund_message = f"Refund status: {payment.refund_status}."
        create_app_notification(
            "business",
            "Appointment Canceled",
            f"{appointment.customer_name}'s appointment was canceled. {refund_message}",
            business=appointment.business,
        )

        return JsonResponse({
            "success": True,
            "appointment_status": appointment.status,
            "payment_status": payment.status,
            "refund_status": payment.refund_status,
            "refunded_amount": payment.refunded_amount,
            "retained_deposit_amount": payment.retained_deposit_amount,
        })
    except ImproperlyConfigured as exc:
        return JsonResponse({"error": str(exc)}, status=503)
    except Exception as exc:
        logger.exception("Paid appointment cancellation failed")
        return JsonResponse({"error": str(exc)}, status=400)

@require_POST
@csrf_exempt
def stripe_webhook(request):
    try:
        stripe = require_stripe()
    except ImproperlyConfigured as exc:
        return HttpResponse(str(exc), status=503)

    payload = request.body
    sig_header = request.META.get('HTTP_STRIPE_SIGNATURE')
    try:
        if settings.STRIPE_WEBHOOK_SECRET:
            event = stripe.Webhook.construct_event(payload, sig_header, settings.STRIPE_WEBHOOK_SECRET)
        else:
            event = json.loads(payload)
    except Exception as exc:
        return HttpResponse(str(exc), status=400)

    event_type = event.get('type')
    intent = event.get('data', {}).get('object', {})
    if event_type == 'checkout.session.completed':
        session = intent
        checkout_id = session.get('id')
        subscription = session.get('subscription')
        subscription_id = subscription.get('id') if isinstance(subscription, dict) else subscription or ''
        OwnerSubscription.objects.filter(stripe_checkout_session_id=checkout_id).update(
            stripe_customer_id=session.get('customer') or '',
            stripe_subscription_id=subscription_id,
            status=subscription_status_from_checkout(session),
        )
    elif event_type in {'customer.subscription.created', 'customer.subscription.updated', 'customer.subscription.deleted'}:
        subscription = intent
        status = subscription.get('status') or 'unknown'
        current_period_end = subscription.get('current_period_end')
        updates = {
            'status': status,
        }
        if current_period_end:
            updates['current_period_end'] = datetime.fromtimestamp(current_period_end, tz=timezone.get_current_timezone())
        OwnerSubscription.objects.filter(stripe_subscription_id=subscription.get('id')).update(**updates)
    elif event_type in {
        'payment_intent.succeeded',
        'payment_intent.payment_failed',
        'payment_intent.processing',
        'payment_intent.canceled',
        'payment_intent.requires_action',
    }:
        payment = Payment.objects.filter(stripe_payment_intent_id=intent.get('id')).select_related('appointment').first()
        if payment:
            payment.status = intent.get('status') or payment.status
            payment.payment_method = intent.get('payment_method_types', ['unknown'])[0]
            payment.stripe_latest_charge_id = intent.get('latest_charge') or ''
            if intent.get('last_payment_error'):
                payment.last_error = intent['last_payment_error'].get('message', '')
            payment.save()

            if payment.appointment and event_type == 'payment_intent.succeeded':
                payment.appointment.confirm()

    return HttpResponse(status=200)

@require_POST
@csrf_exempt
@ratelimit(key='ip', rate='5/m', block=True)
def create_owner_subscription_checkout(request):
    try:
        stripe = require_stripe()
        if not settings.STRIPE_OWNER_SUBSCRIPTION_PRICE_ID:
            return JsonResponse({"error": "Owner subscription price is not configured."}, status=503)

        data = json.loads(request.body)
        email = (data.get("email") or "").strip().lower()
        name = (data.get("name") or "").strip()
        business_code = (data.get("business_code") or "").strip().upper()
        if not email or "@" not in email or not name or not business_code:
            return JsonResponse({"error": "Name, email, and business code are required."}, status=400)

        session = stripe.checkout.Session.create(
            mode="subscription",
            customer_email=email,
            line_items=[{
                "price": settings.STRIPE_OWNER_SUBSCRIPTION_PRICE_ID,
                "quantity": 1,
            }],
            success_url=f"{settings.APP_BASE_URL}/subscriptions/owner/success/?session_id={{CHECKOUT_SESSION_ID}}",
            cancel_url=f"{settings.APP_BASE_URL}/subscriptions/owner/cancel/",
            client_reference_id=email,
            metadata={
                "account_type": "owner",
                "email": email,
                "name": name,
                "business_code": business_code,
            },
            subscription_data={
                "metadata": {
                    "account_type": "owner",
                    "email": email,
                    "business_code": business_code,
                }
            },
        )

        OwnerSubscription.objects.update_or_create(
            stripe_checkout_session_id=session.id,
            defaults={
                "email": email,
                "name": name,
                "business_code": business_code,
                "status": "checkout_started",
            },
        )
        return JsonResponse({"checkout_url": session.url, "session_id": session.id})
    except ImproperlyConfigured as exc:
        return JsonResponse({"error": str(exc)}, status=503)
    except Exception as exc:
        logger.exception("Owner subscription checkout creation failed")
        return JsonResponse({"error": str(exc)}, status=400)

@require_GET
def owner_subscription_status(request):
    session_id = (request.GET.get("session_id") or "").strip()
    if not session_id:
        return JsonResponse({"error": "Missing session_id."}, status=400)

    record = OwnerSubscription.objects.filter(stripe_checkout_session_id=session_id).first()
    try:
        stripe = require_stripe()
        session = stripe.checkout.Session.retrieve(session_id, expand=["subscription"])
        status = subscription_status_from_checkout(session)
        subscription = session.get("subscription")
        subscription_id = subscription.get("id") if isinstance(subscription, dict) else subscription or ''
        if record:
            record.stripe_customer_id = session.get("customer") or record.stripe_customer_id
            record.stripe_subscription_id = subscription_id or record.stripe_subscription_id
            record.status = status
            record.save()
    except Exception:
        logger.exception("Owner subscription status refresh failed")
        status = record.status if record else "unknown"

    active = status in {"active", "trialing", "complete"}
    return JsonResponse({
        "active": active,
        "status": status,
        "email": record.email if record else "",
        "business_code": record.business_code if record else "",
        "stripe_customer_id": record.stripe_customer_id if record else "",
        "stripe_subscription_id": record.stripe_subscription_id if record else "",
    })

@require_GET
def owner_subscription_success(request):
    return render(request, 'core/subscription_success.html')

@require_GET
def owner_subscription_cancel(request):
    return render(request, 'core/subscription_cancel.html')

@require_GET
def privacy_policy(request):
    return render(request, 'core/privacy_policy.html')

@require_GET
def privacy_choices(request):
    return render(request, 'core/privacy_choices.html')

@require_GET
def support(request):
    return render(request, 'core/support.html')

@require_GET
def firebase_health(request):
    return JsonResponse(firebase_status())
