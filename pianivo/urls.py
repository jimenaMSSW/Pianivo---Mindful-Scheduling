from django.contrib import admin
from django.urls import path, include
from core.views.views import (
    book_appointment, 
    confirm_appointment, 
    reject_appointment, 
    whoami,
    employee_dashboard,  # This is the correct function name
    employee_add_appointment,
    employee_delete_appointment,
    root_redirect
)
from django.conf import settings
from django.conf.urls.static import static
from core.views import views

urlpatterns = [
    path('', root_redirect, name='root_home'),
    path('admin/', admin.site.urls),

    # Owner dashboard
    path("owner/", include("core.urls.owner", namespace="owner")),
    path('owner/', views.root_redirect),

    # Employee Dashboard - Corrected function name here
    path('employee/', employee_dashboard, name='employee_dashboard'),
    
    # Employee management paths
    path('employee/appointments/add/', employee_add_appointment, name='employee_add_appointment'),
    path('employee/appointments/<int:appointment_id>/delete/', employee_delete_appointment, name='employee_delete_appointment'),
    
    # Public & Debug views
    path('whoami/', whoami, name='whoami'),
    path("book/", book_appointment, name='book'),

    # Global confirm/reject logic
    path("appointments/<int:appointment_id>/confirm/", confirm_appointment, name='confirm_appointment'),
    path("appointments/<int:appointment_id>/reject/", reject_appointment, name='reject_appointment'),
    
    # Auth system
    path('accounts/', include('django.contrib.auth.urls')),
]

if settings.DEBUG:
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)