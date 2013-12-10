#!/bin/bash

###############################################################################
# Utility functions.
###############################################################################

_print() {
   if [ "_$volume" != "_quiet" ]; then
      echo "$@"
   fi
}

_buffer() {
   if [ "_$volume" = "_verbose" ]; then
      echo
   fi
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

   if [ $dryrun ]; then
      return
   fi

   if read -t 0; then
      cat | $command
   else
      $command
   fi
}

_network() {
   _print Confirming internet connection...

   if ping -c 1 www.google.com 2>&1 >/dev/null; then
      _print Internet connection present.
   else
      _error No internet connection.
   fi

   _buffer
}

_mount() {
   local device="$1"
   local directory="$2"

   _perform mkdir -p "$directory"
   _perform mount "$device" "$directory"
}

_umount() {
   _print Dismounting filesystems on "$@"
   _perform umount -R "$@"
   _buffer
}

_replace() {
   local search="$1"
   local replace="$2"
   local file="$3"

   if [ "_$volume" = "_verbose" ]; then
      echo grep -q \"$search\" \"$file\" '&&' \
       sed -i \"s/$search/$replace\" \"$file\" '||' \
       echo \"$replace\" '>>' \"$file\"
   fi

   if [ $dryrun ]; then
      return
   fi

   grep -q "$search" "$file" && sed -i "s/$search/$replace" "$file" ||
    echo "$replace" >> "$file"
}

_map() {
   local list="$1"
   local command="$2"

   for item in "$list"; do
      $command $item
   done
}

_pacstrap() {
   _perform pacstrap /mnt "$@"
}

###############################################################################
# Partitioning functions.
###############################################################################

_parted() {
   _perform parted --script --align optimal -- "$@"
}

_mkpart() {
   local disk="$1"
   local part="$2"
   local name="$3"
   local start="$4"
   local end="$5"
   local flag="$6"

   _parted "$disk" mkpart primary "$start" "$end"
   _parted "$disk" name "$part" "$name"
   _parted "$disk" set "$part" "$flag" on
}

_partition() {
   _print Creating physical partition table.

   _parted "$disk" mklabel gpt
   _mkpart "$disk" 1 grub 2 4 bios_grub
   _mkpart "$disk" 2 boot 4 204 boot
   _mkpart "$disk" 3 lvm 204 -1 lvm

   _buffer
}

_boot_format() {
   local device="${disk}2"

   _print Formatting and mounting boot partition.

   _perform mkfs.ext4 -q $device
   _mount $device /mnt/boot

   _buffer
}

_lvm_partition() {
   _print Creating lvm partition table.

   _perform pvcreate --force "${disk}3"
   _perform vgcreate --force "$lvm_volume" "${disk}3"
   _perform lvcreate --size 8G "$lvm_volume" --name rootvol
   _perform lvcreate --size 2G "$lvm_volume" --name homevol
   _perform lvcreate --size 2G "$lvm_volume" --name swapvol
   _perform lvcreate --size 2G "$lvm_volume" --name tmpvol
   _perform lvcreate --extents 100%FREE "$lvm_volume" --name varvol

   _buffer
}

###############################################################################
# Cryptography functions.
###############################################################################

_randomize() {
   _print Randomizing disk.
   _perform dd bs=32M if=/dev/random of="$disk"
   _buffer
}

_make_key() {
   local keyfile="$1"
   _perform dd if=/dev/random of="$keyfile" bs=512 count=4 iflag=fullblock
   _perform chmod 400 "$keyfile"
}

_crypttab() {
   if [ "_$volume" = "_verbose" ]; then
      echo echo "\"$@\"" '>>' /mnt/etc/crypttab
   fi

   if [ $dryrun ]; then
      return
   fi

   echo "$@" >> /mnt/etc/crypttab
}

_luks_root_format() {
   local lvm_device="/dev/$lvm_volume/rootvol"
   local luks_device="/dev/mapper/root"
   local cryptsetup="cryptsetup -q --key-file root.key"

   _print Formatting and mounting root luks container.

   _make_key root.key
   _perform $cryptsetup luksFormat "$lvm_device"
   _perform $cryptsetup open --type luks "$lvm_device" root

   if [ "_$volume" = "_verbose" ]; then
      echo echo "\"$luks_pass\"" '|' $cryptsetup luksAddKey "$lvm_device"
   fi

   if [ ! $dryrun ]; then
      echo "$luks_pass" | $cryptsetup luksAddKey "$lvm_device"
   fi

   _perform $cryptsetup luksRemoveKey "$lvm_device" root.key
   _perform rm root.key

   _perform mkfs.ext4 -q $luks_device
   _perform mount $luks_device /mnt
   _perform mkdir -p /mnt/etc/cryptkeys
   _perform touch /mnt/etc/crypttab

   _buffer
}

_luks_swap_format() {
   local keyfile="/etc/swap.key"
   local lvm_device="/dev/$lvm_volume/swapvol"
   local luks_device="/dev/mapper/swap"
   local cryptsetup="_perform cryptsetup -q --key-file /mnt$keyfile"

   _print Formatting and mounting swap luks container.

   _make_key "/mnt$keyfile"
   $cryptsetup luksFormat "$lvm_device"
   $cryptsetup open --type luks "$lvm_device" swap
   _crypttab "swap\t$luks_device\t$keyfile\tswap,noearly"
   _perform mkswap $luks_device

   _buffer
}

