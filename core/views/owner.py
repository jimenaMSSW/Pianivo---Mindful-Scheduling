import json
import logging
from datetime import datetime
from django.contrib.auth.decorators import login_required
from django.shortcuts import render, get_object_or_404
from django.utils import timezone
from django.http import JsonResponse
from django.views.decorators.http import require_POST
from django.views.decorators.csrf import csrf_protect
from django.core.exceptions import PermissionDenied

from core.models import Appointment, Employee, Business, Conversation, Message

logger = logging.getLogger(__name__)


# -------------------------
# Helper Functions
# -------------------------

def get_aware_datetime(date_str):
    """Convert ISO string to timezone-aware datetime"""
    try:
        dt = datetime.fromisoformat(date_str.replace("Z", "+00:00"))
        return dt if timezone.is_aware(dt) else timezone.make_aware(dt)
    except Exception:
        logger.warning(f"Failed to parse datetime '{date_str}', using now.")
        return timezone.now()


def user_can_access_appointment(user, appointment):
    """Owner or assigned employee can access"""
    if appointment.business.owner == user:
        return True
    if appointment.employee and appointment.employee.user == user:
        return True
    return False


def user_can_access_conversation(user, conversation):
    return user_can_access_appointment(user, conversation.appointment)


# -------------------------
# Owner Dashboard
# -------------------------

@login_required
def owner_dashboard(request):
    # Get the first business owned by the user
    user_business = request.user.owned_businesses.first()
    if not user_business:
        raise PermissionDenied("You do not own a business.")

    status_filter = request.GET.get("status", "")
    employee_filter = request.GET.get("employee", "")

    appointments = Appointment.objects.filter(
        business=user_business
    ).select_related('employee__user')

    if status_filter:
        appointments = appointments.filter(status=status_filter)

    if employee_filter:
        appointments = appointments.filter(employee_id=employee_filter)

    events = []
    for a in appointments:
        color = "#ffc107"
        if a.status == "confirmed":
            color = "#28a745"
        elif a.status == "rejected":
            color = "#dc3545"
        elif a.employee and getattr(a.employee, "color", None):
            color = a.employee.color

        events.append({
            "id": str(a.id),
            "title": f"{a.customer_name} ({a.employee.user.username if a.employee else 'Unassigned'})",
            "start": a.start_time.isoformat(),
            "end": a.end_time.isoformat() if a.end_time else None,
            "backgroundColor": color,
            "borderColor": color,
            "textColor": "#000000",
            "extendedProps": {"status": a.status}
        })

    return render(request, "owner/dashboard.html", {
        "appointments": appointments.order_by("start_time"),
        "events_json": json.dumps(events),
        "user_business": user_business,
        "employees": Employee.objects.filter(business=user_business),
        "status_filter": status_filter,
        "employee_filter": employee_filter
    })

# -------------------------
# Permissions Toggle
# -------------------------

@login_required
@require_POST
@csrf_protect
def toggle_permissions(request):
    business = request.user.owned_businesses.first()
    if not business:
        raise PermissionDenied("No business found.")

    enabled = request.POST.get("enabled") == "true"
    business.employees_can_manage_appointments = enabled
    business.save()

    return JsonResponse({"success": True})


# -------------------------
# Appointment CRUD
# -------------------------

@login_required
@require_POST
@csrf_protect
def add_appointment(request):
    """Create a new appointment for the owner's business"""
    try:
        data = json.loads(request.body)
        business = request.user.owned_businesses.first()
        if not business:
            raise PermissionDenied("No business found.")

        employee = None
        emp_id = data.get("employee_id")
        if emp_id not in [None, ""]:
            employee = get_object_or_404(Employee, id=int(emp_id), business=business)

        appointment = Appointment.objects.create(
            customer_name=data["customer_name"],
            business=business,
            employee=employee,
            start_time=get_aware_datetime(data["start_time"]),
            end_time=get_aware_datetime(data["end_time"]),
            status="pending"
        )

        Conversation.objects.get_or_create(appointment=appointment)

        return JsonResponse({
            "success": True,
            "appointment": {
                "id": appointment.id,
                "customer_name": appointment.customer_name,
                "status": appointment.status,
                "start_time": appointment.start_time.isoformat(),
                "end_time": appointment.end_time.isoformat() if appointment.end_time else None,
            }
        })

    except Exception as e:
        logger.error(f"Failed to create appointment: {e}")
        return JsonResponse({"error": str(e)}, status=500)


