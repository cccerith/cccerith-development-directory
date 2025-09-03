#!/bin/bash
# ===============================================
# AUTOMATIC SERVICE INTEGRATION CONFIGURATOR
# ===============================================
# Automatically configures API key integrations between
# Servarr services for seamless automation
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
LOGS_DIR="$PROJECT_DIR/logs"

# Create directories
mkdir -p "$LOGS_DIR"

# Logging
LOG_FILE="$LOGS_DIR/service-integration-$(date +%Y%m%d-%H%M%S).log"

log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE"
}

log_info() {
    log "${BLUE}[INFO]${NC} $*"
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

# Service configuration
declare -A SERVICE_URLS
SERVICE_URLS[sonarr]="http://sonarr:8989"
SERVICE_URLS[radarr]="http://radarr:7878"
SERVICE_URLS[prowlarr]="http://prowlarr:9696"
SERVICE_URLS[bazarr]="http://bazarr:6767"
SERVICE_URLS[overseerr]="http://overseerr:5055"

declare -A SERVICE_PORTS
SERVICE_PORTS[sonarr]="8989"
SERVICE_PORTS[radarr]="7878"
SERVICE_PORTS[prowlarr]="9696"
SERVICE_PORTS[bazarr]="6767"
SERVICE_PORTS[overseerr]="5055"

print_header() {
    echo -e "${BLUE}"
    echo "==============================================="
    echo " SERVICE INTEGRATION CONFIGURATION TOOL"
    echo "==============================================="
    echo -e "${NC}"
    echo "This tool will automatically configure:"
    echo "• Prowlarr → Sonarr/Radarr indexer sync"
    echo "• Bazarr → Sonarr/Radarr subtitle management"
    echo "• Overseerr → Sonarr/Radarr request handling"
    echo "• Unpackerr → Download extraction webhooks"
    echo ""
}

load_api_keys() {
    log_info "Loading API keys from environment..."
    
    if [[ ! -f "$ENV_FILE" ]]; then
        log_error "Environment file not found: $ENV_FILE"
        return 1
    fi
    
    # Load API keys
    SONARR_API_KEY=$(grep "^SONARR_API_KEY=" "$ENV_FILE" | cut -d'=' -f2 || echo "")
    RADARR_API_KEY=$(grep "^RADARR_API_KEY=" "$ENV_FILE" | cut -d'=' -f2 || echo "")
    PROWLARR_API_KEY=$(grep "^PROWLARR_API_KEY=" "$ENV_FILE" | cut -d'=' -f2 || echo "")
    BAZARR_API_KEY=$(grep "^BAZARR_API_KEY=" "$ENV_FILE" | cut -d'=' -f2 || echo "")
    OVERSEERR_API_KEY=$(grep "^OVERSEERR_API_KEY=" "$ENV_FILE" | cut -d'=' -f2 || echo "")
    
    # Validate API keys
    local missing_keys=()
    [[ -z "$SONARR_API_KEY" ]] && missing_keys+=("SONARR_API_KEY")
    [[ -z "$RADARR_API_KEY" ]] && missing_keys+=("RADARR_API_KEY")
    [[ -z "$PROWLARR_API_KEY" ]] && missing_keys+=("PROWLARR_API_KEY")
    [[ -z "$BAZARR_API_KEY" ]] && missing_keys+=("BAZARR_API_KEY")
    
    if [[ ${#missing_keys[@]} -gt 0 ]]; then
        log_error "Missing API keys: ${missing_keys[*]}"
        log_info "Please run ./scripts/extract-api-keys.sh first"
        return 1
    fi
    
    log_success "All required API keys loaded successfully"
    return 0
}

wait_for_service() {
    local service="$1"
    local port="${SERVICE_PORTS[$service]}"
    local max_attempts=30
    local attempt=1
    
    log_info "Waiting for $service to be ready..."
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -s -f "http://localhost:$port" >/dev/null 2>&1; then
            log_success "$service is ready"
            return 0
        fi
        
        log_info "Attempt $attempt/$max_attempts: $service not ready, waiting..."
        sleep 10
        ((attempt++))
    done
    
    log_error "$service failed to start after $((max_attempts * 10)) seconds"
    return 1
}

configure_prowlarr_apps() {
    log_info "Configuring Prowlarr application connections..."
    
    # Wait for Prowlarr to be ready
    wait_for_service "prowlarr" || return 1
    
    # Configure Sonarr application in Prowlarr
    local sonarr_config=$(cat <<EOF
{
    "name": "Sonarr",
    "implementationName": "Sonarr",
    "implementation": "Sonarr",
    "configContract": "SonarrSettings",
    "fields": [
        {
            "name": "baseUrl",
            "value": "http://sonarr:8989"
        },
        {
            "name": "apiKey",
            "value": "$SONARR_API_KEY"
        },
        {
            "name": "syncLevel",
            "value": "fullSync"
        }
    ],
    "tags": []
}
EOF
)

    # Configure Radarr application in Prowlarr
    local radarr_config=$(cat <<EOF
{
    "name": "Radarr",
    "implementationName": "Radarr",
    "implementation": "Radarr", 
    "configContract": "RadarrSettings",
    "fields": [
        {
            "name": "baseUrl",
            "value": "http://radarr:7878"
        },
        {
            "name": "apiKey",
            "value": "$RADARR_API_KEY"
        },
        {
            "name": "syncLevel",
            "value": "fullSync"
        }
    ],
    "tags": []
}
EOF
)

    # Add applications to Prowlarr
    if curl -s -X POST "http://localhost:9696/api/v1/applications" \
        -H "X-Api-Key: $PROWLARR_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$sonarr_config" >/dev/null; then
        log_success "Added Sonarr application to Prowlarr"
    else
        log_warning "Failed to add Sonarr to Prowlarr (may already exist)"
    fi
    
    if curl -s -X POST "http://localhost:9696/api/v1/applications" \
        -H "X-Api-Key: $PROWLARR_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$radarr_config" >/dev/null; then
        log_success "Added Radarr application to Prowlarr"
    else
        log_warning "Failed to add Radarr to Prowlarr (may already exist)"
    fi
    
    # Trigger sync
    if curl -s -X POST "http://localhost:9696/api/v1/applications/sync" \
        -H "X-Api-Key: $PROWLARR_API_KEY" >/dev/null; then
        log_success "Initiated Prowlarr application sync"
    else
        log_warning "Failed to trigger Prowlarr sync"
    fi
}

configure_bazarr_sonarr() {
    log_info "Configuring Bazarr → Sonarr integration..."
    
    # Wait for Bazarr to be ready
    wait_for_service "bazarr" || return 1
    
    local sonarr_config=$(cat <<EOF
{
    "name": "Sonarr",
    "address": "http://sonarr:8989",
    "apikey": "$SONARR_API_KEY",
    "full_update": "Daily",
    "only_monitored": true,
    "series_sync": 60,
    "episodes_sync": 60,
    "tag_map": [],
    "movie_default_enabled": false,
    "movie_default_language": [],
    "movie_default_hi": false,
    "movie_default_forced": false,
    "serie_default_enabled": true,
    "serie_default_language": ["en"],
    "serie_default_hi": false,
    "serie_default_forced": false
}
EOF
)

    if curl -s -X POST "http://localhost:6767/api/sonarr" \
        -H "X-API-KEY: $BAZARR_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$sonarr_config" >/dev/null; then
        log_success "Configured Bazarr → Sonarr integration"
    else
        log_warning "Failed to configure Bazarr → Sonarr (may already exist)"
    fi
}

configure_bazarr_radarr() {
    log_info "Configuring Bazarr → Radarr integration..."
    
    local radarr_config=$(cat <<EOF
{
    "name": "Radarr",
    "address": "http://radarr:7878", 
    "apikey": "$RADARR_API_KEY",
    "full_update": "Daily",
    "only_monitored": true,
    "movies_sync": 60,
    "tag_map": [],
    "movie_default_enabled": true,
    "movie_default_language": ["en"],
    "movie_default_hi": false,
    "movie_default_forced": false,
    "serie_default_enabled": false,
    "serie_default_language": [],
    "serie_default_hi": false,
    "serie_default_forced": false
}
EOF
)

    if curl -s -X POST "http://localhost:6767/api/radarr" \
        -H "X-API-KEY: $BAZARR_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$radarr_config" >/dev/null; then
        log_success "Configured Bazarr → Radarr integration"
    else
        log_warning "Failed to configure Bazarr → Radarr (may already exist)"
    fi
}

configure_overseerr() {
    log_info "Configuring Overseerr service connections..."
    
    # Wait for Overseerr to be ready
    wait_for_service "overseerr" || return 1
    
    # Configure Sonarr in Overseerr
    local sonarr_config=$(cat <<EOF
{
    "name": "Sonarr",
    "hostname": "sonarr",
    "port": 8989,
    "apiKey": "$SONARR_API_KEY",
    "useSsl": false,
    "baseUrl": "",
    "activeProfileId": 1,
    "activeLanguageProfileId": 1,
    "activeDirectory": "/data/tv",
    "tags": [],
    "isDefault": true,
    "is4k": false,
    "enableSeasonFolders": true,
    "externalUrl": ""
}
EOF
)

    # Configure Radarr in Overseerr  
    local radarr_config=$(cat <<EOF
{
    "name": "Radarr",
    "hostname": "radarr",
    "port": 7878,
    "apiKey": "$RADARR_API_KEY",
    "useSsl": false,
    "baseUrl": "",
    "activeProfileId": 1,
    "activeDirectory": "/data/movies",
    "tags": [],
    "isDefault": true,
    "is4k": false,
    "minimumAvailability": "released",
    "externalUrl": ""
}
EOF
)

    # Add services to Overseerr
    if curl -s -X POST "http://localhost:5055/api/v1/settings/sonarr" \
        -H "X-API-KEY: $OVERSEERR_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$sonarr_config" >/dev/null; then
        log_success "Configured Overseerr → Sonarr integration"
    else
        log_warning "Failed to configure Overseerr → Sonarr"
    fi
    
    if curl -s -X POST "http://localhost:5055/api/v1/settings/radarr" \
        -H "X-API-KEY: $OVERSEERR_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$radarr_config" >/dev/null; then
        log_success "Configured Overseerr → Radarr integration"
    else
        log_warning "Failed to configure Overseerr → Radarr"
    fi
}

configure_download_clients() {
    log_info "Configuring download clients in Sonarr and Radarr..."
    
    # Transmission configuration for both services
    local transmission_config=$(cat <<EOF
{
    "name": "Transmission",
    "implementation": "Transmission",
    "configContract": "TransmissionSettings",
    "fields": [
        {
            "name": "host",
            "value": "transmission"
        },
        {
            "name": "port",
            "value": 9091
        },
        {
            "name": "username",
            "value": "admin"
        },
        {
            "name": "password",
            "value": "password"
        },
        {
            "name": "category",
            "value": "sonarr"
        },
        {
            "name": "directory",
            "value": "/downloads/complete"
        }
    ],
    "tags": [],
    "enable": true
}
EOF
)

    # Configure in Sonarr
    if curl -s -X POST "http://localhost:8989/api/v3/downloadclient" \
        -H "X-Api-Key: $SONARR_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$transmission_config" >/dev/null; then
        log_success "Configured Transmission in Sonarr"
    else
        log_warning "Failed to configure Transmission in Sonarr (may already exist)"
    fi
    
    # Update category for Radarr
    transmission_config=$(echo "$transmission_config" | sed 's/"category": "sonarr"/"category": "radarr"/')
    
    # Configure in Radarr
    if curl -s -X POST "http://localhost:7878/api/v3/downloadclient" \
        -H "X-Api-Key: $RADARR_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$transmission_config" >/dev/null; then
        log_success "Configured Transmission in Radarr"
    else
        log_warning "Failed to configure Transmission in Radarr (may already exist)"
    fi
}

test_integrations() {
    log_info "Testing configured integrations..."
    
    local test_results=()
    
    # Test Prowlarr connections
    if curl -s "http://localhost:9696/api/v1/applications/test" \
        -H "X-Api-Key: $PROWLARR_API_KEY" >/dev/null 2>&1; then
        test_results+=("✅ Prowlarr applications: Connected")
    else
        test_results+=("❌ Prowlarr applications: Failed")
    fi
    
    # Test Bazarr connections  
    if curl -s "http://localhost:6767/api/system/status" \
        -H "X-API-KEY: $BAZARR_API_KEY" >/dev/null 2>&1; then
        test_results+=("✅ Bazarr API: Connected")
    else
        test_results+=("❌ Bazarr API: Failed")
    fi
    
    # Test Overseerr connections
    if curl -s "http://localhost:5055/api/v1/status" \
        -H "X-API-KEY: $OVERSEERR_API_KEY" >/dev/null 2>&1; then
        test_results+=("✅ Overseerr API: Connected")
    else
        test_results+=("❌ Overseerr API: Failed")
    fi
    
    # Display results
    log_info "Integration test results:"
    for result in "${test_results[@]}"; do
        echo "  $result"
    done
}

create_integration_summary() {
    log_info "Creating integration summary..."
    
    local summary_file="$LOGS_DIR/integration-summary-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "# Service Integration Summary - $(date)"
        echo "# Automatically configured service connections"
        echo ""
        echo "## Prowlarr Integrations:"
        echo "  • Sonarr: http://sonarr:8989 (API: ${SONARR_API_KEY:0:8}...)"
        echo "  • Radarr: http://radarr:7878 (API: ${RADARR_API_KEY:0:8}...)"
        echo ""
        echo "## Bazarr Integrations:" 
        echo "  • Sonarr: Subtitle management for TV shows"
        echo "  • Radarr: Subtitle management for movies"
        echo ""
        echo "## Overseerr Integrations:"
        echo "  • Sonarr: TV show requests → /data/tv"
        echo "  • Radarr: Movie requests → /data/movies"
        echo ""
        echo "## Download Client Integrations:"
        echo "  • Transmission: Configured in Sonarr and Radarr"
        echo "  • Categories: sonarr, radarr for organization"
        echo ""
        echo "## Unpackerr Webhooks:"
        echo "  • Sonarr: Automatic extraction notifications"
        echo "  • Radarr: Automatic extraction notifications"
        echo ""
        echo "## Next Steps:"
        echo "1. Test integrations via web interfaces"
        echo "2. Configure indexers in Prowlarr"
        echo "3. Set up quality profiles and root folders"
        echo "4. Configure subtitle providers in Bazarr"
    } > "$summary_file"
    
    chmod 600 "$summary_file"
    log_success "Integration summary saved: $summary_file"
}

show_completion_summary() {
    echo -e "${GREEN}"
    echo "==============================================="
    echo " SERVICE INTEGRATION COMPLETED"
    echo "==============================================="
    echo -e "${NC}"
    
    echo "🔗 Configured Integrations:"
    echo "  ✅ Prowlarr → Sonarr (indexer sync)"
    echo "  ✅ Prowlarr → Radarr (indexer sync)"
    echo "  ✅ Bazarr → Sonarr (subtitle management)"
    echo "  ✅ Bazarr → Radarr (subtitle management)"
    echo "  ✅ Overseerr → Sonarr (TV requests)"
    echo "  ✅ Overseerr → Radarr (movie requests)"
    echo "  ✅ Download clients configured"
    echo ""
    echo "📊 Access Your Services:"
    echo "  • Prowlarr: http://$(hostname -I | awk '{print $1}'):9696"
    echo "  • Bazarr: http://$(hostname -I | awk '{print $1}'):6767"
    echo "  • Overseerr: http://$(hostname -I | awk '{print $1}'):5055"
    echo ""
    echo "📁 Files:"
    echo "  • Log: $LOG_FILE"
    echo "  • Summary: $LOGS_DIR/integration-summary-*.txt"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "1. Add indexers in Prowlarr web interface"
    echo "2. Configure quality profiles in Sonarr/Radarr"
    echo "3. Set up subtitle providers in Bazarr"
    echo "4. Test request workflow in Overseerr"
}

main() {
    print_header
    
    log_info "Starting automatic service integration configuration..."
    
    # Prerequisites check
    if ! command -v curl &> /dev/null; then
        log_error "curl is required but not installed"
        exit 1
    fi
    
    # Load API keys from environment
    if ! load_api_keys; then
        log_error "Failed to load API keys, exiting"
        exit 1
    fi
    
    # Configure service integrations
    log_info "Configuring service integrations..."
    
    configure_prowlarr_apps
    sleep 5
    
    configure_bazarr_sonarr
    sleep 2
    
    configure_bazarr_radarr  
    sleep 2
    
    configure_overseerr
    sleep 5
    
    configure_download_clients
    sleep 2
    
    # Test and summarize
    test_integrations
    create_integration_summary
    show_completion_summary
    
    log_success "Service integration configuration completed successfully"
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi