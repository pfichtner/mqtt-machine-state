#!/bin/bash

# Your program name and version
PROGRAM_NAME="mqtt-machine-state"
VERSION="0.0.2"

# Temporary directory for packaging
BUILD_DIR=$(mktemp -d)

# Copy your executable to the temporary directory
cp ./mqtt-machine-state-arm  "$BUILD_DIR/mqtt-machine-state"

# Create a basic package structure
mkdir -p "$BUILD_DIR/usr/local/bin"
cp "$BUILD_DIR/mqtt-machine-state" "$BUILD_DIR/usr/bin/"

# Create systemd service file
mkdir -p "$BUILD_DIR/etc/systemd/system/"
cat <<EOL > "$BUILD_DIR/etc/systemd/system/$PROGRAM_NAME.service"
[Unit]
Description=$PROGRAM_NAME Service
After=network.target

[Service]
ExecStart=/usr/bin/$PROGRAM_NAME
Restart=always
User=nobody

[Install]
WantedBy=default.target
EOL

# Create DEB package
fpm -s dir -t deb -n "$PROGRAM_NAME" -v "$VERSION" -C "$BUILD_DIR" .

# Create RPM package
fpm -s dir -t rpm -n "$PROGRAM_NAME" -v "$VERSION" -C "$BUILD_DIR" .

# Clean up temporary directory
rm -rf "$BUILD_DIR"

