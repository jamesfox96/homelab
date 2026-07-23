#!/usr/bin/env bash

# Replace with your gluetun and qbittorrent container names.
GLUETUN_CONTAINER="gluetun"
QBIT_CONTAINER="qbittorrent" 

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

log_success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

log_error() {
    echo -e "${RED}ERROR: $1${NC}"
}

# --- 1. Verify Container States ---
if ! docker ps --format '{{.Names}}' | grep -Eq "^${GLUETUN_CONTAINER}$"; then
    log_error "Container '${GLUETUN_CONTAINER}' is not running." >&2
    exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -Eq "^${QBIT_CONTAINER}$"; then
    log_error "Container '${QBIT_CONTAINER}' is not running." >&2
    exit 1
fi

# --- 2. Check Port Synchronization ---
GLUETUN_PORT=$(docker exec "${GLUETUN_CONTAINER}" cat /tmp/gluetun/forwarded_port 2>/dev/null)
QBIT_PORT=$(docker exec "${QBIT_CONTAINER}" curl -s http://localhost:8080/api/v2/app/preferences | grep -o '"listen_port":[0-9]*' | awk -F: '{print $2}')

if [[ -z "$GLUETUN_PORT" || -z "$QBIT_PORT" ]]; then
    log_error "Failed to retrieve port configurations." >&2
    exit 1
fi

echo "Gluetun Forwarded Port: $GLUETUN_PORT"
echo "qBittorrent Listening Port: $QBIT_PORT"

if [[ "$GLUETUN_PORT" -eq "$QBIT_PORT" ]]; then
    log_success "Ports match."
else
    log_warning "Mismatch! qBittorrent ($QBIT_PORT) != Gluetun ($GLUETUN_PORT)."
fi

echo "------------------------------------"

# --- 3. Check IP Leakage (Ensure VPN is active) ---
# Get host (non-VPN) external IP address
HOST_IP=$(curl -s https://ifconfig.me)

# Get qBittorrent container external IP address
QBIT_IP=$(docker exec "${QBIT_CONTAINER}" curl -s https://ifconfig.me)

if [[ -z "$HOST_IP" || -z "$QBIT_IP" ]]; then
    log_error "Could not retrieve public IP addresses for comparison." >&2
    exit 1
fi

echo "Host Public IP: $HOST_IP"
echo "qBittorrent Public IP: $QBIT_IP"

if [[ "$HOST_IP" == "$QBIT_IP" ]]; then
    log_warning "IP Leak! qBittorrent is using your non-VPN home IP address." >&2
    exit 1
else
    log_success "IP addresses do not match. Traffic is routed via VPN."
fi

