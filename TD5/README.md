# TD5: Secure Remote Access & Site-to-Site VPN

## Overview
This repository contains the configuration, evidence, and test documentation for TD5. The goal of this lab was to implement a secure remote-access pattern using a bastion host mindset for SSH and an IKEv2 IPsec tunnel via strongSwan to protect traffic across the WAN segment.

## Topology Mapping
* **siteA-gw (gw-fw)**: 10.10.10.254 (LAN) / 10.10.20.254 (WAN)
* **siteB-srv (srv-web)**: 10.10.20.10 (DMZ/WAN)
* **siteA-client (sensor-id)**: 10.10.10.x (LAN)

## How to Reproduce
1. Configure static routes and enable IP forwarding (`net.ipv4.ip_forward=1`) on the gateway.
2. Apply SSH hardening on `siteB-srv` (key-based auth only, root disabled).
3. Install `strongswan` on both endpoints.
4. Apply the IPsec configurations from the `config/` directory.
5. Restart the IPsec daemon and verify the tunnel with `ipsec statusall`.