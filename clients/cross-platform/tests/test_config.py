"""Tests for typed application settings."""

from app.config import AppSettings


def test_default_settings_are_safe() -> None:
    settings = AppSettings(_env_file=None)
    assert settings.environment == "development"
    assert settings.log_level == "INFO"
    assert settings.api_base_url is None
    assert not settings.is_production


def test_settings_read_environment(monkeypatch) -> None:
    monkeypatch.setenv("APP_ENVIRONMENT", "testing")
    monkeypatch.setenv("APP_LOG_LEVEL", "DEBUG")
    settings = AppSettings(_env_file=None)
    assert settings.environment == "testing"
    assert settings.log_level == "DEBUG"
