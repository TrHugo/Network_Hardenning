# TD5 Evidence Pack Report

## 1. Threat Model
* **Asset:** Administrative access to the target web server (`siteB-srv`).
* **Adversary:** An external attacker on the WAN segment or an internal compromised workstation.
* **Key threats:**
  * Password guessing and brute-force attacks on the SSH daemon.
  * MITM (Man-in-the-Middle) attacks or packet sniffing on the unencrypted WAN segment.
* **Security goals:**
  * Only authorized administrators can SSH into the server using cryptographic keys.
  * Administrator traffic is confidential and its integrity is protected in transit via IPsec.
  * Access controls and authentication events are fully auditable.

## 2. Policy Statement
"Only administrators using authorized ED25519 keys may access the `siteB-srv` bastion via SSH. Password authentication and root logins are strictly prohibited. All management traffic originating from the LAN administrative subnet (10.10.10.0/24) destined for the DMZ server (10.10.20.10/32) must be encrypted over an IKEv2 IPsec tunnel."

## 3. SSH Configuration
We transitioned the SSH daemon to a "bastion mindset." Password authentication was disabled (`PasswordAuthentication no`), and root login was blocked (`PermitRootLogin no`). We restricted access to a specific admin user. This mitigates credential stuffing and brute-force risks. See `config/sshd_config_excerpt.txt`.

## 4. IPsec Configuration
We deployed strongSwan using IKEv2. The tunnel is strictly scoped rather than routing all traffic (`0.0.0.0/0`).
* **Scope:** `10.10.10.0/24` (LAN) === `10.10.20.10/32` (Target Server).
* **Crypto:** AES_CBC_256 / HMAC_SHA2_256_128 / MODP_2048.
* A Pre-Shared Key (PSK) was used for lab purposes, though certificates would be deployed in production.

## 5. Test Plan
We executed a suite of positive and negative tests:
* **Positive:** Verified key-based SSH access and ping connectivity originating from the correct source IP (10.10.10.254) traversing the IPsec tunnel.
* **Negative:** Attempted SSH with passwords and root user (both rejected). 
See `tests/TEST_CARDS.md` for full details.

## 6. Telemetry Proof
The `ipsec statusall` counters definitively prove encryption. After sending 10 ping packets, the ESP payload counters incremented exactly to 10 packets (`840 bytes_i (10 pkts), 840 bytes_o (10 pkts)`). See `evidence/` folder.

## 7. Residual Risks
* **PSK vs. Certificates:** The current setup uses a PSK. In a production environment, this should be migrated to PKI/Certificates to prevent secret sharing vulnerabilities.
* **Key Hygiene:** An administrator's compromised private SSH key would still grant access. MFA (Multi-Factor Authentication) should be added.