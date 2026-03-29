#!/bin/bash
# R2: Verify TLS configuration still matches profile
echo "=== R2 TLS Regression ==="

TLS_HOST="10.10.20.10:443"

# Check TLS 1.2 works
echo -n "P1: TLS 1.2 accepted... "
echo "Q" | openssl s_client -connect $TLS_HOST -tls1_2 > /dev/null 2>&1 \
  && echo "PASS" || { echo "FAIL"; exit 1; }

# Check TLS 1.0 is rejected
echo -n "N1: TLS 1.0 rejected... "
echo "Q" | openssl s_client -connect $TLS_HOST -tls1 > /dev/null 2>&1 \
  && { echo "FAIL (TLS 1.0 still accepted!)"; exit 1; } || echo "PASS"

# Check HSTS header present
echo -n "P2: HSTS header present... "
curl -sk -D- https://10.10.20.10/ 2>/dev/null | grep -qi "strict-transport-security" \
  && echo "PASS" || { echo "FAIL (no HSTS)"; exit 1; }

echo "R2: All checks passed"