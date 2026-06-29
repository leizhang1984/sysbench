#!/bin/bash
LOG=$(find / -name 'broker.log' 2>/dev/null | head -1)
echo "LOG=$LOG"
echo "=== real exceptions ==="
grep -nE 'Exception|Caused by|BindException|Address already|Error |error,|DLedger|Raft|refused|failed to|Failed to|cannot|Cannot' "$LOG" 2>/dev/null | grep -vE 'FastFailure|FailoverTopic|brokerFastFail|fastFail' | tail -40
echo "=== context around last shutdown ==="
grep -n 'Try to shutdown service thread:AllocateMappedFileService' "$LOG" | tail -1
