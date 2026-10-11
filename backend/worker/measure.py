"""Body circumferences from a SAM 3D Body mesh.

Every number here is an estimate. SAM 3D Body publishes no circumference accuracy, so the
level fractions below are starting guesses to tune against a tape measure (the bake-off).
"""

from __future__ import annotations

from collections.abc import Callable, Sequence
from dataclasses import dataclass

import numpy as np
import trimesh
from shapely.geometry import MultiPoint, Point

# MHR70 keypoint indices, from sam_3d_body/metadata/mhr70.py.
NOSE = 0
LEFT_SHOULDER, RIGHT_SHOULDER = 5, 6
LEFT_HIP, RIGHT_HIP = 9, 10
LEFT_HEEL, RIGHT_HEEL = 17, 20
NECK = 69

# Torso positions as fractions from the shoulder line (0) down to the hip joints (1).
CHEST_BAND = (0.15, 0.40)  # take the fullest girth
WAIST_BAND = (0.45, 0.85)  # take the narrowest girth
HIPS_BAND = (0.90, 1.30)  # take the fullest girth; the buttocks sit below the hip joints
# The Navy neck tape sits just below the larynx: this far from the neck joint toward the nose.
NECK_RAISE = 0.25
BAND_SAMPLES = 9


@dataclass(frozen=True)
class Circumferences:
    neck_cm: float | None
    chest_cm: float | None
    waist_cm: float | None
    hips_cm: float | None


def measure(vertices: np.ndarray, faces: np.ndarray, keypoints: np.ndarray, height_cm: float) -> Circumferences:
    """Circumferences in cm, after standing the body upright and scaling it to the user's height."""
    verts, kps = _stand_upright(np.asarray(vertices, dtype=float), np.asarray(keypoints, dtype=float))
    top = verts[:, 2].max()
    if top <= 0:
        raise ValueError("mesh has no height")
    # The model's own scale is unreliable from one photo; the user's real height is not.
    scale = height_cm / top
    verts, kps = verts * scale, kps * scale
    mesh = trimesh.Trimesh(verts, np.asarray(faces), process=False)

    shoulders = (kps[LEFT_SHOULDER] + kps[RIGHT_SHOULDER]) / 2
    hips = (kps[LEFT_HIP] + kps[RIGHT_HIP]) / 2
    torso_center = (shoulders[:2] + hips[:2]) / 2

    def torso_level(fraction: float) -> float:
        return shoulders[2] + fraction * (hips[2] - shoulders[2])

    def band(limits: Sequence[float], pick: Callable[[list[float]], float]) -> float | None:
        girths = [torso_girth(mesh, torso_level(f), torso_center) for f in np.linspace(*limits, BAND_SAMPLES)]
        found = [g for g in girths if g is not None]
        return pick(found) if found else None

    neck_level = kps[NECK][2] + NECK_RAISE * (kps[NOSE][2] - kps[NECK][2])
    return Circumferences(
        neck_cm=torso_girth(mesh, neck_level, kps[NECK][:2]),
        chest_cm=band(CHEST_BAND, max),
        waist_cm=band(WAIST_BAND, min),
        hips_cm=band(HIPS_BAND, max),
    )


def torso_girth(mesh: trimesh.Trimesh, z: float, center_xy: np.ndarray) -> float | None:
    """Tape-measure length around the body at height z, or None if the plane misses it.

    Picks the cross-section loop around center_xy so arms beside the body are ignored, and
    uses its convex outline because a tape bridges hollows instead of following them.
    """
    section = mesh.section(plane_origin=[0.0, 0.0, z], plane_normal=[0.0, 0.0, 1.0])
    if section is None:
        return None
    hulls = [MultiPoint(loop[:, :2]).convex_hull for loop in section.discrete if len(loop) >= 3]
    if not hulls:
        return None
    center = Point(center_xy)
    body = min(hulls, key=lambda hull: (hull.distance(center), -hull.area))
    return float(body.length)


def _stand_upright(verts: np.ndarray, kps: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Rotates so feet-to-head is +z and the soles sit at z = 0, whatever axes the model used."""
    up = kps[NOSE] - (kps[LEFT_HEEL] + kps[RIGHT_HEEL]) / 2
    length = np.linalg.norm(up)
    if length < 1e-9:
        raise ValueError("pose has no feet-to-head direction")
    rotation = trimesh.geometry.align_vectors(up / length, [0.0, 0.0, 1.0])
    verts = trimesh.transform_points(verts, rotation)
    kps = trimesh.transform_points(kps, rotation)
    floor = np.array([0.0, 0.0, verts[:, 2].min()])
    return verts - floor, kps - floor
