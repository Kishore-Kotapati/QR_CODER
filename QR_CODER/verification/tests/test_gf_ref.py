"""
Unit Test and Vector Generation for GF(2^8) Reference Model
Verifies all 65,536 multiplication pairs, inverses, and powers against QRTables.bsv constants.
Generates verification/vectors/backend/gf_mul.hex for Person B's TbGFVectors.
"""

import sys
import os

# Add model directory to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../model")))
import gf_ref

# Reference values from QRTables.bsv lines 250, 256, 264-270
ALPHA_POW_SAMPLE = [
    1, 2, 4, 8, 16, 32, 64, 128, 29, 58, 116, 232, 205, 135, 19, 38,
    76, 152, 45, 90, 180, 117, 234, 201, 143, 3, 6, 12, 24, 48
]

ALPHA_INV_POW_SAMPLE = [
    1, 142, 71, 173, 216, 108, 54, 27, 131, 207, 233, 250, 125, 176, 88, 44
]

GF_INV_SAMPLES = {
    0: 0,
    1: 1,
    2: 142,
    3: 244,
    4: 71,
    5: 167,
    6: 122,
    7: 186
}

def test_alpha_tables():
    print("[1/5] Checking alphaPow against QRTables.bsv...")
    for j, expected in enumerate(ALPHA_POW_SAMPLE):
        actual = gf_ref.alpha_pow(j)
        assert actual == expected, f"alphaPow({j}): expected {expected}, got {actual}"
    print(f"      PASS: All {len(ALPHA_POW_SAMPLE)} alphaPow samples matched.")

    print("[2/5] Checking alphaInvPow against QRTables.bsv...")
    for j, expected in enumerate(ALPHA_INV_POW_SAMPLE):
        # alpha^(-j) in GF(256) is alpha^(255 - (j % 255))
        inv_j = (255 - j) % 255 if j != 0 else 0
        actual = gf_ref.alpha_pow(inv_j)
        assert actual == expected, f"alphaInvPow({j}): expected {expected}, got {actual}"
    print(f"      PASS: All {len(ALPHA_INV_POW_SAMPLE)} alphaInvPow samples matched.")

def test_inverses():
    print("[3/5] Checking multiplicative inverses...")
    for a, expected in GF_INV_SAMPLES.items():
        actual = gf_ref.gf_inv_safe(a)
        assert actual == expected, f"gfInv({a}): expected {expected}, got {actual}"

    # Verify a * inv(a) == 1 for all a in 1..255
    for a in range(1, 256):
        inv_a = gf_ref.gf_inv(a)
        prod = gf_ref.gf_mul(a, inv_a)
        assert prod == 1, f"Inverse check failed for a={a}: a * inv(a) = {prod} != 1"
    print("      PASS: All 255 nonzero elements satisfy a * a^(-1) == 1.")

def test_exhaustive_multiplication():
    print("[4/5] Checking all 65,536 multiplication pairs (Bitwise vs Log/Antilog)...")
    mismatches = 0
    for a in range(256):
        for b in range(256):
            p1 = gf_ref.gf_mul_bitwise(a, b)
            p2 = gf_ref.gf_mul(a, b)
            if p1 != p2:
                mismatches += 1
                if mismatches <= 5:
                    print(f"      MISMATCH at ({a}, {b}): bitwise={p1}, table={p2}")
    assert mismatches == 0, f"Total mismatches: {mismatches}"
    print("      PASS: Exhaustive check of 65,536 pairs passed with 0 mismatches.")

def generate_gf_hex_vectors():
    out_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "../vectors/backend"))
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "gf_mul.hex")
    print(f"[5/5] Generating {out_path} for Person B...")
    
    count = 0
    with open(out_path, "w") as f:
        for a in range(256):
            for b in range(256):
                prod = gf_ref.gf_mul(a, b)
                # 2 hex digits per line
                f.write(f"{prod:02X}\n")
                count += 1
                
    assert count == 65536, f"Expected 65,536 lines, got {count}"
    print(f"      PASS: Successfully generated {count} lines in {out_path}")

if __name__ == "__main__":
    test_alpha_tables()
    test_inverses()
    test_exhaustive_multiplication()
    generate_gf_hex_vectors()
    print("\nALL GF(256) CHECKS PASSED SUCCESSFULLY.")

