#!/bin/bash
D=/datadisk/rocketmq/logs
echo "=== log files ==="
ls -la $D 2>/dev/null
echo "=== grep stack traces across all logs (last 60) ==="
grep -rhnE '(\bat org\.apache|Exception:|Caused by:|java\.net\.|java\.io\.IOException|RuntimeException|Error:)' $D 2>/dev/null | tail -60
