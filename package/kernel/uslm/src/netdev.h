#ifndef __CL_NETDEV_H_
#define __CL_NETDEV_H_

struct net_device;

/**
 * @brief Writes network interface names to dmesg. For debugging.
 */
void netdev_dump_network_devices(void);

/**
 * @brief Return the net_device handle named 'device_name', NULL otherwise.
 *
 * Note: takes the dev_base_lock.
 * 
 * @param device_name the name of the device to look for.
 */
struct net_device *netdev_get_device_by_name(const char *device_name);

/**
 * @brief Register a packet listener for 'netdev'. Will sniff for 'packet_types' and when a packet is seen, 'receive_callback' is called with the packet passed in.
 */
void netdev_begin_listening(struct net_device *netdev, int packet_types,
			    int (*receive_callback)(struct sk_buff *,
						    struct net_device *,
						    struct packet_type *,
						    struct net_device *));

/**
 * @brief Unregister all protocol listeners registered during this module's lifetime.
 */
void netdev_cleanup_packs(void);

#endif // __CL_NETDEV_H_
