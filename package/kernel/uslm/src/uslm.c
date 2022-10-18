#include <linux/module.h>
#include <linux/moduleparam.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/netdevice.h>
#include <linux/etherdevice.h>
#include <net/ieee80211_radiotap.h>
#include <net/cfg80211.h>

#include "netdev.h"
#include "radiotap.h"
#include "station.h"
#include "proc.h"
#include "sta_proc.h"

MODULE_AUTHOR("CableLabs");
MODULE_DESCRIPTION("Sniff radiotap headers!");
MODULE_LICENSE("GPL");

static char *nic_name = "eth0";
module_param(nic_name, charp, S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP);
MODULE_PARM_DESC(nic_name, "The network interface to sniff traffic on.");

#define PACKET_RX_CALLBACK_MAX 10

static int (*packet_rx_cb_fns[PACKET_RX_CALLBACK_MAX])(struct sk_buff *,
						       struct net_device *,
						       struct packet_type *,
						       struct net_device *) = {
	station_radiotap_callback,
};

static int __init uslm_init(void)
{
	int callback_idx = 0;
	struct net_device *wireless_device = NULL;
	if (procfile_create(station_procfs_name, &station_stats_ops)) {
		pr_err(KBUILD_MODNAME
		       ": failed to create procfs file entry '%s'\n",
		       station_procfs_name);
	}
	netdev_dump_network_devices();
	wireless_device = netdev_get_device_by_name(nic_name);
	if (!wireless_device) {
		pr_err(KBUILD_MODNAME
		       ": could not open device '%s' for listening.\n",
		       nic_name);
		return -1;
	}
	for (callback_idx = 0; callback_idx < PACKET_RX_CALLBACK_MAX;
	     callback_idx++) {
		if (packet_rx_cb_fns[callback_idx])
			netdev_begin_listening(wireless_device, ETH_P_ALL,
					       packet_rx_cb_fns[callback_idx]);
	}
	pr_info(KBUILD_MODNAME ": loaded.\n");
	return 0;
}

static void __exit uslm_exit(void)
{
	if (procfile_destroy(station_procfs_name)) {
		pr_err(KBUILD_MODNAME
		       ": failed to destroy procfs file entry '%s'\n",
		       station_procfs_name);
	}
	netdev_cleanup_packs();
	station_cleanup_stations();
	pr_info(KBUILD_MODNAME ": unloaded.\n");
}

module_init(uslm_init);
module_exit(uslm_exit);
