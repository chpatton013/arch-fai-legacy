#!/bin/bash

###############################################################################
# Important parameters.
###############################################################################

# Physical device to install system to.
disk='/dev/sda'
# Passphrase for root luks container.
luks_pass='password'
# Password for root user.
root_pass='password'

###############################################################################
# Not-so-important parameters.
###############################################################################

# System configuration.
luks_volume='LuksVol'
lvm_volume='LvmVol'
locale="en_US.utf8"
hostname="archbox"
timezone="America/Los_Angeles"

# Ramdisk configuration.
modules='virtio virtio_blk virtio_pci virtio_net'
hooks='base udev autodetect modconf block keymap encrypt lvm2 filesystems keyboard shutdown fsck usr'

# Bootloader configuration
ssd='true'

# Installer configuration.
mount_point="/mnt/archbox"

