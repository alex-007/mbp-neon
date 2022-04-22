#!/bin/bash

set -eu -o pipefail

echo >&2 "===]> Info: Configure environment... "

mount none -t proc /proc
mount none -t sysfs /sys
mount none -t devpts /dev/pts

export HOME=/root
export LC_ALL=C

echo "neon-fs-live" >/etc/hostname

echo >&2 "===]> Info: Configure and update apt... "

cat <<EOF >/etc/apt/sources.list
deb http://archive.ubuntu.com/ubuntu/ focal main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ focal main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ focal-security main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ focal-security main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ focal-updates main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ focal-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ focal-backports main restricted universe multiverse
deb http://archive.canonical.com/ubuntu focal partner
EOF
apt-get update

echo >&2 "===]> Info: Install systemd and Ubuntu MBP Repo... "

apt-get install -y systemd-sysv gnupg curl wget

mkdir -p /etc/apt/sources.list.d
echo "#deb https://mbp-ubuntu-kernel.herokuapp.com/ /" >/etc/apt/sources.list.d/mbp-ubuntu-kernel.list
curl -L https://mbp-ubuntu-kernel.herokuapp.com/KEY.gpg | apt-key add -
echo "deb http://archive.neon.kde.org/user focal main" > /etc/apt/sources.list.d/neon.list
curl -L http://archive.neon.kde.org/public.key | apt-key add -
apt-get update

echo >&2 "===]> Info: Configure machine-id and divert... "

dbus-uuidgen >/etc/machine-id
ln -fs /etc/machine-id /var/lib/dbus/machine-id
dpkg-divert --local --rename --add /sbin/initctl
ln -s /bin/true /sbin/initctl

echo >&2 "===]> Info: Install packages needed for Live System... "

export DEBIAN_FRONTEND=noninteractive
apt-get install -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
  ubuntu-standard \
  shim-signed \
  sudo \
  casper \
  lupin-casper \
  discover \
  laptop-detect \
  os-prober \
  network-manager \
  resolvconf \
  net-tools \
  wireless-tools \
  wpagui \
  locales \
  initramfs-tools \
  binutils \
  linux-generic \
  linux-headers-generic \
  grub-efi-amd64-signed \
  intel-microcode \
  thermald

# This is not ideal, but it should work until the apt repo gets updated.

curl -L https://github.com/t2linux/T2-Ubuntu-Kernel/releases/download/v${KVER}-${PREL}/linux-headers-${KERNEL_VERSION}_${KVER}-${PREL}_amd64.deb > /tmp/headers.deb
curl -L https://github.com/t2linux/T2-Ubuntu-Kernel/releases/download/v${KVER}-${PREL}/linux-image-${KERNEL_VERSION}_${KVER}-${PREL}_amd64.deb > /tmp/image.deb
curl -L https://cdn.discordapp.com/attachments/706581810745966653/926729551558639646/iso-firmware.deb > /tmp/firmware.deb
file /tmp/*
apt install /tmp/headers.deb /tmp/image.deb /tmp/firmware.deb

echo >&2 "===]> Info: Install window manager... "

apt-get install -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
  plymouth-theme-ubuntu-logo \
  neon-desktop

echo >&2 "===]> Info: Install Graphical installer... "

apt-get install -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
  neon-live

echo >&2 "===]> Info: Install useful applications... "

apt-get install -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
  git \
  curl \
  nano \
  make \
  gcc \
  dkms \
  iwd
  
#snap install snap-store

echo >&2 "===]> Info: Change initramfs format (for grub)... "
sed -i "s/COMPRESS=lz4/COMPRESS=gzip/g" "/etc/initramfs-tools/initramfs.conf"

echo >&2 "===]> Info: Configure drivers... "

# thunderbolt is working for me.
#printf '\nblacklist thunderbolt' >>/etc/modprobe.d/blacklist.conf

printf 'apple-bce' >>/etc/modules-load.d/t2.conf
printf '\n### apple-bce start ###\nhid-apple\nsnd-seq\napple-bce\n### apple-bce end ###' >>/etc/initramfs-tools/modules
printf '\n# display f* key in touchbar\noptions apple-ib-tb fnmode=2\n'  >> /etc/modprobe.d/apple-tb.conf
#printf '\n# delay loading of the touchbar driver\ninstall apple-ib-tb /bin/sleep 7; /sbin/modprobe --ignore-install apple-ib-tb' >> /etc/modprobe.d/delay-tb.conf

echo '
#!/usr/bin/env bash
echo "Select Touch Bar mode"
echo
echo "0: Only show F1-F12"
echo "1: Show media and brightness controls, use the fn key to switch to F1-12"
echo "2: Show F1-F12, use the fn key to switch to media and brightness controls"
echo "3: Only show media and brightness controls"
echo "4: Only show the escape key"
read tb
echo "Changing default mode ..."
echo "# display f* key in touchbar" > /etc/modprobe.d/apple-tb.conf
echo "options apple-ib-tb fnmode=$tb" >> /etc/modprobe.d/apple-tb.conf
bash -c "echo $tb > /sys/class/input/*/device/fnmode"
echo "Done!"' | tee /usr/local/bin/touchbar >/dev/null

chmod a+x /usr/local/bin/touchbar
chown root:root /usr/local/bin/touchbar


echo >&2 "===]> Info: Update initramfs... "

## Add custom drivers to be loaded at boot
/usr/sbin/depmod -a "${KERNEL_VERSION}"
update-initramfs -u -v -k "${KERNEL_VERSION}"

echo >&2 "===]> Info: Remove unused applications ... "

apt-get purge -y -qq \
  transmission-gtk \
  transmission-common \
  gnome-mahjongg \
  gnome-mines \
  gnome-sudoku \
  aisleriot \
  hitori \
  xiterm+thai \
  make \
  gcc \
  vim \
  binutils \
  linux-generic \
  linux-headers-5.4.0-28 \
  linux-headers-5.4.0-28-generic \
  linux-headers-generic \
  linux-image-5.4.0-28-generic \
  linux-image-generic \
  linux-modules-5.4.0-28-generic \
  linux-modules-extra-5.4.0-28-generic

apt-get autoremove -y

echo >&2 "===]> Info: Reconfigure environment ... "

locale-gen --purge en_US.UTF-8 en_US
printf 'LANG="C.UTF-8"\nLANGUAGE="C.UTF-8"\n' >/etc/default/locale

dpkg-reconfigure -f readline resolvconf

cat <<EOF >/etc/NetworkManager/NetworkManager.conf
[main]
plugins=ifupdown,keyfile

[ifupdown]
managed=false

[device]
wifi.scan-rand-mac-address=no
EOF
dpkg-reconfigure network-manager

echo >&2 "===]> Info: Configure Network Manager to use iwd... "
mkdir -p /etc/NetworkManager/conf.d
#my wifi doesn't work with idw, but works well with wpa_supplicant
printf '#[device]\n#wifi.backend=iwd\n' > /etc/NetworkManager/conf.d/wifi_backend.conf
#systemctl enable iwd.service

echo >&2 "===]> Info: Cleanup the chroot environment... "

truncate -s 0 /etc/machine-id
rm /sbin/initctl
dpkg-divert --rename --remove /sbin/initctl
apt-get clean
rm -rf /tmp/* ~/.bash_history
rm -rf /tmp/setup_files

umount -lf /dev/pts
umount -lf /sys
umount -lf /proc

export HISTSIZE=0
