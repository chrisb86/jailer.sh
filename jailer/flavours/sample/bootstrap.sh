#!/bin/sh

## Disable adjkerntz in jail
sed -i .tmp -e '/adjkerntz/ s/^#*/#/' /etc/crontab

## Disable crash dumps
sysrc dumpdev="NO"

## Set alias for root to you mail address
echo root: user@example.org >> /etc/aliases
