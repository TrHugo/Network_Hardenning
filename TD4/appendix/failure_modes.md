# TD4 - Failure Modes

| ID | Failure | Symptom | Fix |
|---|---|---|---|
| FM-01 | OpenSSL Local Enforcement | Scanning for TLS 1.0 with OpenSSL returned `no protocols available` even when Nginx allowed it. | System OpenSSL is configured to globally refuse legacy protocols. Relied on `testssl.sh` to bypass OS restrictions and accurately map server capabilities. |
| FM-02 | Rate Limit Bypassed by Bash | Running a `for` loop with `curl` resulted in 100% `200 OK` codes without triggering the 503 limit. | Bash sequential execution was too slow to hit the 10r/s + burst threshold. Used the `&` operator to background processes and send requests concurrently. |