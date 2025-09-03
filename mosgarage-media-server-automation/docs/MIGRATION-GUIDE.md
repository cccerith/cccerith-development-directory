# 🚀 Complete Media Server Migration Guide

This comprehensive guide will help you migrate your existing native Servarr installation to a fully containerized Docker environment with advanced monitoring, VPN protection, and automated management.

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Migration Overview](#migration-overview)
3. [Phase 1: Backup & Analysis](#phase-1-backup--analysis)
4. [Phase 2: Environment Setup](#phase-2-environment-setup)
5. [Phase 3: Configuration Migration](#phase-3-configuration-migration)
6. [Phase 4: Docker Deployment](#phase-4-docker-deployment)
7. [Phase 5: Validation & Testing](#phase-5-validation--testing)
8. [Phase 6: Production Cutover](#phase-6-production-cutover)
9. [Post-Migration Tasks](#post-migration-tasks)
10. [Troubleshooting](#troubleshooting)
11. [Rollback Procedures](#rollback-procedures)

## Prerequisites

### System Requirements
- **OS**: Debian/Ubuntu Linux (tested on current system: 192.168.69.29)
- **RAM**: Minimum 4GB, recommended 8GB+
- **Storage**: At least 20GB free space for Docker images and configs
- **Network**: Access to NAS at `artopolis.local` (192.168.69.14)

### Current System Analysis
Based on your system analysis, you currently have:
- ✅ Native services: Sonarr, Radarr, Prowlarr, Bazarr, Transmission, NZBGet, Overseerr
- ✅ NAS mounted at `/mnt/artie` (artopolis.local:/Volume2/Media)
- ✅ Media user: `media` (UID/GID: 1001:1001)
- ✅ Network: 192.168.69.0/24
- ✅ Timezone: Australia/Sydney

### Required Software
- Docker & Docker Compose
- Git (for repository cloning)
- SQLite3 (for database analysis)
- Python 3 (for advanced sanitization)
- curl, jq (for API testing)

## Migration Overview

### What This Migration Provides

🔒 **Enhanced Security**
- VPN protection for all download clients
- Secrets management and configuration sanitization
- Container isolation and least-privilege access

📊 **Advanced Monitoring**
- Grafana dashboards for system and application metrics
- Prometheus metrics collection
- Centralized log aggregation with Loki
- Real-time health monitoring and alerting

🚀 **Automation & Management**
- Automated container updates with Watchtower
- VPN health monitoring and auto-recovery
- Automated archive extraction with Unpackerr
- Web-based Docker management with Portainer

🔄 **Reliability & Maintenance**
- Container health checks and auto-restart
- Automated backups and configuration management
- Easy rollback and disaster recovery
- Plug-and-play deployment for new systems

## Phase 1: Backup & Analysis

### 1.1 Create Complete System Backup

```bash
# Navigate to project directory
cd /home/joao/media-server-automation

# Run comprehensive backup tool
./scripts/backup-servarr-configs.sh
```

This will:
- Backup all native Servarr configurations
- Analyze sensitive data in configurations
- Create sanitized templates for Docker migration
- Generate detailed migration report

### 1.2 Review Backup Results

Check the generated files:
- `backups/native-configs/` - Complete configuration backups
- `docker/config-templates/` - Sanitized Docker templates
- `backups/native-configs/migration-report.md` - Detailed analysis

### 1.3 Verify Current System Status

```bash
# Check all services are running
systemctl status sonarr radarr prowlarr bazarr transmission-daemon nzbget

# Verify NAS mount
df -h /mnt/artie

# Test service connectivity
curl -s http://localhost:8989 > /dev/null && echo "Sonarr: OK"
curl -s http://localhost:7878 > /dev/null && echo "Radarr: OK"
curl -s http://localhost:9696 > /dev/null && echo "Prowlarr: OK"
curl -s http://localhost:6767 > /dev/null && echo "Bazarr: OK"
curl -s http://localhost:5055 > /dev/null && echo "Overseerr: OK"
```

## Phase 2: Environment Setup

### 2.1 Configure Environment Variables

Your `.env` file has been pre-configured with your current system settings:

```bash
# Review and update credentials in .env file
cd /home/joao/media-server-automation/docker
nano .env

# REQUIRED: Set these before proceeding
# - PROTON_USER=your_protonvpn_username
# - PROTON_PASS=your_protonvpn_password  
# - TRANSMISSION_PASS=your_secure_password
# - NZBGET_PASS=your_secure_password
# - GRAFANA_PASSWORD=your_secure_password
```

### 2.2 VPN Configuration

```bash
# Create VPN configuration directory
mkdir -p /home/joao/media-server-automation/docker/configs/gluetun

# Download ProtonVPN configuration (replace with your preferred server)
# Place your ProtonVPN .ovpn file as: configs/gluetun/proton.conf
```

### 2.3 Validate Environment

```bash
# Validate Docker Compose configuration
cd /home/joao/media-server-automation/docker
docker-compose config

# Check environment file
./scripts/validate-migration.sh --env-only
```

## Phase 3: Configuration Migration

### 3.1 Generate Docker Templates

```bash
# Generate all Docker configuration templates
./scripts/generate-docker-templates.sh

# Validate generated templates
cd docker/config-templates
./validate-templates.sh
```

### 3.2 Sanitize Configurations

```bash
# For each application, run sanitization
./scripts/sanitize-servarr-configs.py \
  /var/lib/sonarr \
  docker/configs/sonarr \
  sonarr

./scripts/sanitize-servarr-configs.py \
  /var/lib/radarr \
  docker/configs/radarr \
  radarr

# Continue for prowlarr, bazarr, etc.
```

### 3.3 Manual Configuration Updates

1. **API Keys**: Extract API keys from sanitized configs and set in `.env`
2. **Indexers**: Review Prowlarr indexers for any credential placeholders
3. **Download Clients**: Verify connection settings in Sonarr/Radarr
4. **Quality Profiles**: Ensure all custom quality profiles are preserved

## Phase 4: Docker Deployment

### 4.1 Initial Deployment (Testing Mode)

```bash
cd /home/joao/media-server-automation/docker

# Start core infrastructure first
docker-compose up -d gluetun
sleep 30

# Verify VPN is working
docker exec gluetun curl -s ipinfo.io/ip

# Start monitoring stack
docker-compose up -d prometheus grafana loki promtail

# Start Servarr applications (one by one for testing)
docker-compose up -d sonarr
docker-compose up -d radarr
docker-compose up -d prowlarr
docker-compose up -d bazarr
docker-compose up -d overseerr
```

### 4.2 Download Clients (VPN Protected)

```bash
# Start download clients through VPN
docker-compose up -d transmission nzbget

# Verify VPN protection
docker exec transmission curl -s ipinfo.io/ip  # Should show VPN IP
docker exec nzbget curl -s ipinfo.io/ip       # Should show VPN IP
```

### 4.3 Utility Services

```bash
# Start additional services
docker-compose up -d flaresolverr unpackerr watchtower portainer
```

## Phase 5: Validation & Testing

### 5.1 Comprehensive Testing

```bash
# Run full validation suite
./scripts/validate-migration.sh

# Test specific applications
./scripts/validate-migration.sh sonarr radarr prowlarr bazarr
```

### 5.2 Functional Testing

1. **Web Interface Access**:
   - Sonarr: http://192.168.69.29:8989
   - Radarr: http://192.168.69.29:7878
   - Prowlarr: http://192.168.69.29:9696
   - Bazarr: http://192.168.69.29:6767
   - Overseerr: http://192.168.69.29:5055
   - Grafana: http://192.168.69.29:3000
   - Portainer: https://192.168.69.29:9443

2. **API Connectivity**:
   ```bash
   # Test inter-service communication
   curl -s http://192.168.69.29:8989/api/v1/system/status
   ```

3. **Download Testing**:
   - Add a test torrent through Sonarr/Radarr
   - Verify downloads go through VPN
   - Check automatic extraction with Unpackerr

### 5.3 Monitoring Validation

1. **Grafana Dashboards**: Access Grafana and verify data sources
2. **Prometheus Metrics**: Check http://192.168.69.29:9090/targets
3. **Log Aggregation**: Verify logs in Grafana via Loki data source

## Phase 6: Production Cutover

### 6.1 Final Backup

```bash
# Create final backup before cutover
./scripts/backup-servarr-configs.sh

# Export all current API keys and settings
# (Keep this information secure for rollback if needed)
```

### 6.2 Stop Native Services

```bash
# Stop all native services
sudo systemctl stop sonarr radarr prowlarr bazarr transmission-daemon nzbget overseerr

# Verify services are stopped
sudo systemctl status sonarr radarr prowlarr bazarr transmission-daemon nzbget overseerr
```

### 6.3 Start Full Docker Stack

```bash
cd /home/joao/media-server-automation/docker

# Start everything
docker-compose up -d

# Monitor startup
docker-compose logs -f --tail=50
```

### 6.4 Verify Production Deployment

```bash
# Run full validation
./scripts/validate-migration.sh

# Check all services are healthy
docker-compose ps
docker stats --no-stream
```

### 6.5 Disable Native Services

```bash
# Only after confirming Docker deployment works
sudo systemctl disable sonarr radarr prowlarr bazarr transmission-daemon nzbget
```

## Post-Migration Tasks

### 7.1 Configuration Updates

1. **API Key Updates**: If API keys changed, update:
   - Overseerr connections to Sonarr/Radarr
   - Any external monitoring tools
   - Mobile apps (LunaSea, nzb360, etc.)

2. **Indexer Testing**: Test all indexers in Prowlarr
3. **Download Path Verification**: Ensure all paths point to `/mnt/artie`

### 7.2 Monitoring Setup

1. **Grafana Dashboards**: Import media server dashboards
2. **Alerting**: Configure alerts for service outages
3. **Log Retention**: Configure log retention policies

### 7.3 Automation

1. **Backup Schedule**: Set up automated config backups
2. **Update Schedule**: Configure Watchtower update schedule
3. **Health Monitoring**: Review VPN health monitoring logs

## Troubleshooting

### Common Issues

#### Services Won't Start
```bash
# Check container logs
docker-compose logs service-name

# Check system resources
docker stats
df -h
free -h
```

#### VPN Issues
```bash
# Check VPN container logs
docker-compose logs gluetun

# Test VPN connectivity
docker exec gluetun curl -s ipinfo.io/ip
docker exec gluetun ping -c 3 8.8.8.8
```

#### Permission Issues
```bash
# Fix file ownership
sudo chown -R 1001:1001 /home/joao/media-server-automation/docker/configs
```

#### Database Corruption
```bash
# Restore from backup
cp backups/native-configs/sonarr/sonarr.db docker/configs/sonarr/
```

### Service-Specific Issues

#### Sonarr/Radarr Can't Connect to Download Clients
1. Verify download clients are accessible via container names:
   - Transmission: `http://transmission:9091`
   - NZBGet: `http://nzbget:6789`

2. Check network connectivity:
   ```bash
   docker exec sonarr ping transmission
   docker exec radarr ping nzbget
   ```

#### Indexers Not Working in Prowlarr
1. Check Flaresolverr connection: `http://flaresolverr:8191`
2. Verify VPN doesn't block indexer access
3. Check indexer credentials and rate limits

## Rollback Procedures

### Emergency Rollback

If critical issues occur, you can rollback to native installation:

```bash
# Stop Docker containers
cd /home/joao/media-server-automation/docker
docker-compose down

# Start native services
sudo systemctl start sonarr radarr prowlarr bazarr transmission-daemon nzbget

# Re-enable native services
sudo systemctl enable sonarr radarr prowlarr bazarr transmission-daemon nzbget

# Restore configurations if needed
sudo cp backups/native-configs/sonarr/* /var/lib/sonarr/
sudo chown -R media:media /var/lib/sonarr
```

### Partial Rollback

To rollback individual services:

```bash
# Stop specific container
docker-compose stop sonarr

# Start native service
sudo systemctl start sonarr
sudo systemctl enable sonarr
```

## Success Criteria

Your migration is successful when:

- ✅ All services accessible via web interfaces
- ✅ Download clients protected by VPN
- ✅ Monitoring dashboards showing metrics
- ✅ Automated tasks functioning (downloads, extraction, etc.)
- ✅ All validation tests passing
- ✅ Native services disabled
- ✅ Backups and rollback procedures tested

## Support Resources

- **Docker Logs**: `docker-compose logs -f service-name`
- **Validation Tool**: `./scripts/validate-migration.sh --help`
- **Test Reports**: `logs/migration-test-report.md`
- **Configuration Backups**: `backups/native-configs/`

## Next Steps

After successful migration:

1. **Documentation**: Update any local documentation with new URLs/procedures
2. **Monitoring**: Set up alerting for critical service failures
3. **Maintenance**: Schedule regular health checks and updates
4. **Expansion**: Consider additional services (Requestrr, Recyclarr, etc.)

---

🎉 **Congratulations!** You now have a fully containerized, monitored, and automated media server with VPN protection, advanced monitoring, and plug-and-play deployment capabilities.