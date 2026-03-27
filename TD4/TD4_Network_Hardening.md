# TD4 (3h) — TLS Audit and Hardening: Before / After Evidence Pack

**Module:** Network Hardening (4th-year engineering)  
**Normative anchor:** NIST SP 800-52 Rev.2 (TLS configuration guidance) + RFC 8446 (TLS 1.3)  
**Deliverable style:** "config + test + telemetry" evidence pack  
**Scope note:** Everything stays inside the lab. No external target scanning.

---

## 0) What you will build (end state)

TLS rarely fails because an attacker "breaks the math". It fails because of **configuration drift**: wrong protocol versions, weak cipher suites, broken certificate chains, forgotten renewals.

You will deliver:

1. A **baseline TLS audit** that captures the current (deliberately weak) posture with evidence.
2. A **hardened configuration** aligned with a defensible profile (justified by NIST SP 800-52 Rev.2).
3. A **before / after comparison** with reproducible scanning commands and a clear evidence table.
4. A minimal set of **edge controls** (reverse-proxy rate limiting + request filtering) with proof.
5. A **triage note** demonstrating observability from logs.

> The point is not "TLS is secure". The point is: **you can prove what changed, why, and that the result matches your stated profile**.

---

## 1) Prerequisites

### Lab environment (4-VM baseline)
Use the standard **4-VM baseline** from `0_technical_support/00_environment/README.md`:

| VM | Role in TD4 | Zone | IP |
|---|---|---|---|
| **gw-fw** | Boundary context, optional logging | NH-LAN + NH-DMZ | 10.10.10.1 / 10.10.20.1 |
| **client** | TLS scanner, tester, traffic generator | NH-LAN | 10.10.10.10 |
| **srv-web** | TLS endpoint (nginx, native or Docker) | NH-DMZ | 10.10.20.10 |
| **sensor-ids** | Handshake capture (optional) | NH-DMZ | 10.10.20.50 |

> **First time?** Follow `0_technical_support/TD1/TD1.md` for the fast-forward setup guide.

### Tools
- `openssl s_client` — manual TLS handshake
- `curl -vk` — quick HTTP/TLS check
- `testssl.sh` **or** `sslyze` (choose one scanner; keep commands reproducible)
- `tcpdump` / Wireshark — optional handshake capture
- Nginx — TLS termination and reverse proxy
- Docker + Docker Compose — optional fast-start (see §3 Option A)

### Repo skeleton (standard across groups)
```
TD4_<Group>_<Date>/
  README.md
  report.md
  config/
    nginx_before.conf
    nginx_after.conf
    change_log.md
    cert_info_before.txt
    cert_info_after.txt
  tests/
    commands.txt
    TEST_CARDS.md
  evidence/
    before/
    after/
  appendix/
    failure_modes.md
```

---

## 2) Threat model (5 minutes, write it down)

Your report must include a short threat model (6–10 lines):

- **Asset:** web service on srv-web (HTTP API or content)
- **Adversary:** on-path attacker on the LAN/DMZ, or a remote scanner
- **Key threats:**
  - downgrade to weak protocol version (TLS 1.0/1.1)
  - negotiation of weak cipher suite (no forward secrecy)
  - broken or expired certificate chain → user clicks through warnings
  - misconfigured edge → information leakage via headers or error pages
- **Security goals:**
  - only modern TLS versions are offered
  - cipher policy enforces forward secrecy
  - certificate chain is valid for the lab trust model
  - edge controls provide basic availability and filtering

---

## 3) Part A — Deploy a TLS endpoint (weak baseline) (20 min)

You need a TLS endpoint with **at least one intentional weakness** you can later fix.

### Option A — Docker (recommended for speed)
Follow `0_technical_support/00_environment/docker_tls_lab/README.md` on `srv-web`:

```bash
# On srv-web
cd /opt/docker_tls_lab   # or wherever you placed the files
mkdir -p certs
openssl req -x509 -newkey rsa:2048 -keyout certs/server.key \
  -out certs/server.crt -days 7 -nodes -subj "/CN=td4.local"
docker compose up -d
```

Quick verify from `client`:
```bash
curl -k https://10.10.20.10:8443/
```

### Option B — Native nginx
Install nginx on `srv-web`, configure TLS with a self-signed cert, and enable weak settings for the baseline (e.g. TLS 1.0/1.1 enabled, weak ciphers allowed).

**Record:**
- `config/nginx_before.conf`
- `config/cert_info_before.txt` (output of `openssl x509 -in server.crt -noout -text`)

---

## 4) Part B — Baseline TLS audit ("before") (30 min)

From `client`, run these scans against the TLS endpoint:

### OpenSSL sanity check
```bash
openssl s_client -connect 10.10.20.10:8443 -servername td4.local -tls1_2 </dev/null
```
Capture: negotiated protocol, cipher suite, certificate chain summary.

### Curl verbose
```bash
curl -vk https://10.10.20.10:8443/ 2>&1 | tee evidence/before/curl_vk.txt
```

### TLS scanner
```bash
testssl.sh --fast --warnings batch https://10.10.20.10:8443 | tee evidence/before/tls_scan.txt
```
(If `testssl.sh` is unavailable, use `sslyze` or `sslscan`.)

### Optional — handshake pcap (from sensor-ids)

> **⚠ Interface name:** The command below uses `enp0s8`. Verify the correct interface on `sensor-ids` with `ip link` and substitute if needed.

```bash
sudo tcpdump -i enp0s8 -w evidence/before/tls_handshake.pcap \
  'host 10.10.20.10 and tcp port 8443' -c 50
```

**Produce a "before profile table" in `report.md`:**

| Item | Finding |
|---|---|
| Protocol versions offered | TLS 1.0, 1.1, 1.2 |
| Cipher families | (list: CBC, AEAD, etc.) |
| Forward secrecy | yes / partial / no |
| Certificate subject + validity | CN=td4.local, 7 days |
| Key size + signature algorithm | RSA 2048, SHA-256 |
| Chain status | self-signed / incomplete / OK |
| Obvious risk | (one sentence) |

> Evidence rule: **every "before" claim needs a file.** If you say "TLS 1.0 is offered", reference the scan output line.

---

## 5) Part C — TLS hardening (60–70 min)

### 5.1 Define your TLS profile
Write a 6–10 line TLS profile in `report.md` (or a separate `config/TLS_Profile.md`):

- Minimum TLS version (1.2 or 1.3 only; justify)
- Cipher strategy (AEAD suites only; disable CBC; prefer TLS 1.3 suites)
- Certificate management choice (self-signed for lab, document trust model)
- HSTS policy (enable with short `max-age` in lab)
- Operational checks: expiry monitoring, reload strategy, rollback plan

Reference at least one NIST SP 800-52 Rev.2 recommendation in your justification.

### 5.2 Apply hardening in nginx
Implement at minimum:
- `ssl_protocols TLSv1.2 TLSv1.3;` (disable 1.0, 1.1)
- Modern cipher string (e.g., `ECDHE+AESGCM:ECDHE+CHACHA20:!aNULL:!MD5:!RC4`)
- `ssl_prefer_server_ciphers on;`
- HSTS header: `add_header Strict-Transport-Security "max-age=300" always;`
- Optional: session ticket policy, OCSP stapling (document trade-offs)

Save:
- `config/nginx_after.conf`
- `config/change_log.md` (what you changed and why, line by line)

Restart safely:
```bash
nginx -t && sudo systemctl reload nginx   # native
# or
docker compose restart                      # Docker
```

### 5.3 Re-run TLS audit ("after")
Re-run the **exact same commands** from Part B:
```bash
openssl s_client -connect 10.10.20.10:8443 -servername td4.local </dev/null \
  | tee evidence/after/openssl_s_client.txt
testssl.sh --fast --warnings batch https://10.10.20.10:8443 \
  | tee evidence/after/tls_scan.txt
```

**Produce a before / after comparison table in `report.md`:**

