#!/bin/bash
# ===============================================
# MEDIA SERVER AUTOMATION - COMPREHENSIVE TEST SUITE
# ===============================================
# Complete testing framework for all automation components
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
TEST_ENV="$DOCKER_DIR/.env.test"
TEST_COMPOSE="$DOCKER_DIR/docker-compose.test.yml"
LOGS_DIR="$PROJECT_DIR/logs"

# Test results tracking
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TEST_RESULTS=()

# Create directories
mkdir -p "$LOGS_DIR"

# Logging
LOG_FILE="$LOGS_DIR/test-suite-$(date +%Y%m%d-%H%M%S).log"

log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE"
}

log_info() {
    log "${BLUE}[INFO]${NC} $*"
}

log_success() {
    log "${GREEN}[PASS]${NC} $*"
}

log_warning() {
    log "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    log "${RED}[FAIL]${NC} $*"
}

log_test() {
    log "${CYAN}[TEST]${NC} $*"
}

# Test execution framework
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    log_test "Running: $test_name"
    ((TESTS_TOTAL++))
    
    if $test_function; then
        log_success "$test_name"
        TEST_RESULTS+=("✅ $test_name")
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$test_name"
        TEST_RESULTS+=("❌ $test_name")
        ((TESTS_FAILED++))
        return 1
    fi
}

print_header() {
    echo -e "${CYAN}"
    echo "=========================================================="
    echo " MEDIA SERVER AUTOMATION - COMPREHENSIVE TEST SUITE"
    echo "=========================================================="
    echo -e "${NC}"
    echo "Environment: Testing"
    echo "Docker Compose: $TEST_COMPOSE"
    echo "Environment File: $TEST_ENV"
    echo "Log File: $LOG_FILE"
    echo ""
}

# ===========================================
# PREREQUISITES TESTS
# ===========================================

test_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker not installed"
        return 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose not installed"
        return 1
    fi
    
    # Check Vagrant (optional for VM testing)
    if ! command -v vagrant &> /dev/null; then
        log_warning "Vagrant not installed - VM testing will be skipped"
    else
        log_success "Vagrant available for VM testing"
    fi
    
    # Check required files
    if [[ ! -f "$TEST_ENV" ]]; then
        log_error "Test environment file missing: $TEST_ENV"
        return 1
    fi
    
    if [[ ! -f "$TEST_COMPOSE" ]]; then
        log_error "Test compose file missing: $TEST_COMPOSE"
        return 1
    fi
    
    # Check test directories
    if [[ ! -d "/mnt/artie" ]]; then
        log_error "Test media directory missing: /mnt/artie"
        return 1
    fi
    
    log_success "All prerequisites met"
    return 0
}

test_script_permissions() {
    log_info "Checking script permissions..."
    
    local scripts=(
        "extract-api-keys.sh"
        "configure-integrations.sh"
        "init-container.sh"
    )
    
    for script in "${scripts[@]}"; do
        local script_path="$SCRIPT_DIR/$script"
        if [[ ! -x "$script_path" ]]; then
            log_error "Script not executable: $script"
            return 1
        fi
    done
    
    log_success "All scripts are executable"
    return 0
}

test_environment_file_completeness() {
    log_info "Testing environment file completeness..."
    
    # Check line count (should be substantial)
    local line_count=$(wc -l < "$TEST_ENV")
    if [[ $line_count -lt 200 ]]; then
        log_error "Environment file too short: $line_count lines (expected >200)"
        return 1
    fi
    
    # Check for critical variables
    local required_vars=(
        "SONARR_PORT"
        "RADARR_PORT"
        "PROWLARR_PORT"
        "BAZARR_PORT"
        "OVERSEERR_PORT"
        "PUID"
        "PGID"
        "TZ"
    )
    
    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=" "$TEST_ENV"; then
            log_error "Missing required variable: $var"
            return 1
        fi
    done
    
    log_success "Environment file is complete ($line_count lines)"
    return 0
}

# ===========================================
# DOCKER CONTAINER TESTS
# ===========================================

test_docker_compose_syntax() {
    log_info "Testing Docker Compose syntax..."
    
    cd "$DOCKER_DIR"
    if docker-compose -f docker-compose.test.yml config >/dev/null 2>&1; then
        log_success "Docker Compose syntax is valid"
        return 0
    else
        log_error "Docker Compose syntax error"
        return 1
    fi
}

