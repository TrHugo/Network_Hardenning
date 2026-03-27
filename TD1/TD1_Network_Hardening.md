# TD1 (3h) — Network Baseline for Hardening

**Module:** Network Hardening (4th-year engineering)  
**Normative anchor:** Network baselining best practices — asset inventory (NIST SP 800-53 CM-8), flow analysis, and risk-driven observation  
**Deliverable style:** "map + matrix + capture + risk" evidence pack  
**Scope note:** All discovery and capture stay inside the lab. No scanning outside.

---

## 0) What you will build (end state)

You cannot harden what you cannot **describe**. TD1 produces an auditable baseline that every subsequent TD depends on.

You will deliver:

1. A **network map** (zones, assets, trust boundaries)
2. A **flow matrix** (what should talk to what, on which protocol/port, and why)
3. A **baseline capture** (pcap) with **annotated observations**
4. A short **risk list + quick wins** grounded in evidence

This TD is intentionally "boring" in the best way: it creates the foundation that makes CM2 and TD2 rigorous.

---

## 1) Lab scope and ethics
- All discovery, scanning, and packet capture are performed **only inside the authorized lab network**.
- Do not scan or capture traffic on public networks, campus networks, or personal home networks.
- If something looks like a misconfiguration or an unintended exposure in the lab, **document it**; do not "improvise" beyond the assignment.

---

## 2) Prerequisites (before class)

### Lab environment (4-VM baseline)
Use the standard **4-VM baseline** described in `0_technical_support/00_environment/README.md`:

| VM | Role | Zone | IP |
|---|---|---|---|
| **gw-fw** | Gateway / firewall / trust boundary | NH-LAN + NH-DMZ | 10.10.10.1 / 10.10.20.1 |
| **client** | Scanner, traffic generator, evidence collector | NH-LAN | 10.10.10.10 |
| **srv-web** | Target services (HTTP, HTTPS, SSH) | NH-DMZ | 10.10.20.10 |
| **sensor-ids** | Promiscuous capture, IDS validation | NH-DMZ | 10.10.20.50 |

All VMs must be on their assigned VirtualBox Internal Networks (`NH-LAN` 10.10.10.0/24, `NH-DMZ` 10.10.20.0/24).

> **First time?** Follow `0_technical_support/TD1/TD1.md` for the fast-forward setup guide before starting this lab.

### Tools
- Wireshark or tcpdump (capture)
- Nmap (inventory only)
- Standard Linux commands: `ip`, `ss`, `systemctl`, `traceroute`, `dig` (if available)

---

## 3) Time plan (3 hours)
**0:00–0:20** Pre-flight checks, role assignment, confirm IP plan

**0:20–1:10** Discovery and mapping (zones, assets, services)

**1:10–1:50** Flow matrix draft + validate at least 5 flows

**1:50–2:25** Baseline capture + 5 annotated observations

**2:25–3:00** Risk list + quick wins + test cards + submission packaging

---

## 4) Step-by-step instructions

### Part A — Identify zones and assets (mapping)
**Output:** one slide (or one page) network map — `diagram.pdf` (or `diagram.pptx`).

1. On each VM, record:
   - IP address, subnet mask, default gateway
   - host name and OS
   - running services and listening ports

   Commands to run on **every** VM:
   ```bash
   hostname
   ip addr
   ip route
   ss -tulpn
   ```

2. The lab defines two zones and one trust boundary:

   | Zone | Subnet | VMs |
   |---|---|---|
   | **LAN** (NH-LAN) | 10.10.10.0/24 | `client` (10.10.10.10) |
   | **DMZ** (NH-DMZ) | 10.10.20.0/24 | `srv-web` (10.10.20.10), `sensor-ids` (10.10.20.50) |
   | **Trust boundary** | — | `gw-fw` bridges LAN ↔ DMZ (10.10.10.1 / 10.10.20.1) |

   Optionally add a **Management** zone if admin interfaces exist, and a **Monitoring** zone if you centralize logs.

3. Draw the diagram:
   - Use rectangles for zones (LAN, DMZ)
   - Use boxes for VMs and key services
   - Mark `gw-fw` as the trust boundary between zones
   - Use plain lines for connectivity (no arrowheads)
   - Add a legend (VM names, IP ranges, services per host)

