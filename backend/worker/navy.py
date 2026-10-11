"""US Navy body-fat estimate (Hodgdon & Beckett, 1984).

Inputs are cm; the formula itself works in inches. The result is an estimate, not a
clinical measurement.
"""

from __future__ import annotations

from math import log10
from typing import Literal

CM_PER_INCH = 2.54
# Outside this range the inputs are almost certainly a bad scan, not a real body.
PLAUSIBLE_PCT = (2.0, 70.0)

Sex = Literal["male", "female"]


def body_fat(
    sex: Sex,
    height_cm: float | None,
    neck_cm: float | None,
    waist_cm: float | None,
    hips_cm: float | None,
) -> float | None:
    """Body-fat percentage to one decimal, or None when inputs are missing or impossible."""
    if height_cm is None or neck_cm is None or waist_cm is None:
        return None
    height, neck, waist = (value / CM_PER_INCH for value in (height_cm, neck_cm, waist_cm))

    if sex == "male":
        if waist <= neck:
            return None
        pct = 86.010 * log10(waist - neck) - 70.041 * log10(height) + 36.76
    else:
        if hips_cm is None:
            return None
        hips = hips_cm / CM_PER_INCH
        if waist + hips <= neck:
            return None
        pct = 163.205 * log10(waist + hips - neck) - 97.684 * log10(height) - 78.387

    low, high = PLAUSIBLE_PCT
    return round(pct, 1) if low <= pct <= high else None