_luks_format() {
   local label="$1"
   local keyfile="/etc/${label}.key"
   local lvm_device="/dev/$lvm_volume/${label}vol"
   local luks_device="/dev/mapper/$label"
   local cryptsetup="_perform cryptsetup -q --key-file /mnt$keyfile"

   _print Formatting and mounting "$label" luks container.

   _make_key "/mnt$keyfile"
   $cryptsetup luksFormat "$lvm_device"
   $cryptsetup open --type luks "$lvm_device" "$label"
   _crypttab "$label\t$luks_device\t$keyfile"

   _perform mkfs.ext4 -q $luks_device
   _mount $luks_device "/mnt/$label"

   _buffer
}

###############################################################################
# System-installation functions.
###############################################################################

_install() {
   _print Installing system.
   _pacstrap base grub
   _buffer
}

_fstab() {
   _print Generating fstab.

   if [ "_$volume" = "_verbose" ]; then
      echo genfstab -U -p /mnt '>>' /mnt/etc/fstab
   fi

   if [ ! "$dryrun" ]; then
      genfstab -U -p /mnt >> /mnt/etc/fstab
   fi

   _buffer
}

_chroot() {
   _perform arch-chroot /mnt "$@"
}

_system_config() {
   _print Configuring system settings.

   _chroot localectl set-locale "\"LANG=$locale\""
   _chroot hostnamectl set-hostname "$hostname"
   _chroot timedatectl set-timezone "$timezone"
   _chroot timedatectl set-local-rtc false
   _chroot systemctl enable dhcpcd.service

   _buffer
}

_passwd() {
   _print Setting root password.

   if [ "_$volume" = "_verbose" ]; then
      echo echo "\"root:$root_pass\"" '|' chpasswd --root /mnt
   fi

   if [ ! "$dryrun" ]; then
      echo "root:$root_pass" | chpasswd --root /mnt
   fi

   _buffer
}

_mkinitcpio() {
   local hooks1='base udev autodetext modconf block'
   local hooks2='keymap encrypt lvm2 filesystems'
   local hooks3='keyboard shutdown fsck usr'
   local hooks="$hooks1 $hooks2 $hooks3"

   _print Building initial ramdisk.

   if [ "$modules" ]; then
      _replace "^MODULES=.*$" "MODULES=\"$modules\"" /mnt/etc/mkinitcpio.conf
   fi

   _replace "^HOOKS=.*$" "HOOKS=\"$hooks\"" /mnt/etc/mkinitcpio.conf
   _chroot mkinitcpio -p linux

   _buffer
}

_bootloader() {
   local cryptdevice="/dev/mapper/$lvm_volume-rootvol:root root=/dev/mapper/root rw"
   local search="^GRUB_CMD_LINE_LINUX=.*$"
   local replace="GRUB_CMDLINE_LINUX=\"crtpydevice=$cryptdevice\""

   _print Installing bootloader.

   _chroot grub-mkconfig -o /boot/grub/grub.cfg
   _replace "$search" "$replace" /mnt/etc/default/grub
   _chroot grub-mkconfig -o /boot/grub/grub.cfg
   _chroot grub-install --recheck "$disk"

   _buffer
}

###############################################################################
# System-configuration functions.
###############################################################################

_adduser() {
   local user=
   local shell=
   local primary_group=
   local secondary_groups=

   if [ ! "$user" ]; then
      return
   fi

   local command="useradd -mU -R /mnt"
   if [ "$shell" ]; then
      command+=" -s $shell"
   fi
   if [ "$primary_group" ]; then
      command+=" -g $primary_group"
   fi
   if [ "$secondary_groups" ]; then
      command+=" -G $secondary_groups"
   fi
   command+=" $user"

   _perform "$command"
}

_packages() {
   local file="$conf_dir/packages"

   if [ ! -e $file ]; then
      return
   fi

   _print Installing additional packages.

   local packages=`cat "$file" | tr '[:space:]' ' '`
   if [ "$packages" ]; then
      _pacstrap "$packages"
   fi

   _buffer
}

_groups() {
   local file="$conf_dir/groups"

   if [ ! -e $file ]; then
      return
   fi


   _print Creating groups.

   local groups=`cat "$file" | tr '[:space:]' ' '`
   _map "$groups" "_perform groupadd --root /mnt"

   _buffer
}

_users() {
   local file="$conf_dir/users"

   if [ ! -e $file ]; then
      return
   fi

   _print Creating users.

   local users=`cat "$file" | tr '[:blank:]' ' '`
   _map "$users" "_adduser"

   _buffer
}

_units() {
   local file="$conf_dir/users"

   if [ ! -e $file ]; then
      return
   fi

   _print Enabling systemd units.

   local units=`cat "$file" | tr '[:space:]' ' '`
   _map "$units" "_chroot systemctl enable"

   _buffer
}

