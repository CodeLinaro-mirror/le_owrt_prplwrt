# Shared datamodel helpers for prplOS cram tests.
#
# Sourced on the cram host with `. "$TESTDIR/../lib/dm.sh"`. Every command
# reaches the DUT through CRAM_REMOTE_COMMAND (ssh root@<target> in CI).
# POSIX sh only: CI runs cram with /bin/sh, which is dash there.
#
# Design rule: a helper used on an assertion line prints the actual value, or
# the reason plus the actual value when the expected fragment is missing, so a
# failing test reads as "expected vs actual" in the cram diff.

# dm_get Device.Obj.Sub.Param : print the raw value of one parameter.
# Multi-line values (PIDF-LO, SenML XML) come out intact and unquoted.
# Prints "<missing>" when the object or parameter does not exist.
dm_get() {
    _obj="${1%.*}."
    _param="${1##*.}"
    _response=$(R "ba-cli --json '${_obj}?0' | sed -n 2p")

    # Targets may print a parameter as PATH=<JSON string>, whereas the mock
    # and some ba-cli versions return a JSON array. Decode the assignment's
    # right-hand side first so escaped XML newlines and quotes are restored.
    case "$_response" in
        "$_obj$_param="*)
            printf '%s\n' "${_response#*=}" | jq -r '. // "<missing>"'
            ;;
        *)
            printf '%s\n' "$_response" \
                | jq -r --arg o "$_obj" --arg p "$_param" '.[0][$o][$p] // "<missing>"'
            ;;
    esac
}

# dm_wait PATH GREP_RE [TIMEOUT_S=20] : poll dm_get once a second until the
# value matches GREP_RE. Prints how long it took, or the last value on timeout.
dm_wait() {
    _path=$1
    _re=$2
    _timeout=${3:-20}
    _i=0
    _val=""
    while [ "$_i" -lt "$_timeout" ]; do
        _val=$(dm_get "$_path")
        if printf '%s\n' "$_val" | grep -q -- "$_re"; then
            echo "$_path matched /$_re/ after ${_i}s"
            return 0
        fi
        _i=$((_i + 1))
        sleep 1
    done
    echo "$_path did not match /$_re/ within ${_timeout}s; last value:"
    printf '%s\n' "$_val"
    return 1
}

# xml_entry BRE : read an XML value on stdin and print the first element
# matching the basic regex BRE. Otherwise print the reason and the whole value.
xml_entry() {
    _in=$(cat)
    _hit=$(printf '%s\n' "$_in" | grep -o -- "$1" | head -n 1)
    if [ -n "$_hit" ]; then
        printf '%s\n' "$_hit"
        return 0
    fi
    echo "no element matching /$1/; actual value:"
    printf '%s\n' "$_in"
    return 1
}

# senml_entry NAME : the <senml ... n="NAME" ...></senml> element of a SenML value.
senml_entry() {
    xml_entry "<senml [^>]*n=\\\"$1\\\"[^>]*>[^<]*</senml>"
}

# senml_value NAME : extract the numeric v attribute of a named SenML entry.
senml_value() {
    _entry=$(senml_entry "$1") || {
        printf '%s\n' "$_entry"
        return 1
    }
    printf '%s\n' "$_entry" | sed -n 's/.* v="\([^"]*\)".*/\1/p'
}

# pidf_pos : the <gml:pos>lat lon</gml:pos> element of a PIDF-LO value.
pidf_pos() {
    xml_entry '<gml:pos>[^<]*</gml:pos>'
}

# pidf_method : the <gp:method>...</gp:method> element of a PIDF-LO value.
pidf_method() {
    xml_entry '<gp:method>[^<]*</gp:method>'
}

# svc_restart NAME : restart /etc/init.d/NAME on the DUT.
svc_restart() {
    R "/etc/init.d/$1 restart" && echo "$1 restarted"
}

