# Test for FEAT-376 - ODL-file default override of SFPs.AllowedSFPs
#
# Short description
# - Back up tr181-sfp's odl defaults.d directory and its persisted odl
#   save directory.
# - Drop an extra odl file into defaults.d that overrides AllowAllSFPs to
#   false and pre-populates a default AllowedSFP filter row, and move the
#   persisted save directory away so the defaults are loaded again.
# - Restart tr181-sfp and check the overridden default (false) and the
#   default filter row took effect.
# - Restore the original defaults.d and save directory, restart again, and
#   check the device is back to its starting state.
#
# tr181-sfp.odl configures dm-defaults = "defaults.d/", which resolves
# against the plugin's odl directory: /etc/amx/tr181-sfp/defaults.d/ (the
# same directory the component's makefile installs its shipped defaults
# to). amxrt only loads the files in there when the persisted odl
# directory (odl.directory = /etc/config/tr181-sfp/odl/, where dm-save
# writes tr181-sfp.odl) is missing or empty (libamxrt, amxrt_dm_load());
# once a save file exists there the defaults are skipped entirely. amxrt
# also saves the data model on exit (odl.dm-save = true), so the save
# directory must be moved away while the service is stopped - clearing it
# before a restart is undone by the save-on-exit of the stop phase.

  $ alias R="${CRAM_REMOTE_COMMAND:-ssh root@192.168.1.1}"

Check the starting values (default, per 050-allow_block_sfp.t's teardown)

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowAllSFPs?'" | grep -Ev '^(>|$)'
  SFPs.AllowedSFPs.AllowAllSFPs=1

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowedSFPNumberOfEntries?'" | grep -Ev '^(>|$)'
  SFPs.AllowedSFPs.AllowedSFPNumberOfEntries=0

Back up the odl defaults.d directory

  $ R "mkdir -p /etc/amx/tr181-sfp/defaults.d"
  $ R "mv /etc/amx/tr181-sfp/defaults.d /etc/amx/tr181-sfp/defaults.d.bak"

Drop an override file that sets a different default for AllowAllSFPs and
pre-populates a default AllowedSFP filter row (allow all optical Ethernet
SFPs, the same example used in the ODL documentation)

  $ R "mkdir -p /etc/amx/tr181-sfp/defaults.d"
  $ R "cat > /etc/amx/tr181-sfp/defaults.d/99_cram_override.odl" << 'EOF'
  > %populate {
  >     object SFPs.AllowedSFPs {
  >         parameter AllowAllSFPs = false;
  >         object AllowedSFP {
  >             instance add() {
  >                 parameter Enable = true;
  >                 parameter SFPType = "Optical Ethernet";
  >                 parameter VendorName = "";
  >                 parameter VendorOUI = "";
  >                 parameter VendorPN = "";
  >                 parameter Fingerprint = "";
  >             }
  >         }
  >     }
  > }
  > EOF

Stop tr181-sfp, move the persisted odl save directory away (amxrt writes it
again on exit, so this must happen while the service is stopped), then start
again so the defaults, including the override, are loaded

  $ R "/etc/init.d/tr181-sfp stop" > /dev/null 2>&1 ; sleep 1
  $ R "test -d /etc/config/tr181-sfp/odl && mv /etc/config/tr181-sfp/odl /etc/config/tr181-sfp/odl.cram_bak || true"
  $ R "/etc/init.d/tr181-sfp start" > /dev/null 2>&1 ; sleep 2

Check the overridden default took effect

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowAllSFPs?'" | grep -Ev '^(>|$)'
  SFPs.AllowedSFPs.AllowAllSFPs=0

Check the default filter row took effect

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowedSFP.[SFPType==\"Optical Ethernet\"].?'" | grep -Ev '^(>|$)'
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\. (re)
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\.Alias="cpe-AllowedSFP-\d+" (re)
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\.Enable=1 (re)
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\.Fingerprint="" (re)
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\.SFPType="Optical Ethernet" (re)
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\.VendorName="" (re)
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\.VendorOUI="" (re)
  SFPs\.AllowedSFPs\.AllowedSFP\.\d+\.VendorPN="" (re)

Restore the state of the system

  $ R "/etc/init.d/tr181-sfp stop" > /dev/null 2>&1 ; sleep 1
  $ R "rm -rf /etc/amx/tr181-sfp/defaults.d"
  $ R "mv /etc/amx/tr181-sfp/defaults.d.bak /etc/amx/tr181-sfp/defaults.d"
  $ R "rm -rf /etc/config/tr181-sfp/odl"
  $ R "test -d /etc/config/tr181-sfp/odl.cram_bak && mv /etc/config/tr181-sfp/odl.cram_bak /etc/config/tr181-sfp/odl || true"
  $ R "/etc/init.d/tr181-sfp start" > /dev/null 2>&1 ; sleep 2

Check the device is back to its starting state

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowAllSFPs?'" | grep -Ev '^(>|$)'
  SFPs.AllowedSFPs.AllowAllSFPs=1

  $ R "ba-cli 'SFPs.AllowedSFPs.AllowedSFPNumberOfEntries?'" | grep -Ev '^(>|$)'
  SFPs.AllowedSFPs.AllowedSFPNumberOfEntries=0
