#!/bin/bash

. ./functions.bash

###############################################################################
# Configuration.
###############################################################################

filename=`basename $0`
dryrun=''
volume=''
random=''
conf_dir=''
pkg_cache_dir=''

_parse_cmd_line "$@"
_validate_cmd_line

. "$conf_dir"/parameters.bash

_validate_config

###############################################################################
# System installation.
###############################################################################

_title Installing Arch Linux system.

_network

_randomize
_partition
_luks_format
_lvm_partition

_lvm_format root
_boot_format
_lvm_format home
_lvm_format tmp
_lvm_format var
_lvm_format swap

_install
_fstab
_passwd
_mkinitcpio
_bootloader

_packages
_groups
_users
_system_config
_units

_cleanup

_title Arch Linux system installed.

