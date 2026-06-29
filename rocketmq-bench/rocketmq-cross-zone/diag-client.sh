#!/bin/bash
# diag-client.sh  —  Diagnose package install + nameserver reachability from client01.
set -uo pipefail
echo "=== OS ==="; cat /etc/rocky-release 2>/dev/null || cat /etc/os-release | head -2
echo "=== dnf install java/wget/unzip (visible) ==="
dnf -y install java-11-openjdk-headless wget unzip 2>&1 | tail -15
echo "=== java ==="; java -version 2>&1 | head -3
echo "=== nameserver TCP 9876 ==="
for ns in 10.162.0.4 10.162.0.5 10.162.0.6; do
  if timeout 3 bash -c "echo > /dev/tcp/$ns/9876" 2>/dev/null; then echo "  $ns:9876 OK"; else echo "  $ns:9876 UNREACHABLE"; fi
done
echo "=== broker TCP 10911 (masters) ==="
for b in 10.162.0.7 10.162.0.9 10.162.0.11; do
  if timeout 3 bash -c "echo > /dev/tcp/$b/10911" 2>/dev/null; then echo "  $b:10911 OK"; else echo "  $b:10911 UNREACHABLE"; fi
done
