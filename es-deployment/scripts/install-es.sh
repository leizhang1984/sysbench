#!/bin/bash
# Elasticsearch 6.8.1 install + configure script (run via Azure run-command, as root)
# Positional args:
#   $1 = CLUSTER_NAME   (e.g. es-dsv5-cluster)
#   $2 = SEED_HOSTS     (comma-separated, e.g. 10.122.0.4,10.122.0.5,10.122.0.6)
#   $3 = ZONE           (zone1|zone2|zone3)
#   $4 = PKG_MGR        (yum|dnf)
#   $5 = HEAP           (e.g. 8g)
set -e

CLUSTER_NAME="$1"
SEED_HOSTS="$2"
ZONE="$3"
PKG_MGR="$4"
HEAP="${5:-8g}"
NODE_NAME="$(hostname)"

echo "=== ES install: cluster=$CLUSTER_NAME zone=$ZONE pkg=$PKG_MGR heap=$HEAP node=$NODE_NAME ==="

# ---------- 1. Detect & prepare data disk ----------
if mountpoint -q /esdata; then
  echo "Data disk already mounted at /esdata, skipping disk setup."
else
  DEVICE=""
  if [ -e /dev/disk/azure/scsi1/lun0 ]; then
    DEVICE=$(readlink -f /dev/disk/azure/scsi1/lun0)
  elif [ -e /dev/disk/azure/data/by-lun/0 ]; then
    DEVICE=$(readlink -f /dev/disk/azure/data/by-lun/0)
  else
    # fallback: first disk with no mountpoint and no partitions
    for d in $(lsblk -dpn -o NAME,TYPE | awk '$2=="disk"{print $1}'); do
      mp=$(lsblk -n -o MOUNTPOINT "$d" | tr -d ' \n')
      children=$(lsblk -n "$d" | wc -l)
      if [ -z "$mp" ] && [ "$children" = "1" ]; then DEVICE="$d"; break; fi
    done
  fi
  echo "Data disk device: $DEVICE"

  if [ -z "$DEVICE" ]; then echo "ERROR: no data disk found"; exit 1; fi

  # format only if not already xfs
  if ! blkid "$DEVICE" | grep -q xfs; then
    echo "Formatting $DEVICE as xfs..."
    mkfs.xfs -f "$DEVICE"
  fi

  mkdir -p /esdata
  UUID=$(blkid -s UUID -o value "$DEVICE")
  if ! grep -q "$UUID" /etc/fstab; then
    echo "UUID=$UUID /esdata xfs defaults,noatime 0 0" >> /etc/fstab
  fi
  mountpoint -q /esdata || mount /esdata
fi
mkdir -p /esdata/data

# ---------- 2. Install Java 8 ----------
# CentOS 7 is EOL: its yum mirrors are gone, so package install may fail.
# Fall back to a portable Temurin JDK 8 tarball downloaded over HTTPS (DNS works).
echo "Installing Java 8..."
$PKG_MGR install -y java-1.8.0-openjdk java-1.8.0-openjdk-devel 2>/dev/null || true

if command -v java >/dev/null 2>&1; then
  JAVA_BIN=$(readlink -f "$(command -v java)")
  export JAVA_HOME="${JAVA_BIN%/bin/java}"
else
  echo "Package java unavailable; downloading portable Temurin JDK 8..."
  mkdir -p /opt/jdk8
  cd /tmp
  curl -fSL -o jdk8.tar.gz "https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u422-b05/OpenJDK8U-jdk_x64_linux_hotspot_8u422b05.tar.gz"
  tar -xzf jdk8.tar.gz -C /opt/jdk8 --strip-components=1
  export JAVA_HOME=/opt/jdk8
fi
export PATH="$JAVA_HOME/bin:$PATH"
echo "JAVA_HOME=$JAVA_HOME"
java -version || { echo "ERROR: java not available"; exit 1; }

# ---------- 3. Install Elasticsearch 6.8.1 ----------
if ! rpm -q elasticsearch >/dev/null 2>&1; then
  echo "Downloading Elasticsearch 6.8.1 RPM..."
  cd /tmp
  curl -fSL -o elasticsearch-6.8.1.rpm https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-6.8.1.rpm
  JAVA_HOME="$JAVA_HOME" PATH="$JAVA_HOME/bin:$PATH" rpm -iv elasticsearch-6.8.1.rpm
fi

# ---------- 4. Ownership ----------
chown -R elasticsearch:elasticsearch /esdata
mkdir -p /var/log/elasticsearch
chown -R elasticsearch:elasticsearch /var/log/elasticsearch

# ---------- 5. Write elasticsearch.yml ----------
SEEDS_YAML=$(echo "$SEED_HOSTS" | tr ',' '\n' | sed 's/^/  - /')
cat > /etc/elasticsearch/elasticsearch.yml <<EOF
cluster.name: $CLUSTER_NAME
node.name: $NODE_NAME
node.master: true
node.data: true
node.ingest: false
node.attr.zone: $ZONE

network.host: 0.0.0.0
http.port: 9200
transport.tcp.port: 9300

path.data: /esdata/data
path.logs: /var/log/elasticsearch

discovery.zen.ping.unicast.hosts:
$SEEDS_YAML
discovery.zen.minimum_master_nodes: 2

cluster.routing.allocation.awareness.attributes: zone
cluster.routing.allocation.awareness.force.zone.values: zone1,zone2,zone3

bootstrap.memory_lock: false
EOF

# ---------- 6. JVM heap (ES 6.8 has no jvm.options.d; edit jvm.options directly) ----------
sed -i -E "s/^-Xms.*/-Xms$HEAP/; s/^-Xmx.*/-Xmx$HEAP/" /etc/elasticsearch/jvm.options
grep -q '^-Xms' /etc/elasticsearch/jvm.options || echo "-Xms$HEAP" >> /etc/elasticsearch/jvm.options
grep -q '^-Xmx' /etc/elasticsearch/jvm.options || echo "-Xmx$HEAP" >> /etc/elasticsearch/jvm.options

# ---------- 7. System limits & sysctl ----------
sysctl -w vm.max_map_count=262144
grep -q 'vm.max_map_count' /etc/sysctl.conf || echo 'vm.max_map_count=262144' >> /etc/sysctl.conf

# restore the rpm's sysconfig if a prior run clobbered it (saved as .rpmnew)
if [ -f /etc/sysconfig/elasticsearch.rpmnew ]; then
  mv -f /etc/sysconfig/elasticsearch.rpmnew /etc/sysconfig/elasticsearch
fi

mkdir -p /etc/systemd/system/elasticsearch.service.d
cat > /etc/systemd/system/elasticsearch.service.d/override.conf <<EOF
[Service]
Environment=JAVA_HOME=$JAVA_HOME
LimitMEMLOCK=infinity
LimitNOFILE=65536
EOF

# ---------- 8. Start service ----------
# ensure keystore exists (some posttrans scriptlets fail to create it)
if [ ! -f /etc/elasticsearch/elasticsearch.keystore ]; then
  ES_PATH_CONF=/etc/elasticsearch JAVA_HOME="$JAVA_HOME" /usr/share/elasticsearch/bin/elasticsearch-keystore create || true
  chown root:elasticsearch /etc/elasticsearch/elasticsearch.keystore 2>/dev/null || true
  chmod 660 /etc/elasticsearch/elasticsearch.keystore 2>/dev/null || true
fi

systemctl daemon-reload
systemctl enable elasticsearch
systemctl restart elasticsearch

sleep 5
systemctl --no-pager status elasticsearch | head -n 15
echo "=== ES install script done on $NODE_NAME ==="
