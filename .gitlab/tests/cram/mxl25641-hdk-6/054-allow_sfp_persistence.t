# Persistence and factory defaults of SFPs.AllowedSFPs
#
# Short description
# - Put SFPs.AllowedSFPs in a non-default state (AllowAllSFPs=0 plus one
#   AllowedSFP row).
# - Stop and start tr181-sfp and check the non-default state was saved and is
#   loaded again.
# - Drop the persisted odl save directory while the plugin is stopped, start it
#   again, and check the data model is back to its factory defaults:
#   - Requirement: the whitelist is disabled (AllowAllSFPs back to allow-all),
#     so the gateway is not accidentally locked out of talking to the USP
#     controller (e.g. over an SFP-based WAN interface).
#   - Requirement: the whitelist database (AllowedSFP table) is empty again -
#     any addition done before does not survive and must be re-executed.
# - Check add/delete still work normally afterwards.
#
# Device.FactoryReset() is deliberately not used. What a factory reset does to
# this component is remove its persisted configuration, and that is reproduced
# here directly. Calling Device.FactoryReset() instead would wipe /etc for the
# whole board: it costs a full reboot, it destroys the configuration of every
# other component on a shared testbed, and it regenerates the DUT ssh host key,
# which breaks every remote command issued after it in the same job.
#
# This test stops and starts tr181-sfp. tr181-ethernet subscribes to the SFP
# cage and does not re-subscribe when tr181-sfp is restarted underneath it, so
# this test is numbered after 052-allow_sfp_vendor_match.t, which is the test
# that needs that subscription still live (cram runs the suite in filename
# order).
#
# Mechanics, as in 053-allow_sfp_odl_default.t: amxrt saves the data model on
# exit (odl.dm-save = true), so the save directory must be moved while the
# plugin is stopped - clearing it before a restart is undone by the save of the
# stop phase. amxrt reloads dm-defaults only when odl.directory
# (/etc/config/tr181-sfp/odl/, where dm-save writes tr181-sfp.odl) is missing or
# empty (libamxrt, amxrt_dm_load()). The shipped defaults.d is left untouched,
# so the board-data defaults (SFPCage, Mgmt) are loaded again as on a real
# factory reset.
#
# SFPPresent is neither persistent nor part of those defaults: tr181-sfp sets it
# from its discovery timer, which is armed on app:start and first fires a second
# later (sfp_discovery.c). Waiting for the data model to answer is therefore not
# enough to observe it, hence the separate wait on SFPPresent itself.

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Wait helpers: poll the predicate under test - tr181-sfp answering for its own
part of the data model - instead of sleeping for a fixed amount of time

  $ sfp_dm_up() {
  >     R "ba-cli 'SFPs.AllowedSFPs.AllowAllSFPs?'" 2> /dev/null | grep -q 'AllowAllSFPs='
  > }

  $ wait_sfp_stopped() {
  >     tries=0
  >     while sfp_dm_up; do
  >         tries=$((tries+1))
  >         [ "$tries" -ge 30 ] && return 1
  >         sleep 1
  >     done
  > }

  $ wait_sfp_started() {
  >     tries=0
  >     until sfp_dm_up; do
  >         tries=$((tries+1))
  >         [ "$tries" -ge 30 ] && return 1
  >         sleep 1
  >     done
  > }

  $ sfp_cage_populated() {
  >     R "ba-cli 'SFPs.SFPCage.1.SFPPresent?'" 2> /dev/null | grep -q 'SFPPresent=1'
  > }

  $ wait_sfp_cage_populated() {
  >     tries=0
  >     until sfp_cage_populated; do
  >         tries=$((tries+1))
  >         [ "$tries" -ge 30 ] && return 1
  >         sleep 1
  >     done
  > }

