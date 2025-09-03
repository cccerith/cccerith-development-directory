# 🧪 Testing Framework

Comprehensive testing strategy for the Media Server Automation project that allows safe testing without interfering with production services.

## 🎯 Testing Strategy

### Multi-Layer Testing Approach

1. **🖥️ VM Testing Environment** - Isolated testing with proper resources
2. **🐳 Isolated Docker Configuration** - Different ports/networks to avoid conflicts  
3. **🤖 Automated Test Suite** - Validates all API integrations and automation
4. **📁 Mock Data Setup** - Simulates real environment safely
5. **✅ End-to-end Validation** - Tests complete workflow

## 🚀 Quick Start Testing

### Option 1: VM Testing (Recommended)

```bash
# Start VM environment
cd vm-testing
vagrant up
vagrant ssh

# Inside VM - run full test suite
cd media-server-automation
./scripts/setup-test-data.sh
./scripts/test-suite.sh
```

### Option 2: Local Testing (Advanced)

```bash
# Setup test data and run tests locally
./scripts/setup-test-data.sh --size small
./scripts/test-suite.sh

# Or run specific test components
docker-compose -f docker/docker-compose.test.yml --env-file docker/.env.test up -d
./scripts/validate-deployment.sh --env-file docker/.env.test
```

## 🖥️ VM Testing Environment

### Enhanced Vagrant Setup

The VM provides a completely isolated environment with:

- **Resources**: 6GB RAM, 4 CPUs for comprehensive testing
- **Port Mapping**: Testing ports offset by +1000 to avoid conflicts
- **Pre-installed Tools**: Docker, Docker Compose, testing utilities
- **Sample Data**: Mock media files and configurations
- **Network Isolation**: Separate VM network (192.168.56.0/24)

### VM Port Mapping

| Service | Production Port | Testing Port | Access URL |
|---------|-----------------|--------------|------------|
| Sonarr | 8989 | 9989 | http://localhost:9989 |
| Radarr | 7878 | 8878 | http://localhost:8878 |
| Prowlarr | 9696 | 10696 | http://localhost:10696 |
| Bazarr | 6767 | 7767 | http://localhost:7767 |
| Overseerr | 5055 | 6055 | http://localhost:6055 |
| Grafana | 3000 | 4000 | http://localhost:4000 |

### Starting VM Environment

```bash
cd vm-testing
vagrant up    # First time setup (takes ~10 minutes)
vagrant ssh   # SSH into VM
```

## 🐳 Isolated Docker Configuration

### Testing Docker Compose

`docker-compose.test.yml` provides:

- **Separate Network**: `media-network-test` (172.30.0.0/16)
- **Test Volumes**: `prometheus-data-test`, `grafana-data-test`, etc.
- **Mock VPN**: Alpine container simulating VPN (no real VPN needed)
- **Health Checks**: All services have proper health monitoring
- **Service Dependencies**: Proper startup ordering

### Starting Test Stack

```bash
cd docker
docker-compose -f docker-compose.test.yml --env-file .env.test up -d

# Check service health
docker-compose -f docker-compose.test.yml ps
```

## 🤖 Automated Test Suite

### Comprehensive Testing Script

`./scripts/test-suite.sh` provides:

- **Prerequisites Tests**: Docker, files, permissions
- **Container Tests**: Syntax, health checks, networking  
- **API Tests**: Connectivity, key validation
- **Integration Tests**: Service communication
- **Automation Tests**: Script availability and functionality

### Running Tests

```bash
# Full test suite
./scripts/test-suite.sh

# Clean up test environment
./scripts/test-suite.sh --clean

# Help and options
./scripts/test-suite.sh --help
```

### Test Results

The test suite generates:
- **Detailed Log**: `logs/test-suite-YYYYMMDD-HHMMSS.log`
- **HTML Report**: `logs/test-report-YYYYMMDD-HHMMSS.html`
- **Console Output**: Real-time test progress

## 📁 Mock Data Setup

### Sample Data Creation

`./scripts/setup-test-data.sh` creates:

- **Media Files**: Sample movies, TV shows with proper structure
- **Download Files**: Mock completed/incomplete downloads
- **Configuration Files**: API keys, service configs
- **Database Files**: SQLite databases with sample data
- **Log Files**: Sample application logs

### Data Size Options

```bash
# Small dataset (text files only)
./scripts/setup-test-data.sh --size small

# Medium dataset (100MB files)  
./scripts/setup-test-data.sh --size medium

# Large dataset (1GB files)
./scripts/setup-test-data.sh --size large

# Custom media root
./scripts/setup-test-data.sh --media-root /tmp/test-media

# Clean test data
./scripts/setup-test-data.sh --clean
```

### Sample Data Structure

```
/mnt/artie/
├── movies/
│   ├── action/The.Matrix.1999/
│   ├── comedy/The.Grand.Budapest.Hotel.2014/
│   └── drama/The.Shawshank.Redemption.1994/
├── tv/
│   ├── Breaking.Bad/Season 01-03/
│   ├── The.Office.US/Season 01-03/
│   └── Planet.Earth/Season 01-03/
├── downloads/
│   ├── complete/
│   ├── incomplete/
│   ├── sonarr/
│   └── radarr/
└── configs-test/
    ├── sonarr/config.xml (with test API key)
    ├── radarr/config.xml (with test API key)
    └── bazarr/config.yaml (with test API key)
```

## ✅ End-to-End Validation

### Deployment Validation Script

`./scripts/validate-deployment.sh` performs:

- **Service Availability**: All web interfaces responding
- **API Integration**: Key configuration and connectivity
- **Storage Validation**: Media directories and permissions
- **Network Validation**: VPN, container networking
- **Workflow Validation**: Automation scripts and capabilities
- **Performance Validation**: Resource usage and health

### Running Validation

```bash
# Validate current deployment
./scripts/validate-deployment.sh

# Validate specific environment
./scripts/validate-deployment.sh --env-file docker/.env.test

# Help and options  
./scripts/validate-deployment.sh --help
```

### Validation Report

Generates comprehensive report with:
- **Service Status**: ✅/❌ for each service
- **Integration Status**: API connectivity and configuration
- **System Health**: Resource usage and performance
- **Next Steps**: Specific actions based on results

## 🔄 Testing Workflows

### Complete Testing Workflow

```bash
# 1. Setup VM environment
cd vm-testing && vagrant up && vagrant ssh

# 2. Inside VM - setup test data
cd media-server-automation
./scripts/setup-test-data.sh

# 3. Run automated test suite
./scripts/test-suite.sh

# 4. Start test services
cd docker
docker-compose -f docker-compose.test.yml --env-file .env.test up -d

# 5. Test API key extraction and integration
./scripts/extract-api-keys.sh
./scripts/configure-integrations.sh

# 6. Validate complete deployment
./scripts/validate-deployment.sh --env-file .env.test

# 7. Manual testing via web interfaces
# Access services at testing ports (see port mapping above)

# 8. Cleanup when done
docker-compose -f docker-compose.test.yml down --volumes
exit  # Exit VM
vagrant halt  # Stop VM
```

### Quick Smoke Test

```bash
# Minimal test to verify basic functionality
./scripts/test-suite.sh | grep -E "(PASS|FAIL|ERROR)"
./scripts/validate-deployment.sh | grep -E "(✅|❌)"
```

## 🐛 Troubleshooting Testing

### Common Issues

#### VM Won't Start
```bash
# Check VirtualBox installation
vboxmanage --version

# Check VM status
vagrant status

# Destroy and recreate VM
vagrant destroy -f
vagrant up
```

#### Docker Services Won't Start
```bash
# Check Docker daemon
sudo systemctl status docker

# Check available resources
docker system df
docker system prune

# View service logs
docker-compose -f docker-compose.test.yml logs [service]
```

#### Port Conflicts
```bash
# Check what's using ports
sudo netstat -tulpn | grep :9989

# Kill conflicting processes
sudo fuser -k 9989/tcp

# Use different ports in .env.test
sed -i 's/9989/19989/g' docker/.env.test
```

#### Permission Issues
```bash
# Fix ownership of test directories
sudo chown -R $USER:$USER /mnt/artie
sudo chown -R 1001:1001 docker/configs-test/

# Fix script permissions
chmod +x scripts/*.sh
```

### Debug Mode

```bash
# Enable verbose logging
export DEBUG=1
./scripts/test-suite.sh

# Run individual test components
./scripts/test-suite.sh --help
```

## 📊 Test Metrics

### What Gets Tested

| Component | Tests | Coverage |
|-----------|-------|----------|
| **Docker Setup** | Compose syntax, networking, volumes | 100% |
| **Service Health** | HTTP responses, API connectivity | 100% |
| **API Integration** | Key extraction, service communication | 90% |
| **Automation** | Script availability, execution | 100% |
| **Storage** | Permissions, mounts, space | 90% |
| **Networking** | VPN, container communication | 80% |

### Test Coverage Report

```bash
# Generate coverage report
./scripts/test-suite.sh > test-results.txt
./scripts/validate-deployment.sh >> test-results.txt

# View summary
grep -E "(PASS|FAIL)" test-results.txt | sort | uniq -c
```

## 🚀 CI/CD Integration

### GitHub Actions Testing

```yaml
# .github/workflows/test.yml
name: Test Suite
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup test environment
        run: ./scripts/setup-test-data.sh --size small
      - name: Run test suite  
        run: ./scripts/test-suite.sh
      - name: Upload test results
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: logs/
```

## 🎓 Best Practices

### Testing Guidelines

1. **Always Test in VM First** - Isolate testing from production
2. **Use Small Test Data** - Faster tests, same validation
3. **Check Logs** - Review detailed logs for failures
4. **Test API Integrations** - Ensure services communicate
5. **Validate Workflows** - Test complete user scenarios
6. **Performance Testing** - Monitor resource usage

### Before Production Deployment

```bash
# Complete pre-deployment checklist
✅ VM tests pass
✅ API integrations work
✅ Services are healthy
✅ Storage is properly configured
✅ VPN protection is working
✅ Monitoring is functional
✅ Backup procedures tested
```

## 📚 Additional Resources

- **Troubleshooting Guide**: [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **Deployment Guide**: [docs/DEPLOYMENT.md](DEPLOYMENT.md)
- **Project README**: [README.md](../README.md)
- **Docker Compose Reference**: [docker/docker-compose.yml](../docker/docker-compose.yml)

---

**🎉 Ready to test your media server automation safely!**

For support, check existing [GitHub Issues](https://github.com/joaopcmiranda/media-server-automation/issues) or create a new one.