Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Define plugin list:

  $ PLUGINS="\
  > cellular-manager \
  > amx-faultmonitor \
  > oopsmonitor \
  > reboot-service \
  > tr181-dhcpv6client \
  > tr181-firewall \
  > tr181-mqttbroker \
  > tr181-bulkdata \
  > ethernet-manager \
  > tr181-led \
  > tr181-periodicfileupload \
  > wan-manager"

Check that %upc and %usersetting flags are only in <plugin>_upc.odl:

  $ for plugin in $PLUGINS; do
  >   echo "Checking $plugin..."
  >   dir="/etc/amx/$plugin"
  >   for f in $(R "ls $dir/*.odl" | grep -v "_upc.odl"); do
  >     if R "grep -q '%upc\\|%usersetting' $f"; then
  >       echo "ERROR: Found upc/usersetting in $f (must be in ${plugin}_upc.odl)"
  >       continue
  >     fi
  >   done
  > done
  Checking cellular-manager...
  Checking amx-faultmonitor...
  Checking oopsmonitor...
  Checking reboot-service...
  Checking tr181-dhcpv6client...
  Checking tr181-firewall...
  Checking tr181-mqttbroker...
  Checking tr181-bulkdata...
  Checking ethernet-manager...
  Checking tr181-led...
  Checking tr181-periodicfileupload...
  Checking wan-manager...
