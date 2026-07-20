#!/bin/sh

# Wrapper around pkcs11-tool that suppresses all stderr output.
# Usage: pkcs11_tool_silent [pkcs11-tool arguments]
pkcs11_tool_silent() {
	pkcs11-tool "$@" 2>/dev/null
}

# Wrapper around softhsm2-util that suppresses all stderr output.
# Usage: softhsm2_util_silent [softhsm2-util arguments]
softhsm2_util_silent() {
	softhsm2-util "$@" 2>/dev/null
}

# Initialises the SoftHSM2 Hardware Security Module (HSM) environment by:
#   - Creating a PKCS#11 token labelled "lcm_token" with PIN 12345
#   - Generating a 2048-bit RSA key pair inside the token
#   - Generating a Certificate Signing Request (CSR) for the client certificate
#     using the OpenSSL PKCS#11 engine, with subject CN=client_cert
# Outputs progress messages for each step (success or failure).
# No arguments required; all configuration values are hardcoded.
configure_hsm() {
	KEY_URI="pkcs11:token=lcm_token;object=key;type=private;pin-value=12345"
	TOKEN_ACCESS="--module /usr/lib/softhsm/libsofthsm2.so --token-label lcm_token --login --pin 12345"
	ROOT_LOCATION="/tmp/lcm_root_ca"
	CLIENT_CERT_NAME="lcm_cert_client"
	CLIENT_CERT_LOCATION="/etc/config/autocert/"

	# Create a token
	softhsm2_util_silent --init-token --free --label "lcm_token" --so-pin=12345 --pin=12345 > /dev/null && \
		echo "Token created" || \
		echo "Token creation failed"


	# Generate a key in the token
	# shellcheck disable=SC2086
	pkcs11_tool_silent ${TOKEN_ACCESS} --keypairgen --key-type rsa:2048 --id 01 --label key >/dev/null && \
	    echo "Private key created" || \
    	echo "Private key creation failed"


	# Generate a CSR 
	openssl req -new -engine pkcs11 -keyform engine -key "${KEY_URI}" -subj "/C=BE/ST=Brabant/L=Wijgmaal/O=SoftAtHome/OU=IT/CN=client_cert" -out "/tmp/${CLIENT_CERT_NAME}.csr" > /dev/null 2>&1
	if [ ! -f /tmp/${CLIENT_CERT_NAME}.csr ]; then
		echo "Failed to generate the CSR"
	else
		echo "CSR generated"
	fi
}

# Configures the security environment for the LCM (Life Cycle Management) stack by:
#   - Stopping and restarting the services: timingila, rlyeh, tr181-security
#   - Installing the software modules ODL config and the GPG public signing key for rlyeh
#   - Linking the client certificate and its PKCS#11 private key URI in the device data model
#     (Device.Security.Certificate) via CLI JSON commands
#   - Appending two signature server hostnames to /etc/hosts for local DNS resolution
# No arguments required; relies on the CLI_JSON environment variable being set.
configure_security() {
	exec >/dev/null 2>&1
	destination="$1"

	/etc/init.d/timingila stop
	/etc/init.d/rlyeh stop
	/etc/init.d/tr181-security stop
	sleep 2
	mv /tmp/softwaremodules_default.odl /etc/config/softwaremodules/odl/timingila.odl
	mkdir -p /usr/share/rlyeh/keys/
	mv /tmp/sign_test_pub.asc /usr/share/rlyeh/keys/

	/etc/init.d/rlyeh start
	/etc/init.d/tr181-security start
	sleep 2
	/etc/init.d/timingila start

	${CLI_JSON} 'Device.Security.Certificate.[CAFileName=="lcm_cert_client.crt"].PrivateKeyURI="pkcs11:token=lcm_token;object=key;type=private;pin-value=12345"'
	${CLI_JSON} 'Device.Security.Certificate.[CAFileName=="lcm_cert_client.crt"].CertificateURI="file:///etc/config/autocert/lcm_cert_client.crt"'


	# Set the defined server names in /etc/hosts
	echo "${destination} signature.server1.local.com" >> /etc/hosts
	echo "${destination} signature.server2.local.com" >> /etc/hosts
}

# Filters and formats a captured USP event from /tmp/captured_event.
# Extracts only the relevant fields: FaultCode, FaultString, CurrentState,
# and OperationPerformed, then sorts them, and strips leading/trailing
# whitespace and trailing commas.
# No arguments required; reads directly from /tmp/captured_event.
filtered_event() {
	grep -E "FaultCode|FaultString|CurrentState|OperationPerformed" /tmp/captured_event | sort | sed 's/^[ \t]*//; s/,$//'
}

