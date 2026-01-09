from django.contrib import admin
from django.urls import path, include
from core.views.views import whoami, book_appointment, confirm_appointment, reject_appointment
from core.views import employee as employee_view
from core.views import owner as owner_views

urlpatterns = [
    path('admin/', admin.site.urls),

    # Owner dashboard + appointment management
    path("owner/", include("core.urls.owner", namespace="owner")),

    # Employee Dashboard (FIXED: changed core_views to employee_view)
    path('my-schedule/', employee_view.employee_dashboard, name='employee_dashboard'),
    
    # NEW: Employee management paths (so they can add/delete as requested)
    path('employee/appointments/add/', employee_view.employee_add_appointment, name='employee_add_appointment'),
    path('employee/appointments/<int:appointment_id>/delete/', employee_view.employee_delete_appointment, name='employee_delete_appointment'),
    
    # Public views
    path('whoami/', whoami),
    path("book/", book_appointment, name='book'),

    # Global confirm/reject if needed
    path("appointments/<int:appointment_id>/confirm/", confirm_appointment),
    path("appointments/<int:appointment_id>/reject/", reject_appointment),
]