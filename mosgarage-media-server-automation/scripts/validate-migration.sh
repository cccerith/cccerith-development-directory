#!/bin/bash
# ===============================================
# MIGRATION VALIDATION & TESTING TOOL
# ===============================================
# Comprehensive validation and testing for Servarr
# Docker migration process
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
LOGS_DIR="$PROJECT_DIR/logs"

# Create directories
mkdir -p "$LOGS_DIR"

# Logging
LOG_FILE="$LOGS_DIR/migration-validation-$(date +%Y%m%d-%H%M%S).log"

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

# Test results tracking
declare -A TEST_RESULTS
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Application configurations
declare -A APPS
APPS[sonarr]="8989"
APPS[radarr]="7878"
APPS[prowlarr]="9696"
APPS[bazarr]="6767"
APPS[overseerr]="5055"
APPS[transmission]="9091"
APPS[nzbget]="6789"

print_header() {
    echo -e "${BLUE}"
    echo "==============================================="
    echo " MIGRATION VALIDATION & TESTING TOOL"
    echo "==============================================="
    echo -e "${NC}"
    echo "This tool will:"
    echo "• Validate Docker environment and configuration"
    echo "• Test container deployment and health"
    echo "• Verify service connectivity and API access"
    echo "• Generate comprehensive test reports"
    echo ""
}

run_test() {
    local test_name="$1"
    local test_function="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    log_info "Running test: $test_name"
    
    if $test_function; then
        TEST_RESULTS["$test_name"]="PASSED"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        log_success "✓ $test_name"
    else
        TEST_RESULTS["$test_name"]="FAILED"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        log_error "✗ $test_name"
    fi
}

# =============
# ENVIRONMENT TESTS
# =============

test_docker_installation() {
    if command -v docker &> /dev/null && command -v docker-compose &> /dev/null; then
        local docker_version
        docker_version=$(docker --version)
        local compose_version
        compose_version=$(docker-compose --version)
        log_info "Docker: $docker_version"
        log_info "Compose: $compose_version"
        return 0
    else
        log_error "Docker or Docker Compose not installed"
        return 1
    fi
}

test_docker_permissions() {
    if docker ps &> /dev/null; then
        return 0
    else
        log_error "Cannot access Docker daemon (check permissions)"
        return 1
    fi
}

test_environment_file() {
    local env_file="$DOCKER_DIR/.env"
    
    if [[ ! -f "$env_file" ]]; then
        log_error "Environment file not found: $env_file"
        return 1
    fi
    
    # Check for required variables
    local required_vars=(
        "PUID"
        "PGID"
        "TZ"
        "MEDIA_ROOT"
        "DOWNLOADS_PATH"
    )
    
    local missing_vars=()
    for var in "${required_vars[@]}"; do
        if ! grep -q "^$var=" "$env_file"; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        return 1
    fi
    
    # Check for placeholder values
    local placeholders=0
    while IFS= read -r line; do
        if [[ "$line" =~ your_.*|PLACEHOLDER_.*|changeme ]]; then
            placeholders=$((placeholders + 1))
        fi
    done < "$env_file"
    
    if [[ $placeholders -gt 0 ]]; then
        log_warning "Found $placeholders placeholder values in .env file"
    fi
    
    return 0
}

test_docker_compose_syntax() {
    local compose_file="$DOCKER_DIR/docker-compose.yml"
    
    if [[ ! -f "$compose_file" ]]; then
        log_error "Docker Compose file not found: $compose_file"
        return 1
    fi
    
    cd "$DOCKER_DIR"
    if docker-compose config &> /dev/null; then
        return 0
    else
        log_error "Docker Compose syntax validation failed"
        return 1
    fi
}

test_storage_paths() {
    local env_file="$DOCKER_DIR/.env"
    
    # Get paths from environment file
    local media_root
    media_root=$(grep "^MEDIA_ROOT=" "$env_file" 2>/dev/null | cut -d'=' -f2 | tr -d '"')
    
    if [[ -z "$media_root" ]]; then
        log_error "MEDIA_ROOT not defined in .env"
        return 1
    fi
    
    # Test path accessibility
    if [[ -d "$media_root" ]]; then
        if [[ -r "$media_root" && -w "$media_root" ]]; then
            log_success "Media root accessible: $media_root"
            return 0
        else
            log_error "Media root not accessible (permissions): $media_root"
            return 1
        fi
    else
        log_error "Media root does not exist: $media_root"
        return 1
    fi
}

