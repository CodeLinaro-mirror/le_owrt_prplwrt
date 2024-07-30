#!/bin/bash

set -e
if [ $# -ne 5 ]; then
    echo "SYNTAX: $0 <file> <kernel size> <kernel image> <rootfs size> <rootfs image>"
    exit 1
fi

OUTPUT_FILE="$1"
KERNEL_SIZE="$2"
KERNEL_FILE="$3"
ROOTFS_SIZE="$4"
ROOTFS_FILE="$5"
MFGDATA_SIZE=1
SECURESTORE_SIZE=16
LCM_DATA_SIZE=512

LBASIZE=512
GPT_HEADERSIZE=33 # in LBA

PARTITIONS="$KERNEL_FILE:kernel-active:$KERNEL_SIZE \
	$KERNEL_FILE:kernel-inactive:$KERNEL_SIZE \
	$ROOTFS_FILE:rootfs-active:$ROOTFS_SIZE \
	$ROOTFS_FILE:rootfs-inactive:$ROOTFS_SIZE \
	:mfgdata:$MFGDATA_SIZE \
	:securestore:$SECURESTORE_SIZE \
	:lcm_data:$LCM_DATA_SIZE"


# Start with protective MBR space
dd if=/dev/zero of=$OUTPUT_FILE bs=$LBASIZE count=1
# Add primary GPT header space
dd if=/dev/zero bs=$LBASIZE count=$GPT_HEADERSIZE >> $OUTPUT_FILE

# Create sfdisk header
SFDISK_SPECS="label: gpt\n\
sector-size: $LBASIZE\n\
first-lba: $((GPT_HEADERSIZE+1))\n\
\n\
"

lba_start=$((GPT_HEADERSIZE+1))
for partfiledesc in $PARTITIONS; do
	partfile=`echo "$partfiledesc" | cut -d ':' -f 1`
	partname=`echo "$partfiledesc" | cut -d ':' -f 2`
	partsize_mb=`echo "$partfiledesc" | cut -d ':' -f 3`

	if [ -n "$partfile" ]; then
		filesize_bytes=`cat $partfile | wc -c`
		# Add partition file to output file
		dd if=$partfile bs=$LBASIZE >> $OUTPUT_FILE

		# Pad output file to required partition size
		padding=$((partsize_mb*1048576-filesize_bytes))
		block_padding=$((padding/4/1024))
		dd if=/dev/zero bs=4k count=$block_padding >> $OUTPUT_FILE
		dd if=/dev/zero bs=1 count=$((padding-block_padding*4*1024)) >> $OUTPUT_FILE
	else
		# Append empty space to output file, with required partition size
		dd if=/dev/zero bs=1M count=$partsize_mb >> $OUTPUT_FILE
	fi

	partsize_lba=$((partsize_mb*1048576/LBASIZE))
	# Add partition specs to sfdisk specs
	SFDISK_SPECS="$SFDISK_SPECS\nstart=$lba_start, size=$partsize_lba, type=L, name=$partname"

	# Set next partition starting point
	lba_start=$((lba_start+partsize_lba))
done

# Add secondary GPT header space
dd if=/dev/zero bs=$LBASIZE count=$GPT_HEADERSIZE >> $OUTPUT_FILE

# Apply GPT partition specs with sfdisk
echo -e "$SFDISK_SPECS" | sfdisk $OUTPUT_FILE
