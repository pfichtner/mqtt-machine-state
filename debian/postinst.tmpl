#!/bin/sh
set -e

# Create dedicated system user if it doesn't exist
if ! id -u mqttmachinestate >/dev/null 2>&1; then
    useradd --system --no-create-home --shell /usr/sbin/nologin mqttmachinestate
fi

# Ensure config file owned by the user
chown mqttmachinestate:mqttmachinestate /etc/mqttmachinestate.conf || true

# Reload systemd and enable service
systemctl daemon-reload
systemctl enable mqtt-machine.service >/dev/null || true

