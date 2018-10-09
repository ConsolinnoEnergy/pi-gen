#!/bin/bash -e

install -d "${ROOTFS_DIR}/etc/systemd/system/getty@tty1.service.d"
install -m 644 files/noclear.conf "${ROOTFS_DIR}/etc/systemd/system/getty@tty1.service.d/noclear.conf"
install -v -m 644 files/fstab "${ROOTFS_DIR}/etc/fstab"

if [ -f files/pi_default_pass ]; then
	install -v -m 644 files/pi_default_pass "${ROOTFS_DIR}/tmp/pi_default_pass"
else
	echo "pi:raspberry" > "${ROOTFS_DIR}/tmp/pi_default_pass"
fi

on_chroot << EOF
if ! id -u pi >/dev/null 2>&1; then
	adduser --disabled-password --gecos "" pi
fi
cat /tmp/pi_default_pass | chpasswd
echo "root:root" | chpasswd
EOF
