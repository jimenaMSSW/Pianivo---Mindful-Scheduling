from django.db import models
from django.utils import timezone
from django.contrib.auth.models import User


class Business(models.Model):
    name = models.CharField(max_length = 100) # stores business name customers see
    slug = models.SlugField(unique=True, null=True)
    subdomain = models.CharField(max_length = 50, unique = True) # unique subdomain
    email = models.EmailField(blank=True, null=True) # stores email
    timezone = models.CharField(max_length=50, default="UTC") #business timezone
    created_at = models.DateTimeField(auto_now_add = True) # timestamp column

    employees_can_manage_appointments = models.BooleanField(default=True) # The "Turn Off" switch
    
    def __str__(self):
        return self.name # makes it human readable
    
class BusinessEmployee(models.Model):
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
    color = models.CharField(max_length = 7, default = "#007bff")

    def __str__(self):
        return f"{self.user.username} – {self.business.name}"
    
class Booking(models.Model):
    name = models.CharField(max_length=255)
    date = models.DateField()
    business = models.ForeignKey(Business, on_delete=models.CASCADE, related_name="bookings")

    def __str__(self):
        return f"{self.name} ({self.date})"

class Appointment(models.Model):
    employee = models.ForeignKey(
        "BusinessEmployee",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="appointments"
    )
    business = models.ForeignKey(Business, on_delete=models.CASCADE) # links app to business, if business deleted app deleted
    
    customer_name = models.CharField(max_length = 100) # stores customer name
    customer_email = models.EmailField(blank=True, null=True) #stores email address
    start_time = models.DateTimeField() # stores appt start time
    end_time = models.DateTimeField() #stores when appointment ends

    STATUS_CHOICES = [
        ("pending", "Pending"),
        ("confirmed", "Confirmed"),
        ("cancelled", "Canceled"),
        ("rejected", "Rejected"),
    ]

    status = models.CharField(
        max_length = 20,
        choices = STATUS_CHOICES,
        default = "pending"
    )
    confirmed_at = models.DateTimeField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True) #records when booking was created

    def __str__(self):
        return f"{self.customer_name} @ {self.start_time}"

    #Checks for appointment overlap for the same business
    def overlaps(self):
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
