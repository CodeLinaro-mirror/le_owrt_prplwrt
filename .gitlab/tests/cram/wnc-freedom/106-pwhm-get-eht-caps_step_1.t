Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R "logger -t cram 'Starting EHT Operations test (step 1) ...'"

Stop prplMesh:

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=0" | tr -d '\n'
  0 (no-eol)

  $ sleep 2

Set AutoChannelEnable=0 on all WiFi.Radio. interfaces:

  $ wifi_dm "Radio.*.AutoChannelEnable=0"
  Device.WiFi.Radio.1.AutoChannelEnable=0
  Device.WiFi.Radio.2.AutoChannelEnable=0
  Device.WiFi.Radio.3.AutoChannelEnable=0

Configure radio:

  $ wifi_dm_radio_band 2 "OperatingChannelBandwidth=\"40MHz\""
  Device.WiFi.Radio.\d+.OperatingChannelBandwidth="40MHz" (re)

  $ wifi_dm_radio_band 5 "OperatingChannelBandwidth=\"80MHz\""
  Device.WiFi.Radio.\d+.OperatingChannelBandwidth="80MHz" (re)

  $ wifi_dm_radio_band 6 "OperatingChannelBandwidth=\"160MHz\""
  Device.WiFi.Radio.\d+.OperatingChannelBandwidth="160MHz" (re)

  $ wifi_dm_radio_band 2 "Channel=1"
  Device.WiFi.Radio.\d+.Channel=1 (re)

  $ wifi_dm_radio_band 5 "Channel=36"
  Device.WiFi.Radio.\d+.Channel=36 (re)

  $ wifi_dm_radio_band 6 "Channel=37"
  Device.WiFi.Radio.\d+.Channel=37 (re)

  $ wifi_dm "Radio.*.OperatingStandardsFormat=\"Legacy\"" "WiFi." "ba-cli"
  WiFi.Radio.1.OperatingStandardsFormat="Legacy"
  WiFi.Radio.2.OperatingStandardsFormat="Legacy"
  WiFi.Radio.3.OperatingStandardsFormat="Legacy"

  $ wifi_dm "Radio.*.OperatingStandards=\"be\"" "WiFi." "ba-cli"
  WiFi.Radio.1.OperatingStandards="be"
  WiFi.Radio.2.OperatingStandards="be"
  WiFi.Radio.3.OperatingStandards="be"

Enable private vaps radios:

  $ wifi_dm "AccessPoint.1.Enable=1"
  Device.WiFi.AccessPoint.1.Enable=1

  $ wifi_dm "AccessPoint.3.Enable=1"
  Device.WiFi.AccessPoint.3.Enable=1

  $ wifi_dm "AccessPoint.5.Enable=1"
  Device.WiFi.AccessPoint.5.Enable=1

  $ sleep 10

  $ wifi_dm "AccessPoint.1.Status?0"
  Device.WiFi.AccessPoint.1.Status="Enabled"

  $ wifi_dm "AccessPoint.3.Status?0"
  Device.WiFi.AccessPoint.3.Status="Enabled"

  $ wifi_dm "AccessPoint.5.Status?0"
  Device.WiFi.AccessPoint.5.Status="Enabled"

#########################################
#    test 2.4GHz getEHTOperations       #
#########################################

  $ R logger -t cram "Test getEHTOperations on 2.4GHz"

Check ChannelsInUse:

  $ wifi_dm_radio_band 2 "ChannelsInUse?"
  Device.WiFi.Radio.\d+.ChannelsInUse="1,2,3,4,5" (re)

Check EhtPhyCapabilities, EhtPhyCapabilitiesStr, CurrentEhtOperatingIE and getEHTOperations():

  $ R logger -t cram "Check EHT Capabilities"

  $ wifi_dm_radio_band 2 "EhtPhyCapabilities?"
  Device.WiFi.Radio.\d+.EhtPhyCapabilities="4AED4Bh1AB4E" (re)

  $ wifi_dm_radio_band 2 "EhtPhyCapabilitiesStr?"
  Device.WiFi.Radio.1.EhtPhyCapabilitiesStr="SU_BEAMFORMER,SU_BEAMFORMEE,BEAMFORMEE_SS_80MHZ,NB_SOUNDING_80MHZ,TGD_SU_BEAMFORMING_FEEDBACK,TGD_MU_BEAMFORMING_PARTIAL_BW,TGD_CQI_FEEDBACK,MUPPDU_4XEHT_LTF,MAX_NC,NTGD_CQI_FEEDBACK,RX_1024_4096_QAM_242TONE_RU,COMMON_NOMINAL_PACKET_PADDING,MAX_SUPPORTED_EHT_LTFS,NON_OFDMA_ULMIMO_80MHZ,NON_OFDMA_ULMIMO_160MHZ,NON_OFDMA_ULMIMO_320MHZ,MU_BEAMFORMER_80MHZ,20MHZ_ONLY_LIMITED"

  $ wifi_dm_radio_band 2 "CurrentEhtOperatingIE?"
  Device.WiFi.Radio.\d+.CurrentEhtOperatingIE="agFEREREAQMA" (re)

  $ get_eht_ops 2.4
  BasicEHT-MCSAndNssSet=1145324612
  CCFS0=3
  CCFS1=0
  ControlChannelWidth=1
  DisabledSubchannelBitmapPresent=0
  EHTDefaultPEDuration=0
  EHTOperationInformationPresent=1
  GroupAddressedBUIndicationExponent=0
  GroupAddressedBUIndicationLimit=0

