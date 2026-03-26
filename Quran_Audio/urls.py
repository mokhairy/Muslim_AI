from django.urls import path

from .views import home

app_name = "Quran_Audio"

urlpatterns = [
    path("", home, name="home"),
]
