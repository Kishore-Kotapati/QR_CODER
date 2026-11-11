#!/usr/bin/env python3
"""Sweep generator that needs only the `segno` library (no team model).

Usage (from qr/work):  python3 verification/sweep/gen_sweep_segno.py <out_dir> [num_cases] [--selfcheck]

Cases vary version, error-correction level, mask, mode (numeric / alphanumeric / byte), message
length (short or full capacity) and damage:
  none   - clean symbol
  limit  - 1 to 3 flipped data/check modules (at most 3 damaged bytes in total, and every
           block of every version/level can repair at least 3 bytes, so it MUST decode)
  over   - about 40 % of the data/check modules flipped (the decoder may report failed, or by
           chance decode to something else; it must not hang)
"""
import json, os, random, sys
import segno

try:
    Overflow = segno.DataOverflowError
except AttributeError:
    Overflow = Exception

ALNUM = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:"
SEGNO_MODE = {"num": "numeric", "alnum": "alphanumeric", "byte": "byte"}
VERSIONS = [1, 2, 3, 6, 7, 9, 10, 14, 20, 21, 26, 27, 30, 35, 40]
LEVELS = ["L", "M", "Q", "H"]


def alphabet(mode):
    if mode == "num":
        return "0123456789"
    if mode == "alnum":
        return ALNUM
    return "".join(chr(c) for c in range(32, 127))


def rand_text(mode, n, rng):
    a = alphabet(mode)
    return "".join(rng.choice(a) for _ in range(n))


def make(text, v, lvl, mask, mode):
    q = segno.make(text, version=v, error=lvl, mask=mask, mode=SEGNO_MODE[mode], boost_error=False,
                   encoding="ascii" if mode == "byte" else None)
    m = [list(row) for row in q.matrix]
    assert len(m) == 17 + 4 * v, "unexpected size"
    return m


def max_len(v, lvl, mask, mode, rng):
    lo, hi = 1, 8000
    while lo < hi:                       # largest length that still fits
        mid = (lo + hi + 1) // 2
        try:
            make(rand_text(mode, mid, rng), v, lvl, mask, mode)
            lo = mid
        except Overflow:
            hi = mid - 1
        except Exception:
            hi = mid - 1
    return lo


TB = """package {name};
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef {n} N;
(* synthesize *)
module mk{name}(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
{rows}
   Integer n = {n};
   QRDecoder dut <- mkQRDecoder;
   Reg#(Bool)      started <- mkReg(False);
   Reg#(UInt#(32)) cycle   <- mkReg(0);
   Reg#(UInt#(32)) startAt <- mkReg(0);
   Reg#(Bit#(1))   answer  <- mkReg(0);
   rule tick; cycle <= cycle + 1; endrule
   rule go (!started);
      dut.start(fromInteger(n)); started <= True; startAt <= cycle;
   endrule
   rule serve_req;
      match {{.r, .c}} <- dut.mem.req;
      Bit#(1) b = 0;
      if (r < fromInteger(n) && c < fromInteger(n)) begin
         Bit#(N) row = symbol[r];
         b = row[fromInteger(n - 1) - c];
      end
      answer <= b;
   endrule
   (* fire_when_enabled, no_implicit_conditions *)
   rule serve_resp; dut.mem.resp(answer); endrule
   rule get (started);
      let b <- dut.getByte;
      $display("BYTE %02h", b.data);
      if (b.last) begin
         $display("RESULT DONE cycles=%0d", cycle - startAt);
         $finish(0);
      end
   endrule
   rule fail (started && dut.failed);
      $display("RESULT FAILED cycles=%0d", cycle - startAt);
      $finish(0);
   endrule
   rule timeout (started && cycle - startAt > 200000);
      $display("RESULT TIMEOUT");
      $finish(1);
   endrule
endmodule
endpackage
"""


def selfcheck(m, text):
    import cv2, numpy as np
    n = len(m)
    q, s = 4, 8
    img = np.full(((n + 2 * q) * s,) * 2, 255, np.uint8)
    for r in range(n):
        for c in range(n):
            if m[r][c]:
                img[(r + q) * s:(r + q + 1) * s, (c + q) * s:(c + q + 1) * s] = 0
    val, _, _ = cv2.QRCodeDetector().detectAndDecode(img)
    return val == text


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    out = args[0]
    ncases = int(args[1]) if len(args) > 1 else 120
    check = "--selfcheck" in sys.argv
    os.makedirs(out, exist_ok=True)
    damages = ["none", "limit", "limit", "over"]
    modes = ["num", "alnum", "byte"]
    expected, skipped, selffail = {}, 0, []
    for i in range(ncases):
        rng = random.Random(7000 + i)
        v = VERSIONS[i % len(VERSIONS)]
        lvl = LEVELS[(i // len(VERSIONS) + i) % 4]
        mask = (i * 3 + i // 8) % 8
        mode = modes[(i // 2) % 3]
        damage = damages[(i // 3) % 4]
        full = (i % 5 == 0)
        n_chars = max_len(v, lvl, mask, mode, rng) if full else rng.randint(1, 25)
        text = rand_text(mode, n_chars, rng)
        try:
            m = make(text, v, lvl, mask, mode)
        except Exception as e:
            print("case %d skipped: %s" % (i, e)); skipped += 1; continue
        flips = 0
        if damage != "none":
            other = make(rand_text(mode, n_chars, rng), v, lvl, mask, mode)
            diff = [(r, c) for r in range(len(m)) for c in range(len(m)) if m[r][c] != other[r][c]]
            k = rng.randint(1, 3) if damage == "limit" else int(0.4 * len(diff))
            for (r, c) in rng.sample(diff, k):
                m[r][c] ^= 1
            flips = k
        if check and damage != "over" and not selfcheck(m, text):
            selffail.append(i)
        name = "TbSweep%03d" % i
        rows = "\n".join("   symbol[%3d] = 'b%s;" % (r, "".join("1" if b else "0" for b in row)) for r, row in enumerate(m))
        with open(os.path.join(out, name + ".bsv"), "w") as f:
            f.write(TB.format(name=name, n=len(m), rows=rows))
        expected[name] = {"version": v, "level": lvl, "mask": mask, "modes": [mode], "damage": damage,
                          "flips": flips, "full": full, "chars": len(text),
                          "success": damage != "over",
                          "bytes_hex": [format(ord(c), "02x") for c in text] if damage != "over" else []}
    with open(os.path.join(out, "expected.json"), "w") as f:
        json.dump(expected, f, indent=1)
    print("wrote %d test benches (%d skipped) and expected.json to %s" % (len(expected), skipped, out))
    if check:
        print("independent-reader self-check failures: %s" % (selffail if selffail else "none"))


if __name__ == "__main__":
    main()
