_jailer.sh_ is a wrapper script for managing iocage jails on FreeBSD. It can update and upgrade individual or all jails and their ports. It can create jails and has a nice templating system for them (flavours).

Jost copy _jailer.sh_ anywhere in your path and the „jailer" direcory to _/usr/local/etc_. See __/usr/local/etc/jailer/flavours_ for a sample jail. You can put system files in the flavours that should be copied to the jail, you can specify fstab entries that should be enabled in the jail and you can define programs that will be installed in the jail. See _jail.cfg_ for an example for iocage properties that are set when the jail will be created.

# USAGE:

  ```sh
Usage: jailer.sh command {params}

bootstrap         Sets up  the jail host for usage with iocage and jailer.sh.
  -p ZPOOL            Name of the zpool that iocage should use.
update            Updates a jails ports.
  [-j JAIL]           Jail that should be updated. Otherwise all jails will be processed.
  [-s]                Also update FreeBsd in jail(s).
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
