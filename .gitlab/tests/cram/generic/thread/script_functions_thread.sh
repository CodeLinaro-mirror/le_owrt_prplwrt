#!/bin/sh

DEFAULT_UUID="00000000-0000-5000-b000-000000012345"
DEFAULT_EE="generic"
DEFAULT_NETWORK='{ShareParentNetwork = true}'
DEFAULT_USPROLE='Full Access'
BASE_URL="docker://registry.gitlab.com/prpl-foundation/prplos/prplos/prplos"

DEFAULT_ENVVAR='[{Key="CPCDCONFIG", Value="uart_device_baud=115200"}]'
DEFAULT_HOSTOBJECT='[{Source="",Destination="/dev/ttyThread",Options="type=device,devicetype=c,major=244,minor=1,access=rwm,create=1"},{Source="",Destination="/dev/net/tun",Options="type=device,devicetype=c,major=10,minor=200,access=rwm,create=1"}]'

MAX_WAIT_CTR_UP=60

CLI_JSON="ba-cli -l -j"
CLI="ba-cli"

USP_CMD_GET="obuspa -c get"
USP_CMD_OPERATE="obuspa -c operate"
USP_CMD_SET="obuspa -c set"

## Return default container url based on the target 
## Only supported for Freedom and OSPv2
get_container_url(){
    board_name=$(cat /tmp/sysinfo/board_name | cut -d ',' -f 2)
    if [ "${board_name}" = "freedom" ]; then 
        echo "${BASE_URL}/thread-cpc-arm"
    elif [ "${board_name}" = "lgm" ]; then
        echo "${BASE_URL}/thread-prpl-x86"
    fi
}

get_envvar_by_target() {
    board_name=$(cat /tmp/sysinfo/board_name | cut -d ',' -f 2)
    if [ "${board_name}" = "freedom" ]; then 
        echo '[{Key="CPCDCONFIG",Value="uart_device_baud=115200"}]'
    elif [ "${board_name}" = "lgm" ]; then
        echo '[{Key="CPCDCONFIG",Value="uart_device_baud=460800"}]'
    fi
}

