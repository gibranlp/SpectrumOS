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

#include "core.h"
#include "netutils.h"

#include "log.h"
#include "wire.h"
#include "rx.h"
#include "tx.h"
#include "schedule.h"

#include <signal.h>
#include <errno.h>

#ifdef __APPLE__
# define SIGSTATS SIGINFO
#else
# define SIGSTATS SIGUSR1
#endif

#define ETHER_LENGTH 14
#define ETHER_DST_OFFSET 0
#define ETHER_SRC_OFFSET 6
#define ETHER_ETHERTYPE_OFFSET 12

#define POLL_NEW_UNICAST 0x1
#define POLL_NEW_MULTICAST 0x2

static void dump_frame(const char *dump_file, const struct pcap_pkthdr *hdr, const uint8_t *buf) {
	if (dump_file) {
		/* Make sure file exists because 'pcap_dump_open_append' does NOT create file for you */
		fclose(fopen(dump_file, "a+"));
		pcap_t *p = pcap_open_dead(DLT_IEEE802_11_RADIO, 65535);
		pcap_dumper_t *dumper = pcap_dump_open_append(p, dump_file);
		pcap_dump((u_char *) dumper, hdr, buf);
		pcap_close(p);
		pcap_dump_close(dumper);
	}
}

static void ev_timer_rearm(struct ev_loop *loop, ev_timer *timer, double in) {
	ev_timer_stop(loop, timer);
	ev_timer_set(timer, in, 0.);
	ev_timer_start(loop, timer);
}

void wlan_device_ready(struct ev_loop *loop, ev_io *handle, int revents) {
	struct daemon_state *state = handle->data;
	int cnt = pcap_dispatch(state->io.wlan_handle, 1, &awdl_receive_frame, handle->data);
	if (cnt > 0)
		ev_feed_event(loop, handle, revents);
}

static int poll_host_device(struct daemon_state *state) {
	struct buf *buf = NULL;
	int result = 0;
	while (!state->next && !circular_buf_full(state->tx_queue_multicast)) {
		buf = buf_new_owned(ETHER_MAX_LEN);
		int len = buf_len(buf);
		if (host_recv(&state->io, (uint8_t *) buf_data(buf), &len) < 0) {
			goto wire_error;
		} else {
			bool is_multicast;
			struct ether_addr dst;
			buf_take(buf, buf_len(buf) - len);
			READ_ETHER_ADDR(buf, ETHER_DST_OFFSET, &dst);
			is_multicast = dst.ether_addr_octet[0] & 0x01;
			if (is_multicast) {
				circular_buf_put(state->tx_queue_multicast, buf);
				result |= POLL_NEW_MULTICAST;
			} else { /* unicast */
				state->next = buf;
				result |= POLL_NEW_UNICAST;
			}
		}
	}
	return result;
wire_error:
	if (buf)
		buf_free(buf);
	return result;
}

void host_device_ready(struct ev_loop *loop, ev_io *handle, int revents) {
	(void) loop;
	(void) revents; /* should always be EV_READ */
	struct daemon_state *state = handle->data;

	int poll_result = poll_host_device(state); /* fill TX queues */
	if (poll_result & POLL_NEW_MULTICAST)
		awdl_send_multicast(loop, &state->ev_state.tx_mcast_timer, 0);
	if (poll_result & POLL_NEW_UNICAST)
		awdl_send_unicast(loop, &state->ev_state.tx_timer, 0);
}

void awdl_receive_frame(uint8_t *user, const struct pcap_pkthdr *hdr, const uint8_t *buf) {
#define MAX_NUM_AMPDU 16 /* TODO lookup this constant from the standard */
	struct daemon_state *state = (void *) user;
	int result;
	const struct buf *frame = buf_new_const(buf, hdr->caplen);
	struct buf *data_arr[MAX_NUM_AMPDU];
	struct buf **data = &data_arr[0];
	result = awdl_rx(frame, &data, &data_arr[MAX_NUM_AMPDU], &state->awdl_state);
	/* An A-MSDU that fails part way has converted the subframes before the
	 * failure: free those too, unsent. */
	for (struct buf **data_start = &data_arr[0]; data_start < data; data_start++) {
		if (result == RX_OK)
			host_send(&state->io, buf_data(*data_start), buf_len(*data_start));
		buf_free(*data_start);
	}
	if (result < RX_OK) {
		log_warn("unhandled frame (%d)", result);
		dump_frame(state->dump, hdr, buf);
		state->awdl_state.stats.rx_unknown++;
	}
	buf_free(frame);
}

