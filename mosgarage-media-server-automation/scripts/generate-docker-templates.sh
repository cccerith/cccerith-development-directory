#!/bin/bash
# ===============================================
# DOCKER CONFIGURATION TEMPLATE GENERATOR
# ===============================================
# Generates Docker-ready configuration templates from
# sanitized Servarr configurations
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
TEMPLATES_DIR="$PROJECT_DIR/docker/config-templates"
DOCKER_DIR="$PROJECT_DIR/docker"
LOGS_DIR="$PROJECT_DIR/logs"

# Create directories
mkdir -p "$TEMPLATES_DIR" "$LOGS_DIR"

# Logging
LOG_FILE="$LOGS_DIR/docker-templates-$(date +%Y%m%d-%H%M%S).log"

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

# Application configurations with Docker-specific settings
declare -A APP_CONFIGS
APP_CONFIGS[sonarr]="8989:Series management"
APP_CONFIGS[radarr]="7878:Movie management"
APP_CONFIGS[prowlarr]="9696:Indexer management"
APP_CONFIGS[bazarr]="6767:Subtitle management"
APP_CONFIGS[overseerr]="5055:Request management"
APP_CONFIGS[transmission]="9091:BitTorrent client"
APP_CONFIGS[nzbget]="6789:Usenet client"

print_header() {
    echo -e "${BLUE}"
    echo "==============================================="
    echo " DOCKER CONFIGURATION TEMPLATE GENERATOR"
    echo "==============================================="
    echo -e "${NC}"
    echo "This tool will:"
    echo "• Generate Docker-ready configuration templates"
    echo "• Create environment variable mappings"
    echo "• Build migration scripts for each application"
    echo "• Generate comprehensive documentation"
    echo ""
}

create_docker_config_template() {
    local app="$1"
    local port_desc="$2"
    local port=$(echo "$port_desc" | cut -d':' -f1)
    local description=$(echo "$port_desc" | cut -d':' -f2-)
    
    local template_dir="$TEMPLATES_DIR/$app"
    
    log_info "Creating Docker template for $app..."
    
    # Create template directory structure
    mkdir -p "$template_dir"
    
    # Create Docker Compose service definition
    cat > "$template_dir/docker-compose.service.yml" << EOF
  # $description
  $app:
    image: \${${app^^}_IMAGE:-lscr.io/linuxserver/$app:latest}
    container_name: $app
    environment:
      - PUID=\${PUID:-1001}
      - PGID=\${PGID:-1001}
      - TZ=\${TZ:-Australia/Sydney}
EOF

    # Add app-specific environment variables
    case "$app" in
        "transmission")
            cat >> "$template_dir/docker-compose.service.yml" << EOF
      - TRANSMISSION_WEB_HOME=/config/web
      - USER=\${TRANSMISSION_USER:-admin}
      - PASS=\${TRANSMISSION_PASS:-password}
    network_mode: "service:gluetun"
    depends_on:
      gluetun:
        condition: service_healthy
EOF
            ;;
        "nzbget")
            cat >> "$template_dir/docker-compose.service.yml" << EOF
    network_mode: "service:gluetun"
    depends_on:
      gluetun:
        condition: service_healthy
EOF
            ;;
        "overseerr")
            cat >> "$template_dir/docker-compose.service.yml" << EOF
      - LOG_LEVEL=\${OVERSEERR_LOG_LEVEL:-info}
EOF
            ;;
    esac
    
    # Add volumes based on application type
    echo "    volumes:" >> "$template_dir/docker-compose.service.yml"
    echo "      - ./configs/$app:/config" >> "$template_dir/docker-compose.service.yml"
    
    case "$app" in
        "sonarr"|"radarr"|"bazarr")
            cat >> "$template_dir/docker-compose.service.yml" << EOF
      - \${MEDIA_ROOT:-/mnt/artie}:/data
      - \${DOWNLOADS_PATH:-/mnt/artie/downloads}:/downloads
EOF
            ;;
        "transmission"|"nzbget")
            cat >> "$template_dir/docker-compose.service.yml" << EOF
      - \${DOWNLOADS_PATH:-/mnt/artie/downloads}:/downloads
EOF
            if [[ "$app" == "transmission" ]]; then
                echo "      - \${DOWNLOADS_WATCH:-/mnt/artie/downloads/watch}:/watch" >> "$template_dir/docker-compose.service.yml"
            fi
            ;;
    esac
    
    # Add ports if not using VPN network mode
    if [[ "$app" != "transmission" && "$app" != "nzbget" ]]; then
        cat >> "$template_dir/docker-compose.service.yml" << EOF
    ports:
      - "\${${app^^}_PORT:-$port}:$port"
