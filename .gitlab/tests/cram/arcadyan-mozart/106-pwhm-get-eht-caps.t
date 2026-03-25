Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R logger -t cram "Starting EHT Operations test ..."

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

  $ wifi_dm "Radio.*.OperatingStandardsFormat=\"Legacy\""
  Device.WiFi.Radio.1.OperatingStandardsFormat="Legacy"
  Device.WiFi.Radio.2.OperatingStandardsFormat="Legacy"
  Device.WiFi.Radio.3.OperatingStandardsFormat="Legacy"

  $ wifi_dm "Radio.*.OperatingStandards=\"be\""
  Device.WiFi.Radio.1.OperatingStandards="be"
  Device.WiFi.Radio.2.OperatingStandards="be"
  Device.WiFi.Radio.3.OperatingStandards="be"

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
  Device.WiFi.Radio.1.EhtPhyCapabilities="6AEDfihgCBIA"

  $ wifi_dm_radio_band 2 "EhtPhyCapabilitiesStr?"
  Device.WiFi.Radio.1.EhtPhyCapabilitiesStr="NDP_4XEHT_LTF,SU_BEAMFORMER,SU_BEAMFORMEE,BEAMFORMEE_SS_80MHZ,NB_SOUNDING_80MHZ,NG16_SU_FEEDBACK,NG16_MU_FEEDBACK,CBK_SU_FEEDBACK,CBK_MU_FEEDBACK,TGD_SU_BEAMFORMING_FEEDBACK,TGD_MU_BEAMFORMING_PARTIAL_BW,MUPPDU_4XEHT_LTF,MAX_NC,COMMON_NOMINAL_PACKET_PADDING,MAX_SUPPORTED_EHT_LTFS,EHT_MCS15_MRU,NON_OFDMA_ULMIMO_80MHZ,MU_BEAMFORMER_80MHZ"

  $ wifi_dm_radio_band 2 "CurrentEhtOperatingIE?"
  Device.WiFi.Radio.\d+.CurrentEhtOperatingIE="AAFEREREAQMAAAA=" (re)

  $ get_eht_ops 2.4
  BasicEHT-MCSAndNssSet=1145324612
  CCFS0=3
  CCFS1=0
  ControlChannelWidth=1
  DisabledSubchannelBitmap=0
  DisabledSubchannelBitmapPresent=0
  EHTOperationInformationPresent=1

Downgrade to AX operating mode:

  $ wifi_dm_radio_band 2 "OperatingStandards=\"ax\""
  Device.WiFi.Radio.\d+.OperatingStandards="ax" (re)

  $ sleep 5

  $ R logger -t cram "Checks after downgrade to AX"

  $ wifi_dm_radio_band 2 "EhtPhyCapabilities?"
  Device.WiFi.Radio.1.EhtPhyCapabilities="6AEDfihgCBIA"

  $ wifi_dm_radio_band 2 "EhtPhyCapabilitiesStr?"
  Device.WiFi.Radio.1.EhtPhyCapabilitiesStr="NDP_4XEHT_LTF,SU_BEAMFORMER,SU_BEAMFORMEE,BEAMFORMEE_SS_80MHZ,NB_SOUNDING_80MHZ,NG16_SU_FEEDBACK,NG16_MU_FEEDBACK,CBK_SU_FEEDBACK,CBK_MU_FEEDBACK,TGD_SU_BEAMFORMING_FEEDBACK,TGD_MU_BEAMFORMING_PARTIAL_BW,MUPPDU_4XEHT_LTF,MAX_NC,COMMON_NOMINAL_PACKET_PADDING,MAX_SUPPORTED_EHT_LTFS,EHT_MCS15_MRU,NON_OFDMA_ULMIMO_80MHZ,MU_BEAMFORMER_80MHZ"

  $ wifi_dm_radio_band 2 "CurrentEhtOperatingIE?"
  Device.WiFi.Radio.\d+.CurrentEhtOperatingIE="AAAAAAAAAAAAAAA=" (re)

  $ get_eht_ops 2.4
  BasicEHT-MCSAndNssSet=0
  CCFS0=0
  CCFS1=0
  ControlChannelWidth=0
  DisabledSubchannelBitmap=0
  DisabledSubchannelBitmapPresent=0
  EHTOperationInformationPresent=0

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
  Device.WiFi.Radio.2.EhtPhyCapabilities="6A0bfihgCDYA"

  $ wifi_dm_radio_band 5 "EhtPhyCapabilitiesStr?"
  Device.WiFi.Radio.2.EhtPhyCapabilitiesStr="NDP_4XEHT_LTF,SU_BEAMFORMER,SU_BEAMFORMEE,BEAMFORMEE_SS_80MHZ,BEAMFORMEE_SS_160MHZ,NB_SOUNDING_80MHZ,NB_SOUNDING_160MHZ,NG16_SU_FEEDBACK,NG16_MU_FEEDBACK,CBK_SU_FEEDBACK,CBK_MU_FEEDBACK,TGD_SU_BEAMFORMING_FEEDBACK,TGD_MU_BEAMFORMING_PARTIAL_BW,MUPPDU_4XEHT_LTF,MAX_NC,COMMON_NOMINAL_PACKET_PADDING,MAX_SUPPORTED_EHT_LTFS,EHT_MCS15_MRU,NON_OFDMA_ULMIMO_80MHZ,NON_OFDMA_ULMIMO_160MHZ,MU_BEAMFORMER_80MHZ,MU_BEAMFORMER_160MHZ"

  $ wifi_dm_radio_band 5 "CurrentEhtOperatingIE?"
  Device.WiFi.Radio.\d+.CurrentEhtOperatingIE="AAFEREREAioAAAA=" (re)

  $ get_eht_ops 5
  BasicEHT-MCSAndNssSet=1145324612
  CCFS0=42
  CCFS1=0
  ControlChannelWidth=2
  DisabledSubchannelBitmap=0
  DisabledSubchannelBitmapPresent=0
  EHTOperationInformationPresent=1

