SPDX-FileCopyrightText: Copyright (c) 2026 Consult Red
Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ R logger -t cram "Starting $TESTFILE"

Skip unless tr181-zram is part of this image:

  $ R "test -x /etc/init.d/tr181-zram" || exit 80

  $ get() { R "ba-cli -l 'Device.DeviceInfo.Swap.$1?' | sed '/^$/d' | cut -d= -f2- | tr -d '\"'"; }

C1 - the data model is present with the shipped defaults:

  $ get ZRAMNumberOfEntries
  0
  $ get Swappiness
  60
  $ get RebootRequired
  0

The same data model is served over USP:

  $ R "obuspa -f /etc/obuspa.db -c get Device.DeviceInfo.Swap.ZRAMNumberOfEntries"
  Device.DeviceInfo.Swap.ZRAMNumberOfEntries => 0
  $ R "obuspa -f /etc/obuspa.db -c get Device.DeviceInfo.Swap.Swappiness"
  Device.DeviceInfo.Swap.Swappiness => 60

No zram device is in use, and the idle zram0 gets no row. A kernel built
without swap support has no /proc/swaps; the data model is still served:

  $ R "grep -s '^/dev/zram' /proc/swaps | wc -l"
  0
  $ R "ba-cli -l 'Device.DeviceInfo.Swap.ZRAM.*.Alias?' | sed '/^$/d' | wc -l"
  0

SupportedCompressionAlgorithms lists the algorithms of /sys/block/zram0/comp_algorithm,
by their TR-181 names; a kernel algorithm without one is not listed:

  $ tr181_alg() { sed -n -e 's/^lzo$/LZO/p' -e 's/^lzo-rle$/LZORLE/p' -e 's/^lz4$/LZ4/p' -e 's/^lz4hc$/LZ4HC/p' -e 's/^zstd$/ZSTD/p' -e 's/^deflate$/Deflate/p' -e 's/^842$/842/p'; }
  $ EXPECTED=$(R "tr -d '[]' < /sys/block/zram0/comp_algorithm" | tr ' ' '\n' | tr181_alg | sort | tr '\n' ',')
  $ ACTUAL=$(get SupportedCompressionAlgorithms | tr ',' '\n' | sort | tr '\n' ',')
  $ [ -n "$ACTUAL" ] && [ "$ACTUAL" = "$EXPECTED" ] && echo PASS || echo "FAIL: '$ACTUAL' != '$EXPECTED'"
  PASS

C2 - aggregate statistics match the kernel:

  $ [ "$(get Total)" = "$(R "awk '/^SwapTotal:/ {print \$2}' /proc/meminfo")" ] && echo PASS
  PASS
  $ [ "$(get Free)" = "$(R "awk '/^SwapFree:/ {print \$2}' /proc/meminfo")" ] && echo PASS
  PASS
  $ [ "$(get Cached)" = "$(R "awk '/^SwapCached:/ {print \$2}' /proc/meminfo")" ] && echo PASS
  PASS
  $ [ "$(get AreaNumberOfEntries)" = "$(R "tail -n +2 /proc/swaps 2>/dev/null | wc -l")" ] && echo PASS
  PASS

C6 - writes to read-only parameters are rejected:

  $ for p in Total RebootRequired; do
  >   R "ba-cli -l 'Device.DeviceInfo.Swap.$p=1' >/dev/null 2>&1"; done
  $ get RebootRequired
  0

  $ R logger -t cram "Ended $TESTFILE"
