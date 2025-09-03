# Media Server Deployment Guide

Complete guide for deploying a fully automated media server with VPN-protected download clients.

## Table of Contents

1. [Quick Start](#quick-start)
2. [VM Testing](#vm-testing)
3. [Production Deployment](#production-deployment)
4. [Configuration](#configuration)
5. [Services Overview](#services-overview)
6. [Troubleshooting](#troubleshooting)

## Quick Start

### Prerequisites

- Ubuntu 20.04+ or Debian 11+
- 4GB+ RAM, 20GB+ free disk space
- Root access or sudo privileges
- Internet connectivity
- NAS with NFS share (optional but recommended)

### One-Command Deployment

```bash
# Clone the repository
git clone https://github.com/your-username/media-server-automation.git
cd media-server-automation

# Deploy to production
sudo ./scripts/bootstrap.sh
```

That's it! The script will:
- Install all dependencies (Docker, Ansible, etc.)
- Configure system (users, firewall, networking)
- Deploy all media services with VPN protection
- Set up monitoring and backups

## VM Testing

Test the complete deployment in a local VM before production:

### 1. Start Test VM

```bash
cd vm-testing
vagrant up
vagrant ssh
```

### 2. Run Deployment in VM

```bash
cd media-server-automation
sudo ./scripts/bootstrap.sh --environment development
```

### 3. Test Services

Visit these URLs in your browser:
- Sonarr: http://localhost:8989
- Radarr: http://localhost:7878
- Prowlarr: http://localhost:9696
- Bazarr: http://localhost:6767
- Transmission: http://localhost:9091
- NZBGet: http://localhost:6789
- Overseerr: http://localhost:5055

## Production Deployment

### Step 1: Backup Current System

If you have an existing media server, back it up first:

```bash
./scripts/backup-current.sh --nas-backup
```

This creates a complete backup of your current configuration.

### Step 2: Prepare Environment

Create configuration file (optional):

```bash
cp docker/.env.template production.env
```

Edit `production.env` with your settings:
- VPN credentials
- Download client passwords
- API keys

### Step 3: Deploy

```bash
sudo ./scripts/bootstrap.sh --config production.env
```

### Step 4: Restore Data (if migrating)

```bash
./scripts/restore-data.sh /path/to/backup
```

## Configuration

### Environment Variables

The deployment uses these key environment variables:

```bash
# VPN Configuration
PROTON_USER=your_username
PROTON_PASS=your_password
PROTON_CONFIG=proton.conf

# Download Clients
TRANSMISSION_USER=admin
TRANSMISSION_PASS=secure_password

# Network
LOCAL_NETWORK=192.168.69.0/24

# Storage
MEDIA_ROOT=/mnt/artie
DOWNLOADS_PATH=/mnt/artie/downloads
```

### Custom Configuration

Create a custom configuration file:

```yaml
# custom-config.yml
nas_host: your-nas.local
nas_path: /volume1/media
local_network: 192.168.1.0/24

vpn:
  provider: protonvpn
  username: your_vpn_user
  password: your_vpn_pass

services:
  transmission:
    username: admin
    password: secure_password
  
  nzbget:
    username: admin
    password: secure_password
```

Deploy with custom config:

```bash
sudo ./scripts/bootstrap.sh --config custom-config.yml
```

## Services Overview

### Core Management Services

| Service | Port | Description |
|---------|------|-------------|
| Sonarr | 8989 | TV show management |
| Radarr | 7878 | Movie management |
| Prowlarr | 9696 | Indexer management |
| Bazarr | 6767 | Subtitle management |
| Overseerr | 5055 | Request management |

### Download Clients (VPN Protected)

| Service | Port | Description |
|---------|------|-------------|
| Transmission | 9091 | BitTorrent client |
| NZBGet | 6789 | Usenet client |

Both download clients are routed through VPN with kill switch protection.

### Supporting Services

| Service | Port | Description |
|---------|------|-------------|
| Flaresolverr | 8191 | Cloudflare bypass |
| Watchtower | - | Auto-updates containers |

### VPN Architecture

```
Internet Traffic Flow:
├── Management Apps (Sonarr/Radarr) → Local Network → Internet
└── Download Clients (Transmission/NZBGet) → VPN → Internet
```

**Benefits:**
- Download traffic always encrypted
- Management apps work normally
- Kill switch prevents IP leaks
- Better performance (management traffic not VPN-routed)

## Network Configuration

### Firewall Rules

The deployment automatically configures UFW firewall:

```bash
# Allowed ports
22    # SSH
8989  # Sonarr
7878  # Radarr
9696  # Prowlarr
6767  # Bazarr
5055  # Overseerr
9091  # Transmission
6789  # NZBGet
8191  # Flaresolverr
```

### VPN Kill Switch

Automatic kill switch ensures download clients can't leak IP:

- If VPN disconnects, download clients lose internet access
- Traffic monitoring detects and alerts on IP leaks
- Automatic reconnection when VPN comes back online

### Tailscale Integration

Secure remote access via Tailscale:

```bash
# Configure Tailscale during deployment
sudo tailscale up --authkey=your_auth_key
```

## Storage Configuration

### NFS Mount

Automatic NFS configuration for network storage:

```bash
# /etc/fstab entry created automatically
nas.local:/volume1/media /mnt/artie nfs4 defaults,_netdev 0 0
```

### Directory Structure

```
/mnt/artie/
├── downloads/
│   ├── complete/
│   ├── incomplete/
│   └── watch/
├── movies/
├── tv/
├── music/
└── books/
```

### Permissions

All media files use unified user/group:
- User: `media` (UID: 1001)
- Group: `media` (GID: 1001)

## Monitoring and Maintenance

### Health Checks

Automatic monitoring services:

```bash
# Check overall system health
/opt/media-server/status.sh

# Check network connectivity
/opt/media-server/check-network.sh

# Check storage status
/opt/media-server/check-storage.sh
```

### Automatic Backups

Daily configuration backups:

```bash
# Local backups
/opt/media-server/backups/

# NAS backups (if available)
/mnt/artie/backups/media-server/
```

### Log Management

Centralized logging with automatic rotation:

```bash
# Service logs
docker-compose logs [service]

# System logs
journalctl -u media-server

# Application logs
/opt/media-server/configs/*/logs/
```

## Service Management

### Docker Compose Commands

```bash
cd /opt/media-server

# View status
docker-compose ps

# View logs
docker-compose logs [service]

# Restart service
docker-compose restart [service]

# Update services
docker-compose pull
docker-compose up -d
```

### Individual Service Control

```bash
# Stop specific service
docker stop sonarr

# Start specific service  
docker start sonarr

# View service logs
docker logs sonarr -f
```

### System Service

Media server runs as systemd service:

```bash
# Control entire stack
systemctl start media-server
systemctl stop media-server
systemctl restart media-server
systemctl status media-server
```

## Post-Deployment Tasks

### 1. Configure API Keys

After deployment, configure connections between services:

1. **Prowlarr Setup:**
   - Add indexers
   - Copy API key
   - Add applications (Sonarr, Radarr)

2. **Sonarr/Radarr Setup:**
   - Add Prowlarr as indexer (use API key)
   - Add download clients:
     - Transmission: http://gluetun:9091
     - NZBGet: http://gluetun:6789

3. **Overseerr Setup:**
   - Connect to Sonarr/Radarr using API keys
   - Configure request settings

### 2. Test Download Functionality

1. Add a test movie/TV show request via Overseerr
2. Verify it appears in Radarr/Sonarr
3. Check download starts in Transmission/NZBGet
4. Confirm VPN IP is being used

### 3. Verify VPN Protection

```bash
# Check download client IP
docker exec transmission curl -s ifconfig.me

# Should show VPN IP (Switzerland), not your real IP
```

## Updating

### Container Updates

Watchtower automatically updates containers daily at 4 AM. Manual update:

```bash
cd /opt/media-server
docker-compose pull
docker-compose up -d
```

### System Updates

Automatic security updates are enabled. Manual update:

```bash
sudo apt update && sudo apt upgrade
```

## Backup Strategy

### Automated Backups

- **Daily:** Configuration files backed up automatically
- **Weekly:** Database files included in backups
- **Storage:** Backups saved locally and to NAS

### Manual Backup

```bash
# Create full backup
./scripts/backup-current.sh --nas-backup --compress

# Backup specific services
./scripts/backup-current.sh --services sonarr,radarr
```

### Disaster Recovery

Complete system recovery from backup:

1. Deploy fresh system: `./scripts/bootstrap.sh`
2. Restore data: `./scripts/restore-data.sh /path/to/backup`
3. Verify services and connections

## Security

### Built-in Security Features

- UFW firewall configured automatically
- Fail2ban protection against brute force
- VPN kill switch prevents IP leaks
- Services run as non-root user
- Automatic security updates
- Network segmentation via Docker

### Security Best Practices

1. **Change default passwords** in .env file
2. **Enable 2FA** where supported (Overseerr, etc.)
3. **Use strong VPN provider** (ProtonVPN recommended)
4. **Keep system updated** (automatic updates enabled)
5. **Monitor logs** for suspicious activity
6. **Use Tailscale** for secure remote access

## Performance Optimization

### Resource Allocation

Default container resource limits:

```yaml
# High-usage services
sonarr/radarr: 1GB RAM limit
bazarr: 512MB RAM limit

# Download clients
transmission: 2GB RAM limit  
nzbget: 1GB RAM limit
```

### Network Optimization

- Optimized TCP buffers for high-speed transfers
- DNS caching for faster lookups
- Connection pooling for database operations

### Storage Optimization

- NFS client optimized for media streaming
- Proper disk scheduling for concurrent I/O
- Log rotation to prevent disk filling

## Next Steps

After successful deployment:

1. **Configure your indexers** in Prowlarr
2. **Set up quality profiles** in Sonarr/Radarr
3. **Add your media libraries** 
4. **Configure notifications** (Discord, email, etc.)
5. **Set up monitoring** (optional Grafana dashboard)
6. **Create additional backups** of your configuration

## Getting Help

If you encounter issues:

1. Check the [Troubleshooting Guide](TROUBLESHOOTING.md)
2. Review logs: `docker-compose logs [service]`
3. Run health checks: `/opt/media-server/status.sh`
4. Create GitHub issue with logs and system info

The deployment creates a production-ready media server with enterprise-level automation, monitoring, and security. Enjoy your fully automated media management system! 🎬🍿