# Arch-FAI

A Fully-Automated Installer for ArchLinux systems.

## What does it do?

Arch-FAI builds an ArchLinux system with nearly no human interaction.

The target system will use logical volume management under per-container
encryption.

After installation, user defined configuration occurs on first login (again,
unattended after initial configuration).

## What do you need to do to use it?

A series of files must be edited to make the FAI useful:

* [Configuration Files](#configuration-files)
* [Filesystem Schema](#filesystem-schema)

Command-line parameters can be found in the usage message:
```
Usage: arch-fai [ <Optional Arguments> ] [ <Overridable Arguments> ] <Required Arguments>
   -h                Display this help message and exit.

Optional Arguments:
   -s                Is the raw device a solid state drive? (default false)
   -r                Randomize raw device contents using /dev/random.
   -u                Randomize raw device contents using /dev/urandom.

Overridable Arguments:
   -b                System uses BIOS. (default EFI)
   -a <architecture> Hardware architecture. (default to result of `uname -m`)
   -L <device>       Logical volume group name. (default 'LvGroup')
   -M <mount point>  Installation mount point. (default '/mnt/archbox')
   -C <config dir>   Configuration file directory. (default './configure')

Required Arguments:
   -D <device>       Raw device (disk) path. Must be a block device.
   -P <passphrase>   Root volume passphrase.
   -W <password>     Root user password.
```

### Configuration Files

The `configure` directory contains files with my personal minimal configuration.
You can either modify the provided files or specify a different configuration
directory.

#### configure/modules

* **REQUIRED**
* Whitespace-delimited list of kernel modules.

#### configure/hooks

* **REQUIRED**
* Whitespace-delimited list of boot hooks.

#### configure/hostname

* **REQUIRED**
* Valid single-word hostname. (ex: `archbox`)

#### configure/locale

* **REQUIRED**
* Valid locale. (ex: `en_US.UTF8`)

#### configure/timezone

* **REQUIRED**
* Valid timezone (ex: `America/Los_Angeles`)

#### configure/packages

* **OPTIONAL**
* Whitespace-delimited list of packages.
* Must be recognized by `pacman`.

#### configure/groups

* **OPTIONAL**
* Whitespace-delimited list of groups.

#### configure/users

* **OPTIONAL**
* Properly formated, newline-delimited list of users.
* Format: `name=$name shell=$shell gid=$gid [ groups=$group1,$group2,... ]`

#### configure/files

* **OPTIONAL**
* A directory of files that will be copied over the existing root filesystem.

#### configure/units

* **OPTIONAL**
* Whitespace-delimited list of systemd units to enable on boot.

## Filesystem Schema

Additionally, the filesystem schema can be modified in `scripts/variables`.
This is not recommended, and can lead to some subtle problems in your new
system.

If you feel the need to make changes here, follow these rules:

* `root` and `swap` must be present in `LOGICAL_VOLUMES`.
* All other logical volumes must be present in both `LOGICAL_VOLUMES` **AND** `LUKS_CONTAINERS`.
* All elements in `LOGICAL_VOLUMES` must have a corresponding `LOGICAL_VOLUME_*` definition.
   * `name`, `size`, `fs_type`, and `mount` must be present in every definition.
* All elements in `TMPFS_DIRECTORIES` must have a corresponding `TMPFS_DIRECTORY_*` definition.
   * `size`  and `mount` must be present in every definition.
* Do not edit anything else!
