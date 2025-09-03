#!/bin/bash
# ===============================================
# SERVARR CONFIGURATION BACKUP & MIGRATION TOOL
# ===============================================
# Backs up existing native Servarr installations and creates 
# sanitized templates for Docker migration
# ===============================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_DIR/backups/native-configs"
TEMPLATES_DIR="$PROJECT_DIR/docker/config-templates"
LOGS_DIR="$PROJECT_DIR/logs"

# Create directories
mkdir -p "$BACKUP_DIR" "$TEMPLATES_DIR" "$LOGS_DIR"

# Logging
LOG_FILE="$LOGS_DIR/servarr-backup-$(date +%Y%m%d-%H%M%S).log"

log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE"
}

log_info() {
    log "${BLUE}[INFO]${NC} $*"
}

log_success() {
    log "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    log "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    log "${RED}[ERROR]${NC} $*"
}

# Application configurations
declare -A APPS
APPS[sonarr]="/var/lib/sonarr"
APPS[radarr]="/var/lib/radarr" 
APPS[prowlarr]="/var/lib/prowlarr"
APPS[bazarr]="/var/lib/bazarr"
APPS[overseerr]="/var/lib/overseerr"
APPS[transmission]="/var/lib/transmission-daemon/.config/transmission-daemon"
APPS[nzbget]="/opt/nzbget"

# Sensitive data patterns to sanitize
SENSITIVE_PATTERNS=(
    "ApiKey"
    "apiKey" 
    "api_key"
    "Password"
    "password"
    "Secret"
    "secret"
    "Token"
    "token"
    "Auth"
    "auth"
    "username.*=.*"
    "Username.*=.*"
    "rpc-password"
    "rpc-username"
    "ControlPassword"
    "ControlUsername"
)

print_header() {
    echo -e "${BLUE}"
    echo "==============================================="
    echo " SERVARR CONFIGURATION BACKUP & MIGRATION"
    echo "==============================================="
    echo -e "${NC}"
    echo "This tool will:"
    echo "• Backup existing native Servarr configurations"
    echo "• Create sanitized templates for Docker migration"
    echo "• Generate migration reports and documentation"
    echo ""
}

check_dependencies() {
    log_info "Checking dependencies..."
    
    local missing_deps=()
    
    for cmd in sqlite3 jq python3; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -ne 0 ]]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        echo "Please install missing dependencies:"
        echo "  sudo apt install sqlite3 jq python3"
        exit 1
    fi
    
    log_success "All dependencies found"
}

