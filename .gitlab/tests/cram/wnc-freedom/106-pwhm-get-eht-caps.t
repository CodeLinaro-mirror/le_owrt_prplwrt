Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R logger -t cram "Starting EHT Operations test ..."

Stop prplMesh:

  $ R "/etc/init.d/prplmesh stop > /dev/null 2>&1"

Set AutoChannelEnable=0 on all WiFi.Radio. interfaces:

  $ wifi_dm "Radio.*.AutoChannelEnable=0"
  WiFi.Radio.1.AutoChannelEnable=0
  WiFi.Radio.2.AutoChannelEnable=0
  WiFi.Radio.3.AutoChannelEnable=0

Configure radio:

  $ wifi_dm_radio_band 2 "OperatingChannelBandwidth=\"40MHz\""
  WiFi.Radio.\d+.OperatingChannelBandwidth="40MHz" (re)

  $ wifi_dm_radio_band 5 "OperatingChannelBandwidth=\"80MHz\""
  WiFi.Radio.\d+.OperatingChannelBandwidth="80MHz" (re)

  $ wifi_dm_radio_band 6 "OperatingChannelBandwidth=\"160MHz\""
  WiFi.Radio.\d+.OperatingChannelBandwidth="160MHz" (re)

  $ wifi_dm_radio_band 2 "Channel=1"
  WiFi.Radio.\d+.Channel=1 (re)

  $ wifi_dm_radio_band 5 "Channel=36"
  WiFi.Radio.\d+.Channel=36 (re)

  $ wifi_dm_radio_band 6 "Channel=37"
  WiFi.Radio.\d+.Channel=37 (re)

  $ wifi_dm "Radio.*.OperatingStandardsFormat=\"Legacy\""
  WiFi.Radio.1.OperatingStandardsFormat="Legacy"
  WiFi.Radio.2.OperatingStandardsFormat="Legacy"
  WiFi.Radio.3.OperatingStandardsFormat="Legacy"

  $ wifi_dm "Radio.*.OperatingStandards=\"be\""
  WiFi.Radio.1.OperatingStandards="be"
  WiFi.Radio.2.OperatingStandards="be"
  WiFi.Radio.3.OperatingStandards="be"

Enable private vaps radios:

  $ wifi_dm "AccessPoint.1.Enable=1"
  WiFi.AccessPoint.1.Enable=1

  $ wifi_dm "AccessPoint.3.Enable=1"
  WiFi.AccessPoint.3.Enable=1

  $ wifi_dm "AccessPoint.5.Enable=1"
  WiFi.AccessPoint.5.Enable=1

  $ sleep 10

  $ wifi_dm "AccessPoint.1.Status?0"
  WiFi.AccessPoint.1.Status="Enabled"

  $ wifi_dm "AccessPoint.3.Status?0"
  WiFi.AccessPoint.3.Status="Enabled"

  $ wifi_dm "AccessPoint.5.Status?0"
  WiFi.AccessPoint.5.Status="Enabled"

#########################################
#    test 2.4GHz getEHTOperations       #
#########################################

  $ R logger -t cram "Test getEHTOperations on 2.4GHz"

Check ChannelsInUse:

  $ wifi_dm_radio_band 2 "ChannelsInUse?"
  WiFi.Radio.\d+.ChannelsInUse="1,2,3,4,5" (re)

Check EhtPhyCapabilities, EhtPhyCapabilitiesStr, CurrentEhtOperatingIE and getEHTOperations():

  $ R logger -t cram "Check EHT Capabilities"

  $ wifi_dm_radio_band 2 "EhtPhyCapabilities?"
  WiFi.Radio.\d+.EhtPhyCapabilities="4AED4Bh1AB4A" (re)

  $ wifi_dm_radio_band 2 "EhtPhyCapabilitiesStr?"
  WiFi.Radio.\d+.EhtPhyCapabilitiesStr="SU_BEAMFORMER,SU_BEAMFORMEE,BEAMFORMEE_SS_80MHZ,NB_SOUNDING_80MHZ,TGD_SU_BEAMFORMING_FEEDBACK,TGD_MU_BEAMFORMING_PARTIAL_BW,TGD_CQI_FEEDBACK,MUPPDU_4XEHT_LTF,MAX_NC,NTGD_CQI_FEEDBACK,RX_1024_4096_QAM_242TONE_RU,COMMON_NOMINAL_PACKET_PADDING,MAX_SUPPORTED_EHT_LTFS,NON_OFDMA_ULMIMO_80MHZ,NON_OFDMA_ULMIMO_160MHZ,NON_OFDMA_ULMIMO_320MHZ,MU_BEAMFORMER_80MHZ" (re)

  $ wifi_dm_radio_band 2 "CurrentEhtOperatingIE?"
  WiFi.Radio.\d+.CurrentEhtOperatingIE="AAFEREREAQMAAAA=" (re)

  $ R "ba-cli -l \"WiFi.Radio.[OperatingFrequencyBand=='2.4GHz'].getEHTOperations()\"" | awk '/^\[/ {f=1; next} /^\]/ {f=0} f'  | tr -d ' {}[],'  | sed '/^$/d' | sort
  BasicEHT-MCSAndNssSet=1145324612
  CCFS0=3
  CCFS1=0
  ControlChannelWidth=1
  DisabledSubchannelBitmap=0
  DisabledSubchannelBitmapPresent=0
  EHTOperationInformationPresent=1