@login_required
@require_POST
@csrf_protect
def update_appointment(request, appointment_id):
    appointment = get_object_or_404(Appointment, id=appointment_id)
    if not user_can_access_appointment(request.user, appointment):
        raise PermissionDenied()

    try:
        data = json.loads(request.body)
        appointment.customer_name = data.get("customer_name", appointment.customer_name)

        if data.get("employee_id"):
            appointment.employee = get_object_or_404(
                Employee,
                id=int(data["employee_id"]),
                business=appointment.business
            )
        appointment.save()
        return JsonResponse({"success": True})
    except Exception as e:
        logger.error(f"Failed to update appointment {appointment_id}: {e}")
        return JsonResponse({"error": str(e)}, status=500)


@login_required
@require_POST
@csrf_protect
def delete_appointment(request, appointment_id):
    appointment = get_object_or_404(Appointment, id=appointment_id)
    if not user_can_access_appointment(request.user, appointment):
        raise PermissionDenied()
    appointment.delete()
    return JsonResponse({"success": True})


@login_required
@require_POST
@csrf_protect
def confirm_appointment(request, appointment_id):
    appointment = get_object_or_404(Appointment, id=appointment_id)
    if not user_can_access_appointment(request.user, appointment):
        raise PermissionDenied()

    if appointment.status != "pending":
        return JsonResponse({"error": "Only pending appointments can be confirmed"}, status=400)

    if hasattr(appointment, "overlaps") and appointment.overlaps():
        return JsonResponse({"error": "Time slot already taken"}, status=400)

    appointment.status = "confirmed"
    appointment.save()
    return JsonResponse({"success": True, "status": appointment.status})


@login_required
@require_POST
@csrf_protect
def reject_appointment(request, appointment_id):
    appointment = get_object_or_404(Appointment, id=appointment_id)
    if not user_can_access_appointment(request.user, appointment):
        raise PermissionDenied()

    if appointment.status != "pending":
        return JsonResponse({"error": "Only pending appointments can be rejected"}, status=400)

    appointment.status = "rejected"
    appointment.save()
    return JsonResponse({"success": True, "status": appointment.status})


@login_required
@require_POST
@csrf_protect
def reschedule_appointment(request, appointment_id):
    appointment = get_object_or_404(Appointment, id=appointment_id)
    if not user_can_access_appointment(request.user, appointment):
        raise PermissionDenied()

    try:
        data = json.loads(request.body)
        appointment.start_time = get_aware_datetime(data["start_time"])
        appointment.end_time = get_aware_datetime(data["end_time"])
        appointment.save()
        return JsonResponse({"success": True})
    except Exception as e:
        logger.error(f"Failed to reschedule appointment {appointment_id}: {e}")
        return JsonResponse({"error": str(e)}, status=500)


# -------------------------
# Messaging API
# -------------------------

@login_required
def api_get_messages(request):
    conversation_id = request.GET.get("conversation")
    conversation = get_object_or_404(Conversation, id=conversation_id)
    if not user_can_access_conversation(request.user, conversation):
        raise PermissionDenied()

    messages = conversation.messages.order_by("timestamp")
    data = [
        {
            "id": m.id,
            "sender": m.sender.id,
            "content": m.content,
            "timestamp": m.timestamp.isoformat(),
        }
        for m in messages
    ]
    return JsonResponse(data, safe=False)


@login_required
@require_POST
@csrf_protect
def api_send_message(request):
    try:
        data = json.loads(request.body)
        conversation = get_object_or_404(Conversation, id=data.get("conversation"))

        if not user_can_access_conversation(request.user, conversation):
            raise PermissionDenied()

        msg = Message.objects.create(
            conversation=conversation,
            sender=request.user,
            content=data.get("content")
        )
        return JsonResponse({"success": True, "id": msg.id})

    except Exception as e:
        logger.error(f"Failed to send message: {e}")
        return JsonResponse({"error": str(e)}, status=500)
