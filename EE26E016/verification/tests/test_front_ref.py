"""test_front_ref.py -- checks for Person B's front_ref.py.

Each check uses evidence that does NOT come from front_ref itself:
spec arithmetic, coding-theory counts, the supplied QRTables.bsv, or the
supplied sample symbol.  Run from the repo root:

    python3 verification/tests/test_front_ref.py
    QR_BSV_DIR=path/to/bsv python3 verification/tests/test_front_ref.py

Works with or without pytest.  Prints PASS/FAIL per check and a summary.
"""
import os
import re
import sys
from itertools import combinations

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "model"))
import front_ref as F  # noqa: E402

BSV = os.environ.get("QR_BSV_DIR", os.path.join(HERE, "..", "..", "bsv"))
TABLES = open(os.path.join(BSV, "QRTables.bsv")).read()
SAMPLE = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tb", "TbSample.bsv")).read()

# Supplied table: BlockParams.total per (version, level letter)
TOTAL = {(int(v), l): int(t) for t, v, l in re.findall(
    r"total: (\d+) \};  // (\d+)-(\w)", TABLES)}
# Supplied table: the 32 stored format words, index = (level_field << 3) | mask
FMT_TABLE = [int(x) for x in re.search(
    r"Integer t\[32\] = \{([^}]*)\}", TABLES).group(1).split(",")]
# Supplied sample symbol
ROWS = re.findall(r"symbol\[\s*\d+\] = 'b([01]+);", SAMPLE)
SAMPLE_M = [[int(ch) for ch in row] for row in ROWS]

# Leftover data modules after the last whole codeword (ISO/IEC 18004, "remainder
# bits"); a well-known table, independent of anything in front_ref.
REMAINDER = {v: (0 if v == 1 else 7 if v <= 6 else 0 if v <= 13 else
                 3 if v <= 20 else 4 if v <= 27 else 3 if v <= 34 else 0)
             for v in range(1, 41)}


def popcount(x):
    return bin(x).count("1")


# ------------------------------------------------------------------ G1
def test_version_all_sizes():
    for n in range(256):
        expect = (n - 17) // 4 if (n >= 21 and n <= 177 and (n - 17) % 4 == 0) else None
        assert F.version_from_size(n) == expect, f"N={n}"


# ------------------------------------------------------------------ 1.2
def test_format_positions_shape_and_disjoint():
    for v in (1, 2, 7, 40):
        n = 17 + 4 * v
        c1, c2 = F.format_positions(n)
        assert len(c1) == 15 and len(c2) == 15
        assert len(set(c1)) == 15 and len(set(c2)) == 15
        assert not set(c1) & set(c2), "copies overlap"
        assert (6, 8) not in c1 and (8, 6) not in c1, "timing module used"
        assert (n - 8, 8) not in c2, "dark module used as format bit"


def test_bch_matches_supplied_table():
    words = F.valid_format_words()
    assert len(words) == 32
    for d in range(32):
        assert F.bch_encode(d) == FMT_TABLE[d], f"data5={d:05b}"
        assert words[FMT_TABLE[d]] == (d >> 3, d & 7)


def test_bch_min_distance_is_7():
    w = list(F.valid_format_words())
    assert min(popcount(a ^ b) for a, b in combinations(w, 2)) == 7


def test_nearest_recovers_up_to_3_errors():
    for word, (lv, mk) in F.valid_format_words().items():
        for k in range(4):
            for bits in combinations(range(15), k):
                e = sum(1 << b for b in bits)
                d, l2, m2 = F.nearest_format(word ^ e)
                assert (d, l2, m2) == (k, lv, mk), f"word={word:015b} err={e:015b}"


def test_exhaustive_single_copy_count():
    # Radius-3 spheres around 32 words are disjoint (d_min = 7), each holds
    # 1+15+105+455 = 576 words, so exactly 32*576 = 18432 inputs decode.
    ok = sum(1 for x in range(1 << 15) if F.nearest_format(x)[0] <= 3)
    assert ok == 18432, ok
    for x in range(1 << 15):  # distance reported must be a true distance
        d, lv, mk = F.nearest_format(x)
        assert popcount(x ^ FMT_TABLE[(lv << 3) | mk]) == d


def test_two_copy_rules():
    words = list(F.valid_format_words().items())
    (wa, a), (wb, b) = words[3], words[20]
    assert F.decode_format(wa ^ 0b11, wb ^ 0b111) == a        # copy 1 nearer
    assert F.decode_format(wa ^ 0b111, wb ^ 0b1) == b         # copy 2 nearer
    assert F.decode_format(wa ^ 0b11, wb ^ 0b11) == a         # tie -> copy 1
    far = next(x for x in range(1 << 15)                      # > 3 from every
               if min(popcount(x ^ w) for w in FMT_TABLE) > 3)  # valid word
    assert F.decode_format(far, far) is None                  # both unreadable
    assert F.decode_format(far, wb) == b                      # copy 1 bad only
    assert F.decode_format(wa, far) == a                      # copy 2 bad only


