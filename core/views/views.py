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
        # Make sure this matches the app_name and path name
        return redirect('owner:owner_dashboard') 

    if hasattr(request.user, 'employee_profile'):
        # If employee_dashboard is NOT namespaced, use it directly
        return redirect('employee_dashboard')

    return redirect('book')

def get_calendar_events(appointments):
    """Formats appointment queryset into JSON for FullCalendar"""
    events = []
    for a in appointments:
        events.append({
            "id": a.id,
            "title": f"{a.customer_name} ({a.employee.user.username if a.employee else 'Unassigned'})",
            "start": a.start_time.isoformat(),
            "end": a.end_time.isoformat(),
            "backgroundColor": "#27ae60" if a.status == "confirmed" else "#d97706",
            "borderColor": "transparent",
            "textColor": "#ffffff",
        })
    return json.dumps(events, cls=DjangoJSONEncoder)

# --- OWNER VIEWS ---

@login_required
def owner_dashboard(request):
    # Ensure the user owns a business
    business = get_object_or_404(Business, owner=request.user)
    
    # Get Filters from GET request
    status_filter = request.GET.get('status')
    employee_filter = request.GET.get('employee')
    
    appointments = Appointment.objects.filter(business=business)
    
    if status_filter:
        appointments = appointments.filter(status=status_filter)
    if employee_filter:
        appointments = appointments.filter(employee_id=employee_filter)

    context = {
        'user_business': business,
        'appointments': appointments.order_by('-start_time'),
        'employees': Employee.objects.filter(business=business),
        'events_json': get_calendar_events(appointments),
        'status_filter': status_filter,
        'employee_filter': employee_filter,
    }
    return render(request, 'owner/dashboard.html', context)

@require_POST
@login_required
def toggle_permissions(request):
    """Handles the 'Employee Autonomy' switch"""
    business = get_object_or_404(Business, owner=request.user)
    enabled = request.POST.get('enabled') == 'true'
    business.employees_can_manage_appointments = enabled
    business.save()
    return JsonResponse({'status': 'success'})

# --- EMPLOYEE VIEWS ---

@login_required
def employee_dashboard(request):
    # Use filter().first() instead of get_object_or_404 to handle owners/admins gracefully
    employee = getattr(request.user, 'employee_profile', None)
    
    if not employee:
        # If they aren't an employee, maybe they are an owner? Redirect them.
        if request.user.owned_businesses.exists():
            return redirect('owner:owner_dashboard')
        return redirect('login') # Or an error page

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
    """Handles the 'Quick Book' form for Employees"""
    employee = get_object_or_404(Employee, user=request.user)
    
    if not employee.business.employees_can_manage_appointments:
        return JsonResponse({"error": "Manager has disabled self-booking."}, status=403)

    try:
        data = json.loads(request.body)
        Appointment.objects.create(
            business=employee.business,
            employee=employee,
            customer_name=data.get("customer_name"),
            start_time=data.get("start_time"),
            end_time=data.get("end_time"),
            status="confirmed"
        )
        return JsonResponse({"success": True})
    except Exception as e:
        return JsonResponse({"error": str(e)}, status=400)

@require_POST
@csrf_exempt 
def confirm_appointment(request, appointment_id):
    """Marks an appointment as confirmed"""
    appointment = get_object_or_404(Appointment, id=appointment_id)

    if appointment.status != "pending":
        return JsonResponse({"error": "Only pending appointments can be confirmed"}, status=400)

    # Check for overlap with other confirmed appointments
    if appointment.overlaps():
        return JsonResponse({"error": "Time slot already taken by another confirmed appointment"}, status=400)

    appointment.confirm()

    return JsonResponse({
        "success": True,
        "appointment_id": appointment.id,
        "status": appointment.status,
        "confirmed_at": appointment.confirmed_at.isoformat() if appointment.confirmed_at else None
    })

