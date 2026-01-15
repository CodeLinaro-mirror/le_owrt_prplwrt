Run full DHCP DORA test
Interface veth0 must exist in the test namespace

  $ pip install scapy

  $ ip a show 2>&1

  $ sudo setcap cap_net_raw,cap_net_admin+eip $(which python3)

  $ python3 $TESTDIR/dhcp-full-client.py enp2s0 2>&1

