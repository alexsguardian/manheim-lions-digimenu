# Manheim Lions Digital Menu - Deployment Guide

This directory contains the deployment scripts for setting up the digital menu on a Raspberry Pi.

## 📋 Prerequisites

- **Raspberry Pi 3B or newer** with Raspberry Pi OS Lite installed
- **Internet connection** during setup
- **HDMI display** (preferably vertical orientation)
- **SD card** (16GB+ recommended)

## 🚀 Quick Installation

### Option 1: One-Line Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/alexsguardian/manheim-lions-digimenu/main/scripts/install.sh | bash
```

### Option 2: Manual Installation

1. **Download the installer:**
   ```bash
   wget https://raw.githubusercontent.com/alexsguardian/manheim-lions-digimenu/main/scripts/install.sh
   chmod +x install.sh
   ```

2. **Run the installer:**
   ```bash
   ./install.sh
   ```

3. **Reboot the system:**
   ```bash
   sudo reboot
   ```

## 🔧 What the Installer Does

The cloud-init style installer performs the following:

### System Configuration
- ✅ Updates all system packages
- ✅ Installs required packages (Node.js, Chromium, nginx, X11)
- ✅ Creates dedicated service user (`menudisplay`)
- ✅ Configures automatic login to graphical session

### Application Setup
- ✅ Clones the project repository to `/opt/manheim-lions-menu`
- ✅ Installs npm dependencies and builds the application
- ✅ Configures nginx to serve the static files
- ✅ Creates systemd service for automatic startup

### Display Configuration
- ✅ Sets up Chromium in full-screen kiosk mode
- ✅ Configures vertical display rotation (90° left)
- ✅ Disables screen blanking and power management
- ✅ Hides mouse cursor for clean presentation

### Management Tools
- ✅ Creates update script (`menu-update`)
- ✅ Creates status monitoring script (`menu-status`)
- ✅ Configures proper logging and error handling

## 🛠️ Post-Installation Management

### Updating the Menu

To update the menu content or application:

```bash
menu-update
```

This will:
- Pull the latest code from the repository
- Rebuild the application
- Restart all services
- Apply changes immediately

### Checking System Status

```bash
menu-status
```

This displays:
- System information (IP, uptime, etc.)
- Service status (display service, web server)
- Application information (build time, git status)
- Access URLs for the menu

### Manual Service Control

```bash
# Start/stop the display service
sudo systemctl start menu-display
sudo systemctl stop menu-display
sudo systemctl restart menu-display

# Check service status
sudo systemctl status menu-display

# View service logs
journalctl -u menu-display -f

# Web server management
sudo systemctl restart nginx
sudo systemctl status nginx
```

## 🖥️ Display Configuration

### Automatic Display Setup

The installer automatically configures:
- **Vertical orientation** (90° rotation left)
- **Full-screen kiosk mode** with no browser UI
- **No screen blanking** or power management
- **Hidden mouse cursor** for clean presentation

### Manual Display Adjustment

If you need to change display settings:

```bash
# Check available displays
xrandr

# Rotate display (as menudisplay user)
sudo -u menudisplay xrandr --output HDMI-1 --rotate left

# Different rotation options:
# --rotate normal (0°)
# --rotate left (90° counterclockwise)
# --rotate right (90° clockwise)
# --rotate inverted (180°)
```

## 🌐 Network Access

After installation, the menu is accessible at:

- **Local (on Pi):** http://localhost/
- **Network:** http://[PI_IP_ADDRESS]/
- **Health check:** http://[PI_IP_ADDRESS]/health

To find the Pi's IP address:
```bash
hostname -I
```

## 📁 File Structure

```
/opt/manheim-lions-menu/          # Main application directory
├── src/                          # Source code
├── dist/                         # Built static files (served by nginx)
├── scripts/                      # Deployment scripts
└── package.json                  # Node.js dependencies

/etc/systemd/system/
└── menu-display.service          # Systemd service file

/etc/nginx/sites-available/
└── menu-display                  # Nginx configuration

/var/lib/menudisplay/             # Service user home directory
└── .config/openbox/              # Window manager config

