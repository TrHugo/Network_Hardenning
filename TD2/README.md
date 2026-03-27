# TD2 - Firewall Policy From Flows

## Team
- **Hugo TRAN** (Solo / All roles)

## Lab Summary
Implemented a default-deny firewall on the `gw-fw` gateway using `nftables`. The ruleset enforces the flow matrix established in TD1, allowing specific services (HTTP, HTTPS, SSH, rate-limited ICMP) while dropping and logging unauthorized transit traffic.

## What Was Tested
- Verified positive flows (HTTP, ICMP) from the LAN gateway proxy to the DMZ.
- Verified negative flows (unauthorized ports) and confirmed DROP behavior.
- Tested ruleset rollback functionality.