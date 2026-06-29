#!/bin/bash
echo '=== internet egress test (apache archive) ==='
curl -sS -I --max-time 20 https://archive.apache.org/dist/rocketmq/4.9.7/rocketmq-all-4.9.7-bin-release.zip 2>&1 | head -n 5
echo "curl_exit=$?"
echo '=== dnf java availability ==='
dnf -q list available java-11-openjdk 2>&1 | tail -n 3
echo '=== unzip present? ==='
which unzip || echo "no unzip"
