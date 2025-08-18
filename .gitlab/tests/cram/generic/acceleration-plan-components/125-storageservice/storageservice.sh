#!/bin/sh

if [ "$1" = "umount_partitions" ]; then
	for p in $(mount |grep /dev/sda |cut -d" " -f3); do umount -f $p; done >/dev/null 2>/dev/null
fi

if [ "$1" = "create_partition" ]; then
	# Create new partition table
	cat > /tmp/sfdisk_input.txt <<'ENDFILE'
label: dos
,100M,83,*
,100M,83
,100M,83
,,5
,100M,83
,100M,83
,100M,83
,100M,83
ENDFILE

	# Apply partition table
	sfdisk /dev/sda < /tmp/sfdisk_input.txt >/dev/null 2>/dev/null || exit 1

	# Formating ext3:
	echo y | mkfs.ext3 -L EXT3 /dev/sda1 >/dev/null 2>/dev/null || exit 1

	# Formating ext4:
	echo y | mkfs.ext4 -L ext4 /dev/sda2 >/dev/null 2>/dev/null || exit 1

	# Formating HFS+:
	echo y | mkfs.hfsplus -v HFSPLUS /dev/sda3 >/dev/null 2>/dev/null || exit 1

	# Formating NTFS:
	echo y | mkntfs -L NTFS /dev/sda5 >/dev/null 2>/dev/null || exit 1

	# Formating FAT32:
	echo y | mkfs.vfat -f 32 /dev/sda6 >/dev/null 2>/dev/null || exit 1

	# Formating ExFAT:
	echo y | mkfs.exfat -n ExFAT /dev/sda7 >/dev/null 2>/dev/null || exit 1

	# Formating BadEXT4:
	echo y | mkfs.ext4 /dev/sda8 >/dev/null 2>/dev/null || exit 1
	debugfs -w -R "clri <8>" /dev/sda8 2>/dev/null || exit 1
fi

if [ "$1" = "create_share" ]; then
	ba-cli StorageService.1.NetworkServer.SMBEnable=1 >/dev/null || exit 1
	ba-cli StorageService.1.LogicalVolume.1.Folder.+ >/dev/null || exit 1
	ba-cli StorageService.1.LogicalVolume.1.Folder.1.Name=/mnt/sda1 >/dev/null || exit 1
	ba-cli StorageService.1.LogicalVolume.1.Folder.1.UserAccountAccess=2 >/dev/null || exit 1
	ba-cli StorageService.1.LogicalVolume.1.Folder.1.UserAccess.+ >/dev/null || exit 1
	ba-cli StorageService.1.LogicalVolume.1.Folder.1.UserAccess.1.UserReference=Device.Services.StorageService.1.UserAccount.1. >/dev/null || exit 1
	ba-cli StorageService.1.LogicalVolume.1.Folder.1.UserAccess.1.Permissions=7 >/dev/null || exit 1
	ba-cli StorageService.1.LogicalVolume.1.Folder.1.UserAccess.1.Enable=1 >/dev/null || exit 1
	ba-cli StorageService.1.LogicalVolume.1.Folder.1.Enable=1 >/dev/null || exit 1
fi

if [ "$1" = "restart_service" ]; then
	ba-cli StorageService.1.LogicalVolume.*.- >/dev/null 2>/dev/null
	sleep 2
	killall -9 tr140-storageservice >/dev/null 2>/dev/null
	service tr140-storageservice start >/dev/null 2>/dev/null
	ubus -t10 wait_for StorageService >/dev/null 2>/dev/null
	sleep 2
fi

if [ "$1" = "check_partitions" ]; then
	mount | grep '/dev/sda1.*ext3' >/dev/null 2>/dev/null || exit 1
	mount | grep '/dev/sda2.*ext4' >/dev/null 2>/dev/null || exit 2
	mount | grep '/dev/sda3.*hfsplus' >/dev/null 2>/dev/null || exit 3
	mount | grep -e '/dev/sda5.*fuseblk' -e '/dev/sda5.*ntfs3' >/dev/null 2>/dev/null || exit 4
	mount | grep '/dev/sda6.*vfat' >/dev/null 2>/dev/null || exit 5
	mount | grep '/dev/sda7.*exfat' >/dev/null 2>/dev/null || exit 6
fi
