from django.db import models
from django.utils import timezone
from django.contrib.auth.models import User
from django.conf import settings
from django.db.models.signals import post_save
from django.dispatch import receiver

class Business(models.Model):
    owner = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="owned_businesses"
    )
    name = models.CharField(max_length=100)
    slug = models.SlugField(unique=True, null=True)
    subdomain = models.CharField(max_length=50, unique=True)
    email = models.EmailField(blank=True, null=True)
    timezone = models.CharField(max_length=50, default="UTC")
    created_at = models.DateTimeField(auto_now_add=True)
    employees_can_manage_appointments = models.BooleanField(default=True)

    class Meta:
        verbose_name_plural = "Businesses"

    def __str__(self):
        return self.name

class Employee(models.Model):
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
        ("cancelled", "Cancelled"),
        ("rejected", "Rejected"),
    ]
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="pending")
    confirmed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        emp_name = self.employee.user.username if self.employee and self.employee.user else 'Unassigned'
        return f"{self.customer_name} with {emp_name}"

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

class PaymentAccount(models.Model):
    business = models.OneToOneField(
        Business,
        on_delete=models.CASCADE,
        related_name="payment_account"
    )
    stripe_account_id = models.CharField(max_length=255, blank=True)
    charges_enabled = models.BooleanField(default=False)
    payouts_enabled = models.BooleanField(default=False)
    details_submitted = models.BooleanField(default=False)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Payments for {self.business.name}"

class Payment(models.Model):
    STATUS_CHOICES = [
        ("created", "Created"),
        ("requires_payment_method", "Requires payment method"),
        ("requires_confirmation", "Requires confirmation"),
        ("requires_action", "Requires action"),
        ("processing", "Processing"),
        ("succeeded", "Succeeded"),
        ("canceled", "Canceled"),
        ("failed", "Failed"),
    ]
    METHOD_CHOICES = [
        ("card", "Card"),
        ("klarna", "Klarna"),
        ("unknown", "Unknown"),
    ]

    business = models.ForeignKey(
        Business,
        on_delete=models.CASCADE,
        related_name="payments"
    )
    appointment = models.ForeignKey(
        Appointment,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="payments"
    )
    customer_name = models.CharField(max_length=100)
    customer_email = models.EmailField(blank=True, null=True)
    amount = models.PositiveIntegerField(help_text="Smallest currency unit, such as cents.")
    currency = models.CharField(max_length=3, default="usd")
    status = models.CharField(max_length=30, choices=STATUS_CHOICES, default="created")
    payment_method = models.CharField(max_length=30, choices=METHOD_CHOICES, default="unknown")
    stripe_payment_intent_id = models.CharField(max_length=255, unique=True)
    stripe_latest_charge_id = models.CharField(max_length=255, blank=True)
    last_error = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.customer_name} {self.amount} {self.currency.upper()} ({self.status})"

# ==========================
# Messaging Models
# ==========================
class Conversation(models.Model):
    appointment = models.OneToOneField(
        Appointment,
        on_delete=models.CASCADE,
        related_name="conversation"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Conversation for {self.appointment}"

class Message(models.Model):
    conversation = models.ForeignKey(
        Conversation,
        on_delete=models.CASCADE,
        related_name="messages"
    )
    sender = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    content = models.TextField()
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['timestamp']

    def __str__(self):
        return f"{self.sender} - {self.content[:20]}"

# ==========================
# Auto Create Conversation
# ==========================
@receiver(post_save, sender=Appointment)
def create_conversation_for_appointment(sender, instance, created, **kwargs):
    if created:
        Conversation.objects.get_or_create(appointment=instance)
