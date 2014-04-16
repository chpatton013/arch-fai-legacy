#!/usr/bin/env bash

###############################################################################
# Utility functions.
###############################################################################

_print() {
   if [ "_$volume" != "_quiet" ]; then
      echo "$@"
   fi
}

_header() {
   _print "$@"
   _print "########################################"
}

_title() {
   _print "########################################"
   _print "# $@"
   _print "########################################"
   _print
}

_error() {
   echo "$@" Setup cannot continue. Exiting... >&2
   exit 1
}

_perform() {
   local command="$@"

   if [ "_$volume" = "_verbose" ]; then
      echo "$command"
   fi

   if [ "$dryrun" ]; then
      return
   fi

   if read -t 0; then
      cat | $command
   else
      $command
   fi
}

_replace() {
   local search="$1"
   local replace="$2"
   local file="$3"

   if `grep -q "$search" "$file"`; then
      if [ "_$volume" = "_verbose" ]; then
         echo sed -i s#"$search"#"$replace"# "$file"
      fi
      if [ ! "$dryrun" ]; then
         sed -i s#"$search"#"$replace"# "$file"
      fi
      return
   fi

   if [ "_$volume" = "_verbose" ]; then
      echo echo "$replace" '>>' "$file"
   fi
   if [ ! "$dryrun" ]; then
      echo "$replace" >> "$file"
   fi
}

_map() {
   local list="$1"
   local command="$2"

   for item in "$list"; do
      $command $item
   done
}

###############################################################################
# Specific command wrappers.
###############################################################################

_parted() {
   _perform parted --script --align optimal -- "$@"
}

_mklabel() {
   local disk="$1"

   _parted "$disk" mklabel gpt
}

_mkpart() {
   local disk="$1"
   local part="$2"
   local start="$3"
   local end="$4"
   local name="$5"
   local flag="$6"

   _parted "$disk" mkpart primary "$start" "$end"
   _parted "$disk" name "$part" "$name"

   if [ "$flag" ]; then
      _parted "$disk" set "$part" "$flag" on
   fi
}

_make_key() {
   local keyfile="$1"

   _perform dd if=/dev/random of="$keyfile" bs=512 count=4 iflag=fullblock
   _perform chmod 400 "$keyfile"
}

_add_key() {
   local keypath="$1"
   local lvm_device="$2"
   local cryptsetup="cryptsetup -q --key-file $keypath"

   if [ "_$volume" = "_verbose" ]; then
      echo "echo $luks_pass | $cryptsetup luksAddKey $lvm_device"
   fi

   if [ "$dryrun" ]; then
      return
   fi

   echo "$luks_pass" | $cryptsetup luksAddKey "$lvm_device"
}

_format() {
   local device="$1"

   _perform mkfs.ext4 -q "$device"
}

_mount() {
   local device="$1"
   local directory="$2"

   _perform mkdir -p "$directory"
   _perform mount "$device" "$directory"
}

_pacstrap() {
   _perform mkdir -p "$pkg_cache_dir"
   _perform pacstrap "$mount_point" --cachedir "$pkg_cache_dir" "$@"
}

_chroot() {
   _perform arch-chroot "$mount_point" "$@"
}

_nspawn() {
   _perform systemd-nspawn --directory="$mount_point" "$@"
}

_add_user() {
   local user="$1"
   local shell="$2"
   local primary_group="$3"
   shift 3
   local secondary_groups="$@"

   if [ ! "$user" ]; then
      return
   fi

   local command="useradd -mU -R $mount_point"
   if [ "$shell" ]; then
      command="$command -s $shell"
   fi
   if [ "$primary_group" ]; then
      command="$command -g $primary_group"
   fi
   if [ "$secondary_groups" ]; then
      command="$command -G $secondary_groups"
   fi
   command="$command $user"

   _perform "$command"
}

###############################################################################
# Configuration functions.
###############################################################################

_parse_cmd_line() {
   while getopts "hdvqrucp:" opt; do
      case "$opt" in
      h)
         _usage
         exit 0
         ;;
      d)
         dryrun='echo'
         ;;
      v)
         if [ "$volume" ]; then
            _error "Only a single 'verbose' or 'quiet' flag can be specified."
         fi
         volume='verbose'
         ;;
      q)
         if [ "$volume" ]; then
            _error "Only a single 'verbose' or 'quiet' flag can be specified."
         fi
         volume='quiet'
         ;;
      r)
         if [ "$random" ]; then
            _error "Only a single 'random' or 'urandom' flag can be specified."
         fi
         random='random'
         ;;
      u)
         if [ "$random" ]; then
            _error "Only a single 'random' or 'urandom' flag can be specified."
         fi
         random='urandom'
         ;;
      c)
         if [ "$conf_dir" ]; then
            _error "Only one configuration directory can be specified."
         fi
         conf_dir="$OPTARG"
         ;;
      p)
         if [ "$pkg_cache_dir" ]; then
            _error "Only one package cache directory can be specified."
         fi
         pkg_cache_dir="$OPTARG"
         ;;
      \?)
         _usage
         exit 1
         ;;
      esac
   done
}

