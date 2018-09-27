#!/usr/bin/env sh

## jailer.sh
# Update or upgrade all iocage jails on a host.

# Copyright 2018 Christian Baer
# http://github.com/chrisb86/

# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:

# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

iocage_ports_dir="/iocage/ports"
iocage_zfs_dataset="zroot/iocage/jails"
freebsd_release="11.2-RELEASE"
TODAY=$(date +%Y-%m-%d)

jailer=`basename -- $0`
iocage_jail_dir=`zfs get mountpoint $iocage_zfs_dataset | cut -d " " -f 5`

# Show help screen
# Usage: help exitcode
help () {
  echo "Usage: $jailer command {params}"
  echo
  echo "update     Updates all jails base systems and their ports"
  echo "upgrade    Upgrades all jails base systems and their ports to $freebsd_release"
  echo "help       Show this screen"

  exit $1
}

# Update git repo and submodules
# Usage: df_update
jailer_update () {
  echo "### Updating jail $jail"
  iocage update $jail
  echo "### Restarting jail $jail"
  iocage restart $jail

  echo "### Updating ports of jail $jail"
  iocage exec $jail portmaster -Bad
  iocage exec $jail service -R
}

# Deploy files to ~
# Usage: df_deploy
jailer_upgrade () {
  echo "### Updating jail $jail"
  iocage upgrade $jail -r $freebsd_release
  echo "### Restarting jail $jail"
  iocage restart $jail

  echo "### Updating ports of jail $jail"
  iocage exec $jail pkg remove nullmailer
  iocage exec $jail pkg autoremove
  iocage exec $jail portmaster -afd
  iocage exec $jail service -R
}

jailer_snapshot () {
  echo "### Creating snapshot of jail $jail"
  zfs snapshot -r $iocage_zfs_dataset/$jail@$TODAY
}
jailer_ports () {
  echo "### Updating ports tree"
  portsnap -p $iocage_ports_dir fetch update
}

case "$1" in
  ######################## jailer.sh HELP ########################
  help)
  help 0
  ;;
  ######################## jailer.sh UPDATE ########################
  update)
  jailer_ports
  cd $iocage_jail_dir

  for JAIL in *
  do
    jailer_snapshot
    jailer_update
  done
  ;;
  ######################## jailer.sh UPGRADE ########################
  upgrade)
  jailer_ports
  cd $iocage_jail_dir

  for JAIL in *
  do
    jailer_snapshot
    jailer_upgrade
  done
  ;;
  *)
  help 1
  ;;
esac
