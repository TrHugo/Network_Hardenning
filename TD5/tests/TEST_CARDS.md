# TD5 Test Cards

---
**TD5-T01 — SSH password auth is disabled**
**Claim:** Password-based SSH login is rejected.
**Test (negative):** `ssh -o PubkeyAuthentication=no admin@10.10.20.10`
**Result:** "Permission denied (publickey)".
**Evidence:** `evidence/ssh_tests.txt`

---
**TD5-T02 — Root login via SSH is disabled**
**Claim:** Direct root SSH login is blocked.
**Test (negative):** `ssh root@10.10.20.10`
**Result:** "Permission denied".
**Evidence:** `evidence/ssh_tests.txt`

---
**TD5-T03 — SSH logs provide audit trail**
**Claim:** `/var/log/auth.log` records both accepts and denies.
**Test:** Checked log file after SSH attempts.
**Result:** Denied connections are logged with source IP.
**Evidence:** `evidence/authlog_excerpt.txt`

---
**TD5-T04 — IKEv2 tunnel establishes**
**Claim:** `ipsec statusall` shows IKE_SA ESTABLISHED and CHILD_SA INSTALLED.
**Test (positive):** Run `sudo ipsec statusall`.
**Result:** Status confirms negotiation and AES-256 encryption.
**Evidence:** `evidence/ipsec_status.txt`

---
**TD5-T05 — Traffic passes over tunnel (Encrypted)**
**Claim:** Ping from the LAN traverses the IPsec tunnel and is encapsulated in ESP.
**Test (positive):** `ping -I 10.10.10.254 10.10.20.10`
**Result:** StrongSwan internal ESP counters (`bytes_i`, `bytes_o`) increment exactly by 10 packets.
**Evidence:** `evidence/ipsec_status.txt` and `evidence/tunnel_ping.txt`

---
**TD5-T06 — Traffic ignoring tunnel is sent in cleartext**
**Claim:** Ping from an out-of-scope IP (e.g., 10.10.20.50) bypasses the tunnel.
**Test (negative):** Pinging without forcing the source IP.
**Result:** `bytes_i` and `bytes_o` in strongSwan remain at 0.
**Evidence:** Documented in lab notes.

---
**TD5-T07 — Tunnel is scoped to intended subnets**
**Claim:** IPsec limits traffic strictly to 10.10.10.0/24 ↔ 10.10.20.10/32.
**Test:** Inspected config files.
**Result:** Scoping is applied via `leftsubnet` and `rightsubnet`.
**Evidence:** `config/ipsec_siteA.conf`

---
**TD5-T08 — IP Forwarding is active for routing**
**Claim:** The gateway correctly forwards traffic between interfaces.
**Test:** Checked sysctl variables.
**Result:** `net.ipv4.ip_forward = 1` is persistent.
**Evidence:** Verified during pre-flight checks.