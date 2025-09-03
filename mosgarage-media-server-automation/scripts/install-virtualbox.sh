#!/bin/bash
# ===============================================
# VIRTUALBOX AND VAGRANT INSTALLATION SCRIPT
# ===============================================
# Installs VirtualBox and Vagrant on Debian/Ubuntu
# for VM testing of media server automation
# ===============================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "$(date '+%H:%M:%S') $*"
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

print_header() {
    echo -e "${BLUE}"
    echo "=============================================="
    echo " VIRTUALBOX AND VAGRANT INSTALLATION"
    echo "=============================================="
    echo -e "${NC}"
    echo "This script will install VirtualBox and Vagrant"
    echo "for isolated VM testing of your automation."
    echo ""
}

check_system() {
    log_info "Checking system requirements..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    # Check OS
    if [[ ! -f /etc/debian_version ]]; then
        log_error "This script is designed for Debian/Ubuntu systems"
        exit 1
    fi
    
    # Check architecture
    if [[ $(uname -m) != "x86_64" ]]; then
        log_error "This script requires 64-bit system"
        exit 1
    fi
    
    log_success "System check passed"
}

install_prerequisites() {
    log_info "Installing prerequisites..."
    
    # Update package list
    apt-get update -qq
    
    # Install required packages
    apt-get install -y wget curl gnupg2 software-properties-common
    
    log_success "Prerequisites installed"
}

install_virtualbox_method1() {
    log_info "Attempting Method 1: Oracle repository..."
    
    # Create keyrings directory if it doesn't exist
    mkdir -p /usr/share/keyrings
    
    # Download and add Oracle VirtualBox key
    if wget -q -O- https://www.virtualbox.org/download/oracle_vbox_2016.asc | gpg --dearmor --yes --output /usr/share/keyrings/oracle-virtualbox-2016.gpg; then
        log_success "Oracle VirtualBox key added"
    else
        log_error "Failed to add Oracle VirtualBox key"
        return 1
    fi
    
    # Add VirtualBox repository
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-virtualbox-2016.gpg] https://download.virtualbox.org/virtualbox/debian bookworm contrib" > /etc/apt/sources.list.d/virtualbox.list
    
    # Update package list
    if apt-get update -qq; then
        log_success "Package list updated"
    else
        log_error "Failed to update package list"
        return 1
    fi
    
    # Install VirtualBox
    if apt-get install -y virtualbox-7.0; then
        log_success "VirtualBox installed via repository"
        return 0
    else
        log_error "Failed to install VirtualBox via repository"
        return 1
    fi
}

install_virtualbox_method2() {
    log_info "Attempting Method 2: Direct download..."
    
    local temp_dir="/tmp/virtualbox-install"
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    # Download VirtualBox package
    local vbox_url="https://download.virtualbox.org/virtualbox/7.0.14/virtualbox-7.0_7.0.14-161095~Debian~bookworm_amd64.deb"
    
    if wget -q "$vbox_url"; then
        log_success "VirtualBox package downloaded"
    else
        log_error "Failed to download VirtualBox package"
        return 1
    fi
    
    local vbox_package="virtualbox-7.0_7.0.14-161095~Debian~bookworm_amd64.deb"
    
    # Install VirtualBox package
    if dpkg -i "$vbox_package"; then
        log_success "VirtualBox package installed"
    else
        log_warning "VirtualBox package installation had dependency issues, fixing..."
        if apt-get install -f -y; then
            log_success "Dependency issues fixed"
        else
            log_error "Failed to fix dependency issues"
            return 1
        fi
    fi
    
    # Verify installation
    if command -v VBoxManage >/dev/null 2>&1; then
        log_success "VirtualBox installed successfully"
        return 0
    else
        log_error "VirtualBox installation verification failed"
        return 1
    fi
}

install_virtualbox_method3() {
    log_info "Attempting Method 3: Debian repository (older version)..."
    
    # Install VirtualBox from Debian repos (might be older version)
    if apt-get install -y virtualbox virtualbox-ext-pack; then
        log_success "VirtualBox installed from Debian repository"
        return 0
    else
        log_error "Failed to install VirtualBox from Debian repository"
        return 1
    fi
}

install_virtualbox() {
    log_info "Installing VirtualBox..."
    
    # Try multiple installation methods
    if install_virtualbox_method1; then
        log_success "VirtualBox installed using Method 1 (Oracle repository)"
        return 0
    fi
    
    log_warning "Method 1 failed, trying Method 2..."
    if install_virtualbox_method2; then
        log_success "VirtualBox installed using Method 2 (Direct download)"
        return 0
    fi
    
    log_warning "Method 2 failed, trying Method 3..."
    if install_virtualbox_method3; then
        log_success "VirtualBox installed using Method 3 (Debian repository)"
        return 0
    fi
    
    log_error "All VirtualBox installation methods failed"
    return 1
}

