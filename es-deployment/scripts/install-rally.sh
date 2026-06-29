#!/bin/bash
set -e
echo "=== install esrally on $(hostname) ==="

# Rocky 9: install pip, git and build deps
dnf install -y python3-pip python3-devel gcc git 2>&1 | tail -n 5

python3 -m pip install --upgrade pip 2>&1 | tail -n 3

# esrally needs a JDK to drive ES; install Java 11 (used only by the load driver)
dnf install -y java-11-openjdk-devel 2>&1 | tail -n 3
JAVA11=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")
echo "JAVA_HOME candidate: $JAVA11"

# install esrally system-wide
python3 -m pip install esrally 2>&1 | tail -n 8

echo "--- verify ---"
which esrally
esrally --version 2>&1 | head -n 3

# persist JAVA_HOME for the azureadmin/azureuser shells
for f in /etc/profile.d/esrally.sh; do
  echo "export JAVA_HOME=$JAVA11" > "$f"
  echo 'export PATH=$JAVA_HOME/bin:$PATH' >> "$f"
done

echo "=== done $(hostname) ==="
