# Configuration Change Log (Nginx Hardening)

| Directive | Change Made | Justification |
|---|---|---|
| `ssl_protocols` | Removed `TLSv1` and `TLSv1.1`. Set to `TLSv1.2 TLSv1.3`. | NIST SP 800-52 Rev.2 mandates deprecating TLS 1.0 and 1.1 due to known cryptographic weaknesses. |
| `ssl_ciphers` | Replaced `HIGH:MEDIUM:!aNULL` with explicit AEAD ECDHE suites. | `MEDIUM` allows obsolete CBC ciphers which are vulnerable to padding oracle attacks. New list enforces Forward Secrecy. |
| `add_header Strict-Transport-Security` | Added `max-age=300 always;` | Prevents SSL stripping attacks by instructing browsers to exclusively use HTTPS. |
| `limit_req_zone` & `limit_req` | Implemented `10r/s` limit with burst of 5 on `/api`. | Provides basic Layer 7 DoS protection to ensure service availability. |
| `if ($http_user_agent ~* "BadBot")` | Added return `403` logic. | Implements edge filtering (basic WAF) to proactively drop unauthorized or malicious reconnaissance tools. |