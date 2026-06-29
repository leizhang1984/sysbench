#!/bin/bash
# Install OpenJDK 11.0.25 (Red Hat build) on the Rocky Linux client.
set -e

echo "=== installing java-11-openjdk (Red Hat build 11.0.25) ==="
dnf install -y java-11-openjdk java-11-openjdk-devel

# Persist JAVA_HOME for all users
JAVA_DIR=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")
cat > /etc/profile.d/java.sh <<EOF
export JAVA_HOME=${JAVA_DIR}
export PATH=\$JAVA_HOME/bin:\$PATH
EOF
chmod 644 /etc/profile.d/java.sh

echo "=== java version ==="
java -version
echo "JAVA_HOME=${JAVA_DIR}"
