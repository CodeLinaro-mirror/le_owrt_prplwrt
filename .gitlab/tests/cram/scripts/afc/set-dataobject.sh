#!/bin/sh
# ba-cli equivalent of:
#   ba-cli -j -l 'Device.DeviceInfo.Location.N.DataObject="<xml>"'
# Usage: set-dataobject.sh <instance-number> <xml-file>
# The instance must be the number printed by:
#   ba-cli Device.DeviceInfo.Location.+
# A missing number must not be replaced by the filename.
inst="$1"
file="$2"
case "$inst" in
    ''|*[!0-9]*)
        echo "set-dataobject: instance must be a number, got '${inst}'" >&2
        exit 1
        ;;
esac
if [ ! -s "$file" ]; then
    echo "set-dataobject: missing xml file '${file}'" >&2
    exit 1
fi
# One line. The location parser matches element text, not XML layout.
xml=$(tr '\n' ' ' < "$file")
ba-cli -j -l "Device.DeviceInfo.Location.${inst}.DataObject='${xml}'"
