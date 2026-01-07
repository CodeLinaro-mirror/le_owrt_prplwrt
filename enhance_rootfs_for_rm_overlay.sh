echo "$1"

source "$2"
echo "$CURR_INSTALL_DIR"
# change file names
mv $1/etc/passwd $1/etc/passwd_static
mv $1/etc/group $1/etc/group_static
mv $1/etc/hosts $1/etc/hosts_static
mv $1/etc/shadow $1/etc/shadow_static
mv $1/etc/iproute2/ematch_map $1/etc/iproute2/ematch_map_static
mv $1/etc/iproute2/rt_protos $1/etc/iproute2/rt_protos_static
mv $1/etc/iproute2/rt_tables $1/etc/iproute2/rt_tables_static
mv $1/etc/dropbear/* $1/etc/config/ssh_server/

# create directories that will be created during device startup
mkdir -p $1/cfg/board-db/config
mkdir -p $1/etc/board-db/config
mkdir -p $1/mnt/log/
mkdir -p $1/mnt/disk1_1/
mkdir -p $1/perm/
mkdir -p $1/cfg/config_overlay/
mkdir -p $1/lcm/
mkdir -p $1/www/assets/pcm.usr/
mkdir -p $1/factory_data
mkdir -p $1/mnt/defaults
mkdir -p $1/mnt/fs_update
mkdir -p $1/etc/config/ssh_server/odl/
rm -rf $1/etc/amx_original/
rm -rf $1/etc/config_original/
mv $1/etc/amx/ $1/etc/amx_original/
mv $1/etc/config/ $1/etc/config_original/
rm -rf /etc/amx
rm -rf /etc/config
ln -s /tmp/amx $1/etc/amx
ln -s /tmp/config $1/etc/config

# set up symbolic links
ln -s /tmp/passwd $1/etc/passwd
ln -s /tmp/group $1/etc/group
ln -s /tmp/hosts $1/etc/hosts
ln -s /tmp/shadow $1/etc/shadow
ln -s /tmp/iproute2/ematch_map $1/etc/iproute2/ematch_map
ln -s /tmp/iproute2/rt_protos $1/etc/iproute2/rt_protos
ln -s /tmp/iproute2/rt_tables $1/etc/iproute2/rt_tables
ln -s /cfg/board.json $1/etc/board.json
ln -s /cfg/board-db/config/hw $1/etc/board-db/config/hw
ln -s /tmp/urandom.seed $1/etc/urandom.seed
ln -s /tmp/crontabs/root $1/etc/crontabs/root
# For WIFI networklayout.json 
ln -s /cfg/networklayout.json $1/etc/networklayout.json



#remove unused
rm -f $1/etc/rc.d/K50lighttpd
rm -f $1/etc/rc.d/S50lighttpd
rm -f $1/etc/rc.d/K10ddns
rm -f $1/etc/rc.d/K50dropbear
rm -f $1/etc/rc.d/S15chronyd
rm -f $1/etc/rc.d/S19dnsmasq
rm -f $1/etc/rc.d/S19dropbear
rm -f $1/etc/rc.d/S50syslog-ng
rm -f $1/etc/rc.d/S95ddns
rm -f $1/etc/hotplug.d/ntp/25-dnsmasqsec
rm -f $1/etc/init.d/chronyd
rm -f $1/etc/init.d/dnsmasq
rm -f $1/etc/init.d/syslog-ng
rm -f $CURR_INSTALL_DIR/../../fs.src/etc/passwd.static
rm -f $CURR_INSTALL_DIR/../../fs.src/etc/group.static
