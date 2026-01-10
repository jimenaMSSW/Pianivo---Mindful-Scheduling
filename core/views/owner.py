import json
from datetime import datetime
from django.contrib.auth.decorators import login_required
from django.shortcuts import render, get_object_or_404
from django.utils import timezone
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST
from core.models import Appointment, BusinessEmployee, Business
from django.core.exceptions import PermissionDenied

def get_aware_datetime(date_str):
    try:
        dt = datetime.fromisoformat(date_str.replace('Z', '+00:00'))
        return dt if timezone.is_aware(dt) else timezone.make_aware(dt)
    except Exception:
        return timezone.now()

@login_required
def dashboard(request):
    # Get Business Profile
    employee_profile = getattr(request.user, 'employee_profile', None)
    user_business = employee_profile.business if employee_profile else Business.objects.first()

    if not user_business:
        return render(request, "owner/dashboard.html", {"error": "No business found."})

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
        color = "#ffc107" # Default Pending
        if a.employee and a.employee.color:
            color = a.employee.color
        elif a.status == "confirmed":
            color = "#28a745"
        elif a.status == "rejected":
            color = "#dc3545"

        events.append({
            "id": str(a.id),
            "title": f"{a.customer_name} ({a.employee.user.username if a.employee else 'Unassigned'})",
            "start": a.start_time.isoformat(),
            #"end": a.end_time.isoformat(),
            "backgroundColor": color,
            "borderColor": color,
            "textColor": "#000000"
        })

    return render(request, "owner/dashboard.html", {
        "appointments": appointments.order_by("start_time"), # This is for the List View
        "events_json": json.dumps(events),                 # This is for the Calendar
        "user_business": user_business,
        "appointments": appointments.order_by("start_time"),
        "employees": BusinessEmployee.objects.filter(business=user_business),
        "events_json": json.dumps(events),
        "status_filter": status_filter,
        "employee_filter": employee_filter
    })

@login_required
@csrf_exempt
@require_POST
def toggle_permissions(request):
    employee_profile = getattr(request.user, 'employee_profile', None)
    user_business = employee_profile.business if employee_profile else Business.objects.first()
    
    is_enabled = request.POST.get('enabled') == 'true'
    user_business.employees_can_manage_appointments = is_enabled
    user_business.save()
    return JsonResponse({"success": True})

@login_required
@require_POST
def confirm_appointment(request, appointment_id):
    appointment = get_object_or_404(Appointment, id=appointment_id)
    appointment.status = 'confirmed'
    appointment.save()
    return JsonResponse({"success": True})

@login_required
@require_POST
def reject_appointment(request, appointment_id):
    appointment = get_object_or_404(Appointment, id=appointment_id)
    appointment.status = 'rejected'
    appointment.save()
    return JsonResponse({"success": True})

@login_required
@csrf_exempt
@require_POST
def reschedule_appointment(request, appointment_id):
    appointment = get_object_or_404(Appointment, id=appointment_id)
    data = json.loads(request.body)
    appointment.start_time = get_aware_datetime(data['start_time'])
    appointment.end_time = get_aware_datetime(data['end_time'])
    appointment.save()
    return JsonResponse({"success": True})

@login_required
@csrf_exempt
@require_POST
def update_appointment(request, appointment_id):
    appointment = get_object_or_404(Appointment, id=appointment_id)
    data = json.loads(request.body)
    appointment.customer_name = data.get('customer_name', appointment.customer_name)
    if data.get('employee_id'):
        appointment.employee_id = data.get('employee_id')
    appointment.save()
    return JsonResponse({"success": True})

@login_required
@csrf_exempt
def add_appointment(request):
    if request.method == "POST":
        data = json.loads(request.body)
        employee_profile = getattr(request.user, 'employee_profile', None)
        user_business = employee_profile.business if employee_profile else Business.objects.first()
        
        Appointment.objects.create(
            customer_name=data['customer_name'],
            business=user_business,
            employee_id=data.get('employee_id') if data.get('employee_id') else None,
            start_time=get_aware_datetime(data['start_time']),
            end_time=get_aware_datetime(data['end_time']),
            status='pending'
        )
        return JsonResponse({"success": True})
    

def owner_dashboard(request):
    # Security Check: If the user doesn't own a business, block them
    if not hasattr(request.user, 'business_owned'):
        raise PermissionDenied  # This shows a "403 Forbidden" page
    
    # ... rest of your code ...