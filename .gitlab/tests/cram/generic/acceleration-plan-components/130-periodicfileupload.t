Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Start Servefile to act as HTTP server:
  $ servefile -u /tmp/ -p 8484 &
  $ servefile_pid="$!"

Check PeriodicFileTransfer enable/disable functionality:

Check PeriodicFileTransfer profile creation in the data model:
  $ R 'ba-cli "Device.PeriodicFileTransfer.Profile+{Alias=\"cram-Profile-1\"}"'
  $ R "ba-cli \"Device.PeriodicFileTransfer.Profile.cram-Profile-1.HTTP.URL=\"http://$TARGET_LAN_TEST_HOST:8484\"\""

Check PeriodicFileTransfer transfer instance creation:
  $ R 'ba-cli "Device.PeriodicFileTransfer.Transfer.+{Alias=\"cram-Transfer-1\", ProfileReference=\"Device.PeriodicFileTransfer.Profile.2\", UploadInterval=3600}"'

Check PeriodicFileTransfer on demand file upload:

  $ R 'ba-cli "Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.ForceTransfer()"'
  ERROR: call PeriodicFileTransfer.Transfer.cram-Transfer-1.ForceTransfer() failed with status 1 - unknown error

  $ R 'ba-cli "Device.PeriodicFileTransfer.Profile.cram-Profile-1.Enable=1"'

  $ R 'ba-cli "Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.ForceTransfer()"'
  [
    {
        data = "Transfer ended with error code (0)"
    }
  ]

Check PeriodicFileTransfer on demand file upload with GZIP compression:
  $ R 'ba-cli "Device.PeriodicFileTransfer.Profile.cram-Profile-1.HTTP.Compression=GZIP"'
  $ R 'ba-cli "Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.ForceTransfer()"'
  [
    {
        data = "Transfer ended with error code (0)"
    }
  ]

Check PeriodicFileTransfer periodic upload with configured intervals
  $ R 'ba-cli "Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.UploadInterval=30"'
  $ R 'ba-cli "Device.PeriodicFileTransfer.Profile.cram-Profile-1.Enable=0"'
  $ R 'ba-cli "Device.PeriodicFileTransfer.Profile.cram-Profile-1.Enable=1"'
  

Check PeriodicFileTransfer retry mechanism for failed uploads:


Check PeriodicFileTransfer error code reporting for various failure scenarios

Stop Servefile:
  $ kill "$servefile_pid"