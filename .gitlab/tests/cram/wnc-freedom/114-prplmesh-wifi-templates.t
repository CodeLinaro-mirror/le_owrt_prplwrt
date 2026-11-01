Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"
  $ . "${TESTDIR}/../scripts/wifi_templates.sh"

  $ R logger -t cram "Starting $TESTFILE"

Enable Data Elements VAP configuration:

  $ R ba-cli X_PRPLWARE-COM_Controller.UseDataElementsVapConfigs=1 >/dev/null

Restart prplMesh:

  $ prplmesh_stop

  $ prplmesh_start

Verify Agent Management Mode:

  $ R ba-cli -l X_PRPLWARE-COM_Agent.Info.ManagementMode?
  
  Multi-AP-Controller-and-Agent

Verify default templates:

  $ wifi_dm "Templates.BSSTemplate.*.SSID?" | LC_ALL=C sort
  Device.WiFi.Templates.BSSTemplate.1.SSID="PRPL-PRIVATE-5G"
  Device.WiFi.Templates.BSSTemplate.2.SSID="PRPL-GUEST-2G"
  Device.WiFi.Templates.BSSTemplate.3.SSID="PRPL-BH-5G"

Enable default BSS templates:

  $ templates_start

  $ sleep 20

Verify deployed SSIDs:

  $ get_ap_ssid | grep "PRPL-PRIVATE-5G"
  Device.WiFi.SSID.*.SSID="PRPL-PRIVATE-5G" (glob)

  $ get_ap_ssid | grep "PRPL-GUEST-2G"
  Device.WiFi.SSID.*.SSID="PRPL-GUEST-2G" (glob)

  $ get_ap_ssid | grep "PRPL-BH-5G"
  Device.WiFi.SSID.*.SSID="PRPL-BH-5G" (glob)

Set BSSTemplate.1 to PCM:

  $ R "ba-cli Device.WiFi.Templates.BSSTemplate.1.Enable=0" >/dev/null
  $ R "ba-cli Device.WiFi.Templates.BSSTemplate.1.SecurityGroupReference=X_PRPLWARE-COM_Templates.SecurityGroup.4" >/dev/null
  $ R "ba-cli Device.WiFi.Templates.BSSTemplate.1.Enable=1" >/dev/null

  $ sleep 10

Verify Security Group:

  $ wifi_dm "Templates.BSSTemplate.1.SecurityGroupReference?"
  Device.WiFi.Templates.BSSTemplate.1.SecurityGroupReference="X_PRPLWARE-COM_Templates.SecurityGroup.4"

Verify PCM mode:

  $ wifi_dm 'AccessPoint.[SSIDReference+.SSID=="PRPL-PRIVATE-5G"].Security.ModeEnabled?'
  Device.WiFi.AccessPoint.3.Security.ModeEnabled="WPA3-Personal-Compatibility"

Configure colocated 3-link MLO:

  $ templates_configure_mlo

  $ sleep 60

Verify APMLD association:

  $ apmld_id=$(R "ba-cli 'Device.WiFi.Templates.APMLDTemplate.1.APMLDTemplateID?'" | sed -n 's/.*APMLDTemplateID=//p' | head -n 1 | tr -d '"')
  $ test -n "$apmld_id"

  $ wifi_dm "Templates.BSSTemplate.*.LinkedAPMLDTemplateID?" | grep -c "$apmld_id"  
  3

Verify MLO configuration:

  $ R iw dev | grep "ssid TEST_MLO"
  *ssid TEST_MLO* (glob)

  $ mldunit=$(R "ba-cli 'Device.WiFi.SSID.[SSID==\"TEST_MLO\"].MLDUnit?'" | sed -n 's/.*MLDUnit=//p' | head -n 1 | tr -d '"')
  $ test -n "$mldunit"
  $ test "$mldunit" != "-1"
  $ R "ba-cli -l Device.WiFi.APMLD.[MLDID==${mldunit}].AffiliatedAPNumberOfEntries?" | sed '/^$/d'
  3
  $ iw_affliated_link_info_from_mldid ${mldunit} | grep -v channel
  addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  link 0
  link 1
  link 2

Restore default BSS templates:

  $ templates_restore_defaults

  $ wifi_dm "Templates.BSSTemplate.*.SSID?" | LC_ALL=C sort
  Device.WiFi.Templates.BSSTemplate.1.SSID="PRPL-PRIVATE-5G"
  Device.WiFi.Templates.BSSTemplate.2.SSID="PRPL-GUEST-2G"
  Device.WiFi.Templates.BSSTemplate.3.SSID="PRPL-BH-5G"
