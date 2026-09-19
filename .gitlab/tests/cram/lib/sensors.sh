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

# _gps_push_nmea LOCAL_FILE : deliver canned NMEA to the DUT without SSH stdin.
#
# CI sets CRAM_REMOTE_COMMAND to `ssh -n ...` (testbed.yml). `ssh -n` redirects
# stdin from /dev/null, so `R "cat > remote" < local` creates an *empty* remote
# file — the classic local-pass / CI-fail for this fixture (same pitfall as
# process-privileges/collect.sh). Prefer CRAM_REMOTE_COPY; for this tiny fixture
# fall back to an in-band base64 payload so a missing TARGET_LAN_IP still works.
_gps_push_nmea() {
    _gps_host="${TARGET_LAN_IP:-}"
    if [ -z "$_gps_host" ]; then
        _gps_host=$(printf '%s\n' "${CRAM_REMOTE_COMMAND:-}" |
            sed -n 's/.*@\([^[:space:]]*\).*/\1/p')
    fi

    if [ -n "$_gps_host" ]; then
        # scp prints "Permanently added ... known hosts" on stderr in CI.
        ${CRAM_REMOTE_COPY:-scp} "$1" "root@${_gps_host}:${GPS_NMEA}" 2>/dev/null || {
            echo "failed to copy NMEA fixture to ${_gps_host}"
            return 1
        }
    else
        _gps_b64=$(base64 -w0 < "$1" 2>/dev/null || base64 < "$1" | tr -d '\n') ||
            return 1
        # printf (not echo): keep the payload free of echo-backslash surprises.
        R "printf '%s' '$_gps_b64' | base64 -d > ${GPS_NMEA}" || return 1
    fi

    R "test -s ${GPS_NMEA}" || {
        echo "remote NMEA fixture missing or empty (ssh -n stdin discard?)"
        return 1
    }
}

# gps_feed_start NMEA_FILE : push the canned sentences, switch gpsd to a FIFO
# source and start the feeder loop.
#
# Ordering matters with gpsd on Linux:
#  - gpsd's exclusive-open check (fusercount) rejects a FIFO that already has a
#    writer, so gpsd must claim the FIFO first (O_RDWR), then the feeder attaches.
#  - gpsd drops to nobody; a root-owned 0644 FIFO is unreadable on reopen, so
#    the FIFO must be world rw for the fixture.
# Stock OpenWrt gpsd.init only passes -N -n [-G] -S <port> <device> — no UCI
# "options" / -b — so we only repoint device.
gps_feed_start() {
    _gps_push_nmea "$1" || return 1

    R "
        [ -f $GPS_FEED_PID ] && kill \$(cat $GPS_FEED_PID) 2>/dev/null || :
        rm -f $GPS_FIFO $GPS_FEED_PID

        if [ ! -s $GPS_DEV_BACKUP ]; then
            uci get gpsd.core.device > $GPS_DEV_BACKUP 2>/dev/null || exit 1
        fi

        mkfifo $GPS_FIFO || exit 1
        chmod 666 $GPS_FIFO || exit 1
        uci set gpsd.core.device='$GPS_FIFO' &&
        uci commit gpsd &&
        /etc/init.d/gpsd restart || exit 1
    " || return 1

    # Wait until gpsd is accepting clients before attaching the writer, so the
    # daemon can open the FIFO alone and pass its exclusive-open check.
    R "
        i=0
        while [ \$i -lt 20 ]; do
            gpspipe -w -n 1 127.0.0.1:2947 >/dev/null 2>&1 && exit 0
            i=\$((i + 1))
            sleep 1
        done
        exit 1
    " || {
        echo "gpsd not accepting clients after FIFO switch"
        return 1
    }

    # The feeder must outlive the R() session. prplOS busybox has no nohup, so
    # detach with start-stop-daemon (-b: setsid + background, -m: pidfile).
    # The FIFO is reopened per cycle so a reader hiccup only kills that cat.
    R "
        start-stop-daemon -S -b -m -p $GPS_FEED_PID -x /bin/sh -- -c \
            'while :; do cat $GPS_NMEA > $GPS_FIFO; sleep 1; done' || exit 1
        sleep 1
        kill -0 \$(cat $GPS_FEED_PID) 2>/dev/null || exit 1
    " || {
        echo "gps NMEA feeder failed to start"
        return 1
    }

    # Confirm the feeder survived SSH session teardown.
    R "kill -0 \$(cat $GPS_FEED_PID) 2>/dev/null" || {
        echo "gps NMEA feeder died after ssh session end"
        return 1
    }

    # One or two 1 Hz cycles for gpsd to parse RMC/GGA into a TPV fix.
    sleep 3

    echo "gps feed started"
}

# gps_fix_check : wait up to 20s for a TPV fix from gpsd.
# Prints 'mode=<n> lat=<lat> lon=<lon>' from the first TPV with mode >= 2.
gps_fix_check() {
    # BusyBox on the DUT may lack the 'timeout' applet, so use a background
    # watchdog instead. Do NOT stop on the first TPV: gpsd often emits mode=1
    # (no fix) before mode=2/3. Stopping early is a common local-vs-CI flake —
    # a fast DUT may already be at mode=3 when gpspipe connects; a slow CI DUT
    # still has mode=1 and we would kill gpspipe before the fix arrives.
    _gps_reports=$(R "
        set +m 2>/dev/null || :
        _out=/tmp/gps_fix_check.\$\$
        : > \$_out
        gpspipe -w 127.0.0.1:2947 >>\$_out 2>/dev/null &
        _pid=\$!
        ( sleep 20; kill \$_pid ) >/dev/null 2>&1 &
        _wd=\$!
        i=0
        while [ \$i -lt 20 ]; do
            if grep -qE '\"class\"[[:space:]]*:[[:space:]]*\"TPV\"' \$_out 2>/dev/null &&
               grep -qE '\"mode\"[[:space:]]*:[[:space:]]*[23]' \$_out 2>/dev/null; then
                kill \$_pid 2>/dev/null || :
                break
            fi
            kill -0 \$_pid 2>/dev/null || break
            sleep 1
            i=\$((i + 1))
        done
        wait \$_pid 2>/dev/null || :
        kill \$_wd 2>/dev/null || :
        cat \$_out
        rm -f \$_out
    ") || {
        echo "gpsd report collection failed or timed out after 20s"
        return 1
    }
    _tpv=$(printf '%s\n' "$_gps_reports" \
        | jq -r 'select(.class == "TPV" and .mode >= 2 and .lat != null and .lon != null)
                 | "mode=\(.mode) lat=\((.lat * 10000 | round) / 10000) lon=\((.lon * 10000 | round) / 10000)"' \
        | head -n 1)

    if [ -n "$_tpv" ]; then
        printf '%s\n' "$_tpv"
    else
        printf '%s\n' "no TPV fix from gpsd within 20s"
        return 1
    fi
}

# gps_feed_stop : stop the feeder, restore the UART source, and restart both
# consumers. Safe after partial setup and on repeated cleanup.
gps_feed_stop() {
    R "
        [ -f $GPS_FEED_PID ] &&
            kill \$(cat $GPS_FEED_PID) 2>/dev/null || :

        if [ -s $GPS_DEV_BACKUP ]; then
            _gps_device=\$(cat $GPS_DEV_BACKUP) &&
            uci set gpsd.core.device=\"\$_gps_device\" &&
            uci commit gpsd &&
            /etc/init.d/gpsd restart &&
            /etc/init.d/tr181-gps restart &&
            test \"\$(uci -q get gpsd.core.device)\" = \"\$_gps_device\" ||
                exit 1
        fi
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


