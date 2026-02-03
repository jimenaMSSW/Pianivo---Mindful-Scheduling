import json
from datetime import datetime
from django.contrib.auth.decorators import login_required
from django.shortcuts import render, get_object_or_404
from django.utils import timezone
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt, csrf_protect
from django.views.decorators.http import require_POST
from django.core.exceptions import PermissionDenied

from core.models import Appointment, BusinessEmployee, Business


# --- Helper ---
def get_aware_datetime(date_str):
    """Convert ISO string to aware datetime"""
    try:
        dt = datetime.fromisoformat(date_str.replace("Z", "+00:00"))
        return dt if timezone.is_aware(dt) else timezone.make_aware(dt)
    except Exception:
        return timezone.now()


# --- Dashboard ---
@login_required
def owner_dashboard(request):
    """Owner dashboard: list + calendar"""
    # Security check
    user_business = getattr(request.user, 'business_owned', None)
    if not user_business:
        raise PermissionDenied("You do not own a business.")

    # Filters
    status_filter = request.GET.get("status", "")
    employee_filter = request.GET.get("employee", "")

    appointments = Appointment.objects.filter(business=user_business).select_related('employee__user')

    if status_filter:
        appointments = appointments.filter(status=status_filter)
    if employee_filter:
        appointments = appointments.filter(employee_id=employee_filter)

    # Build Calendar Events
    events = []
    for a in appointments:
        color = "#ffc107"  # pending
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
            "extendedProps": {
                "status": a.status
            }
        })

    return render(request, "owner/dashboard.html", {
        "appointments": appointments.order_by("start_time"),
        "events_json": json.dumps(events),
        "user_business": user_business,
        "employees": BusinessEmployee.objects.filter(business=user_business),
        "status_filter": status_filter,
        "employee_filter": employee_filter
    })


# --- Permissions Toggle ---
@login_required
@csrf_exempt
@require_POST
def toggle_permissions(request):
    user_business = getattr(request.user, 'business_owned', None)
    if not user_business:
        raise PermissionDenied("No business found.")
    enabled = request.POST.get("enabled") == "true"
    user_business.employees_can_manage_appointments = enabled
    user_business.save()
    return JsonResponse({"success": True})


# --- Appointment Actions ---
@login_required
@csrf_exempt
@require_POST
def add_appointment(request):
    """Owner creates a pending appointment"""
    try:
        data = json.loads(request.body)
        user_business = getattr(request.user, 'business_owned', None)
        if not user_business:
            raise PermissionDenied("No business found.")

        emp_id = data.get("employee_id")
        if emp_id in [None, ""]:
            emp_id = None
        else:
            emp_id = int(emp_id)

        Appointment.objects.create(
            customer_name=data["customer_name"],
            business=user_business,
            employee_id=emp_id,
            start_time=get_aware_datetime(data["start_time"]),
            end_time=get_aware_datetime(data["end_time"]),
            status="pending"
        )
        return JsonResponse({"success": True})
    except Exception as e:
        print("Failed to create appointment:", e)
        return JsonResponse({"error": str(e)}, status=500)


@login_required
@csrf_exempt
@require_POST
def confirm_appointment(request, appointment_id):
    appointment = get_object_or_404(Appointment, id=appointment_id)
    if appointment.status != "pending":
        return JsonResponse({"error": "Only pending appointments can be confirmed"}, status=400)
    if appointment.overlaps():
        return JsonResponse({"error": "Time slot already taken"}, status=400)
    appointment.status = "confirmed"
    appointment.save()
    return JsonResponse({"success": True, "status": appointment.status})


@login_required
@csrf_exempt
@require_POST
def reject_appointment(request, appointment_id):
    appointment = get_object_or_404(Appointment, id=appointment_id)
    if appointment.status != "pending":
        return JsonResponse({"error": "Only pending appointments can be rejected"}, status=400)
    appointment.status = "rejected"
    appointment.save()
    return JsonResponse({"success": True, "status": appointment.status})


@login_required
@csrf_exempt
@require_POST
def delete_appointment(request, appointment_id):
    """Delete any appointment"""
    appointment = get_object_or_404(Appointment, id=appointment_id)
    appointment.delete()
    return JsonResponse({"success": True})


@login_required
@csrf_exempt
@require_POST
def reschedule_appointment(request, appointment_id):
    appointment = get_object_or_404(Appointment, id=appointment_id)
    data = json.loads(request.body)
    appointment.start_time = get_aware_datetime(data["start_time"])
    appointment.end_time = get_aware_datetime(data["end_time"])
    appointment.save()
    return JsonResponse({"success": True})


@login_required
@csrf_exempt
@require_POST
def update_appointment(request, appointment_id):
    appointment = get_object_or_404(Appointment, id=appointment_id)
    data = json.loads(request.body)
    appointment.customer_name = data.get("customer_name", appointment.customer_name)
    if data.get("employee_id"):
        appointment.employee_id = data.get("employee_id")
    appointment.save()
    return JsonResponse({"success": True})
