#!/usr/bin/env python3
"""
Generate blocks_vectors.hex using Person A's independent blocks_ref and rs_ref models.
Format: RS_VECTOR_FORMAT.md File 3 (2,097,152 lines).
"""
import sys
import os
import random

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "model")))
import rs_ref
import blocks_ref

LINES = 1 << 21  # 2,097,152 lines
LEVELS = [1, 0, 3, 2] # 1=L, 0=M, 3=Q, 2=H

def corrupt(rng, block, count):
    bad = list(block)
    for pos in rng.sample(range(len(bad)), count):
        bad[pos] ^= rng.randrange(1, 256)
    return bad

def make_symbol(rng, version, level, error_plan):
    bp = blocks_ref.get_block_params(version, level)
    blocks_data = []
    clean_blocks = []
    
    # 1. Create clean blocks
    for b in range(bp.nb):
        d = bp.d1 if b < bp.n1 else bp.d1 + 1
        data = [rng.randrange(256) for _ in range(d)]
        blocks_data.append(data)
        codeword = rs_ref.encode_block(data, bp.ecLen)
        clean_blocks.append(codeword)
        
    expected_data = []
    for d in blocks_data:
        expected_data.extend(d)
        
    # 2. Add errors according to error_plan
    damaged_blocks = []
    has_excessive = False
    for b in range(bp.nb):
        t = bp.ecLen // 2
        cnt = error_plan(b, bp.ecLen, len(clean_blocks[b]))
        if cnt > t:
            has_excessive = True
        damaged_blocks.append(corrupt(rng, clean_blocks[b], cnt) if cnt > 0 else list(clean_blocks[b]))
        
    # 3. Interleave into raw bytes
    raw = blocks_ref.interleave(damaged_blocks, version, level)
    
    # 4. Model verification
    deinterleaved = blocks_ref.deinterleave(raw, version, level)
    corrected_blocks = []
    model_success = True
    for b in range(bp.nb):
        corr, nerr, ok = rs_ref.correct_block(deinterleaved[b], bp.ecLen)
        if not ok:
            model_success = False
            break
        corrected_blocks.append(corr)
        
    status = 0 if model_success else 1
    return raw, expected_data, bp.total, bp.totalData, status

def main():
    out_file = sys.argv[1] if len(sys.argv) > 1 else "project/verification/vectors/backend/blocks_vectors.hex"
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 2028
    rng = random.Random(seed)
    lines = []
    count = {0: 0, 1: 0}

    def emit(version, level, status, raw, data, total, total_data):
        lines.extend([version, level, status, total >> 8, total & 0xFF,
                      total_data >> 8, total_data & 0xFF] + raw + data)
        count[status] += 1

    # For all 160 layouts:
    # 1. Clean symbol
    # 2. Every block <= t errors, one block exactly t
    # 3. One block has > t errors (must fail)
    for version in range(1, 41):
        for level in LEVELS:
            # 1. Clean symbol
            raw, data, tot, tdat, status = make_symbol(rng, version, level, lambda b, e, n: 0)
            emit(version, level, status, raw, data, tot, tdat)

            # 2. Symbol with fixable errors (<= t)
            bp = blocks_ref.get_block_params(version, level)
            full_b = rng.randrange(bp.nb)
            def fixable_plan(b, e, n, full_b=full_b):
                return (e // 2) if b == full_b else rng.randint(0, e // 2)
            raw, data, tot, tdat, status = make_symbol(rng, version, level, fixable_plan)
            emit(version, level, status, raw, data, tot, tdat)

            # 3. Symbol with unfixable error (> t in one block)
            bad_b = rng.randrange(bp.nb)
            def unfixable_plan(b, e, n, bad_b=bad_b):
                if b == bad_b:
                    return (e // 2) + rng.randint(1, 3)
                return rng.randint(0, e // 2)
            raw, data, tot, tdat, status = make_symbol(rng, version, level, unfixable_plan)
            emit(version, level, status, raw, data, tot, tdat)

    # Pad with additional random symbols until ~3/4 full
    while len(lines) < (LINES * 3) // 4:
        v = rng.randint(1, 40)
        lvl = rng.choice(LEVELS)
        bp = blocks_ref.get_block_params(v, lvl)
        if rng.random() < 0.7:
            # Fixable
            raw, data, tot, tdat, status = make_symbol(rng, v, lvl, lambda b, e, n: rng.randint(0, e // 2))
        else:
            # Unfixable
            bad_b = rng.randrange(bp.nb)
            raw, data, tot, tdat, status = make_symbol(rng, v, lvl, lambda b, e, n: (e // 2 + 1) if b == bad_b else 0)
        emit(v, lvl, status, raw, data, tot, tdat)

    lines.append(0) # End marker
    lines.extend([0] * (LINES - len(lines))) # Pad to exactly 2^21 lines
    os.makedirs(os.path.dirname(out_file), exist_ok=True)
    with open(out_file, "w") as f:
        f.write("\n".join(f"{v:02x}" for v in lines) + "\n")

    print(f"Wrote {out_file}: {count[0]} fixable + {count[1]} unfixable symbols, {len(lines)} lines.")

if __name__ == "__main__":
    main()