int awdl_send_data(const struct buf *buf, const struct io_state *io_state,
                   struct awdl_state *awdl_state, struct ieee80211_state *ieee80211_state) {
	uint8_t awdl_data[65535];
	int awdl_data_len;
	uint16_t ethertype;
	struct ether_addr src, dst;
	uint64_t now;
	uint16_t period, slot, tu;

	READ_BE16(buf, ETHER_ETHERTYPE_OFFSET, &ethertype);
	READ_ETHER_ADDR(buf, ETHER_DST_OFFSET, &dst);
	READ_ETHER_ADDR(buf, ETHER_SRC_OFFSET, &src);

	/* Read past the Ethernet header rather than strip it, so a frame that
	 * comes back TX_AGAIN can be handed in again unchanged. */
	awdl_data_len = awdl_init_full_data_frame(awdl_data, &src, &dst,
	                                          buf_data(buf) + ETHER_LENGTH, buf_len(buf) - ETHER_LENGTH,
	                                          awdl_state, ieee80211_state);
	now = clock_time_us();
	period = awdl_sync_current_eaw(now, &awdl_state->sync) / AWDL_CHANSEQ_LENGTH;
	slot = awdl_sync_current_eaw(now, &awdl_state->sync) % AWDL_CHANSEQ_LENGTH;
	tu = awdl_sync_next_aw_tu(now, &awdl_state->sync);
	log_trace("Send data (len %d) to %s (%u.%u.%u)", awdl_data_len,
	          ether_ntoa(&dst), period, slot, tu);
	int err = wlan_send(io_state, awdl_data, awdl_data_len);
	if (err == -EAGAIN)
		return TX_AGAIN;
	awdl_state->stats.tx_data++;
	if (err < 0)
		return TX_FAIL;
	return TX_OK;

wire_error:
	return TX_FAIL;
}

void awdl_send_action(struct daemon_state *state, enum awdl_action_type type) {
	uint8_t buf[65535];
	int len;

	len = awdl_init_full_action_frame(buf, &state->awdl_state, &state->ieee80211_state, type);
	if (len < 0)
		return;
	log_trace("send %s", awdl_frame_as_str(type));
	wlan_send(&state->io, buf, len);

	state->awdl_state.stats.tx_action++;
}

void awdl_send_psf(struct ev_loop *loop, ev_timer *handle, int revents) {
	(void) loop;
	(void) revents;
	awdl_send_action(handle->data, AWDL_ACTION_PSF);
}

void awdl_send_mif(struct ev_loop *loop, ev_timer *timer, int revents) {
	(void) revents;
	struct daemon_state *state = timer->data;
	struct awdl_state *awdl_state = &state->awdl_state;
	uint64_t now, next_aw, eaw_len;

	now = clock_time_us();
	next_aw = awdl_sync_next_aw_us(now, &awdl_state->sync);
	eaw_len = awdl_state->sync.presence_mode * awdl_state->sync.aw_period;

	/* Schedule MIF in middle of sequence (if non-zero) */
	if (awdl_chan_num(awdl_state->channel.current, awdl_state->channel.enc) > 0)
		awdl_send_action(state, AWDL_ACTION_MIF);

	/* schedule next in the middle of EAW */
	ev_timer_rearm(loop, timer, usec_to_sec(next_aw + ieee80211_tu_to_usec(eaw_len / 2)));
}

void awdl_send_unicast(struct ev_loop *loop, ev_timer *timer, int revents) {
	(void) revents;
	struct daemon_state *state = timer->data;
	struct awdl_state *awdl_state = &state->awdl_state;
	uint64_t now = clock_time_us();
	double in = 0;

	if (state->next) { /* we have something to send */
		struct awdl_peer *peer;
		struct ether_addr dst;
		read_ether_addr(state->next, ETHER_DST_OFFSET, &dst);
		if (compare_ether_addr(&dst, &awdl_state->self_address) == 0) {
			/* send back to self */
			host_send(&state->io, buf_data(state->next), buf_len(state->next));
			buf_free(state->next);
			state->next = NULL;
		} else if (awdl_peer_get(awdl_state->peers.peers, &dst, &peer) < 0) {
			log_debug("Drop frame to non-peer %s", ether_ntoa(&dst));
			buf_free(state->next);
			state->next = NULL;
		} else {
			in = awdl_can_send_unicast_in(awdl_state, peer, now, AWDL_UNICAST_GUARD_TU);
			if (in == 0) { /* send now */
				if (awdl_send_data(state->next, &state->io, &state->awdl_state, &state->ieee80211_state) == TX_AGAIN) {
					/* Queue full: keep the frame and come back in half a
					 * millisecond, without blocking the loop. The gate above is
					 * checked again then, so it still only leaves while the
					 * peer is on our channel. */
					in = 0.0005;
				} else {
					buf_free(state->next);
					state->next = NULL;
					state->awdl_state.stats.tx_data_unicast++;
				}
			} else { /* try later */
				if (in < 0) /* we are at the end of slot but within guard */
					in = -in + usec_to_sec(ieee80211_tu_to_usec(AWDL_UNICAST_GUARD_TU));
			}
		}
	}

	/* rearm if more unicast frames available */
	if (state->next) {
		log_trace("awdl_send_unicast: retry in %lu TU", ieee80211_usec_to_tu(sec_to_usec(in)));
		ev_timer_rearm(loop, timer, in);
	} else {
		/* poll for more frames to keep queue full */
		ev_feed_event(loop, &state->ev_state.read_host, 0);
	}
}

void awdl_send_multicast(struct ev_loop *loop, ev_timer *timer, int revents) {
	(void) revents;
	struct daemon_state *state = timer->data;
	struct awdl_state *awdl_state = &state->awdl_state;
	uint64_t now = clock_time_us();
	double in = 0;

	if (!circular_buf_empty(state->tx_queue_multicast)) { /* we have something to send */
		/* The multicast guard keeps clear of the slot's first and last AW, for
		 * peers still arriving on the channel. With -F the first AW may be all
		 * a peer spends on ours, so only the unicast guard applies. */
		int guard = awdl_state->channel.fixed_radio ? AWDL_UNICAST_GUARD_TU : AWDL_MULTICAST_GUARD_TU;
		in = awdl_can_send_in(awdl_state, now, guard);
		if (awdl_is_multicast_eaw(awdl_state, now) && (in == 0)) { /* we can send now */
			void *next;
			circular_buf_get(state->tx_queue_multicast, &next, 0);
			awdl_send_data((struct buf *) next, &state->io, &state->awdl_state, &state->ieee80211_state);
			buf_free(next);
			state->awdl_state.stats.tx_data_multicast++;
		} else { /* try later */
			if (in == 0) /* try again next EAW */
				in = usec_to_sec(ieee80211_tu_to_usec(64));
			else if (in < 0) /* we are at the end of slot but within guard */
				in = -in + usec_to_sec(ieee80211_tu_to_usec(guard));
		}
	}

	/* rearm if more multicast frames available */
	if (!circular_buf_empty(state->tx_queue_multicast)) {
		log_trace("awdl_send_multicast: retry in %lu TU", ieee80211_usec_to_tu(sec_to_usec(in)));
		ev_timer_rearm(loop, timer, in);
	} else {
		/* poll for more frames to keep queue full */
		ev_feed_event(loop, &state->ev_state.read_host, 0);
	}
}

void chan_nl_ready(struct ev_loop *loop, ev_io *handle, int revents) {
	(void) loop;
	(void) handle;
	(void) revents;
	set_channel_drain();
}

void awdl_switch_channel(struct ev_loop *loop, ev_timer *timer, int revents) {
	(void) revents;
	uint64_t now, next_aw;
	int slot;
	struct awdl_chan chan_new;
	int chan_num_new, chan_num_old;
	struct daemon_state *state = timer->data;
	struct awdl_state *awdl_state = &state->awdl_state;

	chan_num_old = awdl_chan_num(awdl_state->channel.current, awdl_state->channel.enc);

	now = clock_time_us();
	slot = awdl_sync_current_eaw(now, &awdl_state->sync) % AWDL_CHANSEQ_LENGTH;
	chan_new = awdl_state->channel.sequence[slot];
	chan_num_new = awdl_chan_num(awdl_state->channel.sequence[slot], awdl_state->channel.enc);

	if (chan_num_new && (chan_num_new != chan_num_old)) {
		int err = 0;
		log_debug("switch channel to %d (slot %d)", chan_num_new, slot);
		if (!state->io.wlan_is_file) {
			/* NOTE: upstream called is_channel_available() here and then
			 * discarded the result. That call issues a full split wiphy dump
			 * over netlink and blocks the event loop -- harmless with a static
			 * 16-slot sequence (this branch never re-enters), but once we
			 * actually follow a peer's sequence it runs on every transition,
			 * against a 16 TU (16384 us) availability window. It is dropped.
			 *
			 * set_channel() no longer waits for the kernel's ACK either; its
			 * reply is collected by chan_nl_ready(). The wait was measured at a
			 * mean 8.5 ms over 734 switches, which at 3.5 switches/s is about
			 * 30% of the event loop spent blocked inside the loop itself. */
			uint64_t t0 = clock_time_us();
			err = set_channel(state->io.wlan_ifindex, chan_num_new);
			log_debug("set_channel(%d) queued in %llu us", chan_num_new,
			          (unsigned long long) (clock_time_us() - t0));
		}
		if (err < 0) {
			/* The request could not even be sent. Do NOT advance
			 * channel.current: the radio did not move, and lying about it
			 * desyncs our idea of the channel from the card. A channel the
			 * kernel accepts here but rejects later is no longer visible to us
			 * -- on this hardware that was only ever detectable from radiotap
			 * anyway, since iw reports the requested channel regardless. */
			log_warn("could not request switch to channel %d (slot %d), radio still on %d",
			         chan_num_new, slot, chan_num_old);
		} else {
			awdl_state->channel.current = chan_new;
		}
	}

	next_aw = awdl_sync_next_aw_us(now, &awdl_state->sync);

	ev_timer_rearm(loop, timer, usec_to_sec(next_aw));
}

static void awdl_neighbor_add(struct awdl_peer *p, void *_io_state) {
	struct io_state *io_state = _io_state;
	neighbor_add_rfc4291(io_state->host_ifindex, &p->addr);
}

static void awdl_neighbor_remove(struct awdl_peer *p, void *_io_state) {
	struct io_state *io_state = _io_state;
	neighbor_remove_rfc4291(io_state->host_ifindex, &p->addr);
}

/*
 * Pick the peer whose advertised channel sequence should drive ours: the
 * elected sync master if it is in the peer table and has sent us a sequence.
 *
 * Kept deliberately simple. An earlier version preferred "the peer that most
 * recently sent us data" instead, which flapped between the phone and a
 * bystander at the 1 Hz tick and made throughput 6x worse (FINDINGS 17). Under
 * PIN the question mostly stops mattering anyway, because every Apple device in
 * the room names the same social channel and so maps to the same pin.
 */
static struct awdl_peer *awdl_chanseq_source(struct awdl_state *awdl) {
	struct awdl_peer *master;

	if (awdl_election_is_sync_master(&awdl->election, &awdl->self_address))
		return NULL;
	if (awdl_peer_get(awdl->peers.peers, &awdl->election.sync_addr, &master) < 0)
		return NULL; /* elected master is not in the peer table */
	if (!master->has_sequence)
		return NULL; /* no chanseq TLV seen from it yet; keep what we have */
	return master;
}

/*
 * Derive our own channel sequence from a peer's, according to the configured
 * strategy, so that we are on-channel during that peer's availability windows.
 * Reverts to our own static sequence when we are our own sync master again
 * (e.g. the master aged out of the peer table).
 *
 * The peer's sequence is stored as raw TLV bytes, so its encoding must be
 * adopted along with it -- decoding those bytes with a different encoding
 * yields plausible-looking but wrong channel numbers.
 */
static void awdl_adopt_chanseq(struct daemon_state *state) {
	struct awdl_state *awdl = &state->awdl_state;
	struct awdl_peer *src;
	struct awdl_chan seq[AWDL_CHANSEQ_LENGTH];
	enum awdl_chan_encoding enc;
	uint64_t now = clock_time_us();

	src = awdl_chanseq_source(awdl);

	if (!src) {
		if (awdl->channel.sequence_from_peer) {
			log_info("no sync master, reverting to static channel sequence");
			awdl_chanseq_init_static(awdl->channel.sequence, &awdl->channel.master);
			awdl->channel.enc = AWDL_CHAN_ENC_OPCLASS;
			awdl->channel.sequence_from_peer = 0;
			awdl->channel.pinned_chan = 0;
			memset(&awdl->channel.seq_src, 0, sizeof(awdl->channel.seq_src));
		}
		return;
	}

	switch (awdl->channel.strategy) {
		case AWDL_CHANSEQ_PIN: {
			/* Sit on the peer's dominant social channel in every slot. We have no
			 * infra association to service on the monitor vif, so there is nothing
			 * to gain by ever leaving it -- and everything to lose, because an
			 * iPhone widens its own sequence from 2 slots to as many as 12 during a
			 * transfer and we want to be present for all of them without waiting
			 * for a 1 Hz tick to notice the change. Being on one channel in all 16
			 * slots is also phase-invariant, so the FINDINGS 17 failure (right
			 * channels, wrong times) cannot recur here by construction. */
			uint8_t want = awdl_chanseq_dominant_chan(src->sequence, src->sequence_enc,
			                                          awdl_chan_num(awdl->channel.master,
			                                                        AWDL_CHAN_ENC_OPCLASS));
			struct awdl_chan chan;

			/* -F: the radio never leaves -c's channel, so that is the one we are on
			 * in every slot, whatever the peer favours. */
			if (awdl->channel.fixed_radio)
				want = awdl_chan_num(awdl->channel.master, AWDL_CHAN_ENC_OPCLASS);

			if (!want)
				return; /* peer advertised nothing usable; keep what we have */
			if (awdl->channel.pinned_chan == want)
				return; /* already pinned there -- no log spam, no rewrite */

			chan = (struct awdl_chan) {{{want, want > 14 ? 0x80 : 0x51}}};
			awdl_chanseq_init_static(seq, &chan);
			enc = AWDL_CHAN_ENC_OPCLASS;
			awdl->channel.pinned_chan = want;
			log_info("pinning channel %d in all slots (dominant channel of %s (%s))",
			         want, ether_ntoa(&src->addr), src->name);
			break;
		}
		case AWDL_CHANSEQ_ROTATE: {
			/* Right channels at the right times: the peer's slot array is written
			 * in the peer's availability-window phase, but awdl_switch_channel()
			 * indexes our sequence in *ours*. Rotating by the difference puts the
			 * peer's slots where our clock will actually look for them.
			 *
			 * This is the correct form of the fix that FINDINGS 17 retracted. Note
			 * it is a no-op whenever the source is the elected master, since our
			 * phase is defined by that peer and the delta is then zero -- which is
			 * exactly why upstream never needed it. */
			int delta = ((int) awdl_sync_current_eaw(awdl_peer_time(now, src), &awdl->sync) -
			             (int) awdl_sync_current_eaw(now, &awdl->sync)) % AWDL_CHANSEQ_LENGTH;

			if (delta < 0)
				delta += AWDL_CHANSEQ_LENGTH;

			/* Hysteresis: require two consecutive ticks to agree before moving.
			 * Without it a peer whose phase sits near a window boundary makes the
			 * delta oscillate between two neighbouring values, rewriting the
			 * sequence every second -- the same flapping that made the FINDINGS 17
			 * attempt worse, arriving by a different route. */
			if (!awdl->channel.rot_valid) {
				awdl->channel.rot_delta = delta;
				awdl->channel.rot_valid = 1;
			} else if (delta != awdl->channel.rot_delta) {
				if (delta == awdl->channel.rot_delta_pending) {
					log_debug("rotation delta %d -> %d (confirmed)", awdl->channel.rot_delta, delta);
					awdl->channel.rot_delta = delta;
				} else {
					awdl->channel.rot_delta_pending = delta;
					return; /* unconfirmed: leave the sequence alone this tick */
				}
			}
			awdl_chanseq_rotate(seq, src->sequence, awdl->channel.rot_delta);
			enc = src->sequence_enc;
			break;
		}
		case AWDL_CHANSEQ_WIDEN: {
			/* The peer's own sequence, widened into some of its empty slots.
			 * §25 found the phone answers a sequence copied from it and ignores
			 * one pinned to a single channel; this is the ladder between those,
			 * so the width at which it stops answering is a measurement rather
			 * than a guess. */
			int filled = awdl_chanseq_widen(seq, src->sequence, src->sequence_enc,
			                                awdl->channel.widen_max);
			uint8_t ours = awdl_chan_num(awdl->channel.master, AWDL_CHAN_ENC_OPCLASS);
			int kept = ours ? awdl_chanseq_count_chan(src->sequence, src->sequence_enc, ours) : 0;

			enc = src->sequence_enc;
			if (filled)
				log_debug("widened %s's sequence by %d slot(s)", ether_ntoa(&src->addr), filled);

			/* Report the overlap even though we do not act on it here. Widening
			 * changes what we ADVERTISE; it cannot move the radio, which a
			 * P2P-GO chanctx holds on one channel. So "can this peer reach us"
			 * has the same answer under every strategy, and until now it was
			 * only ever measured under intersect -- which meant that selecting
			 * widen silently blinded the one line that carries it, and anything
			 * parsing this log went on reporting a state it was no longer
			 * measuring.
			 *
			 * Control flow differs from intersect: widen has nothing to withhold,
			 * so with zero overlap it reports and continues rather than bailing.
			 *
			 * The debug line retains the literal "intersect:" prefix because it is
			 * a wire format with a consumer (airdropd greps for it), not a
			 * description, even though nothing was intersected here. */
			if (!kept) {
				uint8_t want = awdl_chanseq_dominant_chan(src->sequence, src->sequence_enc, 0);

				log_info("NO OVERLAP with %s on ch %d - peer wants ch %d",
				         ether_ntoa(&src->addr), ours, want);
			} else {
				log_debug("intersect: %d/%d slots overlap %s on ch %d",
				          kept, AWDL_CHANSEQ_LENGTH, ether_ntoa(&src->addr), ours);
			}
			break;
		}
		case AWDL_CHANSEQ_INTERSECT: {
			/* Advertise only the slots we can actually serve. Our channel is the
			 * static one from -c, which is what the P2P-GO chanctx holds the radio
			 * on; awdl_switch_channel() cannot move off it, so every other slot in
			 * the peer's sequence is a slot we would be claiming and then missing. */
			uint8_t ours = awdl_chan_num(awdl->channel.master, AWDL_CHAN_ENC_OPCLASS);
			int kept = awdl_chanseq_intersect(seq, src->sequence, src->sequence_enc, ours);

			if (awdl->channel.fixed_radio) {
				/* -F: we are on our channel in every slot, so the honest sequence
				 * has every slot in which any peer is there, not only the
				 * master's. It matters because a peer sends to us only in slots
				 * that both sequences give to the channel, and the peer sending
				 * is rarely the master: an iPhone mid-transfer advertised
				 *   149 x8, 6,6,149,6,6,6,149,149
				 * while its master, an idle iPad, had channel 6 in slots 0 and 8.
				 * Following the iPad: 27 kB/s. Following the phone: 150 kB/s.
				 * Bytes are still only ever copied from a peer's own sequence, and
				 * only from peers whose slots line up with ours: a peer from
				 * another cluster means a different slot by the same index. */
				struct awdl_peer *p;
				awdl_peers_it_t it = awdl_peers_it_new(awdl->peers.peers);

				while (awdl_peers_it_next(it, &p) == PEERS_OK) {
					int64_t off_tu;

					if (p == src || !p->is_valid || !p->has_sequence || !p->has_sync_offset ||
					    p->sequence_enc != src->sequence_enc)
						continue;
					/* phase difference, within one period of 16 slots of 64 TU */
					off_tu = ((p->sync_offset / 1024) % 1024 + 1024 + 512) % 1024 - 512;
					if (off_tu > 16 || off_tu < -16)
						continue;
					for (int i = 0; i < AWDL_CHANSEQ_LENGTH; i++) {
						if (!awdl_chan_num(seq[i], src->sequence_enc) &&
						    awdl_chan_num(p->sequence[i], p->sequence_enc) == ours) {
							seq[i] = p->sequence[i];
							kept++;
						}
					}
				}
				awdl_peers_it_free(it);
			}

			if (!kept) {
				/* No overlap at all this tick. Keep whatever we last advertised
				 * rather than announcing an all-empty sequence, which says "never
				 * available" and would have the phone stop addressing us entirely.
				 *
				 * This is the silent-failure case: everything downstream looks
				 * healthy (owl up, awdl0 up, opendrop listening, mDNS leaving the
				 * radio) while not one slot can carry a frame to this peer. It is
				 * what "it just stopped appearing" looked like from outside, so it
				 * is logged at INFO with the channel we WOULD need, loudly enough
				 * for airdropd to notice and act on it. */
				uint8_t want = awdl_chanseq_dominant_chan(src->sequence, src->sequence_enc, 0);

				log_info("NO OVERLAP with %s on ch %d - peer wants ch %d",
				         ether_ntoa(&src->addr), ours, want);
				return;
			}
			log_debug("intersect: %d/%d slots overlap %s on ch %d",
			          kept, AWDL_CHANSEQ_LENGTH, ether_ntoa(&src->addr), ours);
			enc = src->sequence_enc;
			break;
		}
		case AWDL_CHANSEQ_VERBATIM:
		default:
			memcpy(seq, src->sequence, sizeof(seq));
			enc = src->sequence_enc;
			break;
	}

	if (awdl->channel.enc != enc || memcmp(awdl->channel.sequence, seq, sizeof(seq))) {
		awdl->channel.enc = enc;
		memcpy(awdl->channel.sequence, seq, sizeof(seq));
		awdl->channel.sequence_from_peer = 1;
		awdl->channel.seq_src = src->addr;
		if (awdl->channel.strategy != AWDL_CHANSEQ_PIN)
			log_info("following channel sequence of sync master %s (%s), enc %d",
			         ether_ntoa(&src->addr), src->name, enc);
	}
}

void awdl_clean_peers(struct ev_loop *loop, ev_timer *timer, int revents) {
	(void) loop;
	(void) revents; /* should always be EV_TIMER */
	uint64_t cutoff_time;
	struct daemon_state *state;

	state = (struct daemon_state *) timer->data;
	cutoff_time = clock_time_us() - state->awdl_state.peers.timeout;

	awdl_peers_remove(state->awdl_state.peers.peers, cutoff_time,
	                  state->awdl_state.peer_remove_cb, state->awdl_state.peer_remove_cb_data);

	/* TODO for now run election immediately after clean up; might consider seperate timer for this */
	awdl_election_run(&state->awdl_state.election, &state->awdl_state.peers);

	awdl_adopt_chanseq(state);

	ev_timer_again(loop, timer);
}

void awdl_print_stats(struct ev_loop *loop, ev_signal *handle, int revents) {
	(void) loop;
	(void) revents; /* should always be EV_TIMER */
	struct awdl_stats *stats = &((struct daemon_state *) handle->data)->awdl_state.stats;

	log_info("STATISTICS");
	log_info(" TX action %llu, data %llu, unicast %llu, multicast %llu",
	         stats->tx_action, stats->tx_data, stats->tx_data_unicast, stats->tx_data_multicast);
	log_info(" RX action %llu, data %llu, unknown %llu",
	         stats->rx_action, stats->rx_data, stats->rx_unknown);
}

/*
 * The same counters on a timer, so every run records them without anyone having
 * to remember to send SIGUSR1 -- which nothing does, since the harnesses stop
 * OWL with SIGTERM.
 *
 * These split the two failure modes that look identical from outside. If a
 * transfer stalls and tx_data_unicast is NOT advancing, the scheduler is
 * refusing to transmit (awdl_can_send_unicast_in never returns 0, i.e. we
 * believe we are never on-channel with the peer). If it IS advancing while the
 * peer plainly hears nothing, the frames are leaving OWL and dying in the
 * radio. Two completely different investigations, and they were indistinguishable
 * from the capture alone during the TX regression of §23.
 */
void awdl_stats_tick(struct ev_loop *loop, ev_timer *timer, int revents) {
	(void) loop;
	(void) revents;
	struct awdl_stats *stats = &((struct daemon_state *) timer->data)->awdl_state.stats;

	log_info("STATS tx_action %llu tx_data %llu tx_unicast %llu tx_multicast %llu | "
	         "rx_action %llu rx_data %llu rx_unknown %llu",
	         stats->tx_action, stats->tx_data, stats->tx_data_unicast, stats->tx_data_multicast,
	         stats->rx_action, stats->rx_data, stats->rx_unknown);
}

int awdl_init(struct daemon_state *state, const char *wlan, const char *host, struct awdl_chan chan, const char *dump) {
	int err;
	char hostname[HOST_NAME_LENGTH_MAX + 1];

	err = netutils_init();
	if (err < 0)
		return err;

	err = io_state_init(&state->io, wlan, host, &AWDL_BSSID);
	if (err < 0)
		return err;

	err = get_hostname(hostname, sizeof(hostname));
	if (err < 0)
		return err;

	awdl_init_state(&state->awdl_state, hostname, &state->io.if_ether_addr, chan, clock_time_us());
	state->awdl_state.peer_cb = awdl_neighbor_add;
	state->awdl_state.peer_cb_data = (void *) &state->io;
	state->awdl_state.peer_remove_cb = awdl_neighbor_remove;
	state->awdl_state.peer_remove_cb_data = (void *) &state->io;
	ieee80211_init_state(&state->ieee80211_state);

	state->next = NULL;
	state->tx_queue_multicast = circular_buf_init(16);
	state->dump = dump;

	return 0;
}

