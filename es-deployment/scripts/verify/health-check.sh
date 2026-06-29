#!/bin/bash
# Elasticsearch Cluster Health Check Script

set -e

echo "========================================"
echo "ES Cluster Health Check"
echo "========================================"

# Configuration
SUBSCRIPTION_ID="166157a8-9ce9-400b-91c7-1d42482b83d6"
RESOURCE_GROUP="es-rg"

# Get node IPs from Azure
echo ""
echo "[1/4] Retrieving VM information from Azure..."

DSV5_VMS=("dsv5esmasterdata01" "dsv5esmasterdata02" "dsv5esmasterdata03")
DSV6_VMS=("dsv6esmasterdata01" "dsv6esmasterdata02" "dsv6esmasterdata03")
CLIENT_VMS=("clientvm01" "clientvm02")

declare -A dsv5_ips
declare -A dsv6_ips
declare -A client_ips

echo "DSv5 Cluster:"
for vm in "${DSV5_VMS[@]}"; do
    nic_name="${vm}-nic"
    ip=$(az network nic show --resource-group "$RESOURCE_GROUP" --name "$nic_name" --query 'ipConfigurations[0].privateIPAddress' -o tsv 2>/dev/null || echo "NOT_FOUND")
    dsv5_ips[$vm]=$ip
    echo "  $vm: $ip"
done

echo ""
echo "DSv6 Cluster:"
for vm in "${DSV6_VMS[@]}"; do
    nic_name="${vm}-nic"
    ip=$(az network nic show --resource-group "$RESOURCE_GROUP" --name "$nic_name" --query 'ipConfigurations[0].privateIPAddress' -o tsv 2>/dev/null || echo "NOT_FOUND")
    dsv6_ips[$vm]=$ip
    echo "  $vm: $ip"
done

echo ""
echo "Client VMs:"
for vm in "${CLIENT_VMS[@]}"; do
    nic_name="${vm}-nic"
    ip=$(az network nic show --resource-group "$RESOURCE_GROUP" --name "$nic_name" --query 'ipConfigurations[0].privateIPAddress' -o tsv 2>/dev/null || echo "NOT_FOUND")
    client_ips[$vm]=$ip
    echo "  $vm: $ip"
done

# Function to check cluster health
check_cluster_health() {
    local cluster_name=$1
    local first_node_ip=$2
    
    if [ "$first_node_ip" == "NOT_FOUND" ]; then
        echo "    ⚠ Node IP not found"
        return 1
    fi
    
    echo "    Checking cluster health..."
    
    local response=$(curl -s -m 5 "http://${first_node_ip}:9200/_cluster/health" 2>/dev/null || echo '{"status":"error"}')
    
    if echo "$response" | grep -q "status"; then
        local status=$(echo "$response" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
        local nodes=$(echo "$response" | grep -o '"number_of_nodes":[0-9]*' | cut -d':' -f2)
        local active_shards=$(echo "$response" | grep -o '"active_shards":[0-9]*' | cut -d':' -f2)
        
        echo "    Status: $status"
        echo "    Nodes: $nodes"
        echo "    Active Shards: $active_shards"
        
        if [ "$status" == "green" ] && [ "$nodes" == "3" ]; then
            echo "    ✓ Cluster is healthy"
            return 0
        else
            echo "    ⚠ Cluster is not fully healthy yet"
            return 1
        fi
    else
        echo "    ✗ No response from cluster (still initializing?)"
        return 1
    fi
}

# Function to check node details
check_node_details() {
    local cluster_name=$1
    local first_node_ip=$2
    
    if [ "$first_node_ip" == "NOT_FOUND" ]; then
        return 1
    fi
    
    echo "    Checking node details..."
    
    local response=$(curl -s -m 5 "http://${first_node_ip}:9200/_nodes?pretty" 2>/dev/null || echo '{}')
    
    if echo "$response" | grep -q "zone"; then
        echo "    ✓ Nodes have zone attributes"
        
        # Print zone distribution
        echo "    Zone distribution:"
        echo "$response" | grep -o '"zone":"[^"]*"' | sort | uniq -c || true
    else
        echo "    ⚠ Nodes don't have zone attributes"
    fi
}

# Function to check ES process
check_es_process() {
    local vm_name=$1
    local ip=$2
    
    if [ "$ip" == "NOT_FOUND" ]; then
        return 1
    fi
    
    # This would require SSH, so we'll just note that it requires SSH access
    echo "    Note: To check ES process, run:"
    echo "    ssh azureuser@${ip} 'systemctl status elasticsearch'"
}

# Check DSv5 Cluster
echo ""
echo "[2/4] Checking DSv5 Cluster..."
first_dsv5_ip=${dsv5_ips["dsv5esmasterdata01"]}
check_cluster_health "DSv5" "$first_dsv5_ip"
check_node_details "DSv5" "$first_dsv5_ip"

# Check DSv6 Cluster
echo ""
echo "[3/4] Checking DSv6 Cluster..."
first_dsv6_ip=${dsv6_ips["dsv6esmasterdata01"]}
check_cluster_health "DSv6" "$first_dsv6_ip"
check_node_details "DSv6" "$first_dsv6_ip"

# Check Client VMs
echo ""
echo "[4/4] Checking Client VMs..."
first_client_ip=${client_ips["clientvm01"]}
if [ "$first_client_ip" != "NOT_FOUND" ]; then
    echo "    Checking Rally installation..."
    # This would require SSH, so we'll just note that it requires SSH access
    echo "    Note: To verify Rally, run:"
    echo "    ssh azureuser@${first_client_ip} 'source /opt/rally-env/bin/activate && rally --version'"
else
    echo "    ⚠ Client VM IP not found"
fi

echo ""
echo "========================================"
echo "Health Check Complete"
echo "========================================"
echo ""
echo "Manual verification steps:"
echo "1. SSH to a DSv5 node: ssh azureuser@${first_dsv5_ip}"
echo "2. Check ES status: curl http://localhost:9200/_cluster/health?pretty"
echo "3. Check nodes: curl http://localhost:9200/_nodes?pretty"
echo "4. Check disk: df -h /esdata"
echo ""
echo "To run benchmarks later:"
echo "1. SSH to client VM: ssh azureuser@${first_client_ip}"
echo "2. Run Rally: source /opt/rally-env/bin/activate"
echo "3. Execute tests: ~/run-rally.sh dsv5-cluster default"
echo ""