@require_POST
@csrf_exempt
def reject_appointment(request, appointment_id):
    """Marks an appointment as rejected"""
    appointment = get_object_or_404(Appointment, id=appointment_id)

    if appointment.status != "pending":
        return JsonResponse({"error": "Only pending appointments can be rejected"}, status=400)

    appointment.reject()

    return JsonResponse({
        "success": True,
        "appointment_id": appointment.id,
        "status": appointment.status
    })
# --- PUBLIC / SUBDOMAIN VIEWS (Your Original Logic) ---
@csrf_protect
@ratelimit(key='ip', rate='5/m', block=True)
def book_appointment(request):
    # Handle the GET request (Show the booking page)
    if request.method == "GET":
        return render(request, 'core/book_appointment.html')

    # Handle the POST request (Process the JSON data)
    if request.method == "POST":
        try:
            data = json.loads(request.body)
            # Use the subdomain from your custom middleware
            business_slug = getattr(request, "subdomain", None)
            business = get_object_or_404(Business, slug=business_slug)

            # Time parsing
            start_time = timezone.make_aware(datetime.fromisoformat(data.get("start_time")))
            end_time = timezone.make_aware(datetime.fromisoformat(data.get("end_time")))

            # Check for overlap
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

    # Fallback for other methods (PUT, DELETE, etc.)
    return JsonResponse({"error": "Method not allowed"}, status=405)
        
    
@require_POST
@login_required
def employee_delete_appointment(request, appointment_id):
    employee = get_object_or_404(Employee, user=request.user)
    
    # Check if they have permission to manage appointments
    if not employee.business.employees_can_manage_appointments:
        return JsonResponse({"error": "Permission denied"}, status=403)
        
    appointment = get_object_or_404(Appointment, id=appointment_id, employee=employee)
    appointment.delete()
    return JsonResponse({"success": True})
def whoami(request):
    return JsonResponse({
        "user": request.user.username if request.user.is_authenticated else "Anonymous",
        "subdomain": getattr(request, "subdomain", "None"),
    })
# Add these to core/views/views.py

@require_POST
@login_required
def reschedule_appointment(request, appointment_id):
    """Changes the time of an existing appointment"""
    business = get_object_or_404(Business, owner=request.user)
    appointment = get_object_or_404(Appointment, id=appointment_id, business=business)
    
    try:
        data = json.loads(request.body)
        appointment.start_time = data.get("start_time")
        appointment.end_time = data.get("end_time")
        
        if appointment.overlaps():
            return JsonResponse({"error": "New time overlaps with another appointment"}, status=400)
            
        appointment.save()
        return JsonResponse({"success": True})
    except Exception as e:
        return JsonResponse({"error": str(e)}, status=400)

@require_POST
@login_required
def update_appointment(request, appointment_id):
    """Updates general details like customer name or assigned employee"""
    business = get_object_or_404(Business, owner=request.user)
    appointment = get_object_or_404(Appointment, id=appointment_id, business=business)
    
    try:
        data = json.loads(request.body)
        appointment.customer_name = data.get("customer_name", appointment.customer_name)
        
        # If an employee ID is provided, update the assignment
        emp_id = data.get("employee_id")
        if emp_id:
            appointment.employee = get_object_or_404(Employee, id=emp_id, business=business)
            
        appointment.save()
        return JsonResponse({"success": True})
    except Exception as e:
        return JsonResponse({"error": str(e)}, status=400)

@require_POST
@login_required
def add_appointment(request):
    """Owner version of adding an appointment (usually auto-confirmed)"""
    business = get_object_or_404(Business, owner=request.user)
    try:
        data = json.loads(request.body)
        # Owner can assign any of their employees
        employee = Employee.objects.filter(id=data.get("employee_id"), business=business).first()
        
        Appointment.objects.create(
            business=business,
            employee=employee,
            customer_name=data.get("customer_name"),
            start_time=data.get("start_time"),
            end_time=data.get("end_time"),
            status="confirmed"
        )
        return JsonResponse({"success": True})
    except Exception as e:
        return JsonResponse({"error": str(e)}, status=400)
    

