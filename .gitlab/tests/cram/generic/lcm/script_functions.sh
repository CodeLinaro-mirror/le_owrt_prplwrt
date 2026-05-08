#!/bin/sh

### Default parameters config when value is not provided
DEFAULT_UUID="00000000-0000-5000-b000-000000000001"
DEFAULT_HOSTOBJECT='[{Source="/tmp/testdir", Destination="/testdir", Options="type=mount,bind"}, {Source="/tmp/testfile", Destination="/testfile", Options="type=mount,bind"}, {Source="", Destination="/dev/host_serial", Options="type=device,devicetype=c,major=5,minor=1,access=rwm,create=1"}]'
#DEFAULT_NETWORK='{ShareParentNetwork = "true"}''
DEFAULT_NETWORK='{AccessInterfaces = [{Reference = "Lan"}]}'
DEFAULT_EE="generic"
DEFAULT_APPDATA='[{Name = "Volume1", Capacity = 1, Retain = "UntilStopped", AccessPath = "/volume1"}, {Name = "Volume2", Capacity = 1, Retain = "Forever", AccessPath = "/volume2"}]'
DEFAULT_URL="docker://registry.gitlab.com/prpl-foundation/prplos/prplos"
DEFAULT_URL_HTTPS="https://registry.gitlab.com/prpl-foundation/prplos/prplos"
DEFAULT_USPROLES="Full Access"
DEFAULT_USPREQUIRED="Full Access"
DEFAULT_USPOPTIONAL=""
DEFAULT_USPREGISTERPATHS=""
DEFAULT_USPAUTOMOUNTIPC="USP_UDS_Unauthenticated"
DEFAULT_USERNAME=""
DEFAULT_PASSWORD=""
DEFAULT_RETAINDATA="false"
DEFAULT_ENVVAR='[{Key="ENVVAR_KEY1", Value="ENVVAR_VALUE1"}, {Key="ENVVAR_KEY2", Value="ENVVAR_VALUE2"}]'
DEFAULT_SIGNATURE_PASSWORD="secret"
DEFAULT_SIGNATURE_USERNAME="admin"
DEFAULT_PRIVILEGED="false"
DEFAULT_ENABLEHOSTCAPABILITIES="false"

CLI_JSON="cli_cmd -l -j"
CLI="cli_cmd"

## Wrapper around ba-cli that returns error if second output line starts with 'ERROR:'
## Uses a temp file to preserve ba-cli output exactly (including trailing newlines).
## On success: prints to stdout. On error (second line starts with ERROR:): prints to stderr.
cli_cmd() {
	_cli_tmpfile=$(mktemp /tmp/cli_cmd_XXXXXX)
	ba-cli "$@" >"${_cli_tmpfile}" 2>&1
	_cli_rc=$?
	_cli_second=$(sed -n '2p' "${_cli_tmpfile}")
	case "${_cli_second}" in
		ERROR:*)
			cat "${_cli_tmpfile}" >&2
			rm -f "${_cli_tmpfile}"
			return 1 ;;
		*)
			cat "${_cli_tmpfile}"
			rm -f "${_cli_tmpfile}"
			return ${_cli_rc} ;;
	esac
}

MAX_WAIT_CTR_UP=60

## Return default container name based on target.
## Default is Cortex-A53 based ARM 64-bit container
get_container_name() {
	board_name=$(cut -d',' -f2 </tmp/sysinfo/board_name)
	case "${board_name}" in
	"haze" | \
		"freedom" | \
		"mozart" | \
		"valyrian")
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
                    "freedom" | \
		    "valyrian")
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

get_arch_name() {
	board_name=$(cut -d',' -f2 </tmp/sysinfo/board_name)
	case "${board_name}" in
	"haze" | \
		"freedom" | \
		"valyrian")
		echo arm32v7
		;;
	"lgm" | \
		"qemu-standard-pc-"*)
		echo amd64
		;;
	"turris-omnia")
		echo cortexa9
		;;
	*)
		echo arm32v7
		;;
	esac
}