**Quality gate:** A classmate should be able to reconstruct your topology using your diagram and README.

---

### Part B — Build the expected flow matrix
**Output:** `reachability_matrix.csv` (or `.xlsx`) with these columns:

| ID | Source zone | Source asset | Destination zone | Destination asset | Proto | Port | Purpose | Owner | Status |
|---|---|---|---|---|---|---|---|---|---|

Rules:
- Every **ALLOW** must have a **purpose**.
- If you cannot justify it, mark the Status as **REVIEW**.
- Add an "Owner" field: who depends on this flow (team role, service owner).
- Keep it minimal: **least privilege by design**.

Minimum required flows (adapt to your observations):
- LAN → DMZ: HTTP/80 and/or HTTPS/443 (application testing)
- LAN → DMZ: SSH/22 **only if explicitly needed** (remote admin)
- LAN → GW: DNS/53, NTP/123 (if running locally)
- ICMP: connectivity checks (if used)

---

### Part C — Validate reachability (inventory and evidence)
**Output:** evidence files in `tests/commands.txt` and `evidence/nmap_srvweb.txt`.

From `client` (10.10.10.10):

1. Confirm addressing and routes:
   ```bash
   ip addr
   ip route
   ```

2. Identify listening services on `srv-web`:
   ```bash
   ssh <user>@10.10.20.10 "ss -tulpn"
   ```

3. Defensive scan (DMZ host only):
   ```bash
   nmap -sS -sV -p 1-1000 10.10.20.10
   ```

4. Record results:
   - Which ports are open
   - What services/versions are detected (if any)
   - Which of these are expected according to your flow matrix
   - Which are **unexpected** (flag as risks)

**Important:** This is *defensive inventory*. Do not use exploit modules or password guessing tools.

---

### Part D — Baseline packet capture and annotations
**Output:** `evidence/baseline.pcap` + at least 5 annotated observations in `report.md`.

On `sensor-ids` (preferred, promiscuous mode) or `client`, capture 5–10 minutes:
```bash
sudo tcpdump -i <iface> -w evidence/baseline.pcap -nn
```

Generate representative traffic from `client`:
- `curl http://10.10.20.10` (HTTP)
- `curl -k https://10.10.20.10` (HTTPS, if configured)
- `dig @10.10.20.1 example.com` (DNS, if running)
- `ping 10.10.20.10` (ICMP)
- SSH session to `srv-web` (if used)

You can also open the pcap in Wireshark for analysis. Suggested display filters:
- `dns`
- `tcp.port == 22`
- `http`
- `tls`

**Five required observations** (minimum):
For each observation, use the template in Appendix B:
- timestamp range
- flow matrix row reference (by ID)
- what you observed (facts)
- why it matters for hardening
- what control you would propose (for TD2/TD3/TD4)
- evidence pointer (pcap packet number / command output)

---

### Part E — Risk list and quick wins
**Output:** risk and quick-win sections in `report.md`.

Create:
- **Top 10 risks** ranked by **Impact** and **Ease of exploitation**
- **Top 5 quick wins** (high impact, low cost)

Examples of quick wins (only claim what your evidence supports):
- Close or restrict unnecessary services on `srv-web`
- Implement firewall policy on `gw-fw` (TD2)
- Separate management access from application traffic
- Reduce east-west reachability between LAN and DMZ
- Add deny logging at `gw-fw` boundary
- Make outbound connectivity explicit

---

## 5) Deliverables
Submit using the standard evidence-pack layout:

```
TD1_<Group>_<YYYY-MM-DD>/
  README.md
  report.md
  diagram.pdf
  reachability_matrix.csv
  config/
  tests/
    commands.txt
    TEST_CARDS.md
  evidence/
    baseline.pcap
    nmap_srvweb.txt
  appendix/
    failure_modes.md
```

`README.md` must include:
- team members + roles
- lab topology summary (VM names, IPs, zones)
- what you tested and how
- known limitations

---

## 6) Grading rubric (100)
- Network map correctness and clarity (25)
- Flow matrix completeness and justification (25)
- Evidence quality (pcap + annotations + test cards) (25)
- Risk ranking + quick wins rationale (25)

---

## 7) Recommended O'Reilly reading (fast ramp)

These three sources map directly to the TD1 deliverables:

- **Practical Packet Analysis** (Wireshark workflow, capture strategy, interpretation)
  - https://learning.oreilly.com/library/view/practical-packet-analysis/9781593271497/ch08s03.html
- **Applied Network Security Monitoring** (how to turn traffic + logs into detection signals)
  - https://learning.oreilly.com/library/view/applied-network-security/9780124172081/xhtml/Cover.xml
- **Network Security, Firewalls, and VPNs (3rd ed.)** (policy mindset, threat and countermeasure framing)
  - https://learning.oreilly.com/library/view/network-security-firewalls/9781284183696/xhtml/11_chapter02_18.xhtml

---

## 8) Test cards (required)
Create **at least 4** test cards in `tests/TEST_CARDS.md`, using `0_technical_support/_shared/templates/test_card_template.md`. Separate each card with a `---` horizontal rule:

- **TD1-T01:** "Client can reach srv-web on required service (HTTP/HTTPS)"
- **TD1-T02:** "Unexpected port on srv-web is closed or flagged as risk"
- **TD1-T03:** "Baseline capture includes HTTP/HTTPS and DNS traffic (if used)"
- **TD1-T04:** "Topology diagram matches observed addressing and routes"

Each test card must include: Claim → Preconditions → Config fragment → Test method (positive + negative) → Telemetry → Result → Artifacts.

---

## Appendix A — Example flow matrix rows (copy/paste)

| ID | Source zone | Source asset | Destination zone | Destination asset | Proto | Port | Purpose | Owner | Status |
|---|---|---|---|---|---|---|---|---|---|
| F01 | LAN | client | DMZ | srv-web | TCP | 22 | remote admin during TD only | instructor | ALLOW — restrict by source IP |
| F02 | LAN | any | DMZ | srv-web (DNS) | UDP/TCP | 53 | name resolution | lab | ALLOW — log failures |
| F03 | LAN | any | DMZ | srv-web (NTP) | UDP | 123 | time sync for logs | lab | ALLOW — only to NTP server |
| F04 | LAN | client | DMZ | srv-web | TCP | 80/443 | application test | app owner | ALLOW — prefer TLS |
| F05 | LAN | client | DMZ | srv-web | ICMP | — | connectivity check | lab | REVIEW |
| F06 | DMZ | srv-web | LAN | client | TCP | — | response traffic | auto | ALLOW (stateful) |
| F07 | any | any | any | any | any | any | default deny | security | DENY — log |

## Appendix B — Observation card template

Use this structure in `report.md` for each observation:

**Observation ID:** O1

- **Time range:**
- **Flow reference (row ID):**
- **What I saw (facts):**
- **Why it matters:**
- **Proposed control:**
- **Evidence pointer:** (pcap packet number / screenshot / command output)

## Appendix C — Submission naming standard (3 groups)

Use this exact naming to keep grading consistent:

`TD1_<GroupID>_<TeamName>_<YYYY-MM-DD>.zip`

Inside the zip, keep the same tree as in Section 6.

---

## 9) Troubleshooting (common)
- **No traffic in Wireshark/tcpdump:** verify interface selection and that `sensor-ids` has promiscuous mode enabled ("Allow All" in VirtualBox).
- **Nmap sees nothing:** verify subnet, IP addresses, and that VMs are on the correct VirtualBox Internal Networks (`NH-LAN`, `NH-DMZ`).
- **Client cannot reach srv-web:** check that `gw-fw` has IP forwarding enabled (`sysctl net.ipv4.ip_forward`) and correct routes.
- **DNS or updates fail:** check whether internet access is intentionally blocked (NAT adapter should be disabled during TDs).

---

## Appendix D — Common failure modes (TD1-specific)
Add `appendix/failure_modes.md` and document any issues. Typical TD1 failures:
- VMs on different VirtualBox internal networks (no L2 adjacency within a zone)
- Wrong default gateway on `srv-web` or `client` (routing fails between LAN and DMZ)
- `gw-fw` IP forwarding not enabled (LAN↔DMZ traffic drops silently)
- Baseline pcap too big (ungradeable) or contains no relevant traffic
- Evidence missing timestamps and claim linkage
