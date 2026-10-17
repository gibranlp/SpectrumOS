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

/*
 * awdl_same_channel_as_peer() gates EVERY unicast transmission, via
 * awdl_can_send_unicast_in() -> awdl_send_unicast(). If it never returns true,
 * OWL goes silent on the unicast path while continuing to receive perfectly --
 * which is exactly the failure observed against a live iPhone on 2026-07-31:
 * ping6 5/5 with the pre-change build, 0/5 with the current one, same channel,
 * same phone, same advertised sequence.
 *
 * These tests reconstruct that scenario as pure logic, no radio and no clock,
 * by stepping the sync state one availability window at a time.
 */

extern "C" {
#include "state.h"
#include "schedule.h"
#include "peers.h"
#include "channel.h"
#include "ieee80211.h"
}

#include "gtest/gtest.h"

/* One extended availability window: presence_mode 4 * aw_period 16 TU = 64 TU. */
static const uint64_t EAW_USEC = 1024ULL * 64;

/* Real, captured from the iPhone on 2026-07-31 while it sat idle: channel 149
 * in slots 2 and 10, channel 3 in slot 0 (its infra channel), channel 6 in
 * slot 8. This is the sequence that was live when TX died. */
static const uint8_t PHONE_IDLE[AWDL_CHANSEQ_LENGTH] = {
	3, 0, 149, 0, 0, 0, 0, 0, 6, 0, 149, 0, 0, 0, 0, 0};

static void mkseq(struct awdl_chan *seq, const uint8_t *chans) {
	for (int i = 0; i < AWDL_CHANSEQ_LENGTH; i++) {
		seq[i].opclass.chan_num = chans[i];
		seq[i].opclass.opclass = chans[i] == 0 ? 0x00 : (chans[i] > 14 ? 0x80 : 0x51);
	}
}

/* Count, over one full 16-slot sequence period, how many slots the TX gate
 * considers us co-channel with the peer. */
static int co_channel_slots(struct awdl_state *state, struct awdl_peer *peer) {
    int n = 0;
    for (int slot = 0; slot < AWDL_CHANSEQ_LENGTH; slot++) {
        /* aw_counter 0 and last_update 0 means current_eaw(now) == now/EAW. */
        uint64_t now = state->sync.last_update + (uint64_t) slot * EAW_USEC;
        if (awdl_same_channel_as_peer(state, now, peer))
            n++;
    }
    return n;
}

class TxGate : public ::testing::Test {
  protected:
	struct awdl_state state;
	struct awdl_peer *peer;

	void SetUp() override {
		struct ether_addr self = {{0x4c, 0x82, 0xa9, 0x17, 0x65, 0x27}};
		struct ether_addr paddr = {{0x3a, 0xdd, 0x74, 0x15, 0x95, 0x5c}};
		struct awdl_chan c149 = CHAN_OPCLASS_149;

		awdl_init_state(&state, "void-btw", &self, c149, 0);
		state.sync.last_update = 0;
		state.sync.aw_counter = 0;

		awdl_peer_add(state.peers.peers, &paddr, 0, NULL, NULL);
		ASSERT_EQ(awdl_peer_get(state.peers.peers, &paddr, &peer), PEERS_OK);
		mkseq(peer->sequence, PHONE_IDLE);
		peer->sequence_enc = AWDL_CHAN_ENC_OPCLASS;
		peer->has_sequence = 1;
	}

};

TEST_F(TxGate, verbatim_adoption_is_co_channel_on_every_named_slot) {
	/* Upstream behaviour: our sequence IS the peer's, so the two agree wherever
	 * the peer named any channel at all -- slots 0, 2, 8 and 10. This is the
	 * configuration that gets 5/5 on ping6. */
	memcpy(state.channel.sequence, peer->sequence, sizeof(state.channel.sequence));
	state.channel.enc = peer->sequence_enc;
	state.channel.strategy = AWDL_CHANSEQ_VERBATIM;

	EXPECT_EQ(co_channel_slots(&state, peer), 4);
}

TEST_F(TxGate, pinning_is_still_co_channel_on_the_peers_slots) {
	/* THE REGRESSION TEST. Pinned to 149 in all 16 slots, we should still be
	 * co-channel wherever the peer names 149 -- slots 2 and 10. Fewer than
	 * verbatim, but emphatically not zero: zero means no unicast ever leaves,
	 * which is 100% ping loss and a dead TCP handshake. */
	struct awdl_chan c149 = CHAN_OPCLASS_149;
	awdl_chanseq_init_static(state.channel.sequence, &c149);
	state.channel.enc = AWDL_CHAN_ENC_OPCLASS;
	state.channel.strategy = AWDL_CHANSEQ_PIN;

	int n = co_channel_slots(&state, peer);
	EXPECT_GT(n, 0) << "pinning left no slot in which unicast may be sent -- "
	                   "OWL would receive normally and never transmit";
	EXPECT_EQ(n, 2) << "expected the peer's two 149 slots (2 and 10)";
}

TEST_F(TxGate, a_peer_sequence_in_another_encoding_is_not_silently_misread) {
	/* awdl_same_channel_as_peer() decodes the PEER's raw sequence bytes with
	 * state->channel.enc, not peer->sequence_enc. Upstream got away with that
	 * because it always copied the peer's encoding along with its sequence, so
	 * the two agreed by construction. Pinning sets our encoding independently,
	 * which breaks that assumption -- so check what happens when they differ. */
	struct awdl_chan c149 = CHAN_OPCLASS_149;
	awdl_chanseq_init_static(state.channel.sequence, &c149);
	state.channel.enc = AWDL_CHAN_ENC_OPCLASS;
	state.channel.strategy = AWDL_CHANSEQ_PIN;

	/* Same channels, but stored the way a LEGACY-encoded TLV would carry them:
	 * {flags, chan_num} rather than {chan_num, opclass}. */
	for (int i = 0; i < AWDL_CHANSEQ_LENGTH; i++) {
		peer->sequence[i].legacy.flags = PHONE_IDLE[i] ? 0x1d : 0x00;
		peer->sequence[i].legacy.chan_num = PHONE_IDLE[i];
	}
	peer->sequence_enc = AWDL_CHAN_ENC_LEGACY;

	EXPECT_GT(co_channel_slots(&state, peer), 0)
		<< "peer sequence decoded with OUR encoding instead of its own: every "
		   "comparison is garbage and unicast TX stops entirely";
}
