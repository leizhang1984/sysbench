#!/bin/bash
# P1 per-node health: prints node + is-active + port listen. Run on each VM.
echo "host=$(hostname)"
systemctl is-active rmq-namesrv 2>/dev/null && echo "ns=active" || true
systemctl is-active rmq-broker  2>/dev/null && echo "broker=active" || true
ss -ltn 2>/dev/null | grep -E ':9876|:10911|:10912' || echo "no-rmq-port"
