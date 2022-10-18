#include <net/cfg80211.h>
#include <net/ieee80211_radiotap.h>

#include "radiotap.h"

// https://www.kernel.org/doc/html/v5.9/networking/radiotap-headers.html#using-the-radiotap-parser
int parse_radiotap_buf(struct ieee80211_radiotap_header *buf, size_t buflen,
		       struct radiotap_fields *rt_fields_out)
{
	struct ieee80211_radiotap_iterator iter;
	int ret = ieee80211_radiotap_iterator_init(&iter, buf, buflen, 0);

	while (!ret) {
		ret = ieee80211_radiotap_iterator_next(&iter);

		if (ret)
			continue;

		switch (iter.this_arg_index) {
		case IEEE80211_RADIOTAP_DBM_TX_POWER:
			break;
		case IEEE80211_RADIOTAP_CHANNEL:
			rt_fields_out->channel =
				get_unaligned((uint16_t *)iter.this_arg);
			break;
		case IEEE80211_RADIOTAP_DB_ANTSIGNAL:
			break;
		case IEEE80211_RADIOTAP_DB_ANTNOISE:
			break;
		case IEEE80211_RADIOTAP_DBM_ANTSIGNAL:
			rt_fields_out->rssi =
				get_unaligned((uint8_t *)iter.this_arg);
			break;
		case IEEE80211_RADIOTAP_F_BADFCS:
			rt_fields_out->bad_fcs = 1;
			break;
		default:
			break;
		}
	}
	return 0;
}
EXPORT_SYMBOL(parse_radiotap_buf);
