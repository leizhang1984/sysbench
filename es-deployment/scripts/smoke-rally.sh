#!/bin/bash
# Smoke test: esrally test-mode against ES 6.8.1, benchmark-only pipeline.
# Args: $1=cluster-label  $2,$3,$4 = node IPs
set -o pipefail
LABEL="$1"; shift
HOSTS="$1:9200,$2:9200,$3:9200"
source /etc/profile.d/esrally.sh 2>/dev/null
export JAVA_HOME=${JAVA_HOME:-/usr/lib/jvm/java-11-openjdk}
echo "=== $(hostname) smoke test -> $LABEL ($HOSTS) ==="
esrally race \
  --track=geonames \
  --challenge=append-no-conflicts \
  --test-mode \
  --pipeline=benchmark-only \
  --target-hosts="$HOSTS" \
  --kill-running-processes \
  --on-error=abort 2>&1 | tail -n 40
echo "=== exit=$? ==="