Downgrade to AX operating mode:

  $ wifi_dm_radio_band 2 "OperatingStandards=\"ax\""
  Device.WiFi.Radio.\d+.OperatingStandards="ax" (re)

  $ sleep 5

  $ R logger -t cram "Checks after downgrade to AX"

  $ wifi_dm_radio_band 2 "EhtPhyCapabilities?"
  Device.WiFi.Radio.\d+.EhtPhyCapabilities="4AED4Bh1AB4E" (re)

  $ wifi_dm_radio_band 2 "EhtPhyCapabilitiesStr?"
  Device.WiFi.Radio.\d+.EhtPhyCapabilitiesStr="SU_BEAMFORMER,SU_BEAMFORMEE,BEAMFORMEE_SS_80MHZ,NB_SOUNDING_80MHZ,TGD_SU_BEAMFORMING_FEEDBACK,TGD_MU_BEAMFORMING_PARTIAL_BW,TGD_CQI_FEEDBACK,MUPPDU_4XEHT_LTF,MAX_NC,NTGD_CQI_FEEDBACK,RX_1024_4096_QAM_242TONE_RU,COMMON_NOMINAL_PACKET_PADDING,MAX_SUPPORTED_EHT_LTFS,NON_OFDMA_ULMIMO_80MHZ,NON_OFDMA_ULMIMO_160MHZ,NON_OFDMA_ULMIMO_320MHZ,MU_BEAMFORMER_80MHZ,20MHZ_ONLY_LIMITED" (re)

  $ wifi_dm_radio_band 2 "CurrentEhtOperatingIE?"
  Device.WiFi.Radio.\d+.CurrentEhtOperatingIE="" (re)

Check that get_eht_ops output is empty:

  $ get_eht_ops 2.4

#########################################
#    test 5GHz getEHTOperations         #
#########################################

  $ R logger -t cram "Test getEHTOperations on 5GHz"

Check ChannelsInUse:

  $ wifi_dm_radio_band 5 "ChannelsInUse?"
  Device.WiFi.Radio.\d+.ChannelsInUse="36,40,44,48" (re)

Check EhtPhyCapabilities, EhtPhyCapabilitiesStr, CurrentEhtOperatingIE and getEHTOperations():

  $ R logger -t cram "Check EHT Capabilities"

  $ wifi_dm_radio_band 5 "EhtPhyCapabilities?"
  Device.WiFi.Radio.\d+.EhtPhyCapabilities="4v/b4Bh1AH4E" (re)

  $ wifi_dm_radio_band 5 "EhtPhyCapabilitiesStr?"
  Device.WiFi.Radio.\d+.EhtPhyCapabilitiesStr="320MHZ,SU_BEAMFORMER,SU_BEAMFORMEE,BEAMFORMEE_SS_80MHZ,BEAMFORMEE_SS_160MHZ,BEAMFORMEE_SS_320MHZ,NB_SOUNDING_80MHZ,NB_SOUNDING_160MHZ,NB_SOUNDING_320MHZ,TGD_SU_BEAMFORMING_FEEDBACK,TGD_MU_BEAMFORMING_PARTIAL_BW,TGD_CQI_FEEDBACK,MUPPDU_4XEHT_LTF,MAX_NC,NTGD_CQI_FEEDBACK,RX_1024_4096_QAM_242TONE_RU,COMMON_NOMINAL_PACKET_PADDING,MAX_SUPPORTED_EHT_LTFS,NON_OFDMA_ULMIMO_80MHZ,NON_OFDMA_ULMIMO_160MHZ,NON_OFDMA_ULMIMO_320MHZ,MU_BEAMFORMER_80MHZ,MU_BEAMFORMER_160MHZ,MU_BEAMFORMER_320MHZ,20MHZ_ONLY_LIMITED" (re)

  $ wifi_dm_radio_band 5 "CurrentEhtOperatingIE?"
  Device.WiFi.Radio.\d+.CurrentEhtOperatingIE="agFEREREAioA" (re)

  $ get_eht_ops 5
  BasicEHT-MCSAndNssSet=1145324612
  CCFS0=42
  CCFS1=0
  ControlChannelWidth=2
  DisabledSubchannelBitmapPresent=0
  EHTDefaultPEDuration=0
  EHTOperationInformationPresent=1
  GroupAddressedBUIndicationExponent=0
  GroupAddressedBUIndicationLimit=0

