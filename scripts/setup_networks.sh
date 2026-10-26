#!/usr/bin/env bash

# Shared docker networks used across stacks (declared as external in compose).
# Safe to re-run: existing networks are left untouched.
NETWORKS=("tunnel")

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
}

log_error() {
    echo -e "${RED}ERROR: $1${NC}"
}

if ! docker info >/dev/null 2>&1; then
    log_error "Cannot talk to docker. Is it running, and is your user in the docker group?" >&2
    exit 1
fi

for NETWORK in "${NETWORKS[@]}"; do
    if docker network inspect "$NETWORK" >/dev/null 2>&1; then
        log_success "Network '${NETWORK}' already exists."
    elif docker network create "$NETWORK" >/dev/null; then
        log_success "Created network '${NETWORK}'."
    else
        log_error "Failed to create network '${NETWORK}'." >&2
        exit 1
    fi
done

