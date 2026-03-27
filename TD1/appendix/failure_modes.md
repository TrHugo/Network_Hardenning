# TD1 - Failure Modes

| ID | Failure | Symptom | Fix |
|---|---|---|---|
| FM-01 | Elastic IP missing on gateway | Unable to reach gw-fw from public internet | Allocated and associated an Elastic IP to the LAN interface of gw-fw. |
| FM-02 | Nmap stealth scan fails | `You requested a scan type which requires root privileges.` | Run nmap with `sudo`. |
| FM-03 | Promiscuous mode blocked | Cannot capture transit traffic on a dedicated sensor VM | Captured traffic directly on the target endpoint (`srv-web`) using tcpdump. |