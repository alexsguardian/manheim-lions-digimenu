#!/bin/bash

# Manheim Lions Digital Menu - Diagnostic Script
# Run this on the Pi to check what's wrong with the display

echo "🦁 Manheim Lions Digital Menu - Diagnostics"
echo "============================================="

echo
echo "1. Checking if LightDM is running..."
systemctl status lightdm

echo
echo "2. Checking menu-display service status..."
systemctl status menu-display

echo
echo "3. Checking if menudisplay user exists..."
id menudisplay

echo
echo "4. Checking if X server is running..."
ps aux | grep -i xorg

echo
echo "5. Checking LightDM configuration..."
cat /etc/lightdm/lightdm.conf | grep -E "(autologin|user-session)"

echo
echo "6. Checking if nginx is serving the content..."
curl -s -o /dev/null -w "%{http_code}" http://localhost/ || echo "Failed to connect to localhost"

echo
echo "7. Checking if dist directory exists..."
ls -la /opt/manheim-lions-menu/dist/ | head -5

echo
echo "8. Checking recent systemd logs for menu-display..."
journalctl -u menu-display --no-pager -n 20

echo
echo "9. Checking recent systemd logs for lightdm..."
journalctl -u lightdm --no-pager -n 10

echo
echo "10. Manual service start test..."
echo "You can try manually starting the service with:"
echo "sudo systemctl start menu-display"
echo "sudo systemctl enable menu-display"
echo
echo "To check real-time logs:"
echo "journalctl -u menu-display -f"
