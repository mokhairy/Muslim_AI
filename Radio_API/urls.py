from django.urls import path

from .views import home

app_name = "Radio_API"

urlpatterns = [
    path("", home, name="home"),
]
