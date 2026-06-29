#!/bin/bash
# Run on control machine (clientvm01/02) as root via Azure Run Command.
# Installs TiUP + cluster component, generates an SSH keypair, prints public key.
set -e

# 1) Install TiUP (idempotent)
if [ ! -x /root/.tiup/bin/tiup ]; then
  export TIUP_HOME=/root/.tiup
  curl --proto '=https' --tlsv1.2 -sSf https://tiup-mirrors.pingcap.com/install.sh | sh
fi
export PATH=/root/.tiup/bin:$PATH

# 2) Install/confirm cluster component
/root/.tiup/bin/tiup install cluster >/dev/null 2>&1 || true

echo "TIUP_VERSION:"
/root/.tiup/bin/tiup --version 2>/dev/null | head -1 || true

# 3) Generate root SSH keypair (no passphrase) if missing
if [ ! -f /root/.ssh/id_rsa ]; then
  mkdir -p /root/.ssh && chmod 700 /root/.ssh
  ssh-keygen -t rsa -b 4096 -N "" -f /root/.ssh/id_rsa -q
fi

# 4) Emit public key between markers for harvesting
echo "PUBKEY_BEGIN"
cat /root/.ssh/id_rsa.pub
echo "PUBKEY_END"
