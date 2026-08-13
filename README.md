# Linux Hotspot

A Bash utility to create and maintain a persistent, keep-alive Wi-Fi hotspot on Linux.

This project is designed for headless servers, IoT gateways, or development machines that need to broadcast a highly reliable Wi-Fi network. Although tested on Debian 13 minimal, it should work on any Linux distribution that uses NetworkManager and systemd, with nmcli and cron available.

---

## Installation & Setup

> [!IMPORTANT]
> Currently, the installer must be run as root (no sudo inside the script).

### 1. Make sure you are root

```bash
sudo -i
```

### 2. Download and install

#### Option A: From the Source Archive

```bash
wget -O linux-hotspot.tar.gz https://github.com/carsonjan/linux-hotspot/archive/main.tar.gz
tar -xzf linux-hotspot.tar.gz
cd linux-hotspot-main
chmod +x install.sh
./install.sh
```

#### Option B: Clone with Git

```bash
git clone https://github.com/carsonjan/linux-hotspot.git
cd linux-hotspot
chmod +x install.sh
./install.sh
```

---

## Configuration

The hotspot is configured via `hotspot.conf`. You can customize SSID, security, interfaces, and system policies:

| Config Option                          | Default           | Description                                                                                            |
| :------------------------------------- | :---------------- | :----------------------------------------------------------------------------------------------------- |
| `HOTSPOT_SSID`                         | `INJECT_HOSTNAME` | The Wi‑Fi network name (SSID). Set to `INJECT_HOSTNAME` to use the machine’s hostname as the SSID.     |
| `HOTSPOT_PASSWORD`                     | `linux-hotspot`   | The WPA2 passphrase (minimum 8 characters).                                                            |
| `HOTSPOT_NETWORK_BAND`                 | `bg`              | Wi-Fi network band. Use `bg` for 2.4 GHz (maximum compatibility) or `a` for 5 GHz (higher throughput). |
| `HOTSPOT_NETWORK_INTERFACE`            | `wlan0`           | Primary Wi-Fi network interface.                                                                       |
| `HOTSPOT_NETWORK_INTERFACE_FALLBACK_1` | `wlo1`            | Fallback Wi-Fi interface if the primary one is unavailable.                                            |
| `SYSTEM_DISABLE_SLEEP_LIKE`            | `true`            | When `true`, prevents the machine from entering sleep/suspend while the hotspot is active.             |
| `SYSTEM_ENABLE_PERFORMANCE_MODE`       | `false`           | When `true`, configures the system power profile to `performance`.                                     |

---

## How it Works

The utility consists of three main components:

1. **`install.sh`**:
   - Ensures the caller is `root` and `nmcli` is present.
   - Grants executable permissions to the other scripts.
   - Performs an initial run of `start-hotspot.sh` to initialize the hotspot.
   - Appends cron tasks: an `@reboot` job to start the hotspot on system boot, and a `* * * * *` job for minute-by-minute health check.

2. **`start-hotspot.sh`**:
   - Parses `hotspot.conf` robustly (handles comments, whitespace, and quotes).
   - Attempts to spin up the hotspot on the primary interface. If that fails, it tries the fallback interface.
   - Disables Wi‑Fi power saving for the created wireless profile by setting 802-11-wireless.powersave to 2 (disabled).
   - Optionally optimizes system-level properties (masks sleep targets, sets performance power profiles).

3. **`healthcheck-hotspot.sh`**:
   - Runs every minute via cron.
   - First verifies if the `Hotspot` connection is active. If it is inactive, it restarts it immediately.
   - Then performs an internet connectivity check by pinging a reliable IP (8.8.8.8). If the check fails twice in a row, it restarts NetworkManager and recreates the hotspot connection.

---

## Troubleshooting and Conflicts

### 1. Docker / Podman / Firewall Conflicts

Container runtimes like Docker and Podman frequently modify iptables rules, which can interfere with NAT and prevent connected clients from accessing the internet.

**Fix**: Restart the hotspot script after Docker starts, or configure Docker to use userland proxies. You may also need to add forwarding rules to your firewall (e.g., ufw or firewalld). Alternatively, consider disabling these container services via systemd if they are not needed.

### 2. Checking Hotspot Status

You can check if the hotspot is active using NetworkManager's command-line interface:

```bash
nmcli connection show --active | grep Hotspot
```

Or check the wireless device status:

```bash
nmcli device
```

---

## Uninstallation

If you wish to remove the hotspot and restore all default system settings:

1. **Remove Cron Jobs**:

   ```bash
   crontab -l | grep -v "linux-hotspot" | crontab -
   ```

2. **Restore System Sleep Targets**:

   ```bash
   systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target
   ```

3. **Delete the Hotspot Connection**:
   ```bash
   nmcli connection delete Hotspot
   ```
