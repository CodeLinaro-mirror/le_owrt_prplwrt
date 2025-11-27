Setup the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ S="/tmp/storageservice.sh"
  $ C ${TESTDIR}/05-storageservice/storageservice.sh root@${TARGET_LAN_IP}:/tmp/storageservice.sh

Don't run test on Turris Omnia, OSPv1 and Haze boards as they don't have USB flash disk available:

  $ case "$DUT_BOARD" in
  > turris-omnia|urx851-hdk-3|prpl-haze) exit 80 ;;
  > esac

Check Storage service exist

  $ R "which tr140-storageservice"
  /usr/bin/tr140-storageservice

Check USB key is detected:

  $ R "ubus-cli USB.USBHosts.Host.*.Device.*.ConfigurationNumberOfEntries? | grep = | wc -l"
  1

Unmount key partitions:

  $ R "${S} umount_partitions"

Create and format the partitions:

  $ R "${S} create_partition"

Force tr140-storageservice restart to detect newly created partitions:

  $ R "${S} restart_service"

Check filesystem are correctly mounted:

  $ R "${S} check_partitions"

Check DM FileSystem:

  $ R "ba-cli StorageService.1.LogicalVolume.*.FileSystem? | grep '^StorageService'"
  StorageService.1.LogicalVolume.1.FileSystem="EXT3"
  StorageService.1.LogicalVolume.2.FileSystem="EXT4"
  StorageService.1.LogicalVolume.3.FileSystem="HFSPLUS"
  StorageService.1.LogicalVolume.4.FileSystem="NTFS"
  StorageService.1.LogicalVolume.5.FileSystem="FAT32"
  StorageService.1.LogicalVolume.6.FileSystem="EXFAT"
  StorageService.1.LogicalVolume.7.FileSystem="EXT4"

Check DM FileSystem Status:

  $ R "ba-cli StorageService.1.LogicalVolume.*.Status? | grep '^StorageService'"
  StorageService.1.LogicalVolume.1.Status="Online"
  StorageService.1.LogicalVolume.2.Status="Online"
  StorageService.1.LogicalVolume.3.Status="Online"
  StorageService.1.LogicalVolume.4.Status="Online"
  StorageService.1.LogicalVolume.5.Status="Online"
  StorageService.1.LogicalVolume.6.Status="Online"
  StorageService.1.LogicalVolume.7.Status="Offline"

# Configure a share for ext3 partition:

  $ R "${S} create_share"

Check ksmbd config file:

  $ R "cat /etc/ksmbd/ksmbd.conf"
  [global]
  	netbios name = Prpl
  	workgroup = WORKGROUP
  	server min protocol = SMB2_02
  	server string = Prpl Sharing Files
  	interfaces = br-lan
  	bind interfaces only = yes
  	ipc timeout = 10
  	deadtime = 15
  	map to guest = bad user
  [EXT3]
  	comment = Share EXT3 directory
  	path = /mnt/sda1
  	browseable = yes
  	follow symlinks = no
  	encoding = utf8
  	valid users = prpluser
  	writeable = yes

Check ksmbd daemon:

  $ R "ps aux |grep \"ksmbd.mountd --n --config=/etc/ksmbd/ksmbd.conf\" > /dev/null"

Change the Password:

  $ R "ba-cli StorageService.1.UserAccount.1.Password=\"newprplpassword\"" > /dev/null
  $ sleep 3

Verify the new password:

  $ smbclient \\\\${TARGET_LAN_IP}\\ext3 -U 'prpluser%newprplpassword' --command=ls >/dev/null 2>/dev/null

