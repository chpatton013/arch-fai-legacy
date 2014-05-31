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
```

### Configuration Files

The `configure` directory contains files with my personal minimal configuration.
You can either modify the provided files or specify a different configuration
directory.

| Filename   | Importance | Description |
|------------|------------|-------------|
| passphrase | Required   | Root volume passphrase. |
| password   | Required   | Root user password. |
| hostname   | Required   | Valid single-word hostname. (ex: `archbox`) |
| locale     | Required   | Valid locale. (ex: `en_US.UTF8`) |
| timezone   | Required | Valid timezone (ex: `America/Los_Angeles`) |
| modules    | Optional   | Whitespace-delimited list of kernel modules. |
| hooks      | Optional   | Whitespace-delimited list of boot hooks. |
| packages   | Optional   | Whitespace-delimited list of packages.<br />Must be recognized by `pacman`. |
| groups     | Optional   | Whitespace-delimited list of groups. |
| users      | Optional   | Properly formated, newline-delimited list of users.<br />`name=$name shell=$shell gid=$gid [ groups=$group1,$group2,... ]` |
| files      | Optional   | A directory of files that will be copied over the existing root filesystem. |
| units      | Optional   | Whitespace-delimited list of systemd units to enable on boot. |

### Filesystem Schema

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