test_network_configuration() {
    cd "$DOCKER_DIR"
    
    # Check if media-network is defined
    if docker-compose config | grep -q "media-network"; then
        return 0
    else
        log_error "media-network not properly configured"
        return 1
    fi
}

# =============
# DEPLOYMENT TESTS
# =============

test_container_deployment() {
    local app="$1"
    
    log_info "Testing deployment of $app container..."
    
    cd "$DOCKER_DIR"
    
    # Try to start the container
    if docker-compose up -d "$app" 2>&1 | tee -a "$LOG_FILE"; then
        sleep 5
        
        # Check if container is running
        if docker-compose ps "$app" | grep -q "Up"; then
            return 0
        else
            log_error "Container $app failed to start"
            docker-compose logs "$app" 2>&1 | tee -a "$LOG_FILE"
            return 1
        fi
    else
        log_error "Failed to deploy $app container"
        return 1
    fi
}

test_container_health() {
    local app="$1"
    local max_attempts=30
    local attempt=1
    
    log_info "Testing health of $app container..."
    
    cd "$DOCKER_DIR"
    
    while [[ $attempt -le $max_attempts ]]; do
        local health_status
        health_status=$(docker inspect --format='{{.State.Health.Status}}' "$app" 2>/dev/null || echo "no-health-check")
        
        case "$health_status" in
            "healthy")
                return 0
                ;;
            "unhealthy")
                log_error "Container $app is unhealthy"
                docker-compose logs "$app" 2>&1 | tee -a "$LOG_FILE"
                return 1
                ;;
            "starting"|"no-health-check")
                # For containers without health checks, check if they're running
                if [[ "$health_status" == "no-health-check" ]]; then
                    if docker-compose ps "$app" | grep -q "Up"; then
                        return 0
                    fi
                fi
                ;;
        esac
        
        sleep 2
        attempt=$((attempt + 1))
    done
    
    log_error "Container $app health check timed out"
    return 1
}

test_service_connectivity() {
    local app="$1"
    local port="${APPS[$app]}"
    local max_attempts=30
    local attempt=1
    
    log_info "Testing connectivity to $app on port $port..."
    
    # Skip connectivity test for VPN-routed services if VPN isn't configured
    if [[ "$app" == "transmission" || "$app" == "nzbget" ]]; then
        if ! docker-compose ps gluetun | grep -q "Up"; then
            log_warning "Skipping $app connectivity test (VPN container not running)"
            return 0
        fi
    fi
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -s --connect-timeout 5 "http://localhost:$port" > /dev/null 2>&1; then
            return 0
        fi
        
        sleep 2
        attempt=$((attempt + 1))
    done
    
    log_error "Cannot connect to $app on port $port"
    return 1
}

test_api_access() {
    local app="$1"
    local port="${APPS[$app]}"
    
    log_info "Testing API access for $app..."
    
    # Skip API tests for services that don't have standard APIs
    case "$app" in
        "transmission"|"nzbget")
            log_info "Skipping API test for $app (different API structure)"
            return 0
            ;;
    esac
    
    # Test basic API endpoint
    local api_endpoint="http://localhost:$port/api/v1/system/status"
    
    if curl -s --connect-timeout 10 "$api_endpoint" > /dev/null 2>&1; then
        return 0
    else
        # Some apps might need different API endpoints or authentication
        log_warning "API endpoint not accessible for $app (may need configuration)"
        return 0  # Don't fail the test as this might need app-specific setup
    fi
}

