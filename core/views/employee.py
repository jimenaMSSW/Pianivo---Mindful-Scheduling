import json
from django.shortcuts import render, get_object_or_404
from django.http import JsonResponse
from django.contrib.auth.decorators import login_required
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST
from django.utils import timezone
from core.models import Appointment, Employee

@login_required
def employee_dashboard(request):
    # Get the employee profile for the logged-in user
    try:
        employee = request.user.employee_profile
    except Exception:
        return render(request, "errors/no_profile.html", {"message": "No employee profile found."})

    appointments = Appointment.objects.filter(employee=employee).order_by("start_time")

    events = []
    for a in appointments:
        events.append({
            "id": str(a.id),
            "title": a.customer_name,
            "start": a.start_time.isoformat(),
            #"end": a.end_time.isoformat(),
            "backgroundColor": employee.color or "#3498db",
            "borderColor": employee.color or "#3498db",
            "textColor": "#000000"
        })

    return render(request, "employee/dashboard.html", {
        "appointments": appointments.order_by("start_time"), # This is for the List View
        "events_json": json.dumps(events),                 # This is for the Calendar
        "appointments": appointments,
        "events_json": json.dumps(events),
        "employee": employee
    })

@login_required
@csrf_exempt
def employee_add_appointment(request):
    employee = request.user.employee_profile
    if not employee.business.employees_can_manage_appointments:
        return JsonResponse({"error": "Permission denied by owner."}, status=403)

    if request.method == "POST":
        data = json.loads(request.body)
        Appointment.objects.create(
            customer_name=data["customer_name"],
            business=employee.business,
            employee=employee,
            start_time=data["start_time"],
            end_time=data["end_time"],
            status="pending"
        )
        return JsonResponse({"success": True})

@login_required
@csrf_exempt
@require_POST
def employee_delete_appointment(request, appointment_id):
    employee = request.user.employee_profile
    if not employee.business.employees_can_manage_appointments:
        return JsonResponse({"error": "Permission denied by owner."}, status=403)

    appointment = get_object_or_404(Appointment, id=appointment_id, employee=employee)
    appointment.delete()
    return JsonResponse({"success": True})