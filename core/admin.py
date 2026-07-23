from django.contrib import admin
from django.utils import timezone
from django.utils.html import format_html
from django.urls import path
from django.shortcuts import redirect, get_object_or_404
from .models import Appointment, Business, Employee

@admin.register(Appointment)
class AppointmentAdmin(admin.ModelAdmin):
    list_display = (
        "customer_name",
        "business",
        "start_time",
        "end_time",
        "status",
        "confirmed_at",
        "created_at",
        "actions_column",
    )

    list_filter = ("status", "business", "start_time", "created_at")
    search_fields = ("customer_name", "customer_email")
    ordering = ("-created_at",)
    readonly_fields = ("created_at", "confirmed_at")
    actions = ["confirm_selected_appointments", "reject_selected_appointments"]

    # Custom column for buttons
    def actions_column(self, obj):
        if obj.status == "pending":
            return format_html(
                '<a class="button" style="background-color: #28a745; color: white; padding: 2px 8px; border-radius: 3px; text-decoration:none;" href="{}">Confirm</a>&nbsp;'
                '<a class="button" style="background-color: #dc3545; color: white; padding: 2px 8px; border-radius: 3px; text-decoration:none;" href="{}">Reject</a>',
                f'confirm/{obj.id}/',
                f'reject/{obj.id}/'
            )
        return "-"
    actions_column.short_description = "Actions"

    # Custom URLs for button clicks
    def get_urls(self):
        urls = super().get_urls()
        custom_urls = [
            path('confirm/<int:appointment_id>/', self.admin_site.admin_view(self.confirm_appointment_button)),
            path('reject/<int:appointment_id>/', self.admin_site.admin_view(self.reject_appointment_button)),
        ]
        return custom_urls + urls

    # Button click handlers
    def confirm_appointment_button(self, request, appointment_id):
        appointment = get_object_or_404(Appointment, id=appointment_id)
        if appointment.status == "pending":
            appointment.status = "confirmed"
            appointment.confirmed_at = timezone.now()
            appointment.save(update_fields=["status", "confirmed_at"])
            self.message_user(request, f"Appointment '{appointment}' confirmed.")
        return redirect(request.META.get('HTTP_REFERER'))

    def reject_appointment_button(self, request, appointment_id):
        appointment = get_object_or_404(Appointment, id=appointment_id)
        if appointment.status == "pending":
            appointment.delete()
            self.message_user(request, f"Appointment '{appointment}' rejected and deleted.")
        return redirect(request.META.get('HTTP_REFERER'))

    # Dropdown actions
    def confirm_selected_appointments(self, request, queryset):
        updated = queryset.filter(status="pending").update(
            status="confirmed",
            confirmed_at=timezone.now()
        )
        self.message_user(request, f"{updated} appointment(s) confirmed.")
    confirm_selected_appointments.short_description = "✅ Confirm selected appointments"

    def reject_selected_appointments(self, request, queryset):
        deleted, _ = queryset.filter(status="pending").delete()
        self.message_user(request, f"{deleted} appointment(s) rejected and deleted.")
    reject_selected_appointments.short_description = "❌ Reject selected appointments"


@admin.register(Business)
class BusinessAdmin(admin.ModelAdmin):
    list_display = ("name",)
    search_fields = ("name",)


@admin.register(Employee)
class BusinessEmployeeAdmin(admin.ModelAdmin):
    list_display = ("user", "business")
    search_fields = ("user__username", "business__name")
