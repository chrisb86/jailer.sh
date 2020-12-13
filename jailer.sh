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
freebsd_latest="12.2-RELEASE"
jailer_conf_path="/usr/local/etc/jailer"

jailer=`basename -- $0`

# Exit with errormessage
# Usage: exerr errormessage
exerr () { echo -e "$*" >&2 ; exit 1; }

jailer_usage_bootstrap="Usage: $jailer bootstrap -p ZPOOL"
jailer_usage_update="Usage: $jailer update [-j JAIL] [-p] [-s]"
jailer_usage_upgrade="Usage: $jailer upgrade [-j JAIL] [-r RELEASE]"
jailer_usage_create="Usage: $jailer create -n NAME [-r RELEASE] [-p PROPERTIES] [-f FLAVOUR]"

## Get the active pool from iocage
iocage_pool=`iocage get -p`

## Dataset for iocage Jails
iocage_zfs_dataset="$iocage_pool/iocage/jails"

## Get mountpoint of iocage zfs dataset
iocage_jail_dir=`zfs get -H -o value mountpoint $iocage_zfs_dataset`

# Show help screen
# Usage: help exitcode
help () {
  echo "Usage: $jailer command {params}"
  echo
  echo "bootstrap         Sets up  the jail host for usage with iocage and $jailer."
  echo "  -p ZPOOL            Name of the zpool that iocage should use."
  echo "update            Updates a jails ports."
  echo "  [-j JAIL]           Jail that should be updated. Otherwise all jails will be processed."
  echo "  [-s]                Also update FreeBsd in jail(s)."
  echo "upgrade           Upgrades a jails base systems and its ports to given FreeBSD release."
  echo "  [-j JAIL]           Jail that should be upgraded. Otherwise all jails will be processed."
  echo "  [-r RELEASE]        Release that should be used for upgrades."
  echo "create            Creates a jail."
  echo "  -n NAME             Name of the jail that should be created."
  echo "  [-r RELEASE]        Release that should be used for jail creation"
  echo "  [-p PROPERTIES]     iocage properties that should be applied"
  echo "  [-f FLAVOUR]        Flavour that should be applied"
  echo "help              Show this screen"

  exit $1
}

# Update the jail's release, restart the jail, update jail's ports and restart services
# Usage: jailer_update
jailer_update () {

  if [ "$update_system" = true ]; then
    echo "### Updating jail $jail"
    iocage update $jail

    echo "### Restarting jail $jail"
    iocage restart $jail
  fi

  echo "### Updating ports of jail $jail"
  iocage exec $jail portmaster -Bad
  iocage exec $jail service -R
}

# Upgrade the jail's release, restart the jail, autoremove ports, recompile jail's ports and restart services

# Usage: jailer_upgrade
jailer_upgrade () {
  echo "### Upgrading jail $jail"
  iocage upgrade $jail -r $freebsd_release

  echo "### Restarting jail $jail"
  iocage restart $jail

  echo "### Updating ports of jail $jail"
  iocage exec $jail pkg autoremove
  iocage exec $jail portmaster -Bafd
  iocage exec $jail service -R
}

# Update the specified iocage release or fetch it if if doesn't exist
# Usage: jailer_update_base [XX.X-RELEASE]
jailer_update_base () {
  release="${1:-LATEST}"
  iocage fetch -r $release
}

# Update the iocage ports tree
# Usage: jailer_update_ports
jailer_update_ports () {
  echo "### Updating ports tree"
  portsnap -p $iocage_ports_dir auto
}

# Strip comments, blank lines and whitespace from a file
# Usage: jailer_cleanfile FILE
jailer_cleanfile () {
  file=$1
  sed 's/[[:space:]]*#.*//;/^[[:space:]]*$/d' "$file"
}

