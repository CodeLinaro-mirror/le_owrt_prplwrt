Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check if overlay support was enabled and mounted:
  $ OVERLAY_ENABLED=$(R "grep '^CONFIG_PRPL_ALLOW_OVERLAYFS_ON_ROOTFS=y' /etc/build.config; true")
  $ OVERLAY_MOUNTED=$(R "mount | grep ' / type overlay '; true")
  $ if [ -z "$OVERLAY_ENABLED" -a -z "$OVERLAY_MOUNTED" ]; then
  >   echo "PASS: overlay disabled"
  > elif [  -n "$OVERLAY_ENABLED" -a -n "$OVERLAY_MOUNTED" ]; then
  >   echo "PASS: overlay enabled"
  > elif [ -z "$OVERLAY_ENABLED" -a -n "$OVERLAY_MOUNTED" ]; then
  >   echo "FAIL: overlay mounted although it was disabled"
  > else
  >   echo "FAIL: overlay not mounted although it was enabled"
  > fi
  PASS: .* (re)

