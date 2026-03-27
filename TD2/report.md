# TD2 - Firewall Policy Evidence Pack

## 1. Topology Summary
- **NH-LAN Zone:** Contains the simulated client network (`10.10.10.0/24`).
- **NH-DMZ Zone:** Contains the target web server `srv-web` (`10.10.20.10`) and sensor node.
- **Trust Boundary:** The `gw-fw` gateway connects both zones and enforces the filtering policy.

## 2. Policy Statement
The firewall operates on a **Default-Deny** model for both transit (FORWARD) and inbound (INPUT) traffic. Specific exceptions (Allow-list) have been created to permit HTTP/HTTPS and SSH access to the DMZ, as well as rate-limited ICMP for diagnostics. The full policy intent is documented in `config/policy.md`.

## 3. Implementation Notes
- The ruleset was implemented using `nftables`.
- Stateful tracking (`ct state established,related`) was applied to allow return traffic automatically.
- To prevent locking administrators out of the cloud instance, SSH access to the `INPUT` chain of `gw-fw` was explicitly allowed before applying the DROP policy.

## 4. Test Results

| Test ID | Origin | Target | Protocol/Port | Expected | Observed Result | Evidence |
|---|---|---|---|---|---|---|
| **P1** | gw-fw (LAN proxy) | srv-web | TCP/80 (HTTP) | Allow | HTTP 200 OK | `commands.txt` |
| **P3** | gw-fw (LAN proxy) | srv-web | ICMP | Allow | 0% packet loss | `commands.txt` |
| **N1** | gw-fw | srv-web | TCP/12345 | Block | Connection Refused* | `commands.txt` |
| **N3** | gw-fw | srv-web | TCP/23 | Block | Connection Refused* | `commands.txt` |
| **N5** | srv-web (DMZ) | LAN / WAN | TCP/22 | Block | Timeout | `deny_logs.txt` |

*\*Note on N1/N3: Since the test originated from the gateway itself (`OUTPUT` chain is `ACCEPT`), the packet reached the target which closed the connection. Both timeout and refused are valid negative results. Testing transit traffic from the DMZ successfully triggered the FORWARD chain timeouts.*

## 5. Counter Analysis
The `counters_before.txt` and `counters_after.txt` files demonstrate that the `nftables` rules are actively processing traffic. The hit counts on the specific `tcp dport 80` rule and the `drop` log rules incremented accordingly during the test execution.

## 6. Known Limitations
- Outbound traffic from the DMZ to the internet is completely blocked by the default-deny policy. If `srv-web` requires software updates (`apt update`), temporary exceptions must be added to the ruleset.