Downgrade to AX operating mode:

  $ wifi_dm_radio_band 2 "OperatingStandards=\"ax\""
  WiFi.Radio.\d+.OperatingStandards="ax" (re)

  $ sleep 5

  $ R logger -t cram "Checks after downgrade to AX"

  $ wifi_dm_radio_band 2 "EhtPhyCapabilities?"
  WiFi.Radio.\d+.EhtPhyCapabilities="4AED4Bh1AB4A" (re)

  $ wifi_dm_radio_band 2 "EhtPhyCapabilitiesStr?"
  WiFi.Radio.\d+.EhtPhyCapabilitiesStr="SU_BEAMFORMER,SU_BEAMFORMEE,BEAMFORMEE_SS_80MHZ,NB_SOUNDING_80MHZ,TGD_SU_BEAMFORMING_FEEDBACK,TGD_MU_BEAMFORMING_PARTIAL_BW,TGD_CQI_FEEDBACK,MUPPDU_4XEHT_LTF,MAX_NC,NTGD_CQI_FEEDBACK,RX_1024_4096_QAM_242TONE_RU,COMMON_NOMINAL_PACKET_PADDING,MAX_SUPPORTED_EHT_LTFS,NON_OFDMA_ULMIMO_80MHZ,NON_OFDMA_ULMIMO_160MHZ,NON_OFDMA_ULMIMO_320MHZ,MU_BEAMFORMER_80MHZ" (re)

  $ wifi_dm_radio_band 2 "CurrentEhtOperatingIE?"
  WiFi.Radio.\d+.CurrentEhtOperatingIE="AAAAAAAAAAAAAAA=" (re)

  $ R "ba-cli -l \"WiFi.Radio.[OperatingFrequencyBand=='2.4GHz'].getEHTOperations()\"" | awk '/^\[/ {f=1; next} /^\]/ {f=0} f'  | tr -d ' {}[],'  | sed '/^$/d' | sort
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
  WiFi.Radio.\d+.ChannelsInUse="36,40,44,48" (re)

Check EhtPhyCapabilities, EhtPhyCapabilitiesStr, CurrentEhtOperatingIE and getEHTOperations():

  $ R logger -t cram "Check EHT Capabilities"

  $ wifi_dm_radio_band 5 "EhtPhyCapabilities?"
  WiFi.Radio.\d+.EhtPhyCapabilities="4v/b4Bh1AH4A" (re)

  $ wifi_dm_radio_band 5 "EhtPhyCapabilitiesStr?"
  WiFi.Radio.\d+.EhtPhyCapabilitiesStr="320MHZ,SU_BEAMFORMER,SU_BEAMFORMEE,BEAMFORMEE_SS_80MHZ,BEAMFORMEE_SS_160MHZ,BEAMFORMEE_SS_320MHZ,NB_SOUNDING_80MHZ,NB_SOUNDING_160MHZ,NB_SOUNDING_320MHZ,TGD_SU_BEAMFORMING_FEEDBACK,TGD_MU_BEAMFORMING_PARTIAL_BW,TGD_CQI_FEEDBACK,MUPPDU_4XEHT_LTF,MAX_NC,NTGD_CQI_FEEDBACK,RX_1024_4096_QAM_242TONE_RU,COMMON_NOMINAL_PACKET_PADDING,MAX_SUPPORTED_EHT_LTFS,NON_OFDMA_ULMIMO_80MHZ,NON_OFDMA_ULMIMO_160MHZ,NON_OFDMA_ULMIMO_320MHZ,MU_BEAMFORMER_80MHZ,MU_BEAMFORMER_160MHZ,MU_BEAMFORMER_320MHZ" (re)

  $ wifi_dm_radio_band 5 "CurrentEhtOperatingIE?"
  WiFi.Radio.\d+.CurrentEhtOperatingIE="AAFEREREAioAAAA=" (re)

  $ R "ba-cli -l \"WiFi.Radio.[OperatingFrequencyBand=='5GHz'].getEHTOperations()\"" | awk '/^\[/ {f=1; next} /^\]/ {f=0} f'  | tr -d ' {}[],'  | sed '/^$/d' | sort
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
  WiFi.Radio.\d+.StaticPuncturing.DisabledSubChannels="40,48" (re)

  $ sleep 5

  $ R "ba-cli -l \"WiFi.Radio.[OperatingFrequencyBand=='5GHz'].getEHTOperations()\"" | awk '/^\[/ {f=1; next} /^\]/ {f=0} f'  | tr -d ' {}[],'  | sed '/^$/d' | sort
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
  WiFi.Radio.\d+.StaticPuncturing.DisabledSubChannels="40,44,48" (re)

  $ sleep 5

  $ R "ba-cli -l \"WiFi.Radio.[OperatingFrequencyBand=='5GHz'].getEHTOperations()\"" | awk '/^\[/ {f=1; next} /^\]/ {f=0} f'  | tr -d ' {}[],'  | sed '/^$/d' | sort
  BasicEHT-MCSAndNssSet=1145324612
  CCFS0=42
  CCFS1=0
  ControlChannelWidth=2
  DisabledSubchannelBitmap=14
  DisabledSubchannelBitmapPresent=1
  EHTOperationInformationPresent=1

