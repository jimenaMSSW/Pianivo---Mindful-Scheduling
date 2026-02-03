from django.urls import path
from core.views import views  # Your dashboard logic

app_name = "owner"

urlpatterns = [
    # Main Dashboard
    path('dashboard/', views.owner_dashboard, name='owner_dashboard'),
    
    # Appointment actions
    path("appointments/<int:appointment_id>/confirm/", views.confirm_appointment, name="confirm_appointment"),
    path("appointments/<int:appointment_id>/reject/", views.reject_appointment, name="reject_appointment"),
    path("appointments/<int:appointment_id>/reschedule/", views.reschedule_appointment, name="reschedule_appointment"), 
    path("appointments/<int:appointment_id>/update/", views.update_appointment, name="update_appointment"),
    path("appointments/add/", views.add_appointment, name="add_appointment"),
    
    # Settings
    path("settings/toggle-permissions/", views.toggle_permissions, name="toggle_permissions"),
]
