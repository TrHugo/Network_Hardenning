# TD4: Web Server TLS Hardening

## Overview
This repository contains the configuration and evidence for TD4. The objective of this lab was to secure a web server (`srv-web`) by implementing a hardened TLS configuration, mitigating common vulnerabilities associated with legacy cryptographic protocols.

## Infrastructure
* **Target Server (`srv-web`)**: The web server hosting the service requiring HTTPS protection.
* **Client / Scanner**: The workstation used to perform audits and verify the TLS posture.

## Security Controls Implemented
During this lab, the following hardening measures were applied to the web server configuration:
1. **Protocol Restriction**: Disabled vulnerable legacy protocols (SSLv3, TLS 1.0, and TLS 1.1). Enforced the use of TLS 1.2 and TLS 1.3 exclusively.
2. **Cipher Suite Hardening**: Configured the server to prefer strong cipher suites (e.g., AES-GCM, ChaCha20) and explicitly disabled weak algorithms (e.g., RC4, 3DES, MD5).
3. **Forward Secrecy**: Prioritized Elliptic Curve Diffie-Hellman Ephemeral (ECDHE) key exchanges to ensure perfect forward secrecy.
4. **Certificate Deployment**: Generated and successfully deployed the required cryptographic certificates to the web server.

## How to Reproduce
1. Ensure the web server (e.g., Nginx or Apache) is installed on `srv-web`.
2. Generate the necessary certificates and place them in the appropriate directory (e.g., `/etc/ssl/`).
3. Apply the hardened TLS configuration block provided in the `config/` directory of this repository.
4. Test the configuration syntax and restart the web server service.
5. Audit the endpoint using a standard TLS scanning tool (such as `nmap` ssl-enum-ciphers or `testssl.sh`) from the client to confirm compliance with the target posture.