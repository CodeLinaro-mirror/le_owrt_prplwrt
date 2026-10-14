SPDX-FileCopyrightText: Copyright (c) 2026 prpl Foundation

USP Operate of synchronous commands from the controller to the DUT agent over
MQTT. The commands only read state: one in an object of a USP service and one
in an object of the agent itself, with an input argument. The test selects
the rows by Name or Alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/usp-controller.sh"

A command with an output argument:

  $ testbed-qemu usp operate 'Device.Security.CABundle.[Name=="default"].CAFile()'
  Device.Security.CABundle.1.CAFile().CAFile="file:///etc/ssl/certs/ca-certificates.crt"

A command key does not change the reply of a synchronous command:

  $ testbed-qemu usp operate --command-key usp-msg-operate 'Device.Security.CABundle.[Name=="default"].CAFile()'
  Device.Security.CABundle.1.CAFile().CAFile="file:///etc/ssl/certs/ca-certificates.crt"

A wildcard runs the command on each instance:

  $ testbed-qemu usp operate 'Device.Security.CABundle.*.CAFile()'
  Device.Security.CABundle.1.CAFile().CAFile="file:///etc/ssl/certs/ca-certificates.crt"
  Device.Security.CABundle.2.CAFile().CAFile="file:///usr/share/ca-certificates/test/ca-certificate.crt"

A search expression that matches no instance runs nothing and is not an
error:

  $ testbed-qemu usp operate 'Device.Security.CABundle.[Name=="no-such-bundle"].CAFile()'

A command with an input argument. The fingerprint depends on the certificate
of the firmware build:

  $ testbed-qemu usp operate 'Device.LocalAgent.Certificate.[Alias=="cpe-1"].GetFingerprint()' FingerprintAlgorithm=SHA-256
  Device\.LocalAgent\.Certificate\.1\.GetFingerprint\(\)\.Fingerprint="[0-9A-F]{64}" (re)

An input value that the argument does not accept, and a missing input
argument:

  $ testbed-qemu usp operate 'Device.LocalAgent.Certificate.[Alias=="cpe-1"].GetFingerprint()' FingerprintAlgorithm=MD99
  error: 7012 Device.LocalAgent.Certificate.1.GetFingerprint(): KV_VECTOR_GetEnum: Illegal value (MD99) in argument FingerprintAlgorithm
  [1]
  $ testbed-qemu usp operate 'Device.LocalAgent.Certificate.[Alias=="cpe-1"].GetFingerprint()'
  error: 7004 Device.LocalAgent.Certificate.1.GetFingerprint(): Operate_GetFingerprint: FingerprintAlgorithm input argument not specified
  [1]

An instance that does not exist, and a command that is not in the data model:

  $ testbed-qemu usp operate 'Device.LocalAgent.Certificate.9999.GetFingerprint()' FingerprintAlgorithm=SHA-256
  error: 7016 CheckPathProperties: Object exists in schema, but instances are invalid: Device.LocalAgent.Certificate.9999.GetFingerprint()
  [1]
  $ testbed-qemu usp operate 'Device.NoSuchCommand()'
  error: 7026 CheckPathProperties: Path (Device.NoSuchCommand()) does not exist in the schema
  [1]
