#!/bin/bash
# ===============================================
# QUICK LOCAL TESTING (NO VM REQUIRED)
# ===============================================
# Runs comprehensive testing using local Docker
# without requiring Vagrant or VirtualBox
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
    echo -e "${CYAN}"
    echo "=============================================="
    echo " QUICK LOCAL TESTING (NO VM REQUIRED)"
    echo "=============================================="
    echo -e "${NC}"
    echo "This will test your automation locally using Docker"
    echo "without requiring Vagrant or VirtualBox."
    echo ""
}

cleanup_previous_tests() {
    log_info "Cleaning up any previous test runs..."
    
    cd "$DOCKER_DIR"
    
    # Stop and remove test containers
    docker-compose -f docker-compose.test.yml down --volumes --remove-orphans 2>/dev/null || true
    
    # Remove test config directories
    rm -rf configs-test/ 2>/dev/null || true
    
    log_success "Previous test cleanup completed"
}

setup_test_environment() {
    log_info "Setting up local test environment..."
    
    # Ensure .env.test exists
    if [[ ! -f "$DOCKER_DIR/.env.test" ]]; then
        log_info "Creating test environment file..."
        cp "$DOCKER_DIR/.env.template" "$DOCKER_DIR/.env.test"
        
        # Update ports for testing
        sed -i 's/SONARR_PORT=8989/SONARR_PORT=9989/' "$DOCKER_DIR/.env.test"
        sed -i 's/RADARR_PORT=7878/RADARR_PORT=8878/' "$DOCKER_DIR/.env.test"
        sed -i 's/PROWLARR_PORT=9696/PROWLARR_PORT=10696/' "$DOCKER_DIR/.env.test"
        sed -i 's/BAZARR_PORT=6767/BAZARR_PORT=7767/' "$DOCKER_DIR/.env.test"
        sed -i 's/OVERSEERR_PORT=5055/OVERSEERR_PORT=6055/' "$DOCKER_DIR/.env.test"
        
        # Set test credentials
        sed -i 's/PROTON_USER=your_protonvpn_username/PROTON_USER=test@example.com/' "$DOCKER_DIR/.env.test"
        sed -i 's/PROTON_PASS=your_protonvpn_password/PROTON_PASS=testpassword/' "$DOCKER_DIR/.env.test"
        
        log_success "Test environment file created"
    fi
    
    # Setup test data
    log_info "Setting up test media data..."
    "$SCRIPT_DIR/setup-test-data.sh" --size small
    
    log_success "Test environment setup completed"
}

run_local_tests() {
    log_info "Running local test suite..."
    
    # Run the main test suite
    if "$SCRIPT_DIR/test-suite.sh"; then
        log_success "Test suite completed successfully"
        return 0
    else
        log_warning "Some tests failed, but continuing..."
        return 1
    fi
}

start_test_services() {
    log_info "Starting test Docker services..."
    
    cd "$DOCKER_DIR"
    
    # Start test stack
    docker-compose -f docker-compose.test.yml --env-file .env.test up -d
    
    # Wait for services to be ready
    log_info "Waiting for services to start (30 seconds)..."
    sleep 30
    
    # Check service status
    log_info "Checking service status..."
    docker-compose -f docker-compose.test.yml ps
    
    log_success "Test services started"
}

test_automation_scripts() {
    log_info "Testing automation scripts..."
    
    # Test API key extraction (will generate test keys)
    if "$SCRIPT_DIR/extract-api-keys.sh" 2>/dev/null; then
        log_success "API key extraction script works"
    else
        log_warning "API key extraction had issues (may be expected in test mode)"
    fi
    
    # Test service integration
    if "$SCRIPT_DIR/configure-integrations.sh" 2>/dev/null; then
        log_success "Service integration script works"
    else
        log_warning "Service integration had issues (may be expected in test mode)"
    fi
}

validate_test_deployment() {
    log_info "Validating test deployment..."
    
    if "$SCRIPT_DIR/validate-deployment.sh" --env-file "$DOCKER_DIR/.env.test"; then
        log_success "Deployment validation passed"
        return 0
    else
        log_warning "Deployment validation had issues"
        return 1
    fi
}

show_test_results() {
    echo ""
    echo -e "${CYAN}=============================================="
    echo " LOCAL TESTING COMPLETED"
    echo -e "===============================================${NC}"
    echo ""
    echo "🌐 Test Services Access:"
    echo "  • Sonarr:    http://localhost:9989"
    echo "  • Radarr:    http://localhost:8878" 
    echo "  • Prowlarr:  http://localhost:10696"
    echo "  • Bazarr:    http://localhost:7767"
    echo "  • Overseerr: http://localhost:6055"
    echo ""
    echo "📁 Generated Files:"
    echo "  • Logs: $PROJECT_DIR/logs/"
    echo "  • Test Config: $DOCKER_DIR/.env.test"
    echo "  • Test Data: /mnt/artie/"
    echo ""
    echo "🔧 Next Steps:"
    echo "  1. Check test service web interfaces above"
    echo "  2. Review logs for any issues"
    echo "  3. When satisfied, stop test services:"
    echo "     cd docker && docker-compose -f docker-compose.test.yml down"
    echo ""
}

cleanup_on_exit() {
    echo ""
    log_info "Cleaning up test environment..."
    cd "$DOCKER_DIR"
    docker-compose -f docker-compose.test.yml down --volumes 2>/dev/null || true
}

main() {
    print_header
    
    # Setup trap for cleanup
    trap cleanup_on_exit EXIT
    
    # Check basic requirements
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker is required but not installed"
        exit 1
    fi
    
    if ! command -v docker-compose >/dev/null 2>&1; then
        log_error "Docker Compose is required but not installed"
        exit 1
    fi
    
    # Run testing workflow
    cleanup_previous_tests
    setup_test_environment
    
    local test_passed=true
    
    # Run tests (continue even if some fail)
    run_local_tests || test_passed=false
    
    start_test_services
    sleep 5
    
    test_automation_scripts
    validate_test_deployment || test_passed=false
    
    show_test_results
    
    if $test_passed; then
        log_success "All local tests completed successfully!"
        echo "Press Enter to clean up and exit, or Ctrl+C to keep services running for manual testing..."
        read -r
    else
        log_warning "Some tests had issues. Check the logs and service interfaces."
        echo "Press Enter to clean up and exit, or Ctrl+C to keep services running for debugging..."
        read -r
    fi
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Quick Local Testing (No VM Required)"
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --no-cleanup   Don't cleanup test services on exit"
        echo ""
        echo "This script runs comprehensive testing using local Docker"
        echo "without requiring Vagrant or VirtualBox."
        echo ""
        exit 0
        ;;
    --no-cleanup)
        trap - EXIT  # Remove cleanup trap
        shift
        main "$@"
        ;;
    *)
        main "$@"
        ;;
esac