install_vagrant() {
    log_info "Installing Vagrant..."
    
    # Try installing Vagrant from Debian repository first
    if apt-get install -y vagrant; then
        log_success "Vagrant installed from Debian repository"
        return 0
    fi
    
    log_warning "Debian repository failed, trying direct download..."
    
    # Download and install latest Vagrant
    local temp_dir="/tmp/vagrant-install"
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    local vagrant_url="https://releases.hashicorp.com/vagrant/2.4.0/vagrant_2.4.0-1_amd64.deb"
    
    if wget -q "$vagrant_url"; then
        log_success "Vagrant package downloaded"
    else
        log_error "Failed to download Vagrant package"
        return 1
    fi
    
    if dpkg -i vagrant_2.4.0-1_amd64.deb; then
        log_success "Vagrant installed via direct download"
        return 0
    else
        log_warning "Fixing Vagrant dependencies..."
        if apt-get install -f -y; then
            log_success "Vagrant dependencies fixed"
            return 0
        else
            log_error "Failed to install Vagrant"
            return 1
        fi
    fi
}

configure_system() {
    log_info "Configuring system..."
    
    # Get the original user (who ran sudo)
    local original_user="${SUDO_USER:-}"
    
    if [[ -n "$original_user" ]]; then
        # Add user to vboxusers group
        if usermod -a -G vboxusers "$original_user"; then
            log_success "Added $original_user to vboxusers group"
        else
            log_warning "Failed to add $original_user to vboxusers group"
        fi
        
        # Set proper permissions for VirtualBox
        if [[ -d /usr/lib/virtualbox ]]; then
            chmod +s /usr/lib/virtualbox/VirtualBox* 2>/dev/null || true
        fi
    else
        log_warning "Could not determine original user, skipping group configuration"
    fi
    
    log_success "System configuration completed"
}

verify_installation() {
    log_info "Verifying installation..."
    
    # Check VirtualBox
    if command -v VBoxManage >/dev/null 2>&1; then
        local vbox_version=$(VBoxManage --version 2>/dev/null || echo "Unknown")
        log_success "VirtualBox installed: $vbox_version"
    else
        log_error "VirtualBox verification failed"
        return 1
    fi
    
    # Check Vagrant
    if command -v vagrant >/dev/null 2>&1; then
        local vagrant_version=$(vagrant --version 2>/dev/null || echo "Unknown")
        log_success "Vagrant installed: $vagrant_version"
    else
        log_error "Vagrant verification failed"
        return 1
    fi
    
    log_success "Installation verification completed"
}

show_next_steps() {
    local original_user="${SUDO_USER:-$(whoami)}"
    
    echo -e "${GREEN}"
    echo "=============================================="
    echo " INSTALLATION COMPLETED SUCCESSFULLY!"
    echo "=============================================="
    echo -e "${NC}"
    
    echo "✅ VirtualBox and Vagrant are now installed"
    echo ""
    echo "🚀 Next Steps:"
    echo "1. Log out and log back in (or run: newgrp vboxusers)"
    echo "2. Go to your project directory:"
    echo "   cd /home/$original_user/media-server-automation/vm-testing"
    echo "3. Start your test VM:"
    echo "   vagrant up"
    echo "4. SSH into the test VM:"
    echo "   vagrant ssh"
    echo "5. Test your automation in complete isolation!"
    echo ""
    echo "🔧 VM Commands:"
    echo "  vagrant up      # Start VM"
    echo "  vagrant ssh     # Connect to VM"
    echo "  vagrant halt    # Stop VM"
    echo "  vagrant destroy # Delete VM"
    echo ""
    echo "📁 Your automation files will be available in the VM at:"
    echo "   /home/vagrant/media-server-automation/"
}

cleanup() {
    log_info "Cleaning up temporary files..."
    rm -rf /tmp/virtualbox-install /tmp/vagrant-install
    log_success "Cleanup completed"
}

main() {
    print_header
    
    # Trap for cleanup
    trap cleanup EXIT
    
    # Run installation steps
    check_system
    install_prerequisites
    
    if install_virtualbox; then
        log_success "VirtualBox installation completed"
    else
        log_error "VirtualBox installation failed"
        exit 1
    fi
    
    if install_vagrant; then
        log_success "Vagrant installation completed"  
    else
        log_error "Vagrant installation failed"
        exit 1
    fi
    
    configure_system
    verify_installation
    
    show_next_steps
    
    log_success "Installation script completed successfully!"
}

# Run main function
main "$@"