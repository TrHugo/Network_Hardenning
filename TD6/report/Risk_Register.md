# Security Risk Register

| Risk ID | Risk Description | Likelihood | Impact | Current Mitigation | Status | Action Plan |
|---|---|---|---|---|---|---|
| **RR-01** | **Compromise of Admin SSH Key**<br>An attacker stealing the `id_td5` ED25519 private key gains full access to the DMZ server. | Low | Critical | Password auth disabled; root login disabled. | Open | Implement Multi-Factor Authentication (MFA) via TOTP or FIDO2. |
| **RR-02** | **Lack of Centralized Logging**<br>Logs are kept locally on VMs. If a machine is compromised, the attacker can wipe their tracks. | High | Medium | Local retention only. | Open | Deploy a SIEM forwarder (e.g., Filebeat/Wazuh) within 60 days. |
| **RR-03** | **Pre-Shared Key (PSK) Leakage**<br>IPsec uses a static PSK. If leaked, unauthorized tunnels could be established. | Medium | High | Secret restricted via file permissions (`chmod 600`). | Open | Migrate strongSwan to X.509 Certificate-based authentication. |
| **RR-04** | **Application-Layer Attacks**<br>The Nginx server is exposed to layer 7 attacks (XSS, SQLi) since the firewall only blocks layer 3/4. | High | Critical | None currently (only IDS alerts). | Open | Deploy a Web Application Firewall (WAF) like ModSecurity. |