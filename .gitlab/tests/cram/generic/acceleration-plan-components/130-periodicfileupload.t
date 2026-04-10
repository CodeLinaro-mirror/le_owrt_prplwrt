Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ export SERVER_IP="`ip route | grep "192.168.1.0/24" | grep -o "src [0-9.]*" | cut -d' ' -f2 | head -1`"

Install servefile from pip as a workaround until PPW-1258 is fixed:

  $ export PATH=$PATH:/home/testbed/.local/bin
  $ pip install servefile >/dev/null 2>&1

Start Servefile to act as HTTP server:

  $ servefile -u /tmp/130-periodicfileuploads/ -p 8181 >/dev/null 2>&1 &
  $ servefile_pid="$!"

Check PeriodicFileTransfer profile creation in the data model:

  $ R "ba-cli 'Device.PeriodicFileTransfer.Profile+{Alias=\"cram-Profile-1\"}'" > /dev/null
  $ R "ba-cli 'Device.PeriodicFileTransfer.Profile.cram-Profile-1.HTTP.URL=\"http://$SERVER_IP:8181\"'" > /dev/null
  $ R 'ba-cli "Device.PeriodicFileTransfer.Profile.cram-Profile-1.HTTP.Compression=\"None\""' > /dev/null; sleep 1
  $ R 'ba-cli "Device.PeriodicFileTransfer.Profile.cram-Profile-1.?"' | grep -v '>'
  Device.PeriodicFileTransfer.Profile.(.+). (re)
  Device.PeriodicFileTransfer.Profile.(.+).Alias="cram-Profile-1" (re)
  Device.PeriodicFileTransfer.Profile.(.+).Name="" (re)
  Device.PeriodicFileTransfer.Profile.(.+).Protocol="HTTP" (re)
  Device.PeriodicFileTransfer.Profile.(.+).HTTP. (re)
  Device.PeriodicFileTransfer.Profile.(.+).HTTP.CABundle="" (re)
  Device.PeriodicFileTransfer.Profile.(.+).HTTP.Certificate="" (re)
  Device.PeriodicFileTransfer.Profile.(.+).HTTP.Compression="None" (re)
  Device.PeriodicFileTransfer.Profile.(.+).HTTP.IPVersion=-1 (re)
  Device.PeriodicFileTransfer.Profile.(.+).HTTP.Method="POST" (re)
  Device.PeriodicFileTransfer.Profile.(.+).HTTP.Password="" (re)
  Device.PeriodicFileTransfer.Profile.(.+).HTTP.RequestHeaderParameterNumberOfEntries=0 (re)
  Device.PeriodicFileTransfer.Profile.(.+).HTTP.RequestURIParameterNumberOfEntries=0 (re)
  Device.PeriodicFileTransfer.Profile.(.+).HTTP.RetryEnable=0 (re)
  Device.PeriodicFileTransfer.Profile.(.+).HTTP.RetryIntervalMultiplier=2000 (re)
  Device.PeriodicFileTransfer.Profile.(.+).HTTP.RetryMinimumWaitInterval=5 (re)
  Device.PeriodicFileTransfer.Profile.(.+).HTTP.URL="http://(.*):8181" (re)
  Device.PeriodicFileTransfer.Profile.(.+).HTTP.Username="" (re)
  

Check PeriodicFileTransfer transfer instance creation:

  $ R 'ba-cli "Device.PeriodicFileTransfer.Transfer.+{Alias=\"cram-Transfer-1\", ProfileReference=\"Device.PeriodicFileTransfer.Profile.cram-Profile-1\", Type=\"KernelFaults\"}"' > /dev/null
  $ R 'ba-cli "Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.UploadInterval=3600"' > /dev/null
  $ R 'ba-cli "Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.Enable=1"' > /dev/null; sleep 1
  $ R 'ba-cli "Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.?0"' | grep -v '>'
  Device.PeriodicFileTransfer.Transfer.(.+). (re)
  Device.PeriodicFileTransfer.Transfer.(.+).Alias="cram-Transfer-1" (re)
  Device.PeriodicFileTransfer.Transfer.(.+).Enable=1 (re)
  Device.PeriodicFileTransfer.Transfer.(.+).FileReference="" (re)
  Device.PeriodicFileTransfer.Transfer.(.+).NextTransferDate="\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z" (re)
  Device.PeriodicFileTransfer.Transfer.(.+).Origin="System" (re)
  Device.PeriodicFileTransfer.Transfer.(.+).ProfileReference="Device.PeriodicFileTransfer.Profile.(.+)" (re)
  Device.PeriodicFileTransfer.Transfer.(.+).Status="Idle" (re)
  Device.PeriodicFileTransfer.Transfer.(.+).TimeReference="1970-01-01T00:00:00Z" (re)
  Device.PeriodicFileTransfer.Transfer.(.+).Type="KernelFaults" (re)
  Device.PeriodicFileTransfer.Transfer.(.+).UploadInterval=3600 (re)
  Device.PeriodicFileTransfer.Transfer.(.+).X_PRPLWARE-COM_ForceTransfer=0 (re)
  

