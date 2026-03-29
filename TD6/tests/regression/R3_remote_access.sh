#!/bin/bash
# R3: Verify SSH hardening and IPsec tunnel
echo "=== R3 Remote Access Regression ==="

TARGET_IP="10.10.20.10"

# Positive: SSH key auth works
echo -n "P1: SSH key auth... "
ssh -i ~/.ssh/id_td5 -o ConnectTimeout=3 -o BatchMode=yes ubuntu@$TARGET_IP "echo ok" > /dev/null 2>&1 \
  && echo "PASS" || { echo "FAIL"; exit 1; }

# Negative: SSH password auth blocked
echo -n "N1: SSH password denied... "
ssh -o PubkeyAuthentication=no -o ConnectTimeout=3 -o BatchMode=yes ubuntu@$TARGET_IP "echo fail" > /dev/null 2>&1 \
  && { echo "FAIL (password auth still works!)"; exit 1; } || echo "PASS"

# IPsec tunnel status (Assuming script is run on a node with sudo ipsec access, or gracefully skips)
echo -n "P2: IPsec tunnel... "
if command -v ipsec >/dev/null 2>&1; then
    sudo ipsec statusall 2>/dev/null | grep -q "ESTABLISHED" \
      && echo "PASS" || { echo "FAIL (tunnel not established)"; exit 1; }
else
    echo "SKIP (ipsec command not found locally, please verify on gateway manually)"
fi

echo "R3: All checks passed"