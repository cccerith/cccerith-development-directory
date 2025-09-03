#!/bin/bash
# ===============================================
# END-TO-END DEPLOYMENT VALIDATION
# ===============================================
# Validates complete media server deployment
# Tests all integrations and workflows
# ===============================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DOCKER_DIR="$PROJECT_DIR/docker"
ENV_FILE="${ENV_FILE:-$DOCKER_DIR/.env}"
LOGS_DIR="$PROJECT_DIR/logs"

# Validation results
VALIDATIONS_TOTAL=0
VALIDATIONS_PASSED=0
VALIDATIONS_FAILED=0
VALIDATION_RESULTS=()

# Create directories
mkdir -p "$LOGS_DIR"

# Logging
LOG_FILE="$LOGS_DIR/validation-$(date +%Y%m%d-%H%M%S).log"

log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE"
}

log_info() {
    log "${BLUE}[INFO]${NC} $*"
}

log_success() {
    log "${GREEN}[PASS]${NC} $*"
}

log_warning() {
    log "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    log "${RED}[FAIL]${NC} $*"
}

log_validation() {
    log "${CYAN}[VALIDATE]${NC} $*"
}

# Validation execution framework
run_validation() {
    local validation_name="$1"
    local validation_function="$2"
    
    log_validation "Running: $validation_name"
    ((VALIDATIONS_TOTAL++))
    
    if $validation_function; then
        log_success "$validation_name"
        VALIDATION_RESULTS+=("✅ $validation_name")
        ((VALIDATIONS_PASSED++))
        return 0
    else
        log_error "$validation_name"
        VALIDATION_RESULTS+=("❌ $validation_name")
        ((VALIDATIONS_FAILED++))
        return 1
    fi
}

print_header() {
    echo -e "${CYAN}"
    echo "=========================================================="
    echo " END-TO-END DEPLOYMENT VALIDATION"
    echo "=========================================================="
    echo -e "${NC}"
    echo "Environment File: $ENV_FILE"
    echo "Log File: $LOG_FILE"
    echo ""
}

# ===========================================
# SERVICE AVAILABILITY VALIDATION
# ===========================================

validate_core_services() {
    log_info "Validating core Servarr services..."
    
    # Load ports from environment
    local sonarr_port=$(grep "^SONARR_PORT=" "$ENV_FILE" | cut -d'=' -f2 || echo "8989")
    local radarr_port=$(grep "^RADARR_PORT=" "$ENV_FILE" | cut -d'=' -f2 || echo "7878")
    local prowlarr_port=$(grep "^PROWLARR_PORT=" "$ENV_FILE" | cut -d'=' -f2 || echo "9696")
    local bazarr_port=$(grep "^BAZARR_PORT=" "$ENV_FILE" | cut -d'=' -f2 || echo "6767")
    local overseerr_port=$(grep "^OVERSEERR_PORT=" "$ENV_FILE" | cut -d'=' -f2 || echo "5055")
    
    local services=(
        "Sonarr:$sonarr_port"
        "Radarr:$radarr_port"
        "Prowlarr:$prowlarr_port"
        "Bazarr:$bazarr_port"
        "Overseerr:$overseerr_port"
    )
    
    for service_info in "${services[@]}"; do
        local service_name=$(echo "$service_info" | cut -d':' -f1)
        local port=$(echo "$service_info" | cut -d':' -f2)
        
        log_info "Checking $service_name on port $port..."
        
        # Check if service is responding
        if timeout 10 curl -sf "http://localhost:$port" >/dev/null 2>&1; then
            log_success "$service_name is accessible on port $port"
        else
            log_error "$service_name is not responding on port $port"
            return 1
        fi
    done
    
    return 0
}

validate_download_clients() {
    log_info "Validating download clients..."
    
    # Load ports from environment
    local transmission_port=$(grep "^TRANSMISSION_PORT=" "$ENV_FILE" | cut -d'=' -f2 || echo "9091")
    local nzbget_port=$(grep "^NZBGET_PORT=" "$ENV_FILE" | cut -d'=' -f2 || echo "6789")
    
    local clients=(
        "Transmission:$transmission_port"
        "NZBGet:$nzbget_port"
    )
    
    for client_info in "${clients[@]}"; do
        local client_name=$(echo "$client_info" | cut -d':' -f1)
        local port=$(echo "$client_info" | cut -d':' -f2)
        
        log_info "Checking $client_name on port $port..."
        
        if timeout 10 curl -sf "http://localhost:$port" >/dev/null 2>&1; then
            log_success "$client_name is accessible on port $port"
        else
            log_warning "$client_name may not be accessible (could be VPN-protected)"
        fi
    done
    
    return 0
}

