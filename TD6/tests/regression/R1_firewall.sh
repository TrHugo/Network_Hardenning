#!/bin/bash
# R1: Verify firewall still enforces policy
echo "=== R1 Firewall Regression ==="

TARGET_IP="10.10.20.10"

# Positive: HTTPS to srv-web should work
echo -n "P1: HTTPS -> srv-web... "
STATUS=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 5 https://$TARGET_IP)
[ "$STATUS" = "200" ] || [ "$STATUS" = "301" ] && echo "PASS" || { echo "FAIL (got $STATUS)"; exit 1; }

# Positive: SSH to srv-web should work  
echo -n "P2: SSH -> srv-web... "
ssh -i ~/.ssh/id_td5 -o ConnectTimeout=3 -o BatchMode=yes ubuntu@$TARGET_IP "echo ok" > /dev/null 2>&1 \
  && echo "PASS" || { echo "FAIL"; exit 1; }

# Negative: Random port (12345) should timeout
echo -n "N1: Port 12345 -> srv-web... "
nc -vz -w 3 $TARGET_IP 12345 > /dev/null 2>&1 \
  && { echo "FAIL (should be blocked)"; exit 1; } || echo "PASS (blocked)"

# Negative: MySQL (3306) should timeout
echo -n "N2: Port 3306 -> srv-web... "
nc -vz -w 3 $TARGET_IP 3306 > /dev/null 2>&1 \
  && { echo "FAIL (should be blocked)"; exit 1; } || echo "PASS (blocked)"

echo "R1: All checks passed"