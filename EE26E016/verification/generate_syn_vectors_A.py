#!/usr/bin/env python3
"""
Generate syn_vectors.hex using Person A's independent RS reference model.
Format: RS_VECTOR_FORMAT.md File 1 (524,288 lines).
"""
import sys
import os
import random

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "model")))
import rs_ref
import blocks_ref

LINES = 1 << 19  # 524,288 lines

def corrupt(rng, block, count):
    bad = list(block)
    for pos in rng.sample(range(len(bad)), count):
        bad[pos] ^= rng.randrange(1, 256)
    return bad

def main():
    out_file = sys.argv[1] if len(sys.argv) > 1 else "project/verification/vectors/backend/syn_vectors.hex"
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 2026
    rng = random.Random(seed)
    lines = []
    kinds = {"clean": 0, "errors": 0}
    shapes = set()

    def record(block, ec_len, kind):
        # Use Person A's compute_syndromes from rs_ref
        exp = rs_ref.compute_syndromes(block, ec_len)
        if kind == "clean" and any(exp):
            sys.exit(f"Clean block produced non-zero syndromes (ecLen {ec_len})")
        if kind == "errors" and not any(exp):
            return
        n = len(block)
        lines.extend([ec_len, n >> 8, n & 0xFF] + block + exp)
        kinds[kind] += 1

    # Cover every (version, level) shape
    for version in range(1, 41):
        for level in [1, 0, 3, 2]: # L, M, Q, H
            bp = blocks_ref.get_block_params(version, level)
            ec_len = bp.ecLen
            # Group 1 blocks
            d1 = bp.d1
            n1_total = d1 + ec_len
            shapes.add((ec_len, n1_total))
            data = [rng.randrange(256) for _ in range(d1)]
            good = rs_ref.encode_block(data, ec_len)
            record(good, ec_len, "clean")
            for cnt in (1, ec_len // 2, rng.randint(1, ec_len)):
                record(corrupt(rng, good, cnt), ec_len, "errors")

            # Group 2 blocks if n2 > 0
            if bp.n2 > 0:
                d2 = bp.d1 + 1
                n2_total = d2 + ec_len
                shapes.add((ec_len, n2_total))
                data2 = [rng.randrange(256) for _ in range(d2)]
                good2 = rs_ref.encode_block(data2, ec_len)
                record(good2, ec_len, "clean")
                for cnt in (1, ec_len // 2, rng.randint(1, ec_len)):
                    record(corrupt(rng, good2, cnt), ec_len, "errors")

    shapes = sorted(shapes)
    while len(lines) < (LINES * 3) // 4:
        ec_len, total = rng.choice(shapes)
        d = total - ec_len
        data = [rng.randrange(256) for _ in range(d)]
        good = rs_ref.encode_block(data, ec_len)
        if rng.random() < 0.2:
            record(good, ec_len, "clean")
        else:
            record(corrupt(rng, good, rng.randint(1, ec_len)), ec_len, "errors")

    lines.append(0) # End marker
    lines.extend([0] * (LINES - len(lines))) # Pad to exactly 2^19 lines
    os.makedirs(os.path.dirname(out_file), exist_ok=True)
    with open(out_file, "w") as f:
        f.write("\n".join(f"{v:02x}" for v in lines) + "\n")

    print(f"Wrote {out_file}: {kinds['clean']} clean + {kinds['errors']} error blocks, {len(shapes)} shapes, {len(lines)} lines.")

if __name__ == "__main__":
    main()
