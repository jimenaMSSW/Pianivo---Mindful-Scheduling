import json
from django.shortcuts import render, get_object_or_404
from django.http import JsonResponse
from django.contrib.auth.decorators import login_required
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST
from django.utils import timezone
from core.models import Appointment, Employee
from datetime import timedelta
from django.utils.dateparse import parse_datetime

@login_required
def employee_dashboard(request):
    """
    Main dashboard for employees to view their schedule and stats.
    """
    try:
        employee = request.user.employee_profile
    except Exception:
        return render(request, "errors/no_profile.html", {"message": "No employee profile found."})

    appointments = Appointment.objects.filter(employee=employee).order_by("start_time")

    events = []
    for a in appointments:
        bg_color = "#f39c12"  # Pending
        if a.status == 'confirmed':
            bg_color = "#27ae60"
        elif a.status == 'rejected':
            bg_color = "#e74c3c"

        events.append({
            "id": str(a.id),
            "title": a.customer_name,
            "start": a.start_time.isoformat(),
            "end": a.end_time.isoformat() if a.end_time else None,
            "status": a.status,
            "conversation_id": a.conversation.id if hasattr(a, 'conversation') and a.conversation else None,
            "backgroundColor": bg_color,
            "borderColor": bg_color,
            "textColor": "#ffffff"
        })

    return render(request, "employee/dashboard.html", {
        "employee": employee,
        "appointments": appointments,
        "events_json": json.dumps(events)
    })

@login_required
def employee_add_appointment(request):
    """
    Creates a new appointment. Handles both JSON and Form data for robustness.
    """
    employee = request.user.employee_profile
    if not employee.business.employees_can_manage_appointments:
        return JsonResponse({"error": "Permission denied by owner."}, status=403)

    if request.method == "POST":
        # Check if the data is JSON or Form-encoded
        if request.content_type == 'application/json':
            data = json.loads(request.body)
        else:
            data = request.POST

        try:
            start_time = parse_datetime(data.get("start_time"))
            
            # Auto-calculate end_time if not provided (defaulting to 1 hour)
            end_time_str = data.get("end_time")
            if end_time_str:
                end_time = parse_datetime(end_time_str)
            else:
                end_time = start_time + timedelta(hours=1)

            Appointment.objects.create(
                customer_name=data.get("customer_name"),
                business=employee.business,
                employee=employee,
                start_time=start_time,
                end_time=end_time,
                status="pending"
            )
            return JsonResponse({"success": True})
        except Exception as e:
            return JsonResponse({"success": False, "error": str(e)}, status=400)
    
    return JsonResponse({"error": "Method not allowed"}, status=405)

@login_required
@require_POST
def employee_confirm_appointment(request, appointment_id):
    employee = request.user.employee_profile
    appointment = get_object_or_404(Appointment, id=appointment_id, employee=employee)
    appointment.status = 'confirmed'
    appointment.save()
    return JsonResponse({"success": True})

@login_required
@require_POST
def employee_reject_appointment(request, appointment_id):
    employee = request.user.employee_profile
    appointment = get_object_or_404(Appointment, id=appointment_id, employee=employee)
    appointment.status = 'rejected'
    appointment.save()
    return JsonResponse({"success": True})

@login_required
@require_POST
def employee_reschedule_appointment(request, appointment_id):
    employee = request.user.employee_profile
    appointment = get_object_or_404(Appointment, id=appointment_id, employee=employee)
    
    new_time_str = request.POST.get('new_time')
    if new_time_str:
        new_time = parse_datetime(new_time_str)
        if new_time:
            appointment.start_time = new_time
            # Auto-update end time to maintain duration
            appointment.end_time = new_time + timedelta(hours=1)
            appointment.status = 'pending' 
            appointment.save()
            return JsonResponse({"success": True})
    
    return JsonResponse({"success": False, "error": "Invalid or missing time."}, status=400)

@login_required
@require_POST
def employee_delete_appointment(request, appointment_id):
    employee = request.user.employee_profile
    if not employee.business.employees_can_manage_appointments:
        return JsonResponse({"error": "Permission denied by owner."}, status=403)

    appointment = get_object_or_404(Appointment, id=appointment_id, employee=employee)
    appointment.delete()
    return JsonResponse({"success": True})