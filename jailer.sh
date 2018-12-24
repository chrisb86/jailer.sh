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

## Copy of ports for iocage jails
iocage_ports_dir="/iocage/ports"

## Dataset for iocage Jails
iocage_zfs_dataset="zroot/iocage/jails"

jailer=`basename -- $0`

# Exit with errormessage
# Usage: exerr errormessage
exerr () { echo -e "$*" >&2 ; exit 1; }

jailer_usage_upgrade="Usage: $JAILer upgrade [-R FreeBSD-Release]"

## Get mountpoint of iocage zfs dataset
iocage_jail_dir=`zfs get -H -o value mountpoint $iocage_zfs_dataset`

# Show help screen
# Usage: help exitcode
help () {
  echo "Usage: $JAILer command {params}"
  echo
  echo "update            Updates all jails base systems and their ports."
  echo "upgrade           Upgrades all jails base systems and their ports to given FreeBSD release."
  echo "  [-r FreeBSD-Release]        Release that should be used for upgrades"
  echo ""
  echo "help       Show this screen"

  exit $1
}

# Usage: jailer_update
jailer_update () {
  echo "### Updating jail $JAIL"
  iocage update $JAIL
  echo "### Restarting jail $JAIL"
  iocage restart $JAIL

  echo "### Updating ports of jail $JAIL"
  iocage exec $JAIL portmaster -Bad
  iocage exec $JAIL service -R
}

# Usage: jailer_upgrade
jailer_upgrade () {
  echo "### Updating jail $JAIL"
  iocage upgrade $JAIL -r $freebsd_release
  echo "### Restarting jail $JAIL"
  iocage restart $JAIL

  echo "### Updating ports of jail $JAIL"
  iocage exec $JAIL pkg autoremove
  iocage exec $JAIL portmaster -Bafd
  iocage exec $JAIL service -R
}

# Usage: jailer_update_ports
jailer_update_ports () {
  echo "### Updating ports tree"
  portsnap -p $iocage_ports_dir auto
}

case "$1" in
  ######################## jailer.sh HELP ########################
  help)
  help 0
  ;;
  ######################## jailer.sh UPDATE ########################
  update)
  jailer_update_ports
  cd $iocage_jail_dir

  for JAIL in *
  do
    iocage snapshot $JAIL
    jailer_update
  done
  ;;
  ######################## jailer.sh UPGRADE ########################
  upgrade)
  shift; while getopts :r: arg; do case ${arg} in
    r) release=${OPTARG};;
    ?) exerr ${jailer_usage_upgrade};;
    :) exerr ${jailer_usage_upgrade};;
  esac; done; shift $(( ${OPTIND} - 1 ))

  freebsd_release="${release:-12.0-RELEASE}"

  jailer_update_ports
  cd $iocage_jail_dir

  for JAIL in *
  do
    iocage snapshot $JAIL
    jailer_upgrade
  done
  ;;
  *)
  help 1
  ;;
esac
