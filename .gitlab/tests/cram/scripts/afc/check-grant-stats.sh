#!/bin/sh
# Quote-safe AFC Stats tokens for cram over ssh.
#
# ba-cli -l of AvailableSpectrumResponse prints a line whose value is raw JSON
# with many " characters. Carrying that line back through ssh/shell triggers
# busybox: Syntax error: Unterminated quoted string. Dump to a DUT-local file
# and only print plain tokens on stdout.

ba-cli -l Device.WiFi.AFC.Stats.GrantExpiryTime? > /tmp/afc-cram-expiry.out 2>&1
sed -n 's/.*GrantExpiryTime="\([^"]*\)".*/grant-expiry=\1/p' /tmp/afc-cram-expiry.out | head -1

ba-cli -l Device.WiFi.AFC.Stats.AvailableSpectrumResponse? > /tmp/afc-cram-resp.out 2>&1
grep -o responseCode /tmp/afc-cram-resp.out | head -1

ba-cli -j -l Device.WiFi.AFC.Status? > /tmp/afc-cram-status.out 2>&1
grep -o GRANT_SUCCESS /tmp/afc-cram-status.out | head -1
