#!/bin/bash
set -euo pipefail

# Media Server Bootstrap Script
# Deploys complete media server infrastructure from scratch

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="production"
CONFIG_FILE=""
SKIP_BACKUP=false
SKIP_REBOOT=false
DRY_RUN=false
VERBOSE=false

# Logging
LOG_FILE="/tmp/media-server-bootstrap.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO: $*"
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    log "SUCCESS: $*"
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    log "WARNING: $*"
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    log "ERROR: $*"
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

show_help() {
    cat << EOF
Media Server Bootstrap Script v${VERSION}

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -e, --environment ENV    Target environment (development|production) [default: production]
    -c, --config FILE       Configuration file path
    -b, --skip-backup       Skip backing up existing system
    -r, --skip-reboot       Skip system reboot after kernel updates
    -n, --dry-run          Show what would be done without executing
    -v, --verbose          Verbose output
    -h, --help             Show this help message

EXAMPLES:
    # Deploy to production (default)
    $0

    # Deploy to development VM
    $0 --environment development

    # Deploy with custom config file
    $0 --config /path/to/custom.yml

    # Test deployment without changes
    $0 --dry-run

REQUIREMENTS:
    - Ubuntu 20.04+ or Debian 11+
    - Root access or sudo privileges
    - Internet connectivity
    - At least 4GB RAM and 20GB free disk space

DESCRIPTION:
    This script performs a complete media server deployment:
    
    1. System base setup (packages, users, firewall)
    2. Docker installation and configuration
    3. Network setup (VPN, Tailscale, monitoring)
    4. Storage configuration (NFS mounts)
    5. Media stack deployment (Sonarr, Radarr, etc.)
    6. Monitoring and maintenance setup
    
    The deployment is idempotent and can be safely re-run.

EOF
}

check_requirements() {
    log_info "Checking system requirements..."
    
    # Check OS
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot determine operating system"
        exit 1
    fi
    
    source /etc/os-release
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
        log_error "Unsupported OS: $ID. This script requires Ubuntu or Debian."
        exit 1
    fi
    
    # Check version
    if [[ "$ID" == "ubuntu" && $(echo "$VERSION_ID < 20.04" | bc -l) == 1 ]]; then
        log_error "Ubuntu version too old. Requires 20.04 or newer."
        exit 1
    elif [[ "$ID" == "debian" && $(echo "$VERSION_ID < 11" | bc -l) == 1 ]]; then
        log_error "Debian version too old. Requires 11 or newer."
        exit 1
    fi
    
    # Check privileges
    if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        log_error "This script requires root privileges or passwordless sudo"
        exit 1
    fi
    
    # Check resources
    local mem_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $mem_gb -lt 4 ]]; then
        log_warning "Low memory detected (${mem_gb}GB). Recommended: 4GB+"
    fi
    
    local disk_gb=$(df / | awk 'NR==2{gsub(/G/,"",$4); print int($4)}')
    if [[ $disk_gb -lt 20 ]]; then
        log_warning "Low disk space (${disk_gb}GB free). Recommended: 20GB+"
    fi
    
    # Check network
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_error "No internet connectivity detected"
        exit 1
    fi
    
    # Check required commands
    local missing_commands=()
    for cmd in curl wget git; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_info "Installing missing commands: ${missing_commands[*]}"
        if [[ $DRY_RUN == false ]]; then
            apt-get update -qq
            apt-get install -y "${missing_commands[@]}"
        fi
    fi
    
    log_success "System requirements check passed"
}

install_ansible() {
    if command -v ansible-playbook >/dev/null 2>&1; then
        log_info "Ansible already installed"
        return
    fi
    
    log_info "Installing Ansible..."
    if [[ $DRY_RUN == false ]]; then
        apt-get update -qq
        apt-get install -y software-properties-common
        add-apt-repository --yes --update ppa:ansible/ansible 2>/dev/null || {
            # Fallback for Debian
            apt-get install -y ansible
        }
        apt-get install -y ansible
    fi
    log_success "Ansible installed"
}

backup_existing_system() {
    if [[ $SKIP_BACKUP == true ]]; then
        log_info "Skipping system backup (--skip-backup specified)"
        return
    fi
    
    log_info "Backing up existing system configuration..."
    
    local backup_dir="/tmp/media-server-backup-$(date +%Y%m%d_%H%M%S)"
    
    if [[ $DRY_RUN == false ]]; then
        mkdir -p "$backup_dir"
        
        # Backup system configurations
        [[ -f /etc/fstab ]] && cp /etc/fstab "$backup_dir/"
        [[ -d /etc/systemd/system ]] && cp -r /etc/systemd/system "$backup_dir/"
        
        # Backup media service configs if they exist
        for service in sonarr radarr prowlarr bazarr; do
            if [[ -d "/var/lib/$service" ]]; then
                log_info "Backing up $service configuration..."
                cp -r "/var/lib/$service" "$backup_dir/"
            fi
        done
        
        # Create backup info file
        cat > "$backup_dir/backup_info.txt" << EOF
Media Server Backup
==================
Date: $(date)
Host: $(hostname -f)
OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
Kernel: $(uname -r)

This backup was created before media server automation deployment.

Contents:
- System configuration files
- Service configurations (if found)
- Docker configurations (if found)

Restore instructions are available in the documentation.
EOF
        
        log_success "System backup created: $backup_dir"
        echo "BACKUP_LOCATION=$backup_dir" >> "$LOG_FILE"
    fi
}

