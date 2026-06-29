#!/bin/bash
set -e
echo "=== install esrally on $(hostname) ==="

# Rocky 9 build deps + JDK (esrally load driver needs a JDK)
dnf install -y python3-pip python3-devel gcc git java-11-openjdk-devel 2>&1 | tail -n 3
JAVA11=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")
echo "JAVA_HOME candidate: $JAVA11"

# install esrally in an isolated virtualenv to avoid clashing with rpm-managed
# system packages (e.g. requests 2.25.1 which pip cannot uninstall)
python3 -m venv /opt/rally-venv
/opt/rally-venv/bin/pip install --upgrade pip 2>&1 | tail -n 2
/opt/rally-venv/bin/pip install esrally 2>&1 | tail -n 8

# expose esrally on PATH
ln -sf /opt/rally-venv/bin/esrally /usr/local/bin/esrally

echo "--- verify ---"
which esrally
esrally --version 2>&1 | head -n 3

# persist JAVA_HOME for interactive shells
cat > /etc/profile.d/esrally.sh <<EOF
export JAVA_HOME=$JAVA11
export PATH=\$JAVA_HOME/bin:/opt/rally-venv/bin:\$PATH
EOF

echo "=== done $(hostname) ==="
