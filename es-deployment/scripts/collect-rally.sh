#!/bin/bash
# Print esrally CSV result + meta for the given cluster label. Arg: $1=label
LABEL="$1"
echo "===META==="
cat /tmp/rally-$LABEL.meta 2>/dev/null
echo "===CSV==="
cat /tmp/rally-$LABEL.csv 2>/dev/null
echo "===END==="
