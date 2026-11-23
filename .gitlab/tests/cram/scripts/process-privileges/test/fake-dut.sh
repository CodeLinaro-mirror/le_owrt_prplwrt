#!/bin/sh
# Stands in for the DUT transport in the verify.py tests:
#
#   CRAM_REMOTE_COPY="sh fake-dut.sh copy"         instead of scp
#   CRAM_REMOTE_COMMAND="sh fake-dut.sh ssh <host>" instead of ssh
#
# Every call is logged to $FAKE_DUT/log. The collector is never run: each
# "list" run prints $FAKE_DUT/list.<attempt>, or $FAKE_DUT/list once those run
# out, and "tree" and "color" runs print $FAKE_DUT/tree. A file
# $FAKE_DUT/copy-fails makes the copy fail, and $FAKE_DUT/exit-code sets the
# exit code of a collector run.

state="${FAKE_DUT:?FAKE_DUT must name the state directory}"
mode="$1"
shift

case "$mode" in
copy)
	echo "copy $(basename "$1") $2" >> "$state/log"
	if [ -e "$state/copy-fails" ]; then
		exit 1
	fi
	;;
ssh)
	host="$1"
	shift
	echo "ssh $host $*" >> "$state/log"
	case "$*" in
	*" list")
		attempt=$(($(cat "$state/attempts" 2>/dev/null || echo 0) + 1))
		echo "$attempt" > "$state/attempts"
		if [ -e "$state/list.$attempt" ]; then
			cat "$state/list.$attempt"
		else
			cat "$state/list"
		fi
		;;
	*" tree" | *" color")
		cat "$state/tree"
		;;
	esac
	if [ -e "$state/exit-code" ]; then
		exit "$(cat "$state/exit-code")"
	fi
	;;
*)
	echo "usage: fake-dut.sh copy <src> <dest> | ssh <host> <command>" >&2
	exit 2
	;;
esac
