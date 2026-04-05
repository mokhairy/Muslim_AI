"""
URL configuration for Muslim_AI project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/6.0/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""

from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path

urlpatterns = [
    path("admin/", admin.site.urls),
    path("prayers/", include("Prayer_Time.urls")),
    path("quran/", include("Quran_Text.urls")),
    path("quran-audio/", include("Quran_Audio.urls")),
    path("tafsir/", include("Tafsir.urls")),
    path("hadith/", include("Hadith_API.urls")),
    path("hadith-library/", include("Hadith_Library.urls")),
    path("azkar/", include("Azkar_API.urls")),
    path("hisn-muslim/", include("Hisn_Muslim.urls")),
    path("radio/", include("Radio_API.urls")),
    path("", include("Islamic_Calender.urls")),
]

if settings.DEBUG:
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
