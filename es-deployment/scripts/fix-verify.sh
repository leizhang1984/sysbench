#!/bin/bash
# Idempotent fix + health check, run via Azure run-command (@file)
sed -i '/bootstrap.ignore_system_bootstrap_checks/d' /etc/elasticsearch/elasticsearch.yml
systemctl restart elasticsearch
sleep 15
echo "service: $(systemctl is-active elasticsearch)"
echo "--- local node ---"
curl -s "http://localhost:9200/" 2>/dev/null | head -n 20
echo "--- cluster health ---"
curl -s "http://localhost:9200/_cluster/health?pretty" 2>/dev/null
echo "--- nodes ---"
curl -s "http://localhost:9200/_cat/nodes?v&h=name,ip,node.role,master" 2>/dev/null
echo "=== done $(hostname) ==="