Disable channels 40:

  $ R logger -t cram "Disable channels 40"

  $ wifi_dm_radio_band 5 "StaticPuncturing.DisabledSubChannels=\"40\"" "WiFi." "ba-cli"
  WiFi.Radio.\d+.StaticPuncturing.DisabledSubChannels="40" (re)

  $ sleep 5

  $ get_eht_ops 5
  BasicEHT-MCSAndNssSet=1145324612
  CCFS0=42
  CCFS1=0
  ControlChannelWidth=2
  DisabledSubchannelBitmap=2
  DisabledSubchannelBitmapPresent=1
  EHTDefaultPEDuration=0
  EHTOperationInformationPresent=1
  GroupAddressedBUIndicationExponent=0
  GroupAddressedBUIndicationLimit=0

Expecting the EHT Operations IE puncturing bitmap to be updated:

  $ wifi_dm_radio_band 5 "CurrentEhtOperatingIE?"
  Device.WiFi.Radio.\d+.CurrentEhtOperatingIE="agNEREREAioAAgA=" (re)

Downgrade to AX operating mode:

  $ wifi_dm_radio_band 5 "OperatingStandards=\"ax\""
  Device.WiFi.Radio.\d+.OperatingStandards="ax" (re)

  $ sleep 5

  $ R logger -t cram "Checks after downgrade to AX"

  $ wifi_dm_radio_band 5 "EhtPhyCapabilities?"
  Device.WiFi.Radio.\d+.EhtPhyCapabilities="4v/b4Bh1AH4E" (re)

  $ wifi_dm_radio_band 5 "EhtPhyCapabilitiesStr?"
  Device.WiFi.Radio.\d+.EhtPhyCapabilitiesStr="320MHZ,SU_BEAMFORMER,SU_BEAMFORMEE,BEAMFORMEE_SS_80MHZ,BEAMFORMEE_SS_160MHZ,BEAMFORMEE_SS_320MHZ,NB_SOUNDING_80MHZ,NB_SOUNDING_160MHZ,NB_SOUNDING_320MHZ,TGD_SU_BEAMFORMING_FEEDBACK,TGD_MU_BEAMFORMING_PARTIAL_BW,TGD_CQI_FEEDBACK,MUPPDU_4XEHT_LTF,MAX_NC,NTGD_CQI_FEEDBACK,RX_1024_4096_QAM_242TONE_RU,COMMON_NOMINAL_PACKET_PADDING,MAX_SUPPORTED_EHT_LTFS,NON_OFDMA_ULMIMO_80MHZ,NON_OFDMA_ULMIMO_160MHZ,NON_OFDMA_ULMIMO_320MHZ,MU_BEAMFORMER_80MHZ,MU_BEAMFORMER_160MHZ,MU_BEAMFORMER_320MHZ,20MHZ_ONLY_LIMITED" (re)

  $ wifi_dm_radio_band 5 "CurrentEhtOperatingIE?"
  Device.WiFi.Radio.\d+.CurrentEhtOperatingIE="" (re)

Check that get_eht_ops output is empty:

  $ get_eht_ops 5


Check if channels 40 is still configured in Radio.StaticPuncturing

  $ wifi_dm_radio_band 5 "StaticPuncturing.DisabledSubChannels?" "WiFi." "ba-cli"
  WiFi.Radio.\d+.StaticPuncturing.DisabledSubChannels="40" (re)

#########################################
#    test 6GHz getEHTOperations         #
#########################################

  $ R logger -t cram "Test getEHTOperations on 6GHz"

Check ChannelsInUse:

  $ wifi_dm_radio_band 6 "ChannelsInUse?"
  Device.WiFi.Radio.\d+.ChannelsInUse="33,37,41,45,49,53,57,61" (re)
