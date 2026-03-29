# Failure Modes & Troubleshooting

| ID | Failure | Symptom | Fix |
|---|---|---|---|
| FM-01 | Asymmetric Routing via DHCP | Lost SSH connection immediately after running `sudo dhclient ens6`. | `dhclient` overwrites the default route. Reboot instance to restore `ens5` default route, and use Netplan with `use-routes: false` for secondary interfaces. |
| FM-02 | Unencrypted Traffic bypassing tunnel | Ping works, but no ESP packets are seen in `tcpdump` or IPsec counters. | Traffic is originating from an out-of-scope IP (e.g., `10.10.20.50`). Force the correct source IP using `ping -I 10.10.10.254 <target>`. |
| FM-03 | Locked out of SSH | Cannot connect after applying hardening config. | Always keep an active SSH session open and run `sshd -t` to validate syntax before restarting the service. |