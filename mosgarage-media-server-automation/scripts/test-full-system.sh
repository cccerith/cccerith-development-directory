#!/bin/bash
# ===============================================
# FULL SYSTEM TESTING WITH SYSTEMD CONTAINER
# ===============================================
# Creates a complete Ubuntu system inside Docker
# with systemd, users, networking, mounting
# ===============================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CONTAINER_NAME="media-server-full-test"
IMAGE_NAME="jrei/systemd-ubuntu:24.04"

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
    echo -e "${RED}[ERROR]${NC} $*"
}

print_header() {
    echo -e "${BLUE}"
    echo "=================================================="
    echo " FULL SYSTEM TESTING WITH SYSTEMD CONTAINER"
    echo "=================================================="
    echo -e "${NC}"
    echo "This creates a complete Ubuntu system for testing:"
    echo "• Full systemd init system"
    echo "• User management and permissions"
    echo "• Network configuration"
    echo "• File system mounting"
    echo "• Complete automation testing"
    echo ""
}

cleanup_existing() {
    log_info "Cleaning up any existing test containers..."
    
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
    
    log_success "Cleanup completed"
}

create_test_system() {
    log_info "Creating full system test container..."
    
    # Create a complete Ubuntu system with systemd
    docker run -d \
        --name "$CONTAINER_NAME" \
        --privileged \
        --tmpfs /tmp \
        --tmpfs /run \
        --tmpfs /run/lock \
        --volume /sys/fs/cgroup:/sys/fs/cgroup:rw \
        --volume "$(pwd):/workspace:rw" \
        --publish 9989:8989 \
        --publish 8878:7878 \
        --publish 10696:9696 \
        --publish 7767:6767 \
        --publish 6055:5055 \
        --publish 10091:9091 \
        --publish 7789:6789 \
        --publish 4000:3000 \
        --publish 10090:9090 \
        --publish 10443:9443 \
        --cgroupns=host \
        "$IMAGE_NAME" \
        /sbin/init
    
    log_success "System container created: $CONTAINER_NAME"
    
    # Wait for systemd to initialize
    log_info "Waiting for systemd to initialize..."
    sleep 10
    
    log_success "System container is ready"
}

setup_test_system() {
    log_info "Setting up complete test system..."
    
    # Install everything needed for a full system
    docker exec "$CONTAINER_NAME" bash -c '
        # Update system
        apt-get update -qq
        
        # Install essential packages
        apt-get install -y \
            curl wget git htop tree jq xmlstarlet sqlite3 \
            ca-certificates gnupg lsb-release net-tools unzip zip \
            sudo nano vim less \
            nfs-common cifs-utils \
            iptables netfilter-persistent \
            rsyslog logrotate \
            cron
        
        # Install Docker
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
        apt-get update -qq
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
        # Install Docker Compose
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        
        # Start Docker service
        systemctl enable docker
        systemctl start docker
        
        echo "✅ System packages installed"
    '
    
    log_success "System packages installed"
}

setup_users_and_permissions() {
    log_info "Setting up users and permissions..."
    
    docker exec "$CONTAINER_NAME" bash -c '
        # Create media user and group (matching your production)
        groupadd -g 1001 media
        useradd -r -s /bin/false -u 1001 -g 1001 media
        
        # Create admin user for testing
        useradd -m -s /bin/bash testuser
        usermod -aG sudo testuser
        usermod -aG docker testuser
        echo "testuser:testpass" | chpasswd
        
        # Setup sudo without password for testing
        echo "testuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/testuser
        
        echo "✅ Users and permissions configured"
    '
    
    log_success "Users and permissions configured"
}

