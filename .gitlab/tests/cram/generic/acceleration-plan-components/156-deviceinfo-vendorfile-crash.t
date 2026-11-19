Calling VendorLogFile.Upload(), VendorConfigFile.Backup() or VendorConfigFile.Restore()
with a non-string argument (e.g. a numeric Password) used to crash deviceinfo-manager;
it is now accepted and converted to a string instead.

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Get the deviceinfo-manager PID before triggering the regression:

  $ pid_before=$(R "pgrep -f deviceinfo-manager -P 1")
  $ echo "$pid_before"
  \d+ (re)

Calling VendorLogFile.Upload() with a numeric Password must not crash
deviceinfo-manager. The value is accepted, converted to a string:

  $ R "ba-cli 'DeviceInfo.VendorLogFile.1.Upload(URL=\"http://127.0.0.1/\", Username=\"user\", Password=12345)' | grep -v '>'"
  ERROR: call (null) failed with status 1 - unknown error
  DeviceInfo.VendorLogFile.1.Upload() returned
  [
      ""
  ]
  

Same check with a numeric Username and URL:

  $ R "ba-cli 'DeviceInfo.VendorLogFile.1.Upload(URL=\"http://127.0.0.1/\", Username=12345, Password=\"pass\")' | grep -v '>'"
  ERROR: call (null) failed with status 1 - unknown error
  DeviceInfo.VendorLogFile.1.Upload() returned
  [
      ""
  ]
  

  $ R "ba-cli 'DeviceInfo.VendorLogFile.1.Upload(URL=12345, Username=\"user\", Password=\"pass\")' | grep -v '>'"
  ERROR: call (null) failed with status 1 - unknown error
  DeviceInfo.VendorLogFile.1.Upload() returned
  [
      ""
  ]
  

Calling VendorConfigFile.Backup() with a numeric Password must not crash
deviceinfo-manager either:

  $ R "ba-cli 'DeviceInfo.VendorConfigFile.1.Backup(URL=\"http://127.0.0.1/\", Username=\"user\", Password=12345)' | grep -v '>'"
  ERROR: call (null) failed with status 1 - unknown error
  DeviceInfo.VendorConfigFile.1.Backup() returned
  [
      ""
  ]
  

Calling VendorConfigFile.Restore() with a numeric Password must not crash
deviceinfo-manager either:

  $ R "ba-cli 'DeviceInfo.VendorConfigFile.1.Restore(URL=\"http://127.0.0.1/\", Username=\"user\", Password=12345)' | grep -v '>'"
  DeviceInfo.VendorConfigFile.1.Restore() returned
  [
      ""
  ]
  

deviceinfo-manager must still be running with the same PID, i.e. none of the
calls above crashed it:

  $ pid_after=$(R "pgrep -f deviceinfo-manager -P 1")
  $ test "$pid_before" = "$pid_after"
