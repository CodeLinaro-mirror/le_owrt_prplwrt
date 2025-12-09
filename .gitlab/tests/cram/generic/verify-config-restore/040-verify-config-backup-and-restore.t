Create alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Startinig with deviceinfo-manager restart checks"

#Stop Cthulhu service before tests, PPW-1647:

#  $ R "service cthulhu stop"

#Delete the /etc/config/ for all services:

#  $ R "rm -rf /etc/config/deviceinfo-manager/*"

Stop and restart the services:

  $ R "/etc/init.d/deviceinfo-manager stop > /dev/null 2>&1"

  $ R "/etc/init.d/deviceinfo-manager start > /dev/null 2>&1"

#Start Cthulhu service after tests, PPW-1647:

#  $ R "service cthulhu start"

  $ R logger -t cram "deviceinfo-manager restart finished"
