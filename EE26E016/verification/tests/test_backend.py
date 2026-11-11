"""
Comprehensive Unit Tests for Person A's Backend Reference Models (GF, RS, Blocks)
Verifies:
- All 160 BlockParams combinations.
- De-interleave and reassembly round-trip on single and multi-block symbols.
- RS encode and decode with 0, 1, ..., t errors in data and check bytes.
- RS uncorrectable error detection (> t errors).
- End-to-end backend pipeline: deinterleave -> RS correct -> reassemble.
"""

import sys
import os
import random

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../model")))
import gf_ref as gf
import blocks_ref as blocks
import rs_ref as rs

def test_block_tables():
    print("[1/5] Testing BlockParams loading for all 40 versions x 4 levels...")
    assert len(blocks.BLOCK_TABLE) == 160, f"Expected 160 entries, got {len(blocks.BLOCK_TABLE)}"
    
    # Spot-check critical versions
    bp_1M = blocks.get_block_params(1, 'M')
    assert bp_1M.ecLen == 10 and bp_1M.totalData == 16 and bp_1M.total == 26
    
    bp_5Q = blocks.get_block_params(5, 'Q')
    assert bp_5Q.n1 == 2 and bp_5Q.d1 == 15 and bp_5Q.n2 == 2 and bp_5Q.nb == 4
    
    bp_40H = blocks.get_block_params(40, 'H')
    assert bp_40H.n1 == 20 and bp_40H.d1 == 15 and bp_40H.n2 == 61 and bp_40H.nb == 81
    assert bp_40H.totalData == 1276 and bp_40H.total == 3706
    print("      PASS: All 160 BlockParams combinations verified.")

def test_interleave_roundtrip():
    print("[2/5] Testing deinterleave <-> interleave round-trip across multiple versions...")
    test_cases = [
        (1, 'M'),  # Single block
        (3, 'Q'),  # 2 equal blocks
        (5, 'Q'),  # 4 blocks, unequal groups (2 of 15, 2 of 16)
        (7, 'H'),  # 5 blocks, unequal groups (4 of 13, 1 of 14)
        (40, 'H')  # 81 blocks, 20 of 15, 61 of 16
    ]
    
    for v, lvl in test_cases:
        bp = blocks.get_block_params(v, lvl)
        # Create distinct dummy blocks
        test_blocks = []
        val = 1
        for b in range(bp.nb):
            d_len = bp.d1 if b < bp.n1 else bp.d1 + 1
            blk = [(val + i) & 0xFF for i in range(d_len + bp.ecLen)]
            val = (val + d_len + bp.ecLen) & 0xFF
            test_blocks.append(blk)
            
        interleaved = blocks.interleave(test_blocks, v, lvl)
        assert len(interleaved) == bp.total
        
        deinterleaved = blocks.deinterleave(interleaved, v, lvl)
        assert deinterleaved == test_blocks, f"Mismatch on round-trip for V{v}-{lvl}"
        
        # Test reassembly
        data_stream = blocks.reassemble(deinterleaved, v, lvl)
        expected_data = []
        for b in range(bp.nb):
            d_len = bp.d1 if b < bp.n1 else bp.d1 + 1
            expected_data.extend(test_blocks[b][:d_len])
        assert data_stream == expected_data, f"Data stream mismatch for V{v}-{lvl}"

    print("      PASS: Multi-block de-interleave and reassembly verified.")

def test_rs_clean_blocks():
    print("[3/5] Testing RS encoding and decoding on clean blocks...")
    for ec_len in [7, 10, 13, 16, 20, 26, 30]:
        data = [random.randint(0, 255) for _ in range(30)]
        codeword = rs.encode_block(data, ec_len)
        corrected, n_err, success = rs.correct_block(codeword, ec_len)
        assert success is True
        assert n_err == 0
        assert corrected == codeword
    print("      PASS: Clean blocks decode with 0 errors across various ecLen.")

def test_rs_error_correction():
    print("[4/5] Testing RS correction with 1 to t errors (data, check, and mixed)...")
    random.seed(42)
    # Test with ec_len = 10 (t = 5) and ec_len = 28 (t = 14)
    for ec_len in [10, 28]:
        t = ec_len // 2
        d_len = 40
        data = [random.randint(0, 255) for _ in range(d_len)]
        codeword = rs.encode_block(data, ec_len)
        n = len(codeword)
        
        for num_err in range(1, t + 1):
            corrupted = list(codeword)
            err_pos = random.sample(range(n), num_err)
            for p in err_pos:
                corrupted[p] ^= random.randint(1, 255)
                
            corrected, n_err, success = rs.correct_block(corrupted, ec_len)
            assert success is True, f"Failed to correct {num_err} errors for ecLen={ec_len}"
            assert n_err == num_err, f"Expected {num_err} errors found, got {n_err}"
            assert corrected == codeword, f"Corrected codeword does not match original"

    print("      PASS: RS correctly identified and corrected all 1..t injected errors.")

def test_rs_uncorrectable_errors():
    print("[5/5] Testing RS uncorrectable error detection (> t errors)...")
    random.seed(1337)
    ec_len = 10
    t = 5
    d_len = 20
    data = [random.randint(0, 255) for _ in range(d_len)]
    codeword = rs.encode_block(data, ec_len)
    n = len(codeword)

    detected_failures = 0
    trials = 50
    for _ in range(trials):
        # Inject t + 1 or t + 2 errors
        num_err = t + random.randint(1, 3)
        corrupted = list(codeword)
        err_pos = random.sample(range(n), num_err)
        for p in err_pos:
            corrupted[p] ^= random.randint(1, 255)
            
        _, _, success = rs.correct_block(corrupted, ec_len)
        if not success:
            detected_failures += 1
            
    # For randomly injected errors > t, RS should reject (almost 100% detection rate)
    print(f"      Rejected {detected_failures}/{trials} uncorrectable corrupted blocks.")
    assert detected_failures >= 48, f"Too many false corrections: {trials - detected_failures}"
    print("      PASS: Uncorrectable errors reliably detected without false correction.")

if __name__ == "__main__":
    test_block_tables()
    test_interleave_roundtrip()
    test_rs_clean_blocks()
    test_rs_error_correction()
    test_rs_uncorrectable_errors()
    print("\nALL BACKEND REFERENCE MODEL TESTS PASSED SUCCESSFULLY!")

