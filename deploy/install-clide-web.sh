#!/bin/bash
# Clide Web-Access Layer Installation Script
# Run with: sudo bash deploy/install-clide-web.sh
set -e

echo "=== Clide Web-Access Layer Installation ==="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (sudo)"
   exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUDO_USER="${SUDO_USER:-$(logname)}"
USER_HOME=$(eval echo ~"$SUDO_USER")

echo "[1/6] Installing ttyd..."
curl -L https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64 -o /usr/local/bin/ttyd
chmod +x /usr/local/bin/ttyd
ttyd --version

echo ""
echo "[2/6] Installing zellij..."
curl -L https://github.com/zellij-org/zellij/releases/latest/download/zellij-x86_64-unknown-linux-musl.tar.gz | tar -xz -C /usr/local/bin
chmod +x /usr/local/bin/zellij
zellij --version

echo ""
echo "[3/6] Installing clide-launcher..."
cp "$SCRIPT_DIR/clide-launcher" /usr/local/bin/clide-launcher
chmod +x /usr/local/bin/clide-launcher

echo ""
echo "[4/6] Installing Zellij config..."
ZELLIJ_CONFIG_DIR="$USER_HOME/.config/zellij"
ZELLIJ_LAYOUTS_DIR="$ZELLIJ_CONFIG_DIR/layouts"
mkdir -p "$ZELLIJ_LAYOUTS_DIR"
cp "$SCRIPT_DIR/zellij/config.kdl" "$ZELLIJ_CONFIG_DIR/config.kdl"
cp "$SCRIPT_DIR/zellij/bare.kdl" "$ZELLIJ_LAYOUTS_DIR/bare.kdl"
chown -R "$SUDO_USER:$SUDO_USER" "$ZELLIJ_CONFIG_DIR"

echo ""
echo "[5/6] Installing systemd service..."
cp "$SCRIPT_DIR/clide-web.service" /etc/systemd/system/clide-web.service

echo ""
echo "[6/6] Starting service..."
systemctl daemon-reload
systemctl enable clide-web
systemctl start clide-web

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Status:"
systemctl status clide-web --no-pager || true
echo ""
echo "Port check:"
ss -tlnp | grep 8888 || echo "Warning: Port 8888 not listening yet"
echo ""
echo "Access:"
echo "  Local:    http://localhost:8888"
echo "  Direct:   http://localhost:8888?project=system-management"
echo "  External: https://code.schweitz.net?project=system-management"
echo ""
echo "Don't forget to update NPM to enable WebSocket support for code.schweitz.net"
