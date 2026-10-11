import pytest

from navy import body_fat


def test_male_known_values():
    # 70 in tall, 15 in neck, 34 in waist -> 17.5 % with the inch-based Navy formula.
    assert body_fat("male", height_cm=177.8, neck_cm=38.1, waist_cm=86.36, hips_cm=None) == pytest.approx(17.5, abs=0.1)


def test_female_known_values():
    # 65 in tall, 13 in neck, 30 in waist, 40 in hips -> 31.1 %.
    assert body_fat("female", height_cm=165.1, neck_cm=33.02, waist_cm=76.2, hips_cm=101.6) == pytest.approx(31.1, abs=0.1)


def test_female_without_hips_is_unknown():
    assert body_fat("female", height_cm=165.1, neck_cm=33.02, waist_cm=76.2, hips_cm=None) is None


def test_missing_or_impossible_inputs_are_unknown():
    assert body_fat("male", height_cm=177.8, neck_cm=None, waist_cm=86.36, hips_cm=None) is None
    assert body_fat("male", height_cm=177.8, neck_cm=90.0, waist_cm=86.36, hips_cm=None) is None
