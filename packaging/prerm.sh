#!/bin/sh
set -e
systemctl stop mqtt-machine.service >/dev/null || true
systemctl disable mqtt-machine.service >/dev/null || true

