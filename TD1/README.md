# TD1 - Network Baseline for Hardening

## Team
- **Hugo TRAN** (Solo / All roles)

## Lab Topology Summary
The lab consists of 4 instances divided into two distinct zones, bridged by a central gateway acting as a trust boundary:
- **NH-LAN (10.10.10.0/24):** Contains the `client` machine (Windows Host in AWS context).
- **NH-DMZ (10.10.20.0/24):** Contains the `srv-web` (10.10.20.10) and `sensor-ids` (10.10.20.50) instances.
- **Trust Boundary:** The `gw-fw` gateway connects both subnets and the internet (10.10.10.254 / 10.10.20.254).

## What Was Tested and How
- **Discovery:** Used `ip`, `ss`, and `nmap` to map listening services and routing.
- **Flow Validation:** Used `curl`, `ping`, and `dig` to confirm the reachability matrix.
- **Capture:** Used `tcpdump` to create a baseline PCAP of standard traffic before any hardening is applied.

## Known Limitations
- External DNS resolution is currently unavailable on the DMZ (`srv-web`).
- Cloud hypervisor limitations (AWS) prevent standard promiscuous mode, requiring traffic capture to be executed directly on the target endpoints instead of a passive sensor.
- The `client` is simulated via the AWS Gateway's public IP tunnel due to the cloud architecture.