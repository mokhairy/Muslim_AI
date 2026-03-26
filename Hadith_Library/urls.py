from django.urls import path

from .views import home

app_name = "Hadith_Library"

urlpatterns = [
    path("", home, name="home"),
]
