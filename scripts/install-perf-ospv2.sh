#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOF'
Usage: scripts/install-perf-ospv2.sh [--dry-run]

Copy perf and its recursive IPK dependencies to an OSPv2 target through a jump
host, install them with opkg, and verify that perf can run.

Environment:
  BUILD_ROOT   prplOS build tree to read IPKs from; defaults to this repo
  JUMP_HOST    SSH jump host; defaults to apu2-rax40
  DEVICE       target reachable from the jump host; defaults to root@192.168.1.1
  REMOTE_DIR   target directory for copied IPKs; defaults to /tmp/perf-ipks
  SSH_OPTS     extra options passed to ssh and scp, split on shell whitespace
  SCP_OPTS     extra options passed to scp; defaults to -O for Dropbear targets

Examples:
  scripts/install-perf-ospv2.sh --dry-run
  scripts/install-perf-ospv2.sh
  DEVICE=root@192.168.1.2 REMOTE_DIR=/tmp/perf scripts/install-perf-ospv2.sh
EOF
}

die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

log() {
	printf '%s\n' "$*" >&2
}

shell_quote() {
	printf '%q' "$1"
}

split_words() {
	local input=$1
	local -n output=$2

	output=()
	if [[ -n $input ]]; then
		read -r -a output <<<"$input"
	fi
}

dry_run=0
while (($#)); do
	case "$1" in
		--dry-run)
			dry_run=1
			shift
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			die "unknown argument: $1"
			;;
	esac
done

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
default_build_root=$(cd -- "$script_dir/.." && pwd)
BUILD_ROOT=${BUILD_ROOT:-$default_build_root}
JUMP_HOST=${JUMP_HOST:-apu2-rax40}
DEVICE=${DEVICE:-root@192.168.1.1}
REMOTE_DIR=${REMOTE_DIR:-/tmp/perf-ipks}

[[ -d $BUILD_ROOT/bin ]] || die "BUILD_ROOT does not look built: $BUILD_ROOT"

mapfile -t package_indexes < <(find "$BUILD_ROOT/bin" -path '*/Packages' -type f | sort)
((${#package_indexes[@]})) || die "no Packages indexes found below $BUILD_ROOT/bin"

declare -A package_file=()
declare -A package_deps=()

while IFS=$'\t' read -r package file deps; do
	[[ -n $package && -n $file ]] || continue
	if [[ -z ${package_file[$package]:-} ]]; then
		package_file[$package]=$file
		package_deps[$package]=$deps
	fi
done < <(
	awk '
		BEGIN { RS = ""; FS = "\n"; OFS = "\t" }
		{
			package = ""
			filename = ""
			depends = ""
			for (i = 1; i <= NF; i++) {
				if ($i ~ /^Package: /) {
					package = substr($i, 10)
				} else if ($i ~ /^Filename: /) {
					filename = substr($i, 11)
				} else if ($i ~ /^Depends: /) {
					depends = substr($i, 10)
				}
			}
			if (package != "" && filename != "") {
				dir = FILENAME
				sub(/\/Packages$/, "", dir)
				print package, dir "/" filename, depends
			}
		}
	' "${package_indexes[@]}"
)

normalize_deps() {
	local deps=$1

	awk -v deps="$deps" '
		BEGIN {
			n = split(deps, items, ",")
			for (i = 1; i <= n; i++) {
				dep = items[i]
				sub(/\|.*/, "", dep)
				gsub(/^[[:space:]]+|[[:space:]]+$/, "", dep)
				sub(/[[:space:]].*/, "", dep)
				if (dep != "") {
					print dep
				}
			}
		}
	'
}

find_unindexed_ipk() {
	local package=$1
	local -a matches=()

	mapfile -t matches < <(find "$BUILD_ROOT/bin" -type f -name "${package}_*.ipk" | sort)
	if ((${#matches[@]} == 1)); then
		package_file[$package]=${matches[0]}
		package_deps[$package]=
		return 0
	fi

	return 1
}

declare -A resolving=()
declare -A resolved=()
declare -A missing=()
install_order=()

resolve_package() {
	local package=$1
	local dep

	if [[ -n ${resolved[$package]:-} ]]; then
		return
	fi
	if [[ -n ${resolving[$package]:-} ]]; then
		die "dependency cycle while resolving $package"
	fi
	if [[ -z ${package_file[$package]:-} ]]; then
		if ! find_unindexed_ipk "$package"; then
			missing[$package]=1
			return
		fi
	fi

	resolving[$package]=1
	while IFS= read -r dep; do
		[[ -n $dep ]] || continue
		resolve_package "$dep"
	done < <(normalize_deps "${package_deps[$package]:-}")
	unset 'resolving[$package]'

	resolved[$package]=1
	install_order+=("$package")
}

[[ -n ${package_file[perf]:-} ]] || die "perf IPK was not found below $BUILD_ROOT/bin"
resolve_package perf

staging=$(mktemp -d "${TMPDIR:-/tmp}/ospv2-perf-ipks.XXXXXXXX")
cleanup() {
	rm -rf "$staging"
}
trap cleanup EXIT

log "Resolved IPK install set:"
for package in "${install_order[@]}"; do
	file=${package_file[$package]}
	[[ -f $file ]] || die "resolved file does not exist for $package: $file"
	cp -f -- "$file" "$staging/"
	log "  $package -> ${file#$BUILD_ROOT/}"
done

if ((${#missing[@]})); then
	log "Dependencies not present as IPKs; assuming built-in/provided on target:"
	for package in "${!missing[@]}"; do
		log "  $package"
	done | sort >&2
fi

log "Staged $(find "$staging" -maxdepth 1 -type f -name '*.ipk' | wc -l) IPKs in $staging"

if ((dry_run)); then
	log "Dry run requested; not copying or installing."
	exit 0
fi

ssh_extra=()
scp_extra=()
split_words "${SSH_OPTS:-}" ssh_extra
split_words "${SCP_OPTS:--O}" scp_extra

common_ssh_opts=(-o BatchMode=yes -o ConnectTimeout=15)
ssh_device=(ssh "${common_ssh_opts[@]}" "${ssh_extra[@]}" -J "$JUMP_HOST" "$DEVICE")
scp_device=(scp "${scp_extra[@]}" "${common_ssh_opts[@]}" "${ssh_extra[@]}" -J "$JUMP_HOST")
remote_dir_q=$(shell_quote "$REMOTE_DIR")

log "Preparing $DEVICE:$REMOTE_DIR via $JUMP_HOST"
"${ssh_device[@]}" "rm -rf $remote_dir_q && mkdir -p $remote_dir_q"

log "Copying IPKs with scp"
"${scp_device[@]}" "$staging"/*.ipk "$DEVICE:$REMOTE_DIR/"

log "Installing IPKs and verifying perf"
"${ssh_device[@]}" "set -eu
ls -lh $remote_dir_q/*.ipk
opkg install $remote_dir_q/*.ipk
perf --version
perf list >/tmp/perf-list.out
test -s /tmp/perf-list.out
if ! perf stat -e task-clock true >/tmp/perf-stat.out 2>&1; then
	cat /tmp/perf-stat.out
	exit 1
fi
cat /tmp/perf-stat.out
echo 'perf verification passed'"
