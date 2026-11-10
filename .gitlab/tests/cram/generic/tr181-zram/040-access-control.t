SPDX-FileCopyrightText: Copyright (c) 2026 Consult Red
Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ R logger -t cram "Starting $TESTFILE"

Skip unless tr181-zram is part of this image:

  $ R "test -x /etc/init.d/tr181-zram" || exit 80

  $ as() { R "ba-cli -u $1 -l '$2'" 2>&1 | sed '/^$/d'; }
  $ val() { R "ba-cli -l 'Device.DeviceInfo.Swap.$1?' | sed '/^$/d'"; }

C11 - ba-cli -u <role> applies the ACLs of that role, as for a USP controller
holding it. The untrusted role may read Device.DeviceInfo.Swap. but not write it:

  $ as untrusted 'Device.DeviceInfo.Swap.Swappiness?'
  60
  $ as untrusted 'Device.DeviceInfo.Swap.Swappiness=100' | grep -c 'permission denied'
  1
  $ as untrusted 'Device.DeviceInfo.Swap.ZRAM.+{Alias="cram-acl"}' | grep -c 'permission denied'
  1
  $ val Swappiness
  60
  $ val ZRAMNumberOfEntries
  0

An instance created by admin can be read but not changed or deleted by untrusted:

  $ as admin 'Device.DeviceInfo.Swap.ZRAM.+{Alias="cram-acl"}' >/dev/null
  $ as untrusted 'Device.DeviceInfo.Swap.ZRAM.cram-acl.Alias?'
  cram-acl
  $ as untrusted 'Device.DeviceInfo.Swap.ZRAM.cram-acl.DiskSize=1024' | grep -c 'permission denied'
  1
  $ as untrusted 'Device.DeviceInfo.Swap.ZRAM.cram-acl.-' | grep -c 'permission denied'
  1
  $ val ZRAM.cram-acl.DiskSize
  0

The admin and cwmp roles may create, configure and delete instances and set Swappiness:

  $ for role in admin cwmp; do
  >   as $role 'Device.DeviceInfo.Swap.ZRAM.cram-acl.DiskSize=1024' >/dev/null
  >   echo "$role $(val ZRAM.cram-acl.DiskSize)"
  >   as $role 'Device.DeviceInfo.Swap.ZRAM.cram-acl.-' >/dev/null
  >   echo "$role $(val ZRAMNumberOfEntries)"
  >   as $role 'Device.DeviceInfo.Swap.ZRAM.+{Alias="cram-acl"}' >/dev/null
  >   as $role 'Device.DeviceInfo.Swap.Swappiness=61' >/dev/null
  >   echo "$role $(val Swappiness)"
  >   R "ba-cli -l 'Device.DeviceInfo.Swap.Swappiness=60'" >/dev/null
  > done
  admin 1024
  admin 0
  admin 61
  cwmp 1024
  cwmp 0
  cwmp 61

Clean up:

  $ R "ba-cli -l 'Device.DeviceInfo.Swap.ZRAM.cram-acl.-'" >/dev/null
  $ val ZRAMNumberOfEntries
  0
  $ val RebootRequired
  0

  $ R logger -t cram "Ended $TESTFILE"
