#!/bin/bash

ssh "root@$TARGET_LAN_IP" <<'EOF'
grep -q "procd_append_param command -v 3" /etc/init.d/obuspa ||
  sed -i 's/# procd_append_param command -v 2/    procd_append_param command -v 3/' /etc/init.d/obuspa
grep -q "procd_append_param command -v 3" /etc/init.d/obuspa
obuspa -c verbose 3
logger -t CI -p local0.info "obuspa verbose logging enabled, $(uptime -p)"
EOF
