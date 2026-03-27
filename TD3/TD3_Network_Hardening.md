# TD3 (3h) — IDS/IPS: Detection Engineering with Proof (Suricata / Snort)

**Module:** Network Hardening (4th-year engineering)  
**Normative anchor:** NIST SP 800-94 (Guide to Intrusion Detection and Prevention Systems)  
**Deliverable style:** "config + test + telemetry" evidence pack  
**Scope note:** All traffic generation and detection stay inside the lab.

---

## 0) What you will build (end state)

Prevention fails. Detection buys you time and clarity — **if** sensors see the right traffic and alerts are tuned to your environment.

TD3 is not "run IDS and screenshot alerts". It is:

1. **Sensor placement** → prove the sensor actually sees relevant flows.
2. **Deterministic detection** → trigger a known alert with a reproducible command.
3. **One custom rule** → scoped, versioned, testable.
4. **One tuning action** → before/after evidence proving noise reduction without hiding risk.
5. **A professional evidence pack** an auditor can replay.

---

## 1) Prerequisites

### Lab environment (4-VM baseline)
Use the standard **4-VM baseline** from `0_technical_support/00_environment/README.md`:

| VM | Role in TD3 | Zone | IP |
|---|---|---|---|
| **gw-fw** | Boundary context, optional log correlation | NH-LAN + NH-DMZ | 10.10.10.1 / 10.10.20.1 |
| **client** | Traffic generator (scans, test requests) | NH-LAN | 10.10.10.10 |
| **srv-web** | Target service (HTTP, SSH) | NH-DMZ | 10.10.20.10 |
| **sensor-ids** | IDS engine (Suricata/Snort) + packet capture | NH-DMZ | 10.10.20.50 |

**Key design choice:** `sensor-ids` sits on the DMZ segment in **promiscuous mode**, so it sees all traffic entering and leaving the DMZ — including traffic between `gw-fw` and `srv-web`.

> **First time?** Follow `0_technical_support/TD1/TD1.md` for the fast-forward setup guide.

### From TD1/TD2 you should already have
- A network map with zones and trust boundaries
- A flow matrix (TD1) and a firewall policy (TD2)
- Familiarity with traffic between `client` and `srv-web`

### Tools
- **Suricata** (recommended) or **Snort** — IDS engine
- `tcpdump` / Wireshark — capture validation
- `nmap` — deterministic scan trigger
- `curl`, `nc` — application-level test traffic

### Repo skeleton (standard across groups)
```
TD3_<Group>_<Date>/
  README.md
  report.md
  config/
    suricata.yaml (or snort.conf excerpt)
    local.rules
    interface_selection.txt
  tests/
    commands.txt
    TEST_CARDS.md
  evidence/
    visibility_proof.txt
    alerts_excerpt.txt
    before_after_counts.txt
    optional_trigger.pcap
  appendix/
    failure_modes.md
```

---

## 2) Lab scope and safety

- Traffic generation targets **only** lab VMs (10.10.10.0/24, 10.10.20.0/24).
- Do not run scans against external networks.
- Assign team roles: **Operator** (runs IDS), **Evidence keeper** (captures/logs), **Reporter** (writes report).

---

## 3) Time plan (3 hours)

| Window | Activity | Checkpoint |
|---|---|---|
| **0:00–0:15** | Roles + pre-flight + interface selection | — |
| **0:15–0:50** | Install IDS + confirm visibility | Proof #1 |
| **0:50–1:20** | Deterministic trigger with community rules | Proof #2 |
| **1:20–2:00** | Write + test one custom rule | Proof #3 |
| **2:00–2:30** | Tuning action (threshold/suppress) + before/after | Proof #4 |
| **2:30–3:00** | Packaging + report + test cards | — |

---

## 4) Part A — Install and verify visibility (35 min)

Choose **one** engine and stay with it for the whole lab.

### Option A — Suricata (recommended)
On `sensor-ids`:
```bash
sudo apt update && sudo apt install -y suricata
```

Identify the monitoring interface (should be on NH-DMZ):

> **⚠ Interface name:** Examples below use `enp0s8`. Your actual interface depends on the VirtualBox adapter slot. Run `ip link` on `sensor-ids` and substitute the correct name throughout this section.

```bash
ip link
# Look for the interface connected to NH-DMZ (e.g., enp0s8)
```

Enable promiscuous mode:
```bash
sudo ip link set enp0s8 promisc on
```

Configure `HOME_NET` in `/etc/suricata/suricata.yaml`:
```yaml
vars:
  address-groups:
    HOME_NET: "[10.10.10.0/24, 10.10.20.0/24]"
```

Set the monitoring interface:
```yaml
af-packet:
  - interface: enp0s8
```

Start Suricata:
```bash
sudo suricata -c /etc/suricata/suricata.yaml -i enp0s8
```

### Option B — Snort
Same concept: install, configure `HOME_NET`, set interface, start.

### Verification checkpoint #1 — Sensor sees traffic
Generate traffic from `client`:
```bash
curl -s http://10.10.20.10/ > /dev/null
ping -c 3 10.10.20.10
```

On `sensor-ids`, confirm packets are visible:
```bash
sudo tcpdump -i enp0s8 -c 10 'host 10.10.20.10'
```

Save:
- `evidence/visibility_proof.txt` (tcpdump output showing client → srv-web traffic)
- `config/interface_selection.txt` (which interface, why)

> If the sensor sees zero packets, check: VirtualBox promiscuous mode setting ("Allow All"), correct Internal Network assignment, correct interface in config.

---

## 5) Part B — Deterministic trigger (community rules) (30 min)

Enable a community ruleset (Suricata ships with ET Open rules, or download):
```bash
sudo suricata-update
sudo systemctl restart suricata
```

Generate a **reproducible** trigger from `client`:
```bash
# Example: Nmap scan that triggers IDS alerts
nmap -sS -sV -p 1-1000 10.10.20.10
```

Check for alerts on `sensor-ids`:
```bash
sudo tail -f /var/log/suricata/fast.log
# or for JSON:
sudo tail -f /var/log/suricata/eve.json | jq 'select(.event_type=="alert")'
```

### Verification checkpoint #2
- Save the **exact command** used to generate traffic → `tests/commands.txt`
- Save the **alert line(s)** showing `sid`, signature name, and timestamp → `evidence/alerts_excerpt.txt`
- Confirm the alert matches the traffic you sent (source IP = 10.10.10.10, destination = 10.10.20.10)

---

## 6) Part C — Write one custom rule (40 min)

Create a custom rule in `config/local.rules`:

### Example — detect HTTP requests to a specific path
```
alert http $HOME_NET any -> $HOME_NET 80 (
    msg:"TD3 CUSTOM - HTTP request to /admin detected";
    flow:to_server,established;
    http.uri; content:"/admin";
    sid:9000001; rev:1;
    classtype:policy-violation;
)
```

### Requirements
- Target a **specific** flow direction (`->`)
- Constrain by HOME_NET, port(s), and protocol
- Include `sid` (start at 9000001+), `rev`, and descriptive `msg`
- Provide a **deterministic trigger** that fires only when expected

### Test the custom rule
```bash
# From client
curl -s http://10.10.20.10/admin
```

Check `fast.log` for your custom `sid`.

### Verification checkpoint #3
- Save rule text → `config/local.rules`
- Save trigger command → `tests/commands.txt`
- Save matching alert line → `evidence/alerts_excerpt.txt`

---

## 7) Part D — Tuning action (before / after) (30 min)

Pick a rule that generates too many alerts in your lab and apply **one** tuning action:

### Option 1 — Threshold (rate-limit alerts)
```
threshold gen_id 1, sig_id <noisy_sid>, type limit, track by_src, count 1, seconds 60
```

### Option 2 — Suppression (ignore known benign source)
```
suppress gen_id 1, sig_id <noisy_sid>, track by_src, ip 10.10.10.10
```

### Option 3 — Scope narrowing
Modify the rule to constrain ports, flowbits, or content more tightly.

### Evidence — before / after
1. Run the same test traffic **before** tuning → count alerts
2. Apply tuning
3. Run the **same** test traffic **after** tuning → count alerts

```bash
# Count alerts for a specific SID
grep "sid:<noisy_sid>" /var/log/suricata/fast.log | wc -l
```

### Verification checkpoint #4
- Show before count vs after count → `evidence/before_after_counts.txt`
- Explain why tuning improves actionability without hiding real risk

---

## 8) Deliverables

### 8.1 Evidence Pack report (`report.md`)
Structure:
1. **Topology and sensor placement** (4-VM table, interface, promiscuous mode)
2. **What you detected** and why it matters (community rule alert)
3. **Custom rule** (full text, explain scope + intent)
4. **Tuning action** (before/after + rationale)
5. **Limitations** (TLS blindness, sensor placement gaps, asymmetric routing)

### 8.2 Repo checklist
- [ ] Clean README (topology + how to reproduce)
- [ ] `config/` — engine config excerpt, `local.rules`, interface selection
- [ ] `tests/commands.txt` — all trigger commands with timestamps
- [ ] `evidence/` — visibility proof, alerts, before/after counts
- [ ] `tests/TEST_CARDS.md` — ≥ 6 test cards (see §9)
- [ ] `appendix/failure_modes.md`

---

## 9) Test cards (required, ≥ 6)

