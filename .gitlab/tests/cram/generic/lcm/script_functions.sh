#!/bin/sh

### Default parameters config when value is not provided
DEFAULT_UUID="00000000-0000-5000-b000-000000000001"
DEFAULT_HOSTOBJECT='[{Source="/tmp/testdir", Destination="/testdir", Options="type=mount,bind"}, {Source="/tmp/testfile", Destination="/testfile", Options="type=mount,bind"}, {Source="", Destination="/dev/host_serial", Options="type=device,devicetype=c,major=5,minor=1,access=rwm,create=1"}]'
#DEFAULT_NETWORK='{ShareParentNetwork = "true"}''
DEFAULT_NETWORK='{AccessInterfaces = [{Reference = "Lan"}]}'
DEFAULT_EE="generic"
DEFAULT_APPDATA='[{Name = "Volume1", Capacity = 1, Retain = "UntilStopped", AccessPath = "/volume1"}, {Name = "Volume2", Capacity = 1, Retain = "Forever", AccessPath = "/volume2"}]'
DEFAULT_URL="docker://registry.gitlab.com/prpl-foundation/prplos/prplos"
DEFAULT_USPROLES="Full Access"
DEFAULT_USPREQUIRED="Full Access"
DEFAULT_USPOPTIONAL=""
DEFAULT_RETAINDATA="false"
DEFAULT_ENVVAR='[{Key="ENVVAR_KEY1", Value="ENVVAR_VALUE1"}, {Key="ENVVAR_KEY2", Value="ENVVAR_VALUE2"}]'

CLI_JSON="ba-cli -l -j"
CLI="ba-cli"

MAX_WAIT_CTR_UP=60

## Return default container name based on target.
## Default is Cortex-A53 based ARM 64-bit container
get_container_name() {
	board_name=$(cut -d',' -f2 </tmp/sysinfo/board_name)
	case "${board_name}" in
	"haze" | \
		"freedom" | \
		"mozart")
		echo lcm-test-ipq807x-generic
		;;
	"lgm" | \
		"qemu-standard-pc-"*)
		echo lcm-test-x86-64
		;;
	"turris-omnia")
		echo lcm-test-mvebu-cortexa9
		;;
	*)
		echo lcm-test-ipq807x-generic
		;;
	esac
}

get_container_by_name() {
        arg=$1
        ctr_name=$(echo $arg | cut -d ':' -f 1) ## strip the version if any

        if [ ${ctr_name} = "alpine" ]; then
            board_name=$(cut -d',' -f2 </tmp/sysinfo/board_name)
            case "${board_name}" in
            "haze" | \
                    "freedom")
                    hw_ctr_name="alpine3.16-arm32v7"
                   ;;
            "lgm" | \
                    "qemu-standard-pc-"*)
                    hw_ctr_name="alpine3.16-amd64"
                    ;;
            "turris-omnia")
                    hw_ctr_name="alpine3.16-cortexa9"
                    ;;
            *)
                    hw_ctr_name="alpine3.16-arm32v7"
                    ;;
            esac
        else
           hw_ctr_name="unknown"
        fi

        echo "${hw_ctr_name}"
}

## Return architecture name for the board
get_board_arch() {
	board_name=$(cut -d',' -f2 </tmp/sysinfo/board_name)
	case "${board_name}" in
	"haze" | \
		"freedom" | \
		"mozart")
		echo cortexa53
		;;
	"lgm" | \
		"qemu-standard-pc-"*)
		echo x86-64
		;;
	"turris-omnia")
		echo cortexa9
		;;
	*)
		echo generic
		;;
	esac
}

get_container_version_by_name() {
        arg=$1
        version=$(echo $arg | cut -s -d ':' -f 2) ## Get version if any

        if [ -n "${version}" ]; then
            echo "${version}"
        else
           echo "latest"
        fi
}


concat_comma_string() {
	_concat_global_str="$1"
	_concat_param="$2"

	if [ -n "${_concat_global_str}" ]; then
		_concat_global_str="${_concat_global_str}, "
	fi

	_concat_global_str="${_concat_global_str}${_concat_param}"

	echo "${_concat_global_str}"
}