case "$1" in
  ######################## jailer.sh HELP ########################
  help)
  help 0
  ;;
  ######################## jailer.sh BOOTSTRAP ########################
  bootstrap)
  shift; while getopts :p: arg; do case ${arg} in
    p) zpool=${OPTARG};;
    ?) exerr ${jailer_usage_bootstrap};;
    :) exerr ${jailer_usage_bootstrap};;
  esac; done; shift $(( ${OPTIND} - 1 ))

  if [ -z "$zpool" ]; then exerr $jailer_usage_bootstrap; fi

  portsnap auto

  echo "### Installing ccache"
  cd /usr/ports/devel/ccache
  make install clean

  echo "### Installing portmaster"
  cd /usr/ports/ports-mgmt/portmaster
  make install clean

  echo "### Installing rsync"
  portmaster -Bd net/rsync

  echo "### Installing iocage"
  portmaster -Bd sysutils/iocage

  echo "### Activating ZPOOL $zpool for iocage."
  iocage activate $zpool

  jailer_update_base
  jailer_update_ports

  echo "Your host is now ready to be used with $jailer."
  echo "See _$jailer help_ for usage instructions."
  ;;
  ######################## jailer.sh UPDATE ########################
  update)
  shift; while getopts :j:s arg; do case ${arg} in
    j) jail=${OPTARG};;
    s) update_system=true;;
    ?) exerr ${jailer_usage_update};;
    :) exerr ${jailer_usage_update};;
  esac; done; shift $(( ${OPTIND} - 1 ))

  jailer_update_ports

  ## Stop monit
  /usr/sbin/service monit stop

  if [ -n "$jail" ]; then
    iocage snapshot $jail
    jailer_update
  else
    cd $iocage_jail_dir
    for jail in *
    do
      if [ -d "$jail" ]; then
        iocage snapshot $jail
        jailer_update
      fi
    done
  fi

  ## Start monit
  /usr/sbin/service monit start
  ;;
  ######################## jailer.sh UPGRADE ########################
  upgrade)
  shift; while getopts :j:r: arg; do case ${arg} in
    j) jail=${OPTARG};;
    r) release=${OPTARG};;
    ?) exerr ${jailer_usage_upgrade};;
    :) exerr ${jailer_usage_upgrade};;
  esac; done; shift $(( ${OPTIND} - 1 ))

  freebsd_release="${release:-$freebsd_latest}"

  jailer_update_base

  jailer_update_ports

  if [ -n "$jail" ]; then
    iocage snapshot $jail
    jailer_upgrade
  else
    cd $iocage_jail_dir
    for jail in *
    do
      if [ -d "$jail" ]; then
        iocage snapshot $jail
        jailer_upgrade
      fi
    done
  fi
  ;;
  ######################## jailer.sh CREATE ########################
  create)
  shift; while getopts :r:b:p:n:f: arg; do case ${arg} in
    r) release=${OPTARG};;
    b) update_base=true;;
    p) jail_properties="${jail_properties} ${OPTARG}";;
    n) jail_name=${OPTARG};;
    f) jail_flavour=${OPTARG};;
    ?) exerr ${jailer_usage_create};;
    :) exerr ${jailer_usage_create};;
  esac; done; shift $(( ${OPTIND} - 1 ))

  freebsd_release="${release:-LATEST}"

  if [ "$update_base" = true ]; then
    jailer_update_base
  fi

  if [ -z ${jail_name+x} ]; then exerr $jailer_usage_create; fi

  jail=$jail_name
  jail_root="$iocage_jail_dir/$jail/root"
  jail_pkglist=""

  ## Check if jail should be flavoured
  if [ -n $jail_flavour ]; then

    ## Set some paths

    jail_flavour_dir="$jailer_conf_path/flavours/$jail_flavour"

    ## Process the flavours jail.cfg
    if [ -f $jail_flavour_dir/jail.cfg ]; then
      ## load jail.cfg line by line to variable and skip comments, blank lines and whitespace
      jail_properties_cfg=`jailer_cleanfile "$jail_flavour_dir/jail.cfg"`

      ## Append loaded properties to these that where passed by cli
      jail_properties="${jail_properties_cfg} ${jail_properties}"
    fi

    ## Process the flavour's pkgs.json
    if [ -f $jail_flavour_dir/pkgs.json ]; then
      jail_pkglist="-p $jail_flavour_dir/pkgs.json"
    fi

  fi

  ## Create the jail
  iocage create -n $jail_name -r $freebsd_release ${jail_pkglist} ${jail_properties} || exit 1

  ## If we have passed a flavour
  if [ -n $jail_flavour ]; then

    ## Process the flavour's fstab.cfg and create the mountpoints
    if [ -f $jail_flavour_dir/fstab.cfg ]; then
      jailer_cleanfile "$jail_flavour_dir/fstab.cfg" | while IFS='' read -r line; do
        # Get mountpoint from fstab line
        line_mountpoint=`echo $line | awk '{print $2}'`
        # Create mountpoint
        iocage exec $jail "mkdir -p $line_mountpoint"
        # Add line to jail's fstab
        iocage fstab -a $jail "$line"
      done
    fi

    ## Sync the system files in flavour to the jail's root
    echo "### Copying system files from flavour $jail_flavour to $jail's root."

    # What should be ignored
    sync_exclude="fstab.cfg pkgs.json jail.cfg .git/ .gitignore .gitmodules README.md .DS_Store bootstrap.sh"

    for exclude_item in ${sync_exclude}
    do
      rsync_exclude=${rsync_exclude}" --exclude=$exclude_item"
    done

    rsync -ar $jail_flavour_dir/ $jail_root/ $rsync_exclude

    if [ -f $jail_flavour_dir/bootstrap.sh ]; then
      ## Sync the system files in flavour to the jail's root
      echo "### Running bootstrapping script."

      cp $jail_flavour_dir/bootstrap.sh $jail_root/tmp/

      iocage exec $jail "/tmp/bootstrap.sh"
      iocage exec $jail "rm /tmp/bootstrap.sh"
    fi
  fi
  ;;
  *)
  help 1
  ;;
esac