Check PeriodicFileTransfer on demand file upload:

  $ R 'ba-cli "Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.ForceTransfer()"' | grep -v '>'; sleep 1
  Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.ForceTransfer() returned
  [
      {
          data = "Transfer ended with error code (0)"
      }
  ]
  

  $ ls /tmp/130-periodicfileuploads/; rm /tmp/130-periodicfileuploads/*
  oops.tar

Check PeriodicFileTransfer on demand file upload with GZIP compression:

  $ R 'ba-cli "Device.PeriodicFileTransfer.Profile.cram-Profile-1.HTTP.Compression=GZIP"' | grep -v '>'; sleep 1
  Device.PeriodicFileTransfer.Profile.(.+).HTTP. (re)
  Device.PeriodicFileTransfer.Profile.(.+).HTTP.Compression="GZIP" (re)
  

  $ R 'ba-cli "Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.ForceTransfer()"' | grep -v '>'
  Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.ForceTransfer() returned
  [
      {
          data = "Transfer ended with error code (0)"
      }
  ]
  

  $ ls /tmp/130-periodicfileuploads/; rm /tmp/130-periodicfileuploads/*
  oops.tar


Check PeriodicFileTransfer periodic upload with configured intervals

  $ R 'ba-cli "Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.Enable=0"' > /dev/null
  $ R 'ba-cli "Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.UploadInterval=3"' | grep -v '>'; sleep 1
  Device.PeriodicFileTransfer.Transfer.(.+). (re)
  Device.PeriodicFileTransfer.Transfer.(.+).UploadInterval=3 (re)
  
  $ R 'ba-cli "Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.Enable=1"' > /dev/null; sleep 7
  $ ls /tmp/130-periodicfileuploads/ |wc -l ; rm /tmp/130-periodicfileuploads/*
  2

Stop Servefile:

  $ kill -9 "$servefile_pid"

Check PeriodicFileTransfer retry mechanism for failed uploads:

  $ R 'ba-cli "Device.PeriodicFileTransfer.Profile.cram-Profile-1.HTTP.RetryIntervalMultiplier=2000"' > /dev/null
  $ R 'ba-cli "Device.PeriodicFileTransfer.Profile.cram-Profile-1.HTTP.RetryMinimumWaitInterval=3"' > /dev/null
  $ R 'ba-cli "Device.PeriodicFileTransfer.Profile.cram-Profile-1.HTTP.RetryEnable=1"' > /dev/null; sleep 1
  $ R 'ba-cli "Device.PeriodicFileTransfer.Profile.cram-Profile-1.?"' | grep -v '>'
  Device.PeriodicFileTransfer.Profile.(.+). (re)
  Device.PeriodicFileTransfer.Profile.(.+).Alias="cram-Profile-1" (re)
  Device.PeriodicFileTransfer.Profile.(.+).Name="" (re)
  Device.PeriodicFileTransfer.Profile.(.+).Protocol="HTTP" (re)
  Device.PeriodicFileTransfer.Profile.(.+).HTTP. (re)
  Device.PeriodicFileTransfer.Profile.(.+).HTTP.CABundle="" (re)
  Device.PeriodicFileTransfer.Profile.(.+).HTTP.Certificate="" (re)
  Device.PeriodicFileTransfer.Profile.(.+).HTTP.Compression="GZIP" (re)
  Device.PeriodicFileTransfer.Profile.(.+).HTTP.IPVersion=-1 (re)
  Device.PeriodicFileTransfer.Profile.(.+).HTTP.Method="POST" (re)
  Device.PeriodicFileTransfer.Profile.(.+).HTTP.Password="" (re)
  Device.PeriodicFileTransfer.Profile.(.+).HTTP.RequestHeaderParameterNumberOfEntries=0 (re)
  Device.PeriodicFileTransfer.Profile.(.+).HTTP.RequestURIParameterNumberOfEntries=0 (re)
  Device.PeriodicFileTransfer.Profile.(.+).HTTP.RetryEnable=1 (re)
  Device.PeriodicFileTransfer.Profile.(.+).HTTP.RetryIntervalMultiplier=2000 (re)
  Device.PeriodicFileTransfer.Profile.(.+).HTTP.RetryMinimumWaitInterval=3 (re)
  Device.PeriodicFileTransfer.Profile.(.+).HTTP.URL="http://(.*):8181" (re)
  Device.PeriodicFileTransfer.Profile.(.+).HTTP.Username="" (re)
  
  $ sleep 2
  $ R 'ba-cli "Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.Status?0"' | grep -v '>'
  Device.PeriodicFileTransfer.Transfer.(.+).Status="Retrying" (re)
  
  $ servefile -u /tmp/130-periodicfileuploads/ -p 8181 >/dev/null 2>&1 &
  $ servefile_pid="$!"
  $ sleep 6

Check PeriodicFileTransfer over HTTPS:

  $ R 'ba-cli "Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.Enable=0"' > /dev/null
  $ R 'ba-cli "Device.PeriodicFileTransfer.Profile.cram-Profile-1.HTTP.RetryEnable=0"' > /dev/null; sleep 1
  $ R 'ba-cli "Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.UploadInterval=86400"' > /dev/null; sleep 1
  $ R 'ba-cli "Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.Enable=1"' > /dev/null
  $ kill -9 "$servefile_pid"
  $ servefile -u /tmp/130-periodicfileuploads/ -p 8181 --ssl >/dev/null 2>&1 &
  $ servefile_pid="$!"
  $ sleep 2
  $ R "openssl s_client -connect \"$SERVER_IP:8181\" -showcerts < /dev/null 2> /dev/null | openssl x509 -outform PEM > /tmp/server-cert.crt"; sleep 1
  $ R "echo '%populate{object Security{object CABundle{instance add(){parameter Enable=1; parameter CAFileURI=\"/tmp/server-cert.crt\";}}}}' > /etc/amx/tr181-security/extensions/01_cram_periodic_transfer.odl" ; sleep 1
  $ R '/etc/init.d/tr181-security restart'; sleep 1
  $ R 'ba-cli "Device.PeriodicFileTransfer.Profile.cram-Profile-1.Protocol=HTTPS"' > /dev/null; sleep 1
  $ R 'ba-cli "Device.PeriodicFileTransfer.Profile.cram-Profile-1.HTTP.CABundle=Device.Security.CABundle.1"' > /dev/null; sleep 1
  $ R "ba-cli 'Device.PeriodicFileTransfer.Profile.cram-Profile-1.HTTP.URL=\"https://$SERVER_IP:8181\"'" > /dev/null; sleep 1
  $ R 'ba-cli "Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.ForceTransfer()"' | grep -v '>' ; sleep 1
  Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.ForceTransfer() returned
  [
      {
          data = "Transfer ended with error code (0)"
      }
  ]
  

Check PeriodicFileTransfer error code reporting for various failure scenarios:

  $ kill -9 "$servefile_pid"
  $ R 'ba-cli "Device.PeriodicFileTransfer.Profile.cram-Profile-1.Protocol=HTTP"' > /dev/null; sleep 1
  $ R 'ba-cli "Device.PeriodicFileTransfer.Profile.cram-Profile-1.HTTP.CABundle="' > /dev/null; sleep 1
  $ R "ba-cli 'Device.PeriodicFileTransfer.Profile.cram-Profile-1.HTTP.URL=\"http://$SERVER_IP:8181\"'" > /dev/null; sleep 1
  $ R 'ba-cli "Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.ForceTransfer()"' | grep -v '>'
  ERROR: call (null) failed with status 1 - unknown error
  Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.ForceTransfer() returned
  [
      {
          data = "Transfer ended with error code (9015)"
      }
  ]
  
  $ servefile -u /tmp/130-periodicfileuploads/ -p 8181 -a prpl:prpl >/dev/null 2>&1 &
  $ servefile_pid="$!"
  $ sleep 1
  $ R 'ba-cli "Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.ForceTransfer()"' | grep -v '>'; sleep 1
  ERROR: call (null) failed with status 1 - unknown error
  Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.ForceTransfer() returned
  [
      {
          data = "Transfer ended with error code (9012)"
      }
  ]
  
  $ kill -9 "$servefile_pid"
  $ servefile -u /tmp/130-periodicfileuploads/ -p 8181 --ssl >/dev/null 2>&1 &
  $ servefile_pid="$!"
  $ sleep 1
  $ R 'ba-cli "Device.PeriodicFileTransfer.Profile.cram-Profile-1.Protocol=HTTPS"' > /dev/null; sleep 1
  $ R "ba-cli 'Device.PeriodicFileTransfer.Profile.cram-Profile-1.HTTP.URL=\"https://$SERVER_IP:8181\"'" > /dev/null; sleep 1
  $ R 'ba-cli "Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.ForceTransfer()"' | grep -v '>'; sleep 1
  ERROR: call (null) failed with status 1 - unknown error
  Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.ForceTransfer() returned
  [
      {
          data = "Transfer ended with error code (9003)"
      }
  ]
  

Cleanup test instances:

  $ R 'rm -rf /etc/amx/tr181-security/extensions/01_cram_periodic_transfer.odl'
  $ R '/etc/init.d/tr181-security restart'
  $ R 'rm /tmp/server-cert.crt'
  $ rm -rf /tmp/130-periodicfileuploads/*
  $ R 'ba-cli "Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.Enable=0"' > /dev/null; sleep 1
  $ R 'ba-cli "Device.PeriodicFileTransfer.Transfer.cram-Transfer-1.-"' > /dev/null; sleep 1
  $ R 'ba-cli "Device.PeriodicFileTransfer.Profile.cram-Profile-1.-"' > /dev/null; sleep 1
  $ kill -9 "$servefile_pid"
