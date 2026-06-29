#!/bin/bash
set -e

echo "=== ES Initialization Script for Rocky 9.6 ==="
echo "Started at $(date)"

# Variables
ES_VERSION="6.8.1"
ES_USER="elasticsearch"
ES_HOME="/esdata/elasticsearch-${ES_VERSION}"
ES_DATA_DIR="/esdata"
ES_LOG_DIR="/var/log/elasticsearch"
DEVICE="/dev/sdc"  # Standard second disk in Azure

# Upgrade Rocky to latest version
echo "Upgrading Rocky Linux to latest version..."
sudo dnf update -y
sudo dnf upgrade -y

# Wait for disk to appear
echo "Waiting for data disk to appear..."
for i in {1..60}; do
    if [ -b "$DEVICE" ]; then
        echo "Disk $DEVICE found"
        break
    fi
    if [ $i -eq 60 ]; then
        echo "ERROR: Disk $DEVICE not found after 60 seconds"
        exit 1
    fi
    sleep 1
done

# Check if disk is already formatted
if ! sudo blkid $DEVICE; then
    echo "Formatting disk with XFS..."
    sudo mkfs.xfs -f $DEVICE
else
    echo "Disk already formatted"
fi

# Create mount point
echo "Creating mount point $ES_DATA_DIR..."
sudo mkdir -p $ES_DATA_DIR

# Get UUID
UUID=$(sudo blkid -s UUID -o value $DEVICE)
echo "Disk UUID: $UUID"

# Add to fstab if not already present
if ! grep -q "$UUID" /etc/fstab; then
    echo "Adding disk to /etc/fstab..."
    echo "UUID=$UUID $ES_DATA_DIR xfs defaults,nofail 0 2" | sudo tee -a /etc/fstab
fi

# Mount disk
echo "Mounting disk..."
sudo mount -a
sudo chown -R $(whoami):$(whoami) $ES_DATA_DIR
df -h $ES_DATA_DIR

echo "Disk mounted successfully"

# Install essential packages
echo "Installing essential packages..."
sudo dnf install -y wget curl unzip

# Install Java 8 (required for ES 6.8.1)
echo "Installing Java 8..."
sudo dnf install -y java-1.8.0-openjdk java-1.8.0-openjdk-devel

java -version
echo "Java installed successfully"

# Download Elasticsearch
echo "Downloading Elasticsearch $ES_VERSION..."
cd $ES_DATA_DIR
wget -q https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-$ES_VERSION.tar.gz
tar -xzf elasticsearch-$ES_VERSION.tar.gz
rm elasticsearch-$ES_VERSION.tar.gz

# Create elasticsearch user if not exists
if ! id "$ES_USER" &>/dev/null; then
    echo "Creating elasticsearch user..."
    sudo useradd -m -s /bin/bash $ES_USER
fi

# Set permissions
sudo chown -R $ES_USER:$ES_USER $ES_DATA_DIR
sudo mkdir -p $ES_LOG_DIR
sudo chown -R $ES_USER:$ES_USER $ES_LOG_DIR

# Increase file descriptors
echo "Configuring system limits..."
sudo sh -c 'echo "elasticsearch soft nofile 65536" >> /etc/security/limits.conf'
sudo sh -c 'echo "elasticsearch hard nofile 65536" >> /etc/security/limits.conf'
sudo sh -c 'echo "elasticsearch soft memlock unlimited" >> /etc/security/limits.conf'
sudo sh -c 'echo "elasticsearch hard memlock unlimited" >> /etc/security/limits.conf'

# Tune kernel parameters
sudo sysctl -w vm.swappiness=1
sudo sysctl -w vm.max_map_count=262144
sudo sh -c 'echo "vm.swappiness=1" >> /etc/sysctl.conf'
sudo sh -c 'echo "vm.max_map_count=262144" >> /etc/sysctl.conf'

# Create elasticsearch.yml (will be replaced by ARM template)
echo "Configuring Elasticsearch..."
cat > /tmp/elasticsearch.yml << 'EOF'
# ===== Elasticsearch Configuration =====
cluster.name: es-dsv6-cluster
node.name: ${HOSTNAME}
node.master: true
node.data: true

# Data directory
path.data: /esdata/data
path.logs: /var/log/elasticsearch

# Network
network.host: 0.0.0.0
http.port: 9200
transport.tcp.port: 9300

# Discovery (will be customized per node)
discovery.zen.ping.unicast.hosts: ["10.0.0.7", "10.0.0.8", "10.0.0.9"]
discovery.zen.minimum_master_nodes: 2

# AZ Awareness
node.attr.zone: zone1

# JVM Heap
-Xms8g
-Xmx8g

# Bootstrap checks bypass (for dev/test)
bootstrap.ignore_system_bootstrap_checks: true
EOF

sudo cp /tmp/elasticsearch.yml $ES_HOME/config/elasticsearch.yml
sudo chown $ES_USER:$ES_USER $ES_HOME/config/elasticsearch.yml

# Create systemd service
echo "Creating systemd service..."
sudo tee /etc/systemd/system/elasticsearch.service > /dev/null << EOF
[Unit]
Description=Elasticsearch
Documentation=https://www.elastic.co
Wants=network-online.target
After=network-online.target

[Service]
Type=notify
RuntimeDirectory=elasticsearch
Environment=ES_HOME=$ES_HOME
Environment=ES_PATH_CONF=$ES_HOME/config
User=$ES_USER
Group=$ES_USER
ProtectSystem=full
ProtectHome=yes
NoNewPrivileges=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictRealtime=yes
RestrictNamespaces=yes
LockPersonality=yes
MemoryDenyWriteExecute=yes
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
SystemCallFilter=@system-service
SystemCallErrorNumber=EPERM

ExecStart=$ES_HOME/bin/elasticsearch
Restart=on-failure
RestartForceExitStatus=5
TimeoutStartSec=600

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable elasticsearch

# Create data directory
sudo mkdir -p /esdata/data
sudo chown $ES_USER:$ES_USER /esdata/data

# Start Elasticsearch
echo "Starting Elasticsearch..."
sudo systemctl start elasticsearch
sleep 10

# Check if ES is running
if curl -s http://localhost:9200/_cluster/health | grep -q "status"; then
    echo "Elasticsearch started successfully"
else
    echo "WARNING: Elasticsearch may not have started properly"
    sudo journalctl -u elasticsearch -n 50
fi

echo "=== Initialization Complete ==="
echo "Completed at $(date)"