EOF
    fi
    
    # Add network and restart policy
    if [[ "$app" != "transmission" && "$app" != "nzbget" ]]; then
        cat >> "$template_dir/docker-compose.service.yml" << EOF
    networks:
      - media-network
EOF
    fi
    
    echo "    restart: \${RESTART_POLICY:-unless-stopped}" >> "$template_dir/docker-compose.service.yml"
    
    # Add health check for non-VPN services
    if [[ "$app" != "transmission" && "$app" != "nzbget" ]]; then
        cat >> "$template_dir/docker-compose.service.yml" << EOF
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:$port"]
      interval: \${HEALTH_CHECK_INTERVAL:-30s}
      timeout: \${HEALTH_CHECK_TIMEOUT:-10s}
      retries: \${HEALTH_CHECK_RETRIES:-3}
EOF
    fi
    
    log_success "Created Docker Compose service definition for $app"
}

create_environment_template() {
    local app="$1"
    local template_dir="$TEMPLATES_DIR/$app"
    
    log_info "Creating environment template for $app..."
    
    cat > "$template_dir/.env.template" << EOF
# $app Environment Variables
# Generated: $(date)

# Docker Image
${app^^}_IMAGE=lscr.io/linuxserver/$app:latest
${app^^}_PORT=$(echo "${APP_CONFIGS[$app]}" | cut -d':' -f1)

# System Configuration
PUID=1001
PGID=1001
TZ=Australia/Sydney

EOF

    # Add app-specific variables
    case "$app" in
        "transmission")
            cat >> "$template_dir/.env.template" << EOF
# Transmission Credentials (REQUIRED)
TRANSMISSION_USER=admin
TRANSMISSION_PASS=your_secure_password

# Transmission Settings
TRANSMISSION_WEB_HOME=/config/web
TRANSMISSION_DOWNLOAD_DIR=/downloads/complete
TRANSMISSION_INCOMPLETE_DIR=/downloads/incomplete
TRANSMISSION_WATCH_DIR=/downloads/watch
EOF
            ;;
        "nzbget")
            cat >> "$template_dir/.env.template" << EOF
# NZBGet Credentials (REQUIRED)  
NZBGET_USER=admin
NZBGET_PASS=your_secure_password

# NZBGet Settings
NZBGET_MAIN_DIR=/downloads
NZBGET_DEST_DIR=/downloads/complete
NZBGET_INTER_DIR=/downloads/incomplete
EOF
            ;;
        "overseerr")
            cat >> "$template_dir/.env.template" << EOF
# Overseerr Settings
OVERSEERR_LOG_LEVEL=info
OVERSEERR_PORT=5055
EOF
            ;;
    esac
    
    # Add common paths
    cat >> "$template_dir/.env.template" << EOF

# Storage Paths
MEDIA_ROOT=/mnt/artie
DOWNLOADS_PATH=/mnt/artie/downloads
DOWNLOADS_COMPLETE=/mnt/artie/downloads/complete
DOWNLOADS_INCOMPLETE=/mnt/artie/downloads/incomplete
DOWNLOADS_WATCH=/mnt/artie/downloads/watch

# Health Check Settings
HEALTH_CHECK_INTERVAL=30s
HEALTH_CHECK_TIMEOUT=10s
HEALTH_CHECK_RETRIES=3

# Container Settings
RESTART_POLICY=unless-stopped
EOF
    
    log_success "Created environment template for $app"
}