Disable channels 40,48:

  $ R logger -t cram "Disable channels 40,48"

  $ wifi_dm_radio_band 5 "StaticPuncturing.DisabledSubChannels=\"40,48\""
  Device.WiFi.Radio.\d+.StaticPuncturing.DisabledSubChannels="40,48" (re)

  $ sleep 5

  $ get_eht_ops 5
  BasicEHT-MCSAndNssSet=1145324612
  CCFS0=42
  CCFS1=0
  ControlChannelWidth=2
  DisabledSubchannelBitmap=10
  DisabledSubchannelBitmapPresent=1
  EHTOperationInformationPresent=1

Disable channels 40,44,48:

  $ R logger -t cram "Disable channels 40,44,48"

  $ wifi_dm_radio_band 5 "StaticPuncturing.DisabledSubChannels=\"40,44,48\""
  Device.WiFi.Radio.\d+.StaticPuncturing.DisabledSubChannels="40,44,48" (re)

  $ sleep 5

  $ get_eht_ops 5
  BasicEHT-MCSAndNssSet=1145324612
  CCFS0=42
  CCFS1=0
  ControlChannelWidth=2
  DisabledSubchannelBitmap=14
  DisabledSubchannelBitmapPresent=1
  EHTOperationInformationPresent=1

Expecting the EHT Operations IE puncturing bitmap to be updated:

  $ wifi_dm_radio_band 5 "CurrentEhtOperatingIE?"
  Device.WiFi.Radio.\d+.CurrentEhtOperatingIE="AANEREREAioADgA=" (re)

