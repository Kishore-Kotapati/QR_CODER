"""test_against_segno.py -- check front_ref + payload_ref against real QR codes.

segno is a QR library written by other people.  It rebuilds the handout's
sample symbol bit-for-bit, so it is a trustworthy outside source.
We ask it for a symbol with a chosen version, level, mask and message, then
check that our models read back exactly those settings and that message.

Needs:  pip install --user segno      (the test is skipped if it is missing)
Run:    python3 verification/tests/test_against_segno.py
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "model"))
import front_ref as F    # noqa: E402
import payload_ref as P  # noqa: E402

try:
    import segno
except ImportError:
    print("SKIP: segno not installed (pip install --user segno)")
    sys.exit(0)

BSV = os.environ.get("QR_BSV_DIR", os.path.join(HERE, "..", "..", "bsv"))
TABLES = open(os.path.join(BSV, "QRTables.bsv")).read()
PARAMS = {}   # (version, level letter) -> (nb, totalData, total)
for e, n1, d1, n2, nb, td, tot, v, l in re.findall(
        r"ecLen: (\d+), n1: (\d+), d1: (\d+), n2: (\d+), nb: (\d+), "
        r"totalData: (\d+), total: (\d+) \};  // (\d+)-(\w)", TABLES):
    PARAMS[(int(v), l)] = (int(nb), int(td), int(tot))

FIELD = {"L": 1, "M": 0, "Q": 3, "H": 2}           # raw level bits (spec 1.2)
LETTER = {v: k for k, v in FIELD.items()}


def make(msg, version, level, mask, mode=None):
    q = segno.make(msg, version=version, error=level.lower(), mask=mask,
                   mode=mode, micro=False, boost_error=False)
    assert q.version == version and q.mask == mask
    return [list(row) for row in q.matrix]          # no quiet zone


def total_for(v, level_field):
    return PARAMS[(v, LETTER[level_field])][2]


def test_settings_every_version_and_level():
    n = 0
    for v in range(1, 41):
        for level in "LMQH":
            mask = (v * 4 + FIELD[level]) % 8           # spread masks around
            t = F.trace(make("CS6230", v, level, mask), total_for)
            assert t["failed_stage"] is None, (v, level)
            assert (t["version"], LETTER[t["level_field"]], t["mask"]) == (v, level, mask)
            assert len(t["raw"]) == total_for(v, FIELD[level])
            n += 1
    print(f"      {n} symbols: version/level/mask all correct")


def test_every_mask_on_small_and_large_versions():
    for v in (1, 2, 7, 14, 27, 40):
        for mask in range(8):
            t = F.trace(make("MASK TEST", v, "Q", mask), total_for)
            assert t["mask"] == mask and t["version"] == v, (v, mask)


def test_full_message_on_single_block_symbols():
    # For symbols with ONE block and no damage, the data bytes are simply the
    # first totalData raw bytes -- no Reed-Solomon or de-interleaving needed.
    # short enough for the smallest symbol (version 1-H holds 9 data bytes)
    messages = [("0123456789", "numeric"), ("HELLO CAD", "alphanumeric"),
                ("Hi!", "byte"), ("7", "numeric"), ("A", "alphanumeric")]
    n = 0
    for (v, level), (nb, td, tot) in sorted(PARAMS.items()):
        if nb != 1:
            continue
        for msg, mode in messages:
            for mask in range(8):
                m = make(msg, v, level, mask, mode)
                t = F.trace(m, total_for)
                r = P.decode_payload(t["raw"][:td], v)
                assert r.ok and bytes(r.out).decode("latin-1") == msg, (v, level, mask, msg, r.reason)
                n += 1
    print(f"      {n} single-block symbols decoded to the right message")


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
    print(f"\n{len(tests) - failed}/{len(tests)} checks passed  (segno {segno.__version__})")
    sys.exit(1 if failed else 0)
