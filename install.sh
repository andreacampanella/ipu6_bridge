#!/bin/bash
# install.sh — installs IPU6 camera config files
set -e
cd "$(dirname "$0")"

sudo install -m644 modprobe.conf     /etc/modprobe.d/v4l2loopback.conf
sudo install -m644 modules-load.conf /etc/modules-load.d/v4l2loopback.conf
sudo install -m644 99-ipu-psys.rules /etc/udev/rules.d/99-ipu-psys.rules

mkdir -p ~/.config/systemd/user
install -m644 ipu6-camera.service ~/.config/systemd/user/

sudo install -m755 ipu6-camera /usr/local/bin/ipu6-camera

sudo udevadm control --reload && sudo udevadm trigger
sudo usermod -aG video "$USER"
systemctl --user daemon-reload

echo "Done. Log out/in for group + udev changes, then: ipu6-camera start"