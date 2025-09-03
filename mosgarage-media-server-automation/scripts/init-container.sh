#!/bin/bash
# ===============================================
# INIT CONTAINER ORCHESTRATION SCRIPT
# ===============================================
# Handles service initialization, API key setup,
# and dependency management for Docker stack
# ===============================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DOCKER_DIR="$PROJECT_DIR/docker"
ENV_FILE="$DOCKER_DIR/.env"
CONFIGS_DIR="$DOCKER_DIR/configs"

log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') $*"
}

log_info() {
    log "${BLUE}[INIT]${NC} $*"
}

log_success() {
    log "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    log "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    log "${RED}[ERROR]${NC} $*"
}

# Initialize configuration directories
init_config_dirs() {
    log_info "Initializing configuration directories..."
    
    local services=(
        "sonarr" "radarr" "prowlarr" "bazarr" "overseerr"
        "transmission" "nzbget" "gluetun" "flaresolverr"
        "unpackerr" "cleanuparr" "huntarr"
        "grafana" "prometheus" "loki" "promtail"
    )
    
    for service in "${services[@]}"; do
        local config_dir="$CONFIGS_DIR/$service"
        if [[ ! -d "$config_dir" ]]; then
            mkdir -p "$config_dir"
            log_info "Created config directory: $service"
        fi
    done
    
    log_success "Configuration directories initialized"
}

# Set proper permissions for all config directories
set_config_permissions() {
    log_info "Setting configuration directory permissions..."
    
    # Get PUID/PGID from environment
    local puid=$(grep "^PUID=" "$ENV_FILE" | cut -d'=' -f2 || echo "1001")
    local pgid=$(grep "^PGID=" "$ENV_FILE" | cut -d'=' -f2 || echo "1001")
    
    # Set ownership for all config directories
    if [[ -d "$CONFIGS_DIR" ]]; then
        chown -R "${puid}:${pgid}" "$CONFIGS_DIR"
        chmod -R 755 "$CONFIGS_DIR"
        log_success "Set permissions: ${puid}:${pgid} for $CONFIGS_DIR"
    fi
}

# Create default Prometheus configuration
create_prometheus_config() {
    local prometheus_config="$CONFIGS_DIR/prometheus/prometheus.yml"
    
    if [[ ! -f "$prometheus_config" ]]; then
        log_info "Creating default Prometheus configuration..."
        
        mkdir -p "$(dirname "$prometheus_config")"
        
        cat > "$prometheus_config" << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'sonarr'
    static_configs:
      - targets: ['sonarr:8989']
    metrics_path: '/metrics'

  - job_name: 'radarr'
    static_configs:
      - targets: ['radarr:7878']
    metrics_path: '/metrics'

  - job_name: 'prowlarr'
    static_configs:
      - targets: ['prowlarr:9696']
    metrics_path: '/metrics'

  - job_name: 'transmission'
    static_configs:
      - targets: ['transmission:9091']
    metrics_path: '/transmission/web/metrics'
EOF
        
        log_success "Created Prometheus configuration"
    fi
}

# Create default Grafana provisioning
create_grafana_config() {
    local grafana_dir="$CONFIGS_DIR/grafana"
    
    if [[ ! -d "$grafana_dir/datasources" ]]; then
        log_info "Creating Grafana provisioning configuration..."
        
        mkdir -p "$grafana_dir/datasources"
        mkdir -p "$grafana_dir/dashboards"
        
        # Datasource configuration
        cat > "$grafana_dir/datasources/prometheus.yml" << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    editable: true
EOF
        
        # Dashboard provider
        cat > "$grafana_dir/dashboards/dashboard.yml" << 'EOF'
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF
        
        log_success "Created Grafana provisioning configuration"
    fi
}

