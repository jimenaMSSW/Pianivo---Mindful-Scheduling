from django.urls import path
from core.views.owner import dashboard, confirm_appointment, reject_appointment, reschedule_appointment, update_appointment, add_appointment
from core.views import owner as views

app_name = "owner"

urlpatterns = [
    path("", dashboard, name="dashboard"),
    path("appointments/<int:appointment_id>/confirm/", confirm_appointment, name="confirm_appointment"),
    path("appointments/<int:appointment_id>/reject/", reject_appointment, name="reject_appointment"),
    path("appointments/<int:appointment_id>/reschedule/", reschedule_appointment, name="reschedule_appointment"),
    path("appointments/<int:appointment_id>/update/", update_appointment, name="update_appointment"),
    path("appointments/add/", add_appointment, name="add_appointment"),
    path("settings/toggle-permissions/", views.toggle_permissions, name="toggle_permissions"),
]
