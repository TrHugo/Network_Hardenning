# TD2 (3h) — Firewall Policy From Flows: Contract → Ruleset → Tests → Evidence

**Module:** Network Hardening (4th-year engineering)  
**Normative anchor:** NIST SP 800-41 Rev.1 (Guidelines on Firewalls and Firewall Policy)  
**Deliverable style:** "config + test + telemetry" evidence pack  
**Scope note:** Changes apply only to lab VMs. No scanning or changes outside the lab.

---

## 0) What you will build (end state)

TD2 turns TD1's **flow matrix** into a **minimal, auditable firewall policy** enforced on the network gateway.

You will deliver:

1. A written **policy.md** (zones, allow-list, default deny, logging strategy)
2. An exported **ruleset** (nftables or iptables) running on `gw-fw`
3. A **test plan** with positive and negative tests + telemetry evidence
4. An **evidence pack** proving that intent matches enforcement

> This TD is graded like a real change request: **intent, implementation, verification, proof**.

---

## 1) Prerequisites

### Lab environment (4-VM baseline)
Use the standard **4-VM baseline** from `0_technical_support/00_environment/README.md`:

| VM | Role in TD2 | Zone | IP |
|---|---|---|---|
| **gw-fw** | Policy enforcement point (FORWARD chain) | NH-LAN + NH-DMZ | 10.10.10.1 / 10.10.20.1 |
| **client** | Traffic generator, test executor | NH-LAN | 10.10.10.10 |
| **srv-web** | DMZ target service (HTTP, SSH) | NH-DMZ | 10.10.20.10 |
| **sensor-ids** | Capture validation (optional) | NH-DMZ | 10.10.20.50 |

The firewall ruleset is enforced on **`gw-fw`** because it sits between the LAN and DMZ — this is a **network-based** (forwarding) firewall, not a host-based firewall.

> **First time?** Follow `0_technical_support/TD1/TD1.md` for the fast-forward setup guide.

### From TD1 you should already have
- A network map (zones, trust boundaries)
- A flow matrix (what should talk to what, protocol/port, purpose)
- A short list of required services on `srv-web`

### Tools
- `nftables` (preferred) or `iptables` — firewall implementation
- `curl`, `nc`, `nmap` — test traffic generation
- `tcpdump` — optional capture on deny events
- `journalctl`, `/var/log/syslog` — log evidence

### Repo skeleton (standard across groups)
```
TD2_<Group>_<Date>/
  README.md
  report.md
  config/
    policy.md
    firewall_ruleset.txt
    rollback.sh
  tests/
    commands.txt
    TEST_CARDS.md
  evidence/
    counters_before.txt
    counters_after.txt
    deny_logs.txt
  appendix/
    failure_modes.md
```

---

## 2) Lab scope and safety

- Changes apply **only** to lab VMs.
- **Keep console access to `gw-fw` at all times** (VirtualBox console). Do not lock yourself out.
- Implement incrementally: add your access rule **before** setting default deny.
- No exploitation frameworks or scanning outside the lab.

---

## 3) Time plan (3 hours)

| Window | Activity |
|---|---|
| **0:00–0:25** | Translate TD1 flow matrix → `policy.md` |
| **0:25–1:20** | Implement ruleset on `gw-fw` (incremental) |
| **1:20–2:20** | Verification: ≥ 6 positive + ≥ 6 negative tests |
| **2:20–3:00** | Evidence pack + report + test cards |

---

## 4) Part A — Write the policy (intent, not syntax) (25 min)

Create `config/policy.md` with these sections:

### 4.1 Zones
List your zones and which assets belong to each:

| Zone | Network | Assets |
|---|---|---|
| LAN (trusted) | NH-LAN 10.10.10.0/24 | client (10.10.10.10) |
| DMZ (semi-trusted) | NH-DMZ 10.10.20.0/24 | srv-web (10.10.20.10), sensor-ids (10.10.20.50) |
| Gateway | Both interfaces | gw-fw (10.10.10.1 / 10.10.20.1) |

### 4.2 Allow-list (derived from TD1 flow matrix)
Copy your required flows and write them as policy statements:

Example format:
- **ALLOW** LAN → DMZ TCP/80 (HTTP to srv-web), purpose: web access, owner: TD1 baseline
- **ALLOW** LAN → DMZ TCP/22 (SSH to srv-web), purpose: admin access during lab
- **ALLOW** LAN → DMZ ICMP echo (diagnostics, limited rate)
- **ALLOW** established/related return traffic (stateful)