# Create default Loki configuration
create_loki_config() {
    local loki_config="$CONFIGS_DIR/loki/local-config.yaml"
    
    if [[ ! -f "$loki_config" ]]; then
        log_info "Creating default Loki configuration..."
        
        mkdir -p "$(dirname "$loki_config")"
        
        cat > "$loki_config" << 'EOF'
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

query_range:
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

ruler:
  alertmanager_url: http://localhost:9093

# By default, Loki will send anonymous, but uniquely-identifiable usage and configuration
# analytics to Grafana Labs. These statistics are sent to https://stats.grafana.org/
#
# Statistics help us better understand how Loki is used, and they show us performance
# levels for most users. This helps us prioritize features and documentation.
# For more information on what's sent: https://github.com/grafana/loki/blob/main/pkg/usagestats/stats.go
# Refer to the buildReport method to see what goes into a report.
#
# If you would like to disable reporting, uncomment the following lines:
#analytics:
#  reporting_enabled: false
EOF
        
        log_success "Created Loki configuration"
    fi
}

# Create default Promtail configuration
create_promtail_config() {
    local promtail_config="$CONFIGS_DIR/promtail/config.yml"
    
    if [[ ! -f "$promtail_config" ]]; then
        log_info "Creating default Promtail configuration..."
        
        mkdir -p "$(dirname "$promtail_config")"
        
        cat > "$promtail_config" << 'EOF'
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*log

  - job_name: docker
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 5s
    relabel_configs:
      - source_labels: ['__meta_docker_container_name']
        regex: '/(.*)'
        target_label: 'container'
      - source_labels: ['__meta_docker_container_log_stream']
        target_label: 'stream'
EOF
        
        log_success "Created Promtail configuration"
    fi
}

# Create VPN health monitoring script
create_vpn_health_script() {
    local vpn_script="$CONFIGS_DIR/../scripts/vpn-health.sh"
    
    if [[ ! -f "$vpn_script" ]]; then
        log_info "Creating VPN health monitoring script..."
        
        mkdir -p "$(dirname "$vpn_script")"
        
        cat > "$vpn_script" << 'EOF'
#!/bin/sh
# VPN Health Monitor Script

VPN_CHECK_INTERVAL=${VPN_CHECK_INTERVAL:-60}
VPN_RESTART_THRESHOLD=${VPN_RESTART_THRESHOLD:-3}
FAILED_CHECKS=0

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [VPN-MONITOR] $*"
}

check_vpn_connection() {
    # Check if we can reach the VPN container
    if ! nc -z gluetun 8000 2>/dev/null; then
        log "ERROR: Cannot reach Gluetun container"
        return 1
    fi
    
    # Check VPN status via Gluetun API
    if ! curl -sf http://gluetun:8000/v1/openvpn/status | grep -q '"running":true'; then
        log "ERROR: VPN connection not active"
        return 1
    fi
    
    # Check external IP to ensure VPN is working
    EXTERNAL_IP=$(curl -sf --max-time 10 ifconfig.me 2>/dev/null || echo "")
    if [[ -z "$EXTERNAL_IP" ]]; then
        log "ERROR: Cannot determine external IP"
        return 1
    fi
    
    log "VPN OK - External IP: $EXTERNAL_IP"
    return 0
}

restart_vpn_stack() {
    log "CRITICAL: Restarting VPN stack after $VPN_RESTART_THRESHOLD failed checks"
    
    # This would require docker-compose, but we're in a container
    # So we'll just log the issue for now
    log "VPN restart would be triggered here (external monitoring required)"
}

while true; do
    if check_vpn_connection; then
        FAILED_CHECKS=0
    else
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        log "WARNING: VPN check failed ($FAILED_CHECKS/$VPN_RESTART_THRESHOLD)"
        
        if [ $FAILED_CHECKS -ge $VPN_RESTART_THRESHOLD ]; then
            restart_vpn_stack
            FAILED_CHECKS=0
        fi
    fi
    
    sleep $VPN_CHECK_INTERVAL
done
EOF
        
        chmod +x "$vpn_script"
        log_success "Created VPN health monitoring script"
    fi
}

