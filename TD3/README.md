# TD3 - IDS/IPS: Detection Engineering

## Team
- **Hugo TRAN** (Solo / All roles)

## Lab Summary
Deployed Suricata IDS on the gateway (`gw-fw`) due to cloud hypervisor constraints blocking promiscuous mode. Engineered a custom detection rule to monitor unauthorized HTTP access to administrative endpoints and applied threshold tuning to manage alert fatigue.

## What Was Tested
- Verified sensor visibility via ICMP packet capture on the DMZ interface.
- Evaluated the Emerging Threats (ET Open) ruleset against an Nmap scan.
- Created and successfully triggered a custom HTTP URI rule (`sid:9000002`).
- Demonstrated threshold tuning concepts.