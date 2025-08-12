#!/bin/bash

# Manheim Lions Digital Menu - Cloud-Init Style Installation Script
# This script provisions a Raspberry Pi for digital menu display using modern practices

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Configuration
readonly SCRIPT_VERSION="1.0.0"
readonly PROJECT_NAME="manheim-lions-menu"
readonly PROJECT_DIR="/opt/${PROJECT_NAME}"
readonly SERVICE_USER="menudisplay"
readonly REPO_URL="https://github.com/alexsguardian/manheim-lions-digimenu.git"
readonly LOG_FILE="/opt/menu-install.log"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Logging functions
log() {
    if [[ -w "$LOG_FILE" ]] 2>/dev/null; then
        echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO:${NC} $1" | tee -a "$LOG_FILE"
    else
        echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
    fi
}

log_success() {
    if [[ -w "$LOG_FILE" ]] 2>/dev/null; then
        echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS:${NC} $1" | tee -a "$LOG_FILE"
    else
        echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS:${NC} $1"
    fi
}

log_warning() {
    if [[ -w "$LOG_FILE" ]] 2>/dev/null; then
        echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
    else
        echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
    fi
}

log_error() {
    if [[ -w "$LOG_FILE" ]] 2>/dev/null; then
        echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
    else
        echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
    fi
}

# Error handler
error_exit() {
    log_error "$1"
    exit 1
}

# Privilege check
check_privileges() {
    if [[ $EUID -eq 0 ]]; then
        error_exit "This script should not be run as root. Run as pi user with sudo access."
    fi

    if ! sudo -n true 2>/dev/null; then
        error_exit "User must have passwordless sudo access. Run: sudo visudo"
    fi
}

# System package management
install_system_packages() {
    log "Updating package repositories..."
    sudo apt-get update -qq

    log "Upgrading system packages..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq

    local packages=(
        "git"
        "curl"
        "wget"
        "unzip"
        "chromium-browser"
        "nginx"
        "xorg"
        "openbox"
        "lightdm"
        "x11-xserver-utils"
        "xinit"
        "unclutter"
        "ca-certificates"
        "gnupg"
        "lsb-release"
    )

    log "Installing required packages: ${packages[*]}"
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${packages[@]}"

    log_success "System packages installed"
}

# Node.js installation
install_nodejs() {
    log "Installing Node.js LTS..."

    # Detect architecture
    local arch
    arch=$(uname -m)
    log "Detected architecture: $arch"

    # Remove any existing Node.js
    sudo apt-get remove -y -qq nodejs npm || true
    sudo apt-get autoremove -y -qq || true

    # Install from NodeSource with architecture awareness
    log "Downloading and installing Node.js from NodeSource..."
    if ! curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -; then
        log_error "Failed to setup NodeSource repository"

        # Fallback: try installing from default repositories
        log "Falling back to default repository Node.js..."
        sudo apt-get update -qq
        sudo apt-get install -y -qq nodejs npm
    else
        sudo apt-get install -y -qq nodejs
    fi

    # Verify installation
    local node_version
    local npm_version
    if ! node_version=$(node --version 2>/dev/null); then
        error_exit "Node.js installation failed - node command not found"
    fi

    if ! npm_version=$(npm --version 2>/dev/null); then
        error_exit "npm installation failed - npm command not found"
    fi

    log_success "Node.js $node_version and npm $npm_version installed"

    # Update npm to latest compatible version
    log "Updating npm to latest version..."
    sudo npm install -g npm@latest || log_warning "npm update failed, continuing with current version"
}

# User management
create_service_user() {
    log "Creating service user '$SERVICE_USER'..."

    if id "$SERVICE_USER" &>/dev/null; then
        log_warning "User '$SERVICE_USER' already exists"
        return 0
    fi

    sudo adduser --system --group --home "/var/lib/$SERVICE_USER" \
        --shell /bin/bash --comment "Menu Display Service" "$SERVICE_USER"

    # Add to required groups
    sudo usermod -a -G video,audio "$SERVICE_USER"

    log_success "Service user '$SERVICE_USER' created"
}

