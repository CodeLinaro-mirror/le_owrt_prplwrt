SPDX-FileCopyrightText: Copyright (c) 2026 Consult Red
Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ R logger -t cram "Starting $TESTFILE"

Skip unless tr181-zram is part of this image:

  $ R "test -x /etc/init.d/tr181-zram" || exit 80

Skip on a kernel built without swap support, where no swap area can be set up:

  $ R "test -e /proc/swaps" || exit 80

  $ val() { R "ba-cli -l 'Device.DeviceInfo.Swap.$1?' | sed '/^$/d' | cut -d= -f2-"; }

C9 - set up a zram swap device by hand, outside the data model:

  $ DEV=zram$(R "cat /sys/class/zram-control/hot_add")
  $ R "echo 16M > /sys/block/$DEV/disksize && mkswap /dev/$DEV >/dev/null && swapon -p 5 /dev/$DEV"
  $ SWAPS=$(R "cat /proc/swaps")

The kernel signals the swapon on /proc/swaps, so Swap.Area follows it without a restart:

  $ sleep 2
  $ R "ba-cli -l 'Device.DeviceInfo.Swap.Area.*.Name?'" | grep -c "^/dev/$DEV$"
  1

C6 - Area rows are read-only:

  $ SIZE=$(R "ba-cli -l 'Device.DeviceInfo.Swap.Area.[Name==\"/dev/$DEV\"].Size?' | sed '/^$/d' | cut -d= -f2-")
  $ R "ba-cli -l 'Device.DeviceInfo.Swap.Area.[Name==\"/dev/$DEV\"].Size=1' >/dev/null 2>&1"
  $ [ "$(R "ba-cli -l 'Device.DeviceInfo.Swap.Area.[Name==\"/dev/$DEV\"].Size?' | sed '/^$/d' | cut -d= -f2-")" = "$SIZE" ] && [ "$SIZE" -gt 0 ] && echo unchanged
  unchanged

Restart the service, then kill it and let procd respawn it; swap stays active each time:

  $ R "/etc/init.d/tr181-zram restart" >/dev/null 2>&1
  $ sleep 5
  $ [ "$(R "cat /proc/swaps")" = "$SWAPS" ] && echo unchanged
  unchanged
  $ R "kill -9 \$(pidof tr181-zram)"
  $ sleep 10
  $ R "pidof tr181-zram >/dev/null" && echo running
  running
  $ [ "$(R "cat /proc/swaps")" = "$SWAPS" ] && echo unchanged
  unchanged

The device is reported as a ZRAM swap area and as a read-only discovered row:

  $ R "ba-cli -l 'Device.DeviceInfo.Swap.Area.[Name==\"/dev/$DEV\"].Type?' | sed '/^$/d' | cut -d= -f2-"
  ZRAM
  $ val "ZRAM.discovered-$DEV.Name"
  zram* (glob)
  $ R "ba-cli -l 'Device.DeviceInfo.Swap.ZRAM.discovered-$DEV.Priority=7' >/dev/null 2>&1"
  $ R "ba-cli -l 'Device.DeviceInfo.Swap.ZRAM.discovered-$DEV.-' >/dev/null 2>&1"
  $ val "ZRAM.discovered-$DEV.Name"
  zram* (glob)
  $ R "grep -c 'discovered-' /etc/config/tr181-zram/odl/*.odl"
  0
  [1]

Clean up the hand-made device only:

  $ R "swapoff /dev/$DEV && echo 1 > /sys/block/$DEV/reset && echo ${DEV#zram} > /sys/class/zram-control/hot_remove"

The swapoff is followed the same way: the area row goes without a restart:

  $ sleep 2
  $ R "ba-cli -l 'Device.DeviceInfo.Swap.Area.*.Name?'" | grep -c "^/dev/$DEV$"
  0
  [1]

Discovered ZRAM rows are only scanned at start-up, so restart the service; the discovered row goes away:

  $ R "/etc/init.d/tr181-zram restart" >/dev/null 2>&1
  $ sleep 5
  $ R "ba-cli -l 'Device.DeviceInfo.Swap.ZRAM.*.Alias?' | grep -c discovered-"
  0
  [1]
  $ val AreaNumberOfEntries
  0

  $ R logger -t cram "Ended $TESTFILE"
