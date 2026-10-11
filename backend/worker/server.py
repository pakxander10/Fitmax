"""SAM 3D Body scan worker: one full-body photo in, estimated body measurements out.

Body photos are sensitive (CLAUDE.md rule 7). They stay in memory, are never logged or
written to disk, and are dropped when the request ends; so is the mesh. Run with
`uvicorn server:app` from this folder (see colab_setup.ipynb).
"""

from __future__ import annotations

import asyncio
import io
import logging
import os
import sys
from collections.abc import Callable
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from typing import Any, Literal, Protocol

import numpy as np
from fastapi import FastAPI, File, Form, Header, UploadFile
from fastapi.responses import JSONResponse
from PIL import Image, ImageOps, UnidentifiedImageError
from pillow_heif import register_heif_opener

from measure import Circumferences, measure
from navy import body_fat

register_heif_opener()  # iPhones send HEIC, which OpenCV inside SAM 3D Body cannot read.

log = logging.getLogger("scan-worker")

MAX_PHOTO_BYTES = 15 * 1024 * 1024
MAX_SIDE_PX = 1024
SCAN_TIMEOUT_S = 80  # Cloudflare quick tunnels cut requests at about 100 s.
MIN_HEIGHT_CM, MAX_HEIGHT_CM = 100.0, 250.0
MIN_WEIGHT_KG, MAX_WEIGHT_KG = 25.0, 350.0
FIREBASE_PROJECT_ID = os.environ.get("FIREBASE_PROJECT_ID", "fitmax-be935")


class Estimator(Protocol):
    faces: Any

    def process_one_image(self, image: np.ndarray) -> list[dict[str, Any]]: ...


TokenVerifier = Callable[[str], "str | None"]


def create_app(estimator: Estimator | None = None, verify_user: TokenVerifier | None = None) -> FastAPI:
    verify = verify_user or verify_firebase_token

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        if app.state.estimator is None:
            app.state.estimator = load_estimator()
        yield

    app = FastAPI(title="FitQuest scan worker", lifespan=lifespan)
    app.state.estimator = estimator

    @app.get("/health")
    def health() -> dict[str, bool]:
        return {"ok": True}

    @app.post("/scan")
    async def scan(
        photo: UploadFile = File(...),
        height_cm: float = Form(..., ge=MIN_HEIGHT_CM, le=MAX_HEIGHT_CM),
        sex: Literal["male", "female"] = Form(...),
        weight_kg: float | None = Form(None, ge=MIN_WEIGHT_KG, le=MAX_WEIGHT_KG),
        authorization: str | None = Header(None),
    ) -> JSONResponse:
        if verify(_bearer_token(authorization)) is None:
            return _error(401, "unauthorized", "Sign in again and retry.")

        data = await photo.read(MAX_PHOTO_BYTES + 1)
        if len(data) > MAX_PHOTO_BYTES:
            return _error(413, "photo_too_large", "Photo must be under 15 MB.")
        try:
            image = _decode(data)
        except (UnidentifiedImageError, OSError):
            return _error(422, "bad_photo", "Send a JPEG or HEIC photo.")

        model = app.state.estimator
        try:
            people = await asyncio.wait_for(asyncio.to_thread(model.process_one_image, image), SCAN_TIMEOUT_S)
        except Exception:
            log.exception("SAM 3D Body inference failed")  # traceback only, never the photo
            return _fallback()
        if not people:
            return _error(422, "no_person", "No person found. Stand fully in frame and try again.")

        person = max(people, key=_bbox_area)  # the closest person if several are in frame
        try:
            girths = measure(
                _numpy(person["pred_vertices"]),
                _numpy(model.faces),
                _numpy(person["pred_keypoints_3d"]),
                height_cm,
            )
        except Exception:
            log.exception("Measuring the mesh failed")
            return _fallback()
        return JSONResponse(_biometrics(girths, height_cm, weight_kg, sex))

    return app


def load_estimator() -> Estimator:
    """Builds SAM 3D Body from its cloned repo, which is not a pip package."""
    # Repo first on the path: its `notebook` package would otherwise lose to Jupyter's.
    sys.path.insert(0, os.environ.get("SAM3D_REPO", "/content/sam-3d-body"))
    from notebook.utils import setup_sam_3d_body

    return setup_sam_3d_body(
        hf_repo_id=os.environ.get("SAM3D_HF_REPO", "facebook/sam-3d-body-vith"),
        detector_name=os.environ.get("SAM3D_DETECTOR", "vitdet"),
        fov_name=os.environ.get("SAM3D_FOV", "moge2"),
    )


def verify_firebase_token(token: str) -> str | None:
    """User id from a Firebase ID token (anonymous users included), or None if it is not valid."""
    if not token:
        return None
    from google.auth.exceptions import GoogleAuthError
    from google.auth.transport import requests as google_requests
    from google.oauth2 import id_token

    try:
        claims = id_token.verify_firebase_token(token, google_requests.Request(), audience=FIREBASE_PROJECT_ID)
    except (ValueError, GoogleAuthError):
        return None
    if claims.get("iss") != f"https://securetoken.google.com/{FIREBASE_PROJECT_ID}":
        return None
    return claims.get("sub")


def _biometrics(girths: Circumferences, height_cm: float, weight_kg: float | None, sex: str) -> dict[str, Any]:
    def cm(value: float | None) -> float | None:
        return None if value is None else round(value, 1)

    return {
        "method": "sam3d",
        # No published circumference accuracy for SAM 3D Body; raise this after the bake-off.
        "confidence": "low",
        "height_cm": height_cm,
        "weight_kg": weight_kg,
        "sex": sex,
        "neck_cm": cm(girths.neck_cm),
        "chest_cm": cm(girths.chest_cm),
        "waist_cm": cm(girths.waist_cm),
        "hips_cm": cm(girths.hips_cm),
        "body_fat_pct": body_fat(sex, height_cm, girths.neck_cm, girths.waist_cm, girths.hips_cm),  # type: ignore[arg-type]
        "body_fat_method": "navy",
        "measured_at": datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
        "user_edited_fields": [],
    }


def _decode(data: bytes) -> np.ndarray:
    """RGB array, rotated upright from EXIF and shrunk so the long side is at most MAX_SIDE_PX."""
    with Image.open(io.BytesIO(data)) as raw:
        image = ImageOps.exif_transpose(raw).convert("RGB")
    image.thumbnail((MAX_SIDE_PX, MAX_SIDE_PX))
    return np.asarray(image)


def _bearer_token(header: str | None) -> str:
    if header and header.lower().startswith("bearer "):
        return header[len("bearer "):].strip()
    return ""


def _numpy(value: Any) -> np.ndarray:
    if hasattr(value, "detach"):  # torch tensor
        value = value.detach().cpu().numpy()
    return np.asarray(value)


def _bbox_area(person: dict[str, Any]) -> float:
    x1, y1, x2, y2 = _numpy(person.get("bbox", [0, 0, 0, 0]))[:4]
    return float((x2 - x1) * (y2 - y1))


def _error(status: int, code: str, message: str) -> JSONResponse:
    return JSONResponse({"error": {"code": code, "message": message}}, status_code=status)


def _fallback() -> JSONResponse:
    """The app's contract: 503 with fallback=on_device means 'use the on-device scan instead'."""
    return JSONResponse(
        {"fallback": "on_device", "error": {"code": "scan_unavailable", "message": "3D scan is unavailable right now."}},
        status_code=503,
    )


app = create_app()
