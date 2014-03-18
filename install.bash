#!/bin/bash

###############################################################################
# Commandline Parsing.
###############################################################################

display_help=''
dryrun=''
volume=''
randomize=''
conf_dir=''

while getopts "hdvqrc:" opt; do
   case "$opt" in
   h)
      display_help='true'
      exit_status=0
      ;;
   d)
      dryrun='echo'
      ;;
   v)
      if [ "$volume" ]; then
         echo "Only a single 'verbose' or 'quiet' flag can be specified." >&2
         exit 1
      fi
      volume='verbose'
      ;;
   q)
      if [ "$volume" ]; then
         echo "Only a single 'verbose' or 'quiet' flag can be specified." >&2
         exit 1
      fi
      volume='quiet'
      ;;
   r)
      randomize='true'
      ;;
   c)
      if [ "$conf_dir" ]; then
         echo Only one configuration directory can be specified. >&2
         exit 1
      fi
      conf_dir="$OPTARG"
      ;;
   \?)
      display_help='true'
      exit_status=1
      ;;
   esac
done

if [ "$display_help" ]; then
   echo "Usage $0 [OPTIONS]"
   echo "Options:"
   echo "   -h                      Display this help message and exit."
   echo "   -d                      Do not actually run commands (dryrun)."
   echo "   -v                      Run in verbose mode."
   echo "   -q                      Run in quiet mode."
   echo "   -r                      Randomize disk contents."
   echo "   -c <config-directory>   Specify a different configuration directory."
   exit $exit_status
fi

if [ ! "$conf_dir" ]; then
   conf_dir='./configure'
fi

###############################################################################
# Configuration validation.
###############################################################################

if [ ! -d "$conf_dir" ]; then
   echo "Configuration directory '$conf_dir' was not found." >&2
   exit 1
fi

if [ ! -f "$conf_dir/parameters.bash" ]; then
   echo "'parameters.bash' is missing from '$conf_dir'." >&2
   exit 1
fi

. "$conf_dir/parameters.bash"
. ./functions.bash

if [ ! -e "$disk" ]; then
   _error "$disk" does not exist.
elif [ ! -b "$disk" ]; then
   _error "$disk" is not a suitable installation destination.
fi

if [ ! "$luks_pass" ]; then
   _error luks_pass must be set.
fi

if [ ! "$root_pass" ]; then
   _error root_pass must be set.
fi

###############################################################################
# System installation.
###############################################################################

_print Installing Arch Linux system.
_buffer

_network

if [ "$randomize" ]; then
   _randomize
fi

_partition
_lvm_partition

_luks_root_format
_boot_format
_luks_swap_format
_luks_format home
_luks_format var
_luks_format tmp

_install
_fstab
_system_config
_passwd
_mkinitcpio
_bootloader

_packages
_groups
_users
_units

_cleanup

_print Arch Linux system installed.

