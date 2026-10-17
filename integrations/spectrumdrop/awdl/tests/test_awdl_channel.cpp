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

extern "C" {
#include "channel.h"
}

#include "gtest/gtest.h"

/*
 * Sequences below are real, captured from an iPhone on 2026-07-31 and decoded
 * with opclass encoding. Slot 0 holds a non-social channel (the phone's infra
 * channel, seen as 3, 124, 132 and 134 in different runs); a 0 slot means the
 * device is simply not on AWDL for that window.
 */

/* idle: on 149 in 2 of 16 slots */
static const uint8_t IPHONE_IDLE[AWDL_CHANSEQ_LENGTH] = {
	132, 0, 149, 0, 0, 0, 0, 0, 6, 0, 149, 0, 0, 0, 0, 0};
/* mid-transfer escalation: 5 slots */
static const uint8_t IPHONE_BUSY[AWDL_CHANSEQ_LENGTH] = {
	149, 149, 149, 0, 0, 0, 0, 0, 6, 149, 149, 0, 0, 0, 0, 0};
/* peak escalation: 11 slots */
static const uint8_t IPHONE_PEAK[AWDL_CHANSEQ_LENGTH] = {
	149, 149, 149, 149, 149, 149, 0, 0, 6, 149, 149, 149, 149, 149, 0, 0};

static void mkseq(struct awdl_chan *seq, const uint8_t *chans) {
	for (int i = 0; i < AWDL_CHANSEQ_LENGTH; i++) {
		seq[i].opclass.chan_num = chans[i];
		seq[i].opclass.opclass = chans[i] == 0 ? 0x00 : (chans[i] > 14 ? 0x80 : 0x51);
	}
}

TEST(awdl_channel, rotate_by_zero_is_identity) {
	struct awdl_chan in[AWDL_CHANSEQ_LENGTH], out[AWDL_CHANSEQ_LENGTH];
	mkseq(in, IPHONE_IDLE);
	awdl_chanseq_rotate(out, in, 0);
	for (int i = 0; i < AWDL_CHANSEQ_LENGTH; i++)
		EXPECT_EQ(awdl_chan_num(out[i], AWDL_CHAN_ENC_OPCLASS), IPHONE_IDLE[i]);
}

TEST(awdl_channel, rotate_shifts_slots_left) {
	struct awdl_chan in[AWDL_CHANSEQ_LENGTH], out[AWDL_CHANSEQ_LENGTH];
	mkseq(in, IPHONE_IDLE);

	/* The peer is on 149 in slots 2 and 10. If the peer's clock runs 2 slots
	 * ahead of ours, then when our clock says slot 0 the peer is in its slot 2 --
	 * so our slot 0 must hold what the peer put in its slot 2. */
	awdl_chanseq_rotate(out, in, 2);
	EXPECT_EQ(awdl_chan_num(out[0], AWDL_CHAN_ENC_OPCLASS), 149);
	EXPECT_EQ(awdl_chan_num(out[8], AWDL_CHAN_ENC_OPCLASS), 149);
	EXPECT_EQ(awdl_chan_num(out[6], AWDL_CHAN_ENC_OPCLASS), 6);
}

TEST(awdl_channel, rotate_wraps_and_accepts_negative) {
	struct awdl_chan in[AWDL_CHANSEQ_LENGTH], a[AWDL_CHANSEQ_LENGTH], b[AWDL_CHANSEQ_LENGTH];
	mkseq(in, IPHONE_PEAK);

	awdl_chanseq_rotate(a, in, -3);
	awdl_chanseq_rotate(b, in, AWDL_CHANSEQ_LENGTH - 3);
	for (int i = 0; i < AWDL_CHANSEQ_LENGTH; i++)
		EXPECT_EQ(awdl_chan_num(a[i], AWDL_CHAN_ENC_OPCLASS),
		          awdl_chan_num(b[i], AWDL_CHAN_ENC_OPCLASS));

	/* A full turn is the identity. */
	awdl_chanseq_rotate(a, in, AWDL_CHANSEQ_LENGTH);
	for (int i = 0; i < AWDL_CHANSEQ_LENGTH; i++)
		EXPECT_EQ(awdl_chan_num(a[i], AWDL_CHAN_ENC_OPCLASS), IPHONE_PEAK[i]);
}

