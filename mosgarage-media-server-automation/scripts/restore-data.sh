#!/bin/bash
set -euo pipefail

# Media Server Data Restore Script
# Restores configurations and data from backup to new Docker-based setup

VERSION="1.0.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
DOCKER_DIR="/opt/media-server"
MEDIA_USER="media"
MEDIA_UID=1001
MEDIA_GID=1001

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
Media Server Data Restore Script v${VERSION}

USAGE:
    $0 BACKUP_PATH [OPTIONS]

ARGUMENTS:
    BACKUP_PATH             Path to backup directory or .tar.gz file

OPTIONS:
    -s, --services SERVICES Comma-separated list of services to restore
                           [default: all found services]
    -d, --docker-dir DIR   Docker directory [default: $DOCKER_DIR]
    -n, --dry-run          Show what would be restored without changes
    -f, --force            Overwrite existing configurations
    -v, --verbose          Verbose output
    -h, --help             Show this help message

EXAMPLES:
    # Restore all services from backup
    $0 /path/to/backup_20240810_120000

    # Restore only Sonarr and Radarr
    $0 /path/to/backup.tar.gz --services sonarr,radarr

    # Dry run to see what would be restored
    $0 /path/to/backup --dry-run

DESCRIPTION:
    Restores service configurations, databases, and settings from a backup
    created by backup-current.sh to a new Docker-based media server setup.
    
    The script handles:
    • Service configurations (Sonarr, Radarr, etc.)
    • Database files
    • API keys and settings
    • File permissions and ownership

EOF
}

