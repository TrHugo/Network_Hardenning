# TD4 Test Cards

**TD4-T01 — Baseline allows legacy TLS version**
- **Claim:** The baseline endpoint intentionally offers TLS 1.2 alongside obsolete versions, demonstrating configuration drift.
- **Preconditions:** The baseline weak Nginx configuration is active.
- **Test (positive):** Run `testssl.sh --fast https://10.10.20.10`.
- **Expected:** Scanner reports "Obsoleted CBC ciphers: offered".
- **Evidence:** `evidence/before/tls_scan.txt`.

---

**TD4-T02 — After hardening, legacy versions are disabled**
- **Claim:** TLS 1.0 and 1.1, along with obsolete CBC ciphers, are completely rejected.
- **Preconditions:** The hardened Nginx configuration is applied and reloaded.
- **Test (positive):** Re-run `testssl.sh --fast https://10.10.20.10`.
- **Expected:** Scanner explicitly states TLS 1.0 and 1.1 are "not offered", and TLS 1.3 is "offered (OK)".
- **Evidence:** `evidence/after/tls_scan.txt`.

---

**TD4-T03 — Cipher policy enforces forward secrecy**
- **Claim:** All negotiated cipher suites provide robust Forward Secrecy (FS).
- **Preconditions:** The `ssl_ciphers` directive restricts options to ECDHE suites.
- **Test:** Analyze the cipher negotiation block in `testssl.sh`.
- **Expected:** Test reports "FS is offered (OK)" with only GCM/CHACHA20 suites listed.
- **Evidence:** `evidence/after/tls_scan.txt`.

---

**TD4-T04 — Certificate matches documented trust model**
- **Claim:** The server presents a self-signed RSA 2048 certificate for `td4.local`.
- **Test:** Use OpenSSL to inspect the certificate data: `openssl s_client -connect 10.10.20.10:443 -servername td4.local </dev/null`.
- **Expected:** Connection returns `CN = td4.local` with a validation warning (expected in lab).
- **Evidence:** Terminal captures stored in the report.

---

**TD4-T05 — Rate limiting triggers on burst traffic**
- **Claim:** Burst requests exceeding the defined zone limits are throttled to protect backend availability.
- **Preconditions:** `limit_req_zone` is active on `/api`.
- **Test (negative):** Flood the endpoint: `for i in {1..50}; do curl -sk -o /dev/null -w "%{http_code}\n" https://10.10.20.10/api & done; wait`.
- **Expected:** Initial requests return `200`, subsequent requests return `503 Service Unavailable`.
- **Evidence:** Terminal output and logic documented in the failure modes.

---

**TD4-T06 — Request filtering blocks malicious pattern**
- **Claim:** The reverse proxy correctly identifies and drops unauthorized User-Agents.
- **Preconditions:** The `$http_user_agent` rule blocks "BadBot".
- **Test (negative):** Send a crafted request: `curl -k -H "User-Agent: BadBot/1.0" https://10.10.20.10/`.
- **Expected:** HTTP response is exactly `403 Forbidden`.
- **Evidence:** `10.10.10.254 - - [27/Mar/2026:14:18:09 +0000] "GET / HTTP/1.1" 403...` in access logs.