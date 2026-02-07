from django.urls import path
from core.views.owner import owner_dashboard, toggle_permissions, add_appointment

app_name = "owner"

urlpatterns = [
    path('dashboard/', owner_dashboard, name='owner_dashboard'),
    path('toggle-permissions/', toggle_permissions, name='toggle_permissions'),
    path('appointments/add/', add_appointment, name='add_appointment'),
    # ... other owner URLs
]
