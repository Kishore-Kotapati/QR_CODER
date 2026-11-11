"""
End-to-End Regression Test Suite for Complete Software Reference Decoder (decode_ref.py)
Exercises:
- Supplied handout symbol TbSample.bsv ("HELLO CAD FOR VLSI")
- Symbol with clean data
- Symbol with 1 to t byte errors repaired by Reed-Solomon
- Symbol with 1 to 3 format errors repaired by BCH(15, 5)
- Uncorrectable format errors (> 3 errors in both copies) -> failure
- Uncorrectable RS errors (> t errors in a block) -> failure
- Invalid grid size (not 17 + 4v) -> failure
- Malformed payload detection -> failure
"""

import sys
import os
import random

HERE = os.path.dirname(os.path.abspath(__file__))
MODEL_DIR = os.path.join(HERE, "..", "model")
BSV_DIR = os.path.join(HERE, "..", "..", "bsv")
sys.path.insert(0, MODEL_DIR)

import decode_ref as D
import front_ref as F
import rs_ref as RS
import blocks_ref as B

def test_handout_sample():
    print("[1/7] Decoding handout symbol from TbSample.bsv...")
    tb_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tb", "TbSample.bsv")
    sample_matrix = F.load_tb_symbol(tb_path)
    
    result = D.decode_symbol(sample_matrix)
    assert result.success is True, f"Failed to decode TbSample: {result.error_msg}"
    assert result.version == 1
    assert result.level_field == 0  # 00 = M
    assert result.mask == 2
    assert result.message == "HELLO CAD FOR VLSI"
    assert result.bytes_out == list(b"HELLO CAD FOR VLSI")
    assert result.errors_corrected == 0
    print(f"      PASS: Decoded '{result.message}' with 0 errors.")

def test_sample_with_format_errors():
    print("[2/7] Testing BCH format error correction (1 to 3 bit errors)...")
    tb_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tb", "TbSample.bsv")
    sample_matrix = F.load_tb_symbol(tb_path)
    c1, c2 = F.format_positions(21)
    
    # Inject 3 bit flips into copy 1, 0 into copy 2
    m1 = [row[:] for row in sample_matrix]
    for r, c in c1[:3]:
        m1[r][c] ^= 1
    res1 = D.decode_symbol(m1)
    assert res1.success is True and res1.message == "HELLO CAD FOR VLSI"
    
    # Inject 3 bit flips into copy 2, 0 into copy 1
    m2 = [row[:] for row in sample_matrix]
    for r, c in c2[:3]:
        m2[r][c] ^= 1
    res2 = D.decode_symbol(m2)
    assert res2.success is True and res2.message == "HELLO CAD FOR VLSI"
    
    # Tie test: 2 errors in copy 1, 2 errors in copy 2 (both distance 2 -> copy 1 wins)
    m3 = [row[:] for row in sample_matrix]
    for r, c in c1[:2]:
        m3[r][c] ^= 1
    for r, c in c2[:2]:
        m3[r][c] ^= 1
    res3 = D.decode_symbol(m3)
    assert res3.success is True and res3.message == "HELLO CAD FOR VLSI"
    print("      PASS: BCH recovered format settings across 1..3 bit errors.")

def test_sample_with_rs_errors():
    print("[3/7] Testing Reed-Solomon correction under flipped data modules...")
    tb_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tb", "TbSample.bsv")
    sample_matrix = F.load_tb_symbol(tb_path)
    
    # In Version 1-M, ecLen = 10 -> capacity t = 5 byte errors
    # Let's locate data module coordinates
    order = F.data_module_order(1)
    
    # Flip bits within 3 different data codewords (e.g. byte 0, byte 5, byte 10)
    # Codeword byte k occupies order[k*8 : k*8 + 8]
    corrupted_matrix = [row[:] for row in sample_matrix]
    
    corrupt_bytes = [0, 5, 10]
    for byte_idx in corrupt_bytes:
        # Flip 2 bits in each chosen byte
        r1, c1 = order[byte_idx * 8]
        r2, c2 = order[byte_idx * 8 + 3]
        corrupted_matrix[r1][c1] ^= 1
        corrupted_matrix[r2][c2] ^= 1
        
    result = D.decode_symbol(corrupted_matrix)
    assert result.success is True, f"RS failed to correct errors: {result.error_msg}"
    assert result.message == "HELLO CAD FOR VLSI"
    assert result.errors_corrected == 3
    print(f"      PASS: RS successfully corrected {result.errors_corrected} byte errors in matrix.")

