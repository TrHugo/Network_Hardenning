# TD2 - Failure Modes

| ID | Failure | Symptom | Fix |
|---|---|---|---|
| FM-01 | Typos in terminal | Multiple rules mashed into one line | Flushed and re-entered the missing ICMP and logging rules. |
| FM-02 | Deny logs empty on local tests | Connections "Refused" instead of "Timeout" | Realized traffic generated from the gateway itself traverses the OUTPUT chain (set to ACCEPT). To trigger FORWARD logs, traffic must originate from another node traversing the gateway. |