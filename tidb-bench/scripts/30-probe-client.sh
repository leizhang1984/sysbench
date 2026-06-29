#!/bin/bash
# Probe OS, existing bench tools, and repo/internet reachability on a client VM.
echo "===== OS ====="
cat /etc/os-release 2>/dev/null | grep -E '^(NAME|VERSION)=' || echo "no os-release"
echo "===== TOOLS ====="
command -v sysbench >/dev/null 2>&1 && echo "sysbench=YES $(sysbench --version 2>/dev/null)" || echo "sysbench=NO"
command -v mysql >/dev/null 2>&1 && echo "mysql=YES $(mysql --version 2>/dev/null)" || echo "mysql=NO"
command -v mariadb >/dev/null 2>&1 && echo "mariadb=YES" || echo "mariadb=NO"
command -v dnf >/dev/null 2>&1 && echo "dnf=YES" || echo "dnf=NO"
command -v mpstat >/dev/null 2>&1 && echo "mpstat=YES" || echo "mpstat=NO"
echo "===== REPOLIST ====="
dnf repolist 2>&1 | head -20 || true
echo "===== EPEL TEST ====="
timeout 8 bash -lc "</dev/tcp/dl.fedoraproject.org/443" 2>/dev/null && echo "fedora:443 OK" || echo "fedora:443 FAIL"
timeout 8 bash -lc "</dev/tcp/download.pingcap.org/443" 2>/dev/null && echo "pingcap:443 OK" || echo "pingcap:443 FAIL"
echo "===== DONE ====="
