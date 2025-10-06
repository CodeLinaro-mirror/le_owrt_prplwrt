Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Start Servefile to act as HTTP server:
  $ servefile -u /130-periodicfileuploads/ -p 8484 &
  $ servefile_pid="$!"

Check PeriodicFileTransfer enable/disable functionality:

Check PeriodicFileTransfer profile creation in the data model:
  $ R 'ba-cli "Device.PeriodicFileTransfer.Profile+{Alias=\"cram-Profile-1\"}"' > /dev/null; sleep 1
  $ R "ba-cli \"Device.PeriodicFileTransfer.Profile.cram-Profile-1.HTTP.URL=\"http://192.168.1.50:8484\"\"" > /dev/null; sleep 1
  $ R "ba-cli \"Device.PeriodicFileTransfer.Profile.cram-Profile-1.HTTP.Compression=\"None\"\"" > /dev/null; sleep 1
  $ R "ba-cli \"Device.PeriodicFileTransfer.Profile.cram-Profile-1.?\"" | grep -v '>'
  Device.PeriodicFileTransfer.Profile.2.
  Device.PeriodicFileTransfer.Profile.2.Alias="cram-Profile-1"
  Device.PeriodicFileTransfer.Profile.2.Enable=0
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
  $ R 'ba-cli "Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.?0"' | grep -v '>'
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
  

Check PeriodicFileTransfer on demand file upload:

  $ R 'ba-cli "Device.PeriodicFileTransfer.Profile.cram-Profile-1.Enable=1"' > /dev/null; sleep 1
  $ R 'ba-cli "Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.ForceTransfer()"' | grep -v '>'
  Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.ForceTransfer() returned
  [
      {
          data = "Transfer ended with error code (0)"
      }
  ]
  

  $ ls /130-periodicfileuploads/; rm /130-periodicfileuploads/*
   oops.tar
  


Check PeriodicFileTransfer on demand file upload with GZIP compression:
  $ R 'ba-cli "Device.PeriodicFileTransfer.Profile.cram-Profile-1.HTTP.Compression=GZIP"' | grep -v '>'; sleep 1
  Device.PeriodicFileTransfer.Profile.2.HTTP.
  Device.PeriodicFileTransfer.Profile.2.HTTP.Compression="GZIP"
  


  $ R 'ba-cli "Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.ForceTransfer()"' | grep -v '>'
  Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.ForceTransfer() returned
  [
      {
          data = "Transfer ended with error code (0)"
      }
  ]
  

  $ ls /130-periodicfileuploads/; rm /130-periodicfileuploads/*
   oops.tar
  


Check PeriodicFileTransfer periodic upload with configured intervals
  $ R 'ba-cli "Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.UploadInterval=10"' | grep -v '>'; sleep 1
  Device.PeriodicFileTransfer.Transfer.3.
  Device.PeriodicFileTransfer.Transfer.3.UploadInterval=10
  

  $ R 'ba-cli "Device.PeriodicFileTransfer.Profile.cram-Profile-1.Enable=0"' > /dev/null; sleep 1
  $ R 'ba-cli "Device.PeriodicFileTransfer.Profile.cram-Profile-1.Enable=1"' > /dev/null; sleep 22
  $ ls /130-periodicfileuploads/; rm /130-periodicfileuploads/*
   oops.tar  'oops.tar(1)'
  

Check PeriodicFileTransfer retry mechanism for failed uploads:


Check PeriodicFileTransfer error code reporting for various failure scenarios

Stop Servefile:
  $ kill "$servefile_pid"

Cleanup test instances:
  $ R 'ba-cli "Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.Enable=0"' > /dev/null; sleep 1
  $ R 'ba-cli "Device.PeriodicFileTransfer.Profile.cram-Profile-1.Enable=0"' > /dev/null; sleep 1
