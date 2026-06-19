Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that we've correct bridge aliases:

  $ R "ba-cli -l 'Bridging.Bridge.*.Alias?' | sort"
  guest
  lan
  lcm

Check that we've correct DHCP pool settings:

  $ R "ba-cli -l 'DHCPv4Server.Pool.*.Alias?;DHCPv4Server.Pool.*.DNSServers?;DHCPv4Server.Pool.*.Enable?;DHCPv4Server.Pool.*.MaxAddress?;DHCPv4Server.Pool.*.MinAddress?;DHCPv4Server.Pool.*.Status?;DHCPv4Server.Pool.*.WINSServers?' | sort"



  192.168.1.1
  192.168.1.2
  192.168.1.254
  192.168.2.1
  192.168.2.100
  192.168.2.249
  192.168.3.1
  192.168.3.100
  192.168.3.249
  Enabled
  Enabled
  Enabled
  guest
  lan
  lcm
  true
  true
  true

  $ R "ba-cli -l 'DHCPv6Server.Pool.*.Alias?;DHCPv6Server.Pool.*.Enable?;DHCPv6Server.Pool.*.IANAEnable?;DHCPv6Server.Pool.*.IAPDEnable?;DHCPv6Server.Pool.*.Status?' | sort"
  Error_Misconfigured
  Error_Misconfigured
  Error_Misconfigured
  false
  false
  false
  guest
  lan
  lcm
  true
  true
  true
  true
  true
  true

Check that aclmanager has expected setup:

  $ R "ba-cli -l 'ACLManager.Role.*.Name?;ACLManager.Role.*.Alias?' | sort"
  admin
  cpe-Role-1
  cpe-Role-2
  cpe-Role-3
  cpe-Role-4
  cpe-Role-5
  cwmp
  cwmpd
  operator
  untrusted

Check that Users.Role component has expected setup:

  $ R "ba-cli -l 'Users.Role.*.Alias?;Users.Role.*.RoleName?' | sort"
  acl
  acl-role
  admin
  admin-role
  bus-access
  bus-access-role
  guest
  guest-role
  untrusted
  untrusted-role

Check that we've correct hostname and release info:

  $ R "ubus -S call system board | jsonfilter -e '@.hostname' -e '@.release.distribution'"
  prplOS.lan
  prplOS
