# TD4 - TLS Audit and Hardening Evidence Pack

## 1. Threat Model
- **Asset:** Web service hosted on `srv-web` (`10.10.20.10`).
- **Adversary:** On-path attacker within the LAN/DMZ, or a remote automated scanner.
- **Key Threats:** Downgrade attacks to vulnerable TLS 1.0/1.1 protocols, interception via weak cipher suites (lacking Forward Secrecy), and automated bot abuse/spam.
- **Security Goals:** Enforce modern TLS versions (1.2/1.3), require AEAD cipher suites, and implement edge filtering to block malicious user-agents and rate-limit excessive requests.

## 2. TLS Profile
The hardened configuration is explicitly aligned with **NIST SP 800-52 Rev.2**.
- **Minimum TLS Version:** TLS 1.2 and TLS 1.3 only. Legacy versions (TLS 1.0 and 1.1) are strictly prohibited.
- **Cipher Strategy:** Only AEAD suites offering robust Forward Secrecy (ECDHE) are permitted. Obsolete CBC ciphers are disabled.
- **HSTS Policy:** HTTP Strict Transport Security is enabled with a `max-age=300` for lab testing purposes, ensuring clients force HTTPS connections.
- **Certificate:** Self-signed RSA 2048 certificate (CN=td4.local) is used, matching the lab's explicit trust model.

## 3. Before / After Comparison

| Item | Before | After | Evidence file |
|---|---|---|---|
| **TLS 1.0 / 1.1** | Offered (Vulnerable) | **Not offered** | `evidence/before/tls_scan.txt`, `evidence/after/tls_scan.txt` |
| **Weak ciphers (CBC)** | Offered | **Removed** | `evidence/before/tls_scan.txt`, `evidence/after/tls_scan.txt` |
| **Forward Secrecy** | Partial support | **All suites (AEAD)** | `evidence/after/tls_scan.txt` |
| **HSTS** | Absent | **Enabled (300s)** | `evidence/after/tls_scan.txt` |
| **Certificate** | Self-signed | Self-signed (Lab CA) | `config/cert_info_before.txt` |

## 4. Edge Controls
Two edge controls were implemented at the reverse proxy level:
1. **Rate Limiting:** A `limit_req_zone` was applied to the `/api` endpoint (`10r/s`, burst of 5) to protect availability against spam.
2. **Request Filtering (WAF):** A User-Agent filter was implemented to block known malicious bots (e.g., `BadBot/1.0`) returning a `403 Forbidden`.

## 5. Triage Note
- **What happened:** An automated scanner identifying itself as `BadBot/1.0` attempted to access the web root directory (`/`).
- **Signal:** Nginx access log recorded the event: `10.10.10.254 - - [27/Mar/2026:14:18:09 +0000] "GET / HTTP/1.1" 403 162 "-" "BadBot/1.0"`.
- **Classification:** Automated scanning / Reconnaissance abuse.
- **Next steps in a real SOC:**
  - Verify if this IP (`10.10.10.254` acting as proxy) generated other 403s on different paths.
  - Check