create_migration_script() {
    local app="$1"
    local template_dir="$TEMPLATES_DIR/$app"
    
    log_info "Creating migration script for $app..."
    
    cat > "$template_dir/migrate-to-docker.sh" << '#!/bin/bash'
#!/bin/bash
# ===============================================
# DOCKER MIGRATION SCRIPT FOR APP_NAME
# ===============================================

set -euo pipefail

APP_NAME="APP_NAME"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

print_header() {
    echo -e "${BLUE}"
    echo "==============================================="
    echo " DOCKER MIGRATION FOR $APP_NAME"
    echo "==============================================="
    echo -e "${NC}"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Docker and Docker Compose
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed"
        exit 1
    fi
    
    # Check if native service is running
    if systemctl is-active --quiet "$APP_NAME.service" 2>/dev/null; then
        log_warning "$APP_NAME service is running"
        read -p "Stop $APP_NAME service for migration? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo systemctl stop "$APP_NAME.service"
            log_success "Stopped $APP_NAME service"
        else
            log_error "Cannot migrate while service is running"
            exit 1
        fi
    fi
    
    log_success "Prerequisites check passed"
}

prepare_docker_config() {
    log_info "Preparing Docker configuration..."
    
    local docker_config_dir="$PROJECT_DIR/docker/configs/$APP_NAME"
    mkdir -p "$docker_config_dir"
    
    # Copy sanitized configuration
    if [[ -d "$SCRIPT_DIR" ]]; then
        # Find and copy configuration files
        find "$SCRIPT_DIR" -type f \( -name "*.xml" -o -name "*.json" -o -name "*.db" -o -name "*.conf" \) \
            -not -name "sanitization-report.json" \
            -not -name "*.original" \
            -exec cp {} "$docker_config_dir/" \;
        
        log_success "Copied configuration files to Docker directory"
    else
        log_warning "No configuration templates found"
    fi
    
    # Set proper permissions
    sudo chown -R 1001:1001 "$docker_config_dir"
    log_success "Set proper permissions on configuration directory"
}

update_environment() {
    log_info "Updating environment configuration..."
    
    local env_file="$PROJECT_DIR/docker/.env"
    local template_env="$SCRIPT_DIR/.env.template"
    
    if [[ -f "$template_env" ]]; then
        # Merge template variables into main .env file
        while IFS= read -r line; do
            if [[ "$line" =~ ^[A-Z_]+= ]] && ! grep -q "^${line%%=*}=" "$env_file" 2>/dev/null; then
                echo "$line" >> "$env_file"
            fi
        done < "$template_env"
        
        log_success "Updated environment configuration"
    fi
}

test_docker_service() {
    log_info "Testing Docker service..."
    
    # Start the service
    cd "$PROJECT_DIR/docker"
    docker-compose up -d "$APP_NAME"
    
    # Wait for service to be ready
    local port=$(grep "^${APP_NAME^^}_PORT=" .env | cut -d'=' -f2)
    if [[ -n "$port" ]]; then
        log_info "Waiting for service to be ready on port $port..."
        
        local max_attempts=30
        local attempt=1
        
        while [[ $attempt -le $max_attempts ]]; do
            if curl -s "http://localhost:$port" > /dev/null 2>&1; then
                log_success "$APP_NAME is ready on port $port"
                break
            fi
            
            sleep 2
            attempt=$((attempt + 1))
        done
        
        if [[ $attempt -gt $max_attempts ]]; then
            log_error "$APP_NAME failed to start within expected time"
            docker-compose logs "$APP_NAME"
            exit 1
        fi
    fi
    
    log_success "Docker service is running successfully"
}

disable_native_service() {
    log_info "Disabling native service..."
    
    if systemctl is-enabled --quiet "$APP_NAME.service" 2>/dev/null; then
        sudo systemctl disable "$APP_NAME.service"
        log_success "Disabled $APP_NAME native service"
    fi
}

main() {
    print_header
    
    check_prerequisites
    prepare_docker_config
    update_environment
    test_docker_service
    disable_native_service
    
    echo -e "${GREEN}"
    echo "==============================================="
    echo " MIGRATION COMPLETED SUCCESSFULLY"
    echo "==============================================="
    echo -e "${NC}"
    echo "Your $APP_NAME service is now running in Docker!"
    echo ""
    echo "Next steps:"
    echo "1. Verify all settings in the web interface"
    echo "2. Test functionality (add indexers, test downloads, etc.)"
    echo "3. Update any API connections from other applications"
    echo ""
    echo "To view logs: docker-compose logs -f $APP_NAME"
    echo "To restart: docker-compose restart $APP_NAME"
}

main "$@"
#!/bin/bash

    # Replace APP_NAME placeholder
    sed -i "s/APP_NAME/$app/g" "$template_dir/migrate-to-docker.sh"
    chmod +x "$template_dir/migrate-to-docker.sh"
    
    log_success "Created migration script for $app"
}

