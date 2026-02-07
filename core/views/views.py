import json
from datetime import datetime
from django.shortcuts import render, get_object_or_404, redirect
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_protect, csrf_exempt
from django.views.decorators.http import require_POST
from django.contrib.auth.decorators import login_required
from django.utils import timezone
from django.core.serializers.json import DjangoJSONEncoder
from django_ratelimit.decorators import ratelimit
from django.core.exceptions import PermissionDenied

from core.models import Business, Appointment, Employee, Conversation, Message


# --- HELPER FUNCTIONS ---

def root_redirect(request):
    if not request.user.is_authenticated:
        return redirect('login')  # sends user to login page

    if request.user.owned_businesses.exists():
        return redirect('owner:owner_dashboard')  # owner dashboard

    if hasattr(request.user, 'employee_profile'):
        return redirect('employee_dashboard')  # employee dashboard

    return redirect('book')  # public booking page


def get_calendar_events(appointments):
    """Formats appointments for FullCalendar."""
    events = []
    for a in appointments:
        events.append({
            "id": str(a.id),
            "title": a.customer_name,
            "start": a.start_time.isoformat(),
            "end": a.end_time.isoformat() if a.end_time else None,
            "extendedProps": {
                "status": a.status.lower(),
                "employee_name": a.employee.user.username if a.employee else 'Unassigned',
                "conversation_id": getattr(a, "conversation", None) and getattr(a.conversation, "id", None)
            },
            "backgroundColor": "#27ae60" if a.status.lower() == "confirmed" else "#d97706",
            "borderColor": "transparent",
            "textColor": "#ffffff",
        })
    return json.dumps(events, cls=DjangoJSONEncoder)


def whoami(request):
    return JsonResponse({
        "user": request.user.username if request.user.is_authenticated else "Anonymous",
        "subdomain": getattr(request, "subdomain", "None"),
    })


# --- PERMISSION HELPERS ---

def user_can_access_appointment(user, appointment):
    """Check if user owns business or is the assigned employee."""
    if appointment.business.owner == user:
        return True
    if appointment.employee and appointment.employee.user == user:
        return True
    return False


def user_can_access_conversation(user, conversation):
    return user_can_access_appointment(user, conversation.appointment)


# --- OWNER VIEWS ---

@login_required
def owner_dashboard(request):
    business = get_object_or_404(Business, owner=request.user)
    appointments = Appointment.objects.filter(business=business).order_by('start_time')
    employees = Employee.objects.filter(business=business)

    status_filter = request.GET.get('status')
    employee_filter = request.GET.get('employee')

    if status_filter:
        appointments = appointments.filter(status=status_filter)
    if employee_filter:
        appointments = appointments.filter(employee_id=employee_filter)

    context = {
        'user_business': business,
        'appointments': appointments,
        'employees': employees,
        'events_json': get_calendar_events(appointments),
        'status_filter': status_filter,
        'employee_filter': employee_filter,
    }
    return render(request, 'owner/dashboard.html', context)


@require_POST
@login_required
def add_appointment(request):
    """Owner adds an appointment via AJAX."""
    business = get_object_or_404(Business, owner=request.user)
    try:
        data = json.loads(request.body)
        employee = Employee.objects.filter(
            id=data.get("employee_id"), business=business
        ).first()

        start = timezone.make_aware(datetime.fromisoformat(data.get("start_time")))
        end = timezone.make_aware(datetime.fromisoformat(data.get("end_time")))

        appointment = Appointment.objects.create(
            business=business,
            employee=employee,
            customer_name=data.get("customer_name"),
            start_time=start,
            end_time=end,
            status="pending"
        )

        # AUTO CREATE CONVERSATION
        Conversation.objects.get_or_create(appointment=appointment)

        return JsonResponse({"success": True})
    except Exception as e:
        return JsonResponse({"error": str(e)}, status=400)


@require_POST
@login_required
def owner_delete_appointment(request, appointment_id):
    """Owner deletes an appointment."""
    business = get_object_or_404(Business, owner=request.user)
    appointment = get_object_or_404(Appointment, id=appointment_id, business=business)
    appointment.delete()
    return JsonResponse({"success": True})


# --- EMPLOYEE VIEWS ---

@login_required
def employee_dashboard(request):
    employee = getattr(request.user, 'employee_profile', None)

    if not employee:
        if request.user.owned_businesses.exists():
            return redirect('owner:owner_dashboard')
        return redirect('login')

    appointments = Appointment.objects.filter(employee=employee).order_by('start_time')
    context = {
        'employee': employee,
        'appointments': appointments,
        'events_json': get_calendar_events(appointments),
    }
    return render(request, 'employee/dashboard.html', context)


@require_POST
@login_required
def employee_add_appointment(request):
    employee = get_object_or_404(Employee, user=request.user)

    if not employee.business.employees_can_manage_appointments:
        return JsonResponse({"error": "Manager has disabled self-booking."}, status=403)

    try:
        data = json.loads(request.body)
        start = timezone.make_aware(datetime.fromisoformat(data.get("start_time")))
        end = timezone.make_aware(datetime.fromisoformat(data.get("end_time")))

        appointment = Appointment.objects.create(
            business=employee.business,
            employee=employee,
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
def employee_delete_appointment(request, appointment_id):
    employee = get_object_or_404(Employee, user=request.user)
    appointment = get_object_or_404(Appointment, id=appointment_id, employee=employee)
    appointment.delete()
    return JsonResponse({"success": True})


# --- APPOINTMENT STATUS ACTIONS ---

@require_POST
@login_required
def confirm_appointment(request, appointment_id):
    """Confirm an appointment safely."""
    appointment = get_object_or_404(Appointment, id=appointment_id)

    if not user_can_access_appointment(request.user, appointment):
        raise PermissionDenied()

    if appointment.status.lower() != "pending":
        return JsonResponse({"error": "Only pending appointments can be confirmed"}, status=400)

    if appointment.overlaps():
        return JsonResponse({"error": "Time slot already taken"}, status=400)

    appointment.confirm()
    return JsonResponse({"success": True, "status": appointment.status})


@require_POST
@login_required
def reject_appointment(request, appointment_id):
    appointment = get_object_or_404(Appointment, id=appointment_id)

    if not user_can_access_appointment(request.user, appointment):
        raise PermissionDenied()

    if appointment.status.lower() != "pending":
        return JsonResponse({"error": "Only pending appointments can be rejected"}, status=400)

    appointment.reject()
    return JsonResponse({"success": True, "status": appointment.status})


# --- MESSAGES API ---

@login_required
def api_get_messages(request):
    conversation_id = request.GET.get("conversation")
    conversation = get_object_or_404(Conversation, id=conversation_id)

    if not user_can_access_conversation(request.user, conversation):
        raise PermissionDenied()

    messages = conversation.messages.order_by("timestamp")
    data = [{"id": m.id, "sender": m.sender.id, "content": m.content, "timestamp": m.timestamp.isoformat()} for m in messages]
    return JsonResponse(data, safe=False)


@csrf_exempt
@login_required
def api_send_message(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST required"}, status=400)

    data = json.loads(request.body)
    conversation = get_object_or_404(Conversation, id=data.get("conversation"))

    if not user_can_access_conversation(request.user, conversation):
        raise PermissionDenied()

    msg = Message.objects.create(conversation=conversation, sender=request.user, content=data.get("content"))
    return JsonResponse({"success": True, "id": msg.id})


# --- PUBLIC BOOKING ---

@csrf_protect
@ratelimit(key='ip', rate='5/m', block=True)
def book_appointment(request):
    if request.method == "GET":
        return render(request, 'core/book_appointment.html')

    if request.method == "POST":
        try:
            data = json.loads(request.body)
            business_slug = getattr(request, "subdomain", None)
            business = get_object_or_404(Business, slug=business_slug)

            start_time = timezone.make_aware(datetime.fromisoformat(data.get("start_time")))
            end_time = timezone.make_aware(datetime.fromisoformat(data.get("end_time")))

            if Appointment.objects.filter(
                business=business,
                status="confirmed",
                start_time__lt=end_time,
                end_time__gt=start_time
            ).exists():
                return JsonResponse({"error": "Slot taken"}, status=400)

            appointment = Appointment.objects.create(
                customer_name=data.get("customer_name"),
                customer_email=data.get("customer_email"),
                business=business,
                start_time=start_time,
                end_time=end_time,
                status="pending"
            )

            Conversation.objects.get_or_create(appointment=appointment)
            return JsonResponse({"success": True}, status=201)

        except Exception as e:
            return JsonResponse({"error": str(e)}, status=400)

    return JsonResponse({"error": "Method not allowed"}, status=405)
