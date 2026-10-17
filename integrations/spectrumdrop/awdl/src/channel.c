/*
 * OWL: an open Apple Wireless Direct Link (AWDL) implementation
 * Copyright (C) 2018  The Open Wireless Link Project (https://owlink.org)
 * Copyright (C) 2018  Milan Stute
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#include "channel.h"
#include "ieee80211.h"
#include <string.h>

void awdl_chanseq_init(struct awdl_chan *seq) {
	for (int i = 0; i < AWDL_CHANSEQ_LENGTH; i++, seq++) {
		if (i < 8)
			*seq = CHAN_OPCLASS_149;
		else
			*seq = CHAN_OPCLASS_6;
	}
}

void awdl_chanseq_init_idle(struct awdl_chan *seq) {
	for (int i = 0; i < AWDL_CHANSEQ_LENGTH; i++, seq++) {
		switch (i) {
			case 8:
				*seq = CHAN_OPCLASS_6;
				break;
			case 0:
			case 9:
			case 10:
				*seq = CHAN_OPCLASS_149;
				break;
			default:
				*seq = CHAN_NULL;
				break;
		}
	}
}

void awdl_chanseq_init_static(struct awdl_chan *seq, const struct awdl_chan *chan) {
	for (int i = 0; i < AWDL_CHANSEQ_LENGTH; i++, seq++) {
		*seq = *chan;
	}
}

void awdl_chanseq_rotate(struct awdl_chan *dst, const struct awdl_chan *src, int delta) {
	delta %= AWDL_CHANSEQ_LENGTH;
	if (delta < 0)
		delta += AWDL_CHANSEQ_LENGTH;
	for (int i = 0; i < AWDL_CHANSEQ_LENGTH; i++)
		dst[i] = src[(i + delta) % AWDL_CHANSEQ_LENGTH];
}

int awdl_chanseq_widen(struct awdl_chan *dst, const struct awdl_chan *src,
                       enum awdl_chan_encoding enc, int max_fill) {
	uint8_t want = awdl_chanseq_dominant_chan(src, enc, 0);
	struct awdl_chan fill = CHAN_NULL;
	int filled = 0;

	memcpy(dst, src, AWDL_CHANSEQ_LENGTH * sizeof(*dst));
	if (!want || max_fill <= 0)
		return 0;

	/* Reuse the peer's OWN bytes for the channel rather than constructing a
	 * {chan, opclass} pair ourselves. §25 leaves open exactly which part of a
	 * sequence Apple validates, so the fewer bytes we invent, the fewer ways a
	 * negative result can mean something other than "too wide". */
	for (int i = 0; i < AWDL_CHANSEQ_LENGTH; i++) {
		if (awdl_chan_num(src[i], enc) == want) {
			fill = src[i];
			break;
		}
	}

	/* Slot 0 is left exactly as the peer wrote it. Every captured Apple sequence
	 * puts a non-social channel there -- the device's infra channel -- and it is
	 * one of the two things a pinned sequence destroyed. Holding it fixed keeps
	 * this a test of width alone. */
	for (int i = 1; i < AWDL_CHANSEQ_LENGTH && filled < max_fill; i++) {
		if (!awdl_chan_num(dst[i], enc)) {
			dst[i] = fill;
			filled++;
		}
	}
	return filled;
}

int awdl_chanseq_intersect(struct awdl_chan *dst, const struct awdl_chan *src,
                           enum awdl_chan_encoding enc, uint8_t keep) {
	int kept = 0;

	/* The peer's sequence with every slot we cannot physically serve blanked
	 * out.
	 *
	 * This exists for the P2P-GO configuration, where the radio is held on one
	 * channel by go0's chanctx and awdl_switch_channel()'s set_channel() is a
	 * silent no-op -- measured: 2425 of 2425 captured frames on 5180 MHz across
	 * a window in which OWL logged ten switches to 149 and ten back. So we are
	 * on exactly one channel no matter what our sequence claims, while an
	 * iPhone ranges over 36/149/6 plus empty slots.
	 *
	 * That leaves only bad options if we advertise something untrue. VERBATIM
	 * claims we follow the peer everywhere, so the phone sends to us on 149 and
	 * we are deaf for those slots. PIN claims one channel in all 16, which §25
	 * measured the phone rejecting outright. The intersection is the honest
	 * sequence: the slots we really are on the peer's channel, and empty
	 * elsewhere. Empty slots are ordinary in every captured Apple sequence, so
	 * this keeps the structure §25 found to matter while telling no lie about
	 * our availability.
	 *
	 * Bytes are copied from the peer's own sequence, never constructed, for the
	 * same reason awdl_chanseq_widen() does it: fewer invented bytes, fewer ways
	 * a negative result means something other than what we set out to test. */
	for (int i = 0; i < AWDL_CHANSEQ_LENGTH; i++) {
		if (keep && awdl_chan_num(src[i], enc) == keep) {
			dst[i] = src[i];
			kept++;
		} else {
			dst[i] = (struct awdl_chan) CHAN_NULL;
		}
	}
	return kept;
}

uint8_t awdl_chanseq_dominant_chan(const struct awdl_chan *seq, enum awdl_chan_encoding enc, uint8_t prefer) {
	int count[256] = {0};
	uint8_t best = 0;

	for (int i = 0; i < AWDL_CHANSEQ_LENGTH; i++) {
		uint8_t c = awdl_chan_num(seq[i], enc);
		if (c)
			count[c]++;
	}
	for (int i = 1; i < 256; i++) {
		if (count[i] > count[best])
			best = (uint8_t) i;
	}
	/* The operator's channel breaks EXACT ties only. An earlier version returned
	 * it whenever it appeared at all, which is badly wrong: measured against a
	 * live iPhone advertising
	 *   36,36,149,0,0,0,0,36,6,36,149,36,0,0,0,36
	 * while airdrop.sh had swept to channel 6, that rule pinned us to channel 6
	 * for 1 slot of 16 instead of channel 36 for 6 of 16 -- the peer's worst
	 * channel over its best. The point of pinning is to maximise overlap, so
	 * overlap has to win. */
	if (!count[best])
		return 0; /* sequence names no channel at all; do not invent one */
	if (prefer && count[prefer] == count[best])
		return prefer;
	return best;
}

int awdl_chanseq_count_chan(const struct awdl_chan *seq, enum awdl_chan_encoding enc, uint8_t chan) {
	int n = 0;
	for (int i = 0; i < AWDL_CHANSEQ_LENGTH; i++)
		if (awdl_chan_num(seq[i], enc) == chan)
			n++;
	return n;
}

uint8_t awdl_chan_num(struct awdl_chan chan, enum awdl_chan_encoding enc) {
	switch (enc) {
		case AWDL_CHAN_ENC_SIMPLE:
			return chan.simple.chan_num;
		case AWDL_CHAN_ENC_LEGACY:
			return chan.legacy.chan_num;
		case AWDL_CHAN_ENC_OPCLASS:
			return chan.opclass.chan_num;
		default:
			return 0; /* unknown encoding */
	}
}

int awdl_chan_encoding_size(enum awdl_chan_encoding enc) {
	switch (enc) {
		case AWDL_CHAN_ENC_SIMPLE:
			return 1;
		case AWDL_CHAN_ENC_LEGACY:
		case AWDL_CHAN_ENC_OPCLASS:
			return 2;
		default:
			return -1; /* unknown encoding */
	}
}

/* adapted from iw/util.c */
int ieee80211_channel_to_frequency(int chan) {
	/* see 802.11 17.3.8.3.2 and Annex J
	 * there are overlapping channel numbers in 5GHz and 2GHz bands */
	if (chan <= 0)
		return 0; /* not supported */

	/* 2 GHz band */
	if (chan == 14)
		return 2484;
	else if (chan < 14)
		return 2407 + chan * 5;

	/* 5 GHz band */
	if (chan < 32)
		return 0; /* not supported */

	if (chan >= 182 && chan <= 196)
		return 4000 + chan * 5;
	else
		return 5000 + chan * 5;

}

/* from iw/util.c */
int ieee80211_frequency_to_channel(int freq) {
	/* see 802.11-2007 17.3.8.3.2 and Annex J */
	if (freq == 2484)
		return 14;
	else if (freq < 2484)
		return (freq - 2407) / 5;
	else if (freq >= 4910 && freq <= 4980)
		return (freq - 4000) / 5;
	else if (freq <= 45000) /* DMG band lower limit */
		return (freq - 5000) / 5;
	else if (freq >= 58320 && freq <= 64800)
		return (freq - 56160) / 2160;
	else
		return 0;
}
