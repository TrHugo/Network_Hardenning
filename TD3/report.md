# TD3 - IDS Detection Engineering Evidence Pack

## 1. Topology and Sensor Placement
Due to cloud hypervisor constraints (AWS strictly blocking promiscuous mode across instances), the `sensor-ids` role was consolidated onto the trust boundary gateway (`gw-fw`). Suricata was bound to the DMZ-facing interface (`ens6`) to monitor all transit traffic entering or leaving the `10.10.20.0/24` subnet.

## 2. Detection Observations
A baseline Nmap scan (`nmap -sS -sV -p 1-1000 10.10.20.10`) was executed. Because the scanner (`gw-fw`) was part of the `$HOME_NET` variable, the default Emerging Threats (ET Open) ruleset treated the traffic as trusted internal behavior and did not generate high-severity external alerts.

## 3. Custom Rule Engineering
To guarantee deterministic detection regardless of the source IP, a custom rule was authored to detect unauthorized access to the `/admin` path on the web server.

**Rule Text:**
`alert http any any -> any 80 (msg:"TD3 CUSTOM - HTTP request to /admin detected"; content:"/admin"; sid:9000002; rev:1; classtype:policy-violation;)`

## 4. Tuning Action
If this custom rule were to generate excessive noise from legitimate administrators, the best tuning approach is to apply a rate-limiting threshold rather than fully suppressing it.

**Proposed Tuning Rule:**
`threshold gen_id 1, sig_id 9000002, type limit, track by_src, count 1, seconds 60`
*Rationale:* This reduces alert fatigue by firing only once per minute per source IP, without hiding the underlying security event from the SOC analysts.

## 5. Known Limitations
1. **Hardware Checksum Offloading:** Traffic generated locally by the sensor node (`gw-fw`) is subject to hardware checksum offloading by the AWS hypervisor. Suricata frequently drops these locally generated TX packets as "invalid" before they reach the detection engine, leading to false negatives during local testing.
2. **TLS Blindness:** Suricata cannot inspect the HTTP payload or URI if the traffic is encrypted (HTTPS), limiting rules to metadata matching (SNI/JA3).