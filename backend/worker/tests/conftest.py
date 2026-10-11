import sys
from pathlib import Path

import numpy as np
import pytest
import trimesh

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from measure import LEFT_HEEL, LEFT_HIP, LEFT_SHOULDER, NECK, NOSE, RIGHT_HEEL, RIGHT_HIP, RIGHT_SHOULDER  # noqa: E402

TORSO_A, TORSO_B = 0.15, 0.10  # elliptical torso semi-axes, metres
NECK_R = 0.06
BODY_TOP = 1.7


def ramanujan(a: float, b: float) -> float:
    return float(np.pi * (3 * (a + b) - np.sqrt((3 * a + b) * (a + 3 * b))))


@pytest.fixture
def body():
    """A 1.7 m stand-in body: elliptical torso up to 1.45 m, narrow neck above, z up."""
    torso = trimesh.creation.cylinder(radius=1.0, height=1.45, sections=256)
    torso.apply_scale([TORSO_A, TORSO_B, 1.0])
    torso.apply_translation([0, 0, 1.45 / 2])
    neck = trimesh.creation.cylinder(radius=NECK_R, height=BODY_TOP - 1.45, sections=256)
    neck.apply_translation([0, 0, 1.45 + (BODY_TOP - 1.45) / 2])
    mesh = trimesh.util.concatenate([torso, neck])

    keypoints = np.zeros((70, 3))
    keypoints[NOSE] = [0, 0, 1.6]
    keypoints[NECK] = [0, 0, 1.5]
    keypoints[LEFT_SHOULDER], keypoints[RIGHT_SHOULDER] = [0.15, 0, 1.4], [-0.15, 0, 1.4]
    keypoints[LEFT_HIP], keypoints[RIGHT_HIP] = [0.1, 0, 0.9], [-0.1, 0, 0.9]
    keypoints[LEFT_HEEL], keypoints[RIGHT_HEEL] = [0.1, 0, 0], [-0.1, 0, 0]
    return np.asarray(mesh.vertices), np.asarray(mesh.faces), keypoints
