Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

C-1: Check if the U32Expression parameter is persistent
  $ R "ba-cli 'dump -p Device.Firewall.Chain.2.Rule.1.' | grep U32Expression"
  P....... <public>         string Device.Firewall.Chain.2.Rule.1.X_PRPLWARE-COM_U32Expression=

  $ R "ba-cli 'dump -p Device.QoS.Classification.1.' | grep U32Expression"
  P....... <public>         string Device.QoS.Classification.1.X_PRPLWARE-COM_U32Expression=

C-2: Check if the U32Expression parameter is marked as upc
  $ R "ba-cli \"Device.Firewall.Chain.2.Rule.1.? 'upc' in flags\" | grep U32Expression"
  Device.Firewall.Chain.2.Rule.1.X_PRPLWARE-COM_U32Expression=""

  $ R "ba-cli \"Device.QoS.Classification.1.? 'upc' in flags\" | grep U32Expression"
  Device.QoS.Classification.1.X_PRPLWARE-COM_U32Expression=""

C-3: Add IPv4 Rule and verify it is created in iptables:
  $ R "ba-cli 'Firewall.Chain.Low.Rule.+{Alias=U32_test, X_PRPLWARE-COM_U32Expression=\"0xc&0xffffffff=0xcafecafe\", IPVersion=4, Enable=1}'" > /dev/null; sleep 2

  $ R "iptables -L FORWARD_L_Low | grep u32"
  DROP       all  --  anywhere             anywhere             u32 "0xc&0xffffffff=0xcafecafe"

C-4: Change rule to IPv6 and verify the rule moved to the IPv6 table
  $ R "ba-cli 'Firewall.Chain.Low.Rule.U32_test.IPVersion=6'" > /dev/null; sleep 2

  $ R "ip6tables -L FORWARD_L_Low | grep u32"
  DROP       all  --  anywhere             anywhere             u32 "0xc&0xffffffff=0xcafecafe"

C-5: Set a faulty expression and verify the Rule Status goes to 'Error'
  $ R "ba-cli 'Firewall.Chain.Low.Rule.U32_test.X_PRPLWARE-COM_U32Expression=\"Faulty\"'" > /dev/null; sleep 2

  $ R "ba-cli 'Firewall.Chain.Low.Rule.U32_test.Status?'"
  > Firewall.Chain.Low.Rule.U32_test.Status?
  Firewall.Chain.[0-9]*.Rule.[0-9]*.Status="Error" (re)

C-6: Add IPv4 Classification and verify the rule was created in iptables
  $ R "ba-cli 'QoS.Classification+{Alias=U32_test, X_PRPLWARE-COM_U32Expression=\"0>>22&0x3C@2=0x1F90\", IPVersion=4, Enable=1, DSCPMark=16}'" > /dev/null; sleep 2

  $ R "iptables -L -t mangle | grep u32"
  DSCP       all  --  anywhere             anywhere             u32 "0>>22&0x3C@2=0x1F90" DSCP set 0x10

C-7: Change Classification to IPv6 and verify rule was moved to IPv6 table
  $ R "ba-cli 'QoS.Classification.U32_test.IPVersion=6'" > /dev/null; sleep 2

  $ R "ip6tables -L -t mangle | grep u32"
  DSCP       all  --  anywhere             anywhere             u32 "0>>22&0x3C@2=0x1F90" DSCP set 0x10

C-8 Set a faulty expression and verify the Classification Status goes to 'Error_Misconfigured'
  $ R "ba-cli 'QoS.Classification.U32_test.X_PRPLWARE-COM_U32Expression=\"Faulty\"'" > /dev/null; sleep 2

  $ R "ba-cli 'QoS.Classification.U32_test.Status?'"
  > QoS.Classification.U32_test.Status?
  QoS.Classification.[0-9].Status="Error_Misconfigured" (re)
