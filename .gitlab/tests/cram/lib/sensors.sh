# GPS feed and barometer fixture helpers for prplOS cram tests.
#
# Sourced after lib/dm.sh. Everything here runs on the DUT through R and
# needs only busybox: the target has no gpsfake, no socat and no `nc -u`.
#
# GPS: gpsd is repointed from the UART to a FIFO that a 1 Hz shell loop keeps
# fed with a canned fix. tr181-gps polls gpsd on a fixed schedule (at start,
# +5 min, +10 min, hourly), so tests restart it after the feed is live.
#
# Barometer: tr181-barometer reads in_pressure_input (kPa) and in_temp_input
# (millidegrees C) from the directory named by BAROMETER_IIO_PATH, which it
# evaluates once at process start. On prplOS the variable reaches services via
# /var/etc/environment, populated at boot by /etc/env.d. The fixture overrides
# it there and restarts the service, which also re-triggers the SenML push.
#
# Both fixtures back up what they change and restore it on stop.

GPS_FIFO=/tmp/gps.fifo
GPS_NMEA=/tmp/fix.nmea
GPS_DEV_BACKUP=/tmp/gpsd.device.cram-orig
BARO_IIO=/tmp/iio
BARO_UNCERTAINITY=3.5
BARO_ENV=/etc/environment
BARO_ENV_BACKUP=/etc/environment.cram-orig
GPS_FEED_PID=/tmp/gps-feed.pid

# gps_feed_start NMEA_FILE : push the canned sentences, switch gpsd to a FIFO
# source and start the feeder loop.
gps_feed_start() {
    R "cat > $GPS_NMEA" < "$1" || return 1

    R "
        uci get gpsd.core.device > $GPS_DEV_BACKUP 2>/dev/null
        [ -p $GPS_FIFO ] || mkfifo $GPS_FIFO
        uci set gpsd.core.device='$GPS_FIFO' &&
        uci commit gpsd &&
        /etc/init.d/gpsd restart
    " || return 1

    R "
        sh -c 'while :; do cat $GPS_NMEA; sleep 1; done > $GPS_FIFO' \
            >/dev/null 2>&1 &
        echo \$! > $GPS_FEED_PID
    " || return 1

    echo "gps feed started"
}

# gps_fix_check : ask gpsd itself for a fix, independent of the plugin.
# Prints 'mode=<n> lat=<lat> lon=<lon>' from the first TPV report.
gps_fix_check() {
    _tpv=$(R "gpspipe -w -n 8 127.0.0.1:2947" \
        | jq -r 'select(.class == "TPV" and .mode >= 2)
                 | "mode=\(.mode) lat=\((.lat * 10000 | round) / 10000) lon=\((.lon * 10000 | round) / 10000)"' \
        | head -n 1)

    if [ -n "$_tpv" ]; then
        printf '%s\n' "$_tpv"
    else
        echo "no TPV fix in the first 8 gpsd reports"
        return 1
    fi
}

# gps_feed_stop : stop the feeder, restore the UART source, and restart both
# consumers.
gps_feed_stop() {
    R "
        [ -f $GPS_FEED_PID ] &&
            kill \$(cat $GPS_FEED_PID) 2>/dev/null || :

        test -s $GPS_DEV_BACKUP &&
        _gps_device=\$(cat $GPS_DEV_BACKUP) &&
        uci set gpsd.core.device=\"\$_gps_device\" &&
        uci commit gpsd &&
        /etc/init.d/gpsd restart &&
        /etc/init.d/tr181-gps restart &&
        test \"\$(uci -q get gpsd.core.device)\" = \"\$_gps_device\" &&
        rm -f $GPS_FIFO $GPS_NMEA $GPS_DEV_BACKUP $GPS_FEED_PID
    " || return 1

    echo "gps feed stopped"
}

# baro_fixture_start PRESSURE_KPA TEMP_MILLIC : fake IIO device + env override.
baro_fixture_start() {
    R "mkdir -p $BARO_IIO &&
       printf '%s\n' '$1' > $BARO_IIO/in_pressure_input &&
       printf '%s\n' '$2' > $BARO_IIO/in_temp_input" || return 1
    R "[ -f $BARO_ENV_BACKUP ] || cp $BARO_ENV $BARO_ENV_BACKUP 2>/dev/null || : > $BARO_ENV_BACKUP;
       sed -i '/^export BAROMETER_IIO_PATH=/d' $BARO_ENV;
       echo 'export BAROMETER_IIO_PATH=\"$BARO_IIO\"' >> $BARO_ENV;
       echo 'export VERTICAL_UNCERTAINTY_M=\"$BARO_UNCERTAINITY\"' >> $BARO_ENV;
       /etc/init.d/tr181-barometer restart" || return 1
    echo "barometer fixture started"
}

# baro_fixture_path_check : print the IIO path exported to the service
# environment, then confirm that the fixture configuration is available.
baro_fixture_path_check() {
    R ". $BARO_ENV; printf 'BAROMETER_IIO_PATH=%s\n' "\$BAROMETER_IIO_PATH"" || return 1
    echo "barometer fixture path exported"
}

# baro_fixture_break : remove the pressure source and restart (negative path).
baro_fixture_break() {
    R "rm -f $BARO_IIO/in_pressure_input; /etc/init.d/tr181-barometer restart" || return 1
    echo "barometer pressure source removed"
}

# baro_fixture_stop : restore the environment file and the real sensor path.
baro_fixture_stop() {
    R "[ -f $BARO_ENV_BACKUP ] && mv $BARO_ENV_BACKUP $BARO_ENV;
       rm -rf $BARO_IIO; /etc/init.d/tr181-barometer restart"
    echo "barometer fixture stopped"
}

