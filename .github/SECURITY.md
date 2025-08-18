# Security Policy — Cloudeck

Thank you for helping keep Cloudeck secure. This document explains **how to report vulnerabilities** and what we expect from researchers.

## How to report a vulnerability

**Please do not open public Issues.**  
Choose one of the options below:

- **Preferred:** GitHub → **Security** tab → **Report a vulnerability** (if available).
- Or email: **cloudeck.ai@gmail.com**

Please include:
- affected area (file/endpoint/version),
- clear reproduction steps and a minimal PoC,
- expected vs. actual behavior,
- impact assessment (why it matters).

If you need encryption, email us and we will provide a key.

## SLA & process

- **Acknowledgement:** within **48 hours**.
- **Triage & initial assessment:** within **5 business days** (rough CVSS; we’ll refine together).
- **Target fix timelines** (may vary by complexity/risk):
  - Critical — within **7 days**
  - High — within **14 days**
  - Medium — within **30 days**
  - Low — best effort / prioritized

After a fix is released, we will coordinate **responsible disclosure** and, if appropriate, publish a GitHub Security Advisory / request a CVE. By default, public disclosure occurs **after** a patched release is available.

## Scope & testing rules

Allowed (when using local environments/test rigs and avoiding harm/outage):
- passive analysis, static analysis, local fuzzing,
- testing idempotent requests against demo environments,
- PoCs that do **not** exfiltrate data or cause downtime.

Out of scope / prohibited:
- DoS/DDoS, brute-force, or load tests against third‑party/production environments,
- social engineering, phishing, physical access,
- data exfiltration or accessing other users’ private data,
- attacks against third‑party services/accounts (email, CDN, registries, etc.),
- automated scanners that generate excessive load on public resources.

If in doubt, **contact us before testing**.

## Supported versions

We support the current `main` and the latest **minor** releases. Older branches/releases may receive fixes on a **best‑effort** basis.

## Dependencies & secrets

- Dependency updates: we track **Dependabot**/**OSV**; target fix timelines follow the SLA above.
- **No plaintext secrets in the repository.** Use environment/GitHub secrets. If you discover any token/key, please notify us — we will **revoke and rotate immediately**.

## Safe Harbor

When you act in **good faith** within this policy and scope, we will **not pursue legal action** against you. We ask that you:
- avoid harm to users and data,
- comply with applicable laws,
- do not attempt to profit from the vulnerability outside coordinated disclosure.
