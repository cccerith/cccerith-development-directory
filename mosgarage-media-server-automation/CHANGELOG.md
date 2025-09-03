# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial project structure and documentation

## [1.0.0] - 2024-08-10

### Added
- 🎬 Complete Infrastructure as Code solution for media server automation
- 🐳 Docker Compose stack with 11+ services
- 🔒 VPN-protected download clients (Transmission & NZBGet via Gluetun)
- 📺 Full Servarr stack (Sonarr, Radarr, Prowlarr, Bazarr)
- 🎯 Overseerr for request management
- 🤖 One-command deployment with Ansible automation
- 🛡️ Enterprise security (UFW firewall, Fail2ban, automatic updates)
- 🧪 VM testing environment with Vagrant
- 💾 Comprehensive backup and restore system
- 📊 Built-in monitoring and health checks
- 📚 Extensive documentation and troubleshooting guides

### Security
- VPN kill switch prevents IP leaks
- Services run as non-root user (UID 1001)
- Network segmentation via Docker
- Automatic security updates
- Tailscale integration for secure remote access

### Infrastructure
- 5 Ansible playbooks for complete system automation
- Ubuntu 20.04+ and Debian 11+ support
- NFS storage integration
- Automated log rotation and cleanup
- Service monitoring and auto-restart

### Documentation
- Complete deployment guide
- Comprehensive troubleshooting manual
- Architecture documentation
- Contributing guidelines
- Security best practices

[Unreleased]: https://github.com/username/media-server-automation/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/username/media-server-automation/releases/tag/v1.0.0