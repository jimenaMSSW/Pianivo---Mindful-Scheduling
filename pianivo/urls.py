from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from django.shortcuts import redirect

from core.views.views import book_appointment, whoami, root_redirect
from core.views.employee import (
    employee_dashboard,
    employee_add_appointment,
    employee_delete_appointment
)
from core.views import views  # Messaging API

# --- URL patterns ---
urlpatterns = [
    # Root redirect
    path('', root_redirect, name='root_home'),

    # Admin
    path('admin/', admin.site.urls),

    # Owner dashboard URLs (with namespace)
    path('owner/', include('core.urls.owner', namespace='owner')),

    # Employee dashboard
    path('employee/', employee_dashboard, name='employee_dashboard'),
    path('employee/appointments/add/', employee_add_appointment, name='employee_add_appointment'),
    path('employee/appointments/<int:appointment_id>/delete/', employee_delete_appointment, name='employee_delete_appointment'),

    # Public & debug views
    path('whoami/', whoami, name='whoami'),
    path('book/', book_appointment, name='book'),

    # Messaging API
    path('api/messages/', views.api_get_messages, name='api_get_messages'),
    path('api/messages/send/', views.api_send_message, name='api_send_message'),

    # Authentication
    path('accounts/', include('django.contrib.auth.urls')),
]

# Serve static files in debug mode
if settings.DEBUG:
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
