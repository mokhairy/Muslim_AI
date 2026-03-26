from django.urls import path

from .views import branding, home, ramadan_analysis, resources

app_name = "Islamic_Calender"

urlpatterns = [
    path("", home, name="home"),
    path("ramadan/", ramadan_analysis, name="ramadan_analysis"),
    path("branding/", branding, name="branding"),
    path("resources/", resources, name="resources"),
]
