# Cloudeck — Overview

Teams that handle sensitive documents often struggle with two extremes:

* **Consumer file-sharing SaaS** – fast, but data live “forever” and are rarely encrypted at rest.
* **Legacy FTP / SMB servers** – self-hosted, but painful to operate and impossible to audit.

**Cloudeck** bridges that gap: a self-hosted, time-boxed object store where files are encrypted, auto-expired and shareable through signed links.

## Why it matters

| Pain point | How Cloudeck fixes it |
|------------|-----------------------|
|  Files lingering for years | Per-file **TTL** (1 d · 7 d · 30 d · 1 y · never) + background purge |
| Manual file-exchange workflows | **REST/GraphQL API** and lightweight SPA for drag-and-drop uploads |
| Liability of unencrypted storage | **AES-256 server-side encryption** before data hit the disk |
| One-off file sharing via e-mail | **Signed URLs** with `exp` & `max_uses` — revoke any time |
| Ops / SRE blind spots | Prometheus metrics for HTTP, business KPIs and rate-limiter hits |

## MVP feature set

1. **Authentication & Profile** – e-mail + password signup with verification code; profile page with default TTL.
2. **File storage** – uploads via UI or API, 200 MB hard limit, encrypted at rest.
3. **TTL & Auto-deletion** – cron worker removes objects on `expires_at`.
4. **Sharing** – HMAC/JWT signed links, single-use or multi-use.
5. **Abuse protection** – IP/User rate-limiter (HTTP 429 on exceed).
6. **Mini SPA front-end**.