#!/bin/bash
# Install OpenJDK 11 on the Rocky Linux client.
set -e
grep -q '^ip_resolve=4' /etc/dnf/dnf.conf 2>/dev/null || echo 'ip_resolve=4' >> /etc/dnf/dnf.conf
echo "=== installing java-11-openjdk ==="
dnf install -y java-11-openjdk java-11-openjdk-devel
JAVA_DIR=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")
cat > /etc/profile.d/java.sh <<EOF
export JAVA_HOME=${JAVA_DIR}
export PATH=\$JAVA_HOME/bin:\$PATH
EOF
chmod 644 /etc/profile.d/java.sh
echo "=== java version ==="
java -version
echo "JAVA_HOME=${JAVA_DIR}"
