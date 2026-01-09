from django.shortcuts import get_object_or_404
from django.views.decorators.csrf import csrf_protect, csrf_exempt
from django.http import JsonResponse
from django_ratelimit.decorators import ratelimit
from django.utils import timezone
from django.views.decorators.http import require_POST
from datetime import datetime
from core.models import Business, Appointment
import json


def whoami(request):
    """Return current business info based on subdomain"""
    return JsonResponse({
        "subdomain": getattr(request, "subdomain", None),
        "business": getattr(request, "business", None) and request.business.name
    })


@require_POST
@csrf_exempt  # Needed if called via AJAX with JS
def confirm_appointment(request, appointment_id):
    appointment = get_object_or_404(Appointment, id=appointment_id)

    if appointment.status != "pending":
        return JsonResponse({"error": "Only pending appointments can be confirmed"}, status=400)

    # Check for overlap with confirmed appointments
    if Appointment.objects.filter(
        business=appointment.business,
        status="confirmed",
        start_time__lt=appointment.end_time,
        end_time__gt=appointment.start_time
    ).exclude(id=appointment.id).exists():
        return JsonResponse({"error": "Time slot already taken"}, status=400)

    appointment.confirm()

    return JsonResponse({
        "success": True,
        "appointment_id": appointment.id,
        "status": appointment.status,
        "confirmed_at": appointment.confirmed_at.isoformat()
    })


@require_POST
@csrf_exempt
def reject_appointment(request, appointment_id):
    appointment = get_object_or_404(Appointment, id=appointment_id)

    if appointment.status != "pending":
        return JsonResponse({"error": "Only pending appointments can be rejected"}, status=400)

    appointment.reject()

    return JsonResponse({
        "success": True,
        "appointment_id": appointment.id,
        "status": appointment.status
    })


@csrf_protect
@ratelimit(key='ip', rate='5/m', block=True)
def book_appointment(request):
    """
    Book an appointment for a business via subdomain.
    Expects JSON POST: customer_name, customer_email, start_time, end_time
    """
    if request.method != "POST":
        return JsonResponse({"error": "POST request required"}, status=405)

    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({"error": "Invalid JSON"}, status=400)

    business_slug = getattr(request, "subdomain", None)
    if not business_slug:
        return JsonResponse({"error": "No subdomain detected"}, status=400)

    business = get_object_or_404(Business, slug=business_slug)

    # Parse datetimes and make timezone-aware
    try:
        start_time = datetime.fromisoformat(data.get("start_time"))
        end_time = datetime.fromisoformat(data.get("end_time"))
        if timezone.is_naive(start_time):
            start_time = timezone.make_aware(start_time, timezone.get_current_timezone())
        if timezone.is_naive(end_time):
            end_time = timezone.make_aware(end_time, timezone.get_current_timezone())
    except Exception:
        return JsonResponse({"error": "Invalid datetime format"}, status=400)

    if end_time <= start_time:
        return JsonResponse({"error": "End time must be after start time"}, status=400)

    # Overlap check with confirmed appointments
    if Appointment.objects.filter(
        business=business,
        status="confirmed",
        start_time__lt=end_time,
        end_time__gt=start_time
    ).exists():
        return JsonResponse({"error": "Booking overlaps with another appointment"}, status=400)

    appointment = Appointment.objects.create(
        customer_name=data.get("customer_name"),
        customer_email=data.get("customer_email"),
        business=business,
        start_time=start_time,
        end_time=end_time,
        status="pending"
    )

    return JsonResponse({
        "success": True,
        "appointment_id": appointment.id,
        "customer_name": appointment.customer_name,
        "start_time": appointment.start_time.isoformat(),
        "end_time": appointment.end_time.isoformat(),
        "status": appointment.status
    }, status=201)
