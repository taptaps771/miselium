from __future__ import annotations

import pytest

from app.hardware.contracts.models import GeoPosition, HardwareResult, HardwareStatus


def test_geo_position_accepts_valid_coordinates() -> None:
    position = GeoPosition(latitude=-7.3, longitude=108.2, accuracy_m=4.5)

    assert position.latitude == -7.3
    assert position.longitude == 108.2


@pytest.mark.parametrize(
    ("latitude", "longitude"),
    [(91, 0), (-91, 0), (0, 181), (0, -181)],
)
def test_geo_position_rejects_invalid_coordinates(latitude: float, longitude: float) -> None:
    with pytest.raises(ValueError):
        GeoPosition(latitude=latitude, longitude=longitude)


def test_hardware_result_success_flag() -> None:
    result = HardwareResult(status=HardwareStatus.AVAILABLE, data="ready")

    assert result.is_success is True


def test_geo_position_rejects_non_finite_coordinates() -> None:
    with pytest.raises(ValueError):
        GeoPosition(latitude=float("nan"), longitude=108.2)