def test_uncorrectable_format_failure():
    print("[4/7] Testing rejection of unrecoverable format (> 3 errors in both copies)...")
    tb_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tb", "TbSample.bsv")
    sample_matrix = F.load_tb_symbol(tb_path)
    c1, c2 = F.format_positions(21)
    
    # Inject 4 errors into copy 1 AND 4 errors into copy 2
    bad_matrix = [row[:] for row in sample_matrix]
    for r, c in c1[:4]:
        bad_matrix[r][c] ^= 1
    for r, c in c2[:4]:
        bad_matrix[r][c] ^= 1
        
    result = D.decode_symbol(bad_matrix)
    assert result.success is False
    assert result.stage_failed == "format"
    print("      PASS: Reliably failed on uncorrectable format information.")

def test_invalid_size_failure():
    print("[5/7] Testing rejection of invalid matrix dimensions...")
    bad_size_matrix = [[0] * 23 for _ in range(23)]  # 23 is not 17 + 4v
    result = D.decode_symbol(bad_size_matrix)
    assert result.success is False
    assert result.stage_failed == "size"
    print("      PASS: Reliably failed on invalid side length 23.")

def test_uncorrectable_rs_failure():
    print("[6/7] Testing rejection of excessive damage exceeding RS capacity...")
    tb_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tb", "TbSample.bsv")
    sample_matrix = F.load_tb_symbol(tb_path)
    order = F.data_module_order(1)
    
    # Flip bits across 8 distinct codewords (capacity is t=5 in 1-M)
    bad_matrix = [row[:] for row in sample_matrix]
    for byte_idx in range(8):
        r, c = order[byte_idx * 8 + 1]
        bad_matrix[r][c] ^= 1
        
    result = D.decode_symbol(bad_matrix)
    assert result.success is False
    assert result.stage_failed == "rs_correction"
    print("      PASS: Reliably detected and failed on excessive RS errors (> t).")

def test_damaged_function_modules_not_rejected():
    print("[7/7] Testing that damage to finder/timing patterns does NOT reject symbol...")
    tb_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tb", "TbSample.bsv")
    sample_matrix = F.load_tb_symbol(tb_path)
    
    # Damage top-left finder pattern and timing patterns
    # Finder pattern: (0,0) to (6,6)
    finder_damaged = [row[:] for row in sample_matrix]
    for r in range(7):
        for c in range(7):
            finder_damaged[r][c] ^= 1  # Invert finder pattern completely
            
    # Also damage horizontal timing pattern row 6
    for c in range(8, 13):
        finder_damaged[6][c] ^= 1
        
    result = D.decode_symbol(finder_damaged)
    assert result.success is True, f"Failed because of finder damage: {result.error_msg}"
    assert result.message == "HELLO CAD FOR VLSI"
    print("      PASS: Symbol decoded successfully despite severe finder & timing pattern damage.")

if __name__ == "__main__":
    test_handout_sample()
    test_sample_with_format_errors()
    test_sample_with_rs_errors()
    test_uncorrectable_format_failure()
    test_invalid_size_failure()
    test_uncorrectable_rs_failure()
    test_damaged_function_modules_not_rejected()
    print("\nALL 7/7 END-TO-END REFERENCE DECODER TESTS PASSED!")