Check the starting values (default, per 050-allow_block_sfp.t's teardown)

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowAllSFPs?'" | grep -Ev '^(>|$)'
  SFPs.AllowedSFPs.AllowAllSFPs=1

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowedSFPNumberOfEntries?'" | grep -Ev '^(>|$)'
  SFPs.AllowedSFPs.AllowedSFPNumberOfEntries=0

Put SFPs.AllowedSFPs in a non-default state

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowAllSFPs=0'" | grep -Ev '^(>|$)'
  SFPs.AllowedSFPs.
  SFPs.AllowedSFPs.AllowAllSFPs=0

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowedSFP+{Enable=1,SFPType=\"Optical Ethernet\",VendorName=\"\",VendorOUI=\"\",VendorPN=\"\",Fingerprint=\"\"}'" | grep -Ev '^(>|$)'
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\. (re)
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\.Alias="cpe-AllowedSFP-\d+" (re)

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowedSFPNumberOfEntries?'" | grep -Ev '^(>|$)'
  SFPs.AllowedSFPs.AllowedSFPNumberOfEntries=1

Stop and start tr181-sfp, and check the configuration was saved and is loaded
again (tr181-sfp.odl sets dm-save-delay = 1000, and amxrt saves on exit, so
stopping the plugin flushes the pending change)

  $ R "/etc/init.d/tr181-sfp stop" > /dev/null 2>&1
  $ wait_sfp_stopped
  $ R "/etc/init.d/tr181-sfp start" > /dev/null 2>&1
  $ wait_sfp_started

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowAllSFPs?'" | grep -Ev '^(>|$)'
  SFPs.AllowedSFPs.AllowAllSFPs=0

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowedSFPNumberOfEntries?'" | grep -Ev '^(>|$)'
  SFPs.AllowedSFPs.AllowedSFPNumberOfEntries=1

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowedSFP.[SFPType==\"Optical Ethernet\"].?'" | grep -Ev '^(>|$)'
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\. (re)
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\.Alias="cpe-AllowedSFP-\d+" (re)
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\.Enable=1 (re)
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\.Fingerprint="" (re)
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\.SFPType="Optical Ethernet" (re)
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\.VendorName="" (re)
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\.VendorOUI="" (re)
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\.VendorPN="" (re)

Remove this component's persisted configuration while the plugin is stopped -
the same thing a factory reset does to it - and start the plugin again so the
shipped defaults are loaded

  $ R "/etc/init.d/tr181-sfp stop" > /dev/null 2>&1
  $ wait_sfp_stopped
  $ R "test -d /etc/config/tr181-sfp/odl && mv /etc/config/tr181-sfp/odl /etc/config/tr181-sfp/odl.cram_bak || true"
  $ R "/etc/init.d/tr181-sfp start" > /dev/null 2>&1
  $ wait_sfp_started

Requirement: the whitelist is disabled again, so the gateway can talk to the
USP controller instead of being locked out by a stale AllowedSFP configuration

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowAllSFPs?'" | grep -Ev '^(>|$)'
  SFPs.AllowedSFPs.AllowAllSFPs=1

Requirement: the whitelist database is back to its factory defaults - the row
added before is gone

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowedSFPNumberOfEntries?'" | grep -Ev '^(>|$)'
  SFPs.AllowedSFPs.AllowedSFPNumberOfEntries=0

Check the SFP cage defaults were loaded again as well, so the plugin really did
start from its defaults and not from an empty data model

  $ wait_sfp_cage_populated
  $ R "ba-cli 'SFPs.SFPCage.1.SFPPresent?'" | grep -Ev '^(>|$)'
  SFPs.SFPCage.1.SFPPresent=1

Requirement: add/delete operations must be re-executed after the reset - prove
the table is fully functional again, not just empty

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowedSFP+{Enable=1,SFPType=\"Optical Ethernet\",VendorName=\"\",VendorOUI=\"\",VendorPN=\"\",Fingerprint=\"\"}'" | grep -Ev '^(>|$)'
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\. (re)
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\.Alias="cpe-AllowedSFP-\d+" (re)

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowedSFPNumberOfEntries?'" | grep -Ev '^(>|$)'
  SFPs.AllowedSFPs.AllowedSFPNumberOfEntries=1

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowedSFP.[SFPType==\"Optical Ethernet\"].-'" | grep -Ev '^(>|$)'
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\. (re)

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowedSFPNumberOfEntries?'" | grep -Ev '^(>|$)'
  SFPs.AllowedSFPs.AllowedSFPNumberOfEntries=0

Restore the state of the system: the data model is already back at the defaults
the other SFP tests expect, so only the saved copy of the non-default state has
to be dropped

  $ R "rm -rf /etc/config/tr181-sfp/odl.cram_bak"
