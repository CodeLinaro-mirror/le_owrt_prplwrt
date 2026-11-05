#!/bin/sh
# Test-only configuration overlay for the retry-off split measurement.
set -eu
for tool in sed grep cat mkdir sync reboot; do
    command -v "$tool" >/dev/null || { echo "retry-off: missing $tool" >&2; exit 2; }
done
files='/etc/amx/prplmesh-dm-mapper/prplmesh-dm-mapper.odl
/etc/amx/tr181-device/extensions/tr181-device_usp.odl
/opt/prplmesh/config/controller/odl/ieee1905_usp_cfg.odl'
global=/etc/amx/global.d/99-register-retry-off.odl
cli=/etc/amx/cli/usp-cli.init
if [ "$1" = apply ]; then
    # Reject a changed input rather than silently applying a partial overlay.
    for file in $files; do
        [ "$(grep -c 'usp.register-retry = true;' "$file")" = 1 ]
    done
    grep -Fxq '!amx variable usp = { EndpointID = "proto::usp-cli" }' "$cli"
    for file in $files; do
        sed -i 's/usp\.register-retry = true;/usp.register-retry = false;/' "$file"
    done
    sed -i 's/EndpointID = "proto::usp-cli" }/EndpointID = "proto::usp-cli", register-retry = false }/' "$cli"
    mkdir -p /etc/amx/global.d
    printf '%%config { %%global usp.register-retry = false; }\n' >"$global"
elif [ "$1" != check ]; then
    echo 'retry-off: expected apply or check' >&2
    exit 2
fi
# Retain just the option readback, without dumping unrelated configuration.
grep -Fxq '%config { %global usp.register-retry = false; }' "$global"
for file in $files; do
    [ "$(grep -c 'usp.register-retry = false;' "$file")" = 1 ]
    if grep -q 'usp.register-retry = true;' "$file"; then exit 2; fi
    grep -n 'usp.register-retry' "$file"
done
grep -Fxq '!amx variable usp = { EndpointID = "proto::usp-cli", register-retry = false }' "$cli"
grep -n 'register-retry' "$cli" "$global"
sync