extract_backup() {
    local backup_path="$1"
    local temp_dir
    
    if [[ -d "$backup_path" ]]; then
        echo "$backup_path"
        return
    elif [[ -f "$backup_path" && "$backup_path" == *.tar.gz ]]; then
        log_info "Extracting compressed backup..."
        temp_dir=$(mktemp -d)
        tar -xzf "$backup_path" -C "$temp_dir"
        
        # Find the backup directory (should be backup_TIMESTAMP)
        local extracted_dir=$(find "$temp_dir" -name "backup_*" -type d | head -1)
        if [[ -z "$extracted_dir" ]]; then
            log_error "Could not find backup directory in archive"
            rm -rf "$temp_dir"
            exit 1
        fi
        
        echo "$extracted_dir"
        return
    else
        log_error "Backup path must be a directory or .tar.gz file"
        exit 1
    fi
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if Docker is running
    if ! docker ps >/dev/null 2>&1; then
        log_error "Docker is not running or not accessible"
        exit 1
    fi
    
    # Check if media-server directory exists
    if [[ ! -d "$DOCKER_DIR" ]]; then
        log_error "Docker directory not found: $DOCKER_DIR"
        log_info "Run bootstrap.sh first to create the media server setup"
        exit 1
    fi
    
    # Check if media user exists
    if ! id "$MEDIA_USER" >/dev/null 2>&1; then
        log_error "Media user '$MEDIA_USER' not found"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

validate_backup() {
    local backup_dir="$1"
    
    log_info "Validating backup structure..."
    
    if [[ ! -f "$backup_dir/backup_info.json" ]] && [[ ! -f "$backup_dir/BACKUP_SUMMARY.txt" ]]; then
        log_error "Invalid backup: missing backup info files"
        exit 1
    fi
    
    if [[ ! -d "$backup_dir/configs" ]]; then
        log_error "Invalid backup: missing configs directory"
        exit 1
    fi
    
    # Show backup info
    if [[ -f "$backup_dir/BACKUP_SUMMARY.txt" ]]; then
        echo
        echo "===== BACKUP INFORMATION ====="
        head -20 "$backup_dir/BACKUP_SUMMARY.txt"
        echo "==============================="
        echo
    fi
    
    log_success "Backup validation passed"
}

stop_services() {
    local dry_run="$1"
    
    log_info "Stopping media server services..."
    
    if [[ $dry_run == false ]]; then
        cd "$DOCKER_DIR"
        docker-compose down || true
        
        # Wait for containers to stop
        sleep 5
    else
        log_info "DRY RUN: Would stop Docker services"
    fi
    
    log_success "Services stopped"
}

restore_service_config() {
    local service="$1"
    local backup_dir="$2"
    local dry_run="$3"
    local force="$4"
    
    local source_dir="$backup_dir/configs/$service"
    local target_dir="$DOCKER_DIR/configs/$service"
    
    if [[ ! -d "$source_dir" ]]; then
        log_warning "No backup found for $service"
        return
    fi
    
    log_info "Restoring $service configuration..."
    
    if [[ $dry_run == true ]]; then
        log_info "DRY RUN: Would restore $source_dir -> $target_dir"
        return
    fi
    
    # Check if target exists and force not specified
    if [[ -d "$target_dir" && $force == false ]]; then
        log_warning "$service config already exists, use --force to overwrite"
        return
    fi
    
    # Create target directory
    mkdir -p "$target_dir"
    
    # Copy configuration files
    cp -r "$source_dir"/* "$target_dir/" 2>/dev/null || true
    
    # Set proper ownership
    chown -R "$MEDIA_UID:$MEDIA_GID" "$target_dir"
    
    log_success "$service configuration restored"
}

restore_database() {
    local service="$1" 
    local backup_dir="$2"
    local dry_run="$3"
    local force="$4"
    
    local db_file="$backup_dir/databases/${service}.db"
    
    if [[ ! -f "$db_file" ]]; then
        log_warning "No database backup found for $service"
        return
    fi
    
    log_info "Restoring $service database..."
    
    # Determine target path based on service
    local target_path=""
    case $service in
        sonarr) target_path="$DOCKER_DIR/configs/sonarr/sonarr.db" ;;
        radarr) target_path="$DOCKER_DIR/configs/radarr/radarr.db" ;;
        prowlarr) target_path="$DOCKER_DIR/configs/prowlarr/prowlarr.db" ;;
        bazarr) target_path="$DOCKER_DIR/configs/bazarr/db/bazarr.db" ;;
        *) 
            log_warning "Unknown database path for $service"
            return
            ;;
    esac
    
    if [[ $dry_run == true ]]; then
        log_info "DRY RUN: Would restore database $db_file -> $target_path"
        return
    fi
    
    # Check if target exists and force not specified
    if [[ -f "$target_path" && $force == false ]]; then
        log_warning "$service database already exists, use --force to overwrite"
        return
    fi
    
    # Create target directory if needed
    mkdir -p "$(dirname "$target_path")"
    
    # Copy database
    cp "$db_file" "$target_path"
    
    # Set proper ownership
    chown "$MEDIA_UID:$MEDIA_GID" "$target_path"
    chmod 644 "$target_path"
    
    log_success "$service database restored"
}

restore_transmission_config() {
    local backup_dir="$1"
    local dry_run="$2"
    local force="$3"
    
    local source_dir="$backup_dir/configs/transmission-daemon"
    
    if [[ ! -d "$source_dir" ]]; then
        log_warning "No Transmission backup found"
        return
    fi
    
    log_info "Restoring Transmission configuration..."
    
    if [[ $dry_run == true ]]; then
        log_info "DRY RUN: Would restore Transmission configuration"
        return
    fi
    
    # Convert old transmission config to new Docker format
    local target_dir="$DOCKER_DIR/configs/transmission"
    mkdir -p "$target_dir"
    
    # Copy settings if they exist
    if [[ -f "$source_dir/.config/transmission-daemon/settings.json" ]]; then
        cp "$source_dir/.config/transmission-daemon/settings.json" "$target_dir/"
    elif [[ -f "$source_dir/settings.json" ]]; then
        cp "$source_dir/settings.json" "$target_dir/"
    fi
    
    # Set proper ownership
    chown -R "$MEDIA_UID:$MEDIA_GID" "$target_dir"
    
    log_success "Transmission configuration restored"
}

restore_vpn_config() {
    local backup_dir="$1"
    local dry_run="$2"
    local force="$3"
    
    if [[ ! -f "$backup_dir/system/proton.conf" ]]; then
        log_warning "No ProtonVPN configuration found in backup"
        return
    fi
    
    log_info "Restoring VPN configuration..."
    
    if [[ $dry_run == true ]]; then
        log_info "DRY RUN: Would restore VPN configuration"
        return
    fi
    
    # Copy ProtonVPN config for Gluetun
    mkdir -p "$DOCKER_DIR/configs/gluetun"
    cp "$backup_dir/system/proton.conf" "$DOCKER_DIR/configs/gluetun/"
    
    chown -R "$MEDIA_UID:$MEDIA_GID" "$DOCKER_DIR/configs/gluetun"
    chmod 600 "$DOCKER_DIR/configs/gluetun/proton.conf"
    
    log_success "VPN configuration restored"
}

show_api_keys() {
    local backup_dir="$1"
    
    if [[ ! -d "$backup_dir/credentials" ]]; then
        return
    fi
    
    log_info "Found backed up API keys:"
    echo
    echo "========== API KEYS =========="
    
    for key_file in "$backup_dir/credentials"/*_keys.txt; do
        if [[ -f "$key_file" ]]; then
            local service=$(basename "$key_file" _keys.txt)
            echo "[$service]"
            cat "$key_file" 2>/dev/null || echo "  No keys found"
            echo
        fi
    done
    
    echo "=============================="
    echo
    echo "Note: API keys must be manually configured in the web interfaces"
    echo "or by editing the configuration files after services start."
}

start_services() {
    local dry_run="$1"
    
    log_info "Starting media server services..."
    
    if [[ $dry_run == false ]]; then
        cd "$DOCKER_DIR"
        docker-compose up -d
        
        # Wait for services to start
        log_info "Waiting for services to start..."
        sleep 30
        
        # Check service status
        docker-compose ps
    else
        log_info "DRY RUN: Would start Docker services"
    fi
    
    log_success "Services started"
}

create_restore_summary() {
    local backup_dir="$1"
    local services_restored="$2"
    
    log_info "Creating restore summary..."
    
    cat > "$DOCKER_DIR/restore_summary.txt" << EOF
Media Server Restore Summary
============================
Date: $(date)
Backup Source: $backup_dir
Services Restored: $services_restored

Restored Components:
- Service configurations
- Databases
- VPN configuration

Post-Restore Tasks:
1. Verify all services are accessible
2. Configure API keys manually (see backup credentials/)
3. Test connections between services
4. Verify download functionality
5. Check NFS mount permissions

Service URLs:
- Sonarr:       http://$(hostname -I | awk '{print $1}'):8989
- Radarr:       http://$(hostname -I | awk '{print $1}'):7878
- Prowlarr:     http://$(hostname -I | awk '{print $1}'):9696
- Bazarr:       http://$(hostname -I | awk '{print $1}'):6767
- Overseerr:    http://$(hostname -I | awk '{print $1}'):5055
- Transmission: http://$(hostname -I | awk '{print $1}'):9091
- NZBGet:       http://$(hostname -I | awk '{print $1}'):6789

Troubleshooting:
- Check Docker logs: docker-compose logs [service]
- Check service status: docker-compose ps
- Check permissions: ls -la /opt/media-server/configs/

Restore completed successfully!
EOF

    log_success "Restore summary created: $DOCKER_DIR/restore_summary.txt"
}

main() {
    local backup_path=""
    local services_filter=""
    local dry_run=false
    local force=false
    local verbose=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--services)
                services_filter="$2"
                shift 2
                ;;
            -d|--docker-dir)
                DOCKER_DIR="$2"
                shift 2
                ;;
            -n|--dry-run)
                dry_run=true
                shift
                ;;
            -f|--force)
                force=true
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
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                backup_path="$1"
                shift
                ;;
        esac
    done
    
    # Check required arguments
    if [[ -z "$backup_path" ]]; then
        log_error "Backup path is required"
        show_help
        exit 1
    fi
    
    echo
    echo "======================================="
    echo "  Media Server Restore Script v$VERSION "
    echo "======================================="
    echo
    
    # Extract and validate backup
    local backup_dir
    backup_dir=$(extract_backup "$backup_path")
    
    check_prerequisites
    validate_backup "$backup_dir"
    
    # Parse services to restore
    local services_to_restore=()
    if [[ -n "$services_filter" ]]; then
        IFS=',' read -ra services_to_restore <<< "$services_filter"
    else
        # Auto-detect services from backup
        if [[ -d "$backup_dir/configs" ]]; then
            while IFS= read -r -d '' service_dir; do
                services_to_restore+=($(basename "$service_dir"))
            done < <(find "$backup_dir/configs" -mindepth 1 -maxdepth 1 -type d -print0)
        fi
    fi
    
    log_info "Services to restore: ${services_to_restore[*]:-none}"
    
    if [[ $dry_run == true ]]; then
        log_info "=== DRY RUN MODE - No changes will be made ==="
    fi
    
    # Stop services
    stop_services "$dry_run"
    
    # Restore each service
    for service in "${services_to_restore[@]}"; do
        case $service in
            transmission-daemon)
                restore_transmission_config "$backup_dir" "$dry_run" "$force"
                ;;
            sonarr|radarr|prowlarr|bazarr)
                restore_service_config "$service" "$backup_dir" "$dry_run" "$force"
                restore_database "$service" "$backup_dir" "$dry_run" "$force"
                ;;
            *)
                restore_service_config "$service" "$backup_dir" "$dry_run" "$force"
                ;;
        esac
    done
    
    # Restore VPN configuration
    restore_vpn_config "$backup_dir" "$dry_run" "$force"
    
    # Show API keys that need manual configuration
    show_api_keys "$backup_dir"
    
    # Start services
    start_services "$dry_run"
    
    # Create summary
    if [[ $dry_run == false ]]; then
        create_restore_summary "$backup_dir" "${services_to_restore[*]}"
    fi
    
    echo
    echo "====================================="
    echo "        Restore Complete!          "
    echo "====================================="
    echo
    if [[ $dry_run == false ]]; then
        echo "Services restored: ${services_to_restore[*]}"
        echo "Summary: $DOCKER_DIR/restore_summary.txt"
        echo
        echo "Next steps:"
        echo "1. Check service status: docker-compose ps"
        echo "2. Configure API keys in web interfaces"
        echo "3. Test service connectivity"
        echo "4. Verify downloads are working"
    else
        echo "DRY RUN completed - no changes made"
        echo "Remove --dry-run to perform actual restore"
    fi
    echo
    
    log_success "Restore script completed!"
    
    # Cleanup temporary extraction if used
    if [[ "$backup_dir" == /tmp/* ]]; then
        rm -rf "$backup_dir"
    fi
}

main "$@"