Expecting the EHT Operations IE puncturing bitmap to be updated:

  $ wifi_dm_radio_band 5 "CurrentEhtOperatingIE?"
  WiFi.Radio.\d+.CurrentEhtOperatingIE="AANEREREAioADgA=" (re)

Downgrade to AX operating mode:

  $ wifi_dm_radio_band 5 "OperatingStandards=\"ax\""
  WiFi.Radio.\d+.OperatingStandards="ax" (re)

  $ sleep 5

  $ R logger -t cram "Checks after downgrade to AX"

  $ wifi_dm_radio_band 5 "EhtPhyCapabilities?"
  WiFi.Radio.\d+.EhtPhyCapabilities="4v/b4Bh1AH4A" (re)

  $ wifi_dm_radio_band 5 "EhtPhyCapabilitiesStr?"
  WiFi.Radio.\d+.EhtPhyCapabilitiesStr="320MHZ,SU_BEAMFORMER,SU_BEAMFORMEE,BEAMFORMEE_SS_80MHZ,BEAMFORMEE_SS_160MHZ,BEAMFORMEE_SS_320MHZ,NB_SOUNDING_80MHZ,NB_SOUNDING_160MHZ,NB_SOUNDING_320MHZ,TGD_SU_BEAMFORMING_FEEDBACK,TGD_MU_BEAMFORMING_PARTIAL_BW,TGD_CQI_FEEDBACK,MUPPDU_4XEHT_LTF,MAX_NC,NTGD_CQI_FEEDBACK,RX_1024_4096_QAM_242TONE_RU,COMMON_NOMINAL_PACKET_PADDING,MAX_SUPPORTED_EHT_LTFS,NON_OFDMA_ULMIMO_80MHZ,NON_OFDMA_ULMIMO_160MHZ,NON_OFDMA_ULMIMO_320MHZ,MU_BEAMFORMER_80MHZ,MU_BEAMFORMER_160MHZ,MU_BEAMFORMER_320MHZ" (re)

  $ wifi_dm_radio_band 5 "CurrentEhtOperatingIE?"
  WiFi.Radio.\d+.CurrentEhtOperatingIE="AAAAAAAAAAAAAAA=" (re)

  $ R "ba-cli -l \"WiFi.Radio.[OperatingFrequencyBand=='5GHz'].getEHTOperations()\"" | awk '/^\[/ {f=1; next} /^\]/ {f=0} f'  | tr -d ' {}[],'  | sed '/^$/d' | sort
  BasicEHT-MCSAndNssSet=0
  CCFS0=0
  CCFS1=0
  ControlChannelWidth=0
  DisabledSubchannelBitmap=0
  DisabledSubchannelBitmapPresent=0
  EHTOperationInformationPresent=0

Check channels 40,44,48 are still configured in Radio.StaticPuncturing

  $ wifi_dm_radio_band 5 "StaticPuncturing.DisabledSubChannels?"
  WiFi.Radio.\d+.StaticPuncturing.DisabledSubChannels="40,44,48" (re)

#########################################
#    test 6GHz getEHTOperations         #
#########################################

  $ R logger -t cram "Test getEHTOperations on 6GHz"

Check ChannelsInUse:

  $ wifi_dm_radio_band 6 "ChannelsInUse?"
  WiFi.Radio.\d+.ChannelsInUse="33,37,41,45,49,53,57,61" (re)

Check EhtPhyCapabilities, EhtPhyCapabilitiesStr, CurrentEhtOperatingIE and getEHTOperations():

  $ R logger -t cram "Check EHT Capabilities"

  $ wifi_dm_radio_band 6 "EhtPhyCapabilities?"
  WiFi.Radio.\d+.EhtPhyCapabilities="4v/b4Bh1AH4A" (re)

  $ wifi_dm_radio_band 6 "EhtPhyCapabilitiesStr?"
  WiFi.Radio.\d+.EhtPhyCapabilitiesStr="320MHZ,SU_BEAMFORMER,SU_BEAMFORMEE,BEAMFORMEE_SS_80MHZ,BEAMFORMEE_SS_160MHZ,BEAMFORMEE_SS_320MHZ,NB_SOUNDING_80MHZ,NB_SOUNDING_160MHZ,NB_SOUNDING_320MHZ,TGD_SU_BEAMFORMING_FEEDBACK,TGD_MU_BEAMFORMING_PARTIAL_BW,TGD_CQI_FEEDBACK,MUPPDU_4XEHT_LTF,MAX_NC,NTGD_CQI_FEEDBACK,RX_1024_4096_QAM_242TONE_RU,COMMON_NOMINAL_PACKET_PADDING,MAX_SUPPORTED_EHT_LTFS,NON_OFDMA_ULMIMO_80MHZ,NON_OFDMA_ULMIMO_160MHZ,NON_OFDMA_ULMIMO_320MHZ,MU_BEAMFORMER_80MHZ,MU_BEAMFORMER_160MHZ,MU_BEAMFORMER_320MHZ" (re)

  $ wifi_dm_radio_band 6 "CurrentEhtOperatingIE?"
  WiFi.Radio.\d+.CurrentEhtOperatingIE="AAFEREREAycvAAA=" (re)

  $ R "ba-cli -l \"WiFi.Radio.[OperatingFrequencyBand=='6GHz'].getEHTOperations()\"" | awk '/^\[/ {f=1; next} /^\]/ {f=0} f'  | tr -d ' {}[],'  | sed '/^$/d' | sort
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
  WiFi.Radio.\d+.StaticPuncturing.DisabledSubChannels="49,53" (re)

  $ sleep 5

  $ R "ba-cli -l \"WiFi.Radio.[OperatingFrequencyBand=='6GHz'].getEHTOperations()\"" | awk '/^\[/ {f=1; next} /^\]/ {f=0} f'  | tr -d ' {}[],'  | sed '/^$/d' | sort
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
  WiFi.Radio.\d+.StaticPuncturing.DisabledSubChannels="53,57,61" (re)

  $ sleep 5

  $ R "ba-cli -l \"WiFi.Radio.[OperatingFrequencyBand=='6GHz'].getEHTOperations()\"" | awk '/^\[/ {f=1; next} /^\]/ {f=0} f'  | tr -d ' {}[],'  | sed '/^$/d' | sort
  BasicEHT-MCSAndNssSet=1145324612
  CCFS0=39
  CCFS1=47
  ControlChannelWidth=3
  DisabledSubchannelBitmap=224
  DisabledSubchannelBitmapPresent=1
  EHTOperationInformationPresent=1

Expecting the EHT Operations IE:

  $  wifi_dm_radio_band 6 "CurrentEhtOperatingIE?"
  WiFi.Radio.\d+.CurrentEhtOperatingIE="AANEREREAycv4AA=" (re)

