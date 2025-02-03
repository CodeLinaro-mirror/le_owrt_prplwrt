#!/bin/bash

TMP_FOLDER="initramfs.tmp"
MODES="help show-extension build"


function usage {
	echo -e "Usage:
$0 MODE COMPRESSION [OUT_FILE] [IN_FOLDER] [ROOTFS_FOLDER]\n\
\n\
MODE should be one of $MODES.\n\
COMPRESSION should be one of GZIP BZIP2 LZMA LZO XZ LZ4 ZSTD.\n\
Additional parameters are only needed in 'build' mode

'build' mode will also expect environment variables:
  - UNSTRIPPED_FOLDER: a staging folder containing unstripped binaries for objdump
  - BINARIES_PATH: the target PATH variable
"
	exit $1
}

function help {
	usage 0
}

function show-extension {
	echo ".cpio$EXTENSION"
}

function build {
	OUT_FILE="$1"
	IN_FOLDER="$2"
	ROOTFS_FOLDER="$3"
	[ -e `dirname $OUT_FILE` ] && [ -e "$IN_FOLDER" ] && [ -e "$ROOTFS_FOLDER" ] && [ -n "$UNSTRIPPED_FOLDER" ] && [ -n "$BINARIES_PATH" ] || usage 1
	INITRAMFS_BINARIES_SEARCH_PATH="$BINARIES_PATH:/lib:/lib64:/usr/lib:/usr/lib64"

	rm -rf "$TMP_FOLDER"
	mkdir "$TMP_FOLDER"

	import_files_tree
	import_files_list
	package_final_file
}

function parse_compression {
	case "$1" in
		NONE)
			EXTENSION=""
			COMPRESSOR="tee"
			;;
		GZIP)
			EXTENSION=".gz"
			COMPRESSOR="gzip -c -"
			;;
		BZIP2)
			EXTENSION=".bz2"
			COMPRESSOR="bzip2 -c -"
			;;
		LZMA)
			EXTENSION=".lzma"
			COMPRESSOR="lzma -c -"
			;;
		LZO)
			EXTENSION=".lzo"
			COMPRESSOR="lzop -c -"
			;;
		XZ)
			EXTENSION=".xz"
			COMPRESSOR="xz -c -"
			;;
		LZ4)
			EXTENSION=".lz4"
			COMPRESSOR="lz4 -c -"
			;;
		ZSTD)
			EXTENSION=".zstd"
			COMPRESSOR="zstd -c -"
			;;
		*)
			usage 1;;
	esac
}

function import_files_tree {
	cp -r $IN_FOLDER/initramfs-files/* $TMP_FOLDER/
}

# $1 is the file to find, it should be a binary/lib to search in path
# Only first hit is returned
function find_binary {
	while read -r search_dir; do
		if [ -e "$ROOTFS_FOLDER$search_dir/$1" ] || [ -L "$ROOTFS_FOLDER$search_dir/$1" ]; then
			echo "$search_dir/$1"
			return 0
		fi
	done < <(echo "$INITRAMFS_BINARIES_SEARCH_PATH" | sed -r 's/:/\n/g')
	echo "Error: could not find required binary $1" >&2
	exit 1
}


function import_file_symlink {
	import_file_other "$1"
	target=`readlink "$ROOTFS_FOLDER$1"`
	[[ "$target" == /* ]] || target=`dirname "$1"`/$target
	import_file "$target"
}

function import_file_binary {
	import_file_other "$1"
	deps=`objdump -p "$UNSTRIPPED_FOLDER$1" | grep NEEDED | sed -r 's/\s*NEEDED\s*//'`
	[ -z "$deps" ] && return 0
	while read -r dependency; do
		import_file `find_binary "$dependency"`
	done < <(echo "$deps")
}

function import_file_other {
	mkdir -p `dirname $TMP_FOLDER$1`
	cp -pPTr "$ROOTFS_FOLDER$1" "$TMP_FOLDER$1"
}

function import_file {
	[ -e "$TMP_FOLDER$1" ] && return 0

	# Here it both checks the file exists, and expand any wildcard pattern, so we need the ls command
	cd "$ROOTFS_FOLDER"; file=`ls --format=single-column ./$1 | head -n 1 | sed -E 's,\./,,'`; cd - > /dev/null
	[ -z "$file" ] && echo "Could not find $1" >&2 && exit 1
	input_file="$ROOTFS_FOLDER$file"

	if [ -L "$input_file" ]; then
		file_type=symlink
	elif objdump -f "$input_file" > /dev/null; then
		file_type=binary
	else
		file_type=other
	fi
	import_file_$file_type "$file"
}

function import_files_list {
	while read -r file; do
		[[ "$file" == /* ]] || file=`find_binary "$file"`
		import_file "$file"
	done < <(cat $IN_FOLDER/initramfs-files-list.txt; find "$ROOTFS_FOLDER/lib" -name 'ld-*' -printf '/lib/%P\n')
}

function package_final_file {
	cd $TMP_FOLDER
	find . | cpio -o --quiet -H newc --owner "+0:+0" | $COMPRESSOR > "$OUT_FILE"
	cd - > /dev/null
}


mode=$1
echo "$MODES" | grep -wq "$mode" || usage 1
shift
parse_compression "$1"
shift

$mode $@
