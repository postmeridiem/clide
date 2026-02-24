#!/bin/bash
# Temporary script to install ttyd-nerd-font and restart service
set -e

systemctl stop clide-web
cp /mnt/media/Projects/clide/deploy/ttyd-nerd-font/build/ttyd /usr/local/bin/ttyd
cp /mnt/media/Projects/clide/deploy/clide-web.service /etc/systemd/system/clide-web.service
systemctl daemon-reload
systemctl start clide-web

echo "Done. ttyd version: $(ttyd --version)"
systemctl status clide-web --no-pager
