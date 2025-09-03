#!/bin/bash
# ===============================================
# API KEY EXTRACTION AND MANAGEMENT TOOL
# ===============================================
# Extracts API keys from native Servarr installations
# and automatically configures Docker environment
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
LOG_FILE="$LOGS_DIR/api-key-extraction-$(date +%Y%m%d-%H%M%S).log"

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

# Application configurations
declare -A APP_CONFIGS
APP_CONFIGS[sonarr]="/var/lib/sonarr:config.xml"
APP_CONFIGS[radarr]="/var/lib/radarr:config.xml"
APP_CONFIGS[prowlarr]="/var/lib/prowlarr:config.xml"
APP_CONFIGS[bazarr]="/var/lib/bazarr:config.yaml"

print_header() {
    echo -e "${BLUE}"
    echo "==============================================="
    echo " API KEY EXTRACTION & MANAGEMENT TOOL"
    echo "==============================================="
    echo -e "${NC}"
    echo "This tool will:"
    echo "• Extract API keys from native installations"
    echo "• Generate new API keys if none exist"
    echo "• Update Docker environment configuration"
    echo "• Prepare for automatic service integration"
    echo ""
}

generate_api_key() {
    # Generate a 32-character API key
    openssl rand -hex 16 2>/dev/null || \
    python3 -c "import secrets; print(secrets.token_hex(16))" 2>/dev/null || \
    head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32
}

extract_xml_api_key() {
    local config_file="$1"
    local app_name="$2"
    
    if [[ ! -f "$config_file" ]]; then
        log_warning "$app_name config file not found: $config_file"
        return 1
    fi
    
    # Extract API key from XML config
    local api_key
    if command -v xmllint &> /dev/null; then
        api_key=$(xmllint --xpath "string(//ApiKey)" "$config_file" 2>/dev/null || echo "")
    else
        # Fallback to grep/sed
        api_key=$(grep -oP '(?<=<ApiKey>)[^<]+' "$config_file" 2>/dev/null || echo "")
    fi
    
    if [[ -n "$api_key" && "$api_key" != "null" ]]; then
        echo "$api_key"
        return 0
    else
        return 1
    fi
}

extract_yaml_api_key() {
    local config_file="$1"
    local app_name="$2"
    
    if [[ ! -f "$config_file" ]]; then
        log_warning "$app_name config file not found: $config_file"
        return 1
    fi
    
    # Extract API key from YAML config
    local api_key
    if command -v yq &> /dev/null; then
        api_key=$(yq eval '.auth.apikey' "$config_file" 2>/dev/null || echo "")
    else
        # Fallback to grep
        api_key=$(grep -oP '(?<=apikey: )[^\s]+' "$config_file" 2>/dev/null || echo "")
    fi
    
    if [[ -n "$api_key" && "$api_key" != "null" ]]; then
        echo "$api_key"
        return 0
    else
        return 1
    fi
}

extract_api_key_from_running_service() {
    local app="$1"
    local port="$2"
    
    log_info "Attempting to extract API key from running $app service..."
    
    # Try to get API key from service status endpoint
    local api_endpoint="http://localhost:$port/api/v1/system/status"
    
    # For some services, we might be able to extract from other endpoints
    case "$app" in
        "bazarr")
            api_endpoint="http://localhost:$port/api/system/status"
            ;;
        "overseerr")
            # Overseerr doesn't expose API key in status, skip
            return 1
            ;;
    esac
    
    # This is a simplified approach - in reality, API keys are typically not exposed
    # through status endpoints for security reasons
    log_warning "Cannot extract API key from running service (security restriction)"
    return 1
}

update_env_file() {
    local app="$1"
    local api_key="$2"
    
    local env_var="${app^^}_API_KEY"
    
    if [[ ! -f "$ENV_FILE" ]]; then
        log_error "Environment file not found: $ENV_FILE"
        return 1
    fi
    
    # Check if the variable already exists and has a value
    if grep -q "^${env_var}=" "$ENV_FILE"; then
        local current_value
        current_value=$(grep "^${env_var}=" "$ENV_FILE" | cut -d'=' -f2)
        
        if [[ -n "$current_value" && "$current_value" != "your_${app}_api_key" ]]; then
            log_info "$env_var already has a value, skipping update"
            return 0
        fi
        
        # Update existing line
        sed -i "s/^${env_var}=.*/${env_var}=${api_key}/" "$ENV_FILE"
    else
        # Add new line in the API keys section
        if grep -q "# API Keys for Monitoring" "$ENV_FILE"; then
            # Insert after the API keys section header
            sed -i "/# API Keys for Monitoring/a ${env_var}=${api_key}" "$ENV_FILE"
        else
            # Append at end
            echo "${env_var}=${api_key}" >> "$ENV_FILE"
        fi
    fi
    
    log_success "Updated $env_var in environment file"
}

