from django.urls import path
from core.views import views  # Ensure this points to the file where we put the code

app_name = "owner"

urlpatterns = [
    # Dashboard and Permissions
    path('dashboard/', views.owner_dashboard, name='owner_dashboard'),
    path('toggle-permissions/', views.toggle_permissions, name='toggle_permissions'),

    # Appointment Actions
    path('appointments/add/', views.add_appointment, name='add_appointment'),
    path('appointments/<int:appointment_id>/confirm/', views.confirm_appointment, name='confirm_appointment'),
    path('appointments/<int:appointment_id>/reject/', views.reject_appointment, name='reject_appointment'),
    path('appointments/<int:appointment_id>/reschedule/', views.reschedule_appointment, name='reschedule_appointment'),
    path('appointments/<int:appointment_id>/delete/', views.owner_delete_appointment, name='owner_delete_appointment'),

    # Chat API Endpoints
    path('api/appointments/<int:appointment_id>/get_or_create_conversation/', 
         views.get_or_create_conversation, 
         name='get_or_create_conversation'),
    
    # Message API Endpoints (within the owner namespace)
    path('api/messages/', views.api_get_messages, name='api_get_messages'),
    path('api/messages/send/', views.api_send_message, name='api_send_message'),
]