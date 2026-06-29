#!/bin/bash
# Install sysbench, mysql client, sysstat on a Rocky 9 client.
set -e
echo "===== install epel ====="
dnf install -y epel-release >/dev/null 2>&1 || true
echo "===== install tools ====="
dnf install -y sysbench mysql sysstat >/dev/null 2>&1
echo "===== verify ====="
command -v sysbench >/dev/null 2>&1 && echo "sysbench=YES $(sysbench --version)" || echo "sysbench=NO"
command -v mysql >/dev/null 2>&1 && echo "mysql=YES $(mysql --version)" || echo "mysql=NO"
command -v mpstat >/dev/null 2>&1 && echo "mpstat=YES" || echo "mpstat=NO"
echo "===== DONE ====="
