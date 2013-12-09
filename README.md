Arch-FAI
===
A Fully-Automated Installer for ArchLinux systems.

What does it do?
===
The FAI builds an ArchLinux system with the following series of commands:
* Partition the specified disk using GPT, LVM, and LUKS.
* Install a base ArchLinux system.
* Set basic system settings (locale, hostname, timezone, etc).
* Create a modified ramdisk with hooks needed for LVM and LUKS.
* Install and configure GRUB to decrypt the root LUKS container on boot.
* Install additional packages.
* Add users and groups.
* Enable systemctl units.

What do you need to do to use it?
===
A series of files must be edited to make the FAI useful. The `configure`
directory contains files with the default / minimal configuration. Changing the
configuration directory can be accomplished by passing the `conf_dir` parameter
on the command line as an environment variable:
(`conf_dir=/path/to/dir bash install.bash`)

configure/parameters.bash
---
A shell script that defines various configuration variables. Parameters are
segregated by how important it is to change them. Installation will not be
performed if the important parameters are not modified.

configure/packages
---
A whitespace-delimited list of packages to install.
* All package names must be identifiable by `pacman`.
* This step is optional. However, you will have next to nothing installed by
default.

configure/groups
---
A whitespace-delimited list of groups to add to the system.
* All groups must be unique.
* This step is optional.

configure/users
---
A newline-delimited list of user definitions in the following format:
`$username $shell $primary_group $secondary_groups`
* `$username` must be unique.
* `$shell` must be an absolute path.
* `$secondary_groups` must be a comma-delimited list.
* All groups must exist.
* Technically, this step is optional &mdash; you CAN use the root user account.
  That being said, it is strongly recommended that you create a user account.

configure/units
---
A whitespace-delimited list of units to enable with systemd.
* This step is optional.

Future development
===
* Custom systemd unit definitions.