### 4.3 Default stance
- **FORWARD:** DROP (deny by default between zones)
- **INPUT on gw-fw:** DROP (protect the gateway itself)
- **OUTPUT from gw-fw:** ACCEPT (gateway can reach both subnets)

### 4.4 Logging strategy
- Log denied FORWARD traffic (rate-limited to avoid noise)
- Log sensitive allows (admin SSH)
- Tag log entries with a prefix for easy grep

### 4.5 Exception process
How exceptions are requested, who owns them, review date.

> A good policy is **short and unambiguous**. If a rule cannot be traced to a flow in the matrix, it should not exist.

---

## 5) Part B — Implement the ruleset on gw-fw (55 min)

Choose **one** tool (nftables or iptables) and stay consistent.

### Track A — nftables (recommended)

#### Step 1 — Confirm current state and enable forwarding
```bash
# On gw-fw
sudo nft list ruleset
sudo sysctl -w net.ipv4.ip_forward=1
```

#### Step 2 — Create table and chains
```bash
sudo nft add table inet filter

# Forward chain: controls LAN ↔ DMZ traffic
sudo nft add chain inet filter forward { type filter hook forward priority 0\; policy drop\; }

# Input chain: protects gw-fw itself
sudo nft add chain inet filter input { type filter hook input priority 0\; policy drop\; }

# Output chain: allow gw-fw to communicate
sudo nft add chain inet filter output { type filter hook output priority 0\; policy accept\; }
```

#### Step 3 — Essential allows (add BEFORE default deny takes effect)
```bash
# Loopback (always needed)
sudo nft add rule inet filter input iif lo counter accept

# Allow established/related (stateful tracking)
sudo nft add rule inet filter forward ct state established,related counter accept
sudo nft add rule inet filter input ct state established,related counter accept

# Allow SSH to gw-fw from LAN (keep your admin access!)
sudo nft add rule inet filter input ip saddr 10.10.10.0/24 tcp dport 22 counter accept
```

#### Step 4 — Add flow-matrix rules
```bash
# LAN → DMZ: HTTP
sudo nft add rule inet filter forward ip saddr 10.10.10.0/24 ip daddr 10.10.20.10 tcp dport 80 counter accept

# LAN → DMZ: HTTPS
sudo nft add rule inet filter forward ip saddr 10.10.10.0/24 ip daddr 10.10.20.10 tcp dport 443 counter accept

# LAN → DMZ: SSH (admin)
sudo nft add rule inet filter forward ip saddr 10.10.10.0/24 ip daddr 10.10.20.10 tcp dport 22 counter accept

# LAN → DMZ: ICMP (diagnostics, rate-limited)
sudo nft add rule inet filter forward ip saddr 10.10.10.0/24 ip daddr 10.10.20.0/24 icmp type echo-request limit rate 5/second counter accept
```

#### Step 5 — Logging for denied traffic
```bash
sudo nft add rule inet filter forward counter log prefix \"NFT_FWD_DENY \" limit rate 10/minute
sudo nft add rule inet filter input counter log prefix \"NFT_IN_DENY \" limit rate 10/minute
```

#### Step 6 — Export ruleset
```bash
sudo nft list ruleset | tee config/firewall_ruleset.txt
```

### Track B — iptables (accepted)

Same logic, iptables syntax:
```bash
# Flush and set defaults
sudo iptables -F
sudo iptables -P FORWARD DROP
sudo iptables -P INPUT DROP
sudo iptables -P OUTPUT ACCEPT

# Loopback
sudo iptables -A INPUT -i lo -j ACCEPT

# Stateful
sudo iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Admin SSH to gw-fw
sudo iptables -A INPUT -s 10.10.10.0/24 -p tcp --dport 22 -j ACCEPT

# LAN → DMZ allows
sudo iptables -A FORWARD -s 10.10.10.0/24 -d 10.10.20.10 -p tcp --dport 80 -j ACCEPT
sudo iptables -A FORWARD -s 10.10.10.0/24 -d 10.10.20.10 -p tcp --dport 443 -j ACCEPT
sudo iptables -A FORWARD -s 10.10.10.0/24 -d 10.10.20.10 -p tcp --dport 22 -j ACCEPT

# Logging (rate-limited)
sudo iptables -A FORWARD -m limit --limit 10/min -j LOG --log-prefix "IPT_FWD_DENY "

# Export
sudo iptables-save > config/firewall_ruleset.txt
```

