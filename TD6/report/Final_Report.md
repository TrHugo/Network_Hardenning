# Final Hardening Report

## 1. Security Claims Table

| Claim ID | Claim (one sentence) | Control location | Test | Proof artifact |
|----------|---------------------|-----------------|------|---------------|
| C01 | Default-deny firewall blocks unlisted traffic and permits HTTPS | `controls/firewall/` | `R1_firewall.sh` | `evidence/after/R1_firewall.txt` |
| C02 | TLS 1.0/1.1 are disabled on srv-web; only TLS 1.2/1.3 are active | `controls/tls_edge/` | `R2_tls.sh` | `evidence/after/R2_tls.txt` |
| C03 | SSH uses key-only auth; root login and passwords are disabled | `controls/remote_access/` | `R3_remote_access.sh` | `evidence/after/R3_remote_access.txt` |
| C04 | IKEv2 IPsec tunnel encrypts LAN to DMZ administrative traffic | `controls/remote_access/` | `R3_remote_access.sh` | `evidence/after/R3_remote_access.txt` |
| C05 | Suricata IDS detects suspicious access to the /admin URI | `controls/ids/` | `R4_detection.sh` | `evidence/after/R4_detection.txt` |

## 2. Integration Notes
The hardening process was verified using an automated regression suite. All five security layers (Firewall, IDS, TLS, SSH, and IPsec) are functioning simultaneously without conflict. The IPsec tunnel correctly encapsulates administrative traffic, and the firewall enforces a strict HTTPS-only policy for the web service.