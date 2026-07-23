Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Poll both objects for three minutes after the normal testbed boot. Record the
first five-second interval where each becomes ready. If either object is still
missing, apply the exact service restart sequence from 000-lcm-setup.t and
poll for one more minute.

  $ R '
  > software_time=missing
  > root_time=missing
  > elapsed=0
  > while [ "$elapsed" -le 180 ]; do
  >     if [ "$software_time" = missing ] &&
  >        ubus list "Device.X_PRPLWARE-COM_SoftwareModules" |
  >            grep -qx "Device.X_PRPLWARE-COM_SoftwareModules"; then
  >         software_time=$elapsed
  >     fi
  >     if [ "$root_time" = missing ] &&
  >        ba-cli "UPnPDiscovery.RootDevice.1.?" 2>/dev/null |
  >            grep -q "UPnPDiscovery.RootDevice.1."; then
  >         root_time=$elapsed
  >     fi
  >     [ "$software_time" != missing ] && [ "$root_time" != missing ] &&
  >         break
  >     sleep 5
  >     elapsed=$((elapsed + 5))
  > done
  > printf "PHASE10 pre software=%s root=%s\n" "$software_time" "$root_time"
  > if [ "$software_time" = missing ] || [ "$root_time" = missing ]; then
  >     /etc/init.d/cthulhu restart
  >     sleep 2
  >     /etc/init.d/timingila restart
  >     elapsed=0
  >     while [ "$elapsed" -le 60 ]; do
  >         if [ "$software_time" = missing ] &&
  >            ubus list "Device.X_PRPLWARE-COM_SoftwareModules" |
  >                grep -qx "Device.X_PRPLWARE-COM_SoftwareModules"; then
  >             software_time=$elapsed
  >         fi
  >         if [ "$root_time" = missing ] &&
  >            ba-cli "UPnPDiscovery.RootDevice.1.?" 2>/dev/null |
  >                grep -q "UPnPDiscovery.RootDevice.1."; then
  >             root_time=$elapsed
  >         fi
  >         [ "$software_time" != missing ] && [ "$root_time" != missing ] &&
  >             break
  >         sleep 5
  >         elapsed=$((elapsed + 5))
  >     done
  >     printf "PHASE10 post-restart software=%s root=%s\n" \
  >         "$software_time" "$root_time"
  > else
  >     printf "PHASE10 post-restart skipped\n"
  > fi
  > '
  PHASE10 pre software=(missing|[0-9]+) root=(missing|[0-9]+) (re)
  PHASE10 post-restart (skipped|software=(missing|[0-9]+) root=(missing|[0-9]+)) (re)
