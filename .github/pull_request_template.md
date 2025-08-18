## Summary
<!-- 1–2 sentences: what & why. -->

## Checklist
- [ ] CI green
- [ ] Tests pass/updated (unit/integration)
- [ ] No secrets in diff (gitleaks clean)
- [ ] Docs updated if needed
- [ ] Breaking change? No / Yes → one line

## Changes (what & why, grouped by module/file)
- `services/auth/handler_signup.go` — add `POST /v1/auth/signup` …
- `services/auth/redis_store.go` — token storage, TTL 10m …
- `docs/architecture/overview.md` — update Auth section …

## Links
<!-- Closes #123; Relates to #456; ADR-0002; commit abcdef1 -->
