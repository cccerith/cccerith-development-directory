# Contributing to Media Server Automation

First off, thanks for taking the time to contribute! ❤️

This project aims to be the definitive open-source solution for automated media server deployment. We welcome contributions of all kinds.

## 🎯 Ways to Contribute

### 🐛 Reporting Bugs
- Use the [Bug Report template](.github/ISSUE_TEMPLATE/bug_report.yml)
- Include system information (OS, Docker version, etc.)
- Provide detailed steps to reproduce
- Include relevant logs (sanitized of sensitive data)

### ✨ Suggesting Features
- Use the [Feature Request template](.github/ISSUE_TEMPLATE/feature_request.yml)
- Explain the use case and benefit
- Consider implementation complexity
- Check for existing similar requests

### 📝 Improving Documentation
- Fix typos, unclear instructions, or outdated information
- Add examples and use cases
- Improve troubleshooting guides
- Translate documentation (future)

### 💻 Code Contributions
- Bug fixes
- New features (discuss in issues first)
- Performance improvements
- Additional VPN providers
- New service integrations
- Testing and validation

## 🚀 Development Setup

### Prerequisites
- Ubuntu 20.04+ or Debian 11+
- Git
- Docker & Docker Compose
- Vagrant + VirtualBox (for testing)

### Local Development

1. **Fork and Clone**
   ```bash
   git clone https://github.com/your-username/media-server-automation.git
   cd media-server-automation
   ```

2. **Set Up Testing Environment**
   ```bash
   cd vm-testing
   vagrant up
   vagrant ssh
   ```

3. **Test Your Changes**
   ```bash
   cd media-server-automation
   # Test individual components
   ansible-playbook --syntax-check ansible/playbooks/*.yml
   docker-compose -f docker/docker-compose.yml config
   
   # Full deployment test
   sudo ./scripts/bootstrap.sh --environment development --dry-run
   ```

4. **Make Changes**
   - Follow existing code style
   - Update documentation
   - Add/update tests
   - Ensure no sensitive data

5. **Submit Pull Request**
   - Use descriptive commit messages
   - Reference relevant issues
   - Include testing information

## 📋 Pull Request Process

1. **Before Starting**
   - Check existing issues and PRs
   - Discuss major changes in issues first
   - Ensure your idea aligns with project goals

2. **Development Guidelines**
   - **Ansible**: Follow YAML best practices, use meaningful variable names
   - **Docker**: Use official images when possible, optimize for security
   - **Scripts**: Include proper error handling and logging
   - **Documentation**: Update relevant docs with changes

3. **Testing Requirements**
   - Test in VM environment first
   - Verify on clean Ubuntu/Debian installation
   - Ensure backward compatibility
   - Test rollback scenarios

4. **Commit Guidelines**
   ```
   type(scope): brief description
   
   Detailed explanation of what was changed and why.
   
   Fixes #issue-number
   ```
   
   Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

5. **PR Checklist**
   - [ ] Code follows project style
   - [ ] Self-review completed
   - [ ] Documentation updated
   - [ ] Tests pass
   - [ ] No sensitive data included
   - [ ] Backward compatibility maintained

## 🏛️ Code Style Guidelines

### Ansible
```yaml
# Good
- name: Install essential packages
  apt:
    name:
      - curl
      - wget
      - git
    state: present

# Use descriptive task names
# Group related tasks
# Use proper YAML indentation (2 spaces)
```

### Shell Scripts
```bash
#!/bin/bash
set -euo pipefail  # Always use strict mode

# Use descriptive function names
log_info() {
    echo "[INFO] $*"
}

# Include proper error handling
if ! command -v docker >/dev/null 2>&1; then
    log_error "Docker not found"
    exit 1
fi
```

### Docker Compose
```yaml
# Use specific image versions when possible
image: lscr.io/linuxserver/sonarr:latest

# Include health checks
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8989"]
  interval: 30s
  timeout: 10s
  retries: 3

# Use meaningful service names
# Include proper volume mappings
# Set appropriate restart policies
```

## 🔒 Security Guidelines

### Never Commit Sensitive Data
- Passwords, API keys, tokens
- Real IP addresses or domain names
- Personal information
- VPN configuration files with credentials

### Use Template Files
```bash
# Good: .env.template
PROTON_USER=your_protonvpn_username
PROTON_PASS=your_protonvpn_password

# Bad: .env (actual credentials)
PROTON_USER=real_username
PROTON_PASS=real_password
```

### Security Testing
- Test with minimal permissions
- Verify firewall rules
- Test VPN kill switch functionality
- Validate input sanitization

## 🧪 Testing

### VM Testing
```bash
# Always test in clean VM first
cd vm-testing
vagrant destroy -f && vagrant up
vagrant ssh

# Test full deployment
sudo ./scripts/bootstrap.sh --environment development

# Test specific components
ansible-playbook ansible/playbooks/01-system-base.yml --check
```

### Integration Testing
- Test service connectivity
- Verify VPN routing
- Test backup/restore functionality
- Validate monitoring and health checks

## 📚 Documentation Standards

### Code Comments
- Explain **why**, not **what**
- Use meaningful variable names
- Include examples for complex sections

### README Updates
- Keep installation steps current
- Update feature lists
- Maintain compatibility information

### Changelog
- Follow [Keep a Changelog](https://keepachangelog.com/) format
- Include breaking changes
- Reference issue numbers

## 🎭 Community Guidelines

### Be Respectful
- Use inclusive language
- Be patient with newcomers
- Provide constructive feedback
- Assume positive intent

### Be Helpful
- Answer questions when possible
- Share knowledge and experience
- Help newcomers get started
- Provide detailed feedback on issues/PRs

### Be Professional
- Keep discussions on-topic
- Avoid flame wars and bikeshedding
- Focus on technical merit
- Respect different opinions and approaches

## 🏷️ Issue and PR Labels

### Type Labels
- `bug`: Something isn't working
- `feature`: New feature request
- `documentation`: Documentation improvements
- `enhancement`: Improvement to existing feature

### Priority Labels
- `critical`: Security issues, data loss, service down
- `high`: Major functionality broken
- `medium`: Minor issues, feature requests
- `low`: Nice-to-have improvements

### Status Labels
- `needs-review`: Ready for maintainer review
- `needs-testing`: Needs community testing
- `needs-info`: More information required
- `work-in-progress`: Active development

## 🎉 Recognition

Contributors are recognized in:
- README.md contributor section
- CHANGELOG.md release notes
- GitHub repository insights
- Special mentions for significant contributions

## 📞 Getting Help

### Community Support
- GitHub Discussions for questions
- Issues for bug reports and features
- Discord (coming soon) for real-time chat

### Maintainer Contact
- Create an issue for bugs/features
- Use discussions for general questions
- Tag maintainers in PRs when ready for review

## 🚀 Release Process

1. **Version Planning**: Discuss in issues
2. **Development**: PRs merged to main
3. **Testing**: Community testing period
4. **Documentation**: Update all docs
5. **Release**: Tagged release with changelog
6. **Announcement**: Community notification

---

Thank you for contributing to making media server automation accessible to everyone! 🎬✨

**Happy Contributing!** 🚀