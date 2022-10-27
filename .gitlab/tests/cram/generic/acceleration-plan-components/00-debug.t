Add more logging:

    $ script --command "ssh -t root@$TARGET_LAN_IP ubus-cli SSH.set_trace_zone(zone=sshserver,level=500)" > /dev/null; sleep .5
