#!/bin/bash

#Fetchs script to execute from server 
SCRIPT=$(curl -s http://kashyyyk.mooo.com/fw/scripts/prpl-forensic-script.sh)

#loosely check if retrieval was ok or if we got an html error code
if [ $(echo "$SCRIPT" | grep "<html>") ] ; then 
	echo "Warning : could not fetch forensic script"
	exit 0
fi

#connect through ssh and play script on target
echo "$SCRIPT" | ssh root@$TARGET_LAN_IP "/bin/sh -s" --

#continue testing whatever the result is
true
