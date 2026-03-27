# TD3 Test Cards

**TD3-T01 — Sensor sees DMZ traffic**
- **Claim:** Suricata successfully captures packets traversing the DMZ interface.
- **Preconditions:** Suricata is installed and `tcpdump` is available.
- **Test (positive):** Execute `sudo tcpdump -i ens6 -c 5 icmp` on the gateway and send pings from `srv-web` (`10.10.20.10`).
- **Result:** Captured 5 ICMP echo requests originating from the DMZ.
- **Evidence:** `evidence/visibility_proof.txt`.

---

**TD3-T02 — Community rules successfully load**
- **Claim:** Suricata correctly downloads and parses the Emerging Threats Open ruleset.
- **Preconditions:** `suricata-update` is executed with sufficient system memory (Swap enabled).
- **Test (positive):** Review the output of the update process and the `suricata -T` configuration test.
- **Result:** Over 65,000 rules were successfully loaded and parsed.
- **Evidence:** Terminal output showing `Loaded 65180 rules.` and `Done.`

---

**TD3-T03 — Custom rule syntax is valid**
- **Claim:** The custom HTTP detection rule is syntactically correct and loads into the engine.
- **Preconditions:** The rule is written to `/etc/suricata/rules/local.rules`.
- **Test (positive):** Run `sudo suricata-update --local /etc/suricata/rules/local.rules`.
- **Result:** The rule is merged, increasing the total enabled rules by 1 (`added: 1`).
- **Evidence:** Terminal output from the update script showing the successful merge.

---

**TD3-T04 — Custom rule is scoped and versioned**
- **Claim:** The rule contains all required metadata (`msg`, `sid`, `rev`, `classtype`).
- **Preconditions:** The rule is available in `local.rules`.
- **Test (positive):** Manual code review of the rule string.
- **Result:** The rule correctly targets port `80`, includes the `content:"/admin"` payload match, and is uniquely identified by `sid:9000002`.
- **Evidence:** `config/local.rules`.

---

**TD3-T05 — Engine memory allocation is stable**
- **Claim:** The sensor node has sufficient memory to run the IDS engine without OOM (Out of Memory) crashes.
- **Preconditions:** A 2GB swap file is created (`/swapfile`).
- **Test (positive):** Restart the `suricata` service and verify its active status.
- **Result:** Suricata remained active and did not trigger a `Killed` signal during rule loading.
- **Evidence:** System execution logs.

---

**TD3-T06 — Tuning preserves visibility**
- **Claim:** Implementing a threshold rate-limit reduces noise without creating blind spots.
- **Preconditions:** A threshold command is defined for `sid:9000002`.
- **Test (positive):** Analyze the logic of `type limit, track by_src, count 1, seconds 60`.
- **Result:** The first attack from any new IP is immediately alerted, fulfilling security requirements while saving SOC resources.
- **Evidence:** Documentation in `report.md`.