get_hostobject_by_target() {
    board_name=$(cat /tmp/sysinfo/board_name | cut -d ',' -f 2)
    if [ "${board_name}" = "freedom" ]; then 
        echo '[{Source="",Destination="/dev/ttyThread",Options="type=device,devicetype=c,major=244,minor=1,access=rwm,create=1"},{Source="",Destination="/dev/net/tun",Options="type=device,devicetype=c,major=10,minor=200,access=rwm,create=1"}]'
    elif [ "${board_name}" = "lgm" ]; then
        echo '[{Source="",Destination="/dev/ttyThread",Options="type=device,devicetype=c,major=250,minor=1,access=rwm,create=1"},{Source="",Destination="/dev/net/tun",Options="type=device,devicetype=c,major=10,minor=200,access=rwm,create=1"}]'
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

install_thread_ctr() {

    ${CLI} "Device.SoftwareModules.ExecEnv.[Name == \"generic\"].ModifyAvailableRoles(AvailableRoles = \"Full Access\")"

    url=$(get_container_url)
    if [ -n ${url} ]; then
        hostobject=$(get_hostobject_by_target)
        envvar=$(get_envvar_by_target)
        if [ -z ${hostobject} ]; then hostobject=${DEFAULT_HOSTOBJECT}; fi
        if [ -z ${envvar} ]; then envvar=${DEFAULT_ENVVAR}; fi

        str_params=""
        str_params=$(concat_comma_string "${str_params}" "URL = \"${url}\"")
        str_params=$(concat_comma_string "${str_params}" "UUID = \"${DEFAULT_UUID}\"")
        str_params=$(concat_comma_string "${str_params}" "ExecutionEnvRef = \"${DEFAULT_EE}\"")
        str_params=$(concat_comma_string "${str_params}" "NetworkConfig = ${DEFAULT_NETWORK}")
        str_params=$(concat_comma_string "${str_params}" "RequiredRoles = \"${DEFAULT_USPROLE}\"")
        str_params=$(concat_comma_string "${str_params}" "EnvVariable = ${envvar}")
        str_params=$(concat_comma_string "${str_params}" "HostObject = ${hostobject}")
        str_params=$(concat_comma_string "${str_params}" "Privileged = true")

        ${CLI} "Device.SoftwareModules.InstallDU($str_params)" > /dev/null

        wait_ctr_up
    else
        echo "No URL found. Installation not possible"
    fi
}


wait_ctr_up(){
    uuid="${DEFAULT_UUID}"

    duid=$(${CLI_JSON} "SoftwareModules.DeploymentUnit.[ UUID == \"${uuid}\" ].DUID?" | jsonfilter -e @[*].*.DUID)
    if [ -z "${duid}" ]; then
        echo "Container with UUID=${uuid} is not found"
        return
    fi
    i=0
    while [ $i -le ${MAX_WAIT_CTR_UP} ]; do
        status=$(${CLI_JSON} "SoftwareModules.ExecutionUnit.[ EUID == \"${duid}\" ].Status?" | jsonfilter -e @[*].*.Status)
        if [ "${status}" != "Active" ]; then
            i=$((i+2))
            sleep 2
        else
            break
        fi
        # timeout
    done
}

## returns container status, version and name
get_container_info(){
    uuid="${DEFAULT_UUID}"

    duid=$(${CLI_JSON} "SoftwareModules.DeploymentUnit.[ UUID == \"${uuid}\" ].DUID?" | jsonfilter -e @[*].*.DUID)
    ${CLI_JSON} "SoftwareModules.ExecutionUnit.[ EUID == \"${duid}\" ].?0" | jsonfilter -e @[*].*.Status -e @[*].*.Version | sort
    ${CLI_JSON} "SoftwareModules.DeploymentUnit.[ UUID == \"${uuid}\"].Name?0" | jsonfilter -e @[*].*.Name
}

wait_thread_up(){
    MAX_WAIT_THREAD_UP=60
    status=$(${USP_CMD_GET} 'Device.Thread.Radio.[Alias == "wpan0"].Status' | awk '{print $3}')
    i=0
    while [ $i -le ${MAX_WAIT_THREAD_UP} ]; do
        status=$(${USP_CMD_GET} 'Device.Thread.Radio.[Alias == "wpan0"].Status' | awk '{print $3}')
        if [ "${status}" != "Up" ]; then
            i=$((i+2))
            sleep 2
        else
            break
        fi
        # timeout
    done

    ## Also wait for the Connected to go up ? This will cause waiting too long (just wait 10s)
    MAX_WAIT_THREAD_CONNECTED=10
    connected=$(${USP_CMD_GET} 'Device.Thread.Node.[Alias == "br1"].Connected' | awk '{print $3}')
    i=0
    while [ $i -le ${MAX_WAIT_THREAD_CONNECTED} ]; do
        connected=$(${USP_CMD_GET} 'Device.Thread.Node.[Alias == "br1"].Connected' | awk '{print $3}')
        if [ "${status}" == 1 ]; then
            i=$((i+2))
            sleep 2
        else
            break
        fi
        # timeout
    done
}

configure_and_check_thread() {
    sleep 10
    ${USP_CMD_OPERATE} 'Device.Thread.MLE.1.setActiveDataset(tlvs = "0e080000000000010000000300000d35060004001fffe0020857e60f9587f16e780708fd19fe5b5c8bd9e20510fceef10a9a30574e5ac33fe2b10df7d9030f4f70656e5468726561642d616262320102abb204107d8ad0115132c56db67e2a8ddb9c3ac30c0402a0f7f8")' > /dev/null
    sleep 5
    ${USP_CMD_SET} Device.Thread.MLE.1.Enable true > /dev/null

    wait_thread_up

    ${USP_CMD_GET} Device.Thread.Radio.1.Status | awk '{print $3}'
    ${USP_CMD_GET} Device.Thread.Radio.1.FirmwareVersion | awk '{print $3}'
}

## waits for a container to go down or timeout
wait_ctr_down(){
    # Read max shutdown delay
    shutdowndelay=$(${CLI_JSON} Cthulhu.Config.GracefulShutdownTimeoutSeconds? | jsonfilter -e @[*].*.GracefulShutdownTimeoutSeconds)
    if [ -z "$shutdowndelay" ]; then
        shutdowndelay=10
    fi

    # Add extra 3 seconds delay
    shutdowndelay=$((shutdowndelay+3)) 

    sleep ${shutdowndelay}
}

uninstall_ctr_and_check() {
    uuid="${DEFAULT_UUID}"
    duid=$(${CLI_JSON} "SoftwareModules.DeploymentUnit.[ UUID == \"${uuid}\" ].DUID?" | jsonfilter -e @[*].*.DUID)

    # uninstall the container and then check that both the DU and EU instances are gone
    ${CLI} "Device.SoftwareModules.DeploymentUnit.[ UUID == \"${uuid}\" ].Uninstall(RetainData = false)" > /dev/null

    wait_ctr_down

    ${CLI_JSON} "SoftwareModules.DeploymentUnit.[ DUID == \"$duid\" ].?0"  | jsonfilter -e @[*].*.UUID \
        && ${CLI_JSON} "SoftwareModules.ExecutionUnit.[ EUID == \"$duid\" ].?0" | jsonfilter -e @[*].*.EUID \
        && ${CLI_JSON} "Rlyeh.Images.[ DUID == \"$duid\" ].?0" | jsonfilter -e @[*].*.DUID 

}
