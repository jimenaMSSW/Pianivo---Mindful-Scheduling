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

from core.models import Business, Appointment, Employee

# --- HELPER FUNCTIONS ---

def root_redirect(request):
    if not request.user.is_authenticated:
        return redirect('login')

    if request.user.owned_businesses.exists():
        return redirect('owner:owner_dashboard') 

    if hasattr(request.user, 'employee_profile'):
        return redirect('employee_dashboard')

    return redirect('book')

def get_calendar_events(appointments):
    """Formats appointment queryset into JSON for FullCalendar with extendedProps for buttons"""
    events = []
    for a in appointments:
        events.append({
            "id": str(a.id),
            "title": f"{a.customer_name}",
            "start": a.start_time.isoformat(),
            "end": a.end_time.isoformat(),
            "extendedProps": {
                "status": a.status.lower(),
                "employee_name": a.employee.user.username if a.employee else 'Unassigned'
            },
            "backgroundColor": "#27ae60" if a.status == "confirmed" else "#d97706",
            "borderColor": "transparent",
            "textColor": "#ffffff",
        })
    return json.dumps(events, cls=DjangoJSONEncoder)

def whoami(request):
    """Simple helper for debugging user and subdomain status"""
    return JsonResponse({
        "user": request.user.username if request.user.is_authenticated else "Anonymous",
        "subdomain": getattr(request, "subdomain", "None"),
    })

# --- OWNER VIEWS ---

@login_required
def owner_dashboard(request):
    business = get_object_or_404(Business, owner=request.user)
    
    appointments = Appointment.objects.filter(business=business)  # filter first

    status_filter = request.GET.get('status')
    employee_filter = request.GET.get('employee')
    
    if status_filter:
        appointments = appointments.filter(status=status_filter)
    if employee_filter:
        appointments = appointments.filter(employee_id=employee_filter)
    
    # ORDER BY DATE ASCENDING
    appointments = appointments.order_by('start_time')

    context = {
        'user_business': business,
        'appointments': appointments,
        'employees': Employee.objects.filter(business=business),
        'events_json': get_calendar_events(appointments),
        'status_filter': status_filter,
        'employee_filter': employee_filter,
    }
    return render(request, 'owner/dashboard.html', context)


@require_POST
@login_required
def toggle_permissions(request):
    business = get_object_or_404(Business, owner=request.user)
    enabled = request.POST.get('enabled') == 'true'
    business.employees_can_manage_appointments = enabled
    business.save()
    return JsonResponse({'status': 'success'})

@require_POST
@login_required
def add_appointment(request):
    """Owner version of adding an appointment"""
    business = get_object_or_404(Business, owner=request.user)
    try:
        data = json.loads(request.body)
        employee = Employee.objects.filter(id=data.get("employee_id"), business=business).first()
        
        start = timezone.make_aware(datetime.fromisoformat(data.get("start_time")))
        end = timezone.make_aware(datetime.fromisoformat(data.get("end_time")))

        Appointment.objects.create(
            business=business,
            employee=employee,
            customer_name=data.get("customer_name"),
            start_time=start,
            end_time=end,
            status="pending"
        )
        return JsonResponse({"success": True})
    except Exception as e:
        return JsonResponse({"error": str(e)}, status=400)

@require_POST
@login_required
def owner_delete_appointment(request, appointment_id):
    """Allows owners to delete any appointment in their business"""
    business = get_object_or_404(Business, owner=request.user)
    appointment = get_object_or_404(Appointment, id=appointment_id, business=business)
    appointment.delete()
    return JsonResponse({"success": True})

@require_POST
@login_required
def reschedule_appointment(request, appointment_id):
    """Verify ownership and update appointment timing"""
    business = get_object_or_404(Business, owner=request.user)
    appointment = get_object_or_404(Appointment, id=appointment_id, business=business)
    
    try:
        data = json.loads(request.body)
        appointment.start_time = timezone.make_aware(datetime.fromisoformat(data.get("start_time")))
        appointment.end_time = timezone.make_aware(datetime.fromisoformat(data.get("end_time")))
        
        if appointment.overlaps():
            return JsonResponse({"error": "New time overlaps with another appointment"}, status=400)
            
        appointment.save()
        return JsonResponse({"success": True})
    except Exception as e:
        return JsonResponse({"error": str(e)}, status=400)

@require_POST
@login_required
def update_appointment(request, appointment_id):
    """Updates specific details like name or assigned staff"""
    business = get_object_or_404(Business, owner=request.user)
    appointment = get_object_or_404(Appointment, id=appointment_id, business=business)
    
    try:
        data = json.loads(request.body)
        appointment.customer_name = data.get("customer_name", appointment.customer_name)
        
        emp_id = data.get("employee_id")
        if emp_id:
            appointment.employee = get_object_or_404(Employee, id=emp_id, business=business)
            
        appointment.save()
        return JsonResponse({"success": True})
    except Exception as e:
        return JsonResponse({"error": str(e)}, status=400)

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
        
        Appointment.objects.create(
            business=employee.business,
            employee=employee,
            customer_name=data.get("customer_name"),
            start_time=start,
            end_time=end,
            status="pending"
        )
        return JsonResponse({"success": True})
    except Exception as e:
        return JsonResponse({"error": str(e)}, status=400)

@require_POST
@login_required
def employee_delete_appointment(request, appointment_id):
    employee = get_object_or_404(Employee, user=request.user)
    
    if not employee.business.employees_can_manage_appointments:
        return JsonResponse({"error": "Permission denied"}, status=403)
        
    appointment = get_object_or_404(Appointment, id=appointment_id, employee=employee)
    appointment.delete()
    return JsonResponse({"success": True})

# --- APPOINTMENT STATUS ACTIONS ---

@require_POST
@csrf_protect 
def confirm_appointment(request, appointment_id):
    appointment = get_object_or_404(Appointment, id=appointment_id)

    if appointment.status != "pending":
        return JsonResponse({"error": "Only pending appointments can be confirmed"}, status=400)

    if appointment.overlaps():
        return JsonResponse({"error": "Time slot already taken by another confirmed appointment"}, status=400)

    appointment.confirm()
    return JsonResponse({"success": True, "status": appointment.status})

@require_POST
@csrf_protect
def reject_appointment(request, appointment_id):
    appointment = get_object_or_404(Appointment, id=appointment_id)
    if appointment.status != "pending":
        return JsonResponse({"error": "Only pending appointments can be rejected"}, status=400)

    appointment.reject()
    return JsonResponse({"success": True, "status": appointment.status})

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

            # Check for overlap before creating pending
            if Appointment.objects.filter(
                business=business, 
                status="confirmed", 
                start_time__lt=end_time, 
                end_time__gt=start_time
            ).exists():
                return JsonResponse({"error": "Slot taken"}, status=400)

            Appointment.objects.create(
                customer_name=data.get("customer_name"),
                customer_email=data.get("customer_email"),
                business=business,
                start_time=start_time,
                end_time=end_time,
                status="pending"
            )
            return JsonResponse({"success": True}, status=201)
        except Exception as e:
            return JsonResponse({"error": str(e)}, status=400)

    return JsonResponse({"error": "Method not allowed"}, status=405)