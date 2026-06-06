from django.urls import path

from imageops import views

urlpatterns = [
    path("", views.index, name="index"),
    path("health", views.health, name="health"),
    path("get/resolution", views.get_resolution, name="get_resolution"),
    path("convert/grayscale", views.convert_grayscale, name="convert_grayscale"),
]
