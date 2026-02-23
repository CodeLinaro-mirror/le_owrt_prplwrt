Create R alias:
  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Force boot to inactive bank:
  $ R "echo 1 > /sys/class/registers/force-inactive"

Reboot system:
  $ R "reboot"
  $ sleep 150

Check boot bank after reboot:
  $ R "cat /proc/device-tree/chosen/u-boot,booted-bank | tr -d '\0'; echo"
  inactive,forced
