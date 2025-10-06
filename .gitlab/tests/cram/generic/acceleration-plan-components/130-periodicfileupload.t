Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Start Servefile to act as HTTP server:
  $ servefile -u /tmp/ -p 8484 &
  $ servefile_pid="$!"

Check PeriodicFileTransfer enable/disable functionality:

 Check PeriodicFileTransfer profile creation in the data model:
  $ R 'ba-cli "Device.PeriodicFileTransfer.Profile+{Alias=\"cram-Profile-1\"}"' > /dev/null; sleep 1
  $ R "ba-cli \"Device.PeriodicFileTransfer.Profile.cram-Profile-1.HTTP.URL=\"http://192.168.1.50:8484\"\"" > /dev/null; sleep 1
  $ R "ba-cli \"Device.PeriodicFileTransfer.Profile.cram-Profile-1.HTTP.Compression=\"None\"\"" > /dev/null; sleep 1
  $ R "ba-cli \"Device.PeriodicFileTransfer.Profile.cram-Profile-1.?\""
  > Device.PeriodicFileTransfer.Profile.cram-Profile-1.?
  Device.PeriodicFileTransfer.Profile.2.
  Device.PeriodicFileTransfer.Profile.2.Alias="cram-Profile-1"
  Device.PeriodicFileTransfer.Profile.2.Enable=1
  Device.PeriodicFileTransfer.Profile.2.Name=""
  Device.PeriodicFileTransfer.Profile.2.Protocol="HTTP"
  Device.PeriodicFileTransfer.Profile.2.HTTP.
  Device.PeriodicFileTransfer.Profile.2.HTTP.CABundle=""
  Device.PeriodicFileTransfer.Profile.2.HTTP.Certificate=""
  Device.PeriodicFileTransfer.Profile.2.HTTP.Compression="None"
  Device.PeriodicFileTransfer.Profile.2.HTTP.CompressionsSupported="None,GZIP,Compress,Deflate"
  Device.PeriodicFileTransfer.Profile.2.HTTP.IPVersion=-1
  Device.PeriodicFileTransfer.Profile.2.HTTP.Method="POST"
  Device.PeriodicFileTransfer.Profile.2.HTTP.MethodsSupported="POST,PUT"
  Device.PeriodicFileTransfer.Profile.2.HTTP.Password=""
  Device.PeriodicFileTransfer.Profile.2.HTTP.RequestHeaderParameterNumberOfEntries=0
  Device.PeriodicFileTransfer.Profile.2.HTTP.RequestURIParameterNumberOfEntries=0
  Device.PeriodicFileTransfer.Profile.2.HTTP.RetryEnable=0
  Device.PeriodicFileTransfer.Profile.2.HTTP.RetryIntervalMultiplier=2000
  Device.PeriodicFileTransfer.Profile.2.HTTP.RetryMinimumWaitInterval=5
  Device.PeriodicFileTransfer.Profile.2.HTTP.URL="http://192.168.1.50:8484"
  Device.PeriodicFileTransfer.Profile.2.HTTP.Username=""

Check PeriodicFileTransfer transfer instance creation:
  $ R 'ba-cli "Device.PeriodicFileTransfer.Transfer.+{Alias=\"cram-Transfer-1\", ProfileReference=\"PeriodicFileTransfer.Profile.2\", Type=\"KernelFaults\", Enable=1, UploadInterval=3600}"' > /dev/null; sleep 1
  $ R 'ba-cli "Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.?"'
  > Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.?
  Device.PeriodicFileTransfer.Transfer.3.
  Device.PeriodicFileTransfer.Transfer.3.Alias="cram-Transfer-1"
  Device.PeriodicFileTransfer.Transfer.3.Enable=1
  Device.PeriodicFileTransfer.Transfer.3.FileReference=""
  Device.PeriodicFileTransfer.Transfer.3.NextTransferDate="2025-10-06T15:33:00Z"
  Device.PeriodicFileTransfer.Transfer.3.Origin="tr181-periodicfileupload"
  Device.PeriodicFileTransfer.Transfer.3.ProfileReference="PeriodicFileTransfer.Profile.2"
  Device.PeriodicFileTransfer.Transfer.3.Status="Idle"
  Device.PeriodicFileTransfer.Transfer.3.TimeReference="1970-01-01T00:00:00Z"
  Device.PeriodicFileTransfer.Transfer.3.Type="KernelFaults"
  Device.PeriodicFileTransfer.Transfer.3.UploadInterval=3600
  Device.PeriodicFileTransfer.Transfer.3.Stats.
  Device.PeriodicFileTransfer.Transfer.3.Stats.FailedCount=1
  Device.PeriodicFileTransfer.Transfer.3.Stats.LastErrorCode=9015
  Device.PeriodicFileTransfer.Transfer.3.Stats.LastFailed="2025-10-06T15:32:30.770819465Z"
  Device.PeriodicFileTransfer.Transfer.3.Stats.LastSuccess="2025-10-06T15:28:29.226808591Z"
  Device.PeriodicFileTransfer.Transfer.3.Stats.SuccessCount=1

Check PeriodicFileTransfer on demand file upload:

  $ R 'ba-cli "Device.PeriodicFileTransfer.Profile.cram-Profile-1.Enable=1"'
  > Device.PeriodicFileTransfer.Profile.cram-Profile-1.Enable=1
  Device.PeriodicFileTransfer.Profile.2.
  Device.PeriodicFileTransfer.Profile.2.Enable=1


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