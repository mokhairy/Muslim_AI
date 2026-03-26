from django.urls import path

from .views import home

app_name = "Tafsir"

urlpatterns = [
    path("", home, name="home"),
]