## waits for a container to go up or timeout
wait_ctr_up() {
	uuid=""
	debugargs=0
	waittime=${MAX_WAIT_CTR_UP}
	while [ $# -gt 0 ]; do
		key="$1"
		value=""
		value_missing=false
		case $key in
		--*) # If argument starts with "--"
			key="${key#--}"
			shift
			if [ $# -gt 0 ] && case "$1" in --*) false ;; *) true ;; esac then
				value="$1"
				shift
			elif [ $# -eq 0 ] || case "$1" in --*) true ;; *) false ;; esac then
				value_missing=true
			fi

			if [ "${key}" = "uuid" ]; then
				uuid=$(value_or_default "${value_missing}" "${DEFAULT_UUID}" "${value}")
			elif [ "${key}" = "debugargs" ]; then
				debugargs=$(value_or_default "${value_missing}" "1" "${value}")
			elif [ "${key}" = "waittime" ]; then
				waittime=$(value_or_default "${value_missing}" "${MAX_WAIT_CTR_UP}" "${value}")
			else
				if [ ${debugargs} -ne 0 ]; then
					echo "Unknown argument: ${key}=${value}"
				fi
			fi
			;;
		*)
			if [ ${debugargs} -ne 0 ]; then
				echo "Unknown argument: ${key}"
			fi
			shift
			;;
		esac
	done
	if [ $waittime -eq 0 ]; then
		return
	elif [ -z "${uuid}" ]; then
		echo "Missing UUID parameter: Cannot wait for container up"
	else
		duid=$(${CLI_JSON} "SoftwareModules.DeploymentUnit.[ UUID == \"${uuid}\" ].DUID?" | jsonfilter -e @[*].*.DUID)
		if [ -z "${duid}" ]; then
			echo "Container with UUID=${uuid} is not found"
			return
		fi
		i=0
		while [ $i -le ${MAX_WAIT_CTR_UP} ]; do
			status=$(${CLI_JSON} "SoftwareModules.ExecutionUnit.[ EUID == \"${duid}\" ].Status?" | jsonfilter -e @[*].*.Status)
			if [ "${status}" != "Active" ]; then
				i=$((i + 2))
				sleep 2
			else
				break
			fi
			# timeout
		done
	fi
}

## waits for a container to go down or timeout
wait_ctr_down() {
	# Read max shutdown delay
	shutdowndelay=$(${CLI_JSON} Cthulhu.Config.GracefulShutdownTimeoutSeconds? | jsonfilter -e @[*].*.GracefulShutdownTimeoutSeconds)
	if [ -z "$shutdowndelay" ]; then
		shutdowndelay=10
	fi

	# Add extra 3 seconds delay
	shutdowndelay=$((shutdowndelay + 3))

	sleep ${shutdowndelay}
}

## Return default value if no value is given
## or the value provided
value_or_default() {
	_assign_value_missing="$1"
	_assign_default="$2"
	_assign_value="$3"

	if [ "${_assign_value_missing}" = "true" ]; then
		echo "${_assign_default}"
	else
		echo "${_assign_value}"
	fi
}

install_update_ctr_with_params() {
	params=$@
	operation=$1
	if [ "${operation}" != "install" ] && [ "${operation}" != "update" ]; then
		echo "Unknown operation: $operation"
		return
	fi

	shift
	str_params=""
	uuid=""
	debugargs=0

	while [ $# -gt 0 ]; do
		key="$1"
		value=""
		value_missing=false
		case $key in
		--*) # If argument starts with "--"
			key="${key#--}"
			shift
			if [ $# -gt 0 ] && case "$1" in --*) false ;; *) true ;; esac then
				value="$1"
				shift
			elif [ $# -eq 0 ] || case "$1" in --*) true ;; *) false ;; esac then
				value_missing=true
			fi

			if [ "${key}" = "url" ]; then
				#value=$(value_or_default "${value_missing}" "$(get_container_url)" "${value}")
				str_params=$(concat_comma_string "${str_params}" "URL = \"${value}\"")
			elif [ "${key}" = "name" ]; then
				ctr_name=$(get_container_by_name ${value})
                                ctr_version=$(get_container_version_by_name ${value})
				str_params=$(concat_comma_string "${str_params}" "URL = \"${DEFAULT_URL}/${ctr_name}:${ctr_version}\"")
			elif [ "${key}" = "version" ]; then
				ctr_name=$(get_container_name)
				str_params=$(concat_comma_string "${str_params}" "URL = \"${DEFAULT_URL}/prplos/${ctr_name}:${value}\"")
			elif [ "${key}" = "uuid" ]; then
				value=$(value_or_default "${value_missing}" "${DEFAULT_UUID}" "${value}")
				str_params=$(concat_comma_string "${str_params}" "UUID = ${value}")
				uuid=${value}
			elif [ "${key}" = "ee" ]; then
				value=$(value_or_default "${value_missing}" "${DEFAULT_EE}" "${value}")
				str_params=$(concat_comma_string "${str_params}" "ExecutionEnvRef = \"${value}\"")
			elif [ "${key}" = "network" ]; then
				value=$(value_or_default "${value_missing}" "${DEFAULT_NETWORK}" "${value}")
				str_params=$(concat_comma_string "${str_params}" "NetworkConfig = ${value}")
			elif [ "${key}" = "hostobject" ]; then
				value=$(value_or_default "${value_missing}" "${DEFAULT_HOSTOBJECT}" "${value}")
				str_params=$(concat_comma_string "${str_params}" "HostObject = ${value}")
			elif [ "${key}" = "appdata" ]; then
				value=$(value_or_default "${value_missing}" "${DEFAULT_APPDATA}" "${value}")
				str_params=$(concat_comma_string "${str_params}" "ApplicationData = ${value}")
			elif [ "${key}" = "usprequired" ]; then
				value=$(value_or_default "${value_missing}" "${DEFAULT_USPREQUIRED}" "${value}")
				str_params=$(concat_comma_string "${str_params}" "RequiredRoles = \"${value}\"")
			elif [ "${key}" = "uspeoptional" ]; then
				value=$(value_or_default "${value_missing}" "${DEFAULT_USPOPTIONAL}" "${value}")
				str_params=$(concat_comma_string "${str_params}" "OptionalRoles = \"${value}\"")
			elif [ "${key}" = "privileged" ]; then
				value=$(value_or_default "${value_missing}" "${DEFAULT_PRIVILEGED}" "${value}")
				str_params=$(concat_comma_string "${str_params}" "Privileged = ${value}")
				if [ "${value}" = "false" ]; then
					str_params=$(concat_comma_string "${str_params}" "NumRequiredUIDs = 10")
				fi
			elif [ "${key}" = "retaindata" ]; then
				retaindata=$(value_or_default "${value_missing}" "${DEFAULT_RETAINDATA}" "${value}")
				str_params=$(concat_comma_string "${str_params}" "RetainData = $retaindata")
			elif [ "${key}" = "envvar" ]; then
				value=$(value_or_default "${value_missing}" "${DEFAULT_ENVVAR}" "${value}")
				str_params=$(concat_comma_string "${str_params}" "EnvVariable = ${value}")
			elif [ "${key}" = "userroles" ]; then
				value=$(value_or_default "${value_missing}" "" "${value}")
				str_params=$(concat_comma_string "${str_params}" "RequiredUserRoles = \"${value}\"")
			elif [ "${key}" = "debugargs" ]; then
				debugargs=$(value_or_default "${value_missing}" "1" "${value}")
			else
				if [ ${debugargs} -ne 0 ]; then
					echo "Unknown argument: ${key}=${value}"
				fi
			fi
			;;
		*)
			if [ ${debugargs} -ne 0 ]; then
				echo "Unknown argument: ${key}"
			fi
			shift
			;;
		esac
	done

	if [ "${operation}" = "install" ]; then
		${CLI_JSON} "SoftwareModules.InstallDU($str_params)"
	elif [ "${operation}" = "update" ]; then
		${CLI_JSON} "SoftwareModules.DeploymentUnit.[ UUID == \"${uuid}\" ].Update($str_params)"
		wait_ctr_down
	fi

	wait_ctr_up $params
}

uninstall_ctr() {
	uuid=""
	while [ $# -gt 0 ]; do
		key="$1"
		value=""
		value_missing=false
		case $key in
		--*) # If argument starts with "--"
			key="${key#--}"
			shift
			if [ $# -gt 0 ] && case "$1" in --*) false ;; *) true ;; esac then
				value="$1"
				shift
			elif [ $# -eq 0 ] || case "$1" in --*) true ;; *) false ;; esac then
				value_missing=true
			fi

			if [ "${key}" = "uuid" ]; then
				uuid=$(value_or_default "${value_missing}" "${DEFAULT_UUID}" "${value}")
			elif [ "${key}" = "retaindata" ]; then
				retaindata=$(value_or_default "${value_missing}" "${DEFAULT_RETAINDATA}" "${value}")
			else
				echo "Unknown argument: $key=${value}"
			fi
			;;
		*)
			echo "Unknown argument: $1"
			shift
			;;
		esac
	done

	if [ -z "${uuid}" ]; then
		echo "Missing UUID paramter: Uninstall not possible"
	else
		${CLI} "SoftwareModules.DeploymentUnit.[ UUID == \"${uuid}\" ].Uninstall(RetainData = ${retaindata})"
	fi

}

uninstall_ctr_and_check() {
	save_params="$*"
	uuid=""
	while [ $# -gt 0 ]; do
		key="$1"
		value=""
		value_missing=false
		case $key in
		--*) # If argument starts with "--"
			key="${key#--}"
			shift
			if [ $# -gt 0 ] && case "$1" in --*) false ;; *) true ;; esac then
				value="$1"
				shift
			elif [ $# -eq 0 ] || case "$1" in --*) true ;; *) false ;; esac then
				value_missing=true
			fi

			if [ "${key}" = "uuid" ]; then
				uuid=$(value_or_default "${value_missing}" "${DEFAULT_UUID}" "${value}")
			elif [ "${key}" = "retaindata" ]; then
				retaindata=$(value_or_default "${value_missing}" "${DEFAULT_RETAINDATA}" "${value}")
			else
				echo "Unknown argument: $key=${value}"
			fi
			;;
		*)
			echo "Unknown argument: $1"
			shift
			;;
		esac
	done

	if [ -z "${uuid}" ]; then
		echo "Missing UUID parameter. Cannot uninstall ctr"
	else
		duid=$(${CLI_JSON} "SoftwareModules.DeploymentUnit.[ UUID == \"${uuid}\" ].DUID?" | jsonfilter -e @[*].*.DUID)

		# uninstall the container and then check that both the DU and EU instances are gone
		# shellcheck disable=SC2086
		uninstall_ctr ${save_params} >>/dev/null
		wait_ctr_down
		${CLI_JSON} "SoftwareModules.DeploymentUnit.[ DUID == \"$duid\" ].?0" | jsonfilter -e @[*].*.UUID &&
			${CLI_JSON} "SoftwareModules.ExecutionUnit.[ EUID == \"$duid\" ].?0" | jsonfilter -e @[*].*.EUID &&
			${CLI_JSON} "Rlyeh.Images.[ DUID == \"$duid\" ].?0" | jsonfilter -e @[*].*.DUID
	fi
}

ctr_set_requested_state() {
	uuid=""
	requestedstate=""
	debugargs=0

	while [ $# -gt 0 ]; do
		key="$1"
		value=""
		value_missing=false
		case $key in
		--*) # If argument starts with "--"
			key="${key#--}"
			shift
			if [ $# -gt 0 ] && case "$1" in --*) false ;; *) true ;; esac then
				value="$1"
				shift
			elif [ $# -eq 0 ] || case "$1" in --*) true ;; *) false ;; esac then
				value_missing=true
			fi

			if [ "${key}" = "uuid" ]; then
				uuid=$(value_or_default "${value_missing}" "${DEFAULT_UUID}" "${value}")
			elif [ "${key}" = "requestedstate" ]; then
				requestedstate=$(value_or_default "${value_missing}" "Active" "${value}")
			elif [ "${key}" = "debugargs" ]; then
				debugargs=$(value_or_default "${value_missing}" "1" "${value}")
			else
				if [ ${debugargs} -ne 0 ]; then
					echo "Unknown argument: ${key}=${value}"
				fi
			fi
			;;
		*)
			if [ ${debugargs} -ne 0 ]; then
				echo "Unknown argument: ${key}"
			fi
			shift
			;;
		esac
	done

	if [ -z "${uuid}" ]; then
		echo "Missing UUID parameter. Cannot set requested state"
	elif [ -z "${requestedstate}" ]; then
		echo "Missing requestedstate parameter. Cannot set requested state"
	else
		duid=$(${CLI_JSON} "SoftwareModules.DeploymentUnit.[ UUID == \"${uuid}\" ].DUID?" | jsonfilter -e @[*].*.DUID)
		${CLI_JSON} "SoftwareModules.ExecutionUnit.[ EUID == \"${duid}\" ].SetRequestedState(RequestedState = \"${requestedstate}\")"
	fi
}

stop_ctr() {
	ctr_set_requested_state $@ --requestedstate "Idle"
	wait_ctr_down
}

start_ctr() {
	ctr_set_requested_state $@ --requestedstate "Active"
	wait_ctr_up $@
}

## returns container status, version and name
get_container_info() {
	uuid=""
	while [ $# -gt 0 ]; do
		key="$1"
		value=""
		value_missing=false
		case $key in
		--*) # If argument starts with "--"
			key="${key#--}"
			shift
			if [ $# -gt 0 ] && case "$1" in --*) false ;; *) true ;; esac then
				value="$1"
				shift
			elif [ $# -eq 0 ] || case "$1" in --*) true ;; *) false ;; esac then
				value_missing=true
			fi

			if [ "${key}" = "uuid" ]; then
				uuid=$(value_or_default "${value_missing}" "${DEFAULT_UUID}" "${value}")
			else
				echo "Unknown argument: $key=${value}"
			fi
			;;
		*)
			echo "Unknown argument: $1"
			shift
			;;
		esac
	done

	if [ -z "${uuid}" ]; then
		echo "Missing UUID parameter: Cannot get info"
	else
		duid=$(${CLI_JSON} "SoftwareModules.DeploymentUnit.[ UUID == \"${uuid}\" ].DUID?" | jsonfilter -e @[*].*.DUID)
		${CLI_JSON} "SoftwareModules.ExecutionUnit.[ EUID == \"${duid}\" ].?0" | jsonfilter -e @[*].*.Status -e @[*].*.Version | sort
		${CLI_JSON} "SoftwareModules.DeploymentUnit.[ UUID == \"${uuid}\"].Name?0" | jsonfilter -e @[*].*.Name
	fi
}

#returns the parameter of a container
get_container_parameter() {
	uuid=""
	param=""
	while [ $# -gt 0 ]; do
		key="$1"
		value=""
		value_missing=false
		case $key in
		--*) # If argument starts with "--"
			key="${key#--}"
			shift
			if [ $# -gt 0 ] && case "$1" in --*) false ;; *) true ;; esac then
				value="$1"
				shift
			elif [ $# -eq 0 ] || case "$1" in --*) true ;; *) false ;; esac then
				value_missing=true
			fi
			if [ "${key}" = "uuid" ]; then
				uuid=$(value_or_default "${value_missing}" "${DEFAULT_UUID}" "${value}")
			elif [ "${key}" = "param" ]; then
				param=$(value_or_default "${value_missing}" "" "${value}")
			else
				echo "Unknown argument: $key=${value}"
			fi
			;;
		*)
			echo "Unknown argument: $1"
			shift
			;;
		esac
	done

	if [ -z "${uuid}" ]; then
		echo "Missing UUID parameter: Cannot get info"
	elif [ -z "${param}" ]; then
		echo "Missing parameter: Cannot get info"
	else
		duid=$(${CLI_JSON} "SoftwareModules.DeploymentUnit.[ UUID == \"${uuid}\" ].DUID?" | jsonfilter -e @[*].*.DUID)
		${CLI_JSON} "SoftwareModules.ExecutionUnit.[ EUID == \"${duid}\" ].?0" | jsonfilter -e @[*].*.${param} | sort
	fi
}

set_ee_roles() {
	roles=""
	userroles=""
	ee=${DEFAULT_EE}

	while [ $# -gt 0 ]; do
		key="$1"
		value=""
		value_missing=false
		case $key in
		--*) # If argument starts with "--"
			key="${key#--}"
			shift
			if [ $# -gt 0 ] && case "$1" in --*) false ;; *) true ;; esac then
				value="$1"
				shift
			elif [ $# -eq 0 ] || case "$1" in --*) true ;; *) false ;; esac then
				value_missing=true
			fi

			if [ "${key}" = "roles" ]; then
				roles=$(value_or_default "${value_missing}" "" "${value}")
			elif [ "${key}" = "userroles" ]; then
				userroles=$(value_or_default "${value_missing}" "" "${value}")
			elif [ "${key}" = "ee" ]; then
				ee=$(value_or_default "${value_missing}" "${DEFAULT_EE}" "${value}")
			else
				echo "Unknown argument: ${key}=${value}"
			fi
			;;
		*)
			echo "Unknown argument: $1"
			shift
			;;
		esac
	done

	## Roles list can be empty
	${CLI_JSON} "SoftwareModules.ExecEnv.[ Name == \"${ee}\" ].ModifyAvailableRoles(AvailableRoles = \"${roles}\", AvailableUserRoles = \"${userroles}\")"
}

check_available_roles() {
	roles=""
	ee=${DEFAULT_EE}

	while [ $# -gt 0 ]; do
		key="$1"
		value=""
		value_missing=false

		case $key in
		--*) # If argument starts with "--"
			key="${key#--}"
			shift
			if [ $# -gt 0 ] && case "$1" in --*) false ;; *) true ;; esac then
				value="$1"
				shift
			elif [ $# -eq 0 ] || case "$1" in --*) true ;; *) false ;; esac then
				value_missing=true
			fi

			if [ "${key}" = "ee" ]; then
				ee=$(value_or_default "${value_missing}" "${DEFAULT_EE}" "${value}")
			else
				echo "Unknown argument: ${key}=${value}"
			fi
			;;
		*)
			echo "Unknown argument: $1"
			shift
			;;
		esac
	done

	if [ -z "$ee" ]; then
		echo "Missing EE parameter."
	else
		${CLI_JSON} "SoftwareModules.ExecEnv.[ Name == \"${ee}\" ].AvailableRoles?" | jsonfilter -e @[*].*.AvailableRoles
	fi
}

check_available_user_roles() {
	roles=""
	ee=${DEFAULT_EE}

	while [ $# -gt 0 ]; do
		key="$1"
		value=""
		value_missing=false

		case $key in
		--*) # If argument starts with "--"
			key="${key#--}"
			shift
			if [ $# -gt 0 ] && case "$1" in --*) false ;; *) true ;; esac then
				value="$1"
				shift
			elif [ $# -eq 0 ] || case "$1" in --*) true ;; *) false ;; esac then
				value_missing=true
			fi

			if [ "${key}" = "ee" ]; then
				ee=$(value_or_default "${value_missing}" "${DEFAULT_EE}" "${value}")
			else
				echo "Unknown argument: ${key}=${value}"
			fi
			;;
		*)
			echo "Unknown argument: $1"
			shift
			;;
		esac
	done

	if [ -z "$ee" ]; then
		echo "Missing EE parameter."
	else
		${CLI_JSON} "SoftwareModules.ExecEnv.[ Name == \"${ee}\" ].AvailableUserRoles?" | jsonfilter -e @[*].*.AvailableUserRoles
	fi
}

execute_in_container() {
	uuid=""
	cmd=""

	while [ $# -gt 0 ]; do
		key="$1"
		value=""
		value_missing=false
		case $key in
		--*) # If argument starts with "--"
			key="${key#--}"
			shift
			if [ $# -gt 0 ] && case "$1" in --*) false ;; *) true ;; esac then
				value="$1"
				shift
			elif [ $# -eq 0 ] || case "$1" in --*) true ;; *) false ;; esac then
				value_missing=true
			fi

			if [ "${key}" = "uuid" ]; then
				uuid=$(value_or_default "${value_missing}" "${DEFAULT_UUID}" "${value}")
			elif [ "${key}" = "cmd" ]; then
				cmd="${value}"
			else
				echo "Unknown argument: $key=${value}"
			fi
			;;
		*)
			echo "Unknown argument: $1"
			shift
			;;
		esac
	done

	if [ -z "${uuid}" ]; then
		echo "Missing UUID parameter."
	else
		duid=$(${CLI_JSON} "SoftwareModules.DeploymentUnit.[ UUID == \"${uuid}\" ].DUID?" | jsonfilter -e @[*].*.DUID)
		lxc-attach "${duid}" -- sh -c "${cmd}"
	fi

}

check_ee_status() {
	ee=""
	while [ $# -gt 0 ]; do
		key="$1"
		value=""
		ee=${DEFAULT_EE}
		value_missing=false
		case $key in
		--*) # If argument starts with "--"
			key="${key#--}"
			shift
			if [ $# -gt 0 ] && case "$1" in --*) false ;; *) true ;; esac then
				value="$1"
				shift
			elif [ $# -eq 0 ] || case "$1" in --*) true ;; *) false ;; esac then
				value_missing=true
			fi

			if [ "${key}" = "ee" ]; then
				ee=$(value_or_default "${value_missing}" "${DEFAULT_EE}" "${value}")
			else
				echo "Unknown argument: ${key}=${value}"
			fi
			;;
		*)
			echo "Unknown argument: $1"
			shift
			;;
		esac
	done

	if [ -z "${ee}" ]; then
		echo "Missing EE parameter."
	else
		${CLI_JSON} "SoftwareModules.ExecEnv.[ Name == \"${ee}\" ].?0" | jsonfilter -e @[*].*.Status -e @[*].*.Enable | sort
	fi
}

check_cthulhu_config() {
	${CLI_JSON} "Cthulhu.Config.?0" | jsonfilter -e @[*].*.UseOverlayFS -e @[*].*.DefaultBackend -e @[*].*.ImageLocation | sort
}

get_ctr_ip() {
	uuid=""
	while [ $# -gt 0 ]; do
		key="$1"
		value=""
		value_missing=false
		case $key in
		--*) # If argument starts with "--"
			key="${key#--}"
			shift
			if [ $# -gt 0 ] && case "$1" in --*) false ;; *) true ;; esac then
				value="$1"
				shift
			elif [ $# -eq 0 ] || case "$1" in --*) true ;; *) false ;; esac then
				value_missing=true
			fi

			if [ "${key}" = "uuid" ]; then
				uuid=$(value_or_default "${value_missing}" "${DEFAULT_UUID}" "${value}")
			else
				echo "Unknown argument: $key=${value}"
			fi
			;;
		*)
			echo "Unknown argument: $1"
			shift
			;;
		esac
	done

	if [ -z "${uuid}" ]; then
		echo "Missing UUID parameter: Cannot retrieve IP"
	else
		${CLI_JSON} "Cthulhu.Container.Instances.[ LinkedUUID == \"${uuid}\" ].Interfaces.[Name == \"lcm0\"].Addresses.1.?" | jsonfilter -e @[*].*.Address
	fi
}

get_ctr_type() {
	uuid=""
	while [ $# -gt 0 ]; do
		key="$1"
		value=""
		value_missing=false
		case $key in
		--*) # If argument starts with "--"
			key="${key#--}"
			shift
			if [ $# -gt 0 ] && case "$1" in --*) false ;; *) true ;; esac then
				value="$1"
				shift
			elif [ $# -eq 0 ] || case "$1" in --*) true ;; *) false ;; esac then
				value_missing=true
			fi

			if [ "${key}" = "uuid" ]; then
				uuid=$(value_or_default "${value_missing}" "${DEFAULT_UUID}" "${value}")
			else
				echo "Unknown argument: $key=${value}"
			fi
			;;
		*)
			echo "Unknown argument: $1"
			shift
			;;
		esac
	done

	if [ -z "${uuid}" ]; then
		echo "Missing UUID parameter: Cannot retrieve IP"
	else
		duid=$(${CLI_JSON} "SoftwareModules.DeploymentUnit.[ UUID == \"${uuid}\" ].DUID?" | jsonfilter -e @[*].*.DUID)
		uid=$(${CLI_JSON} "SoftwareModules.ExecutionUnit.[ EUID == \"${duid}\" ].?0" | jsonfilter -e @[*].*.AllocatedHostUID)
		gid=$(${CLI_JSON} "SoftwareModules.ExecutionUnit.[ EUID == \"${duid}\" ].?0" | jsonfilter -e @[*].*.AllocatedHostGID)

		if [ "${uid}" -ne 0 ] && [ "${gid}" -ne 0 ]; then
			echo "Unprivileged container"
		elif [ "${uid}" -eq 0 ] && [ "${gid}" -eq 0 ]; then
			echo "Privileged container"
		else
			echo "Unknown container"
		fi
	fi

}

install_ctr() {
	install_update_ctr_with_params install "$@"
}

update_ctr() {
	install_update_ctr_with_params update "$@"
}

## Create the host object resources used for the default HostObject config
setup_hostobjects() {
	mkdir /tmp/testdir
	echo 'test sharing a dir' >/tmp/testdir/testfile
	echo 'test sharing file' >/tmp/testfile

	chmod -R 777 /tmp/testdir
	chmod -R 777 /tmp/testfile
}

cleanup_hostobjects() {
	rm -rf /tmp/testdir
	rm -f /tmp/testfile
}

get_hostobjects() {
	execute_in_container --uuid --cmd "ls -R /testdir/"
	execute_in_container --uuid --cmd "cat /testfile"
	execute_in_container --uuid --cmd "ls /dev/host_serial"
}

add_user_role() {
	rolename=""
	capabilities=""
	while [ $# -gt 0 ]; do
		key="$1"
		value=""
		value_missing=false
		case $key in
		--*) # If argument starts with "--"
			key="${key#--}"
			shift
			if [ $# -gt 0 ] && case "$1" in --*) false ;; *) true ;; esac then
				value="$1"
				shift
			elif [ $# -eq 0 ] || case "$1" in --*) true ;; *) false ;; esac then
				value_missing=true
			fi

			if [ "${key}" = "rolename" ]; then
				rolename=${value}
			elif [ "${key}" = "capabilities" ]; then
				capabilities=${value}
			else
				echo "Unknown argument: $key=${value}"
			fi
			;;
		*)
			echo "Unknown argument: $1"
			shift
			;;
		esac
	done

	if [ -z "${rolename}" ]; then
		echo "Missing rolename parameter"
		return 1
	elif [ -z "${capabilities}" ]; then
		echo "Missing capabilities parameter"
		return 1
	fi
	${CLI_JSON} "Device.Users.Role.+{Alias=\"${rolename}\", Enable=1, RoleName=\"${rolename}\", RequiredCapabilities=\"${capabilities}\"}"
}

remove_user_role() {
	rolename=""
	capabilities=""
	while [ $# -gt 0 ]; do
		key="$1"
		value=""
		value_missing=false
		case $key in
		--*) # If argument starts with "--"
			key="${key#--}"
			shift
			if [ $# -gt 0 ] && case "$1" in --*) false ;; *) true ;; esac then
				value="$1"
				shift
			elif [ $# -eq 0 ] || case "$1" in --*) true ;; *) false ;; esac then
				value_missing=true
			fi

			if [ "${key}" = "rolename" ]; then
				rolename=${value}
			else
				echo "Unknown argument: $key=${value}"
			fi
			;;
		*)
			echo "Unknown argument: $1"
			shift
			;;
		esac
	done

	if [ -z "${rolename}" ]; then
		echo "Missing rolename parameter"
		return 1
	fi
	${CLI_JSON} "Device.Users.Role.[Alias==\"${rolename}\"].-"
}

## It simulates a firmware upgrade by stopping and starting the LCM Agent, as
## well as manually removing critical configurations.
fake_fw_upgrade() {
    duid=$(${CLI_JSON} "SoftwareModules.DeploymentUnit.[ UUID == \"${DEFAULT_UUID}\" ].DUID?" | jsonfilter -e @[*].*.DUID)
    service cthulhu stop
    service rlyeh stop
    service timingila stop

    # reset the import status for PCM; otherwise, it won't send import data for the Cthulhu registration
    ba-cli 'PersistentConfiguration.Service.cthulhu_Cthulhu.ImportStatus=None' > /dev/null
    rm -rf /etc/config/cthulhu /etc/config/lxc/"${duid}"

    service rlyeh start
    service cthulhu start
    service timingila start

    sleep 30
    wait_ctr_up --uuid "${DEFAULT_UUID}"
}
