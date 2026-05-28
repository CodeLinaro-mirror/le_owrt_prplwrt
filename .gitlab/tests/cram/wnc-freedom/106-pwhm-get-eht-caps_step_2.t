Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R "logger -t cram 'Starting EHT Operations test (step 2) ...'"

#########################################
#    test 6GHz getEHTOperations         #
#########################################

  $ R logger -t cram "Test getEHTOperations on 6GHz"

Check ChannelsInUse:

  $ wifi_dm_radio_band 6 "ChannelsInUse?"
  Device.WiFi.Radio.\d+.ChannelsInUse="33,37,41,45,49,53,57,61" (re)

Check EhtPhyCapabilities, EhtPhyCapabilitiesStr, CurrentEhtOperatingIE and getEHTOperations():

  $ R logger -t cram "Check EHT Capabilities"

  $ wifi_dm_radio_band 6 "EhtPhyCapabilities?"
  Device.WiFi.Radio.\d+.EhtPhyCapabilities="4v/b4Bh1AH4E" (re)

  $ wifi_dm_radio_band 6 "EhtPhyCapabilitiesStr?"
  Device.WiFi.Radio.\d+.EhtPhyCapabilitiesStr="320MHZ,SU_BEAMFORMER,SU_BEAMFORMEE,BEAMFORMEE_SS_80MHZ,BEAMFORMEE_SS_160MHZ,BEAMFORMEE_SS_320MHZ,NB_SOUNDING_80MHZ,NB_SOUNDING_160MHZ,NB_SOUNDING_320MHZ,TGD_SU_BEAMFORMING_FEEDBACK,TGD_MU_BEAMFORMING_PARTIAL_BW,TGD_CQI_FEEDBACK,MUPPDU_4XEHT_LTF,MAX_NC,NTGD_CQI_FEEDBACK,RX_1024_4096_QAM_242TONE_RU,COMMON_NOMINAL_PACKET_PADDING,MAX_SUPPORTED_EHT_LTFS,NON_OFDMA_ULMIMO_80MHZ,NON_OFDMA_ULMIMO_160MHZ,NON_OFDMA_ULMIMO_320MHZ,MU_BEAMFORMER_80MHZ,MU_BEAMFORMER_160MHZ,MU_BEAMFORMER_320MHZ,20MHZ_ONLY_LIMITED" (re)

  $ wifi_dm_radio_band 6 "CurrentEhtOperatingIE?"
  Device.WiFi.Radio.\d+.CurrentEhtOperatingIE="agFEREREAycv" (re)

  $ get_eht_ops 6
  BasicEHT-MCSAndNssSet=1145324612
  CCFS0=39
  CCFS1=47
  ControlChannelWidth=3
  DisabledSubchannelBitmapPresent=0
  EHTDefaultPEDuration=0
  EHTOperationInformationPresent=1
  GroupAddressedBUIndicationExponent=0
  GroupAddressedBUIndicationLimit=0

Disable channels 49,53:

  $ R logger -t cram "Disable channels 49,53"

  $ wifi_dm_radio_band 6 "StaticPuncturing.DisabledSubChannels=\"49,53\""
  Device.WiFi.Radio.\d+.StaticPuncturing.DisabledSubChannels="49,53" (re)

  $ sleep 5

  $ get_eht_ops 6
  BasicEHT-MCSAndNssSet=1145324612
  CCFS0=39
  CCFS1=47
  ControlChannelWidth=3
  DisabledSubchannelBitmap=48
  DisabledSubchannelBitmapPresent=1
  EHTDefaultPEDuration=0
  EHTOperationInformationPresent=1
  GroupAddressedBUIndicationExponent=0
  GroupAddressedBUIndicationLimit=0

Expecting the EHT Operations IE:

  $ wifi_dm_radio_band 6 "CurrentEhtOperatingIE?"
  Device.WiFi.Radio.\d+.CurrentEhtOperatingIE="agNEREREAycvMAA=" (re)

