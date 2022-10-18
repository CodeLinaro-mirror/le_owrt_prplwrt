#include <linux/etherdevice.h>
#include <net/ieee80211_radiotap.h>
#include <net/cfg80211.h>
#include "station.h"
#include "radiotap.h"

static struct station *stations[256];

static uint16_t freq2chan(const uint16_t freq_)
{
	uint16_t channel = 0;
	// Channels 1 - 13
	if ((freq_ >= 2412) && (freq_ <= 2472)) {
		channel = (1 + ((freq_ - 2412) / 5));
	}
	// Channels 36 - 64
	else if ((freq_ >= 5170) && (freq_ <= 5320)) {
		channel = (34 + ((freq_ - 5170) / 5));
	}
	// Channels 100 - 144
	else if ((freq_ >= 5500) && (freq_ <= 5720)) {
		channel = (100 + ((freq_ - 5500) / 5));
	}
	// Channels 149 - 161
	else if ((freq_ >= 5745) && (freq_ <= 5805)) {
		channel = (149 + ((freq_ - 5745) / 5));
	}
	// Channel 165
	else if (freq_ == 5825) {
		channel = 165;
	}
	return (channel);
}

static struct station *station_get_by_mac(uint8_t mac[ETH_ALEN])
{
	int i;
	int found = 0;
	for (i = 0; i < ARRAY_SIZE(stations); i++) {
		if (!stations[i])
			continue;
		spin_lock(&stations[i]->lock);
		if (memcmp(stations[i]->mac_addr, mac, ETH_ALEN) == 0) {
			found = 1;
		}
		spin_unlock(&stations[i]->lock);
		if (found) {
			return stations[i];
		}
	}
	return NULL;
}

static bool station_already_exists(uint8_t mac_addr[ETH_ALEN])
{
	return station_get_by_mac(mac_addr) != NULL;
}

static void station_update_max_rssi_measurements(struct station *sta,
						 uint32_t new_max)
{
	if (unlikely(!sta))
		return;
	spin_lock(&sta->lock);
	if (sta->max_rssi_measurements < new_max) {
		sta->n_rssi_measurements = 0;
		sta->rolling_rssi = 0;
	}
	sta->max_rssi_measurements = new_max;
	spin_unlock(&sta->lock);
}

struct station *station_get_at_idx(int i)
{
	if (i < 0 || i > ARRAY_SIZE(stations))
		return NULL;
	return stations[i];
}
size_t station_get_station_table_size(void)
{
	return (size_t)ARRAY_SIZE(stations);
}
struct station *station_create(uint8_t mac_addr[ETH_ALEN])
{
	struct station *sta = NULL;
	if (is_zero_ether_addr(mac_addr) || is_local_ether_addr(mac_addr) ||
	    station_already_exists(mac_addr)) {
		return sta;
	}
	sta = (struct station *)kmalloc(sizeof(struct station), GFP_KERNEL);
	if (!sta) {
		pr_err(KBUILD_MODNAME
		       ": could not allocate memory for struct station\n");
		return sta;
	}
	memcpy(sta->mac_addr, mac_addr, ETH_ALEN);
	// TODO: pass this in via insmod?
	sta->max_rssi_measurements = 10;
	sta->n_rssi_measurements = 0;
	spin_lock_init(&sta->lock);
	return sta;
}

void station_free(struct station *sta)
{
	if (unlikely(!sta))
		return;
	kfree((void *)sta);
	sta = NULL;
}

void station_update_rssi_avg(struct station *sta)
{
	if (unlikely(!sta))
		return;
	spin_lock(&sta->lock);
	// if we've hit the measurement threshold, bail.
	if (sta->n_rssi_measurements > sta->max_rssi_measurements) {
		spin_unlock(&sta->lock);
		return;
	}
	sta->rolling_rssi += sta->rcpi;
	if (sta->n_rssi_measurements != 0)
		sta->avg_rssi = sta->rolling_rssi / sta->n_rssi_measurements;
	pr_info(KBUILD_MODNAME
		": Updating rssi avg for %02x:%02x:%02x:%02x:%02x:%02x. (n_measurements %d, max_measurements %d, current_avg_rssi %d, instantaneous rssi %d)\n",
		sta->mac_addr[0], sta->mac_addr[1], sta->mac_addr[2],
		sta->mac_addr[3], sta->mac_addr[4], sta->mac_addr[5],
		sta->n_rssi_measurements, sta->max_rssi_measurements,
		sta->avg_rssi, sta->rcpi);
	spin_unlock(&sta->lock);
}

