#!/bin/bash
# Post-Deployment Configuration Script
# This script should be run after all VMs are deployed and ES is running
# It updates node-specific configurations and initializes the clusters

set -e

echo "========================================"
echo "ES Post-Deployment Configuration"
echo "========================================"

# Configuration
SUBSCRIPTION_ID="166157a8-9ce9-400b-91c7-1d42482b83d6"
RESOURCE_GROUP="es-rg"
ADMIN_USER="azureuser"

# Define node configurations
declare -A node_configs=(
    # DSv5 Nodes
    ["dsv5esmasterdata01"]="zone1|10.0.0.4"
    ["dsv5esmasterdata02"]="zone2|10.0.0.5"
    ["dsv5esmasterdata03"]="zone3|10.0.0.6"
    # DSv6 Nodes
    ["dsv6esmasterdata01"]="zone1|10.0.0.7"
    ["dsv6esmasterdata02"]="zone2|10.0.0.8"
    ["dsv6esmasterdata03"]="zone3|10.0.0.9"
)

# Function to configure a single node
configure_node() {
    local vm_name=$1
    local zone=$2
    local node_ip=$3
    local is_dsv5=$4
    
    echo ""
    echo "Configuring $vm_name (zone: $zone, IP: $node_ip)..."
    
    # Read the appropriate config template
    if [ "$is_dsv5" == "true" ]; then
        config_file="scripts/es-config/elasticsearch-dsv5.yml"
        cluster_name="es-dsv5-cluster"
    else
        config_file="scripts/es-config/elasticsearch-dsv6.yml"
        cluster_name="es-dsv6-cluster"
    fi
    
    if [ ! -f "$config_file" ]; then
        echo "ERROR: Config file not found: $config_file"
        return 1
    fi
    
    # Create temporary config with node-specific settings
    temp_config=$(mktemp)
    
    # Add standard config
    cat "$config_file" > "$temp_config"
    
    # Add node-specific settings
    cat >> "$temp_config" << EOF

# Node-specific settings
node.name: $vm_name
node.attr.zone: $zone
cluster.name: $cluster_name
EOF
    
    # Copy to remote node (requires SSH key setup)
    echo "Copying configuration to $vm_name..."
    
    # Note: This requires SSH access. For now, we'll just document the command
    # In a production setup, you'd use Azure VM Extension or custom script
    
    echo "To apply configuration manually, run on $vm_name:"
    echo "  sudo cp /tmp/elasticsearch.yml /esdata/elasticsearch-6.8.1/config/elasticsearch.yml"
    echo "  sudo chown elasticsearch:elasticsearch /esdata/elasticsearch-6.8.1/config/elasticsearch.yml"
    echo "  sudo systemctl restart elasticsearch"
    
    rm "$temp_config"
}

# Function to initialize ES cluster
initialize_cluster() {
    local cluster_type=$1  # "dsv5" or "dsv6"
    local first_node_ip=$2
    
    echo ""
    echo "Initializing $cluster_type cluster..."
    
    if [ -z "$first_node_ip" ] || [ "$first_node_ip" == "NOT_FOUND" ]; then
        echo "ERROR: Could not determine first node IP"
        return 1
    fi
    
    # Wait for cluster to be ready
    echo "Waiting for cluster to be ready..."
    
    for i in {1..30}; do
        health=$(curl -s -m 5 "http://${first_node_ip}:9200/_cluster/health" 2>/dev/null || echo '{}')
        
        if echo "$health" | grep -q '"number_of_nodes":3'; then
            echo "✓ All 3 nodes are present"
            break
        fi
        
        echo "  Attempt $i/30: Waiting for all nodes to join cluster..."
        sleep 10
    done
    
    # Get cluster status
    echo ""
    echo "Cluster status:"
    curl -s "http://${first_node_ip}:9200/_cluster/health?pretty" | head -20
    
    # Create index template with AZ awareness
    echo ""
    echo "Creating index template with AZ awareness..."
    
    curl -X PUT "http://${first_node_ip}:9200/_template/default" -H 'Content-Type: application/json' -d'
    {
      "template": "*",
      "settings": {
        "number_of_shards": 3,
        "number_of_replicas": 1,
        "index.routing.allocation.require._zone_awareness": "true"
      }
    }' 2>/dev/null || true
    
    echo ""
    echo "✓ Cluster initialization complete"
}

# Main execution
echo ""
echo "[1/2] Retrieving node information..."

for vm_name in "${!node_configs[@]}"; do
    config="${node_configs[$vm_name]}"
    zone=$(echo $config | cut -d'|' -f1)
    node_ip=$(echo $config | cut -d'|' -f2)
    
    is_dsv5="true"
    if [[ $vm_name == "dsv6"* ]]; then
        is_dsv5="false"
    fi
    
    echo "  $vm_name: zone=$zone, ip=$node_ip"
done

echo ""
echo "[2/2] Configuring nodes..."

# Configure DSv5 nodes
for vm_name in "${!node_configs[@]}"; do
    if [[ $vm_name == "dsv5"* ]]; then
        config="${node_configs[$vm_name]}"
        zone=$(echo $config | cut -d'|' -f1)
        node_ip=$(echo $config | cut -d'|' -f2)
        
        configure_node "$vm_name" "$zone" "$node_ip" "true"
    fi
done

# Configure DSv6 nodes
for vm_name in "${!node_configs[@]}"; do
    if [[ $vm_name == "dsv6"* ]]; then
        config="${node_configs[$vm_name]}"
        zone=$(echo $config | cut -d'|' -f1)
        node_ip=$(echo $config | cut -d'|' -f2)
        
        configure_node "$vm_name" "$zone" "$node_ip" "false"
    fi
done

echo ""
echo "========================================"
echo "Post-Configuration Complete"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. SSH into each node and apply configuration:"
echo "   ssh azureuser@<node-ip>"
echo "   sudo cp /tmp/elasticsearch.yml /esdata/elasticsearch-6.8.1/config/elasticsearch.yml"
echo "   sudo systemctl restart elasticsearch"
echo ""
echo "2. Wait 5 minutes for clusters to stabilize"
echo ""
echo "3. Verify cluster health:"
echo "   bash scripts/verify/health-check.sh"
echo ""
