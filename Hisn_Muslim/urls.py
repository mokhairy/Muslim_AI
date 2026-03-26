from django.urls import path

from .views import home

app_name = "Hisn_Muslim"

urlpatterns = [
    path("", home, name="home"),
]
