#!/bin/bash

ssh root@$TARGET_LAN_IP "ubus -t 60 wait_for PPP"
ssh root@$TARGET_LAN_IP "ubus call PPP.Interface.1 _set '{\"parameters\":{\"Enable\":1}}'"
