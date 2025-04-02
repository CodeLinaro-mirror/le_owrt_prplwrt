Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check time synchronization to start BulkData module:

  $ time_sync=$(R "cat /etc/amx/tr181-bulkdata/tr181-bulkdata.odl | grep -i "needs-time-sync" | sed -E 's/.*= ([^;]*);.*/\1/'")
  $ echo "$time_sync"
  true

Disable time synchronization and restart tr181-bulkdata to test BulkData module without time dependency if needed:

  $ if [ "$time_sync" = true ]; then
  >  R "/etc/init.d/tr181-bulkdata restart"
  >  no_sync=$(R "cat /var/log/messages | grep 'bulkdata' | grep 'synchronization not done yet' | tail -n 1 | sed 's/.*tr181-bulkdata: //'")
  >  if [ -n "$no_sync" ]; then
  >      R "sed -i 's/needs-time-sync = true/needs-time-sync = false/' /etc/amx/tr181-bulkdata/tr181-bulkdata.odl"
  >      R "/etc/init.d/tr181-bulkdata restart"
  >  fi
  > fi

Check BulkData root datamodel:

  $ R "ba-cli 'BulkData.?' | sort | grep '=' | grep -v 'Profile'"
  BulkData.Enable=[0-9]+ (re)
  BulkData.EncodingTypes=".*" (re)
  BulkData.MaxNumberOfParameterReferences=[0-9]+ (re)
  BulkData.MinReportingInterval=[0-9]+ (re)
  BulkData.ParameterWildCardSupported=[0-9]+ (re)
  BulkData.Protocols=".*" (re)
  BulkData.Status=".*" (re)

Enable BulkData and check object status:

  $ R "ba-cli 'BulkData.Enable=1' | grep -v '>' | grep 'Enable'"
  BulkData.Enable=1

  $ R "ba-cli 'BulkData.Status?' | grep '='"
  BulkData.Status="Enabled"

Check added new Profile:

  $ alias=$(R "ba-cli 'BulkData.Profile.+{Protocol=USPEventNotif, Enable=true}' | grep -v '>' | grep 'Alias'| sed -E 's/.*Alias=\"([^\"]+)\"/\1/'")
  $ echo "$alias"
  cpe-Profile-[0-9]+ (re)

Check adding ReportingInterval value:

  $ R "ba-cli 'BulkData.Profile.$alias.ReportingInterval=15' | sort | grep 'BulkData' | grep -v '>'"
  BulkData.Profile.[0-9]+. (re)
  BulkData.Profile.[0-9]+.ReportingInterval=15 (re)

Check adding Reference information:

  $ R "ba-cli "BulkData.Profile.$alias.Parameter.+{Reference="Device.DeviceInfo.SerialNumber"}" | sort | grep 'BulkData' | grep -v '>'"
  BulkData.Profile.[0-9]+.Parameter.[0-9]+. (re)

Check push notification:

  $ R "ubus -t 15 subscribe "BulkData.Profile" | grep '$alias'" | jq -c '.["Push!"].data.Data | fromjson | { SerialNumber: .Report[0].Device.DeviceInfo.SerialNumber, CollectionTime: .Report[0].CollectionTime }' | LC_ALL=C sort
  {"SerialNumber":".*","CollectionTime":"[0-9]+"} (re)

Restore default settings:
  $ if [ "$time_sync" = true -a -n "$no_sync" ]; then
  >  R "sed -i 's/needs-time-sync = false/needs-time-sync = true/' /etc/amx/tr181-bulkdata/tr181-bulkdata.odl"
  > fi
