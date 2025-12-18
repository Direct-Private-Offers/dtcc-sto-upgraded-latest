from django.urls import path
from backend.ingestion.views import receive_event

urlpatterns = [
    path("ingest/", receive_event),
]