Downgrade to AX operating mode:

  $ wifi_dm_radio_band 6 "OperatingStandards=\"ax\""
  WiFi.Radio.\d+.OperatingStandards="ax" (re)

  $ sleep 5

  $ R logger -t cram "Checks after downgrade to AX"

  $ wifi_dm_radio_band 6 "EhtPhyCapabilities?"
  WiFi.Radio.\d+.EhtPhyCapabilities="4v/b4Bh1AH4A" (re)

  $ wifi_dm_radio_band 6 "EhtPhyCapabilitiesStr?"
  WiFi.Radio.\d+.EhtPhyCapabilitiesStr="320MHZ,SU_BEAMFORMER,SU_BEAMFORMEE,BEAMFORMEE_SS_80MHZ,BEAMFORMEE_SS_160MHZ,BEAMFORMEE_SS_320MHZ,NB_SOUNDING_80MHZ,NB_SOUNDING_160MHZ,NB_SOUNDING_320MHZ,TGD_SU_BEAMFORMING_FEEDBACK,TGD_MU_BEAMFORMING_PARTIAL_BW,TGD_CQI_FEEDBACK,MUPPDU_4XEHT_LTF,MAX_NC,NTGD_CQI_FEEDBACK,RX_1024_4096_QAM_242TONE_RU,COMMON_NOMINAL_PACKET_PADDING,MAX_SUPPORTED_EHT_LTFS,NON_OFDMA_ULMIMO_80MHZ,NON_OFDMA_ULMIMO_160MHZ,NON_OFDMA_ULMIMO_320MHZ,MU_BEAMFORMER_80MHZ,MU_BEAMFORMER_160MHZ,MU_BEAMFORMER_320MHZ" (re)

  $ wifi_dm_radio_band 6 "CurrentEhtOperatingIE?"
  WiFi.Radio.\d+.CurrentEhtOperatingIE="AAAAAAAAAAAAAAA=" (re)

  $ R "ba-cli -l \"WiFi.Radio.[OperatingFrequencyBand=='6GHz'].getEHTOperations()\"" | awk '/^\[/ {f=1; next} /^\]/ {f=0} f'  | tr -d ' {}[],'  | sed '/^$/d' | sort
  BasicEHT-MCSAndNssSet=0
  CCFS0=0
  CCFS1=0
  ControlChannelWidth=0
  DisabledSubchannelBitmap=0
  DisabledSubchannelBitmapPresent=0
  EHTOperationInformationPresent=0

Check channels 40,44,48 are still configured in Radio.StaticPuncturing

  $  wifi_dm_radio_band 6 "StaticPuncturing.DisabledSubChannels?"
  WiFi.Radio.\d+.StaticPuncturing.DisabledSubChannels="53,57,61" (re)

#########################################
#    Restore defaults                   #
#########################################

  $ R logger -t cram "Finishing EHT operation test"

Restore defaults:

  $ wifi_dm "Radio.*.OperatingStandardsFormat=\"Standard\""
  WiFi.Radio.1.OperatingStandardsFormat="Standard"
  WiFi.Radio.2.OperatingStandardsFormat="Standard"
  WiFi.Radio.3.OperatingStandardsFormat="Standard"

  $ wifi_dm "Radio.*.StaticPuncturing.DisabledSubChannels=\"\""
  WiFi.Radio.1.StaticPuncturing.DisabledSubChannels=""
  WiFi.Radio.2.StaticPuncturing.DisabledSubChannels=""
  WiFi.Radio.3.StaticPuncturing.DisabledSubChannels=""

  $ wifi_dm_radio_band 2 "OperatingStandards=\"b,g,n,ax,be\""
  WiFi.Radio.\d+.OperatingStandards="b,g,n,ax,be" (re)

  $ wifi_dm_radio_band 5 "OperatingStandards=\"a,n,ac,ax,be\""
  WiFi.Radio.\d+.OperatingStandards="a,n,ac,ax,be" (re)

  $ wifi_dm_radio_band 6 "OperatingStandards=\"ax,be\""
  WiFi.Radio.\d+.OperatingStandards="ax,be" (re)

Disable vaps:

  $ wifi_dm "AccessPoint.1.Enable=0"
  WiFi.AccessPoint.1.Enable=0

  $ wifi_dm "AccessPoint.3.Enable=0"
  WiFi.AccessPoint.3.Enable=0

  $ wifi_dm "AccessPoint.5.Enable=0"
  WiFi.AccessPoint.5.Enable=0

  $ sleep 10

  $ wifi_dm "AccessPoint.1.Status?0"
  WiFi.AccessPoint.1.Status="Disabled"

  $ wifi_dm "AccessPoint.3.Status?0"
  WiFi.AccessPoint.3.Status="Disabled"

  $ wifi_dm "AccessPoint.5.Status?0"
  WiFi.AccessPoint.5.Status="Disabled"

  $ R logger -t cram "Restart prplmesh"

  $ R "( /etc/init.d/prplmesh gateway_mode ; sleep 2 ) > /tmp/prplmesh-gw-mode.log 2>&1 ; logger -t prplmesh-gateway-mode < /tmp/prplmesh-gw-mode.log"

  $ R logger -t cram "Test finished!"
