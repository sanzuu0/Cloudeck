🗺️ **Cloudeck — Development Roadmap**

This roadmap outlines the evolution of Cloudeck a production‑ready, secure, and observable platform. Each version is an incremental step toward a fully‑featured, scalable solution.

---

### ✅ v0.1.0— Infrastructure & Documentation Bootstrap
📅 *Planned: 2025‑07‑30*  
🎯 **Goal:** Set up foundational scaffolding for future development and CI/CD‑driven delivery.

#### Features
* **GitHub Actions**
  * `ci.yml`: `go vet`, `golangci-lint`, `go test`, `docker build`, `trivy scan`
  * `release.yml`: build & push Docker image on `v*` tags, create GitHub Releases
* **Commit Policy & Git Meta**
  * Husky hooks `pre‑commit`, `commit‑msg`
  * `commitlint.config.cjs` with custom rules
  * PR / issue templates, `CODEOWNERS`
* **Documentation** (`docs/…`) – overview, architecture, roadmap, ADR‑0001, testing‑strategy, threat‑model, FAQ
* **Tooling** – `Makefile`, `docker-compose.demo.yml`, placeholder k6 script, `.editorconfig` etc.
* **Helm Scaffold** – empty chart `charts/file-storage`
* **README** – WIP badge + quick‑start (`make demo`, `make perf`)

---

### 🚀 v0.2.0 — Core Flow + Soft Auth
📅 *ETA: TBD*  
🎯 **Goal:** Implement the first working user flow: register ➜ login ➜ upload ➜ list.

#### Features
* 🔒 **Auth Service** – JWT register/login/refresh/logout (no e‑mail yet), Redis for tokens
* 🎯 **User & File Services**
    * File metadata in Postgres
    * AES‑256 encryption in MinIO
    * **Presigned URL** for direct upload, 200 MB limit
* 🎨 **Frontend** – mini SPA with login / upload / list
* ⚙️ **Infrastructure** – `make demo` runs full stack locally

---

### ⏳ v0.3.0 — File TTL + Signed Sharing
📅 *ETA: TBD*  
🎯 **Goal:** Enable secure and ephemeral file sharing.

#### Features
* 🕒 **TTL:** per‑file expiration (1 d, 7 d, 30 d …) stored in metadata
* ⚙️ **Worker‑TTL:** periodic scan & deletion (`expires_at`)
* 🔒 **Signed URLs:** HMAC/JWT links with `exp`, `max_uses`, invalidate on delete/expiry

---

### 🔐 v0.4.0 — E‑mail Verification + Rate Limiting
📅 *ETA: TBD*  
🎯 **Goal:** Enforce identity verification and prevent abuse.

#### Features
* 📨 **E‑mail verification** via SMTP (e.g. Mailtrap)
* 📊 **Rate Limiter:** per‑IP & per‑user (Redis counters in Gateway)
* 🔒 **Security:** refresh‑token blacklist, abuse protection on auth endpoints

---

### 📊 v0.5.0 — Observability & Metrics
📅 *ETA: TBD*  
🎯 **Goal:** Provide monitoring & operational insight.

#### Features
* 📈 **Prometheus metrics** – HTTP, business, rate‑limit counters
* 📊 **Grafana dashboards** – default KPI panels
* 🧵 **Tracing (optional)** – OTEL collector + Tempo

#### Alerts
* `p95 latency > X ms`
* `5xx ratio > threshold`

---

### 🎨 v0.6.0— SPAUX Polish
📅 *ETA: TBD*  
🎯 **Goal:** Make Cloudeck presentable and user‑friendly.

#### Front‑end Enhancements
* Drag‑and‑drop uploads, progress indicators
* Shareable‑link UI, dashboard with TTL info

#### Polish
* Branding, favicon, overall styling
* SPA served from gateway or dedicated container

---

## 🔎 v1.0.0 — Production Hardening & Launch

**Goal:** Polish the MVP and harden the system for public availability or on-prem deployment.

### Features:

* **Full STRIDE threat model mitigation**

  * Close any gaps from `docs/threat-model.md`
  * Address spoofing, tampering, elevation, etc.

  * Integrate with HashiCorp Vault or SOPS for safer credential handling

  * Ensure OSS components comply with Apache
  * Add `security.txt` for disclosures

  * Match code with docs — all MVP features fully documented
* Test coverage pass *

  * Increase unit/e2e coverage; add regression safety nets

---

## 📜 v1.1.0 — File Access History & Auditing

**Goal:** Improve transparency and compliance for file access.

### Features:

* Store metadata for each file access (who, when, from where)
* Track link usage (expired, revoked, overused)
* UI/CLI view of access logs
* Export logs as CSV/JSON

---

## 🧠 v1.2.0 — AI-Powered File Classification

**Goal:** Help users organize files automatically.

### Features:

* Use ML (or GPT/NLP) to classify uploads (e.g. "passport", "contract", "invoice")
* Add suggested tags and title
* Label content as sensitive (PII, financial data)

---

## 🛡 v1.3.0 — Behavioral Anomaly Detection

**Goal:** Spot malicious behavior early.

### Features:

* Train a baseline model (per user or globally) for typical usage
* Alert on download spikes, IP mismatch, strange hours, mass access
* Admin panel for reviewing suspicious activity

---

## 🔐 v1.4.0 — Zero Trust Access Control

**Goal:** Eliminate assumptions of trust — even inside the network.

### Features:

* Issue short-lived tokens (5–15 min)
* Bind token to IP
* Enforce 2FA / re-auth on sensitive actions

---

## 🧱 v1.5.0 — Schema Evolution & API Deprecation 

**Goal:** Prepare the system for long-term maintainability.

### Features:

* Safe schema migrations with Go `migrate`/Atlas
* Deprecation headers for old API endpoints
* Migration dashboard: what needs cleanup

---

## 💳 v1.6.0 — User Quotas & Usage Metrics

**Goal:** Add business logic around per-user limits.

### Features:

* Quotas: storage space, number of files, link count
* Dashboard: current usage and billing simulation
* Rate-limit soft violations

---

## 💣 v1.7.0 — Self-Destructing Files

**Goal:** Allow sensitive files to delete themselves after access.

### Features:

* "Read-once" toggle for uploads
* Optionally burn on first download or after 1 minute
* Visual cue in UI

---

## 🧑‍🤝‍🧑 v1.8.0 — Per-Org Buckets (Multitenancy Ready)

**Goal:** Segment storage by organization or user.

### Features:

* Dedicated MinIO/S3 bucket per tenan
* Auth changes to support org scoping

---

## 🗂️ v1.9.0 — Smart Folder Grouping (via ML)

**Goal:** Cluster user files into folders based on semantics.

### Features:

* Analyze file content + tags
* Suggest or auto-create folders like “IDs”, “Legal Docs”, “Personal”
* Improve on every upload via retraining

---

## 🌐 v1.10.0 — Pluggable Storage Backends

**Goal:** Add cloud flexibility for storage.

### Features:

* Abstract interface for storage (S3, GCS, Azure Blob)
* Config-driven backend selection
* Per-org or global setting

---

## 📍 v1.11.0 — Multi-region Support

**Goal:** Improve performance and compliance globally.

### Features:

* Upload location selector (e.g., EU, US, Asia)
* Data locality awareness
* Future integration with CDN (optional)

---

## 📑 v1.12.0 — Full Audit Logging + Export

**Goal:** Bring full forensic capability to admins.

### Features:

* Full system log for auth, uploads, downloads, errors
* Exportable JSON / CSV logs
* Audit-grade formatting (e.g., RFC 5424)

---

