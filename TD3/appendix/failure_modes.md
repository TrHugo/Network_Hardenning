# TD3 - Failure Modes

| ID | Failure | Symptom | Fix |
|---|---|---|---|
| FM-01 | OOM Killer on Suricata Update | `suricata-update` process outputs `Killed` and custom rules are not loaded. | Created and mounted a 2GB swap file (`/swapfile`) to provide sufficient memory for rule compilation. |
| FM-02 | `$HOME_NET` Misconfiguration | Traffic generated from the gateway itself did not trigger external ET Open alerts. | Documented the behavior: the scanner was inside the trusted network, hence external-facing rules ignored the traffic. Authored a custom rule with `any -> any` to prove detection capabilities. |
| FM-03 | Checksum Offloading | Local packets dropped by engine | Cloud hypervisor offloads checksum calculation, causing Suricata to view TX packets as invalid. Relied on `eve.json` and explicit protocol matching. |