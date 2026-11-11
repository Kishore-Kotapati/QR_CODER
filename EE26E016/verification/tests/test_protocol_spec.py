"""test_protocol_spec.py -- does the interface checker catch what it should?

Each test writes a tiny hand-made log (good or with ONE planted mistake) and
checks the verdict.  A checker that never complains is useless, so most tests
here are "this broken log must be caught".

    python3 verification/tests/test_protocol_spec.py
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "model"))
import protocol_spec as PS  # noqa: E402


def run(log, expected=None, limit=None):
    return PS.check(PS.parse_log(log), expected, limit)


def good_hi():
    """A correct decode of 'HI' with a stall before the second byte."""
    return """
@0 status 0 0
@1 start 21
@2 status 0 0
@2 req 0 8
@3 req 1 8
@40 byte 48 0
@55 byte 49 1
@56 status 0 1
@60 status 0 1
"""


# ------------------------------------------------------------- good logs pass
def test_good_decode_passes():
    r = run(good_hi(), [("ok", b"HI")])
    assert r.ok, r.problems


def test_empty_message_passes():
    r = run("@0 status 0 0\n@1 start 21\n@2 status 0 0\n@30 status 0 1\n", [("ok", b"")])
    assert r.ok, r.problems


def test_failure_after_some_bytes_passes():
    # C2 allows failed to rise after bytes were returned
    log = "@0 status 0 0\n@1 start 21\n@2 status 0 0\n@10 byte 41 0\n@20 status 1 0\n"
    r = run(log, [("fail", None)])
    assert r.ok, r.problems


def test_back_to_back_decodes_pass():
    log = good_hi() + "@70 start 25\n@71 status 0 0\n@90 status 1 0\n@95 start 22\n@96 status 0 0\n@97 status 1 0\n"
    r = run(log, [("ok", b"HI"), ("fail", None), ("fail", None)])
    assert r.ok, r.problems


def test_status_still_high_in_the_start_cycle_is_fine():
    # In the cycle start fires, failed/done still show the OLD decode's result.
    log = "@0 status 0 0\n@1 start 21\n@2 status 1 0\n@5 start 21\n@5 status 1 0\n@6 status 0 0\n@9 status 1 0\n"
    r = run(log, [("fail", None), ("fail", None)])
    assert r.ok, r.problems


# ------------------------------------------------------------- broken logs caught
def must_catch(log, expected=None, words="", limit=None):
    r = run(log, expected, limit)
    assert not r.ok, "checker missed the planted mistake"
    assert any(words in p for p in r.problems), r.problems


def test_catches_both_high():
    must_catch("@1 start 21\n@2 status 0 0\n@9 status 1 1\n", words="both high")


def test_catches_done_before_last_byte():
    must_catch("@1 start 21\n@2 status 0 0\n@5 byte 41 0\n@6 status 0 1\n", words="never taken")


def test_catches_done_same_cycle_as_last_byte():
    must_catch("@1 start 21\n@2 status 0 0\n@5 byte 41 1\n@5 status 0 1\n", words="same cycle")


def test_catches_byte_after_failed():
    must_catch("@1 start 21\n@2 status 0 0\n@5 status 1 0\n@7 byte 41 1\n", words="C3")


def test_catches_byte_after_last():
    must_catch("@1 start 21\n@2 status 0 0\n@5 byte 41 1\n@6 byte 42 1\n@7 status 0 1\n",
               words="after the byte with last")


def test_catches_failed_falling_early():
    must_catch("@1 start 21\n@2 status 0 0\n@5 status 1 0\n@8 status 0 0\n", words="fell")


def test_catches_done_never_rising_after_last():
    must_catch("@1 start 21\n@2 status 0 0\n@5 byte 41 1\n@9 start 21\n@10 status 1 0\n",
               words="done never rose")


def test_catches_two_requests_in_one_cycle():
    must_catch("@1 start 21\n@2 status 0 0\n@3 req 0 8\n@3 req 1 8\n@9 status 1 0\n", words="C4")


def test_catches_wrong_bytes():
    must_catch(good_hi(), [("ok", b"HO")], words="bytes differ")


def test_catches_success_when_failure_expected():
    must_catch(good_hi(), [("fail", None)], words="expected failed")


def test_catches_decode_that_never_ends():
    must_catch("@1 start 21\n@2 status 0 0\n@500 req 3 3\n", words="never ended")


def test_catches_timeout():
    must_catch("@1 start 21\n@2 status 0 0\n@500 req 3 3\n@600 status 1 0\n", words="has not ended", limit=100)


def test_catches_status_high_before_any_start():
    must_catch("@0 status 1 0\n", words="before any start")


# ------------------------------------------------------------- C5 (static)
def test_c5_port_check():
    good = "module mkQRDecoder(CLK, EN_start, RDY_start, EN_getByte, RDY_getByte, mem_resp_b);"
    assert PS.check_c5_verilog(good) == []
    bad = "module mkQRDecoder(CLK, EN_start, EN_getByte, RDY_getByte, EN_mem_resp);"
    probs = PS.check_c5_verilog(bad)
    assert any("RDY_start" in p for p in probs) and any("EN port" in p for p in probs), probs


# ------------------------------------------------------------- runner
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