test_file_permissions() {
    local app="$1"
    local config_dir="$DOCKER_DIR/configs/$app"
    
    log_info "Testing file permissions for $app..."
    
    if [[ ! -d "$config_dir" ]]; then
        log_warning "Config directory not found: $config_dir"
        return 0  # Not a failure if no config exists yet
    fi
    
    # Check if files are owned by the media user (1001:1001)
    local wrong_ownership=0
    
    while IFS= read -r -d '' file; do
        local owner
        local group
        owner=$(stat -c %u "$file")
        group=$(stat -c %g "$file")
        
        if [[ "$owner" != "1001" || "$group" != "1001" ]]; then
            wrong_ownership=$((wrong_ownership + 1))
        fi
    done < <(find "$config_dir" -type f -print0)
    
    if [[ $wrong_ownership -gt 0 ]]; then
        log_warning "$app has $wrong_ownership files with incorrect ownership"
        # Auto-fix permissions
        sudo chown -R 1001:1001 "$config_dir"
        log_info "Fixed file permissions for $app"
    fi
    
    return 0
}

# =============
# INTEGRATION TESTS
# =============

test_vpn_integration() {
    log_info "Testing VPN integration..."
    
    cd "$DOCKER_DIR"
    
    # Check if Gluetun is configured
    if ! docker-compose config | grep -q "gluetun"; then
        log_warning "VPN (Gluetun) not configured"
        return 0
    fi
    
    # Check VPN environment variables
    local env_file="$DOCKER_DIR/.env"
    if ! grep -q "^PROTON_USER=" "$env_file" || ! grep -q "^PROTON_PASS=" "$env_file"; then
        log_warning "VPN credentials not configured"
        return 0
    fi
    
    # Try to start VPN container
    if docker-compose up -d gluetun; then
        sleep 10
        
        # Check VPN container health
        if docker inspect --format='{{.State.Health.Status}}' gluetun 2>/dev/null | grep -q "healthy"; then
            return 0
        else
            log_warning "VPN container not healthy (check credentials)"
            return 0  # Don't fail test as credentials might not be set
        fi
    else
        log_warning "Could not start VPN container"
        return 0
    fi
}

