#!/usr/bin/env python3
"""gen_syndrome_vectors.py -- test vectors for the syndrome unit (Person B).

Independence: the correct blocks are made by segno's own Reed-Solomon encoder
(segno.encoder.make_blocks), and the expected syndromes are computed with
segno's own GF(256) tables.  Nothing here uses Person B's GF or RS code.

Output: one hex byte per line (read by TbSyndrome.bsv with a RegFile).
Record layout (the same format is proposed to Person A for his model):
    ecLen                 1 line   (7..30)
    n (high byte)         1 line
    n (low byte)          1 line
    r[0] .. r[n-1]        n lines  (first byte = highest power of x)
    S_0 .. S_(ecLen-1)    ecLen lines  (expected syndromes)
After the last record: one line "00" (ecLen 0 = end).  The file is then
padded with "00" lines to exactly 2^19 lines.

Usage:  python3 gen_syndrome_vectors.py [out_file] [seed]
Works on Python 3.6.
"""
import random
import sys

from segno import consts
from segno import encoder

EXP = consts.GALIOS_EXP          # EXP[i] = alpha^i (510 entries)
LOG = consts.GALIOS_LOG          # LOG[a] = i with alpha^i = a (a != 0)
LINES = 1 << 19
LEVELS = (consts.ERROR_LEVEL_L, consts.ERROR_LEVEL_M,
          consts.ERROR_LEVEL_Q, consts.ERROR_LEVEL_H)


class _Buf(object):
    """The tiny part of segno's Buffer that make_blocks() uses."""
    def __init__(self, data):
        self.data = list(data)

    def toints(self):
        return iter(self.data)


def segno_block(rng, num_data, num_total):
    """One correct block: random data + segno's check bytes."""
    ec = consts.EC(1, num_total, num_data)
    data = [rng.randrange(256) for _ in range(num_data)]
    data_blocks, err_blocks = encoder.make_blocks([ec], _Buf(data))
    return list(data_blocks[0]) + list(err_blocks[0])


def syndromes(block, ec_len):
    """S_j = R(alpha^j), j = 0..ec_len-1, first byte = highest power."""
    n = len(block)
    out = []
    for j in range(ec_len):
        s = 0
        for k, r in enumerate(block):
            if r:
                deg = n - 1 - k
                s ^= EXP[(LOG[r] + j * deg) % 255]
        out.append(s)
    return out


def add_errors(rng, block, count):
    """Change `count` different bytes to a different value."""
    bad = list(block)
    for pos in rng.sample(range(len(bad)), count):
        bad[pos] ^= rng.randrange(1, 256)
    return bad


def main():
    out_file = sys.argv[1] if len(sys.argv) > 1 else "syn_vectors.hex"
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 2026
    rng = random.Random(seed)
    lines = []
    kinds = {"clean": 0, "errors": 0}
    shapes = set()

    def record(block, ec_len, kind):
        exp = syndromes(block, ec_len)
        if kind == "clean" and any(exp):
            sys.exit("segno block is not a codeword?! (ecLen %d)" % ec_len)
        if kind == "errors" and not any(exp):
            return                       # (can not happen for <= ecLen errors)
        n = len(block)
        lines.extend([ec_len, n >> 8, n & 0xFF] + block + exp)
        kinds[kind] += 1

    for version in range(1, 41):
        for level in LEVELS:
            for ec in consts.ECC[version][level]:
                ec_len = ec.num_total - ec.num_data
                shapes.add((ec_len, ec.num_total))
                good = segno_block(rng, ec.num_data, ec.num_total)
                record(good, ec_len, "clean")
                # 1 error, t = ecLen//2 errors (the most RS can fix), and a
                # random count up to ecLen (syndromes must still be right).
                for cnt in (1, ec_len // 2, rng.randint(1, ec_len)):
                    record(add_errors(rng, good, cnt), ec_len, "errors")
    # Some extra random blocks of every shape, until the file is ~ 3/4 full.
    shapes = sorted(shapes)
    while len(lines) < (LINES * 3) // 4:
        ec_len, total = rng.choice(shapes)
        good = segno_block(rng, total - ec_len, total)
        if rng.random() < 0.2:
            record(good, ec_len, "clean")
        else:
            record(add_errors(rng, good, rng.randint(1, ec_len)), ec_len, "errors")

    lines.append(0)                                   # end marker
    lines.extend([0] * (LINES - len(lines)))          # pad to 2^19 lines
    with open(out_file, "w") as f:
        f.write("\n".join("%02x" % v for v in lines) + "\n")
    print("wrote %s: %d clean blocks + %d blocks with errors, %d shapes (ecLen, n), seed %d"
          % (out_file, kinds["clean"], kinds["errors"], len(shapes), seed))


if __name__ == "__main__":
    main()
