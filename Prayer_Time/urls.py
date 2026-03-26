from django.urls import path

from .views import prayer_times, qibla

app_name = "Prayer_Time"

urlpatterns = [
    path("", prayer_times, name="home"),
    path("qibla/", qibla, name="qibla"),
]
