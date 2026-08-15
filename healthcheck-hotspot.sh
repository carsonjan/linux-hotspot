#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$SCRIPT_DIR/utils.sh" || {
    echo "Error: Failed to source utils.sh." >&2
    exit 1
}

PING_TARGET=$(get_config_val "HOTSPOT_HEALTHCHECK_TARGET")
PING_INTERFACE_0=$(get_config_val "HOTSPOT_NETWORK_INTERFACE")
PING_INTERFACE_1=$(get_config_val "HOTSPOT_NETWORK_INTERFACE_FALLBACK_1")
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
get_interface_ip() {
    local interface="$1"
    local ip

    ip=$(
        ip -4 -o addr show dev "$interface" 2>/dev/null |
        awk 'NR == 1 { split($4, a, "/"); print a[1] }'
    )

    if [[ -z "$ip" ]]; then
        echo "Error: Could not retrieve IPv4 address for interface $interface." >&2
        return 1
    fi

    echo "$ip"
}
test_ping() {
    # test upstream network connectivity
    if ! ping -c 2 -W 5 "$PING_TARGET" &> /dev/null; then
        return 1
    fi
    # test interface 0 reachability
    if ! ping -c 2 -W 5 "$(get_interface_ip "$PING_INTERFACE_0")" &> /dev/null; then
        # test interface 1 reachability
        if ! ping -c 2 -W 5 "$(get_interface_ip "$PING_INTERFACE_1")" &> /dev/null; then
            return 1
        fi
    fi
    return 0
}

if ! test_ping; then
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