## FIXME: `get_arch_name` function returns wrong arch name for freedom board
## Return the architecture name for the board, used for selecting the correct container image from registry
get_true_arch_name() {
	board_name=$(cut -d',' -f2 </tmp/sysinfo/board_name)
	case "${board_name}" in
	"haze" | \
		"freedom" | \
		"valyrian")
		echo arm64v8
		;;
	"lgm" | \
		"qemu-standard-pc-"*)
		echo amd64
		;;
	"turris-omnia")
		echo cortexa9
		;;
	*)
		echo arm32v7
		;;
	esac
}

## Return architecture name for the board
get_board_arch() {
	board_name=$(cut -d',' -f2 </tmp/sysinfo/board_name)
	case "${board_name}" in
	"haze" | \
		"freedom" | \
		"mozart" | \
		"valyrian")
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
		duid=$(cli_json_safe "SoftwareModules.DeploymentUnit.[ UUID == \"${uuid}\" ].DUID?" -e @[*].*.DUID 2>/dev/null)
		if [ -z "${duid}" ]; then
			echo "Container with UUID=${uuid} is not found"
			return
		fi
		i=0
		while [ $i -le ${MAX_WAIT_CTR_UP} ]; do
			status=$(cli_json_safe "SoftwareModules.ExecutionUnit.[ EUID == \"${duid}\" ].Status?" -e @[*].*.Status)
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
	shutdowndelay=$(cli_json_safe "Cthulhu.Config.GracefulShutdownTimeoutSeconds?" -e @[*].*.GracefulShutdownTimeoutSeconds)
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


## Start background subscription to DUStateChange! for a given UUID.
## Usage: start_du_state_change_sub <uuid> <lua_script_path>
## Stores PID in _DU_SUB_PID
start_du_state_change_sub() {
	_du_sub_uuid="$1"
	_du_sub_script="/tmp/du_state_change.lua"
	if [ -f "${_du_sub_script}" ]; then
		rm -f /tmp/du_state_change_out.txt
		lua "${_du_sub_script}" "${_du_sub_uuid}" > /tmp/du_state_change_out.txt 2>&1 &
		_DU_SUB_PID=$!
	else
		_DU_SUB_PID=""
	fi
}

## Wait for background DUStateChange! subscription to finish and print any fault output.
## Call after the CLI operation completes.
wait_du_state_change_sub() {
	_du_sub_timeout="${1:-1}"
	if [ -n "${_DU_SUB_PID}" ]; then
		timeout "${_du_sub_timeout}" tail --pid="${_DU_SUB_PID}" -f /dev/null 2>/dev/null; kill "${_DU_SUB_PID}" 2>/dev/null; wait "${_DU_SUB_PID}" 2>/dev/null
		if [ -s /tmp/du_state_change_out.txt ]; then
			cat /tmp/du_state_change_out.txt >&2
		fi
		rm -f /tmp/du_state_change_out.txt
		_DU_SUB_PID=""
	fi
}

