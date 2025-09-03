# 🛠️ Scripts Directory

Comprehensive automation scripts for media server deployment and management.

## 🚀 Main Deployment Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| **bootstrap.sh** | Main deployment script | `sudo ./bootstrap.sh` |
| **backup-current.sh** | Backup existing system | `./backup-current.sh` |
| **restore-data.sh** | Restore from backup | `./restore-data.sh /path/to/backup` |

## 🔧 Configuration Management

| Script | Purpose | Usage |
|--------|---------|-------|
| **extract-api-keys.sh** | Extract/generate API keys | `./extract-api-keys.sh` |
| **configure-integrations.sh** | Setup service integrations | `./configure-integrations.sh` |
| **backup-servarr-configs.sh** | Backup Servarr configurations | `./backup-servarr-configs.sh` |
| **sanitize-servarr-configs.py** | Remove secrets from configs | `./sanitize-servarr-configs.py` |

## 🧪 Testing Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| **test-suite.sh** | Comprehensive test suite | `./test-suite.sh` |
| **quick-test.sh** | Quick local testing | `./quick-test.sh` |
| **validate-deployment.sh** | End-to-end validation | `./validate-deployment.sh` |
| **setup-test-data.sh** | Create mock test data | `./setup-test-data.sh` |
| **test-full-system.sh** | Full system container test | `./test-full-system.sh` |

## 🔧 Utility Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| **generate-docker-templates.sh** | Generate Docker configurations | `./generate-docker-templates.sh` |
| **validate-migration.sh** | Validate migration readiness | `./validate-migration.sh` |
| **project-summary.sh** | Generate project summary | `./project-summary.sh` |
| **init-container.sh** | Initialize Docker environment | `./init-container.sh` |
| **install-virtualbox.sh** | Install VirtualBox/Vagrant | `sudo ./install-virtualbox.sh` |

## 📋 Common Workflows

### 🏗️ Fresh Server Deployment
```bash
# 1. Deploy complete automation
sudo ./bootstrap.sh

# 2. Validate deployment
./validate-deployment.sh

# 3. Configure integrations
./configure-integrations.sh
```

### 🔄 Migration from Native
```bash
# 1. Backup current system
./backup-current.sh --full

# 2. Deploy Docker stack
sudo ./bootstrap.sh

# 3. Restore configurations
./restore-data.sh /path/to/backup
```

### 🧪 Testing Before Production
```bash
# 1. Setup test environment
./setup-test-data.sh

# 2. Run comprehensive tests
./test-suite.sh

# 3. Validate everything works
./validate-deployment.sh
```

### 🔑 API Key Management
```bash
# 1. Extract existing keys
./extract-api-keys.sh

# 2. Configure service integration
./configure-integrations.sh

# 3. Validate API connectivity
./validate-deployment.sh
```

## 🎯 Script Categories

### **Core Automation** (Required)
- `bootstrap.sh` - Main deployment
- `backup-current.sh` - System backup
- `restore-data.sh` - Data restoration

### **Configuration** (Essential)
- `extract-api-keys.sh` - API key management
- `configure-integrations.sh` - Service setup
- `backup-servarr-configs.sh` - Config backup

### **Testing** (Recommended)
- `test-suite.sh` - Full testing
- `validate-deployment.sh` - Validation
- `quick-test.sh` - Local testing

### **Utilities** (Optional)
- `generate-docker-templates.sh` - Template generation
- `project-summary.sh` - Documentation
- `install-virtualbox.sh` - VM setup

## 📖 Help and Documentation

All scripts support `--help` flag:
```bash
./bootstrap.sh --help
./test-suite.sh --help
./validate-deployment.sh --help
```

## 🔒 Security Notes

- Scripts handle sensitive data (API keys, passwords)
- Always review generated configurations before use
- Backup files contain sensitive information
- Use proper file permissions (600 for sensitive files)

## 📊 Script Dependencies

```
bootstrap.sh
├── extract-api-keys.sh
├── configure-integrations.sh
└── validate-deployment.sh

test-suite.sh
├── setup-test-data.sh
├── extract-api-keys.sh
└── validate-deployment.sh
```

---

**🎯 Start with `./bootstrap.sh` for complete automation or `./test-suite.sh` for testing!**