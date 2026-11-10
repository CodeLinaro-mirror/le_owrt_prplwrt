SPDX-FileCopyrightText: Copyright (c) 2026 Consult Red
Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ R logger -t cram "Starting $TESTFILE"

Skip unless tr181-zram is part of this image:

  $ R "test -x /etc/init.d/tr181-zram" || exit 80

  $ val() { R "ba-cli -l 'Device.DeviceInfo.Swap.$1?' | sed '/^$/d' | cut -d= -f2-"; }
  $ SWAPS_BEFORE=$(R "cat /proc/swaps 2>/dev/null")
  $ NODES_BEFORE=$(R "ls -d /sys/block/zram* | wc -l")

C3 - create an instance with an Alias and configure it; nothing changes live:

  $ R "ba-cli -l 'Device.DeviceInfo.Swap.ZRAM.+{Alias=\"cram\"}' >/dev/null"
  $ R "ba-cli -l 'Device.DeviceInfo.Swap.ZRAM.cram.DiskSize=65536' >/dev/null"
  $ R "ba-cli -l 'Device.DeviceInfo.Swap.ZRAM.cram.MemLimit=32768' >/dev/null"
  $ R "ba-cli -l 'Device.DeviceInfo.Swap.ZRAM.cram.Priority=90' >/dev/null"
  $ ALG=$(val SupportedCompressionAlgorithms | cut -d, -f1)
  $ R "ba-cli -l 'Device.DeviceInfo.Swap.ZRAM.cram.CompressionAlgorithm=$ALG' >/dev/null"
  $ R "ba-cli -l 'Device.DeviceInfo.Swap.ZRAM.cram.Enable=1' >/dev/null"
  $ val ZRAM.cram.DiskSize
  65536
  $ val ZRAM.cram.Enable
  1
  $ val ZRAM.cram.Status
  Disabled
  $ [ -z "$(val ZRAM.cram.Name)" ] && echo empty
  empty
  $ val RebootRequired
  1
  $ [ "$(R "cat /proc/swaps 2>/dev/null")" = "$SWAPS_BEFORE" ] && echo unchanged
  unchanged
  $ [ "$(R "ls -d /sys/block/zram* | wc -l")" = "$NODES_BEFORE" ] && echo unchanged
  unchanged

C4 - an instance created without Alias gets a unique one; a duplicate Alias and a fifth instance are rejected:

  $ R "ba-cli -l 'Device.DeviceInfo.Swap.ZRAM.+' >/dev/null"
  $ R "ba-cli -l 'Device.DeviceInfo.Swap.ZRAM.*.Alias?' | sed '/^$/d' | cut -d= -f2- | sort | uniq -d | wc -l"
  0
  $ R "ba-cli -l 'Device.DeviceInfo.Swap.ZRAM.+{Alias=\"cram\"}' >/dev/null 2>&1"
  $ R "ba-cli -l 'Device.DeviceInfo.Swap.ZRAM.+{Alias=\"cram3\"}' >/dev/null"
  $ R "ba-cli -l 'Device.DeviceInfo.Swap.ZRAM.+{Alias=\"cram4\"}' >/dev/null"
  $ R "ba-cli -l 'Device.DeviceInfo.Swap.ZRAM.+{Alias=\"cram5\"}' >/dev/null 2>&1"
  $ val ZRAMNumberOfEntries
  4

C5 - invalid writes are rejected and the value is unchanged:

  $ R "ba-cli -l 'Device.DeviceInfo.Swap.ZRAM.cram.CompressionAlgorithm=no-such-algorithm' >/dev/null 2>&1"
  $ [ "$(val ZRAM.cram.CompressionAlgorithm)" = "$ALG" ] && echo unchanged
  unchanged
  $ R "ba-cli -l 'Device.DeviceInfo.Swap.ZRAM.cram.DiskSize=0' >/dev/null 2>&1"
  $ val ZRAM.cram.DiskSize
  65536
  $ R "ba-cli -l 'Device.DeviceInfo.Swap.ZRAM.cram.MemLimit=65537' >/dev/null 2>&1"
  $ val ZRAM.cram.MemLimit
  32768
  $ R "ba-cli -l 'Device.DeviceInfo.Swap.ZRAM.cram.Priority=-2' >/dev/null 2>&1"
  $ val ZRAM.cram.Priority
  90
  $ R "ba-cli -l 'Device.DeviceInfo.Swap.Swappiness=201' >/dev/null 2>&1"
  $ val Swappiness
  60

C6 - writes to read-only ZRAM parameters are rejected:

  $ for p in Status Name CompressionRatio; do
  >   R "ba-cli -l 'Device.DeviceInfo.Swap.ZRAM.cram.$p=1' >/dev/null 2>&1"; done
  $ val ZRAM.cram.Status
  Disabled

C7 - Swappiness is only persisted; the kernel value does not change:

  $ KERNEL_SWAPPINESS=$(R "cat /proc/sys/vm/swappiness")
  $ R "ba-cli -l 'Device.DeviceInfo.Swap.Swappiness=100' >/dev/null"
  $ val Swappiness
  100
  $ [ "$(R "cat /proc/sys/vm/swappiness")" = "$KERNEL_SWAPPINESS" ] && echo unchanged
  unchanged
  $ val RebootRequired
  1

C8 - the configuration survives a service restart:

  $ R "/etc/init.d/tr181-zram restart" >/dev/null 2>&1
  $ sleep 5
  $ R "grep -l 'cram' /etc/config/tr181-zram/odl/*.odl | wc -l"
  1
  $ val ZRAM.cram.DiskSize
  65536
  $ val Swappiness
  100
  $ val RebootRequired
  1

C10 - delete instances; reverting Swappiness first makes RebootRequired follow the deletions only:

  $ R "ba-cli -l 'Device.DeviceInfo.Swap.Swappiness=60' >/dev/null"
  $ for a in cram3 cram4; do R "ba-cli -l 'Device.DeviceInfo.Swap.ZRAM.$a.-' >/dev/null"; done
  $ R "ba-cli -l 'Device.DeviceInfo.Swap.ZRAM.[Alias!=\"cram\"].-' >/dev/null"
  $ val ZRAMNumberOfEntries
  1
  $ val RebootRequired
  1
  $ R "ba-cli -l 'Device.DeviceInfo.Swap.ZRAM.cram.-' >/dev/null"
  $ val ZRAMNumberOfEntries
  0
  $ val RebootRequired
  0
  $ R "/etc/init.d/tr181-zram restart" >/dev/null 2>&1
  $ sleep 5
  $ R "grep -l 'cram' /etc/config/tr181-zram/odl/*.odl | wc -l"
  0

  $ R logger -t cram "Ended $TESTFILE"
