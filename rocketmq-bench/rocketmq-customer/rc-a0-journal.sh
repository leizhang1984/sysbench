#!/bin/bash
journalctl -u rmq-broker --no-pager -n 120 | grep -iE 'exception|error|caused|at org|at java|fail|bind|address' | tail -40
echo "=== tail journal ==="
journalctl -u rmq-broker --no-pager -n 60 | tail -40
