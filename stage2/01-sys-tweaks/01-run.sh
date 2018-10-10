#!/bin/bash -e

install -m 755 files/resize2fs_once	"${ROOTFS_DIR}/etc/init.d/"

install -d				"${ROOTFS_DIR}/etc/systemd/system/rc-local.service.d"
install -m 644 files/ttyoutput.conf	"${ROOTFS_DIR}/etc/systemd/system/rc-local.service.d/"

install -m 644 files/50raspi		"${ROOTFS_DIR}/etc/apt/apt.conf.d/"

install -m 644 files/console-setup   	"${ROOTFS_DIR}/etc/default/"

install -m 755 files/rc.local		"${ROOTFS_DIR}/etc/"

#disable ssh password auth
sed -i 's|[#]*PasswordAuthentication yes|PasswordAuthentication no|g' "${ROOTFS_DIR}/etc/ssh/sshd_config"
sed -i 's|UsePAM yes|UsePAM no|g' "${ROOTFS_DIR}/etc/ssh/sshd_config"

on_chroot << EOF
systemctl disable hwclock.sh
systemctl disable nfs-common
systemctl disable rpcbind
systemctl enable regenerate_ssh_host_keys
EOF

if [ "${USE_QEMU}" = "1" ]; then
	echo "enter QEMU mode"
	install -m 644 files/90-qemu.rules "${ROOTFS_DIR}/etc/udev/rules.d/"
	on_chroot << EOF
systemctl disable resize2fs_once
EOF
	echo "leaving QEMU mode"
else
	on_chroot << EOF
systemctl enable resize2fs_once
EOF
fi

on_chroot << \EOF
for GRP in input spi i2c gpio; do
	groupadd -f -r "$GRP"
done
for GRP in adm dialout cdrom audio users sudo video games plugdev input gpio spi i2c netdev; do
  adduser pi $GRP
done
EOF

on_chroot << EOF
setupcon --force --save-only -v
echo "bcm2835_wdt" | tee -a /etc/modules
mkdir /etc/watchdog.d/
EOF

install -m 644 files/watchdog.conf "${ROOTFS_DIR}/etc/watchdog.conf"

on_chroot << EOF
usermod --pass='*' root
EOF

rm -f "${ROOTFS_DIR}/etc/ssh/"ssh_host_*_key*