install_update_ctr_with_params() {
	params=$@
	operation=$1
	no_wait=$2
	if [ "${operation}" != "install" ] && [ "${operation}" != "update" ]; then
		echo "Unknown operation: $operation"
		return
	fi

	shift
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
			elif [ "${key}" = "url_arch" ]; then
				ctr_arch=$(get_arch_name)
				str_params=$(concat_comma_string "${str_params}" "URL = \"${DEFAULT_URL}/lcm_tests/${ctr_arch}_${value}\"")
			elif [ "${key}" = "version" ]; then
				ctr_name=$(get_container_name)
				ctr_version="${value}"
				str_params=$(concat_comma_string "${str_params}" "URL = \"${DEFAULT_URL}/prplos/${ctr_name}:${ctr_version}\"")
			elif [ "${key}" = "httpsversion" ]; then
				ctr_name=$(get_container_name)
				ctr_version="${value}"
				str_params=$(concat_comma_string "${str_params}" "URL = \"${DEFAULT_URL_HTTPS}/prplos/${ctr_name}:${ctr_version}\"")
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
			elif [ "${key}" = "uspregisterpaths" ]; then
				value=$(value_or_default "${value_missing}" "${DEFAULT_USPREGISTERPATHS}" "${value}")
				str_params=$(concat_comma_string "${str_params}" "RegisterTrustPaths = \"${value}\"")
			elif [ "${key}" = "uspautomountipc" ]; then
				value=$(value_or_default "${value_missing}" "${DEFAULT_USPAUTOMOUNTIPC}" "${value}")
				str_params=$(concat_comma_string "${str_params}" "X_PRPLWARE-COM_AutoMountIPC = \"${value}\"")
			elif [ "${key}" = "username" ]; then
				value=$(value_or_default "${value_missing}" "${DEFAULT_USERNAME}" "${value}")
				str_params=$(concat_comma_string "${str_params}" "Username = \"${value}\"")
			elif [ "${key}" = "password" ]; then
				value=$(value_or_default "${value_missing}" "${DEFAULT_PASSWORD}" "${value}")
				str_params=$(concat_comma_string "${str_params}" "Password = \"${value}\"")
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
			elif [ "${key}" = "moduleversion" ]; then
				str_params=$(concat_comma_string "${str_params}" "ModuleVersion = \"${value}\"")
			elif [ "${key}" = "signature" ]; then
				str_params=$(concat_comma_string "${str_params}" "Signature = \"${value}_${ctr_name}_${ctr_version}\"")
			elif [ "${key}" = "signature_pwd" ]; then
				value=$(value_or_default "${value_missing}" "${DEFAULT_SIGNATURE_PASSWORD}" "${value}")
				str_params=$(concat_comma_string "${str_params}" "SignaturePassword = \"${value}\"")
			elif [ "${key}" = "signature_user" ]; then
				value=$(value_or_default "${value_missing}" "${DEFAULT_SIGNATURE_USERNAME}" "${value}")
				str_params=$(concat_comma_string "${str_params}" "SignatureUsername = \"${value}\"")
			elif [ "${key}" = "enablehostcapabilities" ]; then
				value=$(value_or_default "${value_missing}" "${enablehostcapabilities}" "${value}")
				str_params=$(concat_comma_string "${str_params}" "EnableHostCapabilities = ${value}")
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
		start_du_state_change_sub "${uuid}"
		${CLI_JSON} "SoftwareModules.InstallDU($str_params)"
		wait_du_state_change_sub
	elif [ "${operation}" = "update" ]; then
		start_du_state_change_sub "${uuid}"
		${CLI_JSON} "SoftwareModules.DeploymentUnit.[ UUID == \"${uuid}\" ].Update($str_params)"
		wait_du_state_change_sub
		wait_ctr_down
	fi

	if [ "$no_wait" == "false" ]; then
		wait_ctr_up $params
	fi
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
		start_du_state_change_sub "${uuid}"
		${CLI_JSON} "SoftwareModules.DeploymentUnit.[ UUID == \"${uuid}\" ].Uninstall(RetainData = ${retaindata})"
		wait_du_state_change_sub
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
		duid=$(cli_json_safe "SoftwareModules.DeploymentUnit.[ UUID == \"${uuid}\" ].DUID?" -e @[*].*.DUID)
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
		duid=$(cli_json_safe "SoftwareModules.DeploymentUnit.[ UUID == \"${uuid}\" ].DUID?" -e @[*].*.DUID)
		status=$(cli_json_safe "SoftwareModules.ExecutionUnit.[ EUID == \"${duid}\" ].Status?" -e @[*].*.Status)
		## If requested state is already set, then do nothing
		if [ "${status}" != "${requestedstate}" ]; then
			${CLI_JSON} "SoftwareModules.ExecutionUnit.[ EUID == \"${duid}\" ].SetRequestedState(RequestedState = \"${requestedstate}\")"
		fi
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
		duid=$(cli_json_safe "SoftwareModules.DeploymentUnit.[ UUID == \"${uuid}\" ].DUID?" -e @[*].*.DUID)
		cli_json_safe "SoftwareModules.ExecutionUnit.[ EUID == \"${duid}\" ].?0" -e @[*].*.Status -e @[*].*.Version | sort
		cli_json_safe "SoftwareModules.DeploymentUnit.[ UUID == \"${uuid}\"].Name?0" -e @[*].*.Name
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
		duid=$(cli_json_safe "SoftwareModules.DeploymentUnit.[ UUID == \"${uuid}\" ].DUID?" -e @[*].*.DUID)
		cli_json_safe "SoftwareModules.ExecutionUnit.[ EUID == \"${duid}\" ].?0" -e @[*].*.${param} | sort
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
		cli_json_safe "SoftwareModules.ExecEnv.[ Name == \"${ee}\" ].AvailableRoles?" -e @[*].*.AvailableRoles
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
		cli_json_safe "SoftwareModules.ExecEnv.[ Name == \"${ee}\" ].AvailableUserRoles?" -e @[*].*.AvailableUserRoles
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
		duid=$(cli_json_safe "SoftwareModules.DeploymentUnit.[ UUID == \"${uuid}\" ].DUID?" -e @[*].*.DUID)
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
		cli_json_safe "SoftwareModules.ExecEnv.[ Name == \"${ee}\" ].?0" -e @[*].*.Status -e @[*].*.Enable | sort
	fi
}

