SPDX-FileCopyrightText: Copyright (c) 2026 prpl Foundation

USP GetInstances from the controller to the DUT agent over MQTT. The reply
gives each instance and its unique keys. The test reads rows that the
firmware creates and selects them by Alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/usp-controller.sh"

The instances of one table:

  $ testbed-qemu usp instances 'Device.IP.Interface.[Alias=="lan"].IPv4Address.'
  Device.IP.Interface.3.IPv4Address.1.
  Device.IP.Interface.3.IPv4Address.1.Alias="lan"
  Device.IP.Interface.3.IPv4Address.2.
  Device.IP.Interface.3.IPv4Address.2.Alias="public-lan"

With first_level_only the reply has the object itself and no instances of the
tables below it:

  $ testbed-qemu usp instances --first-level-only 'Device.IP.Interface.[Alias=="lan"].'
  Device.IP.Interface.3.
  Device.IP.Interface.3.Alias="lan"

Without first_level_only the reply also has the instances of the tables below
the object:

  $ testbed-qemu usp instances 'Device.IP.Interface.[Alias=="lan"].' | grep -e '^Device\.IP\.Interface\.3\.Alias=' -e '\.IPv4Address\.'
  Device.IP.Interface.3.Alias="lan"
  Device.IP.Interface.3.IPv4Address.1.
  Device.IP.Interface.3.IPv4Address.1.Alias="lan"
  Device.IP.Interface.3.IPv4Address.2.
  Device.IP.Interface.3.IPv4Address.2.Alias="public-lan"

A search expression that matches no instance is not an error:

  $ testbed-qemu usp instances 'Device.IP.Interface.[Alias=="no-such-interface"].'

A path that is not in the data model gives error 7026:

  $ testbed-qemu usp instances Device.NoSuchObject.
  error: 7026 Device.NoSuchObject.: CheckPathProperties: Path (Device.NoSuchObject) does not exist in the schema
  [1]
