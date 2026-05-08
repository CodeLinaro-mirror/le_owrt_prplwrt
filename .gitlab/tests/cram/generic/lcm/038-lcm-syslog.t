## Setup test configuration
Setup the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ R logger -t cram Starting $TESTFILE
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ S=". /tmp/script_functions.sh"
  $ C ${TESTDIR}/script_functions.sh root@${TARGET_LAN_IP}:/tmp/script_functions.sh 2>/dev/null

### SYSLOG CONTAINER SECTION ###

C-1: Syslog API UDS support
###########################
Test support for the Syslog API by defining a syslog source that maps to a UDS
socket (e.g., /tmp/volatile_log.sock and /lcm/persistent_log.sock).

C-1-1 test /tmp/volatile_log.sock
#################################
Add the source

  $ R "ba-cli -l -j 'Device.Syslog.Source.+{Alias = \"C-1-1\", UnixDomainSocket.Enable = 1, UnixDomainSocket.Path = \"file:///tmp/volatile.sock\"}'"
  
  {"Device.Syslog.Source.*.":{"Alias":"C-1-1"}} (glob)
Add the action

  $ R "ba-cli -l -j 'Device.Syslog.Action.+{Alias = \"C-1-1\", SourceRef = \"Device.Syslog.Source.[ Alias == \\\"C-1-1\\\" ]\", LogFile.Enable = 1, LogFile.FilePath = \"file:///tmp/volatile.log\"}'"
  
  {"Device.Syslog.Action.*.":{"Alias":"C-1-1"}} (glob)
Sleep so the socket can be created

  $ R "sleep 1"

Assert the socket file exists

  $ R "ls /tmp/volatile.sock"
  /tmp/volatile.sock

Remove the added Source and Action

  $ R "ba-cli -l -j 'Device.Syslog.Action.[Alias == \"C-1-1\"].-'"
  
  ["Device.Syslog.Action.*.","Device.Syslog.Action.*.LogFile.","Device.Syslog.Action.*.LogRemote."] (glob)

  $ R "ba-cli -l -j 'Device.Syslog.Source.[Alias == \"C-1-1\"].-'"
  
  ["Device.Syslog.Source.*.","Device.Syslog.Source.*.Network.","Device.Syslog.Source.*.UnixDomainSocket."] (glob)

C-1-2 test /lcm/volatile_log.sock
#################################
Add the source

  $ R "ba-cli -l -j 'Device.Syslog.Source.+{Alias = \"C-1-2\", UnixDomainSocket.Enable = 1, UnixDomainSocket.Path = \"file:///lcm/volatile.sock\"}'"
  
  {"Device.Syslog.Source.*.":{"Alias":"C-1-2"}} (glob)
Add the action

  $ R "ba-cli -l -j 'Device.Syslog.Action.+{Alias = \"C-1-2\", SourceRef = \"Device.Syslog.Source.[ Alias == \\\"C-1-2\\\" ]\", LogFile.Enable = 1, LogFile.FilePath = \"file:///lcm/volatile.log\"}'"
  
  {"Device.Syslog.Action.*.":{"Alias":"C-1-2"}} (glob)
Sleep so the socket can be created

  $ R "sleep 1"

Assert the socket file exists

  $ R "ls /lcm/volatile.sock"
  /lcm/volatile.sock

Remove the add Source and Action

  $ R "ba-cli -l -j 'Device.Syslog.Action.[Alias == \"C-1-2\"].-'"
  
  ["Device.Syslog.Action.*.","Device.Syslog.Action.*.LogFile.","Device.Syslog.Action.*.LogRemote."] (glob)

  $ R "ba-cli -l -j 'Device.Syslog.Source.[Alias == \"C-1-2\"].-'"
  
  ["Device.Syslog.Source.*.","Device.Syslog.Source.*.Network.","Device.Syslog.Source.*.UnixDomainSocket."] (glob)


C-2: Test Syslog Plugin Default Configuration
#############################################
- Verify the existence of a default parameter (LogLocation) that defines the
default location for storing containers' logs.
- Check that the default value points to /lcm/cthulhu/syslog.

  $ R "ba-cli -l -j \"Cthulhu.Config.Syslog.LogLocation?\" | jsonfilter -e @[*].*.LogLocation"
  /lcm/cthulhu/syslog


C-3: Test Syslog Configuration
##############################
Install a test container and verify the following:
- A dedicated entry is created under Syslog.Source.xxx, and the UDS socket is set.
- Dedicated Template and Action entries are also created.

