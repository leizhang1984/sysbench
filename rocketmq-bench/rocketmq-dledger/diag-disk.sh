#!/bin/bash
echo "=== HOST: $(hostname) ==="
echo "--- store dir usage breakdown ---"
du -sh /datadisk/rocketmq/store/* 2>/dev/null | sort -rh | head -15
echo "--- commitlog files ---"
ls -lh /datadisk/rocketmq/store/commitlog 2>/dev/null | head
du -sh /datadisk/rocketmq/store/commitlog 2>/dev/null
echo "--- dledger commitlog dir ---"
ls -lh /datadisk/rocketmq/store/dledger-* 2>/dev/null | head
du -sh /datadisk/rocketmq/store/dledger-* 2>/dev/null
echo "--- non-INFO lines around shutdown (tail) ---"
grep -vE ' INFO ' /datadisk/rocketmq/logs/broker.log 2>/dev/null | tail -30