TEST(awdl_channel, rotate_preserves_slot_occupancy) {
	/* Rotation must not create or destroy availability -- it only moves it.
	 * This is what makes a pinned (constant) sequence phase-invariant. */
	struct awdl_chan in[AWDL_CHANSEQ_LENGTH], out[AWDL_CHANSEQ_LENGTH];
	mkseq(in, IPHONE_PEAK);
	for (int d = 0; d < AWDL_CHANSEQ_LENGTH; d++) {
		awdl_chanseq_rotate(out, in, d);
		EXPECT_EQ(awdl_chanseq_count_chan(out, AWDL_CHAN_ENC_OPCLASS, 149), 11);
		EXPECT_EQ(awdl_chanseq_count_chan(out, AWDL_CHAN_ENC_OPCLASS, 6), 1);
	}
}

TEST(awdl_channel, pinned_sequence_is_rotation_invariant) {
	/* The whole safety argument for the PIN strategy: a constant sequence is
	 * unchanged by any rotation, so getting the clock phase wrong -- the bug
	 * that made the FINDINGS 17 attempt 6x worse -- cannot cost anything. */
	struct awdl_chan pinned[AWDL_CHANSEQ_LENGTH], out[AWDL_CHANSEQ_LENGTH];
	struct awdl_chan c149 = CHAN_OPCLASS_149;

	awdl_chanseq_init_static(pinned, &c149);
	for (int d = -AWDL_CHANSEQ_LENGTH; d <= AWDL_CHANSEQ_LENGTH; d++) {
		awdl_chanseq_rotate(out, pinned, d);
		for (int i = 0; i < AWDL_CHANSEQ_LENGTH; i++)
			EXPECT_EQ(awdl_chan_num(out[i], AWDL_CHAN_ENC_OPCLASS), 149);
	}
}

TEST(awdl_channel, dominant_chan_picks_the_social_channel) {
	struct awdl_chan seq[AWDL_CHANSEQ_LENGTH];

	mkseq(seq, IPHONE_IDLE);
	EXPECT_EQ(awdl_chanseq_dominant_chan(seq, AWDL_CHAN_ENC_OPCLASS, 0), 149);
	mkseq(seq, IPHONE_BUSY);
	EXPECT_EQ(awdl_chanseq_dominant_chan(seq, AWDL_CHAN_ENC_OPCLASS, 0), 149);
	mkseq(seq, IPHONE_PEAK);
	EXPECT_EQ(awdl_chanseq_dominant_chan(seq, AWDL_CHAN_ENC_OPCLASS, 0), 149);
}

TEST(awdl_channel, dominant_chan_maximises_overlap_not_familiarity) {
	/* The operator's channel breaks exact ties only. It must NOT win merely by
	 * being present, or we pin to the peer's worst channel over its best.
	 *
	 * The sequence below is real, captured 2026-07-31 from an iPhone while
	 * airdrop.sh had swept to channel 6: ch36 in 6 slots, ch149 in 2, ch6 in 1.
	 * The earlier "prefer wins if present" rule returned 6. */
	struct awdl_chan seq[AWDL_CHANSEQ_LENGTH];
	static const uint8_t real[AWDL_CHANSEQ_LENGTH] = {
		36, 36, 149, 0, 0, 0, 0, 36, 6, 36, 149, 36, 0, 0, 0, 36};

	mkseq(seq, real);
	EXPECT_EQ(awdl_chanseq_count_chan(seq, AWDL_CHAN_ENC_OPCLASS, 36), 6);
	EXPECT_EQ(awdl_chanseq_count_chan(seq, AWDL_CHAN_ENC_OPCLASS, 6), 1);

	EXPECT_EQ(awdl_chanseq_dominant_chan(seq, AWDL_CHAN_ENC_OPCLASS, 0), 36);
	EXPECT_EQ(awdl_chanseq_dominant_chan(seq, AWDL_CHAN_ENC_OPCLASS, 6), 36);
	EXPECT_EQ(awdl_chanseq_dominant_chan(seq, AWDL_CHAN_ENC_OPCLASS, 149), 36);
}

