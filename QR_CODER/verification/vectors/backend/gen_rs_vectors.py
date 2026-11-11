#!/usr/bin/env python3
"""gen_rs_vectors.py -- RS test vectors for Berlekamp-Massey (Day 6) and
Chien/Forney (Day 7).  Person B's test generator.

Independence: correct blocks come from segno's own RS encoder
(segno.encoder.make_blocks).  Expected answers are NOT computed by running
any decoder: we KNOW where we put the errors, so the true error locator is
simply
        Lambda(x) = (1 + X_1 x)(1 + X_2 x) ... (1 + X_v x),  X_k = alpha^(d_k)
(d_k = degree of the changed byte = n-1-k), multiplied out with segno's
GF(256) tables.  The true corrected block is the original segno block.

Output: one hex byte per line.  Record layout (format v1, also proposed to
Person A in docs/RS_VECTOR_FORMAT.md):
    ecLen                1 line   (7..30)
    n >> 8, n & 0xFF     2 lines
    r[0] .. r[n-1]       n lines   received block (first byte = highest power)
    status               1 line    0 = fixable (v <= t): check everything
                                   1 = model says NOT fixable (expect fail)
                                   2 = more than t errors, no fixed answer
                                       (decoder may fail or miscorrect)
    L                    1 line    number of errors (status 0)
    Lambda_0..Lambda_15  16 lines  (status 0; Lambda_0 = 1)
    c[0] .. c[n-1]       n lines   correct block (status 0)
End: one "00" line, then "00" padding to exactly 2^20 lines.

Usage:  python3 gen_rs_vectors.py [out_file] [seed]      (Python 3.6 OK)
"""
import random
import sys

from segno import consts
from segno import encoder

EXP = consts.GALIOS_EXP
LOG = consts.GALIOS_LOG
LINES = 1 << 20
LEVELS = (consts.ERROR_LEVEL_L, consts.ERROR_LEVEL_M,
          consts.ERROR_LEVEL_Q, consts.ERROR_LEVEL_H)


class _Buf(object):
    def __init__(self, data):
        self.data = list(data)

    def toints(self):
        return iter(self.data)


def gmul(a, b):
    if a == 0 or b == 0:
        return 0
    return EXP[(LOG[a] + LOG[b]) % 255]


def segno_block(rng, num_data, num_total):
    ec = consts.EC(1, num_total, num_data)
    data = [rng.randrange(256) for _ in range(num_data)]
    data_blocks, err_blocks = encoder.make_blocks([ec], _Buf(data))
    return list(data_blocks[0]) + list(err_blocks[0])


def locator(n, positions):
    """Lambda(x) = prod (1 + X_k x), X_k = alpha^(n-1-pos).  Low power first."""
    lam = [1]
    for pos in positions:
        x = EXP[(n - 1 - pos) % 255]
        new = lam + [0]
        for i in range(len(lam)):
            new[i + 1] ^= gmul(lam[i], x)
        lam = new
    return lam


def corrupt(rng, block, count):
    bad = list(block)
    positions = rng.sample(range(len(bad)), count)
    for pos in positions:
        bad[pos] ^= rng.randrange(1, 256)
    return bad, positions


def main():
    out_file = sys.argv[1] if len(sys.argv) > 1 else "rs_vectors.hex"
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 2027
    rng = random.Random(seed)
    lines = []
    count = {0: 0, 2: 0}
    shapes = set()

    def record(good, ec_len, nerr):
        n = len(good)
        t = ec_len // 2
        rec, positions = corrupt(rng, good, nerr)
        if nerr <= t:
            lam = locator(n, positions)
            lam = lam + [0] * (16 - len(lam))
            body = [0, nerr] + lam + good
            status = 0
        else:
            body = [2, 0] + [0] * 16 + good
            status = 2
        lines.extend([ec_len, n >> 8, n & 0xFF] + rec + body)
        count[status] += 1

    for version in range(1, 41):
        for level in LEVELS:
            for ec in consts.ECC[version][level]:
                ec_len = ec.num_total - ec.num_data
                t = ec_len // 2
                shapes.add((ec_len, ec.num_total))
                good = segno_block(rng, ec.num_data, ec.num_total)
                for nerr in (0, 1, t, t + 1, rng.randint(1, t)):
                    record(good, ec_len, nerr)
    shapes = sorted(shapes)
    while len(lines) < (LINES * 3) // 4:
        ec_len, total = rng.choice(shapes)
        good = segno_block(rng, total - ec_len, total)
        t = ec_len // 2
        nerr = rng.randint(0, t) if rng.random() < 0.85 else rng.randint(t + 1, ec_len)
        record(good, ec_len, nerr)

    lines.append(0)
    lines.extend([0] * (LINES - len(lines)))
    with open(out_file, "w") as f:
        f.write("\n".join("%02x" % v for v in lines) + "\n")
    print("wrote %s: %d fixable blocks (0..t errors) + %d blocks with more than t errors, %d shapes, seed %d"
          % (out_file, count[0], count[2], len(shapes), seed))


if __name__ == "__main__":
    main()
