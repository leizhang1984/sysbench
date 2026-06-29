#!/bin/bash
# Entry point: create infra, resolve dynamic NameServer IPs, then provision.
# Logs to deploy-infra.log. Verify separately with ./verify.sh after ~5 min.
set -euo pipefail
cd "$(dirname "$0")"
LOG=./deploy-infra.log
{
  echo "=== [$(date)] deploy start ==="
  bash ./deploy-infra.sh
  bash ./inventory.sh
  bash ./provision-all.sh
  echo "=== [$(date)] deploy dispatched ==="
} 2>&1 | tee "$LOG"
echo "Done. Wait ~5 min then run: bash ./verify.sh"