setup_filesystem() {
    log_info "Setting up filesystem and mount points..."
    
    docker exec "$CONTAINER_NAME" bash -c '
        # Create media directory structure (simulating NAS mount)
        mkdir -p /mnt/artie/{downloads/{complete,incomplete,watch},movies,tv,music,books}
        mkdir -p /mnt/artie/downloads/{sonarr,radarr,transmission,nzbget}
        
        # Set proper ownership
        chown -R media:media /mnt/artie
        chmod -R 755 /mnt/artie
        
        # Create sample media files for testing
        mkdir -p /mnt/artie/tv/TestShow/Season01
        mkdir -p /mnt/artie/movies/TestMovie
        echo "Sample TV episode" > "/mnt/artie/tv/TestShow/Season01/TestShow.S01E01.mkv"
        echo "Sample movie" > "/mnt/artie/movies/TestMovie/TestMovie.2024.mkv"
        chown -R media:media /mnt/artie
        
        # Create backup directories
        mkdir -p /opt/media-server/{backups,configs,logs}
        chown -R testuser:testuser /opt/media-server
        
        echo "✅ Filesystem and mount points configured"
    '
    
    log_success "Filesystem configured"
}

setup_networking() {
    log_info "Setting up networking..."
    
    docker exec "$CONTAINER_NAME" bash -c '
        # Configure basic networking (container already has network access)
        # Set hostname
        echo "media-server-test" > /etc/hostname
        
        # Configure hosts file
        echo "127.0.0.1 localhost media-server-test" > /etc/hosts
        echo "::1 localhost ip6-localhost ip6-loopback" >> /etc/hosts
        
        # Enable IP forwarding (for Docker)
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
        sysctl -p
        
        echo "✅ Networking configured"
    '
    
    log_success "Networking configured"
}

copy_automation_files() {
    log_info "Copying automation files..."
    
    docker exec "$CONTAINER_NAME" bash -c '
        # Copy project files
        cp -r /workspace /home/testuser/media-server-automation
        chown -R testuser:testuser /home/testuser/media-server-automation
        
        # Make scripts executable
        chmod +x /home/testuser/media-server-automation/scripts/*.sh
        
        echo "✅ Automation files copied"
    '
    
    log_success "Automation files copied"
}

show_access_info() {
    echo -e "${GREEN}"
    echo "=================================================="
    echo " FULL SYSTEM TEST ENVIRONMENT READY!"
    echo "=================================================="
    echo -e "${NC}"
    
    echo "🖥️  System Details:"
    echo "  • Container: $CONTAINER_NAME"
    echo "  • OS: Ubuntu 24.04 with full systemd"
    echo "  • Users: testuser (admin), media (service user)"
    echo "  • Docker: Installed and running"
    echo "  • Media Root: /mnt/artie (with sample data)"
    echo ""
    echo "🚪 Access Your Test System:"
    echo "  docker exec -it $CONTAINER_NAME bash"
    echo "  # Or as test user:"
    echo "  docker exec -it --user testuser $CONTAINER_NAME bash"
    echo ""
    echo "🧪 Test Your Complete Automation:"
    echo "  docker exec -it --user testuser $CONTAINER_NAME bash"
    echo "  cd media-server-automation"
    echo "  sudo ./scripts/bootstrap.sh"
    echo ""
    echo "🌐 Test Service Ports (from your host):"
    echo "  • Sonarr:    http://localhost:9989"
    echo "  • Radarr:    http://localhost:8878"
    echo "  • Prowlarr:  http://localhost:10696"
    echo "  • Overseerr: http://localhost:6055"
    echo "  • Grafana:   http://localhost:4000"
    echo ""
    echo "🛑 When Done Testing:"
    echo "  docker stop $CONTAINER_NAME"
    echo "  docker rm $CONTAINER_NAME"
}

main() {
    print_header
    
    # Check Docker is available
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker is required but not installed"
        exit 1
    fi
    
    cleanup_existing
    create_test_system
    setup_test_system
    setup_users_and_permissions
    setup_filesystem
    setup_networking
    copy_automation_files
    
    show_access_info
    
    log_success "Full system test environment is ready!"
    echo ""
    echo "Ready to test your complete automation in a real Linux environment!"
}

main "$@"