Create the container

  $ R "${S} && install_ctr --version prplos-v1 --ee --uuid --privileged true"
  
  SoftwareModules.InstallDU() returned
  ["",{"err_code":0,"err_msg":""}]
Check the syslog source

  $ R "ba-cli -l -j \"Device.Syslog.Source.[ Alias == \\\"cpe-917362a3-86e8-5332-bcfd-a4223f0e65e6\\\"].UnixDomainSocket.?\" | jsonfilter -e @[*].*.Enable -e @[*].*.Path"
  1
  file:///var/run/cthulhu/syslog/917362a3-86e8-5332-bcfd-a4223f0e65e6/log.sock

Check the Template

  $ R "ba-cli -l -j \"Device.Syslog.Template.[ Alias == \\\"cpe-917362a3-86e8-5332-bcfd-a4223f0e65e6\\\"].?\" | jsonfilter -e @[*].*.Expression"
  "${FULLDATE} 917362a3-86e8-5332-bcfd-a4223f0e65e6 ${MSGHDR}${MSG}
  "

Check the Action

  $ R "ba-cli -l -j \"Device.Syslog.Action.[ Alias == \\\"cpe-917362a3-86e8-5332-bcfd-a4223f0e65e6\\\"].?\" | jsonfilter -e @[*].*.Enable -e @[*].*.VendorLogFileRef -e @[*].*.FilePath -e @[*].*.SourceRef -e @[*].*.TemplateRef | sort"
  0
  1
  Device.DeviceInfo.VendorLogFile.* (glob)
  Device.Syslog.Source.* (glob)
  Device.Syslog.Template.* (glob)
  file:///lcm/cthulhu/syslog/917362a3-86e8-5332-bcfd-a4223f0e65e6/messages

Assert the socket file exists

  $ R "ls /var/run/cthulhu/syslog/917362a3-86e8-5332-bcfd-a4223f0e65e6/log.sock"
  /var/run/cthulhu/syslog/917362a3-86e8-5332-bcfd-a4223f0e65e6/log.sock

C-4: Test Logging From the Container
####################################
- Install a test container that supports logger, and generate some logs.
- Verify that the generated logs are visible in the dedicated log file (combining
the default log location and a reference to the container, e.g., /lcm/cthulhu/syslog/xxxxxx/messages).

reuse container from C-3

Clear log in container

  $ R "echo > /lcm/cthulhu/syslog/917362a3-86e8-5332-bcfd-a4223f0e65e6/messages"

Generate log in container

  $ R "${S} && execute_in_container --uuid --cmd 'logger test-C-4'"

Check content of the log file

  $ R "cat /lcm/cthulhu/syslog/917362a3-86e8-5332-bcfd-a4223f0e65e6/messages | grep \"test-C\""
  * 917362a3-86e8-5332-bcfd-a4223f0e65e6 root: test-C-4 (glob)

C-5: Test VendorLog
###################
- Install a test container.
- Check that ExecutionUnit.{i}.VendorLogList points to a valid
Device.DeviceInfo.VendorLogFile entry.
- Generate logs from within the container and verify that VendorLogFile.{i}.Name
matches the file to which the container logs (which should be prefixed by the
default LogLocation and container reference). 

reuse container from C-3

Check the VendorLogFile of the ExecutionUnit

  $ R "${S} && get_container_parameter --uuid --param VendorLogList"
  Device.DeviceInfo.VendorLogFile.* (glob)

Check the VendorLogFile object

  $ R "${S} && get_vendorlogfile_name --uuid"
  file:///lcm/cthulhu/syslog/917362a3-86e8-5332-bcfd-a4223f0e65e6/messages

Check the VendorLogFile content

  $ R "${S} && execute_in_container --uuid --cmd 'logger test-C-5'"
  $ R "${S} && get_vendorlogfile_content --uuid"
  file:///lcm/cthulhu/syslog/917362a3-86e8-5332-bcfd-a4223f0e65e6/messages
  * 917362a3-86e8-5332-bcfd-a4223f0e65e6 root: test-C-4 (glob)
  * 917362a3-86e8-5332-bcfd-a4223f0e65e6 root: test-C-5 (glob)

Uninstall the testing container and check datamodel cleaned:

  $ R "${S} && uninstall_ctr_and_check --uuid --retaindata false"
  [1]


C-6: Test Syslog Configuration unpriv
##############################
Install a test container and verify the following:
- A dedicated entry is created under Syslog.Source.xxx, and the UDS socket is set.
- Dedicated Template and Action entries are also created.

Create the container

  $ R "${S} && install_ctr --version prplos-v1 --ee --uuid --privileged false"
  
  SoftwareModules.InstallDU() returned
  ["",{"err_code":0,"err_msg":""}]