Add cards to `tests/TEST_CARDS.md` using the standard template from `0_technical_support/_shared/templates/test_card_template.md`. Separate each card with a `---` horizontal rule.

### Suggested claims

**TD3-T01 — Sensor sees DMZ traffic**
**Claim:** `sensor-ids` in promiscuous mode captures HTTP traffic between `client` and `srv-web`.
**Test (positive):** `curl` from client, `tcpdump` on sensor-ids shows the packets
**Evidence:** `evidence/visibility_proof.txt`

**TD3-T02 — Community rule triggers deterministically**
**Claim:** A known scan pattern generates an alert with correct `sid` and source/destination IPs.
**Test (positive):** `nmap -sS -sV` from client → alert in `fast.log`
**Evidence:** `evidence/alerts_excerpt.txt`

**TD3-T03 — Custom rule triggers on intended traffic**
**Claim:** Custom `sid:9000001` fires when `client` requests `/admin` on `srv-web`.
**Test (positive):** `curl http://10.10.20.10/admin` → alert with custom sid
**Test (negative):** `curl http://10.10.20.10/index.html` → no alert for that sid
**Evidence:** `evidence/alerts_excerpt.txt`

**TD3-T04 — Custom rule is scoped and versioned**
**Claim:** Rule specifies HOME_NET, port 80, flow direction, and has `sid`/`rev`.
**Test:** Review `config/local.rules`; verify fields are present
**Evidence:** `config/local.rules`

**TD3-T05 — Tuning reduces noise without hiding risk**
**Claim:** After threshold/suppression, alert count drops for the same test traffic.
**Test:** Compare before/after counts for identical test runs
**Evidence:** `evidence/before_after_counts.txt`

**TD3-T06 — Evidence is reproducible**
**Claim:** Running the documented commands on the same topology produces matching alerts.
**Test:** Re-run `tests/commands.txt` and verify `fast.log` output matches
**Evidence:** `tests/commands.txt`, `evidence/alerts_excerpt.txt`

**TD3-T07 (bonus) — Sensor placement justification**
**Claim:** Placing the sensor on NH-DMZ provides visibility for LAN→DMZ attacks but not LAN-internal traffic.
**Test:** Generate LAN-only traffic; confirm sensor does NOT see it
**Evidence:** `evidence/visibility_proof.txt` (negative case)

---

## 10) Grading rubric (100 points)

| Category | Points | Key criteria |
|---|---|---|
| **Setup + observability** | 20 | Engine runs, correct interface, visibility proof |
| **Deterministic trigger** | 20 | Reproducible command, matching alert with sid/timestamp |
| **Custom rule quality** | 25 | Scoped, versioned, testable, low noise, good metadata |
| **Tuning quality** | 20 | Before/after evidence, clear justification |
| **Maintainability** | 15 | Clean repo, README reproducibility, test cards ≥ 6 |

---

## Appendix A — Common failure modes

Document relevant items in `appendix/failure_modes.md`:

| ID | Failure | Symptom | Fix |
|---|---|---|---|
| FM-01 | Wrong interface selected | Zero alerts despite traffic | Check `ip link`; match VirtualBox adapter to NH-DMZ |
| FM-02 | Promiscuous mode off | Sensor only sees broadcast/own traffic | `ip link set <iface> promisc on` + VirtualBox "Allow All" |
| FM-03 | Encrypted traffic | Payload rules cannot match | Use metadata (SNI, JA3) or move sensor to cleartext segment |
| FM-04 | Rule scope too broad | Alerts on everything, not actionable | Narrow: specific ports, flow direction, content match |
| FM-05 | No threshold on noisy rule | Log fills up, real alerts buried | Add threshold/suppression + document rationale |
| FM-06 | Time mismatch between VMs | Alert timestamps don't correlate | Sync clocks (`timedatectl set-ntp true`) |
| FM-07 | Asymmetric routing | Session tracking breaks | Place sensor where both directions pass |

---

## Appendix B — Troubleshooting

- **No alerts at all:** Confirm interface, check `suricata.yaml` for correct `af-packet` interface, verify rules are loaded (`suricata --list-keywords` or check rule count in logs).
- **Rule not firing:** Check scope: `HOME_NET`, port, flow direction, protocol. Use `suricata -T` to validate config.
- **Too many alerts:** Start with threshold; do not suppress globally.
- **fast.log empty but eve.json has data:** Fast log may be disabled; check `outputs` section in config.

---

## Appendix C — Extensions (bonus)

- Add a second sensor location (LAN side via `gw-fw`) and compare what each sensor sees.
- Produce a "triage table" for 5 alert types: signal → context needed → first action.
- Map 3 detections to OSI layers and propose a matching countermeasure at each layer.
- Test IDS with TD2's firewall active: does the firewall block before the IDS alerts?