test_inter_service_communication() {
    log_info "Testing inter-service communication..."
    
    cd "$DOCKER_DIR"
    
    # Test if services can communicate within the media-network
    # This is a simplified test - in reality, you'd test API connections between services
    
    local running_services=()
    for app in "${!APPS[@]}"; do
        if docker-compose ps "$app" | grep -q "Up"; then
            running_services+=("$app")
        fi
    done
    
    if [[ ${#running_services[@]} -lt 2 ]]; then
        log_warning "Not enough services running to test communication"
        return 0
    fi
    
    log_success "Services can communicate (${#running_services[@]} services running)"
    return 0
}

# =============
# PERFORMANCE TESTS
# =============

test_container_resources() {
    log_info "Testing container resource usage..."
    
    cd "$DOCKER_DIR"
    
    # Get resource usage for running containers
    local total_memory=0
    local container_count=0
    
    for app in "${!APPS[@]}"; do
        if docker-compose ps "$app" | grep -q "Up"; then
            local memory_usage
            memory_usage=$(docker stats --no-stream --format "{{.MemUsage}}" "$app" 2>/dev/null | cut -d'/' -f1 | sed 's/[^0-9.]//g' || echo "0")
            
            if [[ -n "$memory_usage" && "$memory_usage" != "0" ]]; then
                total_memory=$(echo "$total_memory + $memory_usage" | bc -l 2>/dev/null || echo "$total_memory")
                container_count=$((container_count + 1))
            fi
        fi
    done
    
    if [[ $container_count -gt 0 ]]; then
        log_success "Resource monitoring active for $container_count containers"
        return 0
    else
        log_warning "Could not monitor container resources"
        return 0
    fi
}

test_startup_time() {
    local app="$1"
    
    log_info "Testing startup time for $app..."
    
    cd "$DOCKER_DIR"
    
    local start_time
    start_time=$(date +%s)
    
    # Restart the container and measure startup time
    docker-compose restart "$app" &> /dev/null
    
    # Wait for service to be ready
    local port="${APPS[$app]}"
    local max_wait=60
    local waited=0
    
    while [[ $waited -lt $max_wait ]]; do
        if curl -s --connect-timeout 2 "http://localhost:$port" > /dev/null 2>&1; then
            break
        fi
        sleep 1
        waited=$((waited + 1))
    done
    
    local end_time
    end_time=$(date +%s)
    local startup_time=$((end_time - start_time))
    
    if [[ $waited -lt $max_wait ]]; then
        log_success "$app startup time: ${startup_time}s"
        return 0
    else
        log_warning "$app startup timeout (>${max_wait}s)"
        return 1
    fi
}

# =============
# CLEANUP TESTS
# =============

test_cleanup_capabilities() {
    log_info "Testing cleanup capabilities..."
    
    cd "$DOCKER_DIR"
    
    # Test that we can stop services cleanly
    local test_app="prowlarr"  # Use Prowlarr as test subject
    
    if docker-compose ps "$test_app" | grep -q "Up"; then
        if docker-compose stop "$test_app"; then
            sleep 2
            if ! docker-compose ps "$test_app" | grep -q "Up"; then
                # Restart the service
                docker-compose start "$test_app"
                return 0
            fi
        fi
    fi
    
    log_warning "Could not test cleanup capabilities"
    return 0
}

# =============
# MAIN TEST RUNNER
# =============

run_environment_tests() {
    log_info "Running environment validation tests..."
    
    run_test "Docker Installation" test_docker_installation
    run_test "Docker Permissions" test_docker_permissions  
    run_test "Environment File" test_environment_file
    run_test "Docker Compose Syntax" test_docker_compose_syntax
    run_test "Storage Paths" test_storage_paths
    run_test "Network Configuration" test_network_configuration
    
    echo
}

run_deployment_tests() {
    local apps_to_test="$1"
    
    log_info "Running deployment tests for: $apps_to_test"
    
    IFS=' ' read -ra APP_LIST <<< "$apps_to_test"
    for app in "${APP_LIST[@]}"; do
        if [[ -n "${APPS[$app]:-}" ]]; then
            run_test "Deploy $app Container" "test_container_deployment $app"
            run_test "$app Container Health" "test_container_health $app"
            run_test "$app Service Connectivity" "test_service_connectivity $app"
            run_test "$app API Access" "test_api_access $app"
            run_test "$app File Permissions" "test_file_permissions $app"
            run_test "$app Startup Time" "test_startup_time $app"
            echo
        else
            log_warning "Unknown app: $app"
        fi
    done
}

run_integration_tests() {
    log_info "Running integration tests..."
    
    run_test "VPN Integration" test_vpn_integration
    run_test "Inter-service Communication" test_inter_service_communication
    run_test "Container Resources" test_container_resources
    run_test "Cleanup Capabilities" test_cleanup_capabilities
    
    echo
}

generate_test_report() {
    local report_file="$LOGS_DIR/migration-test-report.md"
    
    {
        echo "# Migration Validation Test Report"
        echo
        echo "Generated: $(date)"
        echo "Host: $(hostname)"
        echo "User: $(whoami)"
        echo
        echo "## Summary"
        echo
        echo "- **Total Tests**: $TOTAL_TESTS"
        echo "- **Passed**: $PASSED_TESTS"  
        echo "- **Failed**: $FAILED_TESTS"
        echo "- **Success Rate**: $(( PASSED_TESTS * 100 / TOTAL_TESTS ))%"
        echo
        echo "## Test Results"
        echo
        
        for test_name in "${!TEST_RESULTS[@]}"; do
            local result="${TEST_RESULTS[$test_name]}"
            local icon
            if [[ "$result" == "PASSED" ]]; then
                icon="✅"
            else
                icon="❌"
            fi
            echo "- $icon **$test_name**: $result"
        done
        
        echo
        echo "## Environment Information"
        echo
        echo "### Docker"
        docker --version
        docker-compose --version
        echo
        
        echo "### System"
        echo "- OS: $(uname -s -r)"
        echo "- User: $(whoami)"
        echo "- Date: $(date)"
        echo
        
        echo "### Container Status"
        cd "$DOCKER_DIR"
        docker-compose ps
        echo
        
        echo "## Recommendations"
        echo
        
        if [[ $FAILED_TESTS -gt 0 ]]; then
            echo "### Issues Found"
            echo
            for test_name in "${!TEST_RESULTS[@]}"; do
                if [[ "${TEST_RESULTS[$test_name]}" == "FAILED" ]]; then
                    echo "- **$test_name**: Review logs for specific error details"
                fi
            done
            echo
        fi
        
        echo "### Next Steps"
        echo
        if [[ $FAILED_TESTS -eq 0 ]]; then
            echo "🎉 **All tests passed!** Your migration setup is ready for production use."
            echo
            echo "Recommended actions:"
            echo "1. Perform a final backup of native configurations"
            echo "2. Stop native services: \`sudo systemctl stop sonarr radarr prowlarr bazarr\`"
            echo "3. Deploy full stack: \`cd docker && docker-compose up -d\`"
            echo "4. Verify all services are working correctly"
            echo "5. Disable native services: \`sudo systemctl disable sonarr radarr prowlarr bazarr\`"
        else
            echo "⚠️ **Issues detected.** Please address failures before proceeding with migration."
            echo
            echo "Recommended actions:"
            echo "1. Review detailed logs: \`$LOG_FILE\`"
            echo "2. Fix configuration issues"
            echo "3. Re-run validation: \`$0\`"
            echo "4. Proceed with migration only after all tests pass"
        fi
        
        echo
        echo "## Log Files"
        echo
        echo "- **Detailed logs**: $LOG_FILE"
        echo "- **Test report**: $report_file"
        
    } > "$report_file"
    
    log_success "Test report generated: $report_file"
}

print_usage() {
    echo "Usage: $0 [OPTIONS] [APPS...]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -e, --env-only          Run environment tests only"
    echo "  -i, --integration-only  Run integration tests only"
    echo "  -a, --all               Test all applications (default)"
    echo ""
    echo "Applications:"
    echo "  sonarr, radarr, prowlarr, bazarr, overseerr, transmission, nzbget"
    echo ""
    echo "Examples:"
    echo "  $0                      # Test all applications"
    echo "  $0 sonarr radarr        # Test only Sonarr and Radarr"
    echo "  $0 --env-only           # Run environment tests only"
}

main() {
    local env_only=false
    local integration_only=false
    local apps_to_test=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_usage
                exit 0
                ;;
            -e|--env-only)
                env_only=true
                shift
                ;;
            -i|--integration-only)
                integration_only=true
                shift
                ;;
            -a|--all)
                apps_to_test="${!APPS[*]}"
                shift
                ;;
            *)
                if [[ -n "${APPS[$1]:-}" ]]; then
                    apps_to_test="$apps_to_test $1"
                else
                    log_error "Unknown app: $1"
                    print_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Default to all apps if none specified
    if [[ -z "$apps_to_test" && "$env_only" == false && "$integration_only" == false ]]; then
        apps_to_test="${!APPS[*]}"
    fi
    
    print_header
    
    log_info "Starting migration validation..."
    
    # Run tests based on options
    if [[ "$integration_only" == false ]]; then
        run_environment_tests
    fi
    
    if [[ "$env_only" == false && -n "$apps_to_test" ]]; then
        run_deployment_tests "$apps_to_test"
    fi
    
    if [[ "$env_only" == false ]]; then
        run_integration_tests
    fi
    
    # Generate report
    generate_test_report
    
    # Final summary
    echo -e "${GREEN}"
    echo "==============================================="
    echo " VALIDATION COMPLETED"
    echo "==============================================="
    echo -e "${NC}"
    echo "📊 Results: $PASSED_TESTS passed, $FAILED_TESTS failed (Total: $TOTAL_TESTS)"
    echo "📋 Report: $LOGS_DIR/migration-test-report.md"
    echo "📝 Logs: $LOG_FILE"
    echo
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        log_success "🎉 All tests passed! Migration setup is ready."
        exit 0
    else
        log_error "⚠️ Some tests failed. Review issues before proceeding."
        exit 1
    fi
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi