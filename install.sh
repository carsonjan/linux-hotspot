#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

# check if current user is root
if [[ "$EUID" -ne 0 ]]; then
    echo "Error: This script must be run as root." >&2
    exit 1
fi

# add execution permissions to start-hotspot.sh and healthcheck-hotspot.sh
chmod +x "$SCRIPT_DIR/start-hotspot.sh" "$SCRIPT_DIR/healthcheck-hotspot.sh"

# check if nmcli is installed
if ! command -v nmcli &> /dev/null; then
    echo "Error: nmcli is not installed. Please install NetworkManager." >&2
    exit 1
fi

# run start-hotspot.sh to create hotspot
"$SCRIPT_DIR/start-hotspot.sh" || {
    echo "Error: Failed to create hotspot." >&2
    exit 1
}

# Function to add a line to crontab if it does not already exist, preserving order and comments
add_to_crontab() {
    local line="$1"
    if crontab -l 2>/dev/null | grep -Fxq "$line"; then
        return 0
    fi
    (crontab -l 2>/dev/null; echo "$line") | crontab -
}

# install cron job to start hotspot on reboot
add_to_crontab "@reboot $SCRIPT_DIR/start-hotspot.sh" || {
    echo "Error: Failed to install cron job for start-hotspot.sh." >&2
    exit 1
}

# install cron job to run healthcheck-hotspot.sh every minute
add_to_crontab "* * * * * $SCRIPT_DIR/healthcheck-hotspot.sh" || {
    echo "Error: Failed to install cron job for healthcheck-hotspot.sh." >&2
    exit 1
}

echo "====="
echo "INFO: Docker, Podman, or other iptables-mutating processes might interfere with the hotspot."
echo "If you experience issues, consider stopping these services."
echo "====="

echo "Success: Hotspot installation and healthcheck setup completed successfully."