create_readme_template() {
    local app="$1"
    local template_dir="$TEMPLATES_DIR/$app"
    local port=$(echo "${APP_CONFIGS[$app]}" | cut -d':' -f1)
    local description=$(echo "${APP_CONFIGS[$app]}" | cut -d':' -f2-)
    
    log_info "Creating README for $app..."
    
    cat > "$template_dir/README.md" << EOF
# $app Docker Template

$description template for Docker deployment.

## Overview

This template provides a complete Docker configuration for $app, including:

- 🐳 **Docker Compose service definition**
- 🔧 **Environment variable templates**
- 🚀 **Automated migration script**
- 📋 **Pre-sanitized configuration files**

## Quick Start

### 1. Prepare Configuration

1. Copy your sanitized $app configuration to this directory
2. Update \`.env.template\` with your credentials and paths
3. Merge environment variables into main \`.env\` file

### 2. Deploy with Docker

\`\`\`bash
# From the main docker directory
cd ../../
docker-compose up -d $app
\`\`\`

### 3. Automated Migration

Use the migration script to automatically migrate from native installation:

\`\`\`bash
./migrate-to-docker.sh
\`\`\`

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| \`${app^^}_IMAGE\` | Docker image to use | \`lscr.io/linuxserver/$app:latest\` |
| \`${app^^}_PORT\` | Service port | \`$port\` |
| \`PUID\` | User ID for file permissions | \`1001\` |
| \`PGID\` | Group ID for file permissions | \`1001\` |
| \`TZ\` | Timezone | \`Australia/Sydney\` |
EOF

    # Add app-specific configuration
    case "$app" in
        "transmission")
            cat >> "$template_dir/README.md" << EOF

### Transmission Specific

| Variable | Description | Default |
|----------|-------------|---------|
| \`TRANSMISSION_USER\` | Web UI username | \`admin\` |
| \`TRANSMISSION_PASS\` | Web UI password | **Required** |
| \`TRANSMISSION_WEB_HOME\` | Web UI theme path | \`/config/web\` |

**Note**: Transmission runs through the VPN container (Gluetun) for privacy.
EOF
            ;;
        "nzbget")
            cat >> "$template_dir/README.md" << EOF

### NZBGet Specific

| Variable | Description | Default |
|----------|-------------|---------|
| \`NZBGET_USER\` | Web UI username | \`admin\` |
| \`NZBGET_PASS\` | Web UI password | **Required** |

**Note**: NZBGet runs through the VPN container (Gluetun) for privacy.
EOF
            ;;
        "overseerr")
            cat >> "$template_dir/README.md" << EOF

### Overseerr Specific

| Variable | Description | Default |
|----------|-------------|---------|
| \`OVERSEERR_LOG_LEVEL\` | Logging level | \`info\` |
EOF
            ;;
    esac
    
    cat >> "$template_dir/README.md" << EOF

### Paths

| Path | Description | Container Mount |
|------|-------------|-----------------|
| \`./configs/$app\` | Configuration files | \`/config\` |
EOF

    # Add path mappings based on app type
    case "$app" in
        "sonarr"|"radarr"|"bazarr")
            cat >> "$template_dir/README.md" << EOF
| \`/mnt/artie\` | Media library root | \`/data\` |
| \`/mnt/artie/downloads\` | Downloads folder | \`/downloads\` |
EOF
            ;;
        "transmission"|"nzbget")
            cat >> "$template_dir/README.md" << EOF
| \`/mnt/artie/downloads\` | Downloads folder | \`/downloads\` |
EOF
            if [[ "$app" == "transmission" ]]; then
                echo "| \`/mnt/artie/downloads/watch\` | Watch folder | \`/watch\` |" >> "$template_dir/README.md"
            fi
            ;;
    esac
    
    cat >> "$template_dir/README.md" << EOF

## Access

- **Web Interface**: http://localhost:$port
- **Container Name**: $app
- **Network**: media-network

## Health Checks

The service includes automatic health checks:
- **Interval**: 30 seconds
- **Timeout**: 10 seconds  
- **Retries**: 3

## Security Considerations

### Sanitized Configuration

This template includes sanitized configuration files where:
- ✅ API keys replaced with placeholders
- ✅ Passwords replaced with placeholders
- ✅ Secrets replaced with placeholders
- ✅ Database credentials sanitized

### Required Actions

Before deployment, you must:
1. Replace all \`PLACEHOLDER_*\` values in config files
2. Set secure passwords in environment variables
3. Configure API keys for external services
4. Test all integrations

## Troubleshooting

### Check Service Status

\`\`\`bash
docker-compose ps $app
docker-compose logs -f $app
\`\`\`

### Common Issues

1. **Permission Issues**
   - Ensure PUID/PGID match your system user
   - Check directory ownership: \`chown -R 1001:1001 configs/$app\`

2. **Port Conflicts**
   - Check if port $port is already in use
   - Modify \`${app^^}_PORT\` in .env file

3. **Configuration Issues**
   - Verify all placeholders are replaced
   - Check database file permissions
   - Review sanitization report

## Migration from Native Installation

The automated migration script will:
1. ✅ Stop the native service
2. ✅ Copy configurations to Docker volume
3. ✅ Update environment variables
4. ✅ Start Docker service
5. ✅ Verify functionality
6. ✅ Disable native service

### Manual Migration Steps

If you prefer manual migration:

1. **Backup Current Config**
   \`\`\`bash
   sudo systemctl stop $app
   cp -r /var/lib/$app /var/lib/${app}.backup
   \`\`\`

2. **Copy to Docker**
   \`\`\`bash
   mkdir -p ./configs/$app
   cp -r /var/lib/$app/* ./configs/$app/
   sudo chown -R 1001:1001 ./configs/$app
   \`\`\`

3. **Start Docker Service**
   \`\`\`bash
   docker-compose up -d $app
   \`\`\`

4. **Disable Native Service**
   \`\`\`bash
   sudo systemctl disable $app
   \`\`\`

## Files Structure

\`\`\`
$app/
├── README.md                    # This documentation
├── docker-compose.service.yml  # Docker Compose service definition
├── .env.template               # Environment variables template
├── migrate-to-docker.sh        # Automated migration script
├── config.xml                  # Application config (if exists)
├── database.db                 # Application database (if exists)
└── sanitization-report.json    # Sanitization details
\`\`\`

## Support

For issues specific to this template:
1. Check the sanitization report for missed sensitive data
2. Verify all environment variables are set correctly
3. Ensure proper file permissions (1001:1001)
4. Review Docker logs for startup errors

For $app-specific issues, consult the official documentation.
EOF
    
    log_success "Created README for $app"
}

generate_master_docker_compose() {
    log_info "Generating master Docker Compose file..."
    
    local compose_file="$TEMPLATES_DIR/docker-compose.generated.yml"
    
    cat > "$compose_file" << 'EOF'
# ===============================================
# MEDIA SERVER DOCKER COMPOSE - GENERATED
# ===============================================
# Generated from configuration templates
# Merge this with your main docker-compose.yml
# ===============================================

version: '3.8'

networks:
  media-network:
    driver: bridge

services:
EOF
    
    # Add each application service
    for app in "${!APP_CONFIGS[@]}"; do
        if [[ -f "$TEMPLATES_DIR/$app/docker-compose.service.yml" ]]; then
            echo "" >> "$compose_file"
            cat "$TEMPLATES_DIR/$app/docker-compose.service.yml" >> "$compose_file"
        fi
    done
    
    log_success "Generated master Docker Compose file: $compose_file"
}

generate_master_env_template() {
    log_info "Generating master environment template..."
    
    local env_file="$TEMPLATES_DIR/.env.master.template"
    
    cat > "$env_file" << 'EOF'
# ===============================================
# MEDIA SERVER ENVIRONMENT VARIABLES - GENERATED
# ===============================================
# Generated from application templates
# Merge this with your main .env file
# ===============================================

# System Configuration
PUID=1001
PGID=1001
TZ=Australia/Sydney

# Network Configuration
LOCAL_NETWORK=192.168.69.0/24

# Storage Paths
MEDIA_ROOT=/mnt/artie
DOWNLOADS_PATH=/mnt/artie/downloads
DOWNLOADS_COMPLETE=/mnt/artie/downloads/complete
DOWNLOADS_INCOMPLETE=/mnt/artie/downloads/incomplete
DOWNLOADS_WATCH=/mnt/artie/downloads/watch

# Health Check Settings
HEALTH_CHECK_INTERVAL=30s
HEALTH_CHECK_TIMEOUT=10s
HEALTH_CHECK_RETRIES=3

# Container Settings
RESTART_POLICY=unless-stopped

EOF
    
    # Merge variables from all app templates
    for app in "${!APP_CONFIGS[@]}"; do
        local app_env="$TEMPLATES_DIR/$app/.env.template"
        if [[ -f "$app_env" ]]; then
            echo "# $app Configuration" >> "$env_file"
            grep -E "^${app^^}_|^TRANSMISSION_|^NZBGET_|^OVERSEERR_" "$app_env" >> "$env_file" || true
            echo "" >> "$env_file"
        fi
    done
    
    log_success "Generated master environment template: $env_file"
}

create_validation_script() {
    log_info "Creating template validation script..."
    
    cat > "$TEMPLATES_DIR/validate-templates.sh" << '#!/bin/bash'
#!/bin/bash
# ===============================================
# TEMPLATE VALIDATION SCRIPT
# ===============================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

validate_app_template() {
    local app="$1"
    local app_dir="$SCRIPT_DIR/$app"
    
    if [[ ! -d "$app_dir" ]]; then
        log_error "$app template directory not found"
        return 1
    fi
    
    log_info "Validating $app template..."
    
    local errors=0
    
    # Check required files
    local required_files=(
        "docker-compose.service.yml"
        ".env.template"
        "migrate-to-docker.sh"
        "README.md"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$app_dir/$file" ]]; then
            log_error "Missing required file: $app/$file"
            errors=$((errors + 1))
        fi
    done
    
    # Check for placeholder values
    if [[ -f "$app_dir/.env.template" ]]; then
        if grep -q "your_secure_password" "$app_dir/.env.template"; then
            log_warning "$app template contains placeholder passwords"
        fi
    fi
    
    # Check Docker Compose syntax
    if [[ -f "$app_dir/docker-compose.service.yml" ]]; then
        if ! docker-compose -f "$app_dir/docker-compose.service.yml" config &>/dev/null; then
            log_error "$app Docker Compose syntax is invalid"
            errors=$((errors + 1))
        fi
    fi
    
    # Check migration script is executable
    if [[ -f "$app_dir/migrate-to-docker.sh" ]]; then
        if [[ ! -x "$app_dir/migrate-to-docker.sh" ]]; then
            log_warning "$app migration script is not executable"
            chmod +x "$app_dir/migrate-to-docker.sh"
        fi
    fi
    
    if [[ $errors -eq 0 ]]; then
        log_success "$app template validation passed"
        return 0
    else
        log_error "$app template validation failed with $errors errors"
        return 1
    fi
}

main() {
    echo -e "${BLUE}"
    echo "==============================================="
    echo " TEMPLATE VALIDATION"
    echo "==============================================="
    echo -e "${NC}"
    
    local total_apps=0
    local valid_apps=0
    
    # Validate each app template
    for app_dir in "$SCRIPT_DIR"/*/; do
        if [[ -d "$app_dir" ]]; then
            app=$(basename "$app_dir")
            if [[ "$app" != "." && "$app" != ".." ]]; then
                total_apps=$((total_apps + 1))
                if validate_app_template "$app"; then
                    valid_apps=$((valid_apps + 1))
                fi
                echo
            fi
        fi
    done
    
    # Summary
    echo -e "${GREEN}"
    echo "==============================================="
    echo " VALIDATION SUMMARY"
    echo "==============================================="
    echo -e "${NC}"
    echo "Total templates: $total_apps"
    echo "Valid templates: $valid_apps"
    echo "Failed templates: $((total_apps - valid_apps))"
    
    if [[ $valid_apps -eq $total_apps ]]; then
        log_success "All templates are valid!"
        return 0
    else
        log_error "Some templates have issues"
        return 1
    fi
}

main "$@"
#!/bin/bash
    
    chmod +x "$TEMPLATES_DIR/validate-templates.sh"
    
    log_success "Created template validation script"
}

main() {
    print_header
    
    log_info "Starting Docker template generation..."
    
    # Generate templates for each application
    for app in "${!APP_CONFIGS[@]}"; do
        create_docker_config_template "$app" "${APP_CONFIGS[$app]}"
        create_environment_template "$app"
        create_migration_script "$app"
        create_readme_template "$app"
        echo
    done
    
    # Generate master files
    generate_master_docker_compose
    generate_master_env_template
    create_validation_script
    
    echo -e "${GREEN}"
    echo "==============================================="
    echo " TEMPLATE GENERATION COMPLETED"
    echo "==============================================="
    echo -e "${NC}"
    echo "📁 Templates location: $TEMPLATES_DIR"
    echo "🐳 Generated templates for: ${!APP_CONFIGS[*]}"
    echo "📋 Master files:"
    echo "   • docker-compose.generated.yml"
    echo "   • .env.master.template"
    echo "   • validate-templates.sh"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Validate templates: $TEMPLATES_DIR/validate-templates.sh"
    echo "2. Review and merge generated Docker Compose sections"
    echo "3. Update environment variables with your credentials"
    echo "4. Test individual application migrations"
    echo ""
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi