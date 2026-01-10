from django.db import models
from django.utils import timezone
from django.contrib.auth.models import User

class Business(models.Model):
    """
    The top-level entity. A Business is owned by a User.
    """
    # Use related_name="owned_business" so we can check request.user.owned_business
    owner = models.ForeignKey(
        User, 
        on_delete=models.CASCADE, 
        related_name="owned_businesses", 
        null=True
    )
    name = models.CharField(max_length=100)
    slug = models.SlugField(unique=True, null=True)
    subdomain = models.CharField(max_length=50, unique=True)
    email = models.EmailField(blank=True, null=True)
    timezone = models.CharField(max_length=50, default="UTC")
    created_at = models.DateTimeField(auto_now_add=True)

    # Permission Toggle
    employees_can_manage_appointments = models.BooleanField(default=True)
    
    class Meta:
        verbose_name_plural = "Businesses"

    def __str__(self):
        return self.name

class Employee(models.Model):
    """
    A profile that links a User to a Business as a staff member.
    An employee is NOT an owner.
    """
    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name="employee_profile"
    )
    business = models.ForeignKey(
        Business,
        on_delete=models.CASCADE,
        related_name="employees"
    )
    color = models.CharField(max_length=7, default="#3498db")

    def __str__(self):
        return f"{self.user.username} ({self.business.name})"

class Appointment(models.Model):
    """
    Appointments belong to a Business and are assigned to an Employee.
    """
    business = models.ForeignKey(
        Business, 
        on_delete=models.CASCADE, 
        related_name="appointments"
    )
    employee = models.ForeignKey(
        Employee,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="appointments"
    )
    
    customer_name = models.CharField(max_length=100)
    customer_email = models.EmailField(blank=True, null=True)
    start_time = models.DateTimeField()
    end_time = models.DateTimeField()

    STATUS_CHOICES = [
        ("pending", "Pending"),
        ("confirmed", "Confirmed"),
        ("cancelled", "Canceled"),
        ("rejected", "Rejected"),
    ]

    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default="pending"
    )
    confirmed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.customer_name} with {self.employee.user.username if self.employee else 'Unassigned'}"

    def overlaps(self):
        """Checks for schedule conflicts within the same business."""
        return Appointment.objects.filter(
            business=self.business,
            start_time__lt=self.end_time,
            end_time__gt=self.start_time
        ).exclude(id=self.id).exists()
    
    def confirm(self):
        self.status = "confirmed"
        self.confirmed_at = timezone.now()
        self.save(update_fields=["status", "confirmed_at"])

    def reject(self):
        self.status = "rejected"
        self.save(update_fields=["status"])