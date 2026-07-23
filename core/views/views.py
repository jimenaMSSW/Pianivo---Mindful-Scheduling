import json
import logging
from datetime import datetime
from django.shortcuts import render, get_object_or_404, redirect
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_protect
from django.views.decorators.http import require_POST
from django.contrib.auth.decorators import login_required
from django.utils import timezone
from django.core.serializers.json import DjangoJSONEncoder
from django.core.exceptions import PermissionDenied
from django_ratelimit.decorators import ratelimit

from core.models import Business, Appointment, Employee, Conversation, Message

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
        
        # Extract the employee's name for the calendar view
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

# --- OWNER VIEWS ---

@login_required
def owner_dashboard(request):
    business = Business.objects.filter(owner=request.user).first()
    if not business:
        return render(request, 'owner/no_business.html')

    # Default view shows all appointments for the business
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
    """View to filter the dashboard by a specific employee's schedule."""
    business = Business.objects.filter(owner=request.user).first()
    if not business:
        return render(request, 'owner/no_business.html')

    # Verify the employee belongs to this business owner
    employee = get_object_or_404(Employee, id=employee_id, business=business)
    
    # Filter appointments specifically for this employee
    appointments = Appointment.objects.filter(
        business=business, 
        employee=employee
    ).order_by('start_time').select_related('conversation', 'employee__user')

    # Still need the full list of employees for the sidebar dropdown
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
        start = timezone.make_aware(datetime.fromisoformat(data.get("start_time").replace('Z', '+00:00')))
        end = timezone.make_aware(datetime.fromisoformat(data.get("end_time").replace('Z', '+00:00')))
        appointment = Appointment.objects.create(
            business=business,
            customer_name=data.get("customer_name"),
            start_time=start,
            end_time=end,
            status="pending"
        )
        Conversation.objects.create(appointment=appointment)
        return JsonResponse({"success": True})
    except Exception as e:
        return JsonResponse({"error": str(e)}, status=400)

@require_POST
@login_required
def reschedule_appointment(request, appointment_id):
    appointment = get_object_or_404(Appointment, id=appointment_id, business__owner=request.user)
    try:
        data = json.loads(request.body)
        appointment.start_time = timezone.make_aware(datetime.fromisoformat(data.get("start_time").replace('Z', '+00:00')))
        appointment.end_time = timezone.make_aware(datetime.fromisoformat(data.get("end_time").replace('Z', '+00:00')))
        appointment.save()
        return JsonResponse({"success": True})
    except Exception as e:
        return JsonResponse({"error": str(e)}, status=400)

@require_POST
@login_required
def confirm_appointment(request, appointment_id):
    appointment = get_object_or_404(Appointment, id=appointment_id, business__owner=request.user)
    appointment.status = "confirmed"
    appointment.save()
    return JsonResponse({"success": True})

@require_POST
@login_required
def reject_appointment(request, appointment_id):
    appointment = get_object_or_404(Appointment, id=appointment_id, business__owner=request.user)
    appointment.status = "rejected"
    appointment.save()
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
    msg = Message.objects.create(
        conversation_id=data.get("conversation"),
        sender=request.user,
        content=data.get("content")
    )
    return JsonResponse({"success": True})

# --- PUBLIC BOOKING ---

@csrf_protect
@ratelimit(key='ip', rate='5/m', block=True)
def book_appointment(request):
    if request.method == "POST":
        try:
            data = json.loads(request.body)
            business_slug = getattr(request, "subdomain", None)
            business = get_object_or_404(Business, slug=business_slug)
            appointment = Appointment.objects.create(
                customer_name=data.get("customer_name"),
                business=business,
                start_time=timezone.make_aware(datetime.fromisoformat(data.get("start_time"))),
                end_time=timezone.make_aware(datetime.fromisoformat(data.get("end_time"))),
                status="pending"
            )
            Conversation.objects.create(appointment=appointment)
            return JsonResponse({"success": True}, status=201)
        except Exception as e:
            return JsonResponse({"error": str(e)}, status=400)
    return render(request, 'core/book_appointment.html')