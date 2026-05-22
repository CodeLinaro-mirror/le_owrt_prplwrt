#!/bin/sh

case "${1:-generic}" in
    generic)
        obuspa -f /etc/obuspa.db -c dump datamodel | grep '^Device.' | grep -v \
            -e 'Device.Cellular.' \
            -e 'Device.WiFi.AccessPoint.{i}.Vendor.' \
            -e 'Device.WiFi.EndPoint.{i}.Vendor.' \
            -e 'Device.WiFi.Radio.{i}.Vendor.' \
            -e 'Device.WiFi.Radio.{i}.NaStaMonitor.' \
            -e 'Device.WiFi.Vendor.ReconfManager.'
        ;;
    cellular)
        obuspa -f /etc/obuspa.db -c dump datamodel | grep '^Device.Cellular.' || true
        ;;
    *)
        echo "Usage: $0 [generic|cellular]" >&2
        exit 1
        ;;
esac