TEST(awdl_channel, dominant_chan_breaks_exact_ties_towards_the_operator) {
	struct awdl_chan seq[AWDL_CHANSEQ_LENGTH];
	static const uint8_t tied[AWDL_CHANSEQ_LENGTH] = {
		6, 6, 6, 6, 0, 0, 0, 0, 149, 149, 149, 149, 0, 0, 0, 0};

	mkseq(seq, tied);
	EXPECT_EQ(awdl_chanseq_dominant_chan(seq, AWDL_CHAN_ENC_OPCLASS, 149), 149);
	EXPECT_EQ(awdl_chanseq_dominant_chan(seq, AWDL_CHAN_ENC_OPCLASS, 6), 6);
	/* No preference: deterministic, not dependent on iteration order. */
	EXPECT_EQ(awdl_chanseq_dominant_chan(seq, AWDL_CHAN_ENC_OPCLASS, 0), 6);
}

TEST(awdl_channel, dominant_chan_of_empty_sequence_is_zero) {
	struct awdl_chan seq[AWDL_CHANSEQ_LENGTH];
	struct awdl_chan null_chan = CHAN_NULL;

	awdl_chanseq_init_static(seq, &null_chan);
	EXPECT_EQ(awdl_chanseq_dominant_chan(seq, AWDL_CHAN_ENC_OPCLASS, 0), 0);
	/* A preferred channel that is absent must not be conjured up. */
	EXPECT_EQ(awdl_chanseq_dominant_chan(seq, AWDL_CHAN_ENC_OPCLASS, 149), 0);
}

/* Slots in which both sequences name the same non-zero channel: the only slots
 * in which anything can actually be exchanged. */
static int overlap(const struct awdl_chan *ours, const struct awdl_chan *theirs) {
	int n = 0;
	for (int i = 0; i < AWDL_CHANSEQ_LENGTH; i++) {
		uint8_t a = awdl_chan_num(ours[i], AWDL_CHAN_ENC_OPCLASS);
		uint8_t b = awdl_chan_num(theirs[i], AWDL_CHAN_ENC_OPCLASS);
		if (a && a == b)
			n++;
	}
	return n;
}

TEST(awdl_channel, pin_never_loses_windows_to_phase_error) {
	/* The claim that once made PIN the default, as a test rather than an
	 * assertion in a commit message.
	 *
	 * Copying a peer's sequence is only correct when our clock phase matches
	 * the peer's. When it does not -- which is every non-master peer, and any
	 * master whose phase has drifted -- verbatim adoption loses windows, and
	 * that is precisely the 6x regression of FINDINGS 17. Pinning is a constant
	 * sequence, so it overlaps every window the peer offers at every phase.
	 *
	 * All still true, and all beside the point: an iPhone will not answer a peer
	 * advertising a constant sequence at all (FINDINGS 25), so the windows PIN
	 * wins on paper are ones nobody transmits in. Kept because the arithmetic is
	 * what any future widening of our duty cycle has to beat, and because it is
	 * a standing reminder that a model can be correct and still lose to what the
	 * other device is willing to talk to.
	 */
	const uint8_t *captured[] = {IPHONE_IDLE, IPHONE_BUSY, IPHONE_PEAK};
	struct awdl_chan peer[AWDL_CHANSEQ_LENGTH];
	struct awdl_chan ours[AWDL_CHANSEQ_LENGTH];
	struct awdl_chan c149 = CHAN_OPCLASS_149;

	for (unsigned k = 0; k < sizeof(captured) / sizeof(*captured); k++) {
		mkseq(peer, captured[k]);
		int offered = awdl_chanseq_count_chan(peer, AWDL_CHAN_ENC_OPCLASS, 149);
		int worst_verbatim = AWDL_CHANSEQ_LENGTH;

		/* PIN: on 149 in all 16 slots, at every possible phase error. */
		awdl_chanseq_init_static(ours, &c149);
		EXPECT_EQ(overlap(ours, peer), offered);

		/* VERBATIM: our sequence is the peer's, but read in a phase that is
		 * wrong by delta slots. */
		for (int delta = 1; delta < AWDL_CHANSEQ_LENGTH; delta++) {
			awdl_chanseq_rotate(ours, peer, delta);
			int got = overlap(ours, peer);
			EXPECT_LE(got, offered) << "adoption cannot beat full presence";
			if (got < worst_verbatim)
				worst_verbatim = got;
		}
		/* There is always some phase error that costs real windows. */
		EXPECT_LT(worst_verbatim, offered);
	}
}