# Cleans up (silently) all security-related configuration and generated files by:
#   - Removing previous subscription and used cli
#   - Stopping the timingila and tr181-security services
#   - Removing the client CSR, server CA certificate, client certificate,
#     root CA directory, software modules ODL config, and the CRAM LCM ODL extension
#   - Restarting the timingila and tr181-security services
# No arguments required; all paths are hardcoded.
cleanup_security() {
	exec >/dev/null 2>&1

	configure_datamodel remove_subscription
	rm -rf /etc/amx/cli/usp-test-cli.* /usr/bin/usp-test-cli /tmp/event.lua

	ROOT_LOCATION="/tmp/lcm_root_ca"
	CLIENT_CERT_LOCATION="/etc/config/autocert/"
	CLIENT_CERT_NAME="lcm_cert_client"

	service timingila stop
	service tr181-security stop

	# Remove all config installed or generated
	rm -rf /tmp/"${CLIENT_CERT_NAME}".csr
	rm -rf /usr/share/ca-certificates/server_1.crt
	rm -rf ${CLIENT_CERT_LOCATION}/${CLIENT_CERT_NAME}.crt
	rm -rf ${ROOT_LOCATION}
	rm -rf /etc/config/softwaremodules/odl/timingila.odl
	rm -rf /etc/amx/tr181-security/extensions/01_cram_lcm.odl
	rm -rf /usr/share/ca-certificates/lcm_servers_root_ca1.crt
	rm -rf /usr/share/ca-certificates/ca_bundle.crt

	sed -i '/signature\.server1\.local\.com/d' /etc/hosts
	sed -i '/signature\.server2\.local\.com/d' /etc/hosts

	# Delete the test HSM token
	softhsm2-util --delete-token --token lcm_token

	#rm -f /tmp/script_functions.sh /tmp/security_functions.sh
	service tr181-security start
	service timingila start
}

# Applies a named data model configuration command via usp-test-cli or ubus.
# Accepts a single command name and maps it to the appropriate data model
# parameter, value, and CLI interface. Supported commands:
#   set_http             - Set DU signature protocol to HTTP
#   set_https            - Set DU signature protocol to HTTPS
#   set_useragent        - Set a custom Rlyeh User-Agent string
#   docker_repo_root_ca1 - Assign root_ca1 CA bundle to the docker repository
#   docker_repo_ca_bundle- Assign ca_bundle CA bundle to the docker repository
#   no_client_cert       - Clear the client certificate for the mtls repository
#   set_client_cert      - Assign a client certificate (by serial number) to the mtls repository
#   disable_docker_repo  - Disable the docker repository
#   set_default_ca_wrong - Set an incorrect default CA bundle on SoftwareModules config
#   set_subscription     - Create a DUStateChange event subscription via USP
#   remove_subscription  - Remove the DUStateChange event subscription via USP
# Usage: configure_datamodel <command>
# Returns 1 for unknown commands.
configure_datamodel() {
    cmd="$1"

    # Initialize variables
    param=""
    value=""
    sub=""
    cli=""
    type=""

	case "$cmd" in
		set_subscription|remove_subscription)
			type="sub"
			;;
		*)
			type="set"
			;;
	esac

    # Process commands
    case "$cmd" in
        set_http)
            param='Device.SoftwareModules.Config.DUSignatureProtocols'
            value='HTTP'
            cli='usp'
            ;;
        set_https)
            param='Device.SoftwareModules.Config.DUSignatureProtocols'
            value='HTTPS'
            cli='usp'
            ;;
        set_useragent)
            param='Rlyeh.UserAgent'
            value='my custom User-Agent value'
            cli='ubus'
            ;;
        docker_repo_root_ca1)
            param='Device.SoftwareModules.Config.Repository.[Name == "docker_repo"].CABundle'
            value='Device.Security.CABundle.[Name == "root_ca1"]'
            cli='usp'
            ;;
        docker_repo_ca_bundle)
            param='Device.SoftwareModules.Config.Repository.[Name == "docker_repo"].CABundle'
            value='Device.Security.CABundle.[Name == "ca_bundle"]'
            cli='usp'
            ;;
        no_client_cert)
            param='Device.SoftwareModules.Config.Repository.[Name == "mtls"].Certificate'
            value=''
            cli='usp'
            ;;
        set_client_cert)
            param='Device.SoftwareModules.Config.Repository.[Name == "mtls"].Certificate'
            value='Device.Security.Certificate.[SerialNumber == "0123456789"].'
            cli='usp'
            ;;
        disable_docker_repo)
            param='Device.SoftwareModules.Config.Repository.[Name == "docker_repo"].Enable'
            value='0'
            cli='usp'
            ;;
        set_default_ca_wrong)
            param='Device.SoftwareModules.Config.CABundle'
            value='Device.Security.CABundle.[Name == "root_ca1"]'
            cli='usp'
            ;;
        set_subscription)
            sub='Device.LocalAgent.Subscription.+{Alias="DUStateChange", ID="DUStateChange", ReferenceList="Device.SoftwareModules.DUStateChange!", Enable=1, NotifType="Event"}'
            cli='usp'
            ;;
        remove_subscription)
            sub='Device.LocalAgent.Subscription.[ Alias== "DUStateChange" ].-'
            cli='usp'
            ;;
        *)
            echo "Unknown command: $cmd" >&2
            return 1
            ;;
    esac

    # Execute based on cli and type
    if [ "$cli" = "usp" ] && [ "$type" = "set" ]; then
		usp-test-cli -lj "$param='$value'" | sed '/^$/d'
    elif [ "$cli" = "ubus" ] && [ "$type" = "set" ]; then
		ubus-cli -lj "$param='$value'" | sed '/^$/d'
    elif [ "$cli" = "usp" ] && [ "$type" = "sub" ]; then
        usp-test-cli "$sub"
    fi
}

# Starts a background Lua listener for DUStateChange events on the
# Device.SoftwareModules data model path, writing output to a destination file.
# Usage: listen_dustatechange [destination]
#   destination - (optional) file path to capture the event output.
#                 Defaults to /tmp/captured_event if not provided.
# The listener runs as a background process via event.lua.
listen_dustatechange() {
	exec >/dev/null 2>&1

	destination="$1"
	if [ -z "$destination" ]; then
		destination="/tmp/captured_event"
	fi
	lua /tmp/event.lua "Device.SoftwareModules." "DUStateChange!" > "$destination" &
}
