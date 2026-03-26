from django.urls import path

from .views import home

app_name = "Hadith_API"

urlpatterns = [
    path("", home, name="home"),
]