start_test_stack() {
    log_info "Starting test Docker stack..."
    
    cd "$DOCKER_DIR"
    
    # Clean up any existing test containers
    docker-compose -f docker-compose.test.yml --env-file .env.test down --volumes --remove-orphans 2>/dev/null || true
    
    # Create test config directories
    mkdir -p configs-test/{sonarr,radarr,prowlarr,bazarr,overseerr,transmission,grafana,prometheus}
    chown -R 1001:1001 configs-test/ || sudo chown -R 1001:1001 configs-test/ || true
    
    # Start core services first
    log_info "Starting core Servarr services..."
    if ! docker-compose -f docker-compose.test.yml --env-file .env.test up -d \
        gluetun-test sonarr-test radarr-test prowlarr-test; then
        log_error "Failed to start core services"
        return 1
    fi
    
    # Wait for core services to be healthy
    log_info "Waiting for core services to be healthy..."
    local max_wait=300  # 5 minutes
    local wait_time=0
    
    while [[ $wait_time -lt $max_wait ]]; do
        if docker-compose -f docker-compose.test.yml --env-file .env.test ps | grep -q "healthy.*sonarr-test" && \
           docker-compose -f docker-compose.test.yml --env-file .env.test ps | grep -q "healthy.*radarr-test" && \
           docker-compose -f docker-compose.test.yml --env-file .env.test ps | grep -q "healthy.*prowlarr-test"; then
            break
        fi
        sleep 10
        wait_time=$((wait_time + 10))
        log_info "Waiting for services... ($wait_time/$max_wait seconds)"
    done
    
    if [[ $wait_time -ge $max_wait ]]; then
        log_error "Services failed to become healthy within $max_wait seconds"
        return 1
    fi
    
    # Start dependent services
    log_info "Starting dependent services..."
    docker-compose -f docker-compose.test.yml --env-file .env.test up -d
    
    # Wait a bit more for all services
    sleep 30
    
    log_success "Test stack started successfully"
    return 0
}

test_service_health() {
    log_info "Testing service health..."
    
    cd "$DOCKER_DIR"
    
    local services=(
        "sonarr-test:9989"
        "radarr-test:8878"
        "prowlarr-test:10696"
    )
    
    for service_info in "${services[@]}"; do
        local service_name=$(echo "$service_info" | cut -d':' -f1)
        local port=$(echo "$service_info" | cut -d':' -f2)
        
        log_info "Checking $service_name on port $port..."
        
        # Check if container is running
        if ! docker ps | grep -q "$service_name"; then
            log_error "$service_name is not running"
            return 1
        fi
        
        # Check if service responds
        local max_attempts=30
        local attempt=1
        
        while [[ $attempt -le $max_attempts ]]; do
            if curl -sf "http://localhost:$port/ping" >/dev/null 2>&1; then
                log_success "$service_name is responding on port $port"
                break
            fi
            
            if [[ $attempt -eq $max_attempts ]]; then
                log_error "$service_name failed to respond on port $port"
                return 1
            fi
            
            sleep 5
            ((attempt++))
        done
    done
    
    return 0
}

# ===========================================
# API KEY EXTRACTION TESTS
# ===========================================

test_api_key_extraction() {
    log_info "Testing API key extraction..."
    
    # Create mock config directories and files
    local test_config_dir="/tmp/test-servarr-configs"
    mkdir -p "$test_config_dir"/{sonarr,radarr,prowlarr,bazarr}
    
    # Create mock Sonarr config
    cat > "$test_config_dir/sonarr/config.xml" << 'EOF'
<Config>
  <ApiKey>test-sonarr-api-key-12345678</ApiKey>
  <Port>8989</Port>
</Config>
EOF
    
    # Create mock Radarr config
    cat > "$test_config_dir/radarr/config.xml" << 'EOF'
<Config>
  <ApiKey>test-radarr-api-key-87654321</ApiKey>
  <Port>7878</Port>
</Config>
EOF
    
    # Create mock Bazarr config
    cat > "$test_config_dir/bazarr/config.yaml" << 'EOF'
auth:
  apikey: test-bazarr-api-key-11223344
port: 6767
EOF
    
    # Create temporary environment file for testing
    local temp_env="/tmp/test.env"
    cp "$TEST_ENV" "$temp_env"
    
    # Test API key extraction (dry run mode)
    # Note: This would need modification of the extraction script for testing
    # For now, we'll just test that the script exists and is executable
    
    if [[ -x "$SCRIPT_DIR/extract-api-keys.sh" ]]; then
        log_success "API key extraction script is available and executable"
        # Clean up
        rm -rf "$test_config_dir"
        rm -f "$temp_env"
        return 0
    else
        log_error "API key extraction script not found or not executable"
        return 1
    fi
}

