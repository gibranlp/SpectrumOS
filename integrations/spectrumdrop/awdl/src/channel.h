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

#ifndef AWDL_CHANNEL_H_
#define AWDL_CHANNEL_H_

#include <stdint.h>
#include <netinet/ether.h>

#define AWDL_CHANSEQ_LENGTH 16

enum awdl_chan_encoding {
	AWDL_CHAN_ENC_SIMPLE = 0,
	AWDL_CHAN_ENC_LEGACY = 1,
	AWDL_CHAN_ENC_OPCLASS = 3,
};

struct awdl_chan {
	union {
		uint8_t val[2];
		struct {
			uint8_t chan_num;
		} simple;
		struct {
			uint8_t flags;
			uint8_t chan_num;
		} legacy;
		struct {
			uint8_t chan_num;
			uint8_t opclass;
		} opclass;
	};
};

#define CHAN_NULL (struct awdl_chan) { { { 0, 0x00 } } }
#define CHAN_OPCLASS_6 (struct awdl_chan) { { { 6, 0x51 } } }
/* 36 is a social channel Apple devices actually favour - an iPhone was observed
 * advertising 36 in 6 of 16 slots against only 2 on 149. Same 5 GHz opclass as
 * 44 and 149. */
#define CHAN_OPCLASS_36 (struct awdl_chan) { { { 36, 0x80 } } }
#define CHAN_OPCLASS_44 (struct awdl_chan) { { { 44, 0x80 } } }
#define CHAN_OPCLASS_149 (struct awdl_chan) { { { 149, 0x80 } } }

uint8_t awdl_chan_num(struct awdl_chan chan, enum awdl_chan_encoding);

int awdl_chan_encoding_size(enum awdl_chan_encoding);

/*
 * How to derive our own channel sequence from a peer's advertised one.
 *
 * Measured against a real iPhone; see docs/FINDINGS.md sections 16-18 and 21 in
 * the airdrop-mt7921 repo. The short version: a peer is on a given channel in
 * exactly the slots its advertised sequence names, and an iPhone *escalates*
 * that sequence during a transfer, from 2 slots of 16 when idle up to 12 of 16
 * at peak. Which of those slots we actually share with it is the entire
 * throughput story.
 */
enum awdl_chanseq_strategy {
	/* Copy the elected sync master's sequence verbatim. Upstream behaviour, the
	 * ~45 kB/s baseline, and the DEFAULT: it is the only strategy an iPhone has
	 * ever been observed to answer (§25). Correct only because the master's
	 * phase is ours by construction, so it silently breaks for any non-master
	 * peer -- which is what ROTATE is for. */
	AWDL_CHANSEQ_VERBATIM = 0,
	/* Copy a peer's sequence but rotate it into our own clock phase first.
	 * Needed for any peer that is not the elected master. */
	AWDL_CHANSEQ_ROTATE = 1,
	/* Ignore slot structure entirely and sit on the peer's dominant social
	 * channel in all 16 slots.
	 *
	 * DOES NOT WORK against iOS 26 -- an iPhone stops answering us entirely, and
	 * this is measured, not suspected (§25): same phone, same setup, same binary,
	 * verbatim 60% ping loss against pin 100%, twice, with pin's frames provably
	 * leaving the radio and its channel provably unchanged. What is left is the
	 * sequence itself: a peer that claims one channel in all 16 slots, with no
	 * empty slots and no infra channel in slot 0, looks like nothing any Apple
	 * device emits, and the phone appears to reject it.
	 *
	 * Kept because it is the natural experiment for "how much slot structure
	 * does Apple actually require", which is the open question behind widening
	 * our duty cycle. Not a default, and not a thing to reach for casually. */
	AWDL_CHANSEQ_PIN = 2,
	/* The peer's own sequence with up to N of its empty slots filled in with the
	 * peer's dominant channel, slot 0 left exactly as the peer wrote it.
	 *
	 * §25 established the two extremes: the peer's sequence verbatim is answered,
	 * one channel in all 16 slots is not. This walks between them, so the width
	 * at which an iPhone stops answering can be measured rather than guessed --
	 * and every slot we add that the phone still accepts is duty cycle we get
	 * back (§21). Nothing is invented: the fill value is copied from the peer's
	 * own bytes. */
	AWDL_CHANSEQ_WIDEN = 3,
	/* The peer's sequence with every slot blanked whose channel we cannot
	 * actually be on. For P2P-GO, where the radio is pinned by go0's chanctx and
	 * OWL's channel switching does nothing. See awdl_chanseq_intersect(). */
	AWDL_CHANSEQ_INTERSECT = 4,
};

