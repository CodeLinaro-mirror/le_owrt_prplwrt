SPDX-FileCopyrightText: Copyright (c) 2026 Consult Red
Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ R logger -t cram "Starting $TESTFILE"

Skip unless tr181-zram is part of this image:

  $ R "test -x /etc/init.d/tr181-zram" || exit 80

  $ as() { R "ba-cli -u $1 -l '$2'" 2>&1 | sed '/^$/d'; }
  $ val() { R "ba-cli -l 'Device.DeviceInfo.Swap.$1?' | sed '/^$/d'"; }

C11 - ba-cli -u <role> applies the ACLs of that role, as for a USP controller
holding it. The untrusted and admin roles may read Device.DeviceInfo.Swap. but
not write it:

  $ for role in untrusted admin; do
  >   echo "$role $(as $role 'Device.DeviceInfo.Swap.Swappiness?')"
  >   as $role 'Device.DeviceInfo.Swap.Swappiness=100' | grep -c 'permission denied'
  >   as $role 'Device.DeviceInfo.Swap.ZRAM.+{Alias="cram-acl"}' | grep -c 'permission denied'
  > done
  untrusted 60
  1
  1
  admin 60
  1
  1
  $ val Swappiness
  60
  $ val ZRAMNumberOfEntries
  0

An instance created by cwmp can be read but not changed or deleted by untrusted
or admin:

  $ as cwmp 'Device.DeviceInfo.Swap.ZRAM.+{Alias="cram-acl"}' >/dev/null
  $ for role in untrusted admin; do
  >   echo "$role $(as $role 'Device.DeviceInfo.Swap.ZRAM.cram-acl.Alias?')"
  >   as $role 'Device.DeviceInfo.Swap.ZRAM.cram-acl.DiskSize=1024' | grep -c 'permission denied'
  >   as $role 'Device.DeviceInfo.Swap.ZRAM.cram-acl.-' | grep -c 'permission denied'
  > done
  untrusted cram-acl
  1
  1
  admin cram-acl
  1
  1
  $ val ZRAM.cram-acl.DiskSize
  0

The cwmp role may create, configure and delete instances and set Swappiness:

  $ as cwmp 'Device.DeviceInfo.Swap.ZRAM.cram-acl.DiskSize=1024' >/dev/null
  $ val ZRAM.cram-acl.DiskSize
  1024
  $ as cwmp 'Device.DeviceInfo.Swap.ZRAM.cram-acl.-' >/dev/null
  $ val ZRAMNumberOfEntries
  0
  $ as cwmp 'Device.DeviceInfo.Swap.ZRAM.+{Alias="cram-acl"}' >/dev/null
  $ as cwmp 'Device.DeviceInfo.Swap.Swappiness=61' >/dev/null
  $ val Swappiness
  61
  $ R "ba-cli -l 'Device.DeviceInfo.Swap.Swappiness=60'" >/dev/null

Clean up:

  $ R "ba-cli -l 'Device.DeviceInfo.Swap.ZRAM.cram-acl.-'" >/dev/null
  $ val ZRAMNumberOfEntries
  0
  $ val RebootRequired
  0

  $ R logger -t cram "Ended $TESTFILE"