_usage() {
   echo "Usage: $filename [OPTIONS]"
   echo "Options:"
   echo "   -h             Display this help message and exit."
   echo "   -d             Do not actually run commands (dryrun)."
   echo "   -v             Run in verbose mode."
   echo "   -q             Run in quiet mode."
   echo "   -r             Randomize disk contents using /dev/random."
   echo "   -u             Randomize disk contents using /dev/urandom."
   echo "   -c <directory> Specify a different configuration directory."
   echo "   -p <directory> Specify a different package cache directory."
}

_validate_cmd_line() {
   if [ ! "$conf_dir" ]; then
      conf_dir=./configure
   fi

   if [ ! "$pkg_cache_dir" ]; then
      pkg_cache_dir=./package_cache
   fi

   if [ ! -d "$conf_dir" ]; then
      echo "Configuration directory '$conf_dir' was not found." >&2
      exit 1
   fi

   if [ ! -f "$conf_dir"/parameters.bash ]; then
      echo "'parameters.bash' is missing from '$conf_dir'." >&2
      exit 1
   fi
}

_validate_config() {
   if [ ! -e "$disk" ]; then
      _error "$disk" does not exist.
   fi

   if [ ! "$luks_pass" ]; then
      _error luks_pass must be set.
   fi

   if [ ! "$root_pass" ]; then
      _error root_pass must be set.
   fi
}

_network() {
   _header Confirming internet connection...

   if ping -c 1 www.google.com 2>&1 >/dev/null; then
      _print "# Internet connection present."
   else
      _error "# No internet connection."
   fi

   _print
}

###############################################################################
# Partitioning functions.
###############################################################################

_randomize() {
   if [ ! "$random" ]; then
      return
   fi

   _header Randomizing disk.
   _perform dd if=/dev/"$random" of="$disk" bs=32M iflag=fullblock
   _print
}

_partition() {
   _header Creating physical partition table.

   _mklabel "$disk"
   _mkpart "$disk" 1 2 4 grub bios_grub
   _mkpart "$disk" 2 4 204 boot boot
   _mkpart "$disk" 3 204 -1 luks lvm

   _print
}

_luks_format() {
   local device="${disk}3"
   local keyfile='luks.key'
   local cryptsetup="cryptsetup -q --key-file $keyfile"

   _header Formatting luks container.

   _make_key "$keyfile"

   _perform "$cryptsetup" luksFormat "$device"
   _perform "$cryptsetup" luksOpen "$device" "$luks_volume"

   _add_key "$keyfile" "$device"
   _perform cryptsetup -q luksRemoveKey "$device" "$keyfile"

   _perform rm "$keyfile"

   _print
}

_boot_format() {
   local device="${disk}2"

   _header Formatting and mounting boot partition.

   _format "$device"
   _mount "$device" "$mount_point/boot"

   _print
}

_lvm_partition() {
   local physical_volume="/dev/mapper/$luks_volume"

   _header Creating LVM partition table.

   _perform pvcreate "$physical_volume"
   _perform vgcreate "$lvm_volume" "$physical_volume"
   _perform lvcreate --name root --size 4G "$lvm_volume"
   _perform lvcreate --name home --size 4G "$lvm_volume"
   _perform lvcreate --name tmp --size 2G "$lvm_volume"
   _perform lvcreate --name var --size 2G "$lvm_volume"
   _perform lvcreate --name swap --size 2G "$lvm_volume"

   _print
}

_lvm_format() {
   local label="$1"
   local device="/dev/mapper/$lvm_volume-$label"

   _header Formatting and mounting "$label" LVM container.

   if [ "_$label" = '_swap' ]; then
      _perform mkswap "$device"
   elif [ "_$label" = '_root' ]; then
      _format "$device"
      _mount "$device" "$mount_point"
   else
      _format "$device"
      _mount "$device" "$mount_point/$label"
   fi

   _print
}

