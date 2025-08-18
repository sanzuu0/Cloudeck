# Contributing to Cloudeck

Shared rules so changes reach `main` quickly and safely.

## Quick start

1. Requirements: Go ≥ 1.22, Node ≥ 20 (if you touch `/web`), Docker (optional).
2. Install hooks:
   ```bash
   pipx install pre-commit || pip install pre-commit
   pre-commit install
   ```
3. Handy commands:
   ```bash
   make fmt   # formatting
   make lint  # linters
   make test  # tests
   make build # build
   make demo  # local demo/stub
   ```

## Branches & PRs

- Branches: `<type>/<scope>/<short-kebab>` — e.g., `feat/auth/email-signup`.
- PR title: **Conventional Commits** — `type(scope): summary`.
- Merge: **Squash & merge only**. Keep PRs small.
- Use the PR template (auto-applied). Always answer **“Breaking change?”**.

**Types:** `feat` · `fix` · `refactor` · `perf` · `test` · `docs` · `chore` · `build` · `ci` · `style` · `revert`

**Scopes (pick one primary):**
`auth` · `user` · `file` · `share` · `gateway` · `worker` · `frontend` · `web` · `ml` · `inference` · `storage` · `db` · `search` · `analytics` · `billing` · `payments` · `notifications` · `admin` · `security` · `api` · `contracts` · `perf` · `infra` · `deploy` · `charts` · `ci` · `repo` · `docs` · `tooling` · `scripts`

> If you truly need a new scope, propose it in the PR description (prefer **domain** scopes like `sharing`, `billing` over implementation ones). If a change spans multiple areas, pick the primary and mention the rest in the Summary.

## Commits (Conventional Commits)

Header format: `type(scope): imperative action`

Examples:
```text
feat(auth): add email signup
fix(file): map S3 413 to 400
refactor(user): extract repository
```

Breaking changes:
```text
BREAKING CHANGE: user_id changed to uuid; see migration steps
```

## Before pushing / before PR

- Run: `pre-commit run -a` (fmt, linters, **gitleaks**).
- Run tests: `make test` (or `go test ./... -race -cover`).
- Fill in the PR template; add `Closes #…` where applicable.

## Backend quality (minimum)

- Service endpoints: `GET /healthz`, `GET /readyz`, `GET /metrics` (Prometheus).
- Logs are structured; add `request_id`, and include `trace_id` in error responses.
- Errors use **RFC7807** (`application/problem+json`).
- **Write** endpoints support idempotency via `Idempotency-Key` header.

## Contracts & docs

- If you change the API, update `api/openapi.yaml` (OpenAPI 3.1).
- If behavior changes, update `README` and/or `docs/adr`.

## Security

- **No plaintext secrets in the repo.** Use env vars / GitHub secrets.
- `gitleaks` is required locally and in CI. Fix dependency/vuln alerts promptly.

## Contacts

Owner: **@sanzuu0** · security: `cloudeck.ai@gmail.com`