Downgrade to AX operating mode:

  $ wifi_dm_radio_band 5 "OperatingStandards=\"ax\""
  Device.WiFi.Radio.\d+.OperatingStandards="ax" (re)

  $ sleep 5

  $ R logger -t cram "Checks after downgrade to AX"

  $ wifi_dm_radio_band 5 "EhtPhyCapabilities?"
  Device.WiFi.Radio.2.EhtPhyCapabilities="6A0bfihgCDYA"

  $ wifi_dm_radio_band 5 "EhtPhyCapabilitiesStr?"
  Device.WiFi.Radio.2.EhtPhyCapabilitiesStr="NDP_4XEHT_LTF,SU_BEAMFORMER,SU_BEAMFORMEE,BEAMFORMEE_SS_80MHZ,BEAMFORMEE_SS_160MHZ,NB_SOUNDING_80MHZ,NB_SOUNDING_160MHZ,NG16_SU_FEEDBACK,NG16_MU_FEEDBACK,CBK_SU_FEEDBACK,CBK_MU_FEEDBACK,TGD_SU_BEAMFORMING_FEEDBACK,TGD_MU_BEAMFORMING_PARTIAL_BW,MUPPDU_4XEHT_LTF,MAX_NC,COMMON_NOMINAL_PACKET_PADDING,MAX_SUPPORTED_EHT_LTFS,EHT_MCS15_MRU,NON_OFDMA_ULMIMO_80MHZ,NON_OFDMA_ULMIMO_160MHZ,MU_BEAMFORMER_80MHZ,MU_BEAMFORMER_160MHZ"

  $ wifi_dm_radio_band 5 "CurrentEhtOperatingIE?"
  Device.WiFi.Radio.\d+.CurrentEhtOperatingIE="AAAAAAAAAAAAAAA=" (re)

  $ get_eht_ops 5
  BasicEHT-MCSAndNssSet=0
  CCFS0=0
  CCFS1=0
  ControlChannelWidth=0
  DisabledSubchannelBitmap=0
  DisabledSubchannelBitmapPresent=0
  EHTOperationInformationPresent=0

Check channels 40,44,48 are still configured in Radio.StaticPuncturing

  $ wifi_dm_radio_band 5 "StaticPuncturing.DisabledSubChannels?"
  Device.WiFi.Radio.\d+.StaticPuncturing.DisabledSubChannels="40,44,48" (re)

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
  Device.WiFi.Radio.3.EhtPhyCapabilities="6m3bfihgCH4A"

  $ wifi_dm_radio_band 6 "EhtPhyCapabilitiesStr?"
  Device.WiFi.Radio.3.EhtPhyCapabilitiesStr="320MHZ,NDP_4XEHT_LTF,SU_BEAMFORMER,SU_BEAMFORMEE,BEAMFORMEE_SS_80MHZ,BEAMFORMEE_SS_160MHZ,BEAMFORMEE_SS_320MHZ,NB_SOUNDING_80MHZ,NB_SOUNDING_160MHZ,NB_SOUNDING_320MHZ,NG16_SU_FEEDBACK,NG16_MU_FEEDBACK,CBK_SU_FEEDBACK,CBK_MU_FEEDBACK,TGD_SU_BEAMFORMING_FEEDBACK,TGD_MU_BEAMFORMING_PARTIAL_BW,MUPPDU_4XEHT_LTF,MAX_NC,COMMON_NOMINAL_PACKET_PADDING,MAX_SUPPORTED_EHT_LTFS,EHT_MCS15_MRU,NON_OFDMA_ULMIMO_80MHZ,NON_OFDMA_ULMIMO_160MHZ,NON_OFDMA_ULMIMO_320MHZ,MU_BEAMFORMER_80MHZ,MU_BEAMFORMER_160MHZ,MU_BEAMFORMER_320MHZ"

  $ wifi_dm_radio_band 6 "CurrentEhtOperatingIE?"
  Device.WiFi.Radio.\d+.CurrentEhtOperatingIE="AAFEREREAycvAAA=" (re)

  $ get_eht_ops 6
  BasicEHT-MCSAndNssSet=1145324612
  CCFS0=39
  CCFS1=47
  ControlChannelWidth=3
  DisabledSubchannelBitmap=0
  DisabledSubchannelBitmapPresent=0
  EHTOperationInformationPresent=1

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
  EHTOperationInformationPresent=1

Disable channels 53,57,61:

  $ R logger -t cram "Disable channels 53,57,61"

  $ wifi_dm_radio_band 6 "StaticPuncturing.DisabledSubChannels=\"53,57,61\""
  Device.WiFi.Radio.\d+.StaticPuncturing.DisabledSubChannels="53,57,61" (re)

  $ sleep 5

  $ get_eht_ops 6
  BasicEHT-MCSAndNssSet=1145324612
  CCFS0=39
  CCFS1=47
  ControlChannelWidth=3
  DisabledSubchannelBitmap=224
  DisabledSubchannelBitmapPresent=1
  EHTOperationInformationPresent=1

