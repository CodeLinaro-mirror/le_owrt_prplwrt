#ifndef __CL_STATION_H
#define __CL_STATION_H

#include <linux/types.h>
#include <linux/if_ether.h>
#include <linux/spinlock.h>

struct sk_buff;
struct radiotap_fields;
struct net_device;
struct packet_type;

struct station {
	uint8_t mac_addr[ETH_ALEN];
	int32_t rcpi;
	uint32_t channel; // channel number
	uint16_t freq; // channel freq.
	uint32_t avg_rssi;
	uint32_t rolling_rssi;
	uint16_t n_rssi_measurements;
	uint32_t max_rssi_measurements;
	spinlock_t lock;
};

/**
 * @brief Create a station. If 'mac_addr' is zero or a local address, return NULL.
 * 
 * @param mac_addr The address of the STA.
 * @return struct station* The station. NULL if we couldn't malloc, or 'mac_addr' was bogus.
 */
struct station *station_create(uint8_t mac_addr[ETH_ALEN]);

/**
 * @brief Free a station object.
 * 
 * @param sta the station to free.
 */
void station_free(struct station *sta);

/**
 * @brief Update a station's ratiotap fields from a radiotap_fields instance.
 * 
 * @param sta the station to update.
 * @param rtf the radiotap fields to update sta with.
 */
void station_update_rt_info(struct station *sta, struct radiotap_fields *rtf);

/**
 * @brief Dump a station's internals to dmesg.
 * 
 * @param sta the station of interest.
 */
void station_debug_dump(struct station *sta);

// TODO: make this calculate WMA with weights based on measurement time
void station_update_rssi_avg(struct station *sta);

// TODO: this will update a timestamp every time the station is seen.
// We will need a threshold timeout for 'garbage collection' of stations.
void station_update_last_seen(struct station *sta);

void station_cleanup_stations(void);

int station_radiotap_callback(struct sk_buff *skb, struct net_device *nd,
			      struct packet_type *pt,
			      struct net_device *orig_d);

struct station *station_get_at_idx(int i);

size_t station_get_station_table_size(void);

#endif // __CL_STATION_H