extract_app_api_key() {
    local app="$1"
    local config_info="${APP_CONFIGS[$app]}"
    local config_path=$(echo "$config_info" | cut -d':' -f1)
    local config_file=$(echo "$config_info" | cut -d':' -f2)
    local full_config_path="$config_path/$config_file"
    
    log_info "Processing $app API key..."
    
    local extracted_key=""
    
    # Try to extract from configuration file
    if [[ "$config_file" == *.xml ]]; then
        if sudo test -f "$full_config_path"; then
            extracted_key=$(sudo cat "$full_config_path" | extract_xml_api_key /dev/stdin "$app" || echo "")
        fi
    elif [[ "$config_file" == *.yaml || "$config_file" == *.yml ]]; then
        if sudo test -f "$full_config_path"; then
            extracted_key=$(sudo cat "$full_config_path" | extract_yaml_api_key /dev/stdin "$app" || echo "")
        fi
    fi
    
    # If extraction failed, try to get from running service
    if [[ -z "$extracted_key" ]]; then
        case "$app" in
            "sonarr") extract_api_key_from_running_service "$app" "8989" || true ;;
            "radarr") extract_api_key_from_running_service "$app" "7878" || true ;;
            "prowlarr") extract_api_key_from_running_service "$app" "9696" || true ;;
            "bazarr") extract_api_key_from_running_service "$app" "6767" || true ;;
        esac
    fi
    
    # Generate new key if extraction failed
    if [[ -z "$extracted_key" ]]; then
        log_warning "Could not extract existing API key for $app, generating new one"
        extracted_key=$(generate_api_key)
        log_info "Generated new API key for $app: ${extracted_key:0:8}..."
    else
        log_success "Extracted existing API key for $app: ${extracted_key:0:8}..."
    fi
    
    # Update environment file
    update_env_file "$app" "$extracted_key"
}

extract_overseerr_api_key() {
    log_info "Processing Overseerr API key..."
    
    # Overseerr API key extraction is more complex as it's typically stored in database
    local overseerr_config="/var/lib/overseerr/db/db.sqlite3"
    
    local extracted_key=""
    
    if sudo test -f "$overseerr_config"; then
        # Try to extract from SQLite database
        extracted_key=$(sudo sqlite3 "$overseerr_config" "SELECT value FROM settings WHERE key='apikey';" 2>/dev/null || echo "")
    fi
    
    if [[ -z "$extracted_key" ]]; then
        log_warning "Could not extract existing API key for overseerr, generating new one"
        extracted_key=$(generate_api_key)
        log_info "Generated new API key for overseerr: ${extracted_key:0:8}..."
    else
        log_success "Extracted existing API key for overseerr: ${extracted_key:0:8}..."
    fi
    
    update_env_file "overseerr" "$extracted_key"
}

validate_api_keys() {
    log_info "Validating extracted API keys..."
    
    local validation_passed=true
    
    # Check each API key in environment file
    for app in sonarr radarr prowlarr bazarr overseerr; do
        local env_var="${app^^}_API_KEY"
        local api_key
        
        if api_key=$(grep "^${env_var}=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2); then
            if [[ -n "$api_key" && ${#api_key} -eq 32 ]]; then
                log_success "$app API key: Valid (${api_key:0:8}...)"
            else
                log_error "$app API key: Invalid or missing"
                validation_passed=false
            fi
        else
            log_error "$app API key: Not found in environment file"
            validation_passed=false
        fi
    done
    
    if $validation_passed; then
        log_success "All API keys validated successfully"
        return 0
    else
        log_error "API key validation failed"
        return 1
    fi
}

create_api_key_backup() {
    log_info "Creating API key backup..."
    
    local backup_file="$LOGS_DIR/api-keys-backup-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "# API Keys Backup - $(date)"
        echo "# DO NOT SHARE THIS FILE - CONTAINS SENSITIVE INFORMATION"
        echo ""
        
        for app in sonarr radarr prowlarr bazarr overseerr; do
            local env_var="${app^^}_API_KEY"
            if api_key=$(grep "^${env_var}=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2); then
                echo "${env_var}=${api_key}"
            fi
        done
    } > "$backup_file"
    
    chmod 600 "$backup_file"
    log_success "API key backup saved: $backup_file"
}

show_summary() {
    echo -e "${GREEN}"
    echo "==============================================="
    echo " API KEY EXTRACTION COMPLETED"
    echo "==============================================="
    echo -e "${NC}"
    
    echo "📊 Summary:"
    for app in sonarr radarr prowlarr bazarr overseerr; do
        local env_var="${app^^}_API_KEY"
        if api_key=$(grep "^${env_var}=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2); then
            if [[ -n "$api_key" ]]; then
                echo "  ✅ $app: ${api_key:0:8}..."
            else
                echo "  ❌ $app: Not configured"
            fi
        else
            echo "  ❌ $app: Not found"
        fi
    done
    
    echo ""
    echo "📁 Files:"
    echo "  • Environment: $ENV_FILE"
    echo "  • Log: $LOG_FILE"
    echo "  • Backup: $LOGS_DIR/api-keys-backup-*.txt"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Review the updated .env file"
    echo "2. Run service integration: ./scripts/configure-integrations.sh"
    echo "3. Deploy Docker stack: cd docker && docker-compose up -d"
}

main() {
    print_header
    
    log_info "Starting API key extraction and management..."
    
    # Check prerequisites
    if [[ ! -f "$ENV_FILE" ]]; then
        log_error "Environment file not found: $ENV_FILE"
        log_info "Please ensure .env file exists before running this script"
        exit 1
    fi
    
    # Extract API keys for each application
    for app in "${!APP_CONFIGS[@]}"; do
        extract_app_api_key "$app"
        echo
    done
    
    # Handle Overseerr separately (different storage format)
    extract_overseerr_api_key
    echo
    
    # Validate all extracted keys
    if validate_api_keys; then
        create_api_key_backup
        show_summary
        return 0
    else
        log_error "API key extraction completed with errors"
        return 1
    fi
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi