#include <linux/netdevice.h>
#include <linux/ieee80211.h>

#include "netdev.h"

void netdev_dump_network_devices(void)
{
	int d_n = 0;
	struct net_device *d = first_net_device(&init_net);
	while (d) {
		pr_info("Device #%d (%s)\n", d_n++, d->name);
		d = next_net_device(d);
	}
}

struct net_device *netdev_get_device_by_name(const char *device_name)
{
	struct net_device *device = NULL;
	read_lock(&dev_base_lock);
	device = first_net_device(&init_net);
	while (device) {
		if (strncmp(device->name, device_name, strlen(device_name)) ==
		    0) {
			read_unlock(&dev_base_lock);
			return device;
		}
		device = next_net_device(device);
	}
	read_unlock(&dev_base_lock);
	return NULL;
}

static struct packet_type *allocate_packet_type(void)
{
	struct packet_type *pt =
		(struct packet_type *)kmalloc(sizeof(struct packet_type), 0);
	if (!pt)
		pr_err("%s: failed to allocate memory for struct packet_type\n",
		       __func__);
	return pt;
}

static struct packet_type *packet_types[256];

static void init_packet_types(void)
{
	int i;
	for (i = 0; i < 256; ++i) {
		packet_types[i] = NULL;
	}
}

static void internal_add_pack(struct packet_type *pt)
{
	static uint8_t insertion_idx = 0;
	packet_types[insertion_idx] = pt;
	insertion_idx = (insertion_idx + 1) % 256;
}

void netdev_cleanup_packs(void)
{
	int p_i;
	for (p_i = 0; p_i < 256; ++p_i) {
		if (packet_types[p_i]) {
			dev_remove_pack(packet_types[p_i]);
			packet_types[p_i] = NULL;
		}
	}
}

void netdev_begin_listening(struct net_device *netdev, int packet_types,
			    int (*receive_callback)(struct sk_buff *,
						    struct net_device *,
						    struct packet_type *,
						    struct net_device *))
{
	struct packet_type *pt = NULL;
	init_packet_types();
	if (!receive_callback) {
		pr_err("receive_callback is NULL\n");
		return;
	}
	pt = allocate_packet_type();
	if (!pt) {
		pr_err("Allocation for struct packet_type failed.\n");
		return;
	}
	pt->dev = netdev;
	pt->type = htons(packet_types);
	pt->func = receive_callback;
	dev_add_pack(pt);
	internal_add_pack(pt);
	pr_info("Packet listener registered.\n");
}
