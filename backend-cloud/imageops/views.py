"""HTTP endpoints exposed by Backend Server 2."""
import json
import logging

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_GET, require_POST

from .image_utils import (
    ImageDecodeError,
    decode_image_payload,
    get_resolution as get_resolution_size,
    to_grayscale_png_b64,
)

logger = logging.getLogger(__name__)

VERSION = "1.1.0"


@require_GET
def index(request):
    return JsonResponse({
        "service": "backend-server-2",
        "version": VERSION,
        "endpoints": ["/get/resolution", "/convert/grayscale", "/health"],
    })


@require_GET
def health(request):
    return JsonResponse({"status": "ok", "version": VERSION})


def _parse_image_from_request(request):
    try:
        body = json.loads(request.body.decode("utf-8") or "{}")
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ImageDecodeError(f"Invalid JSON body: {exc}") from exc
    payload = body.get("image") or body.get("image_b64") or ""
    return decode_image_payload(payload)


@csrf_exempt
@require_POST
def get_resolution(request):
    """Return the width and height of the image supplied in the JSON body."""
    try:
        image = _parse_image_from_request(request)
    except ImageDecodeError as exc:
        logger.warning("get_resolution decode error: %s", exc)
        return JsonResponse({"error": str(exc)}, status=400)
    width, height = get_resolution_size(image)
    logger.info("get_resolution served %sx%s", width, height)
    return JsonResponse({
        "width": width,
        "height": height,
        "resolution": f"{width}x{height}",
    })


@csrf_exempt
@require_POST
def convert_grayscale(request):
    """Convert the supplied image to grayscale and return it as base64 PNG."""
    try:
        image = _parse_image_from_request(request)
    except ImageDecodeError as exc:
        logger.warning("convert_grayscale decode error: %s", exc)
        return JsonResponse({"error": str(exc)}, status=400)
    try:
        encoded = to_grayscale_png_b64(image)
    except Exception as exc:
        logger.exception("convert_grayscale failed")
        return JsonResponse({"error": f"{type(exc).__name__}: {exc}"}, status=500)
    width, height = image.size
    logger.info("convert_grayscale served %sx%s", width, height)
    return JsonResponse({
        "image": encoded,
        "width": width,
        "height": height,
    })
