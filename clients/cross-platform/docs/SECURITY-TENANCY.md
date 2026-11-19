# Security and tenant isolation baseline

- Never commit `.env`, database dumps, signing keys, Firebase service accounts, or JWT secrets.
- Use HTTPS for every non-local API endpoint.
- Keep JWT access tokens short-lived and never log tokens or push tokens.
- Re-check membership and active status on each authenticated request.
- Scope tenant-owned database access to the active tenant; test cross-tenant IDOR attempts.
- Do not store biometric templates. Delegate authentication to the operating system.
- Treat Android content URIs as opaque references, not local paths.
- Use a secret manager and least-privilege service accounts in production.
- Apply database migrations explicitly; application startup does not mutate a production schema.
- Configure API rate limits at the gateway/reverse proxy before exposing registration/login/invitation endpoints publicly.