test_api_key_generation() {
    log_info "Testing API key generation..."
    
    # Test that openssl or python is available for key generation
    if command -v openssl >/dev/null 2>&1; then
        local test_key=$(openssl rand -hex 16)
        if [[ ${#test_key} -eq 32 ]]; then
            log_success "API key generation (openssl) working: ${test_key:0:8}..."
            return 0
        fi
    elif command -v python3 >/dev/null 2>&1; then
        local test_key=$(python3 -c "import secrets; print(secrets.token_hex(16))" 2>/dev/null)
        if [[ ${#test_key} -eq 32 ]]; then
            log_success "API key generation (python3) working: ${test_key:0:8}..."
            return 0
        fi
    fi
    
    log_error "API key generation not working"
    return 1
}

# ===========================================
# SERVICE INTEGRATION TESTS  
# ===========================================

test_service_api_connectivity() {
    log_info "Testing service API connectivity..."
    
    # Get API keys from test environment
    local sonarr_key=$(grep "^SONARR_API_KEY=" "$TEST_ENV" | cut -d'=' -f2 || echo "")
    local radarr_key=$(grep "^RADARR_API_KEY=" "$TEST_ENV" | cut -d'=' -f2 || echo "")
    local prowlarr_key=$(grep "^PROWLARR_API_KEY=" "$TEST_ENV" | cut -d'=' -f2 || echo "")
    
    # Generate test keys if not present
    if [[ -z "$sonarr_key" ]]; then
        sonarr_key="test-sonarr-$(openssl rand -hex 16)"
        log_info "Generated test Sonarr API key"
    fi
    
    if [[ -z "$radarr_key" ]]; then
        radarr_key="test-radarr-$(openssl rand -hex 16)"
        log_info "Generated test Radarr API key"
    fi
    
    if [[ -z "$prowlarr_key" ]]; then
        prowlarr_key="test-prowlarr-$(openssl rand -hex 16)"
        log_info "Generated test Prowlarr API key"
    fi
    
    # Test API endpoints (basic connectivity)
    local services=(
        "sonarr-test:9989:$sonarr_key:system/status"
        "radarr-test:8878:$radarr_key:system/status"
        "prowlarr-test:10696:$prowlarr_key:system/status"
    )
    
    for service_info in "${services[@]}"; do
        local service_name=$(echo "$service_info" | cut -d':' -f1)
        local port=$(echo "$service_info" | cut -d':' -f2)
        local api_key=$(echo "$service_info" | cut -d':' -f3)
        local endpoint=$(echo "$service_info" | cut -d':' -f4)
        
        log_info "Testing $service_name API connectivity..."
        
        # Test basic API access (may fail due to authentication, but we check for proper response)
        local response_code=$(curl -s -o /dev/null -w "%{http_code}" \
            "http://localhost:$port/api/v3/$endpoint" \
            -H "X-Api-Key: $api_key" || echo "000")
        
        # Accept both successful responses and authentication errors (but not connection errors)
        if [[ "$response_code" =~ ^(200|401|403)$ ]]; then
            log_success "$service_name API is reachable (HTTP $response_code)"
        else
            log_error "$service_name API unreachable (HTTP $response_code)"
            return 1
        fi
    done
    
    return 0
}

test_integration_script_availability() {
    log_info "Testing integration script availability..."
    
    if [[ -x "$SCRIPT_DIR/configure-integrations.sh" ]]; then
        log_success "Integration configuration script is available"
        return 0
    else
        log_error "Integration configuration script not found"
        return 1
    fi
}

# ===========================================
# DOCKER COMPOSE ENHANCEMENTS TEST
# ===========================================

test_docker_compose_enhancements() {
    log_info "Testing Docker Compose enhancements..."
    
    cd "$DOCKER_DIR"
    
    # Test that health checks are defined
    if docker-compose -f docker-compose.test.yml config | grep -q "healthcheck:"; then
        log_success "Health checks are defined in Docker Compose"
    else
        log_error "No health checks found in Docker Compose"
        return 1
    fi
    
    # Test that dependencies are properly configured
    if docker-compose -f docker-compose.test.yml config | grep -q "depends_on:"; then
        log_success "Service dependencies are configured"
    else
        log_error "No service dependencies found"
        return 1
    fi
    
    # Test that environment variables are templated
    if docker-compose -f docker-compose.test.yml config | grep -q '\${.*}'; then
        log_success "Environment variable templating is working"
    else
        log_warning "Limited environment variable templating found"
    fi
    
    return 0
}

# ===========================================
# CLEANUP AND REPORTING
# ===========================================

cleanup_test_environment() {
    log_info "Cleaning up test environment..."
    
    cd "$DOCKER_DIR"
    
    # Stop and remove test containers
    docker-compose -f docker-compose.test.yml --env-file .env.test down --volumes --remove-orphans >/dev/null 2>&1 || true
    
    # Remove test config directories
    rm -rf configs-test/ 2>/dev/null || true
    
    log_success "Test environment cleaned up"
}

generate_test_report() {
    local report_file="$LOGS_DIR/test-report-$(date +%Y%m%d-%H%M%S).html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Media Server Automation - Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { background: #f0f8ff; padding: 20px; border-radius: 10px; }
        .summary { background: #f9f9f9; padding: 15px; margin: 20px 0; border-radius: 5px; }
        .pass { color: #28a745; }
        .fail { color: #dc3545; }
        .test-results { margin: 20px 0; }
        .test-item { padding: 5px; margin: 2px 0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🚀 Media Server Automation - Test Report</h1>
        <p><strong>Generated:</strong> $(date)</p>
        <p><strong>Environment:</strong> Testing</p>
    </div>
    
    <div class="summary">
        <h2>📊 Test Summary</h2>
        <p><strong>Total Tests:</strong> $TESTS_TOTAL</p>
        <p><strong class="pass">Passed:</strong> $TESTS_PASSED</p>
        <p><strong class="fail">Failed:</strong> $TESTS_FAILED</p>
        <p><strong>Success Rate:</strong> $(( TESTS_TOTAL > 0 ? (TESTS_PASSED * 100) / TESTS_TOTAL : 0 ))%</p>
    </div>
    
    <div class="test-results">
        <h2>📋 Test Results</h2>
EOF

    for result in "${TEST_RESULTS[@]}"; do
        echo "        <div class=\"test-item\">$result</div>" >> "$report_file"
    done
    
    cat >> "$report_file" << EOF
    </div>
    
    <div class="summary">
        <h2>📁 Log Files</h2>
        <p><strong>Detailed Log:</strong> $LOG_FILE</p>
        <p><strong>Report:</strong> $report_file</p>
    </div>
</body>
</html>
EOF
    
    log_success "Test report generated: $report_file"
}

show_final_summary() {
    echo -e "${CYAN}"
    echo "=========================================================="
    echo " TEST SUITE COMPLETED"
    echo "=========================================================="
    echo -e "${NC}"
    
    echo "📊 Results Summary:"
    echo "  • Total Tests: $TESTS_TOTAL"
    echo -e "  • Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "  • Failed: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "  • Status: ${GREEN}✅ ALL TESTS PASSED${NC}"
    else
        echo -e "  • Status: ${RED}❌ SOME TESTS FAILED${NC}"
    fi
    
    echo ""
    echo "📁 Output Files:"
    echo "  • Detailed Log: $LOG_FILE"
    echo "  • Test Report: $LOGS_DIR/test-report-*.html"
    echo ""
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "${YELLOW}Failed Tests:${NC}"
        for result in "${TEST_RESULTS[@]}"; do
            if [[ "$result" == ❌* ]]; then
                echo "  $result"
            fi
        done
        echo ""
    fi
    
    echo "🚀 Next Steps:"
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "  1. All tests passed! System is ready for deployment"
        echo "  2. Run: docker-compose --env-file docker/.env up -d"  
        echo "  3. Access services via web interfaces"
    else
        echo "  1. Review failed tests and fix issues"
        echo "  2. Re-run test suite: ./scripts/test-suite.sh"
        echo "  3. Check logs for detailed error information"
    fi
}

# ===========================================
# MAIN EXECUTION
# ===========================================

main() {
    print_header
    
    log_info "Starting comprehensive test suite..."
    
    # Prerequisites Tests
    run_test "System Prerequisites" test_prerequisites
    run_test "Script Permissions" test_script_permissions  
    run_test "Environment File Completeness" test_environment_file_completeness
    
    # Docker Tests
    run_test "Docker Compose Syntax" test_docker_compose_syntax
    run_test "Docker Compose Enhancements" test_docker_compose_enhancements
    
    # Start test environment
    if run_test "Start Test Stack" start_test_stack; then
        # Service Tests (only if stack started successfully)
        run_test "Service Health Checks" test_service_health
        run_test "Service API Connectivity" test_service_api_connectivity
        
        # Automation Tests
        run_test "API Key Extraction Available" test_api_key_extraction
        run_test "API Key Generation" test_api_key_generation
        run_test "Integration Scripts Available" test_integration_script_availability
        
        # Cleanup
        cleanup_test_environment
    else
        log_warning "Skipping service tests due to stack startup failure"
    fi
    
    # Generate reports
    generate_test_report
    show_final_summary
    
    # Exit with appropriate code
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All tests completed successfully!"
        exit 0
    else
        log_error "Some tests failed. Please review and fix issues."
        exit 1
    fi
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Media Server Automation Test Suite"
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --clean        Clean up test environment only"
        echo ""
        exit 0
        ;;
    --clean)
        cleanup_test_environment
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac