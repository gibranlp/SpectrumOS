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

#include "schedule.h"

#include "log.h"

double usec_to_sec(uint64_t usec) {
	return usec / 1000000.;
}

uint64_t sec_to_usec(double sec) {
	return sec * 1000000;
}

bool awdl_same_channel_as_peer(const struct awdl_state *state, uint64_t now, const struct awdl_peer *peer) {
	int own_slot, peer_slot;
	int own_chan, peer_chan;

	own_slot = awdl_sync_current_eaw(now, &state->sync) % AWDL_CHANSEQ_LENGTH;

	/* Deliberately does NOT apply peer->sync_offset unless the ROTATE strategy
	 * asked for it.
	 *
	 * This function gates every unicast transmission (awdl_can_send_unicast_in
	 * -> awdl_send_unicast): if it says we are never on-channel with the peer,
	 * OWL silently stops transmitting while continuing to receive perfectly.
	 * Upstream read sync_offset here but never assigned it, so it was 0 for
	 * every peer and this was effectively `own_slot == peer_slot`. Populating
	 * it therefore changed behaviour that had been load-bearing-by-accident for
	 * years, and the TX path is not the place to find out whether the new value
	 * is right.
	 *
	 * It is also not obviously right in general: awdl_sync_error_tu() compares
	 * the peer's free-running aw_counter against ours, which is only meaningful
	 * for the peer our clock actually tracks -- the elected master. For anyone
	 * else the difference is arbitrary. */
	peer_slot = (state->channel.strategy == AWDL_CHANSEQ_ROTATE)
	            ? awdl_sync_current_eaw(awdl_peer_time(now, peer), &state->sync) % AWDL_CHANSEQ_LENGTH
	            : own_slot;

	/* With -F that channel is where we are in every slot, not only in the
	 * slots we advertise. Those are the sync master's; a peer that offers our
	 * channel in more slots than the master does (an iPhone adds some once it
	 * sees we are only ever there) can be sent to in all of them. */
	if (state->channel.fixed_radio)
		own_chan = awdl_chan_num(state->channel.master, AWDL_CHAN_ENC_OPCLASS);
	else
		own_chan = awdl_chan_num(state->channel.sequence[own_slot], state->channel.enc);
	/* The peer's sequence must be decoded with the encoding it ARRIVED in, not
	 * with ours. They are different fields for a reason: the raw TLV bytes are
	 * stored verbatim, and {chan_num, opclass} read as {flags, chan_num} yields
	 * plausible-looking nonsense.
	 *
	 * Upstream used state->channel.enc here and got away with it, because
	 * adopting a peer's sequence also adopted its encoding, so the two always
	 * agreed. Anything that sets our encoding independently -- such as pinning a
	 * channel -- breaks that coupling, and then this comparison never matches,
	 * the unicast gate never opens, and OWL receives perfectly while
	 * transmitting nothing at all. */
	peer_chan = awdl_chan_num(peer->sequence[peer_slot], peer->sequence_enc);

	/* Instrumentation for the "receives fine, transmits nothing" failure.
	 * This gate is the only thing standing between a queued unicast frame and
	 * the air, and when it is stuck shut the symptom is indistinguishable from
	 * a radio problem: mDNS multicast flows, the peer's frames arrive, and our
	 * TCP replies simply never appear. Log what it actually compared, rate
	 * limited to once a second so -vv stays readable. */
	{
		static uint64_t last_log_us = 0;
		if (now - last_log_us > 1000000) {
			last_log_us = now;
			log_debug("GATE slot %d own_chan %d (enc %d) peer_chan %d (enc %d) seq[%d]=%04x -> %s",
			          own_slot, own_chan, state->channel.enc, peer_chan, peer->sequence_enc,
			          peer_slot, (unsigned) ((peer->sequence[peer_slot].val[1] << 8)
			                                 | peer->sequence[peer_slot].val[0]),
			          (own_chan && (own_chan == peer_chan)) ? "OPEN" : "SHUT");
		}
	}

	return own_chan && (own_chan == peer_chan);
}

int awdl_is_multicast_eaw(const struct awdl_state *state, uint64_t now) {
	uint16_t slot = awdl_sync_current_eaw(now, &state->sync) % AWDL_CHANSEQ_LENGTH;

	/* Slots 0 and 10 are where Apple devices send multicast, each on whatever
	 * channel its sequence has there, and for a channel nobody favours that is
	 * never ours: an iPhone advertising
	 *   149,149,149,0,0,0,0,0,6,149,149,0,0,0,0,0
	 * is on channel 6 in slot 8 alone, and did not hear a radio fixed there
	 * until it moved slot 0 to channel 6 a minute later. Nor can we tell from
	 * here in which slots, or for how much of one, a peer really listens on a
	 * channel it only visits. So with -F multicast goes out as it comes, and
	 * whoever wants it heard repeats it across a whole period of 16 slots, as
	 * omdrop-owl's announcer does. */
	if (state->channel.fixed_radio)
		return 1;
	return slot == 0 || slot == 10;
}

double awdl_can_send_in(const struct awdl_state *state, uint64_t now, int guard) {
	uint64_t next_aw = awdl_sync_next_aw_us(now, &state->sync);
	uint64_t _guard = ieee80211_tu_to_usec(guard);
	uint64_t eaw = ieee80211_tu_to_usec(64);

	return (next_aw < _guard) ? -usec_to_sec(_guard - next_aw) : ((eaw - next_aw < _guard) ? usec_to_sec(
		(_guard - (eaw - next_aw))) : 0);
}

double awdl_can_send_unicast_in(const struct awdl_state *state, const struct awdl_peer *peer, uint64_t now, int guard) {
	uint64_t next_aw = awdl_sync_next_aw_us(now, &state->sync);
	uint64_t _guard = ieee80211_tu_to_usec(guard);
	uint64_t eaw = ieee80211_tu_to_usec(64);

	if (!awdl_same_channel_as_peer(state, now, peer))
		return usec_to_sec(next_aw); /* try again in the next slot */

	if (next_aw < _guard) { /* we are at the end of slot */
		if (awdl_same_channel_as_peer(state, now + eaw, peer)) {
			return 0; /* we are on the same channel in next slot, ignore guard */
		} else {
			return -usec_to_sec(_guard - next_aw);
		}
	} else if (eaw - next_aw < _guard) {
		if (awdl_same_channel_as_peer(state, now - eaw, peer)) {
			return 0; /* we were on the same channel last slot, ignore guard */
		} else {
			return usec_to_sec(_guard - (eaw - next_aw));
		}
	} else {
		return 0; /* we are inside guard interval */
	}
}
