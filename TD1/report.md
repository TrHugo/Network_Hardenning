# TD1 Report - Network Baseline for Hardening

## 1. Baseline Observations

**Observation ID:** O1
- **Time range:** 12.516797 - 12.516986
- **Flow reference (row ID):** F04
- **What I saw (facts):** HTTP web traffic is transmitted in cleartext. The capture shows a `GET / HTTP/1.1` request (Packet 10) originating from the LAN gateway (`10.10.10.254`) and a `200 OK` response (Packet 12) from `srv-web` (`10.10.20.10`). 
- **Why it matters:** Anyone intercepting the traffic (passive sniffing) can read the full contents of the requests and responses, including sensitive data or credentials.
- **Proposed control:** Implement TLS encryption (HTTPS) on `srv-web` (TD4) and redirect port 80 to 443.
- **Evidence pointer:** File `baseline.pcap` (Wireshark filter: `http`). See Packets 10 and 12.

**Observation ID:** O2
- **Time range:** N/A (Based on Nmap scan)
- **Flow reference (row ID):** F01
- **What I saw (facts):** Port 22 (SSH) is open and exposed on `srv-web` (`10.10.20.10`). Note: Although the baseline capture shows encrypted SSH traffic (e.g., Packet 1), default configurations typically allow password authentication.
- **Why it matters:** An exposed SSH port with password authentication is a primary vector for brute-force attacks.
- **Proposed control:** Disable password authentication, enforce SSH key usage (TD5), and restrict access to the specific administrator IP.
- **Evidence pointer:** File `nmap_srvweb.txt`.

**Observation ID:** O3
- **Time range:** 23.617607 - 28.618866
- **Flow reference (row ID):** F06
- **What I saw (facts):** ICMP Echo requests originating from the LAN (`10.10.10.254`) successfully reach the DMZ (`10.10.20.10`) and receive Echo replies without any restriction (e.g., Packets 21 and 22).
- **Why it matters:** Unrestricted ICMP traffic facilitates network reconnaissance, allowing an attacker to map active hosts easily.
- **Proposed control:** Implement ICMP rate-limiting or block ICMP entirely at the `gw-fw` boundary (TD2).
- **Evidence pointer:** File `baseline.pcap` (Wireshark filter: `icmp`). See Packets 21 to 28.

**Observation ID:** O4
- **Time range:** N/A (Based on Nmap scan)
- **Flow reference (row ID):** F08
- **What I saw (facts):** All open ports on `srv-web` are directly reachable from the LAN through `gw-fw`, indicating the absence of an active firewall policy at the trust boundary.
- **Why it matters:** The lack of filtering results in "Zero enforcement," exposing the DMZ to all connected networks.
- **Proposed control:** Deploy a strict "Default-deny" policy using `nftables` on the gateway (TD2).
- **Evidence pointer:** File `nmap_srvweb.txt`.

**Observation ID:** O5
- **Time range:** 30.091393 - 30.091926
- **Flow reference (row ID):** N/A
- **What I saw (facts):** DNS standard queries (A record for `example.com`) sent to `10.10.20.10` via port 53 (e.g., Packet 31) are immediately rejected with an ICMP "Destination unreachable (Port unreachable)" message (e.g., Packet 32).
- **Why it matters:** This confirms that no local DNS service is listening on the target IP, which is positive for attack surface reduction but documents a limitation for internal name resolution.
- **Proposed control:** Document this expected limitation. Configure hosts to use a legitimate enterprise DNS resolver if updates or external resolution are required.
- **Evidence pointer:** File `baseline.pcap` (Wireshark filter: `dns` or `icmp.type == 3`). See Packets 31 to 36.

**Observation ID:** O6 (Bonus Observation based on telemetry)
- **Time range:** 191.594121 - 191.594976
- **Flow reference (row ID):** N/A
- **What I saw (facts):** The server `srv-web` (`10.10.20.10`) initiated an HTTP GET request to the AWS Instance Metadata Service (IMDS) at `169.254.169.254` (Packet 74) targeting `/latest/meta-data/iam/security-credentials/`. It received a `404 Not Found` response (Packet 76).
- **Why it matters:** While the 404 response indicates no IAM role is currently attached, unrestricted access to the IMDS endpoint is a critical risk. If an application vulnerability (like SSRF) occurs on `srv-web`, an attacker could query this endpoint to steal temporary AWS credentials.
- **Proposed control:** Enforce IMDSv2 (requiring session tokens) or use a firewall rule on `srv-web` (iptables/nftables) to block outbound traffic from the `nginx` user to `169.254.169.254`.
- **Evidence pointer:** File `baseline.pcap`. See Packets 74 and 76.

---

## 2. Top Risks (Ranked by Impact × Ease of exploitation)

1. **No firewall (Zero enforcement):** CRITICAL Impact / TRIVIAL Exploitation. Services are completely exposed to adjacent networks without filtering.
2. **HTTP cleartext:** HIGH Impact / EASY Exploitation. Permits passive sniffing and interception of sensitive data.
3. **SSH password authentication:** HIGH Impact / EASY Exploitation. Direct vulnerability to brute-force credential stuffing.
4. **Unrestricted AWS IMDS Access:** HIGH Impact / MEDIUM Exploitation. Could lead to AWS credential theft via SSRF if an IAM role is attached in the future.
5. **No deny logging:** HIGH Impact / N/A Exploitation. Prevents visibility into active reconnaissance or attacks.

---

## 3. Top 5 Quick Wins

1. Implement a **Default-deny** firewall policy on the `gw-fw` gateway (TD2).
2. Secure web traffic by enabling **HTTPS** on `srv-web` (TD4).
3. Disable **password authentication for SSH** and enforce key-based access (TD5).
4. Enable **deny logging** on the firewall to monitor blocked traffic (TD2).
5. Restrict ICMP traffic to **echo-only** (TD2).