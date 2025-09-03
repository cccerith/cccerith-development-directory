# 💻 Laptop Testing Guide

Quick guide for testing your media server automation on a fresh Ubuntu laptop.

## 🚀 Quick Setup on Fresh Ubuntu

### 1. Clone the Repository
```bash
git clone https://github.com/joaopcmiranda/media-server-automation.git
cd media-server-automation
```

### 2. Run Complete Automation Test
```bash
# Test the complete automation as if rebuilding your server
sudo ./scripts/bootstrap.sh --environment testing

# Or step-by-step testing
./scripts/setup-test-data.sh
./scripts/test-suite.sh
```

### 3. Test Individual Components
```bash
# Test API key extraction and management
./scripts/extract-api-keys.sh

# Test service integration setup
./scripts/configure-integrations.sh

# Validate complete deployment
./scripts/validate-deployment.sh
```

## 🌐 Access Test Services

After successful deployment, access services at:
- **Overseerr**: http://localhost:5055 (main interface)
- **Sonarr**: http://localhost:8989
- **Radarr**: http://localhost:7878
- **Prowlarr**: http://localhost:9696
- **Bazarr**: http://localhost:6767
- **Grafana**: http://localhost:3000

## ✅ What Gets Tested

- ✅ **User Management**: Creates media user (1001:1001)
- ✅ **Permissions**: Proper file/folder permissions
- ✅ **Storage**: NFS mount simulation and media structure
- ✅ **Networking**: Docker networking and VPN routing
- ✅ **API Integration**: Automatic service configuration
- ✅ **Automation Scripts**: All custom automation tools
- ✅ **Service Health**: Complete monitoring stack

## 🔧 Testing Different Scenarios

### Test with Your Actual VPN
```bash
# Edit .env file with real ProtonVPN credentials
nano docker/.env

# Add your credentials:
PROTON_USER=your_actual_username
PROTON_PASS=your_actual_password
```

### Test NAS Mount Simulation
```bash
# The bootstrap script creates /mnt/artie with sample data
# This simulates your actual NAS mount structure
ls -la /mnt/artie/
```

### Test Complete Migration
```bash
# Simulate migrating from native to Docker
./scripts/backup-current.sh    # Backup configs
./scripts/bootstrap.sh         # Deploy Docker stack
./scripts/restore-data.sh      # Restore configurations
```

## 📋 Verification Checklist

After testing, verify:
- [ ] All services start and are accessible
- [ ] API keys are properly configured between services
- [ ] Prowlarr can connect to Sonarr/Radarr
- [ ] Bazarr can connect to Sonarr/Radarr for subtitles
- [ ] Download clients work through VPN
- [ ] Media directories have proper permissions
- [ ] Monitoring stack (Grafana) is functional
- [ ] Backup/restore procedures work

## 🚀 Ready for Production?

If all tests pass on your laptop, you can confidently run the same automation on your production server:

```bash
# On your production server
git clone https://github.com/joaopcmiranda/media-server-automation.git
cd media-server-automation

# Update .env with your production settings
cp docker/.env.template docker/.env
nano docker/.env

# Deploy to production
sudo ./scripts/bootstrap.sh
```

## 📞 Support

- **Documentation**: [README.md](README.md)
- **Testing Framework**: [docs/TESTING.md](docs/TESTING.md)
- **Troubleshooting**: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- **Issues**: [GitHub Issues](https://github.com/joaopcmiranda/media-server-automation/issues)

---

**🎯 Goal**: Test everything on the laptop first, then deploy to production with confidence!