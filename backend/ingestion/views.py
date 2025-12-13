from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
import json

from .event_ingestor import ingest_event

@csrf_exempt
def receive_event(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST only"}, status=405)

    try:
        payload = json.loads(request.body.decode("utf-8"))
        ingest_event(payload)
        return JsonResponse({"status": "ok"})
    except Exception as e:
        return JsonResponse({"error": str(e)}, status=500)
