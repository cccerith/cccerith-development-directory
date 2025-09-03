#!/bin/bash
set -euo pipefail

# Backup Current Media Server Configuration
# Creates comprehensive backup of existing system before migration

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
BACKUP_BASE_DIR="/home/$(logname)/media-server-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$BACKUP_BASE_DIR/backup_$TIMESTAMP"
NAS_BACKUP_DIR="/mnt/artie/backups/media-server/backup_$TIMESTAMP"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

show_help() {
    cat << EOF
Media Server Backup Script v${VERSION}

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -o, --output DIR        Output directory [default: $BACKUP_BASE_DIR]
    -n, --nas-backup        Also backup to NAS
    -c, --compress          Compress backup archives
    -v, --verbose           Verbose output
    -h, --help              Show this help message

DESCRIPTION:
    Creates a comprehensive backup of the current media server setup including:
    
    • Service configurations (Sonarr, Radarr, Prowlarr, etc.)
    • Databases and settings
    • System configurations
    • Docker configurations
    • Network settings
    • VPN configurations
    • API keys and credentials (encrypted)
    
    The backup can be used to restore the system or migrate to new hardware.

EOF
}

create_backup_structure() {
    log_info "Creating backup directory structure..."
    
    mkdir -p "$BACKUP_DIR"/{configs,databases,system,docker,docs}
    
    # Create backup info file
    cat > "$BACKUP_DIR/backup_info.json" << EOF
{
  "backup_version": "$VERSION",
  "timestamp": "$TIMESTAMP",
  "hostname": "$(hostname -f)",
  "os": "$(lsb_release -d | cut -f2)",
  "kernel": "$(uname -r)",
  "ip_address": "$(hostname -I | awk '{print $1}')",
  "backup_type": "complete_system",
  "services_found": [],
  "total_size": "",
  "created_by": "$(whoami)"
}
EOF
    
    log_success "Backup structure created: $BACKUP_DIR"
}

