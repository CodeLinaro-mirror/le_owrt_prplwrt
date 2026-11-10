SPDX-FileCopyrightText: Copyright (c) 2026 Consult Red
Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ R logger -t cram "Starting $TESTFILE"

Skip unless tr181-zram is part of this image:

  $ R "test -x /etc/init.d/tr181-zram" || exit 80

Skip on a kernel built without swap support, where no swap area can be set up:

  $ R "test -e /proc/swaps" || exit 80

Skip unless zram0 exists and is unclaimed (not a swap area, no disksize), as
it is on a freshly booted image; boot-time set-up adopts only such a zram0:

  $ R "test -e /sys/block/zram0" || exit 80
  $ ! R "grep -q '^/dev/zram0 ' /proc/swaps" || exit 80
  $ [ "$(R "cat /sys/block/zram0/disksize")" = 0 ] || exit 80

  $ val() { R "ba-cli -l 'Device.DeviceInfo.Swap.$1?' | sed '/^$/d' | cut -d= -f2-"; }

tr181-zram tells a boot from a restart by its run-marker in /var/run (tmpfs),
which only a reboot clears. Removing it makes the next start run the full
boot-time set-up, as after a reboot. The init script may wait up to 60 s for
syslog-ng, so wait for the new marker rather than for a fixed time:

  $ boot_start() {
  >   R "/etc/init.d/tr181-zram stop; rm -f /var/run/tr181-zram/applied; /etc/init.d/tr181-zram start" >/dev/null 2>&1
  >   for i in $(seq 1 90); do
  >     R "test -e /var/run/tr181-zram/applied" && val RebootRequired | grep -qx '[01]' && return 0
  >     sleep 1
  >   done
  >   return 1
  > }

  $ val ZRAMNumberOfEntries
  0

C13 - an instance created and enabled through the data model is set up as swap at boot:

The data model names algorithms by their TR-181 names, sysfs by the kernel's:

  $ tr181_alg() { sed -n -e 's/^lzo$/LZO/p' -e 's/^lzo-rle$/LZORLE/p' -e 's/^lz4$/LZ4/p' -e 's/^lz4hc$/LZ4HC/p' -e 's/^zstd$/ZSTD/p' -e 's/^deflate$/Deflate/p' -e 's/^842$/842/p'; }
  $ selected_alg() { R "cat /sys/block/zram0/comp_algorithm" | sed -n 's/.*\[\([^]]*\)\].*/\1/p' | tr181_alg; }

  $ CUR=$(selected_alg)
  $ ALG=$(val SupportedCompressionAlgorithms | tr , '\n' | grep -vx "$CUR" | head -n 1)
  $ [ -n "$ALG" ] || ALG=$CUR
  $ R "ba-cli -l 'Device.DeviceInfo.Swap.ZRAM.+{Alias=\"cram-boot\"}' >/dev/null"
  $ R "ba-cli -l 'Device.DeviceInfo.Swap.ZRAM.cram-boot.DiskSize=16384' >/dev/null"
  $ R "ba-cli -l 'Device.DeviceInfo.Swap.ZRAM.cram-boot.MemLimit=8192' >/dev/null"
  $ R "ba-cli -l 'Device.DeviceInfo.Swap.ZRAM.cram-boot.Priority=90' >/dev/null"
  $ R "ba-cli -l 'Device.DeviceInfo.Swap.ZRAM.cram-boot.CompressionAlgorithm=$ALG' >/dev/null"
  $ R "ba-cli -l 'Device.DeviceInfo.Swap.ZRAM.cram-boot.Enable=1' >/dev/null"

Set Swappiness to a value the kernel does not have yet; it is only persisted:

  $ SWAP_DM=$(val Swappiness)
  $ SWAP_KERNEL=$(R "cat /proc/sys/vm/swappiness")
  $ if [ "$SWAP_KERNEL" = 100 ]; then SWAP_NEW=90; else SWAP_NEW=100; fi
  $ R "ba-cli -l 'Device.DeviceInfo.Swap.Swappiness=$SWAP_NEW' >/dev/null"
  $ [ "$(R "cat /proc/sys/vm/swappiness")" = "$SWAP_KERNEL" ] && echo unchanged
  unchanged
  $ val RebootRequired
  1

  $ boot_start && echo started
  started

The instance runs on zram0 and nothing is pending:

  $ val ZRAM.cram-boot.Status
  Enabled
  $ val ZRAM.cram-boot.Name
  zram0
  $ val ZRAM.cram-boot.Usage
  Swap
  $ val RebootRequired
  0

The kernel runs the configuration from the data model:

  $ R "cat /proc/swaps" | awk '$1 == "/dev/zram0" { print $2, $5 }'
  partition 90
  $ R "cat /sys/block/zram0/disksize"
  16777216
  $ R "cat /sys/block/zram0/mm_stat" | awk '{ print $4 }'
  8388608
  $ [ "$(selected_alg)" = "$ALG" ] && echo selected
  selected
  $ [ "$(R "cat /proc/sys/vm/swappiness")" = "$SWAP_NEW" ] && echo applied
  applied

The swap area is reported and references the instance:

  $ R "ba-cli -l 'Device.DeviceInfo.Swap.Area.[Name==\"/dev/zram0\"].Type?' | sed '/^$/d' | cut -d= -f2-"
  ZRAM
  $ REF=$(R "ba-cli -l 'Device.DeviceInfo.Swap.Area.[Name==\"/dev/zram0\"].ZRAM?' | sed '/^$/d' | cut -d= -f2-")
  $ R "ba-cli -l '${REF%.}.Alias?' | sed '/^$/d' | cut -d= -f2-"
  cram-boot

Clean up: deactivate and reset the device, delete the instance, restore
Swappiness, and start once more as at boot, so that the next boot-time
snapshot holds no instance and the kernel gets the original value back:

  $ R "swapoff /dev/zram0 && echo 1 > /sys/block/zram0/reset"
  $ R "ba-cli -l 'Device.DeviceInfo.Swap.ZRAM.cram-boot.-' >/dev/null"
  $ R "ba-cli -l 'Device.DeviceInfo.Swap.Swappiness=$SWAP_DM' >/dev/null"
  $ boot_start && echo started
  started
  $ [ "$(R "cat /proc/sys/vm/swappiness")" = "$SWAP_DM" ] && [ "$(val Swappiness)" = "$SWAP_DM" ] && echo restored
  restored
  $ val ZRAMNumberOfEntries
  0
  $ val AreaNumberOfEntries
  0
  $ val RebootRequired
  0
  $ R "cat /sys/block/zram0/disksize"
  0

  $ R logger -t cram "Ended $TESTFILE"
