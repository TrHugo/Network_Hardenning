# SSH Hardening Justification
* `PasswordAuthentication no`: Eliminates the risk of dictionary and brute-force attacks.
* `PermitRootLogin no`: Prevents direct superuser access, forcing admins to log in as a standard user and escalate privileges auditably via `sudo`.
* `PubkeyAuthentication yes`: Mandates cryptographic keys (ED25519) for access.