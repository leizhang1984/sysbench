#!/bin/bash
# Pre-flight: strip CRLF, chmod +x, and bash -n syntax-check the core scripts.
set -euo pipefail
cd "$(dirname "$0")"
for f in 00-vars.sh deploy-infra.sh inventory.sh namesrv-setup.sh broker-setup.sh provision-all.sh verify.sh _run-infra.sh; do
  [ -f "$f" ] || continue
  sed -i 's/\r$//' "$f"
  chmod +x "$f"
  bash -n "$f" && echo "OK  $f" || { echo "BAD $f"; exit 1; }
done
echo "=== prep complete ==="
