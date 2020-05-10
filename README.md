_jailer.sh_ is a wrapper script for managing iocage jails on FreeBSD. It can update and upgrade individual or all jails and their ports. It can create jails and has a nice templating system for them (flavours).

Jost copy _jailer.sh_ anywhere in your path and the „jailer" direcory to _/usr/local/etc_. See _/usr/local/etc/jailer/flavours_ for a sample jail. You can put system files in the flavours that should be copied to the jail, you can specify fstab entries that should be enabled in the jail and you can define programs that will be installed in the jail. See _jail.cfg_ for an example for iocage properties that are set when the jail will be created.

## Usage

  ```sh
Usage: jailer.sh command {params}

bootstrap         Sets up  the jail host for usage with iocage and jailer.sh.
  -p ZPOOL            Name of the zpool that iocage should use.
update            Updates a jails ports.
  [-j JAIL]           Jail that should be updated. Otherwise all jails will be processed.
  [-s]                Also update FreeBSD in jail(s).
upgrade           Upgrades a jails base systems and its ports to given FreeBSD release.
  [-j JAIL]           Jail that should be upgraded. Otherwise all jails will be processed.
  [-r RELEASE]    Release that should be used for upgrades.
create            Creates a jail.
  -n NAME             Name of the jail that should be created.
  [-r RELEASE]        Release that should be used for jail creation
  [-p PROPERTIES]     iocage properties that should be applied
  [-f FLAVOUR]        Flavour that should be applied
help              Show this screen
  ```

## Flavours

Flavours are skeleton directories for jails with the ability to configure the jail. The flavours live under _/usr/local/etc/jailer/flavours_ by default.

A flavour can consist of the following parts (but all of them are optional).

### jail.cfg

The jail config contains configuration parametres of iocage and uses it for the jail. These can be eg. networking settings or autoboot.

A simple _jail.cfg_ can look like this:
  ```sh
## jail.cfg
boot=on
allow_raw_sockets="1"
ip4_addr=10.0.3.254/24
vnet=on
  ```
### pkgs.json

The _pkgs.json_ file defines the packages that should be installed after jail creation.

A _pkgs.json_ can look like this:

  ```json
{
  pkgs": [
    "portmaster",
    "ccache",
    "vim-console"
  ]
}
  ```

### fstab.cfg

The _fstab.cfg_ defines the entries that should be added to the fstab of the jail. You must define them in the view from inside the jails filesystem (like you would do with _iocage fstab -a_ command).

The file will be parsed and the neccessary mountpoints are created automatically.

A sample file looks like this:

   ```fstab
/var/cache/ccache /var/cache/ccache nullfs rw 0 0
/iocage/ports /usr/ports nullfs rw 0 0
   ```

It's reccomended to have at least the iocage ports tree and the ccache cache in there.

### bootstrap.sh

_bootstrap.sh_ is a simple shell script that will be run from inside the jail after jail creation. You can put anything in there to modify the resulting system like adding aliases, add rc.conf entries, create users and so on.

A sample file looks like this:

  ```sh
#!/bin/sh

## Disable adjkerntz in jail
sed -i .tmp -e '/adjkerntz/ s/^#*/#/' /etc/crontab

## Disable crash dumps
sysrc dumpdev="NO"

## Set alias for root to you mail address
echo root: user@example.org >> /etc/aliases

  ```

### Other files and directories

All other files and directories that are contained in the flavour directory will just be copied over to the jails root (/).

You can put configuration files, certificates, home directories, scripts and all other stuff here that you want to have in a jail.
