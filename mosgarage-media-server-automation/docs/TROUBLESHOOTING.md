# Media Server Troubleshooting Guide

Common issues and solutions for the automated media server deployment.

## Table of Contents

1. [General Troubleshooting](#general-troubleshooting)
2. [Deployment Issues](#deployment-issues)
3. [Docker Issues](#docker-issues)
4. [VPN Issues](#vpn-issues)
5. [Service-Specific Issues](#service-specific-issues)
6. [Network Issues](#network-issues)
7. [Storage Issues](#storage-issues)
8. [Performance Issues](#performance-issues)

## General Troubleshooting

### Quick Diagnosis Commands

```bash
# Check overall system status
/opt/media-server/status.sh

# Check all containers
docker-compose ps

# Check logs for all services
docker-compose logs --tail=50

# Check system resources
htop
df -h
```

### Common First Steps

1. **Restart services:**
   ```bash
   cd /opt/media-server
   docker-compose restart
   ```

2. **Check system resources:**
   ```bash
   free -h  # Memory usage
   df -h    # Disk usage
   ```

3. **Review recent logs:**
   ```bash
   journalctl -n 100 --no-pager
   ```

## Deployment Issues

### Bootstrap Script Fails

**Issue:** `bootstrap.sh` exits with errors

**Common Causes & Solutions:**

1. **Insufficient permissions:**
   ```bash
   sudo ./scripts/bootstrap.sh
   ```

2. **Network connectivity:**
   ```bash
   ping -c 3 8.8.8.8
   curl -I https://github.com
   ```

3. **Disk space:**
   ```bash
   df -h /
   # Need at least 20GB free
   ```

4. **Missing dependencies:**
   ```bash
   sudo apt update
   sudo apt install -y curl wget git
   ```

### Ansible Playbook Failures

**Issue:** Ansible tasks fail during deployment

**Debug Steps:**

1. **Run with verbose output:**
   ```bash
   ./scripts/bootstrap.sh --verbose
   ```

2. **Check Ansible logs:**
   ```bash
   tail -f /tmp/media-server-bootstrap.log
   ```

3. **Test specific playbook:**
   ```bash
   ansible-playbook -i ansible/inventory/hosts.yml \
     ansible/playbooks/01-system-base.yml --check
   ```

4. **Common fixes:**
   ```bash
   # Update package lists
   sudo apt update
   
   # Fix broken packages
   sudo apt --fix-broken install
   
   # Clear apt cache
   sudo apt clean
   ```

### VM Testing Issues

**Issue:** Vagrant VM won't start or provision fails

**Solutions:**

1. **VirtualBox issues:**
   ```bash
   # Update VirtualBox
   sudo apt update
   sudo apt install virtualbox virtualbox-ext-pack
   
   # Check VM status
   VBoxManage list runningvms
   ```

2. **Vagrant issues:**
   ```bash
   # Update Vagrant
   vagrant version
   
   # Destroy and recreate
   vagrant destroy -f
   vagrant up
   ```

3. **Network conflicts:**
   ```bash
   # Check for conflicting networks
   VBoxManage list hostonlyifs
   ```

## Docker Issues

### Containers Won't Start

**Issue:** Services fail to start or keep restarting

**Diagnosis:**

1. **Check container status:**
   ```bash
   docker-compose ps
   docker ps -a
   ```

2. **Check container logs:**
   ```bash
   docker-compose logs [service_name]
   docker logs [container_name] --tail=50
   ```

3. **Check resource usage:**
   ```bash
   docker stats
   ```

**Common Solutions:**

1. **Permission issues:**
   ```bash
   sudo chown -R 1001:1001 /opt/media-server/configs
   sudo chmod -R 755 /opt/media-server/configs
   ```

2. **Port conflicts:**
   ```bash
   netstat -tlnp | grep -E ':(8989|7878|9696)'
   # Stop conflicting services
   sudo systemctl stop service_name
   ```

3. **Memory issues:**
   ```bash
   # Check available memory
   free -h
   # Reduce container memory limits in docker-compose.yml
   ```

### Docker Compose Issues

**Issue:** `docker-compose` commands fail

**Solutions:**

1. **Update Docker Compose:**
   ```bash
   sudo curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
   sudo chmod +x /usr/local/bin/docker-compose
   ```

2. **Check compose file syntax:**
   ```bash
   docker-compose config
   ```

3. **Recreate containers:**
   ```bash
   docker-compose down --volumes
   docker-compose up -d
   ```

### Image Pull Failures

**Issue:** Docker images fail to download

**Solutions:**

1. **Check internet connectivity:**
   ```bash
   docker run --rm busybox ping -c 3 8.8.8.8
   ```

2. **Clear Docker cache:**
   ```bash
   docker system prune -a
   ```

3. **Use alternative registry:**
   ```bash
   # Edit docker-compose.yml to use different image registry
   ```

## VPN Issues

### VPN Container Fails

**Issue:** Gluetun VPN container won't start or connect

**Diagnosis:**

1. **Check Gluetun logs:**
   ```bash
   docker logs gluetun --tail=50
   ```

2. **Test VPN credentials:**
   ```bash
   # Check if credentials are set
   docker exec gluetun env | grep -E "(USER|PASS)"
   ```

**Common Solutions:**

1. **VPN credential issues:**
   ```bash
   # Update .env file with correct credentials
   vim /opt/media-server/.env
   docker-compose restart gluetun
   ```

2. **VPN server issues:**
   ```bash
   # Try different server
   # Edit docker-compose.yml:
   environment:
     - SERVER_COUNTRIES=Netherlands  # Instead of Switzerland
   ```

3. **Firewall blocking VPN:**
   ```bash
   # Temporarily disable UFW
   sudo ufw disable
   # Test if VPN connects
   # Re-enable after testing
   sudo ufw enable
   ```

### Download Clients Can't Connect

**Issue:** Transmission/NZBGet can't access internet through VPN

**Diagnosis:**

1. **Check VPN connection:**
   ```bash
   # Test from Gluetun container
   docker exec gluetun curl -s ifconfig.me
   ```

2. **Check download client network:**
   ```bash
   # Should show VPN IP, not real IP
   docker exec transmission curl -s ifconfig.me
   docker exec nzbget curl -s ifconfig.me
   ```

**Solutions:**

1. **Restart VPN stack:**
   ```bash
   docker-compose restart gluetun transmission nzbget
   ```

2. **Check container dependencies:**
   ```bash
   # Ensure containers depend on healthy VPN
   # See docker-compose.yml depends_on configuration
   ```

### IP Leak Detection

**Issue:** Downloads using real IP instead of VPN

**Test for leaks:**

```bash
# Your real IP
curl -s ifconfig.me

# VPN IP (should be different)
docker exec gluetun curl -s ifconfig.me

# Download client IPs (should match VPN)
docker exec transmission curl -s ifconfig.me
docker exec nzbget curl -s ifconfig.me
```

**Solutions:**

1. **Check kill switch:**
   ```bash
   # Kill switch should block non-VPN traffic
   docker exec gluetun iptables -L -n
   ```

2. **Recreate VPN containers:**
   ```bash
   docker-compose stop transmission nzbget gluetun
   docker-compose rm -f transmission nzbget gluetun
   docker-compose up -d gluetun
   # Wait for VPN to connect
   docker-compose up -d transmission nzbget
   ```

## Service-Specific Issues

### Sonarr/Radarr Issues

**Issue:** Can't connect to download clients or indexers

**Common Problems:**

1. **Wrong download client URLs:**
   ```
   ❌ Wrong: http://localhost:9091
   ✅ Correct: http://gluetun:9091
   ```

2. **API key issues:**
   ```bash
   # Get API key from config
   docker exec sonarr cat /config/config.xml | grep ApiKey
   ```

3. **Database corruption:**
   ```bash
   # Backup and recreate database
   docker-compose stop sonarr
   cp /opt/media-server/configs/sonarr/sonarr.db /tmp/sonarr.db.backup
   rm /opt/media-server/configs/sonarr/sonarr.db
   docker-compose start sonarr
   ```

### Prowlarr Connection Issues

**Issue:** Can't add applications or sync indexers

**Solutions:**

1. **Check Prowlarr API key:**
   ```bash
   docker logs prowlarr | grep -i "api"
   ```

2. **Verify application URLs:**
   ```
   Sonarr URL: http://sonarr:8989
   Radarr URL: http://radarr:7878
   ```

3. **Reset Prowlarr:**
   ```bash
   docker-compose stop prowlarr
   rm -rf /opt/media-server/configs/prowlarr/*
   docker-compose start prowlarr
   ```

### Transmission Issues

**Issue:** Torrents won't download or WebUI inaccessible

**Common Solutions:**

1. **Check VPN connection:**
   ```bash
   docker exec transmission curl -s ifconfig.me
   ```

2. **Verify settings:**
   ```bash
   docker exec transmission cat /config/settings.json | jq '.["rpc-enabled"]'
   ```

3. **Fix permissions:**
   ```bash
   sudo chown -R 1001:1001 /mnt/artie/downloads
   ```

### NZBGet Issues

**Issue:** Downloads fail or can't connect to newsgroups

**Solutions:**

1. **Check newsgroup server config:**
   ```bash
   docker logs nzbget | grep -i "server"
   ```

2. **Verify download paths:**
   ```bash
   docker exec nzbget ls -la /downloads
   ```

## Network Issues

### Can't Access Web Interfaces

**Issue:** Services not accessible via browser

**Diagnosis:**

1. **Check if services are running:**
   ```bash
   docker-compose ps
   netstat -tlnp | grep -E ':(8989|7878|9696)'
   ```

2. **Test local connectivity:**
   ```bash
   curl -I http://localhost:8989  # Sonarr
   curl -I http://localhost:7878  # Radarr
   ```

**Solutions:**

1. **Check firewall:**
   ```bash
   sudo ufw status
   sudo ufw allow 8989/tcp  # Add missing ports
   ```

2. **Restart network stack:**
   ```bash
   sudo systemctl restart networking
   docker-compose restart
   ```

### Tailscale Issues

**Issue:** Can't connect via Tailscale

**Solutions:**

1. **Check Tailscale status:**
   ```bash
   sudo tailscale status
   sudo tailscale ip -4
   ```

2. **Restart Tailscale:**
   ```bash
   sudo systemctl restart tailscaled
   sudo tailscale up
   ```

### DNS Issues

**Issue:** Services can't resolve domain names

**Solutions:**

1. **Check DNS configuration:**
   ```bash
   docker exec sonarr nslookup google.com
   ```

2. **Update DNS servers:**
   ```bash
   # Edit /etc/systemd/resolved.conf
   [Resolve]
   DNS=1.1.1.1 8.8.8.8
   sudo systemctl restart systemd-resolved
   ```

## Storage Issues

### NFS Mount Failures

**Issue:** Can't mount NAS storage

**Diagnosis:**

1. **Check NFS connectivity:**
   ```bash
   showmount -e nas_server_ip
   ping nas_server_ip
   ```

2. **Test manual mount:**
   ```bash
   sudo mount -t nfs4 nas_server:/path /mnt/test
   ```

**Solutions:**

1. **Install NFS client:**
   ```bash
   sudo apt install nfs-common
   ```

2. **Fix NFS exports on NAS:**
   ```bash
   # On NAS server, check /etc/exports
   /volume1/media *(rw,sync,no_subtree_check,no_root_squash)
   ```

3. **Update fstab:**
   ```bash
   # Correct fstab entry
   nas_server:/volume1/media /mnt/artie nfs4 rw,relatime,_netdev 0 0
   ```

### Permission Issues

**Issue:** Can't write to downloads directory

**Solutions:**

1. **Fix ownership:**
   ```bash
   sudo chown -R 1001:1001 /mnt/artie/downloads
   sudo chmod -R 755 /mnt/artie/downloads
   ```

2. **Check NFS exports:**
   ```bash
   # NAS should allow UID/GID mapping
   # Check NFS export options include: no_root_squash
   ```

### Disk Space Issues

**Issue:** Running out of disk space

**Solutions:**

1. **Check usage:**
   ```bash
   df -h
   du -sh /opt/media-server/*
   du -sh /mnt/artie/*
   ```

2. **Clean up Docker:**
   ```bash
   docker system prune -a --volumes
   ```

3. **Clean up logs:**
   ```bash
   journalctl --vacuum-time=7d
   /opt/media-server/cleanup-disk.sh
   ```

## Performance Issues

### Slow Downloads

**Issue:** Download speeds are slower than expected

**Solutions:**

1. **Check VPN server load:**
   ```bash
   # Try different VPN server
   # Edit docker-compose.yml SERVER_COUNTRIES
   ```

2. **Optimize Transmission settings:**
   ```json
   {
     "peer-limit-global": 300,
     "peer-limit-per-torrent": 60,
     "queue-stalled-minutes": 15,
     "ratio-limit": 2.0
   }
   ```

3. **Check network bottlenecks:**
   ```bash
   iftop  # Monitor network usage
   ```

### High CPU Usage

**Issue:** System using too much CPU

**Diagnosis:**

1. **Check container resources:**
   ```bash
   docker stats
   ```

2. **Identify heavy processes:**
   ```bash
   htop
   ```

**Solutions:**

1. **Limit container resources:**
   ```yaml
   # In docker-compose.yml
   services:
     bazarr:
       deploy:
         resources:
           limits:
             cpus: '0.5'
             memory: 512M
   ```

2. **Reduce concurrent operations:**
   ```bash
   # In service web interfaces:
   # - Reduce simultaneous downloads
   # - Increase check intervals
   # - Disable unnecessary features
   ```

### High Memory Usage

**Issue:** System running out of memory

**Solutions:**

1. **Add swap space:**
   ```bash
   sudo fallocate -l 2G /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile
   echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
   ```

2. **Optimize container memory:**
   ```bash
   # Restart memory-hungry services
   docker-compose restart bazarr sonarr radarr
   ```

## Emergency Recovery

### Complete System Recovery

**Issue:** System is completely broken and needs rebuild

**Recovery Steps:**

1. **Boot from USB/rescue mode**

2. **Mount and backup critical data:**
   ```bash
   mount /dev/sda1 /mnt/recovery
   cp -r /mnt/recovery/opt/media-server/configs /backup/
   ```

3. **Fresh installation:**
   ```bash
   # Reinstall OS
   # Clone automation repository
   git clone https://github.com/your-repo/media-server-automation.git
   cd media-server-automation
   ```

4. **Deploy and restore:**
   ```bash
   sudo ./scripts/bootstrap.sh
   ./scripts/restore-data.sh /backup
   ```

### Rollback to Previous Version

**Issue:** Update broke something, need to rollback

**Steps:**

1. **Stop current services:**
   ```bash
   docker-compose down
   ```

2. **Restore from backup:**
   ```bash
   ./scripts/restore-data.sh /path/to/last-good-backup
   ```

3. **Use specific image versions:**
   ```bash
   # Edit docker-compose.yml to pin versions
   image: linuxserver/sonarr:3.0.8  # Instead of :latest
   ```

## Getting Help

### Log Collection

When asking for help, collect these logs:

```bash
# System info
uname -a > debug_info.txt
docker --version >> debug_info.txt
docker-compose --version >> debug_info.txt

# Service status
docker-compose ps >> debug_info.txt
/opt/media-server/status.sh >> debug_info.txt

# Recent logs
journalctl -n 100 >> debug_info.txt
docker-compose logs --tail=50 >> debug_info.txt
```

### Create GitHub Issue

Include in your issue:

1. **System information** (OS, hardware, Docker version)
2. **Deployment method** (VM test, production, custom config)
3. **Error messages** (exact error text)
4. **Steps to reproduce** (what you did before the error)
5. **Logs** (relevant log excerpts, not entire files)
6. **Configuration** (sanitized config files, no passwords)

### Community Resources

- **Documentation:** Check all markdown files in `docs/`
- **GitHub Issues:** Search existing issues first
- **Docker Hub:** Check service-specific documentation
- **Reddit:** r/selfhosted, r/docker, r/sonarr, etc.

Most issues can be resolved by following this troubleshooting guide systematically. Start with the general steps and work your way to specific issues. Remember to always backup your configuration before making major changes! 🛠️