| Item | Before | After | Evidence file |
|---|---|---|---|
| TLS 1.0 | offered | **not offered** | tls_scan before/after |
| TLS 1.1 | offered | **not offered** | tls_scan before/after |
| Weak ciphers | RC4, CBC-SHA | **removed** | tls_scan after |
| Forward secrecy | partial | **all suites** | openssl after |
| HSTS | absent | **enabled (300s)** | curl after |
| Certificate | self-signed | self-signed (lab) | cert_info |

---

## 6) Part D — Edge controls (reverse proxy) (40 min)

Your TLS endpoint doubles as a reverse proxy. Implement **two** controls:

### Control 1 — Rate limiting (availability protection)
Limit requests per IP for a path (e.g., `/login`, `/api`):

```nginx
# In http block
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;

# In location block
location /api {
    limit_req zone=api_limit burst=5 nodelay;
    proxy_pass http://127.0.0.1:8080;
}
```

**Prove it:**
- Send a burst from `client`: `for i in $(seq 1 30); do curl -sk https://10.10.20.10:8443/api; done`
- Show 429 / 503 responses
- Show the log evidence

Save:
- `evidence/after/rate_limit_test.txt`
- `evidence/after/nginx_access_log_rate.txt`

### Control 2 — Basic request filtering (WAF concept)
Pick one:
- Block obvious SQL-injection patterns in query strings
- Block invalid `Host` headers
- Block known-bad user agents (toy example)
- Enforce allowed HTTP methods (GET/POST only)

**Prove it:**
- Craft a request that triggers the block
- Show the response (403) + log line

Save:
- `evidence/after/filter_test.txt`
- `evidence/after/nginx_access_log_filter.txt`

> You are not "solving web security" with regex. You are demonstrating **edge enforcement + observability**.

### Optional advanced — ModSecurity + OWASP CRS
If time allows, deploy a WAF container and demonstrate one CRS rule triggering. This is bonus (document clearly if attempted).

---

## 7) Part E — Log triage (15 min)

Write a triage note in `report.md` (or `appendix/triage.md`):

1. **What happened?** (one paragraph summarizing edge activity)
2. **What was the signal?** (which log field(s) — source IP, path, status code, user-agent)
3. **Classification:** benign / scan / abuse / likely attack
4. **What would you do next in a real SOC?** (2–4 bullets)

Your triage must reference:
- one request IP / timestamp
- one exact log line excerpt (pasted)

---

## 8) Deliverables

### 8.1 Evidence Pack report (`report.md`)
Structure:
1. **Threat model** (from §2)
2. **TLS profile** (explicit, with NIST reference)
3. **Before / after table** (with evidence file references)
4. **Edge controls** (rate limiting + filtering: config + proof)
5. **Triage note** (log excerpt + classification)
6. **Residual risks** (cert rotation, WAF tuning, upstream auth, etc.)

### 8.2 Repo checklist
- [ ] Clean README (setup + how to reproduce)
- [ ] `config/` — before and after configs, change log
- [ ] `evidence/before/` and `evidence/after/` — all scan outputs
- [ ] `tests/TEST_CARDS.md` — ≥ 6 test cards (see §9)
- [ ] `appendix/failure_modes.md`
- [ ] No private keys committed

---

## 9) Test cards (required, ≥ 6)

Add cards to `tests/TEST_CARDS.md` using the standard template from `0_technical_support/_shared/templates/test_card_template.md`. Separate each card with a `---` horizontal rule.

### Suggested claims

**TD4-T01 — Baseline allows legacy TLS version**  
**Claim:** The baseline endpoint offers TLS 1.0 or 1.1 (documented weakness).  
**Preconditions:** nginx_before.conf deployed  
**Test (positive):** `openssl s_client -connect 10.10.20.10:8443 -tls1`  
**Expected:** connection succeeds with TLS 1.0  
**Evidence file:** `evidence/before/tls_scan.txt`

**TD4-T02 — After hardening, legacy versions are disabled**  
**Claim:** TLS 1.0 and 1.1 are rejected after hardening.  
**Test (positive):** `testssl.sh` reports "not offered" for TLS 1.0/1.1  
**Test (negative):** `openssl s_client -tls1 ...` fails to connect  
**Evidence file:** `evidence/after/tls_scan.txt`

**TD4-T03 — Cipher policy enforces forward secrecy**  
**Claim:** All negotiated cipher suites provide forward secrecy (ECDHE).  
**Test:** `testssl.sh` cipher listing; no non-FS suites present  
**Evidence file:** `evidence/after/tls_scan.txt`

**TD4-T04 — Certificate chain is valid for lab model**  
**Claim:** Certificate subject, validity, and chain match documented trust model.  
**Test:** `openssl s_client ... | openssl x509 -noout -text`  
**Evidence file:** `evidence/after/openssl_s_client.txt`

**TD4-T05 — Rate limiting triggers on burst traffic**  
**Claim:** Burst requests exceeding the limit return 429/503.  
**Test (positive):** Normal request returns 200  
**Test (negative):** Burst loop returns 429/503 after threshold  
**Evidence file:** `evidence/after/rate_limit_test.txt`

**TD4-T06 — Request filtering blocks malicious pattern**  
**Claim:** SQLi/bad-UA/invalid-Host pattern is blocked (403).  
**Test (positive):** Clean request returns 200  
**Test (negative):** Malicious request returns 403  
**Evidence file:** `evidence/after/filter_test.txt`

**TD4-T07 (bonus) — Before/after scan is reproducible**  
**Claim:** Running the same scanner command twice produces consistent results.  
**Test:** Re-run `testssl.sh` and compare output  
**Evidence file:** `evidence/after/tls_scan.txt`

---

## 10) Grading rubric (100 points)

| Category | Points | Key criteria |
|---|---|---|
| **Baseline audit quality** | 20 | Scan outputs present, "before" table complete |
| **TLS hardening + justification** | 30 | Profile explicit, changes traceable, NIST reference |
| **Before / after comparison** | 15 | Table with evidence file references |
| **Edge controls (rate limit + filter)** | 15 | Two controls, proof of trigger + log excerpt |
| **Log triage** | 10 | Correct interpretation, clear next steps |
| **Maintainability** | 10 | Clean repo, reproducible steps, test cards ≥ 6 |

---

## Appendix A — Common failure modes

Document relevant items in `appendix/failure_modes.md`:

| ID | Failure | Symptom | Fix |
|---|---|---|---|
| FM-01 | Nginx reload fails | `nginx -t` shows syntax error | Fix config, always run `nginx -t` before reload |
| FM-02 | Wrong port (8443 vs 443) | `curl` connection refused | Check `listen` directive and Docker port mapping |
| FM-03 | Certificate hostname mismatch | Scanner warns "hostname mismatch" | Use `-servername` with SNI; match `server_name` |
| FM-04 | Incomplete certificate chain | Scanner flags "chain incomplete" | Concatenate intermediate cert into the chain file |
| FM-05 | Self-signed warning | Expected in lab; must document | Explain trust model (lab CA or self-signed) |
| FM-06 | Rate limit blocks legitimate traffic | All requests get 429 | Tune `burst` and `rate` parameters |
| FM-07 | Filter regex creates false positives | Benign request blocked | Narrow match scope; restrict to specific paths |

---

## Appendix B — Professor-level check

If a reviewer reads your report, they should **never** need to ask:

- "Where is the scanner output?" → evidence file
- "What changed?" → before/after table + change_log.md
- "Why this profile?" → NIST SP 800-52 reference
- "How did you test?" → test card with command + expected + observed
- "Where is the proof?" → log line or scan snippet pasted

If any of these is missing, the work is incomplete.

---

## Appendix C — Triage cheat-sheet

When analyzing Nginx logs, look at:

- Source IP + timestamp + path + status code
- User-agent anomalies
- Burst patterns (same IP, many requests in short time)
- Error log correlation (upstream failures, TLS handshake errors)
- Response sizes and unusual HTTP methods

Triage is a skill: you are not required to be perfect, but you must be **explicit and evidence-driven**.
