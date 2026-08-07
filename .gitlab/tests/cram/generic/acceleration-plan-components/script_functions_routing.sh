#!/bin/sh

# Helpers shared by the 122-routing-* cram tests.
#
# The routing data model is filled in asynchronously, once the routing protocol
# converges, so the tests have to poll it instead of reading a parameter once.
# All the wait_* helpers below are built on top of the same generic poller.

# Seconds the wait_* helpers keep polling before they give up.
ROUTING_WAIT_TIMEOUT=${ROUTING_WAIT_TIMEOUT:-20}

# get_param - reads a single parameter from the data model
# Parameters:
#   $1 - path: data model path of the parameter, without the trailing '?'
# Outputs:
#   the parameter value, empty when it is not available (yet)
get_param() {
	R "ba-cli -l $1?" | awk 'NF'
}

# _wait_param - polls a data model parameter until it satisfies a condition
# Parameters:
#   $1 - match: 'eq' to compare as strings, 'min' for a numeric lower bound
#   $2 - path: data model path of the parameter, without the trailing '?'
#   $3 - expected: value to compare the parameter against
# Returns:
#   0 as soon as the parameter satisfies the condition,
#   1 on timeout (after ROUTING_WAIT_TIMEOUT seconds)
_wait_param() {
	match=$1
	path=$2
	expected=$3
	i=0
	while [ ${i} -le ${ROUTING_WAIT_TIMEOUT} ]; do
		value=$(get_param "${path}")
		case ${match} in
		eq)
			if [ "${value}" = "${expected}" ]; then
				return 0
			fi
			;;
		min)
			case ${value} in
			'' | *[!0-9]*) ;;
			*)
				if [ "${value}" -ge "${expected}" ]; then
					return 0
				fi
				;;
			esac
			;;
		esac

		i=$((i + 1))
		sleep 1
	done
	echo "[ERROR]: timeout waiting for ${path} to match '${match} ${expected}', last value: '${value}'"
	return 1
}

# wait_param - waits for a data model parameter to hold the expected value
# Parameters:
#   $1 - path: data model path of the parameter, without the trailing '?'
#   $2 - expected: value to wait for
wait_param() {
	_wait_param eq "$1" "$2"
}

# wait_param_min - waits for a numeric data model parameter to reach a minimum
# Parameters:
#   $1 - path: data model path of the parameter, without the trailing '?'
#   $2 - minimum: smallest accepted value
wait_param_min() {
	_wait_param min "$1" "$2"
}

# wait_bgp_session - waits for a BGP neighbor session to reach a given state
# Parameters:
#   $1 - config_alias: BGP configuration alias name
#   $2 - nb_alias: BGP neighbor alias name
#   $3 - state: expected session state
wait_bgp_session() {
	wait_param "Device.Routing.X_PRPLWARE-COM_BGP.Config.$1.Neighbor.$2.SessionState" "$3"
}

# wait_ospf_state - waits for an OSPF interface to reach a given state
# Parameters:
#   $1 - config_alias: OSPF configuration alias name
#   $2 - area_index: OSPF area instance index
#   $3 - interface_index: OSPF interface instance index
#   $4 - state: expected interface state
wait_ospf_state() {
	wait_param "Routing.X_PRPLWARE-COM_OSPF.Config.$1.Area.$2.Interface.$3.State" "$4"
}

# wait_ospf_neighbors - waits until an OSPF interface discovered its neighbors
# Parameters:
#   $1 - config_alias: OSPF configuration alias name
#   $2 - area_index: OSPF area instance index
#   $3 - interface_index: OSPF interface instance index
#   $4 - count: minimum number of expected neighbors, defaults to 1
wait_ospf_neighbors() {
	wait_param_min "Routing.X_PRPLWARE-COM_OSPF.Config.$1.Area.$2.Interface.$3.NeighborNumberOfEntries" "${4:-1}"
}