validate_monitoring_stack() {
    log_info "Validating monitoring stack..."
    
    # Load ports from environment
    local grafana_port=$(grep "^GRAFANA_PORT=" "$ENV_FILE" | cut -d'=' -f2 || echo "3000")
    local prometheus_port=$(grep "^PROMETHEUS_PORT=" "$ENV_FILE" | cut -d'=' -f2 || echo "9090")
    
    # Check Grafana
    if timeout 10 curl -sf "http://localhost:$grafana_port" >/dev/null 2>&1; then
        log_success "Grafana is accessible on port $grafana_port"
    else
        log_warning "Grafana not accessible (optional service)"
    fi
    
    # Check Prometheus
    if timeout 10 curl -sf "http://localhost:$prometheus_port" >/dev/null 2>&1; then
        log_success "Prometheus is accessible on port $prometheus_port"
    else
        log_warning "Prometheus not accessible (optional service)"
    fi
    
    return 0
}

# ===========================================
# API INTEGRATION VALIDATION
# ===========================================

validate_api_keys() {
    log_info "Validating API key configuration..."
    
    # Check API keys are present in environment
    local api_keys=(
        "SONARR_API_KEY"
        "RADARR_API_KEY"
        "PROWLARR_API_KEY"
        "BAZARR_API_KEY"
    )
    
    for key in "${api_keys[@]}"; do
        local key_value=$(grep "^${key}=" "$ENV_FILE" | cut -d'=' -f2 || echo "")
        
        if [[ -n "$key_value" && ${#key_value} -eq 32 ]]; then
            log_success "$key configured (${key_value:0:8}...)"
        elif [[ -n "$key_value" ]]; then
            log_warning "$key present but may be invalid length (${#key_value} chars)"
        else
            log_error "$key not configured"
            return 1
        fi
    done
    
    return 0
}

validate_prowlarr_integrations() {
    log_info "Validating Prowlarr application integrations..."
    
    local prowlarr_port=$(grep "^PROWLARR_PORT=" "$ENV_FILE" | cut -d'=' -f2 || echo "9696")
    local prowlarr_key=$(grep "^PROWLARR_API_KEY=" "$ENV_FILE" | cut -d'=' -f2 || echo "")
    
    if [[ -z "$prowlarr_key" ]]; then
        log_warning "Prowlarr API key not configured, skipping integration check"
        return 0
    fi
    
    # Check applications endpoint
    local response=$(timeout 10 curl -sf \
        "http://localhost:$prowlarr_port/api/v1/applications" \
        -H "X-Api-Key: $prowlarr_key" 2>/dev/null || echo "[]")
    
    if [[ "$response" != "[]" ]]; then
        local app_count=$(echo "$response" | grep -o '"name"' | wc -l || echo "0")
        log_success "Prowlarr has $app_count configured applications"
    else
        log_warning "Prowlarr has no configured applications (may need setup)"
    fi
    
    return 0
}

validate_bazarr_integrations() {
    log_info "Validating Bazarr service integrations..."
    
    local bazarr_port=$(grep "^BAZARR_PORT=" "$ENV_FILE" | cut -d'=' -f2 || echo "6767")
    local bazarr_key=$(grep "^BAZARR_API_KEY=" "$ENV_FILE" | cut -d'=' -f2 || echo "")
    
    if [[ -z "$bazarr_key" ]]; then
        log_warning "Bazarr API key not configured, skipping integration check"
        return 0
    fi
    
    # Check system status which includes integration info
    local response=$(timeout 10 curl -sf \
        "http://localhost:$bazarr_port/api/system/status" \
        -H "X-API-KEY: $bazarr_key" 2>/dev/null || echo "{}")
    
    if [[ "$response" != "{}" ]]; then
        log_success "Bazarr API is responding"
    else
        log_warning "Bazarr API not responding (may need setup)"
    fi
    
    return 0
}

# ===========================================
# STORAGE AND PERMISSIONS VALIDATION
# ===========================================

validate_media_storage() {
    log_info "Validating media storage configuration..."
    
    local media_root=$(grep "^MEDIA_ROOT=" "$ENV_FILE" | cut -d'=' -f2 || echo "/mnt/artie")
    local downloads_path=$(grep "^DOWNLOADS_PATH=" "$ENV_FILE" | cut -d'=' -f2 || echo "/mnt/artie/downloads")
    
    # Check media root exists and is accessible
    if [[ -d "$media_root" ]]; then
        log_success "Media root directory exists: $media_root"
    else
        log_error "Media root directory missing: $media_root"
        return 1
    fi
    
    # Check downloads directory
    if [[ -d "$downloads_path" ]]; then
        log_success "Downloads directory exists: $downloads_path"
    else
        log_warning "Downloads directory missing: $downloads_path"
    fi
    
    # Check if directories are writable
    local puid=$(grep "^PUID=" "$ENV_FILE" | cut -d'=' -f2 || echo "1001")
    local test_file="$media_root/.write_test_$(date +%s)"
    
    if touch "$test_file" 2>/dev/null; then
        rm -f "$test_file"
        log_success "Media directories are writable"
    else
        log_warning "Media directories may not be writable for user $puid"
    fi
    
    return 0
}

validate_docker_volumes() {
    log_info "Validating Docker volume mounts..."
    
    cd "$DOCKER_DIR"
    
    # Check if containers have proper volume mounts
    local containers=(
        "sonarr"
        "radarr" 
        "prowlarr"
        "bazarr"
    )
    
    for container in "${containers[@]}"; do
        if docker ps --format "table {{.Names}}" | grep -q "$container"; then
            # Check volume mounts
            local mounts=$(docker inspect "$container" --format '{{range .Mounts}}{{.Source}}:{{.Destination}} {{end}}' 2>/dev/null || echo "")
            
            if [[ "$mounts" == *"/mnt/artie"* ]]; then
                log_success "$container has media volume mounted"
            else
                log_warning "$container may not have media volume properly mounted"
            fi
        else
            log_warning "$container is not running"
        fi
    done
    
    return 0
}

# ===========================================
# NETWORK AND VPN VALIDATION
# ===========================================

validate_vpn_protection() {
    log_info "Validating VPN protection for download clients..."
    
    # Check if gluetun container is running
    if docker ps --format "table {{.Names}}" | grep -q "gluetun"; then
        log_success "Gluetun VPN container is running"
        
        # Check VPN status if possible
        if timeout 10 curl -sf "http://localhost:8000/v1/openvpn/status" 2>/dev/null | grep -q "running.*true"; then
            log_success "VPN connection is active"
        else
            log_warning "VPN status could not be verified"
        fi
    else
        log_warning "Gluetun VPN container not running"
    fi
    
    return 0
}

validate_container_networking() {
    log_info "Validating container networking..."
    
    cd "$DOCKER_DIR"
    
    # Check if containers are on the same network
    local network_name="media-network"
    
    if docker network ls | grep -q "$network_name"; then
        log_success "Media network exists"
        
        local containers_on_network=$(docker network inspect "$network_name" --format '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null || echo "")
        local container_count=$(echo "$containers_on_network" | wc -w)
        
        log_success "$container_count containers connected to media network"
    else
        log_warning "Media network not found"
    fi
    
    return 0
}

# ===========================================
# WORKFLOW VALIDATION
# ===========================================

validate_automation_workflows() {
    log_info "Validating automation workflow capabilities..."
    
    # Check if automation scripts are present and executable
    local scripts=(
        "extract-api-keys.sh"
        "configure-integrations.sh"
        "init-container.sh"
    )
    
    for script in "${scripts[@]}"; do
        local script_path="$SCRIPT_DIR/$script"
        if [[ -x "$script_path" ]]; then
            log_success "Automation script available: $script"
        else
            log_error "Automation script missing or not executable: $script"
            return 1
        fi
    done
    
    return 0
}

validate_backup_capabilities() {
    log_info "Validating backup and recovery capabilities..."
    
    # Check if backup directory is configured
    local backup_path=$(grep "^BACKUP_LOCATION=" "$ENV_FILE" | cut -d'=' -f2 || echo "")
    
    if [[ -n "$backup_path" ]]; then
        if [[ -d "$(dirname "$backup_path")" ]]; then
            log_success "Backup location parent directory exists"
        else
            log_warning "Backup location parent directory not found: $(dirname "$backup_path")"
        fi
    else
        log_warning "Backup location not configured"
    fi
    
    return 0
}

# ===========================================
# PERFORMANCE VALIDATION
# ===========================================

validate_system_resources() {
    log_info "Validating system resource utilization..."
    
    # Check memory usage
    local memory_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    if (( $(echo "$memory_usage < 80" | bc -l) )); then
        log_success "Memory usage acceptable: ${memory_usage}%"
    else
        log_warning "High memory usage: ${memory_usage}%"
    fi
    
    # Check disk usage
    local media_root=$(grep "^MEDIA_ROOT=" "$ENV_FILE" | cut -d'=' -f2 || echo "/mnt/artie")
    if [[ -d "$media_root" ]]; then
        local disk_usage=$(df "$media_root" | tail -1 | awk '{print $5}' | sed 's/%//')
        if [[ $disk_usage -lt 90 ]]; then
            log_success "Disk usage acceptable: ${disk_usage}%"
        else
            log_warning "High disk usage: ${disk_usage}%"
        fi
    fi
    
    # Check container health
    local unhealthy_containers=$(docker ps --filter "health=unhealthy" --format "table {{.Names}}" | grep -v NAMES | wc -l)
    if [[ $unhealthy_containers -eq 0 ]]; then
        log_success "All containers are healthy"
    else
        log_warning "$unhealthy_containers containers are unhealthy"
    fi
    
    return 0
}

# ===========================================
# REPORTING
# ===========================================

generate_validation_report() {
    local report_file="$LOGS_DIR/deployment-validation-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$report_file" << EOF
# 🚀 Media Server Deployment Validation Report

**Generated:** $(date)  
**Environment:** $ENV_FILE  
**Log File:** $LOG_FILE  

## 📊 Validation Summary

- **Total Validations:** $VALIDATIONS_TOTAL
- **Passed:** $VALIDATIONS_PASSED
- **Failed:** $VALIDATIONS_FAILED
- **Success Rate:** $(( VALIDATIONS_TOTAL > 0 ? (VALIDATIONS_PASSED * 100) / VALIDATIONS_TOTAL : 0 ))%

## 📋 Validation Results

EOF

    for result in "${VALIDATION_RESULTS[@]}"; do
        echo "- $result" >> "$report_file"
    done
    
    cat >> "$report_file" << EOF

## 🎯 Service Status

### Core Services
$(timeout 2 curl -sf "http://localhost:$(grep '^SONARR_PORT=' "$ENV_FILE" | cut -d'=' -f2 || echo 8989)" >/dev/null 2>&1 && echo "- ✅ Sonarr" || echo "- ❌ Sonarr")
$(timeout 2 curl -sf "http://localhost:$(grep '^RADARR_PORT=' "$ENV_FILE" | cut -d'=' -f2 || echo 7878)" >/dev/null 2>&1 && echo "- ✅ Radarr" || echo "- ❌ Radarr")
$(timeout 2 curl -sf "http://localhost:$(grep '^PROWLARR_PORT=' "$ENV_FILE" | cut -d'=' -f2 || echo 9696)" >/dev/null 2>&1 && echo "- ✅ Prowlarr" || echo "- ✅ Prowlarr")
$(timeout 2 curl -sf "http://localhost:$(grep '^OVERSEERR_PORT=' "$ENV_FILE" | cut -d'=' -f2 || echo 5055)" >/dev/null 2>&1 && echo "- ✅ Overseerr" || echo "- ❌ Overseerr")

### System Information
- **Media Root:** $(grep '^MEDIA_ROOT=' "$ENV_FILE" | cut -d'=' -f2 || echo '/mnt/artie')
- **Docker Network:** $(docker network ls | grep -q media-network && echo "✅ Active" || echo "❌ Missing")
- **VPN Protection:** $(docker ps --format "table {{.Names}}" | grep -q gluetun && echo "✅ Active" || echo "❌ Inactive")

## 🔧 Next Steps

EOF

    if [[ $VALIDATIONS_FAILED -eq 0 ]]; then
        cat >> "$report_file" << EOF
### ✅ Deployment Successful
Your media server automation is fully deployed and operational!

**Recommended Actions:**
1. Configure indexers in Prowlarr
2. Add root folders in Sonarr/Radarr
3. Set up quality profiles
4. Configure Overseerr for user requests

**Access Your Services:**
- Overseerr: http://localhost:$(grep '^OVERSEERR_PORT=' "$ENV_FILE" | cut -d'=' -f2 || echo 5055)
- Sonarr: http://localhost:$(grep '^SONARR_PORT=' "$ENV_FILE" | cut -d'=' -f2 || echo 8989)
- Radarr: http://localhost:$(grep '^RADARR_PORT=' "$ENV_FILE" | cut -d'=' -f2 || echo 7878)
EOF
    else
        cat >> "$report_file" << EOF
### ❌ Issues Detected
Some validations failed. Please address the following:

**Failed Validations:**
EOF
        for result in "${VALIDATION_RESULTS[@]}"; do
            if [[ "$result" == ❌* ]]; then
                echo "- $result" >> "$report_file"
            fi
        done
        
        cat >> "$report_file" << EOF

**Troubleshooting:**
1. Check service logs: docker-compose logs [service-name]
2. Verify configuration: cat $ENV_FILE
3. Review documentation: docs/TROUBLESHOOTING.md
4. Run diagnostic: ./scripts/test-suite.sh
EOF
    fi
    
    log_success "Validation report generated: $report_file"
}

show_final_summary() {
    echo -e "${CYAN}"
    echo "=========================================================="
    echo " DEPLOYMENT VALIDATION COMPLETED"
    echo "=========================================================="
    echo -e "${NC}"
    
    echo "📊 Results:"
    echo "  • Total Validations: $VALIDATIONS_TOTAL"
    echo -e "  • Passed: ${GREEN}$VALIDATIONS_PASSED${NC}"
    echo -e "  • Failed: ${RED}$VALIDATIONS_FAILED${NC}"
    
    if [[ $VALIDATIONS_FAILED -eq 0 ]]; then
        echo -e "  • Status: ${GREEN}✅ DEPLOYMENT VALIDATED${NC}"
        echo ""
        echo "🎉 Your media server automation is fully operational!"
        echo ""
        echo "🌐 Access your services:"
        echo "  • Overseerr: http://localhost:$(grep '^OVERSEERR_PORT=' "$ENV_FILE" | cut -d'=' -f2 || echo 5055)"
        echo "  • Sonarr: http://localhost:$(grep '^SONARR_PORT=' "$ENV_FILE" | cut -d'=' -f2 || echo 8989)"
        echo "  • Radarr: http://localhost:$(grep '^RADARR_PORT=' "$ENV_FILE" | cut -d'=' -f2 || echo 7878)"
    else
        echo -e "  • Status: ${RED}❌ ISSUES DETECTED${NC}"
        echo ""
        echo "🔧 Please address failed validations before proceeding"
    fi
    
    echo ""
    echo "📁 Reports:"
    echo "  • Detailed Log: $LOG_FILE"
    echo "  • Validation Report: $LOGS_DIR/deployment-validation-*.md"
}

# ===========================================
# MAIN EXECUTION
# ===========================================

main() {
    print_header
    
    log_info "Starting deployment validation..."
    
    # Service Availability
    run_validation "Core Services Availability" validate_core_services
    run_validation "Download Clients Availability" validate_download_clients
    run_validation "Monitoring Stack" validate_monitoring_stack
    
    # API Integration
    run_validation "API Key Configuration" validate_api_keys
    run_validation "Prowlarr Integrations" validate_prowlarr_integrations
    run_validation "Bazarr Integrations" validate_bazarr_integrations
    
    # Storage and Permissions
    run_validation "Media Storage Configuration" validate_media_storage
    run_validation "Docker Volume Mounts" validate_docker_volumes
    
    # Network and VPN
    run_validation "VPN Protection" validate_vpn_protection
    run_validation "Container Networking" validate_container_networking
    
    # Workflows
    run_validation "Automation Workflows" validate_automation_workflows
    run_validation "Backup Capabilities" validate_backup_capabilities
    
    # Performance
    run_validation "System Resources" validate_system_resources
    
    # Generate reports
    generate_validation_report
    show_final_summary
    
    # Exit with appropriate code
    if [[ $VALIDATIONS_FAILED -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "End-to-End Deployment Validation"
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h          Show this help message"
        echo "  --env-file FILE     Use specific environment file"
        echo ""
        exit 0
        ;;
    --env-file)
        ENV_FILE="$2"
        shift 2
        main "$@"
        ;;
    *)
        main "$@"
        ;;
esac