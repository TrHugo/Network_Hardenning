# TD5 (3h) — Secure Remote Access: SSH Hardening + Site-to-Site IPsec VPN (IKEv2)

**Module:** Network Hardening (4th-year engineering)  
**Normative anchor:** NIST SP 800-77 Rev.1 (Guide to IPsec VPNs) + security engineering best practices  
**Deliverable style:** "config + test + telemetry" evidence pack  
**Scope note:** Everything stays inside the lab. No scanning or brute-force outside the lab.

---

## 0) What you will build (end state)

Remote access is where secure designs go to die: "temporary" SSH keys, shared credentials, VPN tunnels that silently drift from intended policy.

You will deliver a secure remote-access pattern that does **not** rely on trust-by-location:

1. **A hardened SSH endpoint** (bastion mindset: key-only, scoped users, auditable).
2. **A site-to-site IPsec VPN (IKEv2)** connecting two gateways via strongSwan.
3. **A policy statement** ("who can admin what, from where") translated into:
   - configuration fragments,
   - a minimal test plan (positive + negative),
   - and an evidence bundle (logs / counters / pcaps).

> The point is not "SSH is secure" or "VPN is secure".
> The point is: **you can prove what is allowed, what is blocked, and why**.

---

## 1) Prerequisites

### Lab environment (two-site topology)
TD5 extends the 4-VM baseline into a **two-site** layout connected by a WAN segment.

#### Site A (LAN side)
| VM | Role | Network | IP |
|---|---|---|---|
| **siteA-gw** | Gateway + strongSwan | NH-LAN (NIC1) + NH-WAN (NIC2) | 10.10.10.1 / 10.10.99.1 |
| **siteA-client** | Admin workstation | NH-LAN | 10.10.10.10 |

#### Site B (DMZ side)
| VM | Role | Network | IP |
|---|---|---|---|
| **siteB-gw** | Gateway + strongSwan | NH-DMZ (NIC1) + NH-WAN (NIC2) | 10.10.20.1 / 10.10.99.2 |
| **siteB-srv** | Bastion / target host | NH-DMZ | 10.10.20.10 |

> You can reuse `gw-fw` → `siteA-gw`, `client` → `siteA-client`, a cloned gateway → `siteB-gw`, and `srv-web` → `siteB-srv`. Rename roles clearly in your report.

**WAN segment:** VirtualBox Internal Network `NH-WAN` (10.10.99.0/24).
- `siteA-gw` NIC2: 10.10.99.1/24
- `siteB-gw` NIC2: 10.10.99.2/24

Both gateways must have `ip_forward = 1` and default routes through their WAN interfaces (or static routes for the remote subnet).

> **First time?** Follow `0_technical_support/TD1/TD1.md` for the base 4-VM setup, then extend for two sites.

### Tools
- `ssh`, `ssh-keygen`, `scp` — SSH key management
- `nmap` (only for your lab network)
- `tcpdump` / Wireshark — capture IKE, ESP, SSH
- **strongSwan** — IPsec IKEv2 (recommended for Linux-to-Linux)
- `nftables` / `ufw` — optional firewall enforcement

### Repo skeleton (standard across groups)
```
TD5_<Group>_<Date>/
  README.md
  report.md
  config/
    ssh_hardening.md
    sshd_config_excerpt.txt
    ipsec_siteA.conf (or swanctl excerpt)
    ipsec_siteB.conf (or swanctl excerpt)
    ipsec.secrets (PLACEHOLDERS ONLY — no real secrets)
  tests/
    commands.txt
    TEST_CARDS.md
  evidence/
    ssh_tests.txt
    authlog_excerpt.txt
    ipsec_status.txt
    tunnel_ping.txt
    optional_esp_capture.pcap
  appendix/
    failure_modes.md
```

---

## 2) Threat model (5 minutes, write it down)

Your report must include a short threat model (6–10 lines):

- **Asset:** administrative access to servers across sites
- **Adversary:** external attacker / internal compromised workstation
- **Key threats:**
  - password guessing / credential stuffing on SSH
  - stolen private key / weak key hygiene
  - MITM on WAN segment (if no VPN)
  - lateral movement after VPN (if no subnet scoping)
- **Security goals:**
  - **only** authorized admins can SSH (scoped users + key-only)
  - admin traffic is **confidential + integrity-protected** in transit (IPsec)
  - tunnel is **scoped** to intended subnets (not 0.0.0.0/0)
  - actions are **auditable** (logs you can point to)

---

## 3) Time plan (3 hours)

| Window | Activity |
|---|---|
| **0:00–0:25** | Build two-site topology + routes + verify intra-site ping |
| **0:25–1:10** | SSH hardening on `siteB-srv` (bastion mindset) + evidence |
| **1:10–2:20** | IPsec site-to-site config (strongSwan IKEv2) + bring up tunnel |
| **2:20–2:40** | Proof: ping/curl over tunnel + capture ESP/NAT-T |
| **2:40–3:00** | Packaging + report + test cards |

---

## 4) Part A — Two-site topology (25 min)

### Task A1 — Network setup
Configure VirtualBox Internal Networks:
- `NH-LAN`: siteA-gw NIC1 + siteA-client
- `NH-DMZ`: siteB-gw NIC1 + siteB-srv
- `NH-WAN`: siteA-gw NIC2 + siteB-gw NIC2

### Task A2 — IP forwarding and routes
On both gateways:
```bash
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.d/99-forward.conf
```

Static routes so each site knows about the other:
```bash
# On siteA-gw: route to DMZ via siteB-gw
sudo ip route add 10.10.20.0/24 via 10.10.99.2

# On siteB-gw: route to LAN via siteA-gw
sudo ip route add 10.10.10.0/24 via 10.10.99.1
```

Client default routes:
```bash
# siteA-client
sudo ip route add 10.10.20.0/24 via 10.10.10.1
sudo ip route add 10.10.99.0/24 via 10.10.10.1

# siteB-srv
sudo ip route add 10.10.10.0/24 via 10.10.20.1
sudo ip route add 10.10.99.0/24 via 10.10.20.1
```

### Task A3 — Pre-flight verification
```bash
# From siteA-client → siteA-gw
ping -c 2 10.10.10.1

# From siteA-gw → siteB-gw (WAN)
ping -c 2 10.10.99.2

# From siteA-client → siteB-srv (through both gateways, no VPN yet)
ping -c 2 10.10.20.10
```

> All three must succeed before continuing. If the cross-site ping fails, check routes and IP forwarding.

---

## 5) Part B — SSH hardening (bastion mindset) (45 min)

Target host: `siteB-srv` (the service you want to administer remotely).

### Target posture (what "good" looks like)
- **Key-based authentication** only (no password auth)
- Root login disabled
- Dedicated admin user with scoped access (`AllowUsers`)
- Logging sufficient to audit accepts and denies

### Task B1 — Create a dedicated admin account
On `siteB-srv`:
```bash
sudo useradd -m -s /bin/bash adminX   # replace X with your group ID
sudo passwd adminX                      # set temporary password for initial key copy
```

### Task B2 — Key-based authentication
On `siteA-client`:
```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_td5 -C "adminX@td5"
ssh-copy-id -i ~/.ssh/id_td5.pub adminX@10.10.20.10
```

Verify key login works before disabling passwords:
```bash
ssh -i ~/.ssh/id_td5 adminX@10.10.20.10 whoami
```

### Task B3 — Harden `/etc/ssh/sshd_config`
Apply at minimum:
```
PasswordAuthentication no
PermitRootLogin no
AllowUsers adminX
PubkeyAuthentication yes
MaxAuthTries 3
LoginGraceTime 30
```

Optional (good practice): `ClientAliveInterval`, `Banner`, restrict to VPN interface (after Part C).

Restart safely:
```bash
sudo sshd -t && sudo systemctl restart ssh
```

Store:
- `config/sshd_config_excerpt.txt`
- `config/ssh_hardening.md` (what you changed and why)

### Task B4 — Prove the hardening works
**Positive test:** key-based SSH works for `adminX`
```bash
ssh -i ~/.ssh/id_td5 adminX@10.10.20.10 "echo SSH_KEY_OK"
```

**Negative test 1:** password auth fails
```bash
ssh -o PubkeyAuthentication=no adminX@10.10.20.10
# Expected: Permission denied (publickey).
```

**Negative test 2:** root login fails
```bash
ssh -i ~/.ssh/id_td5 root@10.10.20.10
# Expected: Permission denied
```

Collect server-side logs:
```bash
sudo tail -n 50 /var/log/auth.log
```

Store:
- `evidence/ssh_tests.txt` (all three tests)
- `evidence/authlog_excerpt.txt` (log lines showing accept + deny)

---

## 6) Part C — IPsec site-to-site VPN (IKEv2) (70 min)

### Design overview
You are building a **site-to-site IPsec tunnel** so that traffic between NH-LAN (10.10.10.0/24) and NH-DMZ (10.10.20.0/24) is encrypted over the NH-WAN segment.

### Task C1 — Install strongSwan
On **both** gateways:
```bash
sudo apt update && sudo apt install -y strongswan strongswan-pki libcharon-extra-plugins
sudo systemctl enable strongswan-starter
```

### Task C2 — Configure IKEv2 (PSK for lab)
PSK is acceptable for the lab but you **must** document it as a lab simplification (state what you would use in production: certificates).

**On siteA-gw** (`/etc/ipsec.conf`):
```
config setup
    charondebug="ike 2, knl 2, cfg 2"

conn site-to-site
    authby=secret
    left=10.10.99.1
    leftsubnet=10.10.10.0/24
    right=10.10.99.2
    rightsubnet=10.10.20.0/24
    ike=aes256-sha256-modp2048!
    esp=aes256-sha256-modp2048!
    keyexchange=ikev2
    auto=start
```

**On siteA-gw** (`/etc/ipsec.secrets`):
```
10.10.99.1 10.10.99.2 : PSK "Lab-TD5-SharedSecret-ChangeMe"
```

**On siteB-gw** — mirror config with `left`/`right` swapped.

Save:
- `config/ipsec_siteA.conf`
- `config/ipsec_siteB.conf`
- `config/ipsec.secrets` — **placeholder only** (replace actual PSK with `<REDACTED>`)

### Task C3 — Requirements checklist (verify before bringing up)
- [ ] UDP 500 and 4500 not blocked between gateways
- [ ] IP forwarding enabled on both gateways
- [ ] Correct subnets defined on both sides (LAN ↔ DMZ)
- [ ] Time in sync (important for cert-based auth; less critical for PSK)

### Task C4 — Bring up the tunnel and prove it
```bash
# On both gateways
sudo ipsec restart

# Check status
sudo ipsec statusall
```

**Minimal proof that "it is up":**

1. `ipsec statusall` shows `ESTABLISHED` for IKE_SA and `INSTALLED` for CHILD_SA
2. Ping from siteA-client to siteB-srv:
   ```bash
   ping -c 4 10.10.20.10
   ```
3. Capture ESP packets on the WAN:

   > **⚠ Interface name:** The command below uses `enp0s9` (WAN segment). Verify the correct interface with `ip link` on your gateway and substitute if needed.

   ```bash
   # On siteA-gw or siteB-gw
   sudo tcpdump -i enp0s9 -c 20 'udp port 500 or udp port 4500 or esp'
   ```

Store:
- `evidence/ipsec_status.txt`
- `evidence/tunnel_ping.txt`
- `evidence/optional_esp_capture.pcap` (or text summary)

### Task C5 — Restrict the tunnel (policy, not just connectivity)
Your tunnel must be **scoped**:
- Only LAN subnet (10.10.10.0/24) ↔ DMZ subnet (10.10.20.0/24)
- **Not** 0.0.0.0/0 ↔ 0.0.0.0/0
- Optionally restrict to specific ports (advanced)

Show the exact config fragment that enforces scope (`leftsubnet`/`rightsubnet`).

---

## 7) Part D — Bind SSH to the VPN path (optional, advanced) (15 min)

If time allows, enforce that SSH to `siteB-srv` is only allowed through the IPsec tunnel:

Option 1 — SSH `Match Address`:
```
# In sshd_config on siteB-srv
Match Address 10.10.10.0/24
    AllowUsers adminX
```

Option 2 — nftables on siteB-srv:
```bash
sudo nft add rule inet filter input ip saddr != 10.10.10.0/24 tcp dport 22 drop
```

Prove:
- SSH from siteA-client (10.10.10.10, tunneled) → succeeds
- SSH from siteB-gw (10.10.20.1, local) → blocked (if policy says so)

Store:
- `config/ssh_vpn_restriction.txt`
- `evidence/ssh_nonvpn_denied.txt`

---

## 8) Deliverables

### 8.1 Evidence Pack report (`report.md`)
Structure:
1. **Threat model** (from §2)
2. **Policy statement** ("only admins in group X can SSH to bastion; password auth disabled; cross-site traffic encrypted via IPsec")
3. **SSH configuration** — diffs/excerpts with justification
4. **IPsec configuration** — sanitized config with design choice documented
5. **Test plan** (positive + negative, referencing evidence files)
6. **Telemetry proof** (log snippets, `ipsec statusall`, pcap notes)
7. **Residual risks** (key rotation, MFA, device posture, PSK→certs migration)

### 8.2 Repo checklist
- [ ] Clean README (topology + setup + how to reproduce)
- [ ] `config/` — SSH and IPsec configs, secrets redacted
- [ ] `evidence/` — all test outputs and log excerpts
- [ ] `tests/TEST_CARDS.md` — ≥ 8 test cards (see §9)
- [ ] `appendix/failure_modes.md`
- [ ] No private secrets committed (PSK, private keys)

---

## 9) Test cards (required, ≥ 8)

Add cards to `tests/TEST_CARDS.md` using the standard template from `0_technical_support/_shared/templates/test_card_template.md`. Separate each card with a `---` horizontal rule.

### Suggested claims

**TD5-T01 — SSH password auth is disabled**
**Claim:** Password-based SSH login is rejected.
**Test (positive):** Key-based login succeeds for `adminX`
**Test (negative):** `ssh -o PubkeyAuthentication=no adminX@siteB-srv` → "Permission denied (publickey)"
**Evidence:** `evidence/ssh_tests.txt`, `evidence/authlog_excerpt.txt`

**TD5-T02 — Root login via SSH is disabled**
**Claim:** Direct root SSH login is blocked.
**Test (negative):** `ssh root@10.10.20.10` → denied
**Evidence:** `evidence/ssh_tests.txt`

**TD5-T03 — Only intended admin user can connect with key**
**Claim:** `AllowUsers` restricts SSH to the designated admin account.
**Test (negative):** SSH as a different user → denied
**Evidence:** `evidence/authlog_excerpt.txt`

**TD5-T04 — SSH logs provide audit trail**
**Claim:** `/var/log/auth.log` records both accepts and denies with username, method, and source IP.
**Test:** Inspect auth.log after positive and negative tests
**Evidence:** `evidence/authlog_excerpt.txt`

**TD5-T05 — IKEv2 tunnel establishes**
**Claim:** `ipsec statusall` shows IKE_SA ESTABLISHED and CHILD_SA INSTALLED.
**Test (positive):** Run `ipsec statusall` on both gateways
**Evidence:** `evidence/ipsec_status.txt`

