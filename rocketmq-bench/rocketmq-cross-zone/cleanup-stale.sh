#!/bin/bash
# cleanup-stale.sh — kill leftover detached setup procs and recover dnf/rpm
# state left behind by the interrupted 'dnf distro-sync'. Safe to re-run.
echo "host: $(hostname)"

# kill any lingering detached setup runs / dnf from the previous attempt
pkill -f 'broker-setup-run.sh'  2>/dev/null || true
pkill -f 'ns-setup-run.sh'      2>/dev/null || true
pkill -f 'setup-broker.sh'      2>/dev/null || true
pkill -f 'setup-nameserver.sh'  2>/dev/null || true
pkill -x dnf                    2>/dev/null || true
pkill -f 'dnf'                  2>/dev/null || true
sleep 2

# clear any stale dnf lock
rm -f /var/cache/dnf/*.pid 2>/dev/null || true

# recover an interrupted rpm/dnf transaction
rpm --rebuilddb 2>/dev/null || true
dnf -y install dnf-plugins-core >/dev/null 2>&1 || true
dnf history redo last >/dev/null 2>&1 || true

echo "java now: $(command -v java || echo none)"
echo "dnf running: $(pgrep -x dnf >/dev/null && echo yes || echo no)"
echo "cleanup done"
