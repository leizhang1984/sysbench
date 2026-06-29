#!/bin/bash
# Emit gzip+base64 of the rally CSV and meta so it survives run-command tail truncation.
LABEL="$1"
echo "===META_B64==="
base64 -w0 /tmp/rally-$LABEL.meta 2>/dev/null
echo ""
echo "===CSV_B64==="
gzip -c /tmp/rally-$LABEL.csv 2>/dev/null | base64 -w0
echo ""
echo "===END==="
