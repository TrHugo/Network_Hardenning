# Final Hardening Report

## 1. Security Claims Table

| Claim ID | Claim (one sentence) | Control location | Test | Proof artifact |
|----------|---------------------|-----------------|------|---------------|
| C01 | Default-deny firewall blocks unlisted traffic and permits HTTP/HTTPS | `controls/firewall/` | `R1_firewall.sh` | `evidence/after/firewall_tests.txt` |
| C02 | TLS 1.0/1.1 are disabled on srv-web; only TLS 1.2/1.3 are active | `controls/tls_edge/` | `R2_tls.sh` | `evidence/after/tls_scan.txt` |
| C03 | SSH uses key-only auth; root login and passwords are disabled | `controls/remote_access/` | `R3_remote_access.sh` | `evidence/after/ssh_tests.txt` |
| C04 | IKEv2 IPsec tunnel encrypts LAN to DMZ administrative traffic | `controls/remote_access/` | `R3_remote_access.sh` | `evidence/after/ipsec_status.txt` |
| C05 | Suricata IDS detects suspicious access to the /admin URI | `controls/ids/` | `R4_detection.sh` | `evidence/after/ids_alerts.txt` |

## 2. Integration Notes
(To be completed after regression testing)