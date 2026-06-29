#!/bin/bash
set -e

echo "=== Rally Installation Script for Rocky 9.6 ==="
echo "Started at $(date)"

# Upgrade Rocky to latest version
echo "Upgrading Rocky Linux to latest version..."
sudo dnf update -y
sudo dnf upgrade -y

# Install essential packages
echo "Installing essential packages..."
sudo dnf install -y wget curl git python3 python3-pip python3-devel gcc

# Install Python 3.9+ for Rally
echo "Installing Python 3.9..."
sudo dnf install -y python3.9 python3.9-devel python3.9-pip

# Create a virtual environment for Rally
echo "Creating Python virtual environment..."
python3.9 -m venv /opt/rally-env
source /opt/rally-env/bin/activate

# Upgrade pip
pip install --upgrade pip setuptools wheel

# Install Elasticsearch Rally
echo "Installing Elasticsearch Rally..."
pip install esrally

# Verify Rally installation
rally --version

# Create rally directory structure
echo "Setting up Rally configuration..."
mkdir -p ~/.rally/benchmarks
mkdir -p ~/.rally/logging

# Basic Rally configuration
mkdir -p ~/.rally
cat > ~/.rally/rally.ini << 'EOF'
[meta]
config.version = 2

[system]
available.cores = 32
available.memory.gb = 128

[reporting]
console.numbers.formatting = plain

[distributions]
release.cache = true
EOF

# Make Rally activation easier
echo "source /opt/rally-env/bin/activate" | tee -a ~/.bashrc

# Create a helper script for running Rally against ES clusters
cat > /home/$(whoami)/run-rally.sh << 'EOF'
#!/bin/bash

# Helper script to run Rally against ES clusters

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <cluster-name> <track> [--test-mode]"
    echo ""
    echo "Examples:"
    echo "  $0 dsv5-cluster default"
    echo "  $0 dsv6-cluster default --test-mode"
    exit 1
fi

CLUSTER_NAME=$1
TRACK=$2
TEST_MODE=${3:-}

source /opt/rally-env/bin/activate

# Determine cluster endpoint based on name
if [[ "$CLUSTER_NAME" == "dsv5-cluster" ]]; then
    ENDPOINTS="10.0.0.4:9200,10.0.0.5:9200,10.0.0.6:9200"
elif [[ "$CLUSTER_NAME" == "dsv6-cluster" ]]; then
    ENDPOINTS="10.0.0.7:9200,10.0.0.8:9200,10.0.0.9:9200"
else
    echo "Unknown cluster: $CLUSTER_NAME"
    exit 1
fi

echo "Running Rally against $CLUSTER_NAME ($ENDPOINTS)"
echo "Track: $TRACK"
echo "Test Mode: ${TEST_MODE:-disabled}"

# Run Rally
if [ "$TEST_MODE" == "--test-mode" ]; then
    rally race --track=$TRACK --target-hosts=$ENDPOINTS --test-mode
else
    rally race --track=$TRACK --target-hosts=$ENDPOINTS
fi
EOF

chmod +x /home/$(whoami)/run-rally.sh

echo ""
echo "=== Rally Installation Complete ==="
echo "Completed at $(date)"
echo ""
echo "To use Rally:"
echo "1. Activate environment: source /opt/rally-env/bin/activate"
echo "2. Run Rally: rally race --track=<track-name> --target-hosts=<host:port>"
echo "3. Or use helper script: ~/run-rally.sh <cluster-name> <track>"
