"""Pure image helpers used by the view layer."""
import base64
import binascii
import re
from io import BytesIO
from typing import Tuple

from PIL import Image, UnidentifiedImageError

DATA_URL_RE = re.compile(r"^data:image/[a-zA-Z0-9.+-]+;base64,(.+)$")


class ImageDecodeError(ValueError):
    """Raised when an incoming payload cannot be decoded as an image."""


def decode_image_payload(payload: str) -> Image.Image:
    """Decode a base64 string (raw or data-URL) into a PIL image."""
    if not payload or not isinstance(payload, str):
        raise ImageDecodeError("Payload is empty or not a string.")
    match = DATA_URL_RE.match(payload.strip())
    b64 = match.group(1) if match else payload.strip()
    try:
        raw = base64.b64decode(b64, validate=True)
    except (binascii.Error, ValueError) as exc:
        raise ImageDecodeError(f"Invalid base64 payload: {exc}") from exc
    try:
        return Image.open(BytesIO(raw))
    except UnidentifiedImageError as exc:
        raise ImageDecodeError("Could not identify image format.") from exc


def get_resolution(image: Image.Image) -> Tuple[int, int]:
    """Return (width, height) of an image."""
    return image.size


def to_grayscale_png_b64(image: Image.Image) -> str:
    """Convert image to grayscale and return a base64-encoded PNG data URL."""
    gray = image.convert("L")
    buf = BytesIO()
    gray.save(buf, format="PNG")
    encoded = base64.b64encode(buf.getvalue()).decode("ascii")
    return f"data:image/png;base64,{encoded}"