/usr/local/bin/
├── menu-update                   # Update script
└── menu-status                   # Status script
```

## 🔍 Troubleshooting

### Service Won't Start

1. **Check service status:**
   ```bash
   sudo systemctl status menu-display
   journalctl -u menu-display -n 20
   ```

2. **Verify X server is running:**
   ```bash
   ps aux | grep X
   ```

3. **Check display connection:**
   ```bash
   sudo -u menudisplay DISPLAY=:0 xrandr
   ```

### Display Issues

1. **Wrong orientation:**
   ```bash
   sudo systemctl stop menu-display
   sudo -u menudisplay DISPLAY=:0 xrandr --output HDMI-1 --rotate left
   sudo systemctl start menu-display
   ```

2. **Browser not starting:**
   ```bash
   # Check Chromium manually
   sudo -u menudisplay DISPLAY=:0 chromium-browser --version
   ```

### Network Issues

1. **Nginx not serving content:**
   ```bash
   sudo nginx -t
   sudo systemctl status nginx
   curl http://localhost/health
   ```

2. **Application not built:**
   ```bash
   cd /opt/manheim-lions-menu
   sudo -u menudisplay npm run build
   ```

### Performance Issues

1. **High CPU usage:**
   ```bash
   top -u menudisplay
   ```

2. **Memory issues:**
   ```bash
   free -h
   sudo journalctl -u menu-display | grep -i memory
   ```

## 🔐 Security Notes

- The service runs as a dedicated user (`menudisplay`) with minimal privileges
- Systemd security features are enabled (NoNewPrivileges, PrivateTmp, etc.)
- Nginx serves static files only with security headers
- No unnecessary network services are exposed

## 📋 System Requirements

### Minimum Requirements
- **Raspberry Pi 3B** or newer
- **1GB RAM** (2GB+ recommended)
- **16GB SD card** (Class 10 or better)
- **HDMI display** with 1920x1080 resolution

### Recommended Setup
- **Raspberry Pi 4B** with 4GB RAM
- **32GB SD card** (Class 10 or A2)
- **Fast ethernet** or 5GHz WiFi connection
- **Vertical HDMI display** for optimal menu viewing

## 📞 Support

For issues or questions:

1. Check the troubleshooting section above
2. Review service logs: `journalctl -u menu-display -f`
3. Check system status: `menu-status`
4. Create an issue in the GitHub repository

## 🔄 Updating This Guide

This README is automatically deployed with the application. To update:

1. Edit this file in the repository
2. Commit and push changes
3. Run `menu-update` on the Pi
4. Changes will be reflected immediately

## Installation Process

### Prerequisites
- Raspberry Pi 3B or newer
- Raspberry Pi OS Lite (recommended) or Desktop
- Internet connection
- SSH access (if installing remotely)

### Step-by-Step Installation

1. **Flash Raspberry Pi OS Lite** to SD card
2. **Enable SSH** (place empty `ssh` file in boot partition)
3. **Boot the Pi** and SSH in as `pi` user
4. **Run the install script**:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/alexsguardian/manheim-lions-digimenu/main/scripts/install.sh | bash
   ```
5. **Reboot** the system:
   ```bash
   sudo reboot
   ```

### Post-Installation

After reboot, the system will:
- Auto-login as `pi` user
- Start X11 with Openbox window manager
- Launch the digital menu in Chromium kiosk mode
- Display the menu automatically

## Helper Scripts Created

The installation creates these additional scripts in `/home/pi/`:

### 🔄 `update-menu.sh`
Updates the menu with latest changes from Git:
```bash
./update-menu.sh
```

### 📊 `menu-status.sh`
Shows system status and menu health:
```bash
./menu-status.sh
```

## Configuration Files

The installation creates/modifies these configuration files:

- `/etc/nginx/sites-available/menu` - Nginx configuration
- `/etc/lightdm/lightdm.conf` - Auto-login configuration
- `/home/pi/.config/openbox/autostart` - Auto-start configuration
- `/home/pi/.xsession` - X session configuration

## Troubleshooting

### Menu not displaying
1. Check if Chromium is running: `pgrep chromium`
2. Check nginx status: `sudo systemctl status nginx`
3. View boot logs: `tail -f /home/pi/menu-boot.log`

### Network access issues
1. Check Pi's IP: `hostname -I`
2. Test local access: `curl http://localhost/`
3. Check nginx logs: `sudo tail -f /var/log/nginx/error.log`

### Update issues
1. Ensure Git repository is clean: `cd /home/pi/manheim-lions-menu && git status`
2. Manual update: `cd /home/pi/manheim-lions-menu && git pull && npm run build`

## Manual Operations

### Restart the display
```bash
sudo systemctl restart lightdm
```

### Stop/start the menu manually
```bash
# Stop
pkill chromium-browser

# Start
/home/pi/start-menu.sh
```

### View real-time logs
```bash
tail -f /home/pi/menu-boot.log
```

## Network Access

Once installed, the menu is accessible via:
- **Local**: `http://localhost/`
- **Network**: `http://[PI_IP_ADDRESS]/`

Use `hostname -I` to find the Pi's IP address.

---

**Support**: For issues, check the logs and ensure all services are running. The status script provides a good overview of system health.