check_running_services() {
    log_info "Checking for running Servarr services..."
    
    local running_services=()
    
    for app in "${!APPS[@]}"; do
        if systemctl is-active --quiet "${app}.service" 2>/dev/null; then
            running_services+=("$app")
        fi
    done
    
    if [[ ${#running_services[@]} -gt 0 ]]; then
        log_warning "Found running services: ${running_services[*]}"
        echo -e "${YELLOW}It's recommended to stop services during backup to ensure consistency.${NC}"
        read -p "Stop services and continue? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for service in "${running_services[@]}"; do
                log_info "Stopping $service..."
                sudo systemctl stop "$service.service"
            done
        else
            log_warning "Continuing with running services (backup may be inconsistent)"
        fi
    else
        log_info "No running Servarr services found"
    fi
}

backup_app_config() {
    local app="$1"
    local source_dir="$2"
    local backup_app_dir="$BACKUP_DIR/$app"
    
    log_info "Backing up $app configuration..."
    
    if [[ ! -d "$source_dir" ]]; then
        log_warning "$app config directory not found: $source_dir"
        return 1
    fi
    
    # Create backup directory
    mkdir -p "$backup_app_dir"
    
    # Copy all configuration files
    if sudo cp -r "$source_dir"/* "$backup_app_dir/" 2>/dev/null; then
        # Fix permissions
        sudo chown -R "$(whoami):$(whoami)" "$backup_app_dir"
        log_success "Backed up $app configuration"
        
        # Get size information
        local size
        size=$(du -sh "$backup_app_dir" | cut -f1)
        echo "  Size: $size"
        
        # Count important files
        local db_count
        local config_count
        db_count=$(find "$backup_app_dir" -name "*.db" | wc -l)
        config_count=$(find "$backup_app_dir" -name "*.xml" -o -name "*.json" -o -name "*.conf" | wc -l)
        echo "  Database files: $db_count"
        echo "  Config files: $config_count"
        
        return 0
    else
        log_error "Failed to backup $app configuration"
        return 1
    fi
}

analyze_sensitive_data() {
    local app="$1"
    local backup_dir="$BACKUP_DIR/$app"
    local analysis_file="$backup_dir/sensitive-data-analysis.txt"
    
    log_info "Analyzing sensitive data in $app..."
    
    {
        echo "SENSITIVE DATA ANALYSIS FOR $app"
        echo "Generated: $(date)"
        echo "======================================="
        echo
        
        # Check database files for sensitive data
        echo "DATABASE ANALYSIS:"
        echo "=================="
        
        while IFS= read -r -d '' db_file; do
            echo "File: $(basename "$db_file")"
            echo "---"
            
            # Get table list
            if tables=$(sqlite3 "$db_file" ".tables" 2>/dev/null); then
                echo "Tables: $tables"
                
                # Check for sensitive columns
                for table in $tables; do
                    if schema=$(sqlite3 "$db_file" ".schema $table" 2>/dev/null); then
                        echo "Schema for $table:"
                        echo "$schema" | grep -iE "(api|key|password|secret|token|auth)" || echo "  No sensitive columns detected"
                    fi
                done
            else
                echo "  Could not read database"
            fi
            echo
        done < <(find "$backup_dir" -name "*.db" -print0)
        
        # Check config files for sensitive data
        echo "CONFIG FILE ANALYSIS:"
        echo "===================="
        
        while IFS= read -r -d '' config_file; do
            echo "File: $(basename "$config_file")"
            echo "---"
            
            local sensitive_found=false
            for pattern in "${SENSITIVE_PATTERNS[@]}"; do
                if grep -iE "$pattern" "$config_file" >/dev/null 2>&1; then
                    echo "  Found pattern: $pattern"
                    sensitive_found=true
                fi
            done
            
            if [[ "$sensitive_found" == "false" ]]; then
                echo "  No sensitive patterns detected"
            fi
            echo
        done < <(find "$backup_dir" -name "*.xml" -o -name "*.json" -o -name "*.conf" -print0)
        
    } > "$analysis_file"
    
    log_success "Sensitive data analysis saved to: $analysis_file"
}

create_sanitized_template() {
    local app="$1"
    local backup_dir="$BACKUP_DIR/$app"
    local template_dir="$TEMPLATES_DIR/$app"
    
    log_info "Creating sanitized template for $app..."
    
    mkdir -p "$template_dir"
    
    # Copy all files to template directory
    cp -r "$backup_dir"/* "$template_dir/"
    
    # Remove the analysis file from template
    rm -f "$template_dir/sensitive-data-analysis.txt"
    
    # Sanitize database files
    while IFS= read -r -d '' db_file; do
        log_info "Sanitizing database: $(basename "$db_file")"
        
        # Create sanitization SQL script
        local sanitize_sql="$template_dir/sanitize_$(basename "$db_file" .db).sql"
        
        {
            echo "-- Sanitization script for $(basename "$db_file")"
            echo "-- Remove sensitive data and replace with placeholders"
            echo
            
            # Get table list and generate sanitization queries
            if tables=$(sqlite3 "$db_file" ".tables" 2>/dev/null); then
                for table in $tables; do
                    echo "-- Sanitize $table table"
                    
                    # Common sensitive columns to sanitize
                    sqlite3 "$db_file" "PRAGMA table_info($table);" | while IFS='|' read -r _ name type _ _ _; do
                        case "$name" in
                            *[Aa]pi[Kk]ey*|*[Pp]assword*|*[Ss]ecret*|*[Tt]oken*|*[Aa]uth*)
                                echo "UPDATE $table SET $name = 'PLACEHOLDER_${name^^}' WHERE $name IS NOT NULL;"
                                ;;
                        esac
                    done
                done
            fi
        } > "$sanitize_sql"
        
        # Apply sanitization
        if sqlite3 "$db_file" < "$sanitize_sql" 2>/dev/null; then
            log_success "Sanitized database: $(basename "$db_file")"
        else
            log_warning "Could not sanitize database: $(basename "$db_file")"
        fi
        
    done < <(find "$template_dir" -name "*.db" -print0)
    
    # Sanitize config files
    while IFS= read -r -d '' config_file; do
        log_info "Sanitizing config file: $(basename "$config_file")"
        
        # Create backup of original
        cp "$config_file" "$config_file.original"
        
        # Apply sanitization patterns
        for pattern in "${SENSITIVE_PATTERNS[@]}"; do
            if [[ "$pattern" == *"="* ]]; then
                # Handle key=value patterns
                sed -i -E "s/($pattern)([^<>\n]*)/\1PLACEHOLDER_VALUE/gi" "$config_file"
            else
                # Handle standalone patterns
                sed -i -E "s/($pattern[\"']?[[:space:]]*[:=][[:space:]]*[\"']?)([^<>\"\n']*)/\1PLACEHOLDER_${pattern^^}/gi" "$config_file"
            fi
        done
        
        log_success "Sanitized config file: $(basename "$config_file")"
        
    done < <(find "$template_dir" -name "*.xml" -o -name "*.json" -o -name "*.conf" -print0)
    
    # Create template documentation
    cat > "$template_dir/README.md" << EOF
# $app Configuration Template

This template was generated from a native $app installation.

## Sanitization Applied

- API keys replaced with PLACEHOLDER_APIKEY
- Passwords replaced with PLACEHOLDER_PASSWORD  
- Secrets replaced with PLACEHOLDER_SECRET
- Tokens replaced with PLACEHOLDER_TOKEN
- Auth credentials replaced with PLACEHOLDER_AUTH

## Before Using This Template

1. Replace all placeholder values with your actual credentials
2. Update any hardcoded paths to match your Docker setup
3. Review database entries for any missed sensitive data
4. Test the configuration in a development environment first

## Files Included

$(find "$template_dir" -type f -name "*.db" -o -name "*.xml" -o -name "*.json" -o -name "*.conf" | sed 's|'"$template_dir"'/||' | sort)

## Generated

- Date: $(date)
- Source: $backup_dir
- Sanitization: Applied
EOF
    
    log_success "Created sanitized template: $template_dir"
}

generate_migration_report() {
    log_info "Generating migration report..."
    
    local report_file="$BACKUP_DIR/migration-report.md"
    
    {
        echo "# Servarr Configuration Migration Report"
        echo
        echo "Generated: $(date)"
        echo "Host: $(hostname)"
        echo "User: $(whoami)"
        echo
        echo "## Summary"
        echo
        
        local total_apps=0
        local successful_backups=0
        
        for app in "${!APPS[@]}"; do
            total_apps=$((total_apps + 1))
            if [[ -d "$BACKUP_DIR/$app" ]]; then
                successful_backups=$((successful_backups + 1))
            fi
        done
        
        echo "- Total applications scanned: $total_apps"
        echo "- Successful backups: $successful_backups"
        echo "- Failed backups: $((total_apps - successful_backups))"
        echo
        echo "## Application Details"
        echo
        
        for app in "${!APPS[@]}"; do
            echo "### $app"
            echo
            if [[ -d "$BACKUP_DIR/$app" ]]; then
                echo "- ✅ **Status**: Successfully backed up"
                echo "- 📁 **Source**: ${APPS[$app]}"
                echo "- 💾 **Backup**: $BACKUP_DIR/$app"
                echo "- 🧹 **Template**: $TEMPLATES_DIR/$app"
                
                local size
                size=$(du -sh "$BACKUP_DIR/$app" 2>/dev/null | cut -f1 || echo "Unknown")
                echo "- 📊 **Size**: $size"
                
                local db_count config_count
                db_count=$(find "$BACKUP_DIR/$app" -name "*.db" 2>/dev/null | wc -l)
                config_count=$(find "$BACKUP_DIR/$app" -name "*.xml" -o -name "*.json" -o -name "*.conf" 2>/dev/null | wc -l)
                echo "- 🗃️ **Database files**: $db_count"
                echo "- ⚙️ **Config files**: $config_count"
                
                if [[ -f "$BACKUP_DIR/$app/sensitive-data-analysis.txt" ]]; then
                    echo "- 🔍 **Security analysis**: Available"
                fi
                
                echo "- 🐳 **Docker ready**: $([ -d "$TEMPLATES_DIR/$app" ] && echo "Yes" || echo "No")"
            else
                echo "- ❌ **Status**: Backup failed or directory not found"
                echo "- 📁 **Source**: ${APPS[$app]} (not accessible)"
            fi
            echo
        done
        
        echo "## Next Steps"
        echo
        echo "1. **Review sensitive data analysis** for each application"
        echo "2. **Customize Docker templates** with your credentials"
        echo "3. **Test Docker deployment** in development environment"
        echo "4. **Migrate to production** using the provided templates"
        echo
        echo "## Files Generated"
        echo
        echo "### Backups"
        find "$BACKUP_DIR" -type f -name "*.db" -o -name "*.xml" -o -name "*.json" -o -name "*.conf" | sed 's|'"$BACKUP_DIR"'/|- |'
        echo
        echo "### Templates"
        find "$TEMPLATES_DIR" -type f -name "*.db" -o -name "*.xml" -o -name "*.json" -o -name "*.conf" | sed 's|'"$TEMPLATES_DIR"'/|- |'
        echo
        
    } > "$report_file"
    
    log_success "Migration report generated: $report_file"
}

restart_stopped_services() {
    log_info "Restarting previously stopped services..."
    
    for app in "${!APPS[@]}"; do
        if systemctl is-enabled --quiet "${app}.service" 2>/dev/null; then
            log_info "Starting $app service..."
            if sudo systemctl start "$app.service"; then
                log_success "Started $app"
            else
                log_error "Failed to start $app"
            fi
        fi
    done
}

main() {
    print_header
    
    log_info "Starting Servarr configuration backup..."
    
    # Pre-flight checks
    check_dependencies
    check_running_services
    
    # Backup all applications
    local successful_backups=0
    for app in "${!APPS[@]}"; do
        if backup_app_config "$app" "${APPS[$app]}"; then
            analyze_sensitive_data "$app"
            create_sanitized_template "$app"
            successful_backups=$((successful_backups + 1))
        fi
        echo
    done
    
    # Generate summary report
    generate_migration_report
    
    # Restart services if needed
    restart_stopped_services
    
    # Final summary
    echo -e "${GREEN}"
    echo "==============================================="
    echo " BACKUP COMPLETED SUCCESSFULLY"
    echo "==============================================="
    echo -e "${NC}"
    echo "📊 Summary:"
    echo "  • Successful backups: $successful_backups/${#APPS[@]}"
    echo "  • Backups location: $BACKUP_DIR"
    echo "  • Templates location: $TEMPLATES_DIR"
    echo "  • Migration report: $BACKUP_DIR/migration-report.md"
    echo "  • Logs: $LOG_FILE"
    echo
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Review the migration report and sensitive data analysis"
    echo "2. Customize the Docker templates with your credentials"
    echo "3. Test the Docker deployment using: cd docker && docker-compose up -d"
    echo
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi