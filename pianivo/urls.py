from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

from core.views import views
from core.views import employee as employee_views

urlpatterns = [
    path('', views.root_redirect, name='root_home'),
    path('admin/', admin.site.urls),

    path('owner/', include('core.urls.owner', namespace='owner')),

    path('employee/', employee_views.employee_dashboard, name='employee_dashboard'),
    path('employee/appointments/add/', employee_views.employee_add_appointment, name='employee_add_appointment'),
    path('employee/appointments/<int:appointment_id>/confirm/', employee_views.employee_confirm_appointment, name='employee_confirm_appointment'),
    path('employee/appointments/<int:appointment_id>/reject/', employee_views.employee_reject_appointment, name='employee_reject_appointment'),
    path('employee/appointments/<int:appointment_id>/reschedule/', employee_views.employee_reschedule_appointment, name='employee_reschedule_appointment'),
    path('employee/appointments/<int:appointment_id>/delete/', employee_views.employee_delete_appointment, name='employee_delete_appointment'),

    path('whoami/', views.whoami, name='whoami'),
    path('firebase/health/', views.firebase_health, name='firebase_health'),
    path('book/', views.book_appointment, name='book'),
    path('payments/create-intent/', views.create_payment_intent, name='create_payment_intent'),
    path('payments/stripe/webhook/', views.stripe_webhook, name='stripe_webhook'),

    path('owner/api/messages/', views.api_get_messages, name='api_get_messages'),
    path('owner/api/messages/send/', views.api_send_message, name='api_send_message'),

    path('accounts/', include('django.contrib.auth.urls')),
    path('owner/employee/<int:employee_id>/schedule/', views.employee_schedule_view, name='employee_schedule_global'),
]

if settings.DEBUG:
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
