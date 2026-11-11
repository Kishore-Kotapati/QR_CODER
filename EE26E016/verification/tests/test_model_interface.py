"""test_model_interface.py -- checks the functions Person A's decode_ref.py
calls (docs/MODEL_INTERFACE.md v1): front_ref.decode_frontend and the
PayloadResult names message / bytes_out / failed / error_msg.

    python3 verification/tests/test_model_interface.py
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "model"))
import front_ref as F    # noqa: E402
import payload_ref as P  # noqa: E402

BSV = os.environ.get("QR_BSV_DIR", os.path.join(HERE, "..", "..", "bsv"))
TABLES = open(os.path.join(BSV, "QRTables.bsv")).read()
TOTAL = {(int(v), l): int(t) for t, v, l in re.findall(r"total: (\d+) \};  // (\d+)-(\w)", TABLES)}
SAMPLE = F.load_tb_symbol(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tb", "TbSample.bsv"))


def test_total_from_geometry_matches_course_table():
    # all 160 (version, level) entries: total bytes depend only on the version
    for (v, lv), tot in TOTAL.items():
        assert F.total_codewords(v) == tot, (v, lv, F.total_codewords(v), tot)


def test_decode_frontend_on_sample():
    r = F.decode_frontend(SAMPLE)
    assert not r.failed and r.error_msg is None
    assert (r.version, r.level_field, r.mask) == (1, 0b00, 2)
    assert len(r.raw_codewords) == 26 and r.raw_codewords[:2] == [0x20, 0x93]
    d = r.to_dict()
    assert set(d) == {"version", "level_field", "mask", "raw_codewords", "failed", "error_msg"}


def test_decode_frontend_bad_size():
    r = F.decode_frontend([[0] * 22 for _ in range(22)])
    assert r.failed and r.failed_stage == "size" and r.raw_codewords == []


def test_decode_frontend_bad_format():
    m = [row[:] for row in SAMPLE]
    c1, c2 = F.format_positions(21)
    for (r_, c_) in c1[:4] + c2[:4]:            # 4 errors in each copy, both > 3 away
        m[r_][c_] ^= 1
    r = F.decode_frontend(m)
    assert r.failed and r.failed_stage == "format", r.to_dict()


def test_payload_names_on_success():
    raw = F.decode_frontend(SAMPLE).raw_codewords
    p = P.decode_payload(raw[:16], 1)            # v1-M: 16 data bytes, 1 block
    assert p.failed is False and p.error_msg is None
    assert p.message == "HELLO CAD FOR VLSI"
    assert p.bytes_out == list(b"HELLO CAD FOR VLSI")
    assert p.ok and p.out == p.bytes_out         # old names still work


def test_payload_names_on_failure():
    p = P.decode_payload([0b01110000, 0, 0], 1)  # mode 0111 = unknown -> fail
    assert p.failed is True and "unknown mode" in p.error_msg


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