# Project deployment
deploy_project() {
    log "Deploying project to $PROJECT_DIR (using pre-built dist.tar)..."

    # Clean existing directory
    if [[ -d "$PROJECT_DIR" ]]; then
        log_warning "Existing project directory found. Creating backup..."
        sudo mv "$PROJECT_DIR" "${PROJECT_DIR}.backup.$(date +%s)"
    fi

    # Create project directory
    sudo mkdir -p "$PROJECT_DIR"

    # Check for pre-built dist.tar file
    local dist_tar="/opt/dist.tar"
    if [[ -f "$dist_tar" ]]; then
        log "Found pre-built dist.tar file, extracting..."

        # Extract the pre-built distribution
        sudo tar -xf "$dist_tar" -C "$PROJECT_DIR" || error_exit "Failed to extract dist.tar"

        # Verify extraction was successful
        if [[ -d "$PROJECT_DIR/dist" ]] && [[ -f "$PROJECT_DIR/dist/index.html" ]]; then
            log_success "Pre-built distribution extracted successfully!"
        else
            error_exit "dist.tar extraction failed - no valid dist folder found"
        fi

        # Clone repository for configuration files (but skip building)
        log "Cloning repository for configuration files..."
        local temp_repo="/tmp/menu-repo"
        if [[ -d "$temp_repo" ]]; then
            sudo rm -rf "$temp_repo"
        fi
        sudo git clone "$REPO_URL" "$temp_repo"

        # Copy configuration files if they exist
        if [[ -f "$temp_repo/package.json" ]]; then
            sudo cp "$temp_repo/package.json" "$PROJECT_DIR/"
        fi
        if [[ -f "$temp_repo/astro.config.ts" ]]; then
            sudo cp "$temp_repo/astro.config.ts" "$PROJECT_DIR/"
        fi
        if [[ -f "$temp_repo/astro.config.js" ]]; then
            sudo cp "$temp_repo/astro.config.js" "$PROJECT_DIR/"
        fi

        # Clean up temp repo
        sudo rm -rf "$temp_repo"

        log "Pre-built deployment completed - no build required on Pi!"

    else
        log_warning "No pre-built dist.tar found at $dist_tar"
        log "Falling back to building from source..."

        # Clone repository
        sudo git clone "$REPO_URL" "$PROJECT_DIR"

        log "System architecture: $(uname -m)"
        log "Node.js version: $(node --version)"
        log "npm version: $(npm --version)"

        # Try building from source (fallback)
        log "Installing dependencies..."
        sudo -u "$SERVICE_USER" bash -c "cd $PROJECT_DIR && npm install"

        log "Building application..."
        if sudo -u "$SERVICE_USER" bash -c "cd $PROJECT_DIR && npm run build"; then
            log_success "Source build completed successfully!"
        else
            error_exit "Build from source failed. Please provide a pre-built dist.tar file in /opt/ or fix ARM64 compatibility issues."
        fi
    fi

    # Set proper ownership
    sudo chown -R "$SERVICE_USER:$SERVICE_USER" "$PROJECT_DIR"

    # Ensure dist directory has correct permissions
    if [[ -d "$PROJECT_DIR/dist" ]]; then
        sudo chmod -R 755 "$PROJECT_DIR/dist"
        log_success "Project deployed successfully"
    else
        error_exit "No dist directory found after deployment"
    fi
}

# Web server configuration
configure_nginx() {
    log "Configuring nginx web server..."

    # Create nginx configuration
    sudo tee /etc/nginx/sites-available/menu-display > /dev/null <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root $PROJECT_DIR/dist;
    index index.html;

    server_name _;

    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";

    # Main location
    location / {
        try_files \$uri \$uri/ =404;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
    }

    # Static assets with caching
    location ~* \.(png|jpg|jpeg|gif|ico|svg|css|js)$ {
        expires 1d;
        add_header Cache-Control "public, immutable";
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }
}
EOF

    # Enable site
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo ln -sf /etc/nginx/sites-available/menu-display /etc/nginx/sites-enabled/

    # Test configuration
    sudo nginx -t

    # Enable and start nginx
    sudo systemctl enable nginx
    sudo systemctl restart nginx

    log_success "Nginx configured and started"
}

