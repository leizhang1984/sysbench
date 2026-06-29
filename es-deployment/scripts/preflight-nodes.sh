#!/bin/bash
echo "=== $(hostname) ==="
echo "[mount] $(findmnt -no SOURCE,FSTYPE,SIZE,TARGET /esdata 2>/dev/null || echo NOT_MOUNTED)"
echo "[path.data] $(grep '^path.data' /etc/elasticsearch/elasticsearch.yml)"
echo "[es service] $(systemctl is-active elasticsearch)"
echo "[health] $(curl -s 'http://localhost:9200/_cluster/health?pretty' | tr -d '\n' | sed 's/  */ /g')"
echo "[df] $(df -h /esdata | tail -n1)"
echo "=== done ==="
