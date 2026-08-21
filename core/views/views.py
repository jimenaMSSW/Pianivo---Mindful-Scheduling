import json
import logging
from datetime import datetime
from django.conf import settings
from django.shortcuts import render, get_object_or_404, redirect
from django.http import HttpResponse, JsonResponse
from django.views.decorators.csrf import csrf_exempt, csrf_protect
from django.views.decorators.http import require_GET, require_POST
from django.contrib.auth.decorators import login_required
from django.utils import timezone
from django.core.serializers.json import DjangoJSONEncoder
from django.core.exceptions import PermissionDenied, ImproperlyConfigured
from django_ratelimit.decorators import ratelimit

from core.firebase import firebase_status
from core.models import Business, Appointment, Employee, Conversation, Message, Payment

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
        amount = int(data.get("amount", 0))
        if amount < 50:
            return JsonResponse({"error": "Amount must be at least 50 cents."}, status=400)

        business = get_public_business(request, data)
        if business is None:
            return JsonResponse({"error": "No business is configured yet."}, status=404)

        customer_name = data.get("customer_name", "").strip()
        customer_email = data.get("customer_email", "").strip() or None
        if not customer_name:
            return JsonResponse({"error": "Customer name is required."}, status=400)

        appointment = None
        if data.get("start_time") and data.get("end_time"):
            appointment = Appointment.objects.create(
                customer_name=customer_name,
                customer_email=customer_email,
                business=business,
                start_time=parse_client_datetime(data.get("start_time")),
                end_time=parse_client_datetime(data.get("end_time")),
                status="pending"
            )
            Conversation.objects.get_or_create(appointment=appointment)

        intent = stripe.PaymentIntent.create(
            amount=amount,
            currency=settings.STRIPE_CURRENCY,
            payment_method_types=["card", "klarna"],
            receipt_email=customer_email,
            metadata={
                "business_id": str(business.id),
                "appointment_id": str(appointment.id) if appointment else "",
                "customer_name": customer_name,
            },
        )
        Payment.objects.create(
            business=business,
            appointment=appointment,
            customer_name=customer_name,
            customer_email=customer_email,
            amount=amount,
            currency=settings.STRIPE_CURRENCY,
            status=intent.status,
            stripe_payment_intent_id=intent.id,
        )
        return JsonResponse({
            "client_secret": intent.client_secret,
            "publishable_key": settings.STRIPE_PUBLISHABLE_KEY,
            "payment_intent_id": intent.id,
            "appointment_id": appointment.id if appointment else None,
        })
    except ImproperlyConfigured as exc:
        return JsonResponse({"error": str(exc)}, status=503)
    except Exception as exc:
        logger.exception("PaymentIntent creation failed")
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
    if event_type in {
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

@require_GET
def firebase_health(request):
    return JsonResponse(firebase_status())
