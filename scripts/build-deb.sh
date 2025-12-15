#!/bin/bash
set -e

PKGROOT="deb-pkg"
PKGNAME="mqttmachinestate"
VERSION="${1:-0.0.0}"
ARCH="${2:-amd64}"

rm -rf "$PKGROOT"
mkdir -p "$PKGROOT/DEBIAN" "$PKGROOT/usr/bin" "$PKGROOT/etc" "$PKGROOT/lib/systemd/system" "$PKGROOT/usr/share/doc/$PKGNAME"

# Copy binary
install -m 0755 binaries/mqttmachinestate "$PKGROOT/usr/bin/"

# Copy config and service
cp debian/mqttmachinestate.conf.tmpl "$PKGROOT/etc/mqttmachinestate.conf"
chmod 644 "$PKGROOT/etc/mqttmachinestate.conf"

cp debian/mqtt-machine.service.tmpl "$PKGROOT/lib/systemd/system/mqtt-machine.service"
chmod 644 "$PKGROOT/lib/systemd/system/mqtt-machine.service"

# Optional: copy README
[ -f README.md ] && cp README.md "$PKGROOT/usr/share/doc/$PKGNAME/"

# Render control
envsubst < debian/control.tmpl > "$PKGROOT/DEBIAN/control"

# Maintainer scripts
cp debian/postinst.tmpl "$PKGROOT/DEBIAN/postinst"
cp debian/prerm.tmpl "$PKGROOT/DEBIAN/prerm"
chmod 755 "$PKGROOT/DEBIAN/postinst" "$PKGROOT/DEBIAN/prerm"

# Build .deb using fakeroot so ownership metadata is correct
fakeroot dpkg-deb --build "$PKGROOT"

# Move to artifacts
mkdir -p publish-artifacts
mv "${PKGROOT}.deb" "publish-artifacts/${PKGNAME}_${VERSION}_${ARCH}.deb"

