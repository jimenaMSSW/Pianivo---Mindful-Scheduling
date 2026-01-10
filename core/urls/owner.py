from django.urls import path
from core.views import views  # This is where all your dashboard logic lives

app_name = "owner"

urlpatterns = [
    # Main Dashboard
    path('dashboard/', views.owner_dashboard, name='owner_dashboard'),
    
    # --- YOUR ORIGINAL CONFIRM/REJECT PATHS ---
    path("appointments/<int:appointment_id>/confirm/", views.confirm_appointment, name="confirm_appointment"),
    path("appointments/<int:appointment_id>/reject/", views.reject_appointment, name="reject_appointment"),
    
    # --- RESCHEDULE & UPDATE PATHS ---
    # Make sure you have 'reschedule_appointment' and 'update_appointment' defined in views.py
    path("appointments/<int:appointment_id>/reschedule/", views.owner_dashboard, name="reschedule_appointment"), 
    path("appointments/<int:appointment_id>/update/", views.owner_dashboard, name="update_appointment"),
    
    # --- ADD & SETTINGS ---
    path("appointments/add/", views.owner_dashboard, name="add_appointment"),
    path("settings/toggle-permissions/", views.toggle_permissions, name="toggle_permissions"),
]