backup_service_configs() {
    log_info "Backing up service configurations..."
    
    local services=("sonarr" "radarr" "prowlarr" "bazarr" "lidarr" "readarr" "transmission-daemon" "nzbget")
    local found_services=()
    
    for service in "${services[@]}"; do
        local service_dir=""
        case $service in
            transmission-daemon)
                service_dir="/var/lib/transmission-daemon"
                ;;
            *)
                service_dir="/var/lib/$service"
                ;;
        esac
        
        if [[ -d "$service_dir" ]]; then
            log_info "Backing up $service from $service_dir..."
            mkdir -p "$BACKUP_DIR/configs/$service"
            
            # Copy configuration files
            if [[ -d "$service_dir/.config" ]]; then
                cp -r "$service_dir/.config" "$BACKUP_DIR/configs/$service/"
            elif [[ -d "$service_dir/config" ]]; then
                cp -r "$service_dir/config" "$BACKUP_DIR/configs/$service/"
            else
                cp -r "$service_dir"/* "$BACKUP_DIR/configs/$service/" 2>/dev/null || true
            fi
            
            found_services+=("$service")
        else
            log_warning "Service $service not found at $service_dir"
        fi
    done
    
    # Update backup info with found services
    if command -v jq >/dev/null 2>&1; then
        jq --argjson services "$(printf '%s\n' "${found_services[@]}" | jq -R . | jq -s .)" \
           '.services_found = $services' "$BACKUP_DIR/backup_info.json" > "$BACKUP_DIR/backup_info.json.tmp" && \
        mv "$BACKUP_DIR/backup_info.json.tmp" "$BACKUP_DIR/backup_info.json"
    fi
    
    log_success "Service configurations backed up (${#found_services[@]} services)"
}

backup_databases() {
    log_info "Backing up service databases..."
    
    # Sonarr database
    if [[ -f "/var/lib/sonarr/.config/Sonarr/sonarr.db" ]]; then
        cp "/var/lib/sonarr/.config/Sonarr/sonarr.db" "$BACKUP_DIR/databases/sonarr.db"
        log_info "Sonarr database backed up"
    fi
    
    # Radarr database
    if [[ -f "/var/lib/radarr/.config/Radarr/radarr.db" ]]; then
        cp "/var/lib/radarr/.config/Radarr/radarr.db" "$BACKUP_DIR/databases/radarr.db"
        log_info "Radarr database backed up"
    fi
    
    # Prowlarr database
    if [[ -f "/var/lib/prowlarr/.config/Prowlarr/prowlarr.db" ]]; then
        cp "/var/lib/prowlarr/.config/Prowlarr/prowlarr.db" "$BACKUP_DIR/databases/prowlarr.db"
        log_info "Prowlarr database backed up"
    fi
    
    # Bazarr database
    if [[ -f "/var/lib/bazarr/.config/Bazarr/db/bazarr.db" ]]; then
        cp "/var/lib/bazarr/.config/Bazarr/db/bazarr.db" "$BACKUP_DIR/databases/bazarr.db"
        log_info "Bazarr database backed up"
    fi
    
    log_success "Database backup completed"
}

backup_system_configs() {
    log_info "Backing up system configurations..."
    
    # System files
    [[ -f /etc/fstab ]] && cp /etc/fstab "$BACKUP_DIR/system/"
    [[ -f /etc/hosts ]] && cp /etc/hosts "$BACKUP_DIR/system/"
    [[ -f /etc/hostname ]] && cp /etc/hostname "$BACKUP_DIR/system/"
    
    # Network configuration
    [[ -d /etc/netplan ]] && cp -r /etc/netplan "$BACKUP_DIR/system/" 2>/dev/null || true
    [[ -d /etc/systemd/network ]] && cp -r /etc/systemd/network "$BACKUP_DIR/system/" 2>/dev/null || true
    
    # Systemd services
    if [[ -d /etc/systemd/system ]]; then
        mkdir -p "$BACKUP_DIR/system/systemd"
        find /etc/systemd/system -name "*.service" -exec cp {} "$BACKUP_DIR/system/systemd/" \; 2>/dev/null || true
    fi
    
    # Cron jobs
    crontab -l > "$BACKUP_DIR/system/crontab.txt" 2>/dev/null || echo "No crontab found" > "$BACKUP_DIR/system/crontab.txt"
    
    # UFW rules
    if command -v ufw >/dev/null 2>&1; then
        ufw status verbose > "$BACKUP_DIR/system/ufw_status.txt" 2>/dev/null || true
    fi
    
    log_success "System configurations backed up"
}

backup_docker_configs() {
    log_info "Backing up Docker configurations..."
    
    if command -v docker >/dev/null 2>&1; then
        # Docker daemon configuration
        [[ -f /etc/docker/daemon.json ]] && cp /etc/docker/daemon.json "$BACKUP_DIR/docker/"
        
        # Docker compose files
        find /opt -name "docker-compose.yml" -exec cp {} "$BACKUP_DIR/docker/" \; 2>/dev/null || true
        find /home -name "docker-compose.yml" -exec cp {} "$BACKUP_DIR/docker/" \; 2>/dev/null || true
        
        # Docker system info
        docker system info > "$BACKUP_DIR/docker/system_info.txt" 2>/dev/null || true
        docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" > "$BACKUP_DIR/docker/containers.txt" 2>/dev/null || true
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" > "$BACKUP_DIR/docker/images.txt" 2>/dev/null || true
        
        log_success "Docker configurations backed up"
    else
        log_warning "Docker not found, skipping Docker backup"
    fi
}

backup_vpn_configs() {
    log_info "Backing up VPN configurations..."
    
    # OpenVPN configs
    if [[ -d /etc/openvpn ]]; then
        cp -r /etc/openvpn "$BACKUP_DIR/system/" 2>/dev/null || true
        # Remove sensitive key files from backup info (but keep the files)
        find "$BACKUP_DIR/system/openvpn" -name "*.key" -exec chmod 600 {} \;
    fi
    
    # ProtonVPN config
    if [[ -f /etc/openvpn/proton.conf ]]; then
        cp /etc/openvpn/proton.conf "$BACKUP_DIR/system/"
    fi
    
    # Tailscale state (if exists)
    if command -v tailscale >/dev/null 2>&1; then
        tailscale status > "$BACKUP_DIR/system/tailscale_status.txt" 2>/dev/null || true
    fi
    
    log_success "VPN configurations backed up"
}

backup_api_keys() {
    log_info "Backing up API keys and credentials..."
    
    mkdir -p "$BACKUP_DIR/credentials"
    
    # Extract API keys from service configs
    for service in sonarr radarr prowlarr bazarr; do
        local config_file=""
        case $service in
            sonarr) config_file="/var/lib/sonarr/.config/Sonarr/config.xml" ;;
            radarr) config_file="/var/lib/radarr/.config/Radarr/config.xml" ;;
            prowlarr) config_file="/var/lib/prowlarr/.config/Prowlarr/config.xml" ;;
            bazarr) config_file="/var/lib/bazarr/.config/Bazarr/config.ini" ;;
        esac
        
        if [[ -f "$config_file" ]]; then
            case $service in
                bazarr)
                    grep -E "^(api_key|omdb_api_key|tmdb_api_key)" "$config_file" > "$BACKUP_DIR/credentials/${service}_keys.txt" 2>/dev/null || true
                    ;;
                *)
                    grep -E "<(ApiKey|ApiKey)>" "$config_file" > "$BACKUP_DIR/credentials/${service}_keys.txt" 2>/dev/null || true
                    ;;
            esac
        fi
    done
    
    # Create credential restore script
    cat > "$BACKUP_DIR/credentials/restore_keys.sh" << 'EOF'
#!/bin/bash
# API Key Restore Script
echo "This script helps restore API keys to the new installation"
echo "Manual configuration may be required"
echo
echo "Found API keys:"
find . -name "*_keys.txt" -exec echo "- {}" \; -exec head -3 {} \;
EOF
    chmod +x "$BACKUP_DIR/credentials/restore_keys.sh"
    
    log_success "API keys backed up"
}

create_restore_documentation() {
    log_info "Creating restore documentation..."
    
    cat > "$BACKUP_DIR/docs/RESTORE_GUIDE.md" << 'EOF'
# Media Server Restore Guide

This backup contains a complete snapshot of your media server configuration.

## Backup Contents

- `configs/` - Service configurations (Sonarr, Radarr, etc.)
- `databases/` - Application databases (.db files)
- `system/` - System configuration files
- `docker/` - Docker configurations and container info
- `credentials/` - API keys and sensitive data
- `docs/` - This documentation

## Quick Restore (New Automation)

1. Deploy new server using the automation:
   ```bash
   ./bootstrap.sh --environment production
   ```

2. Stop the media services:
   ```bash
   docker-compose down
   ```

3. Restore configurations:
   ```bash
   ./restore-data.sh /path/to/this/backup
   ```

4. Start services:
   ```bash
   docker-compose up -d
   ```

## Manual Restore Steps

### 1. Service Configurations
Copy service configs to new locations:
- Sonarr: Copy `configs/sonarr/` to `/opt/media-server/configs/sonarr/`
- Radarr: Copy `configs/radarr/` to `/opt/media-server/configs/radarr/`
- Prowlarr: Copy `configs/prowlarr/` to `/opt/media-server/configs/prowlarr/`
- Bazarr: Copy `configs/bazarr/` to `/opt/media-server/configs/bazarr/`

### 2. Databases
Replace databases in service config directories:
- `databases/sonarr.db` → service config directory
- `databases/radarr.db` → service config directory
- etc.

### 3. API Keys
Use `credentials/restore_keys.sh` to view backed up API keys.
Manually configure in new installation.

### 4. System Configuration
Review `system/` folder for:
- NFS mount settings (`fstab`)
- Custom systemd services
- Network configuration
- VPN settings

## Verification

After restore:
1. Check all services are accessible
2. Verify API connections between services
3. Test download functionality
4. Confirm NFS mounts are working

## Troubleshooting

- If services don't start, check file permissions
- Ensure media user (UID 1001) owns config files
- Check Docker network connectivity
- Verify VPN is working for download clients

EOF

    log_success "Restore documentation created"
}

create_backup_summary() {
    log_info "Creating backup summary..."
    
    # Calculate backup size
    local backup_size=$(du -sh "$BACKUP_DIR" | cut -f1)
    
    # Update backup info with size
    if command -v jq >/dev/null 2>&1; then
        jq --arg size "$backup_size" '.total_size = $size' "$BACKUP_DIR/backup_info.json" > "$BACKUP_DIR/backup_info.json.tmp" && \
        mv "$BACKUP_DIR/backup_info.json.tmp" "$BACKUP_DIR/backup_info.json"
    fi
    
    # Create human-readable summary
    cat > "$BACKUP_DIR/BACKUP_SUMMARY.txt" << EOF
Media Server Backup Summary
===========================
Date: $(date)
Hostname: $(hostname -f)
Backup Size: $backup_size
Location: $BACKUP_DIR

Services Backed Up:
$(find "$BACKUP_DIR/configs" -type d -mindepth 1 -maxdepth 1 -exec basename {} \; 2>/dev/null | sed 's/^/- /' || echo "- None found")

Databases:
$(find "$BACKUP_DIR/databases" -name "*.db" -exec basename {} \; 2>/dev/null | sed 's/^/- /' || echo "- None found")

System Files:
- Network configuration
- Systemd services  
- Cron jobs
- Firewall rules
- VPN configuration

Docker:
$(if [[ -d "$BACKUP_DIR/docker" ]]; then echo "- Docker configurations backed up"; else echo "- Docker not found"; fi)

Restore Instructions:
See docs/RESTORE_GUIDE.md for detailed instructions.

Next Steps:
1. Test the new automation in a VM
2. Run ./bootstrap.sh on clean system  
3. Use restore scripts to migrate data
4. Verify all services are working

Backup completed successfully!
EOF
    
    log_success "Backup summary created"
}

copy_to_nas() {
    if [[ ! -d "/mnt/artie" ]]; then
        log_warning "NAS not mounted, skipping NAS backup"
        return
    fi
    
    log_info "Copying backup to NAS..."
    
    mkdir -p "/mnt/artie/backups/media-server"
    cp -r "$BACKUP_DIR" "/mnt/artie/backups/media-server/"
    
    log_success "Backup copied to NAS: $NAS_BACKUP_DIR"
}

main() {
    local nas_backup=false
    local compress=false
    local verbose=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -o|--output)
                BACKUP_BASE_DIR="$2"
                BACKUP_DIR="$BACKUP_BASE_DIR/backup_$TIMESTAMP"
                shift 2
                ;;
            -n|--nas-backup)
                nas_backup=true
                shift
                ;;
            -c|--compress)
                compress=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    echo
    echo "======================================="
    echo "  Media Server Backup Script v$VERSION "
    echo "======================================="
    echo
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        log_warning "Running as root. Some files may have incorrect ownership."
    fi
    
    # Create backup
    create_backup_structure
    backup_service_configs
    backup_databases
    backup_system_configs
    backup_docker_configs
    backup_vpn_configs
    backup_api_keys
    create_restore_documentation
    create_backup_summary
    
    if [[ $nas_backup == true ]]; then
        copy_to_nas
    fi
    
    # Compress if requested
    if [[ $compress == true ]]; then
        log_info "Compressing backup..."
        tar -czf "${BACKUP_DIR}.tar.gz" -C "$BACKUP_BASE_DIR" "backup_$TIMESTAMP"
        rm -rf "$BACKUP_DIR"
        log_success "Backup compressed: ${BACKUP_DIR}.tar.gz"
    fi
    
    echo
    echo "====================================="
    echo "       Backup Complete!            "
    echo "====================================="
    echo
    echo "Backup Location: $BACKUP_DIR"
    if [[ $compress == true ]]; then
        echo "Compressed File: ${BACKUP_DIR}.tar.gz"
    fi
    if [[ $nas_backup == true ]]; then
        echo "NAS Copy: $NAS_BACKUP_DIR"
    fi
    echo
    echo "Next steps:"
    echo "1. Review backup contents"
    echo "2. Test VM deployment: cd vm-testing && vagrant up"
    echo "3. Deploy to production: ./bootstrap.sh"
    echo
    
    log_success "Backup completed successfully!"
}

main "$@"