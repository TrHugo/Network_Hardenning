# TD6 (3h) — Final Project Workshop: Integration + Regression Tests + Evidence Review

**Module:** Network Hardening (4th-year engineering)  
**Normative anchor:** MEF 70.1 / 70.2 (SD-WAN Service Attributes) — service contract mindset for testable claims  
**Deliverable style:** "claims + regression suite + executive summary" hardening pack  
**Scope note:** This is a consolidation workshop. No new tools — engineering-grade packaging of TD1–TD5 evidence.

**Format:** 3h in-person workshop (3 groups)  
**Goal:** finish the project with **engineering-grade evidence**, not a “pretty doc”.  
**This TD is a convergence point**: you consolidate TD1–TD5 deliverables into the final “Hardening Pack”.

---

## 0) What “done” looks like

By the end of TD6, your team should have:

1) A stable repo structure for the final project  
2) A **regression test suite** that re-checks your main security claims in minutes  
3) A draft executive summary that a non-technical manager can read  
4) A clean evidence pack that an engineer can reproduce

This is where we convert “we think it’s secure” into “we can re-prove it after every change”.

---

## 1) Inputs (what you should already have)

From earlier TDs:
- TD1: network map + reachability contract
- TD2: firewall policy + test evidence
- TD3: detection plan + sensor placement + tuned rules evidence
- TD4: TLS audit + hardening + edge controls + logs triage evidence
- TD5: SSH hardening + site-to-site IPsec VPN evidence

If something is missing, TD6 is your chance to patch it.

---

## 2) Repository standard (must be identical across groups)

```
final-hardening-pack/
  README.md
  executive/
    Executive_Summary_1p.md
  architecture/
    network_diagram.png
    reachability_matrix.csv
    assumptions.md
  controls/
    firewall/
    ids/
    remote_access/
    tls_edge/
    sdwan_zt/
  evidence/
    baseline/
    after/
  tests/
    TEST_CARDS.md
    regression/
      run_all.sh
      R1_firewall.sh
      R2_tls.sh
      R3_remote_access.sh
      R4_detection.sh
      results/
  report/
    Final_Report.md
    Risk_Register.md
    30_60_90_Plan.md
```

---

## 3) Part A — Freeze your “claims” (25 minutes)

Create a single table in `report/Final_Report.md`:

| Claim ID | Claim (one sentence) | Control location | Proof artifact |
|---|---|---|---|

Examples:
- “Only HTTPS (443) reaches the DMZ web service from Internet.”
- “SSH uses keys only; root login disabled; admin access only over VPN.”
- “TLS min version is 1.2; TLS 1.3 enabled; weak suites disabled.”
- “IDS sees egress boundary traffic; a known test flow is detected.”

Rule: every claim must point to:
- a config snippet,
- a test,
- and a telemetry artifact.

---

## 4) Part B — Build a regression suite (60 minutes)

### The philosophy
A regression suite is not a full pentest. It is a **fast, repeatable check** that your key controls did not silently break.

### Task B1 — Implement `tests/regression/run_all.sh`
It should:
- run each test script,
- store outputs in `tests/regression/results/<timestamp>/`,
- exit non-zero if any critical test fails.

### Task B2 — Create at least 4 regression scripts

**R1_firewall.sh**
- Positive: allowed flow works (curl to 443)
- Negative: forbidden port fails (curl/nc to 22 or 3306)
- Capture evidence output

**R2_tls.sh**
- `openssl s_client` sanity check (protocol + cert)
- optional: grep for “Protocol  : TLSv1.3” if using testssl output

**R3_remote_access.sh**
- attempt SSH without VPN (should fail)
- bring VPN up (if applicable) and attempt again (should succeed)
- collect logs snippet

**R4_detection.sh**
- generate a known test flow (scan or crafted request)
- show IDS alert / log entry exists
- store alert excerpt

Each script must write:
- what it tests,
- expected result,
- command outputs.

---

## 5) Part C — Evidence review clinic (45 minutes)

You will do a peer review (team A reviews team B):

Use this checklist:

1) **Clarity**
- Can you understand the policy without guessing?

2) **Reproducibility**
- Can you run the regression suite and see the same outcomes?

3) **Evidence quality**
- Do claims cite exact evidence files?
- Are log excerpts tied to specific tests?

4) **Maintainability**
- Are configs readable and minimal?
- Is there “temporary” debt?

Write review feedback in:
- `report/Peer_Review.md`

---

## 6) Part D — Executive summary & 30/60/90 plan (30 minutes)

Create `executive/Executive_Summary_1p.md`:
- 3 top risks (business language)
- 5 controls implemented (one line each)
- Residual risk (what you did NOT solve)
- Next actions (30/60/90 days)

Create `report/30_60_90_Plan.md`:
- 30 days: quick wins (monitoring, patching, backups, key rotation)
- 60 days: architecture improvements (segmentation, ZT pilots, WAF tuning)
- 90 days: governance + automation (IaC, CI checks, policy review cadence)

---

## 7) Deliverables (TD6)

Submit a zip or repo link with:
- final-hardening-pack repo
- regression suite scripts + results folder
- Executive summary + Final report draft
- Peer review note

TD6 is not about “new tech”; it is about professional packaging.

---

## 8) Grading rubric (100 points)

- **Claims table quality (25)**
  - clear, testable, minimal claims (15)
  - each claim points to artifacts (10)
- **Regression suite (35)**
  - 4 scripts minimum (20)
  - repeatable storage of results (10)
  - failure behavior correct (5)
- **Evidence pack maturity (25)**
  - configs + tests + telemetry coherent (15)
  - peer review incorporated (10)
- **Executive clarity (15)**
  - 1-page summary readable (10)
  - 30/60/90 plan realistic (5)

---

## Appendix A — Test Card Template (copy/paste)

**Test Card ID:** FP-CLAIM-01  
**Claim:** Only HTTPS reaches DMZ web from Internet  
**Setup:** firewall policy deployed; service listening on 443  
**Action:** `curl -k https://dmz-web` then `nc -vz dmz-web 22`  
**Expected:** HTTPS works; SSH port fails  
**Observed:** (paste output)  
**Evidence:** tests/regression/results/.../R1_firewall.txt  
**Telemetry:** firewall log excerpt in evidence/after/firewall_drops.txt

---

## Appendix B — Common failure modes (integration week)

1) **Your “policy contract” and your rules disagree**
- Fix the contract or fix the rule, but don’t keep both.

2) **Evidence is not tied to a claim**
- Rename files and reference them explicitly in the report.

3) **Regression suite is flaky**
- Stabilize timing; avoid fragile greps; document assumptions.

4) **“Works on my VM”**
- Provide setup scripts and explicit versions.

5) **You optimize for pretty diagrams**
- Diagrams are good, but they do not replace tests.

---

## Appendix C — Instructor sanity checks

A final project is “professional” if:
- the repo is readable in 5 minutes,
- the regression suite runs in <10 minutes,
- and every major claim has a reproducible proof artifact.