void awdl_free(struct daemon_state *state) {
	circular_buf_free(state->tx_queue_multicast);
	io_state_free(&state->io);
	netutils_cleanup();
}

void awdl_schedule(struct ev_loop *loop, struct daemon_state *state) {

	state->ev_state.loop = loop;

	/* Timer for channel switching */
	state->ev_state.chan_timer.data = (void *) state;
	ev_timer_init(&state->ev_state.chan_timer, awdl_switch_channel, 0, 0);
	ev_timer_start(loop, &state->ev_state.chan_timer);

	/* Timer for peer table cleanup */
	state->ev_state.peer_timer.data = (void *) state;
	ev_timer_init(&state->ev_state.peer_timer, awdl_clean_peers, 0, usec_to_sec(state->awdl_state.peers.clean_interval));
	ev_timer_again(loop, &state->ev_state.peer_timer);

	/* Trigger frame reception from WLAN device */
	state->ev_state.read_wlan.data = (void *) state;
	ev_io_init(&state->ev_state.read_wlan, wlan_device_ready, state->io.wlan_fd, EV_READ);
	ev_io_start(loop, &state->ev_state.read_wlan);

	/* Trigger frame reception from host device */
	state->ev_state.read_host.data = (void *) state;
	ev_io_init(&state->ev_state.read_host, host_device_ready, state->io.host_fd, EV_READ);
	ev_io_start(loop, &state->ev_state.read_host);

	/* Periodic counters, so a stalled transfer can be attributed without a
	 * second run. See awdl_stats_tick(). */
	state->ev_state.stats_timer.data = (void *) state;
	ev_timer_init(&state->ev_state.stats_timer, awdl_stats_tick, 10.0, 10.0);
	ev_timer_start(loop, &state->ev_state.stats_timer);

	/* Collect replies to the channel switches we no longer wait for. Without
	 * this they would pile up in the socket receive buffer until it overflowed. */
	if (!state->io.wlan_is_file && set_channel_fd() >= 0) {
		state->ev_state.read_chan_nl.data = (void *) state;
		ev_io_init(&state->ev_state.read_chan_nl, chan_nl_ready, set_channel_fd(), EV_READ);
		ev_io_start(loop, &state->ev_state.read_chan_nl);
	}

	/* Timer for PSFs */
	state->ev_state.psf_timer.data = (void *) state;
	ev_timer_init(&state->ev_state.psf_timer, awdl_send_psf,
	              usec_to_sec(ieee80211_tu_to_usec(state->awdl_state.psf_interval)),
	              usec_to_sec(ieee80211_tu_to_usec(state->awdl_state.psf_interval)));
	ev_timer_start(loop, &state->ev_state.psf_timer);

	/* Timer for MIFs */
	state->ev_state.mif_timer.data = (void *) state;
	ev_timer_init(&state->ev_state.mif_timer, awdl_send_mif, 0, 0);
	ev_timer_start(loop, &state->ev_state.mif_timer);

	/* Timer for unicast packets */
	state->ev_state.tx_timer.data = (void *) state;
	ev_timer_init(&state->ev_state.tx_timer, awdl_send_unicast, 0, 0);
	ev_timer_start(loop, &state->ev_state.tx_timer);

	/* Timer for multicast packets */
	state->ev_state.tx_mcast_timer.data = (void *) state;
	ev_timer_init(&state->ev_state.tx_mcast_timer, awdl_send_multicast, 0, 0);
	ev_timer_start(loop, &state->ev_state.tx_mcast_timer);

	/* Register signal to print statistics */
	state->ev_state.stats.data = (void *) state;
	ev_signal_init(&state->ev_state.stats, awdl_print_stats, SIGSTATS);
	ev_signal_start(loop, &state->ev_state.stats);
}
