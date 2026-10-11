import numpy as np
import pytest
import trimesh

from conftest import NECK_R, TORSO_A, TORSO_B, ramanujan
from measure import measure

HEIGHT_CM = 170.0
TORSO_CM = ramanujan(TORSO_A * 100, TORSO_B * 100)  # body is 1.7 m, so 170 cm scales metres to cm
NECK_CM = 2 * np.pi * NECK_R * 100


def test_measures_an_upright_body(body):
    result = measure(*body, height_cm=HEIGHT_CM)
    assert result.waist_cm == pytest.approx(TORSO_CM, rel=0.01)
    assert result.chest_cm == pytest.approx(TORSO_CM, rel=0.01)
    assert result.hips_cm == pytest.approx(TORSO_CM, rel=0.01)
    assert result.neck_cm == pytest.approx(NECK_CM, rel=0.01)


def test_scales_to_the_users_height(body):
    result = measure(*body, height_cm=HEIGHT_CM * 2)
    assert result.waist_cm == pytest.approx(TORSO_CM * 2, rel=0.01)


def test_any_orientation_gives_the_same_answer(body):
    # SAM 3D Body uses camera axes (y points down); the measurement must not care.
    vertices, faces, keypoints = body
    turn = trimesh.transformations.rotation_matrix(np.pi / 2, [1, 0, 0])
    turned = measure(trimesh.transform_points(vertices, turn), faces,
                     trimesh.transform_points(keypoints, turn), height_cm=HEIGHT_CM)
    assert turned.waist_cm == pytest.approx(TORSO_CM, rel=0.01)


def test_arms_beside_the_torso_are_ignored(body):
    vertices, faces, keypoints = body
    arm = trimesh.creation.cylinder(radius=0.04, height=0.6, sections=64)
    arm.apply_translation([0.3, 0, 1.1])
    merged = trimesh.util.concatenate([trimesh.Trimesh(vertices, faces, process=False), arm])
    result = measure(np.asarray(merged.vertices), np.asarray(merged.faces), keypoints, height_cm=HEIGHT_CM)
    assert result.chest_cm == pytest.approx(TORSO_CM, rel=0.01)


def test_degenerate_pose_is_rejected(body):
    vertices, faces, _ = body
    with pytest.raises(ValueError):
        measure(vertices, faces, np.zeros((70, 3)), height_cm=HEIGHT_CM)
