# TD1 Test Cards

**TD1-T01: Client can reach srv-web on required service (HTTP/HTTPS)**

- **Claim:** The client machine in the LAN zone can successfully reach the web service hosted on `srv-web` in the DMZ zone via HTTP.
- **Preconditions:** IP forwarding is enabled on `gw-fw`; `nginx` is actively running on `srv-web` (port 80); static routing is correctly configured between the `NH-LAN` and `NH-DMZ` subnets.
- **Config fragment:** `sysctl net.ipv4.ip_forward` on the gateway must return `1`. 
- **Test method:**
  - *Positive:* Run `curl -s -o /dev/null -w "%{http_code}" http://10.10.20.10` from the LAN client.
  - *Negative:* Run `curl -k https://10.10.20.10` from the LAN client (HTTPS is not yet configured).
- **Telemetry / Expected Result:** The positive test must return an HTTP status code `200`. The negative test must fail or time out.
- **Artifacts:** `baseline.pcap` (Packets 10 to 12 confirm the successful HTTP 200 OK exchange).

---

**TD1-T02: Unexpected port on srv-web is closed or flagged as risk**

- **Claim:** Only expected ports are open on `srv-web`, and any risky configurations (like password-enabled SSH) are identified.
- **Preconditions:** The `srv-web` machine is booted; Nmap is installed on the scanning node (`gw-fw` acting as proxy for the LAN client).
- **Config fragment:** N/A (Testing default OS listening state).
- **Test method:**
  - *Positive:* Run a defensive stealth and version scan: `sudo nmap -sS -sV -p 1-1000 10.10.20.10`.
  - *Negative:* Attempt to connect to a known closed port, e.g., `nc -zv 10.10.20.10 23` (Telnet).
- **Telemetry / Expected Result:** Nmap reports exactly 998 closed ports and 2 open ports: 22 (OpenSSH 8.9p1) and 80 (nginx 1.18.0). Port 22 is flagged as a risk in the main report due to default password authentication.
- **Artifacts:** `evidence/nmap_srvweb.txt`.

---

**TD1-T03: Baseline capture includes HTTP/HTTPS and DNS traffic**

- **Claim:** The network capture successfully records representative traffic (HTTP, ICMP, DNS) to establish a "before-hardening" baseline.
- **Preconditions:** `tcpdump` is actively listening on `srv-web` (`sudo tcpdump -i any -w baseline.pcap -c 100`); traffic is manually generated from the LAN.
- **Config fragment:** `tcpdump` packet capture command.
- **Test method:**
  - *Positive:* Open the `.pcap` file in Wireshark and apply display filters: `http`, `icmp`, and `dns`.
- **Telemetry / Expected Result:** The capture must contain cleartext HTTP GET requests, ICMP Echo requests/replies, and DNS standard queries proving the baseline state of the network.
- **Artifacts:** `evidence/baseline.pcap` (HTTP at Packet 10, ICMP at Packet 21, DNS at Packet 31).

---

**TD1-T04: Topology diagram matches observed addressing and routes**

- **Claim:** The logical network map accurately reflects the real configurations, IP addresses, and routing tables of the lab environment.
- **Preconditions:** All 4 VMs are running and accessible via SSH.
- **Config fragment:** Execution of `hostname && ip addr && ip route && ss -tulpn` on all VMs.
- **Test method:**
  - *Positive:* Cross-reference the outputs of `ip addr` and `ip route` from `commands.txt` against the drawn `diagram.pdf`.
- **Telemetry / Expected Result:** `gw-fw` acts as the trust boundary with interfaces in both `10.10.10.0/24` and `10.10.20.0/24`. `srv-web` (`10.10.20.10`) routes traffic to the LAN via `10.10.20.254`. The diagram perfectly matches these facts.
- **Artifacts:** `tests/commands.txt` and `diagram.pdf`.