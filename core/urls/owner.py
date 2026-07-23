from django.urls import path
from core.views import views 

app_name = "owner"

urlpatterns = [
    # --- DASHBOARD & SIDEBAR NAV ---
    # Primary dashboard view
    path('dashboard/', views.owner_dashboard, name='owner_dashboard'),
    
    # NEW: Filtered view for specific employee schedules
    path('employee/<int:employee_id>/schedule/', views.employee_schedule_view, name='employee_schedule'),
    
    # Restored placeholders to prevent 404s when clicking sidebar links
    path('employees/', views.owner_dashboard, name='manage_employees'), 
    path('settings/', views.owner_dashboard, name='business_settings'),
    
    path('toggle-permissions/', views.toggle_permissions, name='toggle_permissions'),

    # --- APPOINTMENT ACTIONS ---
    path('appointments/add/', views.add_appointment, name='add_appointment'),
    path('appointments/<int:appointment_id>/confirm/', views.confirm_appointment, name='confirm_appointment'),
    path('appointments/<int:appointment_id>/reject/', views.reject_appointment, name='reject_appointment'),
    path('appointments/<int:appointment_id>/reschedule/', views.reschedule_appointment, name='reschedule_appointment'),
    path('appointments/<int:appointment_id>/delete/', views.owner_delete_appointment, name='owner_delete_appointment'),

    # --- CHAT & API ---
    # This matches the fetch() call in your JavaScript for "smart chat"
    path('api/appointments/<int:appointment_id>/get_or_create_conversation/', 
         views.get_or_create_conversation, 
         name='get_or_create_conversation'),
    
    # Since these are in the "owner" namespace, 
    # the JS fetch calls in your HTML should be /owner/api/messages/
    path('api/messages/', views.api_get_messages, name='api_get_messages'),
    path('api/messages/send/', views.api_send_message, name='api_send_message'),
]