###############################################################################
# System-installation functions.
###############################################################################

_install() {
   _header Installing system.
   _pacstrap base grub
   _print
}

_fstab() {
   _header Generating fstab.

   if [ "_$volume" = '_verbose' ]; then
      echo "genfstab -U -p $mount_point >> $mount_point/etc/fstab"
   fi

   if [ ! "$dryrun" ]; then
      genfstab -U -p "$mount_point" >> "$mount_point/etc/fstab"
   fi

   _print
}

_passwd() {
   _header Setting root password.

   if [ "_$volume" = '_verbose' ]; then
      echo "echo root:$root_pass | chpasswd --root $mount_point"
   fi

   if [ ! "$dryrun" ]; then
      echo "root:$root_pass" | chpasswd --root "$mount_point"
   fi

   _print
}

_mkinitcpio() {
   local mkinitcpio_file="$mount_point/etc/mkinitcpio.conf"

   _header Building initial ramdisk.

   if [ "$modules" ]; then
      _replace "^\s*MODULES=.*$" "MODULES=\\\"$modules\\\"" "$mkinitcpio_file"
   fi
   if [ "$hooks" ]; then
      _replace "^\s*HOOKS=.*$" "HOOKS=\\\"$hooks\\\"" "$mkinitcpio_file"
   fi
   _chroot mkinitcpio -p linux

   _print
}

_bootloader() {
   local cryptdevice="${disk}3:$luks_volume"
   if [ "$ssd" ]; then
      cryptdevice="$cryptdevice:allow-discards"
   fi
   local root="/dev/mapper/$lvm_volume-root"

   local cmdline="cryptdevice=$cryptdevice root=$root"

   local cmdline_search="^\s*GRUB_CMDLINE_LINUX=.*$"
   local cmdline_replace="GRUB_CMDLINE_LINUX=\\\"$cmdline\\\""
   local disable_search="^\s*GRUB_DISABLE_LINUX_UUID=.*$"
   local disable_replace="GRUB_DISABLE_LINUX_UUID=true"

   local grub_file="$mount_point/etc/default/grub"

   _header Installing bootloader.

   _chroot grub-install --recheck "$disk"
   _replace "$cmdline_search" "$cmdline_replace" "$grub_file"
   _replace "$disable_search" "$disable_replace" "$grub_file"
   _chroot grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null

   _print
}

###############################################################################
# System-configuration functions.
###############################################################################

_packages() {
   local file="$conf_dir"/packages
   if [ ! -s "$file" ]; then
      return
   fi

   local packages=`cat "$file" | tr '[:space:]' ' '`
   if [ ! "$packages" ]; then
      return
   fi

   _header Installing additional packages.
   _pacstrap "$packages"
   _print
}

_groups() {
   local file="$conf_dir"/groups
   if [ ! -s "$file" ]; then
      return
   fi

   local groups=`cat "$file" | tr '[:space:]' ' '`
   if [ ! "$groups" ]; then
      return
   fi

   _header Creating groups.
   _map "$groups" "_perform groupadd --root $mount_point"
   _print
}

_users() {
   local file="$conf_dir/users"
   if [ ! -s "$file" ]; then
      return
   fi

   local users=`cat "$file" | tr '[:blank:]' ' '`
   if [ ! "$users" ]; then
      return
   fi

   _header Creating users.
   _map "$users" _add_user
   _print
}

_system_config() {
   _header Configuring system settings.

   _nspawn localectl set-locale "\"LANG=$locale\""
   _nspawn hostnamectl set-hostname "$hostname"
   _nspawn timedatectl set-timezone "$timezone"
   _nspawn timedatectl set-local-rtc false

   _print
}

_units() {
   local file="$conf_dir/units"
   if [ ! -s "$file" ]; then
      return
   fi

   local units=`cat "$file" | tr '[:space:]' ' '`
   if [ ! "$units" ]; then
      return
   fi

   _header Enabling systemd units.
   _map "$units" "_nspawn systemctl enable"
   _print
}

_cleanup() {
   _header Dismounting file systems and closing containers.

   _perform umount -R "$mount_point"

   _perform lvchange -an "$lvm_volume/root"
   _perform lvchange -an "$lvm_volume/home"
   _perform lvchange -an "$lvm_volume/swap"
   _perform lvchange -an "$lvm_volume/tmp"
   _perform lvchange -an "$lvm_volume/var"
   _perform vgchange -an "$lvm_volume"

   _perform cryptsetup luksClose "$luks_volume"

   _print
}

