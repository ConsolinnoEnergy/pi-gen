#!/bin/bash -e

install -v -d					"${ROOTFS_DIR}/etc/systemd/system/dhcpcd.service.d"
install -v -m 644 files/wait.conf		"${ROOTFS_DIR}/etc/systemd/system/dhcpcd.service.d/"

install -v -d					"${ROOTFS_DIR}/etc/wpa_supplicant"
install -v -m 600 files/wpa_supplicant.conf	"${ROOTFS_DIR}/etc/wpa_supplicant/wpa_supplicant.conf"

if [ -f files/hostapd.conf ]; then
  install -v -m 644 files/hostapd.conf	"${ROOTFS_DIR}/etc/hostapd/hostapd.conf"
else
  install -v -m 644 files/hostapd.conf.template "${ROOTFS_DIR}/etc/hostapd/hostapd.conf"
fi

install -v -m 600 files/dhcpcd.conf	"${ROOTFS_DIR}/etc/dhcpcd.conf"

install -v -m 600 files/dnsmasq.conf	"${ROOTFS_DIR}/etc/dnsmasq.conf"

sed -i 's|#DAEMON_CONF|DAEMON_CONF="/etc/hostapd/hostapd.conf"|g' "${ROOTFS_DIR}/etc/ssh/sshd_config"

mkdir 700 "${ROOTFS_DIR}/home/pi/.ssh"

if [ -f files/authorized_keys ]; then
  install -v -m 600 files/authorized_keys	"${ROOTFS_DIR}/home/pi/.ssh/authorized_keys"
  chown 1000:1000 "${ROOTFS_DIR}/home/pi/.ssh" -Rf
fi