check_cthulhu_config() {
	cli_json_safe "Cthulhu.Config.?0" -e @[*].*.UseOverlayFS -e @[*].*.DefaultBackend -e @[*].*.ImageLocation| sort
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
		cli_json_safe "Cthulhu.Container.Instances.[ LinkedUUID == \"${uuid}\" ].Interfaces.[Name == \"lcm0\"].Addresses.1.?" -e @[*].*.Address
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
		duid=$(cli_json_safe "SoftwareModules.DeploymentUnit.[ UUID == \"${uuid}\" ].DUID?" -e @[*].*.DUID)
		uid=$(cli_json_safe "SoftwareModules.ExecutionUnit.[ EUID == \"${duid}\" ].?0" -e @[*].*.AllocatedHostUID)
		gid=$(cli_json_safe "SoftwareModules.ExecutionUnit.[ EUID == \"${duid}\" ].?0" -e @[*].*.AllocatedHostGID)
		if [ "${uid}" -ne 0 ] && [ "${gid}" -ne 0 ]; then
			echo "Unprivileged container"
		elif [ "${uid}" -eq 0 ] && [ "${gid}" -eq 0 ]; then
			echo "Privileged container"
		else
			echo "Unknown container"
		fi
	fi

}

install_ctr_no_wait() {
	install_update_ctr_with_params install true "$@"
}

install_ctr() {
	install_update_ctr_with_params install false "$@"
}

update_ctr() {
	install_update_ctr_with_params update false "$@"
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
    duid=$(cli_json_safe "SoftwareModules.DeploymentUnit.[ UUID == \"${DEFAULT_UUID}\" ].DUID?" -e @[*].*.DUID)
    uuid=$(cli_json_safe "SoftwareModules.DeploymentUnit.[ UUID == \"${DEFAULT_UUID}\" ].UUID?" -e @[*].*.UUID)
    ## Stop the active container to allow stopping cthulhu without any problem
    stop_ctr --uuid "${uuid}" >> /dev/null

    service cthulhu stop
    service rlyeh stop
    service timingila stop

    rm -rf /etc/config/cthulhu /etc/config/lxc/"${duid}"

    service rlyeh start
    service cthulhu start
    sleep 2
    service timingila start

    sleep 5
    start_ctr --uuid "${uuid}" >> /dev/null
}

get_vendorlogfile_name() {
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
		echo "Missing UUID parameter"
	else
		VendorLogFileRef=$(get_container_parameter --uuid ${uuid} --param VendorLogList)
		cli_json_safe "${VendorLogFileRef}.?" -e @[*].*.Name
	fi
}

get_vendorlogfile_content() {
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
		echo "Missing UUID parameter"
	else
		VendorLogFileRef=$(get_container_parameter --uuid ${uuid} --param VendorLogList)
		file=$(cli_json_safe "${VendorLogFileRef}.Name?" -e @[*].*.Name)
		echo ${file}
		file_wo_prefix="${file:7}"
		cat ${file_wo_prefix} | grep "test-C"
	fi
}

add_containers_descriptors() {
	DEFAULT_PATH="/lcm/rlyeh/images/prpl-foundation/prplos/prplos"
	ctr_name1="3_16_alpine_copy"
	ctr_arch=$(get_arch_name)
	DISK_LOCATION1="${DEFAULT_PATH}/lcm_tests/${ctr_arch}_${ctr_name1}"

	ctr_name2=$(get_container_name)
	DISK_LOCATION2="${DEFAULT_PATH}/prplos/${ctr_name2}"

	echo "
        {
          \"Bundle\": \"arm32v7/alpine\",
          \"Autostart\": 1,
          \"DiskLocation\": \"${DISK_LOCATION1}\",
          \"LinkedUUID\": \"00000000-0000-5000-b000-000000000001\",
          \"BundleVersion\": \"latest\",
          \"ModuleVersion\": \"3.16.1\",
          \"Description\": \"\",
          \"ContainerId\": \"917362a3-86e8-5332-bcfd-a4223f0e65e6\",
          \"Sandbox\": \"generic\",
          \"Privileged\": 1,
          \"EnvVariable\": [
            {\"Key\": \"EnvVar1\", \"Value\": \"MOD_VarValue1\"},
            {\"Key\": \"EnvVar2\", \"Value\": \"MOD_VarValue2\"}
          ]
        }" > /etc/amx/cthulhu/onboard/917362a3-86e8-5332-bcfd-a4223f0e65e6.json

        echo "
        {
          \"Bundle\": \"prpl-foundation/prplos/prplos/prplos/lcm-test-ipq807x-generic\",
          \"Autostart\": 1,
          \"DiskLocation\": \"${DISK_LOCATION2}\",
          \"LinkedUUID\": \"00000000-0000-5000-b000-000000000006\",
          \"BundleVersion\": \"prplos-v2\",
          \"ModuleVersion\": \"2.0.0\",
          \"Description\": \"\",
          \"ContainerId\": \"70a9bf70-9df9-5221-b51b-184c74d022e3\",
          \"AllocatedCPUPercent\": 50,
          \"Sandbox\": \"generic\",
          \"Privileged\": 1
        }" > /etc/amx/cthulhu/onboard/70a9bf70-9df9-5221-b51b-184c74d022e3.json
}

cleanup_pcm_test() {
	remove_user_role --rolename full_caps > /dev/null
	set_ee_roles > /dev/null
	result=$(check_available_user_roles)
	if [ "${result}" != "" ]; then 
		echo "error"
	fi
	cleanup_hostobjects
	echo "Done"
}

cleanup_appdata() {
	umount /lcm/cthulhu/data/mounts/generic > /dev/null 2>&1
	umount /lcm/cthulhu/data/mounts/generic/applicationdata/mounts/00000000-0000-5000-b000-000000000001/Volume1 > /dev/null 2>&1
	umount /lcm/cthulhu/data/mounts/generic/applicationdata/mounts/00000000-0000-5000-b000-000000000001/Volume2 > /dev/null 2>&1
	rm -rf /lcm/cthulhu/data/mounts/generic/applicationdata
	service cthulhu stop > /dev/null 2>&1
	while [ -n "$(pidof cthulhu)" ]; do sleep 1; done; sleep 10
	rm -rf /etc/config/cthulhu/* > /dev/null 2>&1
	service cthulhu start > /dev/null
	sleep 2
	service timingila restart > /dev/null
}

##
## install_basic_container() - Install a container with default parameters and wait for it to become active.
##
## Fixed defaults applied by this function:
##   --version prplos-v1   : Container image version to install.
##   --ee                  : Execution environment (defaults to DEFAULT_EE = "generic" if not overridden).
##   --uuid                : Deployment unit UUID (defaults to DEFAULT_UUID if not overridden).
##   --privileged true     : Container is started in privileged mode.
##
## Parameters:
##   "$@"  : Optional extra arguments forwarded verbatim to install_ctr.
##           Any supported install_ctr argument (--url, --network, --hostobject,
##           --appdata, --envvar, --retaindata, --usprequired, etc.) can be supplied
##           here to override the defaults above.
##
## Example:
##   install_basic_container
##   install_basic_container --envvar --network '{ShareParentNetwork = "true"}'
##
install_basic_container() {
	install_ctr --version prplos-v1 --ee --uuid --privileged true "$@" > /dev/null
}

##
## install_basic_container_no_wait() - Install a container with default parameters without waiting for it to become active.
##
## Fixed defaults applied by this function:
##   --version prplos-v1   : Container image version to install.
##   --ee                  : Execution environment (defaults to DEFAULT_EE = "generic" if not overridden).
##   --uuid                : Deployment unit UUID (defaults to DEFAULT_UUID if not overridden).
##   --privileged true     : Container is started in privileged mode.
##
## Parameters:
##   "$@"  : Optional extra arguments forwarded verbatim to install_ctr_no_wait.
##           Any supported install_ctr argument (--url, --network, --hostobject,
##           --appdata, --envvar, --retaindata, --usprequired, etc.) can be supplied
##           here to override the defaults above.
##
## Example:
##   install_basic_container_no_wait
##   install_basic_container_no_wait --envvar
##
install_basic_container_no_wait() {
	install_ctr_no_wait --version prplos-v1 --ee --uuid --privileged true "$@"
}

normalize_dump(){
    ## Generic substitution of any instantionated subtree
    sed -i -e "s/\(\.Instances\)\.[[:digit:]]/\1\.{i}/g" $1

    ## Softwware modules specific cases
    sed -i -e "s/\(SoftwareModules\.ExecEnv\)\.[[:digit:]]/\1\.{i}/g" $1
    sed -i -e "s/\(SoftwareModules\.ExecutionUnit\)\.[[:digit:]]/\1\.{i}/g" $1

    ## Cthulhu LocalPolicy spacific case
    sed -i -e "s/\(\.LocalPolicyManager\.Action\)\.[[:digit:]]/\1\.{i}/g" $1
}

cleanup_lpm_test(){

    /etc/init.d/cthulhu stop
    /etc/init.d/rlyeh stop
    /etc/init.d/timingila stop

    ## Wait for cthulhu to terminate all containers and itself, before clearing its data

    COUNT=0; while [ -n "$(pidof cthulhu)" ]; do if [ "$COUNT" -ge 10 ]; then echo "Warning: cthulhu is still running after 10 checks. Exiting."; break; fi; sleep 1; COUNT=$((COUNT + 1)); done

    rm -rf /usr/rlyeh/*
    rm -rf /etc/amx/cthulhu/onboard/*
    rm -rf /etc/config/cthulhu/odl/*

    /etc/init.d/cthulhu start
    /etc/init.d/rlyeh start
    /etc/init.d/timingila start
}

## Wrapper around CLI_JSON that prints descriptive errors on failure.
## Usage: cli_json_safe "ba-cli command" -e @[*].*.Field [-e ...]
## Captures raw output, runs jsonfilter, and on failure prints the command + raw response to stderr.
cli_json_safe() {
    _cli_cmd="$1"
    shift
    _raw=$(ba-cli -l -j "${_cli_cmd}" 2>&1)
    _cli_rc=$?
    _filtered=$(echo "${_raw}" | jsonfilter "$@" 2>&1)
    _jrc=$?
    if [ ${_jrc} -ne 0 ]; then
        echo "json error: ${_cli_cmd} -- $* -- ${_raw}" >&2
        return 1
    fi
    echo "${_filtered}"
    return ${_cli_rc}
}

## Write du_state_change.lua to /tmp/ when this script is sourced
cat > /tmp/du_state_change.lua << 'LUAEOF'
#!/usr/bin/lua

local req_uuid = arg[1]
local lamx = require 'lamx'

lamx.backend.load("/usr/bin/mods/amxb/mod-amxb-ubus.so")
lamx.bus.open("ubus:/var/run/ubus/ubus.sock")

local el = lamx.eventloop.new()

local print_event = function(event, data)
    if event == "DUStateChange!" then
        local d = data and data.data
        if d and (req_uuid == "" or req_uuid == nil or d.UUID == req_uuid) then
            local fault_code = d.Fault and d.Fault.FaultCode or 0
            local fault_str  = d.Fault and d.Fault.FaultString or ""
            local op         = d.OperationPerformed or "Unknown"
            local state      = d.CurrentState or "Unknown"
            if fault_code ~= 0 then
                print("DUStateChange! ERROR: operation=" .. op
                    .. " state=" .. state
                    .. " FaultCode=" .. tostring(fault_code)
                    .. " FaultString=" .. fault_str)
            end
            el:stop()
        end
    end
end

local sub = lamx.bus.subscribe("SoftwareModules.", print_event)

el:start()
LUAEOF