**TD5-T06 — Traffic passes over tunnel**
**Claim:** Ping/curl from siteA-client to siteB-srv traverses the IPsec tunnel.
**Test (positive):** `ping -c 4 10.10.20.10` from siteA-client succeeds
**Telemetry:** `tcpdump` on WAN shows ESP (not cleartext ICMP)
**Evidence:** `evidence/tunnel_ping.txt`, `evidence/optional_esp_capture.pcap`

**TD5-T07 — Tunnel is scoped to intended subnets**
**Claim:** IPsec config limits traffic to LAN ↔ DMZ (not 0.0.0.0/0).
**Test:** Show `leftsubnet`/`rightsubnet` config excerpts
**Evidence:** `config/ipsec_siteA.conf`, `config/ipsec_siteB.conf`

**TD5-T08 — Firewall permits only required IPsec ports on WAN**
**Claim:** Only UDP 500 and UDP 4500 are needed on the WAN segment for IKE negotiation.
**Test (positive):** Tunnel establishes with only those ports open
**Test (negative):** Block UDP 500 → tunnel fails to negotiate
**Evidence:** `evidence/ipsec_status.txt` (before/after port block)

---

## 10) Grading rubric (100 points)

| Category | Points | Key criteria |
|---|---|---|
| **SSH hardening correctness** | 25 | Key-only auth, root disabled, AllowUsers, log audit |
| **IPsec tunnel correctness + scoping** | 40 | Tunnel up, traffic passes, subnet scoping, sane crypto |
| **Verification quality (tests + telemetry)** | 25 | Positive + negative tests, log/pcap proof |
| **Maintainability** | 10 | Clean repo, reproducible steps, test cards ≥ 8 |

---

## Appendix A — Common failure modes

Document relevant items in `appendix/failure_modes.md`:

| ID | Failure | Symptom | Fix |
|---|---|---|---|
| FM-01 | Locked out of SSH | Cannot connect after config change | Keep a console open; always run `sshd -t` before restart |
| FM-02 | IKEv2 fails to negotiate | `ipsec statusall` shows no SA | Check time sync, proposal match, IDs/secrets; increase charondebug |
| FM-03 | UDP 500/4500 blocked | No IKE packets visible | Check firewall on gateways; use `tcpdump udp port 500` |
| FM-04 | VPN up but no traffic | Ping fails despite ESTABLISHED SA | Check routes, IP forwarding, MTU (ESP overhead) |
| FM-05 | Proposal mismatch | "NO_PROPOSAL_CHOSEN" in logs | Align `ike=` and `esp=` on both sides exactly |
| FM-06 | NAT-T issues | Tunnel drops or encapsulation fails | Ensure UDP 4500 allowed; check for unexpected NAT |
| FM-07 | Routes missing on clients | Traffic goes to wrong gateway | Add static routes: `ip route add 10.10.x.0/24 via <gw>` |
| FM-08 | SSH restriction breaks access | VPN must be up first for SSH | Document dependency chain; provide fallback plan |

---

## Appendix B — Professor-level check

If a reviewer reads your report, they should **never** need to ask:

- "Where is the SSH config?" → config fragment + diff
- "How do you know password auth is off?" → negative test output + log line
- "Is the tunnel really up?" → `ipsec statusall` output
- "Is traffic actually encrypted?" → ESP capture or no cleartext in pcap
- "What is the scope?" → `leftsubnet`/`rightsubnet` config excerpt
- "Where is the proof?" → evidence file with matching timestamp

If any of these is missing, the work is incomplete.

---

## Appendix C — strongSwan debugging cheat-sheet

```bash
# Restart and watch logs
sudo ipsec restart && sudo journalctl -fu strongswan-starter

# Status overview
sudo ipsec statusall

# Detailed SA info (swanctl)
sudo swanctl --list-sas

# Capture IKE + ESP on WAN interface
# ⚠ Verify the correct interface with `ip link` (examples use enp0s9)
sudo tcpdump -ni enp0s9 'udp port 500 or udp port 4500 or esp'

# Increase debug level temporarily
# In ipsec.conf: charondebug="ike 4, knl 4, cfg 4, net 4"
```
