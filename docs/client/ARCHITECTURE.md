# Miselium application architecture (M0–M8)

## Runtime layers

```text
QML presentation
      │ Qt signals / slots / context properties
      ▼
Application controllers and use cases
      ├── HardwareAccessService
      │      ├── CapabilityRegistry ── Qt / Android native adapters
      │      └── PermissionManager ── platform permission providers
      ├── API client / synchronization
      └── local application services
             │ HTTPS / WebSocket (future realtime channel)
             ▼
       FastAPI backend (separate process)
             │ authenticated principal + active tenant
             ▼
       SQLAlchemy / PostgreSQL / Alembic
```

## Boundaries

- QML owns presentation and user interaction only.
- `application/` exposes narrow Qt-facing controllers and orchestrates use cases.
- `core/` contains reusable infrastructure and does not import QML or native hardware SDKs.
- `hardware/contracts/` is platform-neutral and has no PySide6/native SDK imports.
- `hardware/adapters/` translates platform APIs into shared contracts. Missing native bridges fail closed with `unsupported`.
- `hardware/services/` coordinates capability and permission preflight.
- Production bootstrap does not register simulated hardware as real hardware.
- Android background work must use platform-approved native services; Python timers are not substitutes.
- The FastAPI service is a separate deployment target.
- Every tenant-owned backend resource is scoped to the authenticated membership's tenant.

## Platform capability semantics

`available` means a concrete adapter has verified the operation/device. `not_checked` means a module or bridge is present but physical hardware, runtime permissions, or operational readiness have not been verified. `unsupported` means no adapter/bridge is available. Permission state `unknown` is never treated as granted.

## Multi-tenant identity

A user is global and may belong to several workspaces through `Membership`. A short-lived signed token selects one active tenant. Each request reloads the user, tenant, and membership; tenant-owned queries include the active `tenant_id`. Role claims in the JWT are informational and are not used as the authorization source. See `docs/M7-SAAS-BACKEND.md`.

## Production boundary

The repository includes the SaaS data model and core API, but does not yet include production email delivery, FCM delivery, billing webhooks, refresh-token rotation, database RLS, or a production observability stack. Android native feature bridges and physical-device release QA remain external release gates.