# Ensure proper API key availability
ensure_api_keys() {
    log_info "Verifying API key availability..."
    
    local api_keys=(
        "SONARR_API_KEY"
        "RADARR_API_KEY"
        "PROWLARR_API_KEY"
        "BAZARR_API_KEY"
        "OVERSEERR_API_KEY"
    )
    
    local missing_keys=()
    
    for key in "${api_keys[@]}"; do
        if ! grep -q "^${key}=.\+" "$ENV_FILE" 2>/dev/null; then
            missing_keys+=("$key")
        fi
    done
    
    if [[ ${#missing_keys[@]} -gt 0 ]]; then
        log_warning "Missing API keys: ${missing_keys[*]}"
        log_info "These will be auto-generated when services start"
    else
        log_success "All API keys are configured"
    fi
}

# Wait for critical services
wait_for_dependencies() {
    log_info "Checking service dependencies..."
    
    # VPN must be working for download clients
    if docker ps --format "table {{.Names}}" | grep -q "gluetun"; then
        log_info "VPN container (gluetun) is running"
    else
        log_warning "VPN container not found - download clients may not work"
    fi
    
    # Check if NAS mount is available
    if [[ -d "/mnt/artie" ]] && mountpoint -q "/mnt/artie"; then
        log_success "NAS mount is available at /mnt/artie"
    else
        log_warning "NAS mount not detected - services may not access media"
    fi
}

# Create unified service startup script
create_startup_script() {
    local startup_script="$SCRIPT_DIR/startup-sequence.sh"
    
    log_info "Creating service startup sequence script..."
    
    cat > "$startup_script" << 'EOF'
#!/bin/bash
# Service Startup Sequence Script
# Ensures proper initialization order

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DOCKER_DIR="$PROJECT_DIR/docker"

echo "🚀 Starting Media Server Automation Stack..."

# Step 1: Initialize environment
echo "📋 Step 1: Environment initialization"
cd "$DOCKER_DIR"
$SCRIPT_DIR/init-container.sh

# Step 2: Start core infrastructure
echo "🔧 Step 2: Starting core infrastructure"
docker-compose up -d gluetun prometheus grafana loki

# Wait for VPN
echo "⏳ Waiting for VPN connection..."
timeout 120 bash -c 'until docker exec gluetun curl -sf http://localhost:8000/v1/openvpn/status | grep -q "running.*true"; do sleep 5; done'

# Step 3: Start download clients (VPN dependent)
echo "📥 Step 3: Starting download clients"
docker-compose up -d transmission nzbget

# Step 4: Start Servarr applications
echo "🎬 Step 4: Starting Servarr applications"
docker-compose up -d sonarr radarr prowlarr bazarr overseerr

# Step 5: Start supporting services
echo "🛠️  Step 5: Starting supporting services"
docker-compose up -d flaresolverr unpackerr cleanuparr huntarr

# Step 6: Start monitoring stack
echo "📊 Step 6: Starting monitoring"
docker-compose up -d cadvisor node-exporter promtail portainer

# Step 7: Extract and configure API keys
echo "🔑 Step 7: Configuring API integrations"
sleep 30  # Wait for services to fully start
$SCRIPT_DIR/extract-api-keys.sh
sleep 10
$SCRIPT_DIR/configure-integrations.sh

echo "✅ Media Server Automation Stack started successfully!"
echo ""
echo "🌐 Access your services:"
echo "  • Overseerr: http://$(hostname -I | awk '{print $1}'):5055"
echo "  • Grafana: http://$(hostname -I | awk '{print $1}'):3000"
echo "  • Portainer: https://$(hostname -I | awk '{print $1}'):9443"
EOF
    
    chmod +x "$startup_script"
    log_success "Created startup sequence script"
}

main() {
    log_info "Initializing Docker container environment..."
    
    # Ensure we have the environment file
    if [[ ! -f "$ENV_FILE" ]]; then
        log_error "Environment file not found: $ENV_FILE"
        exit 1
    fi
    
    # Run initialization steps
    init_config_dirs
    set_config_permissions
    create_prometheus_config
    create_grafana_config
    create_loki_config
    create_promtail_config
    create_vpn_health_script
    ensure_api_keys
    wait_for_dependencies
    create_startup_script
    
    log_success "Container initialization completed successfully"
    log_info "Use './scripts/startup-sequence.sh' to start the full stack"
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi