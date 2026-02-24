#!/bin/bash
# Clide Web Server Installation Script
# Run with: sudo bash deploy/install-clide-web.sh
set -e

echo "=== Clide Web Server Installation ==="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (sudo)"
   exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "[1/3] Installing clide-web Python package..."
cd "$PROJECT_DIR"
.venv/bin/pip install -e "./clide-web"

echo ""
echo "[2/3] Installing systemd service..."
cp "$SCRIPT_DIR/clide-web.service" /etc/systemd/system/clide-web.service

echo ""
echo "[3/3] Starting service..."
systemctl daemon-reload
systemctl enable clide-web
systemctl restart clide-web

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
echo "  Direct:   http://localhost:8888?project=clide"
echo "  External: https://code.schweitz.net?project=clide"