# Create systemd service
create_systemd_service() {
    log "Creating systemd service..."

    sudo tee /etc/systemd/system/menu-display.service > /dev/null <<EOF
[Unit]
Description=Manheim Lions Digital Menu Display
Documentation=https://github.com/alexsguardian/manheim-lions-digimenu
After=graphical-session.target network.target nginx.service
Wants=graphical-session.target
Requires=nginx.service

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
Environment=DISPLAY=:0
Environment=HOME=/var/lib/$SERVICE_USER
WorkingDirectory=$PROJECT_DIR
ExecStartPre=/bin/sleep 10
ExecStart=/opt/$PROJECT_NAME/scripts/menu-display.sh
Restart=always
RestartSec=10
KillMode=mixed
KillSignal=SIGTERM
TimeoutStopSec=30

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=$PROJECT_DIR /var/lib/$SERVICE_USER /tmp

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=menu-display

[Install]
WantedBy=graphical.target
EOF

    # Create the actual service script
    sudo mkdir -p "$PROJECT_DIR/scripts"
    sudo tee "$PROJECT_DIR/scripts/menu-display.sh" > /dev/null <<'EOF'
#!/bin/bash

# Menu Display Service Script
set -euo pipefail

readonly LOG_TAG="menu-display"
readonly DISPLAY_NUM=":0"

log() {
    logger -t "$LOG_TAG" "$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_error() {
    logger -t "$LOG_TAG" -p user.err "$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
}

# Wait for X server
wait_for_x() {
    log "Waiting for X server..."
    for i in {1..30}; do
        if xset -display "$DISPLAY_NUM" q &>/dev/null; then
            log "X server is ready"
            return 0
        fi
        sleep 2
    done
    log_error "X server failed to start within timeout"
    return 1
}

# Configure display
configure_display() {
    log "Configuring display settings..."

    export DISPLAY="$DISPLAY_NUM"

    # Set vertical orientation (90 degrees left)
    xrandr --output HDMI-1 --rotate left 2>/dev/null || \
    xrandr --output HDMI-A-1 --rotate left 2>/dev/null || \
    log "Could not set display rotation (continuing anyway)"

    # Disable power management
    xset s off
    xset -dpms
    xset s noblank

    # Hide cursor
    unclutter -idle 0.1 -root &

    log "Display configured"
}

# Start browser
start_browser() {
    log "Starting Chromium browser..."

    # Clean up any existing processes
    pkill -f chromium-browser || true
    sleep 2

    # Start Chromium in kiosk mode
    exec chromium-browser \
        --kiosk \
        --no-first-run \
        --disable-infobars \
        --disable-session-crashed-bubble \
        --disable-translate \
        --disable-features=TranslateUI \
        --disable-background-timer-throttling \
        --disable-backgrounding-occluded-windows \
        --disable-renderer-backgrounding \
        --disable-background-networking \
        --disable-sync \
        --disable-default-apps \
        --disable-extensions \
        --disable-plugins \
        --disable-java \
        --disable-notifications \
        --no-default-browser-check \
        --no-sandbox \
        --disable-dev-shm-usage \
        --disable-software-rasterizer \
        --start-fullscreen \
        --window-position=0,0 \
        --app=http://localhost/
}

# Main execution
main() {
    log "Starting menu display service"

    wait_for_x || exit 1
    configure_display || exit 1
    start_browser
}

# Signal handlers
trap 'log "Received SIGTERM, shutting down..."; pkill -f chromium-browser; exit 0' TERM
trap 'log "Received SIGINT, shutting down..."; pkill -f chromium-browser; exit 0' INT

main "$@"
EOF

    sudo chmod +x "$PROJECT_DIR/scripts/menu-display.sh"
    sudo chown "$SERVICE_USER:$SERVICE_USER" "$PROJECT_DIR/scripts/menu-display.sh"

    # Reload systemd and enable service
    sudo systemctl daemon-reload
    sudo systemctl enable menu-display.service

    log_success "Systemd service created and enabled"
}

# Display configuration
configure_display_manager() {
    log "Configuring display manager..."

    # Configure LightDM for auto-login
    sudo tee /etc/lightdm/lightdm.conf > /dev/null <<EOF
[Seat:*]
autologin-guest=false
autologin-user=$SERVICE_USER
autologin-user-timeout=0
user-session=openbox
xserver-command=X -s 0 -dpms
EOF

    # Create openbox config for service user
    sudo mkdir -p "/var/lib/$SERVICE_USER/.config/openbox"
    sudo tee "/var/lib/$SERVICE_USER/.config/openbox/autostart" > /dev/null <<EOF
# Menu display auto-start configuration
# The systemd service will handle the actual application startup
EOF

    sudo chown -R "$SERVICE_USER:$SERVICE_USER" "/var/lib/$SERVICE_USER/.config"

    # Enable auto-login service
    sudo systemctl enable lightdm

    log_success "Display manager configured"
}

