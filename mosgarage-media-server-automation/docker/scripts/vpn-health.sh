#!/bin/sh
# ===============================================
# VPN HEALTH MONITOR SCRIPT
# ===============================================
# Monitors VPN connection and restarts Gluetun if issues are detected
# ===============================================

# Configuration
CHECK_INTERVAL=${VPN_CHECK_INTERVAL:-60}
RESTART_THRESHOLD=${VPN_RESTART_THRESHOLD:-3}
MAX_RESTARTS=5
LOG_PREFIX="[VPN-MONITOR]"

# State tracking
failure_count=0
restart_count=0
last_ip=""

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_PREFIX $*"
}

check_vpn_health() {
    local health_status
    health_status=$(wget -qO- --timeout=10 http://gluetun:8000/v1/openvpn/status 2>/dev/null)
    
    if [ $? -eq 0 ] && echo "$health_status" | grep -q '"status":"running"'; then
        return 0
    else
        return 1
    fi
}

check_external_ip() {
    local current_ip
    current_ip=$(wget -qO- --timeout=10 http://ipinfo.io/ip 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$current_ip" ]; then
        if [ "$current_ip" != "$last_ip" ]; then
            log "External IP: $current_ip"
            last_ip="$current_ip"
        fi
        return 0
    else
        return 1
    fi
}

check_dns_resolution() {
    if nslookup google.com 8.8.8.8 >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

restart_vpn() {
    log "Attempting to restart VPN (attempt $((restart_count + 1))/$MAX_RESTARTS)"
    
    # Send restart signal to gluetun container
    if wget -qO- --post-data='' http://gluetun:8000/v1/openvpn/actions/restart >/dev/null 2>&1; then
        log "VPN restart signal sent successfully"
        restart_count=$((restart_count + 1))
        failure_count=0
        
        # Wait for VPN to stabilize
        sleep 30
        return 0
    else
        log "Failed to send VPN restart signal"
        return 1
    fi
}

main() {
    log "VPN Health Monitor started (check interval: ${CHECK_INTERVAL}s)"
    log "Restart threshold: $RESTART_THRESHOLD failures"
    
    while true; do
        local vpn_healthy=true
        local issues=""
        
        # Check VPN service health
        if ! check_vpn_health; then
            vpn_healthy=false
            issues="$issues VPN-service-down"
        fi
        
        # Check external connectivity
        if ! check_external_ip; then
            vpn_healthy=false
            issues="$issues external-connectivity"
        fi
        
        # Check DNS resolution
        if ! check_dns_resolution; then
            vpn_healthy=false
            issues="$issues DNS-resolution"
        fi
        
        if [ "$vpn_healthy" = true ]; then
            if [ $failure_count -gt 0 ]; then
                log "VPN health restored after $failure_count failures"
                failure_count=0
            fi
        else
            failure_count=$((failure_count + 1))
            log "VPN health check failed (attempt $failure_count/$RESTART_THRESHOLD): $issues"
            
            if [ $failure_count -ge $RESTART_THRESHOLD ]; then
                if [ $restart_count -lt $MAX_RESTARTS ]; then
                    restart_vpn
                else
                    log "ERROR: Maximum restart attempts reached ($MAX_RESTARTS). Manual intervention required."
                    # Continue monitoring but don't attempt more restarts
                fi
            fi
        fi
        
        sleep $CHECK_INTERVAL
    done
}

# Handle signals gracefully
trap 'log "VPN Health Monitor shutting down"; exit 0' TERM INT

# Start monitoring
main