#!/bin/bash

# Project Summary Script
# Displays overview of the media server automation project

VERSION="1.0.0"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo
echo "========================================================"
echo "🎬 Media Server Automation - Project Summary v${VERSION}"
echo "========================================================"
echo

# Project structure
echo -e "${BLUE}📁 Project Structure:${NC}"
echo
tree "$PROJECT_DIR" -I '__pycache__|*.pyc|.git' -a -L 3 2>/dev/null || {
    find "$PROJECT_DIR" -type d | head -20 | sed 's|[^/]*/|  |g'
}
echo

# File counts
echo -e "${BLUE}📊 Component Summary:${NC}"
echo
echo "Ansible Playbooks: $(find "$PROJECT_DIR/ansible/playbooks" -name "*.yml" | wc -l)"
echo "Docker Services: $(grep -c 'image:' "$PROJECT_DIR/docker/docker-compose.yml" 2>/dev/null || echo "0")"
echo "Scripts: $(find "$PROJECT_DIR/scripts" -name "*.sh" | wc -l)"
echo "Documentation: $(find "$PROJECT_DIR/docs" -name "*.md" | wc -l)"
echo

# Services overview
echo -e "${BLUE}🐳 Docker Services:${NC}"
echo
if [[ -f "$PROJECT_DIR/docker/docker-compose.yml" ]]; then
    grep -E "^\s+[a-z-]+:" "$PROJECT_DIR/docker/docker-compose.yml" | \
    sed 's/://' | sed 's/^[ ]*/  • /' | head -15
else
    echo "  • Docker Compose file not found"
fi
echo

# Features
echo -e "${BLUE}✨ Key Features:${NC}"
echo
cat << 'EOF'
  🔐 VPN Protection
    • Transmission & NZBGet routed through VPN
    • Kill switch prevents IP leaks
    • Support for ProtonVPN + 60+ providers

  🎯 Complete Media Stack
    • Sonarr (TV), Radarr (Movies), Prowlarr (Indexers)
    • Bazarr (Subtitles), Overseerr (Requests)
    • Automated downloads with VPN protection

  🛡️ Security & Monitoring
    • UFW firewall, Fail2ban protection
    • Tailscale secure remote access
    • Health checks & automated backups
    • Performance monitoring

  🚀 One-Command Deployment
    • Complete setup in ~30 minutes
    • VM testing environment included
    • Backup/restore existing systems
    • Idempotent automation
EOF
echo

# Quick start
echo -e "${BLUE}🚀 Quick Start Commands:${NC}"
echo
echo -e "${GREEN}# Test in VM:${NC}"
echo "cd vm-testing && vagrant up && vagrant ssh"
echo "cd media-server-automation && sudo ./scripts/bootstrap.sh --environment development"
echo
echo -e "${GREEN}# Deploy to Production:${NC}"
echo "sudo ./scripts/bootstrap.sh"
echo
echo -e "${GREEN}# Backup Current System:${NC}"
echo "./scripts/backup-current.sh --nas-backup"
echo
echo -e "${GREEN}# Restore from Backup:${NC}"
echo "./scripts/restore-data.sh /path/to/backup"
echo

# URLs after deployment
echo -e "${BLUE}🌐 Service URLs (after deployment):${NC}"
echo
cat << 'EOF'
  • Overseerr:    http://server:5055  (Request management)
  • Sonarr:       http://server:8989  (TV shows)
  • Radarr:       http://server:7878  (Movies)  
  • Prowlarr:     http://server:9696  (Indexers)
  • Bazarr:       http://server:6767  (Subtitles)
  • Transmission: http://server:9091  (BitTorrent)
  • NZBGet:       http://server:6789  (Usenet)
EOF
echo

# Architecture
echo -e "${BLUE}🏗️ Architecture Overview:${NC}"
echo
cat << 'EOF'
  ┌─────────────────────────────────────────────────────────┐
  │                    Internet                             │
  └─────────────────────┬───────────────────────────────────┘
                        │
  ┌─────────────────────▼───────────────────────────────────┐
  │                VPN Provider                             │
  │              (ProtonVPN, etc.)                         │
  └─────────────────────┬───────────────────────────────────┘
                        │
  ┌─────────────────────▼───────────────────────────────────┐
  │              Gluetun Container                          │
  │                (VPN Client)                            │
  └─────────┬───────────────────────┬─────────────────────────┘
            │                       │
  ┌─────────▼──────────┐   ┌────────▼──────────┐
  │   Transmission     │   │     NZBGet        │
  │   (BitTorrent)     │   │    (Usenet)       │
  └─────────┬──────────┘   └────────┬──────────┘
            │                       │
            └─────────┬───────────────┘
                      │
  ┌─────────────────────▼───────────────────────────────────┐
  │                 Downloads                               │
  │              (/mnt/artie/downloads)                    │
  └─────────────────────┬───────────────────────────────────┘
                        │
  ┌─────────────────────▼───────────────────────────────────┐
  │         Sonarr  │  Radarr  │  Prowlarr  │  Bazarr      │
  │         (TV)    │ (Movies) │(Indexers)  │(Subtitles)   │
  └─────────────────────┬───────────────────────────────────┘
                        │
  ┌─────────────────────▼───────────────────────────────────┐
  │                  Overseerr                              │
  │              (Request Management)                       │
  └─────────────────────────────────────────────────────────┘

  Key Benefits:
  • Download clients ALWAYS use VPN (kill switch protection)
  • Management apps use local network (better performance)
  • Complete automation with one command deployment
  • Enterprise-grade security and monitoring
EOF
echo

echo -e "${BLUE}📚 Documentation:${NC}"
echo
echo "  • README.md           - Project overview & quick start"
echo "  • docs/DEPLOYMENT.md  - Complete deployment guide"  
echo "  • docs/TROUBLESHOOTING.md - Issue resolution guide"
echo

echo -e "${BLUE}🎯 Next Steps:${NC}"
echo
echo "1. 🧪 Test deployment in VM: cd vm-testing && vagrant up"
echo "2. 💾 Backup current system: ./scripts/backup-current.sh"
echo "3. 🚀 Deploy to production: sudo ./scripts/bootstrap.sh"
echo "4. 🔧 Configure services via web interfaces"
echo "5. ✅ Verify VPN protection is working"
echo

echo "========================================================"
echo "🎉 Ready to build your automated media server!"
echo "   Start with: sudo ./scripts/bootstrap.sh"
echo "========================================================"
echo