### Engineering rules
- Do not "spray" ACCEPT rules. Keep each rule narrow (source, destination, port).
- Always export the ruleset **after** all changes.
- Write a `config/rollback.sh` that flushes rules and restores a permissive state.

---

## 6) Part C — Verification (prove behavior, not just config) (60 min)

### 6.1 Capture counters before testing
```bash
sudo nft list ruleset   # shows packet/byte counters per rule
# or
sudo iptables -L -v -n  # counters per rule
```
Save as `evidence/counters_before.txt`.

### 6.2 Positive tests (≥ 6)
Flows that **must work** according to your policy:

```bash
# From client (10.10.10.10):
# P1: HTTP to srv-web
curl -sI http://10.10.20.10 | head -5

# P2: HTTPS to srv-web (if TLS is up)
curl -skI https://10.10.20.10 | head -5

# P3: SSH to srv-web
ssh -o ConnectTimeout=3 adminX@10.10.20.10 whoami

# P4: ICMP to srv-web
ping -c 2 10.10.20.10

# P5: SSH to gw-fw (admin access preserved)
ssh -o ConnectTimeout=3 adminX@10.10.10.1 whoami

# P6: ICMP to gw-fw
ping -c 2 10.10.10.1
```

### 6.3 Negative tests (≥ 6)
Flows that **must fail** (blocked by default deny):

```bash
# From client (10.10.10.10):
# N1: Random high port on srv-web
nc -vz -w 3 10.10.20.10 12345

# N2: MySQL port (not in matrix)
nc -vz -w 3 10.10.20.10 3306

# N3: DNS on srv-web (if not offered)
nc -vuz -w 3 10.10.20.10 53

# N4: Telnet (should not exist)
nc -vz -w 3 10.10.20.10 23

# From srv-web (10.10.20.10) — test reverse direction:
# N5: DMZ → LAN should be blocked (if policy says so)
nc -vz -w 3 10.10.10.10 22

# N6: DMZ → gw-fw SSH (if not allowed from DMZ)
nc -vz -w 3 10.10.20.1 22
```

### 6.4 Capture counters after testing
```bash
sudo nft list ruleset | tee evidence/counters_after.txt
```

Compare counter changes: the deny counter should have incremented for your negative tests.

### 6.5 Collect log evidence
```bash
# On gw-fw
sudo journalctl -k --since "1 hour ago" | grep -E "NFT_FWD_DENY|IPT_FWD_DENY" \
  | tail -20 | tee evidence/deny_logs.txt
```

Each negative test should produce a corresponding log entry with source IP, destination IP, and port.

---

## 7) Deliverables

### 7.1 Evidence Pack report (`report.md`)
Structure:
1. **Topology summary** (4-VM table, zone diagram)
2. **Policy statement** (reference `config/policy.md`)
3. **Implementation notes** (nftables or iptables, key decisions)
4. **Test results** (positive/negative summary table with evidence references)
5. **Counter analysis** (before/after showing deny hits)
6. **Known limitations** (what you did not implement: egress control, DMZ→LAN, etc.)

### 7.2 Repo checklist
- [ ] Clean README (topology + how to reproduce)
- [ ] `config/policy.md` — plain-English policy
- [ ] `config/firewall_ruleset.txt` — exported ruleset
- [ ] `config/rollback.sh` — emergency flush script
- [ ] `tests/commands.txt` — all test commands
- [ ] `evidence/` — counters, logs, test outputs
- [ ] `tests/TEST_CARDS.md` — ≥ 6 test cards (see §8)
- [ ] `appendix/failure_modes.md`

---

## 8) Test cards (required, ≥ 6)

Add cards to `tests/TEST_CARDS.md` using the standard template from `0_technical_support/_shared/templates/test_card_template.md`. Separate each card with a `---` horizontal rule.

### Suggested claims

**TD2-T01 — Allowed flows from matrix pass**  
**Claim:** HTTP (TCP/80) from LAN to srv-web is forwarded by gw-fw.  
**Test (positive):** `curl -sI http://10.10.20.10` returns HTTP 200  
**Evidence:** `evidence/counters_after.txt`

**TD2-T02 — Default deny blocks unlisted traffic**  
**Claim:** Traffic to ports not in the allow-list is dropped.  
**Test (negative):** `nc -vz -w 3 10.10.20.10 12345` → connection refused/timeout  
**Evidence:** `evidence/deny_logs.txt`

**TD2-T03 — Denied traffic produces telemetry**  
**Claim:** Blocked forwarded packets generate log entries on gw-fw.  
**Test:** Send blocked traffic, grep logs for `NFT_FWD_DENY`  
**Evidence:** `evidence/deny_logs.txt`

**TD2-T04 — Ruleset is reversible**  
**Claim:** `rollback.sh` restores a permissive state within 30 seconds.  
**Test (positive):** Run rollback, verify all traffic passes  
**Evidence:** `config/rollback.sh`

**TD2-T05 — Admin access preserved**  
**Claim:** SSH from LAN to gw-fw works at all times.  
**Test (positive):** `ssh adminX@10.10.10.1 whoami` succeeds  
**Test (negative):** SSH from DMZ to gw-fw is blocked  
**Evidence:** `evidence/positive_tests/`

**TD2-T06 — Rules are minimal and scoped**  
**Claim:** Each rule specifies source, destination, and port (no any-any).  
**Test:** Review exported ruleset; count rules  
**Evidence:** `config/firewall_ruleset.txt`

**TD2-T07 (bonus) — Counter analysis shows enforcement**  
**Claim:** Deny counter increases after negative tests.  
**Test:** Compare `counters_before.txt` vs `counters_after.txt`  
**Evidence:** `evidence/counters_before.txt`, `evidence/counters_after.txt`

---

## 9) Grading rubric (100 points)

| Category | Points | Key criteria |
|---|---|---|
| **Policy quality** | 35 | Least privilege, clear zones, traceable to flow matrix |
| **Implementation correctness** | 25 | Forwarding rules on gw-fw, stateful, no over-permitting |
| **Verification + evidence** | 30 | ≥ 6 positive + ≥ 6 negative, log/counter proof |
| **Maintainability** | 10 | Rollback script, clean repo, test cards ≥ 6 |

---

## Appendix A — Common failure modes

Document relevant items in `appendix/failure_modes.md`:

| ID | Failure | Symptom | Fix |
|---|---|---|---|
| FM-01 | IP forwarding disabled | LAN↔DMZ traffic never arrives | `sysctl -w net.ipv4.ip_forward=1` on gw-fw |
| FM-02 | Default DROP before allow rules | Everything breaks instantly | Add essential allows first, then change policy |
| FM-03 | Loopback forgotten | Local services on gw-fw fail | `nft add rule ... iif lo accept` |
| FM-04 | Stateful rule missing | Return traffic blocked | Add `ct state established,related accept` |
| FM-05 | Rules on wrong chain | INPUT vs FORWARD confusion | FORWARD = transit traffic; INPUT = to gw-fw |
| FM-06 | Logging noise | Syslog flooded, VM sluggish | Rate-limit log rules (`limit rate 10/minute`) |
| FM-07 | Rules too broad | `0.0.0.0/0` allows everything | Scope each rule to specific src/dst/port |
| FM-08 | NAT confusion | Unexpected address translation | Do not add NAT unless explicitly required |

---

## Appendix B — Troubleshooting

- **Locked out of gw-fw:** Use the VirtualBox console (not SSH). Flush rules: `nft flush ruleset` or `iptables -F && iptables -P INPUT ACCEPT && iptables -P FORWARD ACCEPT`
- **Counters not moving:** Verify you are testing from the correct VM and that traffic traverses gw-fw (not bypassing it).
- **Service still reachable after deny:** Check that the service is reached through gw-fw (FORWARD), not locally. Verify you are testing the right port.
- **"Connection refused" vs timeout:** Refused = service is reached but port is closed; timeout = traffic was dropped (firewall). Both are valid negative results but mean different things.

---

## Appendix C — Recommended reading

- NIST SP 800-41 Rev.1 — Guidelines on Firewalls and Firewall Policy: <https://csrc.nist.gov/pubs/sp/800/41/r1/final>
- Linux Firewalls with nftables: <https://wiki.nftables.org/wiki-nftables/index.php/Quick_reference-nftables_in_10_minutes>
- Suehring, S. — *Linux Firewalls: Enhancing Security with nftables and Beyond* (4th ed.)
