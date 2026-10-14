SPDX-FileCopyrightText: Copyright (c) 2026 prpl Foundation

USP GetSupportedDM from the controller to the DUT agent over MQTT. The reply
describes the data model that this firmware supports, so it is fixed for one
firmware build:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/usp-controller.sh"

The parameters, tables and commands directly below one object:

  $ testbed-qemu usp supported-dm --first-level-only Device.Time.
  Device.Time. object
  Device.Time.Client.{i}. object access=OBJ_ADD_DELETE multi_instance=true
  Device.Time.ClientNumberOfEntries parameter type=PARAM_UNSIGNED_INT value_change=VALUE_CHANGE_ALLOWED
  Device.Time.CurrentLocalTime parameter type=PARAM_DATE_TIME value_change=VALUE_CHANGE_WILL_IGNORE
  Device.Time.Enable parameter access=PARAM_READ_WRITE type=PARAM_BOOLEAN value_change=VALUE_CHANGE_ALLOWED
  Device.Time.LocalTimeZone parameter access=PARAM_READ_WRITE type=PARAM_STRING value_change=VALUE_CHANGE_ALLOWED
  Device.Time.Server.{i}. object access=OBJ_ADD_DELETE multi_instance=true
  Device.Time.ServerNumberOfEntries parameter type=PARAM_UNSIGNED_INT value_change=VALUE_CHANGE_ALLOWED
  Device.Time.Status parameter type=PARAM_STRING value_change=VALUE_CHANGE_ALLOWED
  Device.Time.X_PRPLWARE-COM_SetTime() command type=CMD_SYNC input=Time,TimeZone

A command with its input and output arguments. A path with an instance number
gives the same reply as the path with "{i}":

  $ testbed-qemu usp supported-dm --first-level-only --no-params 'Device.LocalAgent.Certificate.{i}.'
  Device.LocalAgent.Certificate.{i}. object multi_instance=true
  Device.LocalAgent.Certificate.{i}.GetFingerprint() command type=CMD_SYNC input=FingerprintAlgorithm output=Fingerprint
  $ testbed-qemu usp supported-dm --first-level-only --no-params Device.LocalAgent.Certificate.1.
  Device.LocalAgent.Certificate.{i}. object multi_instance=true
  Device.LocalAgent.Certificate.{i}.GetFingerprint() command type=CMD_SYNC input=FingerprintAlgorithm output=Fingerprint

Events with their arguments, without parameters and commands:

  $ testbed-qemu usp supported-dm --first-level-only --no-params --no-commands Device.LocalAgent.
  Device.LocalAgent. object
  Device.LocalAgent.Certificate.{i}. object multi_instance=true
  Device.LocalAgent.Controller.{i}. object access=OBJ_ADD_DELETE multi_instance=true
  Device.LocalAgent.ControllerTrust. object
  Device.LocalAgent.MTP.{i}. object access=OBJ_ADD_DELETE multi_instance=true
  Device.LocalAgent.Periodic! event
  Device.LocalAgent.Request.{i}. object multi_instance=true
  Device.LocalAgent.Subscription.{i}. object access=OBJ_ADD_DELETE multi_instance=true
  Device.LocalAgent.TransferComplete! event arguments=TransferURL,Affected,FaultCode,StartTime,Requestor,CompleteTime,Command,CommandKey,TransferType,FaultString

The unique key sets of a table:

  $ testbed-qemu usp supported-dm --first-level-only --no-params --no-commands --no-events --unique-key-sets 'Device.LocalAgent.Subscription.{i}.'
  Device.LocalAgent.Subscription.{i}. object access=OBJ_ADD_DELETE multi_instance=true
  Device.LocalAgent.Subscription.{i}. unique_keys=Alias
  Device.LocalAgent.Subscription.{i}. unique_keys=ID,Recipient

A path that is not in the data model gives error 7026:

  $ testbed-qemu usp supported-dm Device.NoSuchObject.
  error: 7026 Device.NoSuchObject.: DM_PRIV_GetNodeFromPath: Path is invalid: Device.NoSuchObject.
  [1]