Expecting the EHT Operations IE:

  $  wifi_dm_radio_band 6 "CurrentEhtOperatingIE?"
  Device.WiFi.Radio.\d+.CurrentEhtOperatingIE="AANEREREAycv4AA=" (re)

Downgrade to AX operating mode:

  $ wifi_dm_radio_band 6 "OperatingStandards=\"ax\""
  Device.WiFi.Radio.\d+.OperatingStandards="ax" (re)

  $ sleep 5

  $ R logger -t cram "Checks after downgrade to AX"

  $ wifi_dm_radio_band 6 "EhtPhyCapabilities?"
  Device.WiFi.Radio.3.EhtPhyCapabilities="6m3bfihgCH4A"

  $ wifi_dm_radio_band 6 "EhtPhyCapabilitiesStr?"
  Device.WiFi.Radio.3.EhtPhyCapabilitiesStr="320MHZ,NDP_4XEHT_LTF,SU_BEAMFORMER,SU_BEAMFORMEE,BEAMFORMEE_SS_80MHZ,BEAMFORMEE_SS_160MHZ,BEAMFORMEE_SS_320MHZ,NB_SOUNDING_80MHZ,NB_SOUNDING_160MHZ,NB_SOUNDING_320MHZ,NG16_SU_FEEDBACK,NG16_MU_FEEDBACK,CBK_SU_FEEDBACK,CBK_MU_FEEDBACK,TGD_SU_BEAMFORMING_FEEDBACK,TGD_MU_BEAMFORMING_PARTIAL_BW,MUPPDU_4XEHT_LTF,MAX_NC,COMMON_NOMINAL_PACKET_PADDING,MAX_SUPPORTED_EHT_LTFS,EHT_MCS15_MRU,NON_OFDMA_ULMIMO_80MHZ,NON_OFDMA_ULMIMO_160MHZ,NON_OFDMA_ULMIMO_320MHZ,MU_BEAMFORMER_80MHZ,MU_BEAMFORMER_160MHZ,MU_BEAMFORMER_320MHZ"

  $ wifi_dm_radio_band 6 "CurrentEhtOperatingIE?"
  Device.WiFi.Radio.\d+.CurrentEhtOperatingIE="AAAAAAAAAAAAAAA=" (re)

  $ get_eht_ops 6
  BasicEHT-MCSAndNssSet=0
  CCFS0=0
  CCFS1=0
  ControlChannelWidth=0
  DisabledSubchannelBitmap=0
  DisabledSubchannelBitmapPresent=0
  EHTOperationInformationPresent=0

Check channels 40,44,48 are still configured in Radio.StaticPuncturing

  $  wifi_dm_radio_band 6 "StaticPuncturing.DisabledSubChannels?"
  Device.WiFi.Radio.\d+.StaticPuncturing.DisabledSubChannels="53,57,61" (re)

#########################################
#    Restore defaults                   #
#########################################

  $ R logger -t cram "Finishing EHT operation test"

Restore defaults:

  $ wifi_dm "Radio.*.OperatingStandardsFormat=\"Standard\""
  Device.WiFi.Radio.1.OperatingStandardsFormat="Standard"
  Device.WiFi.Radio.2.OperatingStandardsFormat="Standard"
  Device.WiFi.Radio.3.OperatingStandardsFormat="Standard"

  $ wifi_dm "Radio.*.StaticPuncturing.DisabledSubChannels=\"\""
  Device.WiFi.Radio.1.StaticPuncturing.DisabledSubChannels=""
  Device.WiFi.Radio.2.StaticPuncturing.DisabledSubChannels=""
  Device.WiFi.Radio.3.StaticPuncturing.DisabledSubChannels=""

  $ wifi_dm_radio_band 2 "OperatingStandards=\"b,g,n,ax,be\""
  Device.WiFi.Radio.\d+.OperatingStandards="b,g,n,ax,be" (re)

  $ wifi_dm_radio_band 5 "OperatingStandards=\"a,n,ac,ax,be\""
  Device.WiFi.Radio.\d+.OperatingStandards="a,n,ac,ax,be" (re)

  $ wifi_dm_radio_band 6 "OperatingStandards=\"ax,be\""
  Device.WiFi.Radio.\d+.OperatingStandards="ax,be" (re)

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
