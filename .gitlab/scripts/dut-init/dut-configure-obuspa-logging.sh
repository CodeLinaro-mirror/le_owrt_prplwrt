#!/bin/bash

set -eu
set -o pipefail

verbose_level="${DUT_OBUSPA_VERBOSE_LEVEL:-}"
protocol_trace="${DUT_OBUSPA_PROTOCOL_TRACE:-}"
protocol_trace_state=""

if [ -z "$verbose_level" ] && [ -z "$protocol_trace" ]; then
	echo "OBUSPA debug logging not requested; leaving DUT unchanged"
	exit 0
fi

case "$verbose_level" in
	"" | 0 | 1 | 2 | 3) ;;
	*)
		echo "DUT_OBUSPA_VERBOSE_LEVEL must be empty or one of: 0, 1, 2, 3" >&2
		exit 1
		;;
esac

case "$protocol_trace" in
	"") ;;
	0 | false | False | FALSE | no | No | NO | off | Off | OFF)
		protocol_trace_state=0
		;;
	1 | true | True | TRUE | yes | Yes | YES | on | On | ON)
		protocol_trace_state=1
		;;
	*)
		echo "DUT_OBUSPA_PROTOCOL_TRACE must be empty, boolean false, or boolean true" >&2
		exit 1
		;;
esac

ssh "root@$TARGET_LAN_IP" \
	DUT_OBUSPA_VERBOSE_LEVEL="$verbose_level" \
	DUT_OBUSPA_PROTOCOL_TRACE="$protocol_trace_state" \
	'sh -s' <<'EOF'
set -eu

if [ -n "$DUT_OBUSPA_VERBOSE_LEVEL" ]; then
	if grep -q "^[[:space:]#]*procd_append_param command -v [0-9][0-9]*" /etc/init.d/obuspa; then
		sed -i "s/^[[:space:]#]*procd_append_param command -v [0-9][0-9]*/    procd_append_param command -v ${DUT_OBUSPA_VERBOSE_LEVEL}/" /etc/init.d/obuspa
	else
		sed -i "/procd_set_param stderr 1/a\\
    procd_append_param command -v ${DUT_OBUSPA_VERBOSE_LEVEL}" /etc/init.d/obuspa
	fi
	grep -q "^[[:space:]]*procd_append_param command -v ${DUT_OBUSPA_VERBOSE_LEVEL}" /etc/init.d/obuspa

	obuspa -c verbose "$DUT_OBUSPA_VERBOSE_LEVEL"
	logger -t CI -p local0.info "obuspa verbose logging set to ${DUT_OBUSPA_VERBOSE_LEVEL}"
fi

if [ -n "$DUT_OBUSPA_PROTOCOL_TRACE" ]; then
	if [ "$DUT_OBUSPA_PROTOCOL_TRACE" = "1" ]; then
		if grep -q "^[[:space:]#]*procd_append_param command -p" /etc/init.d/obuspa; then
			sed -i "s/^[[:space:]#]*procd_append_param command -p/    procd_append_param command -p/" /etc/init.d/obuspa
		else
			sed -i "/procd_set_param stderr 1/a\\
    procd_append_param command -p" /etc/init.d/obuspa
		fi
		grep -q "^[[:space:]]*procd_append_param command -p" /etc/init.d/obuspa
	else
		sed -i "s/^[[:space:]]*procd_append_param command -p/# procd_append_param command -p/" /etc/init.d/obuspa
		! grep -q "^[[:space:]]*procd_append_param command -p" /etc/init.d/obuspa
	fi

	obuspa -c prototrace "$DUT_OBUSPA_PROTOCOL_TRACE"
	logger -t CI -p local0.info "obuspa protocol tracing set to ${DUT_OBUSPA_PROTOCOL_TRACE}"
fi
EOF
