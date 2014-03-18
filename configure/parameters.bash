#!/bin/bash

###############################################################################
# Important parameters.
###############################################################################

# Physical block device to install system to.
disk='/dev/sdx'
# Passphrase for root luks container.
luks_pass=''
# Password for root user.
root_pass=''

###############################################################################
# Not-so-important parameters.
###############################################################################

# System configuration.
lvm_volume='arch-box'
locale="en_US.utf8"
hostname="arch-box"
timezone="America/Los_Angeles"
# Ramdisk configuration.
modules='virtio virtio_blk virtio_pci virtio_net'