Downgrade to AX operating mode:

  $ wifi_dm_radio_band 6 "OperatingStandards=\"ax\""
  Device.WiFi.Radio.\d+.OperatingStandards="ax" (re)

  $ sleep 5

  $ R logger -t cram "Checks after downgrade to AX"

  $ wifi_dm_radio_band 6 "EhtPhyCapabilities?"
  Device.WiFi.Radio.\d+.EhtPhyCapabilities="4v/b4Bh1AH4E" (re)

  $ wifi_dm_radio_band 6 "EhtPhyCapabilitiesStr?"
  Device.WiFi.Radio.\d+.EhtPhyCapabilitiesStr="320MHZ,SU_BEAMFORMER,SU_BEAMFORMEE,BEAMFORMEE_SS_80MHZ,BEAMFORMEE_SS_160MHZ,BEAMFORMEE_SS_320MHZ,NB_SOUNDING_80MHZ,NB_SOUNDING_160MHZ,NB_SOUNDING_320MHZ,TGD_SU_BEAMFORMING_FEEDBACK,TGD_MU_BEAMFORMING_PARTIAL_BW,TGD_CQI_FEEDBACK,MUPPDU_4XEHT_LTF,MAX_NC,NTGD_CQI_FEEDBACK,RX_1024_4096_QAM_242TONE_RU,COMMON_NOMINAL_PACKET_PADDING,MAX_SUPPORTED_EHT_LTFS,NON_OFDMA_ULMIMO_80MHZ,NON_OFDMA_ULMIMO_160MHZ,NON_OFDMA_ULMIMO_320MHZ,MU_BEAMFORMER_80MHZ,MU_BEAMFORMER_160MHZ,MU_BEAMFORMER_320MHZ,20MHZ_ONLY_LIMITED" (re)

  $ wifi_dm_radio_band 6 "CurrentEhtOperatingIE?"
  Device.WiFi.Radio.\d+.CurrentEhtOperatingIE="" (re)

Check that get_eht_ops output is empty:

  $ get_eht_ops 6


Check channels 49,53 are still configured in Radio.StaticPuncturing

  $ wifi_dm_radio_band 6 "StaticPuncturing.DisabledSubChannels?"
  Device.WiFi.Radio.\d+.StaticPuncturing.DisabledSubChannels="49,53" (re)

Check that all radios and private vaps are still up:

  $ sleep 5

  $ wifi_dm_radio_band 2 "Status?"
  Device.WiFi.Radio.\d+.Status="Up" (re)

  $ wifi_dm_radio_band 5 "Status?"
  Device.WiFi.Radio.\d+.Status="Up" (re)

  $ wifi_dm_radio_band 6 "Status?"
  Device.WiFi.Radio.\d+.Status="Up" (re)

  $ wifi_dm "AccessPoint.1.Status?0"
  Device.WiFi.AccessPoint.1.Status="Enabled"

  $ wifi_dm "AccessPoint.3.Status?0"
  Device.WiFi.AccessPoint.3.Status="Enabled"

  $ wifi_dm "AccessPoint.5.Status?0"
  Device.WiFi.AccessPoint.5.Status="Enabled"

#########################################
#    Restore defaults                   #
#########################################

  $ R logger -t cram "Finishing EHT operation test"

Restore defaults:

  $ wifi_dm "Radio.*.OperatingStandardsFormat=\"Standard\"" "WiFi." "ba-cli"
  WiFi.Radio.1.OperatingStandardsFormat="Standard"
  WiFi.Radio.2.OperatingStandardsFormat="Standard"
  WiFi.Radio.3.OperatingStandardsFormat="Standard"

  $ wifi_dm "Radio.*.StaticPuncturing.DisabledSubChannels=\"\"" "WiFi." "ba-cli"
  WiFi.Radio.1.StaticPuncturing.DisabledSubChannels=""
  WiFi.Radio.2.StaticPuncturing.DisabledSubChannels=""
  WiFi.Radio.3.StaticPuncturing.DisabledSubChannels=""

  $ wifi_dm_radio_band 2 "OperatingStandards=\"b,g,n,ax,be\"" "WiFi." "ba-cli"
  WiFi.Radio.\d+.OperatingStandards="b,g,n,ax,be" (re)

  $ wifi_dm_radio_band 5 "OperatingStandards=\"a,n,ac,ax,be\"" "WiFi." "ba-cli"
  WiFi.Radio.\d+.OperatingStandards="a,n,ac,ax,be" (re)

  $ wifi_dm_radio_band 6 "OperatingStandards=\"ax,be\"" "WiFi." "ba-cli"
  WiFi.Radio.\d+.OperatingStandards="ax,be" (re)

Disable vaps:

  $ wifi_dm "AccessPoint.1.Enable=0"
  Device.WiFi.AccessPoint.1.Enable=0

  $ wifi_dm "AccessPoint.3.Enable=0"
  Device.WiFi.AccessPoint.3.Enable=0

  $ wifi_dm "AccessPoint.5.Enable=0"
  Device.WiFi.AccessPoint.5.Enable=0

  $ sleep 10

  $ wifi_dm "AccessPoint.1.Status?0"
  Device.WiFi.AccessPoint.1.Status="Disabled"

  $ wifi_dm "AccessPoint.3.Status?0"
  Device.WiFi.AccessPoint.3.Status="Disabled"

  $ wifi_dm "AccessPoint.5.Status?0"
  Device.WiFi.AccessPoint.5.Status="Disabled"

  $ R logger -t cram "Restart prplmesh"

  $ R "ba-cli X_PRPLWARE-COM_ProcessManager.PrplMesh.ManagementMode=Multi-AP-Controller-and-Agent"  > /dev/null
  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=1" | tr -d '\n'
  1 (no-eol)

  $ R logger -t cram "Test finished!"
