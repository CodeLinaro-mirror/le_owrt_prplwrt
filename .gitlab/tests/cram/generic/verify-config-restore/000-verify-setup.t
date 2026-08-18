Create alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"


## Stopping the Cthulhu service before backup/restore tests.
## This is required because Cthulhu does not support
## triggering a backup followed by a restore without restarting
## the service.
## If this step is not followed, it may cause unpredictable
## behavior on the LCM.
  $ R "service cthulhu stop"
