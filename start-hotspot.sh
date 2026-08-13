#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$SCRIPT_DIR/utils.sh" || {
    echo "Error: Failed to source utils.sh." >&2
    exit 1
}

# check if config file exists
if [[ ! -f "$SCRIPT_DIR/hotspot.conf" ]]; then
    echo "Error: hotspot.conf file not found in script directory." >&2
    exit 1
fi

# read variables from config file
raw_ssid=$(get_config_val "HOTSPOT_SSID")
if [[ "$raw_ssid" == "INJECT_HOSTNAME" ]]; then
    ssid=$(hostname)
else
    ssid="$raw_ssid"
fi
password=$(get_config_val "HOTSPOT_PASSWORD")
network_band=$(get_config_val "HOTSPOT_NETWORK_BAND")
network_interface_0=$(get_config_val "HOTSPOT_NETWORK_INTERFACE")
network_interface_1=$(get_config_val "HOTSPOT_NETWORK_INTERFACE_FALLBACK_1")
healthcheck_target=$(get_config_val "HOTSPOT_HEALTHCHECK_TARGET")
system_enable_performance_mode=$(get_config_val "SYSTEM_ENABLE_PERFORMANCE_MODE")
system_disable_sleep_like=$(get_config_val "SYSTEM_DISABLE_SLEEP_LIKE")

# check if variables are not empty
if [[ -z "$ssid" || 
-z "$password" || 
-z "$network_band" || 
-z "$network_interface_0" || 
-z "$network_interface_1" || 
-z "$healthcheck_target" || 
-z "$system_enable_performance_mode" || 
-z "$system_disable_sleep_like"
]]; then
    echo "Error: One or more configuration variables are empty in hotspot.conf." >&2
    echo "Please check: HOTSPOT_SSID, HOTSPOT_PASSWORD, HOTSPOT_NETWORK_BAND, HOTSPOT_NETWORK_INTERFACE, HOTSPOT_NETWORK_INTERFACE_FALLBACK_1, HOTSPOT_HEALTHCHECK_TARGET, SYSTEM_ENABLE_PERFORMANCE_MODE, SYSTEM_DISABLE_SLEEP_LIKE" >&2
    exit 1
fi 

# create hotspot with nmcli (ADD MORE FALLBACK INTERFACES HERE IF NEEDED)
nmcli dev wifi hotspot ifname "$network_interface_0" ssid "$ssid" band "$network_band" con-name Hotspot password "$password" &>/dev/null ||
nmcli dev wifi hotspot ifname "$network_interface_1" ssid "$ssid" band "$network_band" con-name Hotspot password "$password" &>/dev/null || {
    echo "Error: Failed to create hotspot on any of the configured interfaces." >&2
    exit 1
}

# set optional config for the hotspot to increase stability
nmcli connection modify Hotspot 802-11-wireless.powersave 2 >/dev/null >&1 || true
nmcli connection modify Hotspot connection.autoconnect no >/dev/null >&1 || true

# set optional config in system to prevent sleeping and disconnecting the hotspot
#    enable performance mode for the machine
if [[ "$system_enable_performance_mode" == "true" ]]; then
    powerprofilesctl set performance >/dev/null 2>&1 || echo "Warning: Failed to enable Performance Mode." >&2
fi
#    disable sleep, suspend, hibernate, and hybrid-sleep targets to prevent the hotspot from disconnecting
if [[ "$system_disable_sleep_like" == "true" ]]; then
    systemctl mask sleep.target >/dev/null 2>&1 || echo "Warning: Failed to disable sleep.target." >&2
    systemctl mask suspend.target >/dev/null 2>&1 || echo "Warning: Failed to disable suspend.target." >&2
    systemctl mask hibernate.target >/dev/null 2>&1 || echo "Warning: Failed to disable hibernate.target." >&2
    systemctl mask hybrid-sleep.target >/dev/null 2>&1 || echo "Warning: Failed to disable hybrid-sleep.target." >&2
fi

echo "Hotspot created successfully."