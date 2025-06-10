#!/bin/sh

if [ "$1" = "create_partition" ]; then
	# Create new partition table

	sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' <<EOF | fdisk /dev/sda >/dev/null 2>/dev/null || exit 1
  o # clear the in memory partition table
  n # new partition
  p # primary partition
  1 # partition number 1
    # default - start at beginning of disk
  +100M # 100 MB boot parttion
  n # new partition
  p # primary partition
  2 # partion number 2
    # default, start immediately after preceding partition
  +100M # 100 MB boot parttion
  n # new partition
  p # primary partition
  3 # partion number 3
    # default, start immediately after preceding partition
  +100M # 100 MB boot parttion
  n # new partition
  e # primary partition
  4 # partion number 4
    # default, start immediately after preceding partition
    # 100 MB boot parttion
  n # new partition
  e # primary partition
  5 # partion number 5
    # default, start immediately after preceding partition
  +100M # 100 MB boot parttion
  n # new partition
  e # primary partition
  6 # partion number 6
    # default, start immediately after preceding partition
  +100M # 100 MB boot parttion
  n # new partition
  e # primary partition
  7 # partion number 7
    # default, start immediately after preceding partition
  +100M # 100 MB boot parttion
  n # new partition
  e # primary partition
  8 # partion number 8
    # default, start immediately after preceding partition
  +100M # 100 MB boot parttion
  a # make a partition bootable
  1 # bootable partition is partition 1 -- /dev/sda1
  p # print the in-memory partition table
  w # write the partition table
  q # and we're done
EOF

	# Formating ext3:

	echo y | mkfs.ext3 -L EXT3 /dev/sda1 >/dev/null 2>/dev/null || exit 1
	mkdir -p /tmp/mnt/part >/dev/null 2>/dev/null || exit 1
	mount /dev/sda1 /tmp/mnt/part >/dev/null 2>/dev/null || exit 1
	touch /tmp/mnt/part/ext3.txt >/dev/null 2>/dev/null || exit 1
	umount /tmp/mnt/part >/dev/null 2>/dev/null || exit 1

	# Formating ext4:

	echo y | mkfs.ext4 -L ext4 /dev/sda2 >/dev/null 2>/dev/null || exit 1
	mount /dev/sda2 /tmp/mnt/part >/dev/null 2>/dev/null || exit 1
	touch /tmp/mnt/part/ext4.txt >/dev/null 2>/dev/null || exit 1
	umount /tmp/mnt/part >/dev/null 2>/dev/null || exit 1

	# Formating HFS+:

	echo y | mkfs.hfsplus -v HFSPLUS /dev/sda3 >/dev/null 2>/dev/null || exit 1
	mount /dev/sda3 /tmp/mnt/part >/dev/null 2>/dev/null || exit 1
	touch /tmp/mnt/part/hfsplus.txt >/dev/null 2>/dev/null || exit 1
	umount /tmp/mnt/part >/dev/null 2>/dev/null || exit 1

	# Formating NTFS:

	echo y | mkntfs -L NTFS /dev/sda5 >/dev/null 2>/dev/null || exit 1
	mount /dev/sda5 /tmp/mnt/part >/dev/null 2>/dev/null || exit 1
	touch /tmp/mnt/part/ntfs.txt >/dev/null 2>/dev/null || exit 1
	umount /tmp/mnt/part >/dev/null 2>/dev/null || exit 1

	# Formating FAT32:

	echo y | mkfs.vfat -f 32 /dev/sda6 >/dev/null 2>/dev/null || exit 1
	mount /dev/sda6 /tmp/mnt/part >/dev/null 2>/dev/null || exit 1
	touch /tmp/mnt/part/fat32.txt >/dev/null 2>/dev/null || exit 1
	umount /tmp/mnt/part >/dev/null 2>/dev/null || exit 1

	# Formating ExFAT:

	echo y | mkfs.exfat -n ExFAT /dev/sda7 >/dev/null 2>/dev/null || exit 1
	mount /dev/sda7 /tmp/mnt/part >/dev/null 2>/dev/null || exit 1
	touch /tmp/mnt/part/exfat.txt >/dev/null 2>/dev/null || exit 1
	umount /tmp/mnt/part >/dev/null 2>/dev/null || exit 1

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
	ba-cli StorageService.1.LogicalVolume.*.- >/dev/null 2>/dev/null || exit 1
	sleep 2
	killall -9 tr140-storageservice || exit 1
	service tr140-storageservice start || exit 1
	ubus -t10 wait_for StorageService || exit 1
fi

if [ "$1" = "check_partitions" ]; then
	mount | grep '/dev/sda1.*ext3' >/dev/null 2>/dev/null || exit 1
	mount | grep '/dev/sda2.*ext4' >/dev/null 2>/dev/null || exit 1
	mount | grep '/dev/sda3.*hfsplus' >/dev/null 2>/dev/null || exit 1
	mount | grep -e '/dev/sda5.*fuseblk' -e '/dev/sda5.*ntfs3' >/dev/null 2>/dev/null || exit 1
	mount | grep '/dev/sda6.*vfat' >/dev/null 2>/dev/null || exit 1
	mount | grep '/dev/sda7.*exfat' >/dev/null 2>/dev/null || exit 1
fi
