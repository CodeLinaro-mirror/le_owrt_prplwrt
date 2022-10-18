#ifndef _RADIOTAP_PARSE_H_
#define _RADIOTAP_PARSE_H_

// forward decls
struct ieee80211_radiotap_header;

struct radiotap_fields {
	uint8_t rssi;
	uint16_t channel;
	uint8_t bad_fcs;
};
/**
 * @brief Parse radiotap header.
 * 
 * Iterates over available fields in the radiotap header.
 * @param buf the radiotap header.
 * @param buflen the length of the header.
 * @param[out] rt_fields_out the parsed radiotap fields.
 * @return int 0 on success, 1 otherwise.
 */
int parse_radiotap_buf(struct ieee80211_radiotap_header *buf, size_t buflen,
		       struct radiotap_fields *rt_fields_out);

#endif // _RADIOTAP_PARSE_H_