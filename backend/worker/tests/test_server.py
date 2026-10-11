import io

import numpy as np
import pytest
from fastapi.testclient import TestClient
from PIL import Image

import server
from conftest import TORSO_A, TORSO_B, ramanujan

GOOD = {"Authorization": "Bearer good-token"}
FORM = {"height_cm": "170", "sex": "male"}


def jpeg() -> bytes:
    buffer = io.BytesIO()
    Image.new("RGB", (64, 128), "white").save(buffer, format="JPEG")
    return buffer.getvalue()


class FakeEstimator:
    """Stands in for SAM 3D Body so tests run on a laptop without a GPU."""

    def __init__(self, body, people: int = 1, error: Exception | None = None):
        vertices, faces, keypoints = body
        self.faces = faces
        self.people = [
            {"bbox": np.array([0, 0, 10 * (i + 1), 10 * (i + 1)]), "pred_vertices": vertices, "pred_keypoints_3d": keypoints}
            for i in range(people)
        ]
        self.error = error
        self.calls = 0

    def process_one_image(self, image):
        self.calls += 1
        if self.error:
            raise self.error
        return self.people


def make_client(estimator) -> TestClient:
    def verify(token: str) -> str | None:
        return "uid-1" if token == "good-token" else None

    return TestClient(server.create_app(estimator=estimator, verify_user=verify))


def scan(client: TestClient, headers=GOOD, data=FORM, photo: bytes | None = None):
    return client.post("/scan", headers=headers, data=data, files={"photo": ("p.jpg", photo or jpeg(), "image/jpeg")})


def test_returns_estimated_biometrics(body):
    response = scan(make_client(FakeEstimator(body)))
    assert response.status_code == 200
    result = response.json()
    assert result["method"] == "sam3d"
    assert result["confidence"] == "low"
    assert result["waist_cm"] == pytest.approx(ramanujan(TORSO_A * 100, TORSO_B * 100), abs=0.5)
    assert 5 < result["body_fat_pct"] < 40
    assert result["body_fat_method"] == "navy"
    assert result["user_edited_fields"] == []
    assert result["measured_at"].endswith("Z")


def test_rejects_requests_without_a_valid_firebase_token(body):
    estimator = FakeEstimator(body)
    client = make_client(estimator)
    assert scan(client, headers={}).status_code == 401
    assert scan(client, headers={"Authorization": "Bearer stolen"}).status_code == 401
    assert estimator.calls == 0


def test_model_failure_tells_the_app_to_fall_back(body):
    response = scan(make_client(FakeEstimator(body, error=RuntimeError("CUDA out of memory"))))
    assert response.status_code == 503
    assert response.json()["fallback"] == "on_device"


def test_no_person_in_photo_is_a_client_error(body):
    response = scan(make_client(FakeEstimator(body, people=0)))
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "no_person"


def test_rejects_impossible_height_and_non_images(body):
    client = make_client(FakeEstimator(body))
    assert scan(client, data={"height_cm": "20", "sex": "male"}).status_code == 422
    assert scan(client, photo=b"not an image").status_code == 422


def test_health_check_needs_no_token(body):
    assert make_client(FakeEstimator(body)).get("/health").json() == {"ok": True}
