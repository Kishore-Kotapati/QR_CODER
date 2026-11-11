#!/usr/bin/env python3
"""
Generate rs_vectors.hex using Person A's independent RS reference model.
Format: RS_VECTOR_FORMAT.md File 2 (1,048,576 lines).
"""
import sys
import os
import random

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "model")))
import rs_ref
import blocks_ref

LINES = 1 << 20  # 1,048,576 lines

def corrupt(rng, block, count):
    bad = list(block)
    for pos in rng.sample(range(len(bad)), count):
        bad[pos] ^= rng.randrange(1, 256)
    return bad

def evaluate_block_with_model(rec, ec_len):
    n = len(rec)
    t = ec_len // 2
    syndromes = rs_ref.compute_syndromes(rec, ec_len)
    if all(s == 0 for s in syndromes):
        return 0, 0, [1] + [0] * 15, list(rec)

    Lambda, L = rs_ref.berlekamp_massey(syndromes, ec_len)
    if L > t or (len(Lambda) - 1) != L:
        return 1, 0, [0] * 16, [0] * n

    positions = rs_ref.chien_search(Lambda, n)
    if positions is None:
        return 1, 0, [0] * 16, [0] * n

    try:
        errors = rs_ref.forney(syndromes, Lambda, positions, n, ec_len)
    except Exception:
        return 1, 0, [0] * 16, [0] * n

    corr = list(rec)
    for p, Y in errors:
        corr[p] = rs_ref.gf.gf_sub(corr[p], Y)

    check_s = rs_ref.compute_syndromes(corr, ec_len)
    if any(s != 0 for s in check_s):
        return 1, 0, [0] * 16, [0] * n

    lam_16 = Lambda + [0] * (16 - len(Lambda))
    return 0, L, lam_16, corr

def main():
    out_file = sys.argv[1] if len(sys.argv) > 1 else "project/verification/vectors/backend/rs_vectors.hex"
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 2027
    rng = random.Random(seed)
    lines = []
    count = {0: 0, 1: 0}
    shapes = set()

    def record(good, ec_len, nerr):
        n = len(good)
        t = ec_len // 2
        rec = corrupt(rng, good, nerr) if nerr > 0 else list(good)
        status, L, lam_16, corr = evaluate_block_with_model(rec, ec_len)
        lines.extend([ec_len, n >> 8, n & 0xFF] + rec + [status, L] + lam_16 + corr)
        count[status] += 1

    # Loop over all 160 layouts
    for version in range(1, 41):
        for level in [1, 0, 3, 2]:
            bp = blocks_ref.get_block_params(version, level)
            ec_len = bp.ecLen
            t = ec_len // 2
            # Group 1
            d1 = bp.d1
            shapes.add((ec_len, d1 + ec_len))
            good = rs_ref.encode_block([rng.randrange(256) for _ in range(d1)], ec_len)
            for nerr in (0, 1, t, t + 1, rng.randint(1, t)):
                record(good, ec_len, nerr)

            if bp.n2 > 0:
                d2 = bp.d1 + 1
                shapes.add((ec_len, d2 + ec_len))
                good2 = rs_ref.encode_block([rng.randrange(256) for _ in range(d2)], ec_len)
                for nerr in (0, 1, t, t + 1, rng.randint(1, t)):
                    record(good2, ec_len, nerr)

    shapes = sorted(shapes)
    while len(lines) < (LINES * 3) // 4:
        ec_len, total = rng.choice(shapes)
        d = total - ec_len
        good = rs_ref.encode_block([rng.randrange(256) for _ in range(d)], ec_len)
        t = ec_len // 2
        nerr = rng.randint(0, t) if rng.random() < 0.85 else rng.randint(t + 1, ec_len)
        record(good, ec_len, nerr)

    lines.append(0) # End marker
    lines.extend([0] * (LINES - len(lines))) # Pad to exactly 2^20 lines
    os.makedirs(os.path.dirname(out_file), exist_ok=True)
    with open(out_file, "w") as f:
        f.write("\n".join(f"{v:02x}" for v in lines) + "\n")

    print(f"Wrote {out_file}: {count[0]} fixable + {count[1]} unfixable blocks, {len(shapes)} shapes, {len(lines)} lines.")

if __name__ == "__main__":
    main()