run_ansible_playbook() {
    local playbook="$1"
    local extra_vars="$2"
    
    log_info "Running playbook: $playbook"
    
    local cmd="ansible-playbook"
    cmd+=" -i $PROJECT_DIR/ansible/inventory/hosts.yml"
    cmd+=" $PROJECT_DIR/ansible/playbooks/$playbook"
    cmd+=" --limit $ENVIRONMENT"
    
    if [[ -n "$extra_vars" ]]; then
        cmd+=" --extra-vars '$extra_vars'"
    fi
    
    if [[ -n "$CONFIG_FILE" ]]; then
        cmd+=" --extra-vars @$CONFIG_FILE"
    fi
    
    if [[ $VERBOSE == true ]]; then
        cmd+=" -v"
    fi
    
    if [[ $DRY_RUN == true ]]; then
        cmd+=" --check --diff"
        log_info "DRY RUN - Command would be: $cmd"
    else
        log_info "Executing: $cmd"
        eval "$cmd" 2>&1 | tee -a "$LOG_FILE"
        
        if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
            log_error "Playbook $playbook failed"
            exit 1
        fi
    fi
    
    log_success "Playbook $playbook completed successfully"
}

deploy_media_server() {
    log_info "Starting media server deployment..."
    
    # Phase 1: System Base Setup
    run_ansible_playbook "01-system-base.yml" ""
    
    # Phase 2: Docker Installation
    run_ansible_playbook "02-docker-setup.yml" ""
    
    # Phase 3: Network Configuration
    local network_vars=""
    if [[ -n "$CONFIG_FILE" ]]; then
        network_vars="config_file=$CONFIG_FILE"
    fi
    run_ansible_playbook "03-network-config.yml" "$network_vars"
    
    # Phase 4: Storage Setup
    run_ansible_playbook "04-storage-setup.yml" ""
    
    # Phase 5: Media Stack Deployment
    run_ansible_playbook "05-media-stack.yml" ""
    
    log_success "Media server deployment completed!"
}

show_deployment_summary() {
    log_info "Deployment Summary"
    echo
    echo "====================================="
    echo "  Media Server Deployment Complete  "
    echo "====================================="
    echo
    echo "Services should be available at:"
    echo "  • Sonarr:       http://$(hostname -I | awk '{print $1}'):8989"
    echo "  • Radarr:       http://$(hostname -I | awk '{print $1}'):7878"  
    echo "  • Prowlarr:     http://$(hostname -I | awk '{print $1}'):9696"
    echo "  • Bazarr:       http://$(hostname -I | awk '{print $1}'):6767"
    echo "  • Overseerr:    http://$(hostname -I | awk '{print $1}'):5055"
    echo "  • Transmission: http://$(hostname -I | awk '{print $1}'):9091"
    echo "  • NZBGet:       http://$(hostname -I | awk '{print $1}'):6789"
    echo
    echo "Useful commands:"
    echo "  • Check status:     /opt/media-server/status.sh"
    echo "  • View logs:        tail -f $LOG_FILE"
    echo "  • Docker status:    docker ps"
    echo "  • Restart services: systemctl restart media-server"
    echo
    echo "Configuration files:"
    echo "  • Docker Compose:   /opt/media-server/docker-compose.yml"
    echo "  • Environment:      /opt/media-server/.env"
    echo "  • Logs:             $LOG_FILE"
    echo
    if [[ $SKIP_REBOOT == false ]] && [[ $DRY_RUN == false ]]; then
        echo "A system reboot is recommended to ensure all changes take effect."
        echo "Run 'sudo reboot' when ready."
    fi
    echo
}

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -b|--skip-backup)
                SKIP_BACKUP=true
                shift
                ;;
            -r|--skip-reboot)
                SKIP_REBOOT=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
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
    
    # Validate environment
    if [[ "$ENVIRONMENT" != "development" && "$ENVIRONMENT" != "production" ]]; then
        log_error "Invalid environment: $ENVIRONMENT. Must be 'development' or 'production'"
        exit 1
    fi
    
    # Check config file exists
    if [[ -n "$CONFIG_FILE" && ! -f "$CONFIG_FILE" ]]; then
        log_error "Config file not found: $CONFIG_FILE"
        exit 1
    fi
    
    # Start deployment
    log_info "Media Server Bootstrap v${VERSION}"
    log_info "Environment: $ENVIRONMENT"
    log_info "Dry run: $DRY_RUN"
    log_info "Log file: $LOG_FILE"
    echo
    
    # Run deployment phases
    check_requirements
    install_ansible
    backup_existing_system
    deploy_media_server
    show_deployment_summary
    
    log_success "Bootstrap completed successfully!"
}

# Error handling
trap 'log_error "Script failed at line $LINENO"' ERR

# Run main function
main "$@"