#!/usr/bin/env python3
"""gen_blocks_vectors.py -- whole-symbol test vectors for QRBlocks (Person B).

Independence: segno does BOTH the Reed-Solomon encoding AND the interleaving
(segno.encoder.make_final_message, ISO 18004 section 7.6).  We only add
errors to segno's blocks, by wrapping segno's make_blocks() while it runs, so
the raw byte order comes from segno, not from Person B's address logic.
The expected output is just the random data bytes we started with.

Output: one hex byte per line.  Record layout (blocks format v1):
    version              1 line   (1..40)
    levelField           1 line   raw format field: 1=L 0=M 3=Q 2=H
    status               1 line   0 = every block has <= t errors: must decode
                                  2 = one block has > t errors: may fail
    total     (hi, lo)   2 lines
    totalData (hi, lo)   2 lines
    raw[0..total-1]          raw bytes in the order the front end reads them
    data[0..totalData-1]     expected corrected data bytes (block 0 first)
End: one "00" line, then "00" padding to exactly 2^21 lines.

Usage:  python3 gen_blocks_vectors.py [out_file] [seed]     (Python 3.6 OK)
"""
import random
import sys

from segno import consts
from segno import encoder

LINES = 1 << 21
LEVELS = (consts.ERROR_LEVEL_L, consts.ERROR_LEVEL_M,
          consts.ERROR_LEVEL_Q, consts.ERROR_LEVEL_H)


def symbol(rng, version, level, plan):
    """Raw interleaved bytes (with errors) + the clean data bytes.
    plan(block_index, ec_len, n) -> how many bytes to damage in that block."""
    infos = consts.ECC[version][level]
    total_data = sum(e.num_blocks * e.num_data for e in infos)
    total = sum(e.num_blocks * e.num_total for e in infos)
    data = [rng.randrange(256) for _ in range(total_data)]
    buff = encoder.Buffer()
    for b in data:
        buff.append_bits(b, 8)

    real_make_blocks = encoder.make_blocks

    def damaged_make_blocks(ec_infos, bf):
        dblocks, eblocks = real_make_blocks(ec_infos, bf)
        for i in range(len(dblocks)):
            whole = list(dblocks[i]) + list(eblocks[i])
            ec_len = len(eblocks[i])
            for pos in rng.sample(range(len(whole)), plan(i, ec_len, len(whole))):
                whole[pos] ^= rng.randrange(1, 256)
            nd = len(dblocks[i])
            dblocks[i] = bytearray(whole[:nd])
            eblocks[i] = bytearray(whole[nd:])
        return dblocks, eblocks

    encoder.make_blocks = damaged_make_blocks
    try:
        bits = encoder.make_final_message(version, level, buff).getbits()
    finally:
        encoder.make_blocks = real_make_blocks
    raw = []
    for k in range(total):
        v = 0
        for bit in bits[8 * k: 8 * k + 8]:
            v = (v << 1) | bit
        raw.append(v)
    return raw, data, total, total_data, sum(e.num_blocks for e in infos)


def main():
    out_file = sys.argv[1] if len(sys.argv) > 1 else "blocks_vectors.hex"
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 2028
    rng = random.Random(seed)
    lines = []
    count = {0: 0, 2: 0}
    bytes_damaged = [0]

    def emit(version, level, status, raw, data, total, total_data):
        lines.extend([version, level, status, total >> 8, total & 0xFF,
                      total_data >> 8, total_data & 0xFF] + raw + data)
        count[status] += 1

    for version in range(1, 41):
        for level in LEVELS:
            # 1. clean symbol
            raw, data, tot, tdat, nb = symbol(rng, version, level, lambda i, e, n: 0)
            emit(version, level, 0, raw, data, tot, tdat)

            # 2. every block gets 0..t errors, and one block exactly t
            full = rng.randrange(nb)

            def fixable(i, e, n, full=full):
                c = (e // 2) if i == full else rng.randint(0, e // 2)
                bytes_damaged[0] += c
                return c
            raw, data, tot, tdat, nb = symbol(rng, version, level, fixable)
            emit(version, level, 0, raw, data, tot, tdat)

            # 3. one block gets more than t errors
            bad = rng.randrange(nb)

            def too_many(i, e, n, bad=bad):
                return rng.randint(e // 2 + 1, e) if i == bad else rng.randint(0, e // 2)
            raw, data, tot, tdat, nb = symbol(rng, version, level, too_many)
            emit(version, level, 2, raw, data, tot, tdat)

    lines.append(0)
    if len(lines) > LINES:
        sys.exit("too many lines: %d" % len(lines))
    lines.extend([0] * (LINES - len(lines)))
    with open(out_file, "w") as f:
        f.write("\n".join("%02x" % v for v in lines) + "\n")
    print("wrote %s: %d symbols that must decode (%d damaged bytes) + %d with a block beyond t, all 160 layouts, seed %d"
          % (out_file, count[0], bytes_damaged[0], count[2], seed))


if __name__ == "__main__":
    main()
