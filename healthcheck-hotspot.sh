#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$SCRIPT_DIR/utils.sh" || {
    echo "Error: Failed to source utils.sh." >&2
    exit 1
}

PING_TARGET=$(get_config_val "HOTSPOT_HEALTHCHECK_TARGET")
DOUBLE_CHECK_DELAY=10

# 1. Check if the Hotspot connection is active
if ! nmcli connection show --active | grep -q "Hotspot"; then
    echo "Warning: Hotspot connection is not active. Attempting to start..." >&2
    "$SCRIPT_DIR/start-hotspot.sh" || {
        echo "Error: Failed to start hotspot." >&2
        exit 1
    }
    exit 0
fi

# 2. Check if local can reach the internet by pinging a reliable host (Google DNS)
if ! ping -c 1 -W 5 "$PING_TARGET" &> /dev/null; then
    
    # Double check if this is not a temporary network issue by pinging again
    sleep $DOUBLE_CHECK_DELAY
    if ! ping -c 3 -W 5 "$PING_TARGET" &> /dev/null; then
        echo "Error: Internet connectivity check failed. The hotspot may not be functioning properly." >&2
        echo "Restarting NetworkManager and the hotspot..." >&2

        # Restart NetworkManager service to reset network interfaces
        #    assumes current user is root
        systemctl restart NetworkManager || {
            echo "Error: Failed to restart NetworkManager service." >&2
            exit 1
        }

        # Wait a bit for NetworkManager to initialize
        sleep 3

        # Restart the hotspot by running start-hotspot.sh
        "$SCRIPT_DIR/start-hotspot.sh" || {
            echo "Error: Failed to restart the hotspot." >&2
            exit 1
        }
    fi
fi