def test_sample_format_is_M_mask2():
    c1, c2 = F.read_format(SAMPLE_M, 21)
    assert c1 == c2 == 0b101111001111100, (bin(c1), bin(c2))
    assert F.decode_format(c1, c2) == (0b00, 2)   # README: level M, mask 2


# ------------------------------------------------------------------ 1.1
def test_data_module_count_all_versions():
    for v in range(1, 41):
        fm = F.function_map(v)
        n = 17 + 4 * v
        assert len(fm) == n and all(len(r) == n for r in fm)
        data = sum(not x for row in fm for x in row)
        assert data == 8 * TOTAL[(v, "L")] + REMAINDER[v], f"v={v}: {data}"


def test_fixed_function_modules():
    for v in (1, 2, 7, 40):
        n, fm = 17 + 4 * v, F.function_map(v)
        for r, c in [(0, 0), (8, 8), (6, n // 2), (n // 2, 6), (n - 8, 8),
                     (0, n - 1), (n - 1, 0), (8, n - 8)]:
            assert fm[r][c], f"v={v} ({r},{c}) should be function"
        assert not fm[n - 1][n - 1], f"v={v} bottom-right corner is data"


def test_alignment_examples_from_spec():
    # v2: single centre (18,18); v7: six centres (spec 1.1)
    fm = F.function_map(2)
    assert fm[18][18] and fm[16][16] and fm[20][20] and not fm[15][18]
    fm7 = F.function_map(7)
    for r, c in [(6, 22), (22, 6), (22, 22), (22, 38), (38, 22), (38, 38)]:
        assert fm7[r][c], (r, c)


# ------------------------------------------------------------------ 1.3
def test_masks_table2_spot_values():
    # hand-evaluated from Table 2 at (r, c) = (2, 3) and (1, 1)
    want_23 = [False, True, True, False, True, True, True, False]
    want_11 = [True, False, False, False, True, False, True, False]
    for m in range(8):
        assert F.mask_inverts(m, 2, 3) == want_23[m], f"mask {m} @ (2,3)"
        assert F.mask_inverts(m, 1, 1) == want_11[m], f"mask {m} @ (1,1)"


def test_zigzag_properties():
    for v in range(1, 41):
        n, fm, order = 17 + 4 * v, F.function_map(v), F.data_module_order(v)
        assert order[0] == (n - 1, n - 1) and order[1] == (n - 1, n - 2)
        assert len(order) == len(set(order)), f"v={v} duplicate visit"
        assert all(not fm[r][c] for r, c in order), f"v={v} visits function module"
        assert all(c != 6 for _, c in order)
        assert len(order) == sum(not x for row in fm for x in row)


def test_sample_first_codewords():
    # Alphanumeric, count 18, "HE" = 17*45+14 = 779:
    # 0010 000010010 01100001011 ... -> 0x20, 0x93  (derived from spec 1.5 by hand)
    raw = F.raw_codewords(SAMPLE_M, 1, 2, TOTAL[(1, "M")])
    assert len(raw) == 26
    assert raw[0] == 0x20 and raw[1] == 0x93, [hex(b) for b in raw[:4]]


def test_alignment_list_matches_supplied_table():
    # The model's list was typed from the ISO standard; the course table is a
    # separate source.  They must agree for all 40 versions.
    table = {int(v): ([int(x) for x in lst.split(",")] if lst.strip() else [])
             for v, lst in re.findall(r"(\d+): begin n = \d; p = 56'h[0-9a-f]+; end  // \[([^\]]*)\]", TABLES)}
    assert len(table) == 40
    for v in range(1, 41):
        assert F.alignment_centres(v) == table[v], f"v={v}"


def test_damaged_finder_does_not_change_raw_bytes():
    # Spec 4.1: damage to fixed patterns must not matter.  Flip whole finder.
    m = [row[:] for row in SAMPLE_M]
    for r in range(7):
        for c in range(7):
            m[r][c] ^= 1
    assert F.raw_codewords(m, 1, 2, 26) == F.raw_codewords(SAMPLE_M, 1, 2, 26)


# ------------------------------------------------------------------ runner
if __name__ == "__main__":
    tests = [(k, f) for k, f in sorted(globals().items()) if k.startswith("test_")]
    failed = 0
    for name, fn in tests:
        try:
            fn()
            print(f"PASS {name}")
        except NotImplementedError:
            failed += 1
            print(f"TODO {name}  (function not written yet)")
        except Exception as e:                      # assertion or crash
            failed += 1
            print(f"FAIL {name}: {type(e).__name__}: {e}")
    print(f"\n{len(tests) - failed}/{len(tests)} checks passed")
    sys.exit(1 if failed else 0)