void station_update_rt_info(struct station *sta,
			    struct radiotap_fields *rt_fields)
{
	if (unlikely(!sta) || unlikely(!rt_fields))
		return;
	spin_lock(&sta->lock);
	sta->channel = freq2chan(rt_fields->channel);
	sta->freq = rt_fields->channel;
	sta->rcpi = rt_fields->rssi;
	sta->n_rssi_measurements++;
	spin_unlock(&sta->lock);
}

void station_debug_dump(struct station *sta)
{
	if (!sta) {
		pr_info(KBUILD_MODNAME ": STA is NULL\n");
		return;
	}
	spin_lock(&sta->lock);
	pr_info(KBUILD_MODNAME
		": STA %02x:%02x:%02x:%02x:%02x:%02x instantaneous RSSI (dBm) %d channel #%d channel freq (MHz) %d\nrolling_rssi %d avg_rssi %d n_rssi_measurements %d max_rssi_measurements %d\n",
		sta->mac_addr[0], sta->mac_addr[1], sta->mac_addr[2],
		sta->mac_addr[3], sta->mac_addr[4], sta->mac_addr[5], sta->rcpi,
		sta->channel, sta->freq, sta->rolling_rssi, sta->avg_rssi,
		sta->n_rssi_measurements, sta->max_rssi_measurements);
	spin_unlock(&sta->lock);
}

static void add_station(struct station *s)
{
	static uint current_sta_rb_idx = 0;
	// if we've wrapped to the beginning of the 'ring buffer', free it.
	if (stations[current_sta_rb_idx])
		station_free(stations[current_sta_rb_idx]);
	stations[current_sta_rb_idx] = s;
	current_sta_rb_idx = (current_sta_rb_idx + 1) % ARRAY_SIZE(stations);
}

void station_cleanup_stations(void)
{
	int i;
	for (i = 0; i < ARRAY_SIZE(stations); i++)
		station_free(stations[i]);
}

static int station_radiotap_callback_core(struct sk_buff *skb,
					  struct radiotap_fields *rt_fields,
					  uint8_t mac[ETH_ALEN])
{
	struct station *sta = NULL;
	if (!station_already_exists(mac)) {
		sta = station_create(mac);
		add_station(sta);
	} else {
		sta = station_get_by_mac(mac);
	}
	station_update_rt_info(sta, rt_fields);
	station_update_rssi_avg(sta);
	return 0;
}

static int station_radiotap_prework(struct sk_buff *skb)
{
	struct ieee80211_hdr *eth_hdr = NULL;
	struct radiotap_fields rt_fields = { 0 };
	if (unlikely(!skb))
		return -1;
	eth_hdr =
		(struct ieee80211_hdr *)(skb->data +
					 ieee80211_get_radiotap_len(skb->data));
	if (parse_radiotap_buf((struct ieee80211_radiotap_header *)skb->data,
			       skb->len, &rt_fields)) {
		return -1;
	}
	if (rt_fields.bad_fcs)
		// drop it on the floor, walk the dinosaur.
		return -1;
	return station_radiotap_callback_core(skb, &rt_fields, eth_hdr->addr2);
}

int station_radiotap_callback(struct sk_buff *skb, struct net_device *nd,
			      struct packet_type *pt, struct net_device *unused)
{
	int status = 0;
	// pre-filter
	switch (skb->pkt_type) {
	case PACKET_HOST:
	case PACKET_OTHERHOST:
		status = station_radiotap_prework(skb);
		break;
	default:
		pr_warn(KBUILD_MODNAME ": packet type %d -- ignoring\n",
			skb->pkt_type);
		status = -1;
		break;
	}
	kfree_skb(skb);
	return status;
}
