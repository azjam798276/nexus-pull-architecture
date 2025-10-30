#!/bin/bash
# Deploy webhook receiver to Proxmox host

set -euo pipefail

INSTALL_DIR="/opt/webhook-receiver"

echo "Installing webhook receiver..."

# Install dependencies
apt-get update
apt-get install -y python3 python3-pip

# Create installation directory
mkdir -p "$INSTALL_DIR"
cp webhook_receiver.py "$INSTALL_DIR/"
cp requirements.txt "$INSTALL_DIR/"

# Install Python dependencies
pip3 install -r "$INSTALL_DIR/requirements.txt"

# Install systemd service
cp webhook.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable webhook.service
systemctl restart webhook.service

echo "Webhook receiver installed and started!"
echo "Listening on: http://0.0.0.0:9191/webhook"
echo "Check status: systemctl status webhook.service"
echo "View logs: journalctl -u webhook.service -f"
