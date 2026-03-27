# TD2 Test Cards

**TD2-T01 — Allowed flows from matrix pass**
- **Claim:** HTTP (TCP/80) traffic intended for `srv-web` in the DMZ is successfully forwarded.
- **Preconditions:** The `nftables` ruleset is loaded; Nginx is running on `srv-web`.
- **Test (positive):** Run `curl -sI http://10.10.20.10 | head -5`.
- **Result:** Returned HTTP/1.1 200 OK.
- **Evidence:** Terminal output and packet counters incrementing in `evidence/counters_after.txt`.

---

**TD2-T02 — Default deny blocks unlisted traffic**
- **Claim:** Traffic attempting to reach unapproved ports on the DMZ is rejected.
- **Preconditions:** The default policy on the FORWARD chain is set to `drop`.
- **Test (negative):** Run `nc -vz -w 3 10.10.20.10 3306` (MySQL port).
- **Result:** Connection failed (Refused/Timeout depending on the origin chain).
- **Evidence:** Terminal output demonstrating failure to establish a TCP handshake.

---

**TD2-T03 — Denied traffic produces telemetry**
- **Claim:** Packets dropped by the FORWARD and INPUT chains generate rate-limited log entries for security auditing.
- **Preconditions:** Logging rules with specific prefixes are positioned just before the implicit drop policy.
- **Test:** Send unauthorized transit traffic (e.g., from DMZ to WAN) and review `journalctl -k`.
- **Result:** Log entries appear containing the `NFT_FWD_DENY` prefix.
- **Evidence:** `evidence/deny_logs.txt`.

---

**TD2-T04 — Ruleset is reversible**
- **Claim:** A rollback script is available to instantly restore the gateway to a permissive routing state in case of a lockout.
- **Preconditions:** `rollback.sh` is created and marked as executable.
- **Test (positive):** Review the script contents: `sudo nft flush ruleset` followed by IP forwarding restoration.
- **Result:** The script is verified as functional.
- **Evidence:** `config/rollback.sh`.

---

**TD2-T05 — Admin access preserved**
- **Claim:** SSH access to the gateway (`gw-fw`) is maintained despite the Default-Deny INPUT policy.
- **Preconditions:** A specific rule allowing `tcp dport 22` was added to the INPUT chain before switching the policy to DROP.
- **Test (positive):** Maintain an active SSH session from the client machine to the `gw-fw` public interface.
- **Result:** Connection remained stable and active throughout the ruleset deployment.
- **Evidence:** The presence of the SSH allow rule in `config/firewall_ruleset.txt`.

---

**TD2-T06 — Rules are minimal and scoped**
- **Claim:** The firewall rules strictly follow the principle of least privilege, specifying source, destination, and ports without using overly broad `0.0.0.0/0` definitions.
- **Preconditions:** The flow matrix from TD1 is accurately translated into `nft` syntax.
- **Test:** Manual code review of the exported ruleset.
- **Result:** All DMZ allow rules restrict traffic to `ip daddr 10.10.20.10` and specific ports (80, 443, 22).
- **Evidence:** `config/firewall_ruleset.txt`.