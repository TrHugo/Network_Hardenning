# Firewall Policy (TD2)

## 1. Zones
| Zone | Network | Assets |
|---|---|---|
| LAN (trusted) | NH-LAN 10.10.10.0/24 | client (10.10.10.10) |
| DMZ (semi-trusted) | NH-DMZ 10.10.20.0/24 | srv-web (10.10.20.10), sensor-ids (10.10.20.50) |
| Gateway | Both interfaces | gw-fw (10.10.10.1 / 10.10.20.1) |

## 2. Allow-list
- **ALLOW** Any → Gateway TCP/22 (SSH), purpose: Admin access to firewall from anywhere (Cloud context).
- **ALLOW** LAN → DMZ TCP/80 (HTTP to srv-web), purpose: Web application access.
- **ALLOW** LAN → DMZ TCP/443 (HTTPS to srv-web), purpose: Secure web access (for TD4).
- **ALLOW** LAN → DMZ TCP/22 (SSH to srv-web), purpose: Admin access to DMZ servers.
- **ALLOW** LAN → DMZ ICMP echo-request, purpose: Network diagnostics (rate-limited to 5/s).
- **ALLOW** Any ↔ Any (Stateful), purpose: Permit established and related return traffic.

## 3. Default Stance
- **FORWARD:** DROP (Deny all transit traffic by default).
- **INPUT:** DROP (Protect the gateway itself from unauthorized access).
- **OUTPUT:** ACCEPT (Allow the gateway to initiate outbound connections).

## 4. Logging Strategy
- Log denied FORWARD traffic with prefix `NFT_FWD_DENY` (rate-limited to 10/min).
- Log denied INPUT traffic with prefix `NFT_IN_DENY` (rate-limited to 10/min).