Check the syslog source

  $ R "ba-cli -l -j \"Device.Syslog.Source.[ Alias == \\\"cpe-917362a3-86e8-5332-bcfd-a4223f0e65e6\\\"].UnixDomainSocket.?\" | jsonfilter -e @[*].*.Enable -e @[*].*.Path"
  1
  file:///var/run/cthulhu/syslog/917362a3-86e8-5332-bcfd-a4223f0e65e6/log.sock

Check the Template

  $ R "ba-cli -l -j \"Device.Syslog.Template.[ Alias == \\\"cpe-917362a3-86e8-5332-bcfd-a4223f0e65e6\\\"].?\" | jsonfilter -e @[*].*.Expression"
  "${FULLDATE} 917362a3-86e8-5332-bcfd-a4223f0e65e6 ${MSGHDR}${MSG}
  "

Check the Action

  $ R "ba-cli -l -j \"Device.Syslog.Action.[ Alias == \\\"cpe-917362a3-86e8-5332-bcfd-a4223f0e65e6\\\"].?\" | jsonfilter -e @[*].*.Enable -e @[*].*.VendorLogFileRef -e @[*].*.FilePath -e @[*].*.SourceRef -e @[*].*.TemplateRef | sort"
  0
  1
  Device.DeviceInfo.VendorLogFile.* (glob)
  Device.Syslog.Source.* (glob)
  Device.Syslog.Template.* (glob)
  file:///lcm/cthulhu/syslog/917362a3-86e8-5332-bcfd-a4223f0e65e6/messages

Assert the socket file exists

  $ R "ls /var/run/cthulhu/syslog/917362a3-86e8-5332-bcfd-a4223f0e65e6/log.sock"
  /var/run/cthulhu/syslog/917362a3-86e8-5332-bcfd-a4223f0e65e6/log.sock

C-7: Test Logging From the Container
####################################
- Install a test container that supports logger, and generate some logs.
- Verify that the generated logs are visible in the dedicated log file (combining
the default log location and a reference to the container, e.g., /lcm/cthulhu/syslog/xxxxxx/messages).

reuse container from C-6

Generate log in container

  $ R "${S} && execute_in_container --uuid --cmd 'logger test-C-7'"

Check content of the log file

  $ R "cat /lcm/cthulhu/syslog/917362a3-86e8-5332-bcfd-a4223f0e65e6/messages | grep \"test-C\""
  * 917362a3-86e8-5332-bcfd-a4223f0e65e6 root: test-C-4 (glob)
  * 917362a3-86e8-5332-bcfd-a4223f0e65e6 root: test-C-5 (glob)
  * 917362a3-86e8-5332-bcfd-a4223f0e65e6 root: test-C-7 (glob)

C-8: Test VendorLog
###################
- Install a test container.
- Check that ExecutionUnit.{i}.VendorLogList points to a valid
Device.DeviceInfo.VendorLogFile entry.
- Generate logs from within the container and verify that VendorLogFile.{i}.Name
matches the file to which the container logs (which should be prefixed by the
default LogLocation and container reference). 

reuse container from C-6

Check the VendorLogFile of the ExecutionUnit

  $ R "${S} && get_container_parameter --uuid --param VendorLogList"
  Device.DeviceInfo.VendorLogFile.* (glob)

Check the VendorLogFile object

  $ R "${S} && get_vendorlogfile_name --uuid"
  file:///lcm/cthulhu/syslog/917362a3-86e8-5332-bcfd-a4223f0e65e6/messages

Check the VendorLogFile content

  $ R "${S} && execute_in_container --uuid --cmd 'logger test-C-8'"
  $ R "${S} && get_vendorlogfile_content --uuid"
  file:///lcm/cthulhu/syslog/917362a3-86e8-5332-bcfd-a4223f0e65e6/messages
  * 917362a3-86e8-5332-bcfd-a4223f0e65e6 root: test-C-4 (glob)
  * 917362a3-86e8-5332-bcfd-a4223f0e65e6 root: test-C-5 (glob)
  * 917362a3-86e8-5332-bcfd-a4223f0e65e6 root: test-C-7 (glob)
  * 917362a3-86e8-5332-bcfd-a4223f0e65e6 root: test-C-8 (glob)

Uninstall the testing container and check datamodel cleaned:

  $ R "${S} && uninstall_ctr_and_check --uuid --retaindata false"
  [1]


Cleanup test environment:

  $ R "rm -f /tmp/script_functions.sh"
  $ R logger -t cram Ended $TESTFILE