struct awdl_channel_state {
	enum awdl_chan_encoding enc;
	struct awdl_chan sequence[AWDL_CHANSEQ_LENGTH];
	struct awdl_chan master;
	struct awdl_chan current;
	/* 0: 'sequence' is our own static sequence built from 'master'.
	 * 1: 'sequence' was inherited from the elected sync master peer. */
	uint8_t sequence_from_peer;
	enum awdl_chanseq_strategy strategy;
	/* Address the current adopted sequence came from, and the channel PIN
	 * settled on, so that a re-evaluation that reaches the same answer is a
	 * no-op instead of a log line and a rewrite. */
	struct ether_addr seq_src;
	uint8_t pinned_chan;
	/* ROTATE hysteresis. The rotation delta is derived from a peer's reported
	 * sync phase, which jitters; when that phase sits near an availability
	 * window boundary the delta flips between two adjacent values on successive
	 * ticks, and every flip rewrites the whole sequence. So a new delta has to
	 * show up on two consecutive ticks before it is applied. */
	int rot_delta;         /* currently applied */
	int rot_delta_pending; /* seen once, not yet confirmed */
	uint8_t rot_valid;
	/* WIDEN: how many of the peer's empty slots to fill. */
	int widen_max;
	/* owl -F: the radio is held on the -c channel by something we can't move
	 * (an ad-hoc vif's channel context, or a card that may transmit nowhere
	 * else) and nobody chose that channel to suit the peers. See
	 * awdl_same_channel_as_peer() and awdl_is_multicast_eaw(). */
	uint8_t fixed_radio;
};

void awdl_chanseq_init(struct awdl_chan *seq);

void awdl_chanseq_init_idle(struct awdl_chan *seq);

void awdl_chanseq_init_static(struct awdl_chan *seq, const struct awdl_chan *chan);

/**
 * @brief Rotate a channel sequence by {@code delta} slots into another clock phase.
 *
 * A sequence array is written in the phase of whoever advertised it. Indexing
 * someone else's array with our own slot number puts us on the right channels
 * at the wrong times, which is exactly the regression documented in FINDINGS 17.
 * dst and src must not overlap.
 */
void awdl_chanseq_rotate(struct awdl_chan *dst, const struct awdl_chan *src, int delta);

/**
 * @brief The channel occupying the most slots in {@code seq}, ignoring empty slots.
 * @param prefer if non-zero and present anywhere in the sequence, wins outright
 * @return the channel number, or 0 if the sequence names no channel at all
 */
uint8_t awdl_chanseq_dominant_chan(const struct awdl_chan *seq, enum awdl_chan_encoding enc, uint8_t prefer);

/**
 * @brief The peer's sequence with up to {@code max_fill} empty slots filled in.
 *
 * Fills with the peer's dominant channel, copying the peer's own encoded bytes
 * rather than constructing them, and never touches slot 0. dst and src may not
 * overlap. Returns the number of slots actually filled.
 */
int awdl_chanseq_widen(struct awdl_chan *dst, const struct awdl_chan *src,
                       enum awdl_chan_encoding enc, int max_fill);

/**
 * @brief The peer's sequence with every slot blanked whose channel is not {@code keep}.
 *
 * For a radio that cannot actually hop (P2P-GO holds it on one channel), this is
 * the only sequence that is both structurally Apple-like and true. Copies the
 * peer's own encoded bytes. dst and src may not overlap. Returns the number of
 * slots kept - our real overlap with the peer, out of AWDL_CHANSEQ_LENGTH.
 */
int awdl_chanseq_intersect(struct awdl_chan *dst, const struct awdl_chan *src,
                           enum awdl_chan_encoding enc, uint8_t keep);

/** @brief How many of the 16 slots name {@code chan}. */
int awdl_chanseq_count_chan(const struct awdl_chan *seq, enum awdl_chan_encoding enc, uint8_t chan);

#endif /* AWDL_CHANNEL_H_ */
