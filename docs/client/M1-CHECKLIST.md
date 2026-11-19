# M1 validation checklist

- [ ] Python 3.14 virtual environment is active.
- [ ] Install `requirements/desktop.txt` and `requirements-dev.txt`.
- [ ] Copy `.env.example` to `.env` when local overrides are needed.
- [ ] Run `python main.py` and confirm the foundation dashboard opens.
- [ ] Confirm the environment, API setting, lifecycle state, and log file are shown.
- [ ] Click **Keluar** and confirm normal shutdown.
- [ ] Run `pytest -q`.
- [ ] Run `ruff check .`.
- [ ] Confirm `application.log` is created in the user log directory.

M1 does not yet test real camera, GPS, Bluetooth, NFC, biometric, push notification, or Android packaging.