# Create management scripts
create_management_scripts() {
    log "Creating management scripts..."

    # Update script
    sudo tee /usr/local/bin/menu-update > /dev/null <<EOF
#!/bin/bash
set -euo pipefail

echo "🦁 Updating Manheim Lions Digital Menu..."

cd $PROJECT_DIR

# Stop service
sudo systemctl stop menu-display.service

# Update code
sudo -u $SERVICE_USER git pull origin main

# Install dependencies and rebuild
sudo -u $SERVICE_USER npm ci --only=production
sudo -u $SERVICE_USER npm run build

# Restart services
sudo systemctl restart nginx
sudo systemctl start menu-display.service

echo "✅ Menu updated successfully!"
EOF

    # Status script
    sudo tee /usr/local/bin/menu-status > /dev/null <<EOF
#!/bin/bash

echo "🦁 Manheim Lions Digital Menu - System Status"
echo "============================================="
echo ""

echo "📊 System Information:"
echo "  Hostname: \$(hostname)"
echo "  IP Address: \$(hostname -I | awk '{print \$1}')"
echo "  Uptime: \$(uptime -p)"
echo ""

echo "🖥️  Display Service:"
sudo systemctl status menu-display.service --no-pager -l
echo ""

echo "🌐 Web Server:"
sudo systemctl status nginx --no-pager -l
echo ""

echo "🔗 Access URLs:"
echo "  Local: http://localhost/"
echo "  Network: http://\$(hostname -I | awk '{print \$1}')/"
echo ""

echo "📁 Project Information:"
echo "  Location: $PROJECT_DIR"
echo "  Last Build: \$(stat -c %y $PROJECT_DIR/dist/index.html 2>/dev/null || echo 'Not built')"
echo "  Git Branch: \$(cd $PROJECT_DIR && git branch --show-current 2>/dev/null || echo 'Unknown')"
echo "  Git Commit: \$(cd $PROJECT_DIR && git rev-parse --short HEAD 2>/dev/null || echo 'Unknown')"
EOF

    sudo chmod +x /usr/local/bin/menu-update /usr/local/bin/menu-status

    log_success "Management scripts created"
}

# Main installation function
main() {
    # Create log file first, before any logging
    sudo touch "$LOG_FILE"
    sudo chmod 644 "$LOG_FILE"

    echo "🦁 Manheim Lions Digital Menu - Cloud-Init Installation v$SCRIPT_VERSION"
    echo "======================================================================="

    log "Starting installation process..."

    check_privileges
    install_system_packages
    install_nodejs
    create_service_user
    deploy_project
    configure_nginx
    create_systemd_service
    configure_display_manager
    create_management_scripts

    log_success "Installation completed successfully!"

    echo ""
    echo "🎉 Installation Summary"
    echo "======================"
    echo "✅ System packages installed"
    echo "✅ Node.js and npm installed"
    echo "✅ Service user '$SERVICE_USER' created"
    echo "✅ Project deployed to $PROJECT_DIR"
    echo "✅ Nginx web server configured"
    echo "✅ Systemd service 'menu-display' created"
    echo "✅ Display manager configured for auto-login"
    echo "✅ Management scripts installed"
    echo ""
    echo "🚀 Next Steps:"
    echo "1. Reboot the system: sudo reboot"
    echo "2. The menu will automatically start in kiosk mode"
    echo "3. Update the menu: menu-update"
    echo "4. Check status: menu-status"
    echo ""
    echo "🌐 The menu will be available at:"
    echo "  - http://localhost/ (on the Pi)"
    echo "  - http://$(hostname -I | awk '{print $1}')/ (on your network)"
    echo ""
    echo "📋 Service Management:"
    echo "  - Start: sudo systemctl start menu-display"
    echo "  - Stop: sudo systemctl stop menu-display"
    echo "  - Status: sudo systemctl status menu-display"
    echo "  - Logs: journalctl -u menu-display -f"
    echo ""
    log_warning "Please reboot the system to start the digital menu display"
}

# Run main function
main "$@"