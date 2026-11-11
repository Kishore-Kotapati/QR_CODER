"""test_payload_ref.py -- checks for Person B's payload_ref.py.

The expected answers come from a tiny bit-BUILDER written here, straight from
spec Table 4 (it encodes; the model decodes, so they are separate derivations),
plus two worked examples from the QR standard.

    python3 verification/tests/test_payload_ref.py
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "model"))
import payload_ref as P  # noqa: E402

ALPHA = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:"


# ---------------------------------------------------------------- builder
def width(mode, v):
    band = 0 if v <= 9 else 1 if v <= 26 else 2
    return {"N": (10, 12, 14), "A": (9, 11, 13), "B": (8, 16, 16)}[mode][band]


def seg(mode, text, v):
    """Bit string for one segment, built from spec Table 4."""
    ind = {"N": "0001", "A": "0010", "B": "0100"}[mode]
    n = len(text)
    bits = ind + format(n, f"0{width(mode, v)}b")
    if mode == "N":
        for i in range(0, n, 3):
            g = text[i:i + 3]
            bits += format(int(g), {3: "010b", 2: "07b", 1: "04b"}[len(g)])
    elif mode == "A":
        for i in range(0, n, 2):
            g = text[i:i + 2]
            if len(g) == 2:
                bits += format(45 * ALPHA.index(g[0]) + ALPHA.index(g[1]), "011b")
            else:
                bits += format(ALPHA.index(g), "06b")
    else:
        for b in text:                       # text is a bytes object here
            bits += format(b, "08b")
    return bits


def pack(bits, nbytes, terminator=True, pad=True):
    """Add terminator (if room), fill to a byte, then pad bytes EC 11 EC ..."""
    total = 8 * nbytes
    assert len(bits) <= total, "test message too long"
    if terminator:
        bits += "0" * min(4, total - len(bits))
    bits += "0" * (-len(bits) % 8)
    padbytes = ["11101100", "00010001"]
    i = 0
    while len(bits) < total:
        bits += padbytes[i % 2] if pad else "00000000"
        i += 1
    return [int(bits[k:k + 8], 2) for k in range(0, total, 8)]


def decode_bits(bits, v=1, nbytes=None):
    nbytes = nbytes or (len(bits) + 7) // 8
    return P.decode_payload(pack(bits, nbytes), v)


def text(r):
    return bytes(r.out).decode("latin-1")


# ---------------------------------------------------------------- good input
def test_standard_numeric_example():
    # ISO 18004 example: "01234567" -> 0001 0000001000 0000001100 0101011001 1000011
    bits = "0001" "0000001000" "0000001100" "0101011001" "1000011"
    r = decode_bits(bits, 1, 16)
    assert r.ok and text(r) == "01234567", (r.ok, text(r), r.reason)


def test_standard_alnum_example():
    # ISO 18004 example: "AC-42" -> 0010 000000101 00111001110 11100111001 000010
    bits = "0010" "000000101" "00111001110" "11100111001" "000010"
    r = decode_bits(bits, 1, 16)
    assert r.ok and text(r) == "AC-42", (r.ok, text(r), r.reason)


def test_numeric_short_groups_and_leading_zeros():
    for msg in ["7", "42", "007", "0000", "00012", "999999", "1234567890"]:
        r = decode_bits(seg("N", msg, 1), 1, 19)
        assert r.ok and text(r) == msg, msg


def test_alnum_odd_and_even_lengths_all_chars():
    for msg in ["A", "AB", ALPHA, ALPHA[::-1], " $%*+-./:"]:
        r = decode_bits(seg("A", msg, 1), 1, 34)
        assert r.ok and text(r) == msg, msg


def test_byte_mode_keeps_every_value():
    data = bytes([0x00, 0xFF, 0x80, 0x0A, 0x41])
    r = decode_bits(seg("B", data, 1), 1, 19)
    assert r.ok and bytes(r.out) == data


def test_count_width_bands():
    # widths change between versions 9/10 and 26/27 (Table 4)
    for v in (9, 10, 26, 27):
        for mode, msg in (("N", "314159"), ("A", "QR CODE"), ("B", b"hi")):
            r = decode_bits(seg(mode, msg, v), v, 40)
            want = msg if isinstance(msg, str) else msg.decode()
            assert r.ok and text(r) == want, (v, mode)


def test_several_segments_in_order():
    bits = seg("A", "ID:", 1) + seg("N", "12345", 1) + seg("B", b"ok", 1)
    r = decode_bits(bits, 1, 19)
    assert r.ok and text(r) == "ID:12345ok", text(r)
    assert [s["mode"] for s in r.segments] == [P.ALNUM, P.NUMERIC, P.BYTE]


def test_empty_message():
    r = P.decode_payload(pack("", 9), 1)          # terminator then padding
    assert r.ok and r.out == []


def test_zero_length_segment_is_fine():
    r = decode_bits(seg("N", "", 1) + seg("A", "OK", 1), 1, 9)
    assert r.ok and text(r) == "OK"


def test_ends_when_fewer_than_4_bits_left():
    # Numeric "12" takes 4 + 10 + 7 = 21 bits.  In 3 bytes (24 bits) that
    # leaves exactly 3 bits: too few for a mode, so the message just ends.
    bits = seg("N", "12", 1)
    assert len(bits) == 21
    r = P.decode_payload(pack(bits, 3, terminator=False, pad=False), 1)
    assert r.ok and text(r) == "12", r.reason


def test_padding_after_terminator_is_ignored():
    bits = seg("A", "HI", 1) + "0000" + "0010"   # terminator, then junk that looks like a mode
    r = P.decode_payload(pack(bits, 9, terminator=False), 1)
    assert r.ok and text(r) == "HI"


# ---------------------------------------------------------------- must fail
def must_fail(bits, nbytes, v=1, why=""):
    r = P.decode_payload(pack(bits, nbytes, terminator=False), v)
    assert not r.ok, f"should fail: {why}"
    return r


def test_unknown_modes_fail():
    for mode in ["0011", "0101", "0111", "1000", "1001", "1111"]:   # ECI, Kanji, ...
        must_fail(mode + "0" * 20, 4, why=mode)


def test_out_of_range_numeric_fails():
    must_fail("0001" + format(3, "010b") + format(1000, "010b"), 4, why="3 digits 1000")
    must_fail("0001" + format(2, "010b") + format(100, "07b"), 4, why="2 digits 100")
    must_fail("0001" + format(1, "010b") + format(10, "04b"), 4, why="1 digit 10")


def test_out_of_range_alnum_fails():
    must_fail("0010" + format(2, "09b") + format(2025, "011b"), 4, why="pair 2025")
    must_fail("0010" + format(1, "09b") + format(45, "06b"), 4, why="single 45")


def test_largest_valid_values_pass():
    r = decode_bits("0001" + format(3, "010b") + format(999, "010b"), 1, 4)
    assert r.ok and text(r) == "999"
    r = decode_bits("0010" + format(2, "09b") + format(2024, "011b"), 1, 4)
    assert r.ok and text(r) == "::"


def test_segment_running_past_end_fails():
    must_fail("0100" + format(3, "08b") + "01000001", 3, why="count 3, only 1 byte of room")
    must_fail("0100" + format(50, "08b"), 4, why="50 bytes in a 4-byte symbol")


def test_count_field_cut_off_fails():
    # 8 data bits: mode 0001 then only 4 of the 10 count bits exist
    r = P.decode_payload([0b00010000], 1)
    assert not r.ok


# ---------------------------------------------------------------- runner
if __name__ == "__main__":
    tests = [(k, f) for k, f in sorted(globals().items()) if k.startswith("test_")]
    failed = 0
    for name, fn in tests:
        try:
            fn()
            print(f"PASS {name}")
        except Exception as e:                      # assertion or crash
            failed += 1
            print(f"FAIL {name}: {type(e).__name__}: {e}")
    print(f"\n{len(tests) - failed}/{len(tests)} checks passed")
    sys.exit(1 if failed else 0)
