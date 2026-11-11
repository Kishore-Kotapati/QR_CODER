#!/usr/bin/env python3
"""Sweep generator: builds many QR symbols with the team's Python model and writes one
BSV test bench per symbol plus expected.json (what the model says the decoder must do).

Usage (from qr/work):   python3 verification/sweep/gen_sweep.py <out_dir> [num_cases]
"""
import json, os, random, sys

# ---- find the model folder (the one that holds front_ref.py) -------------------------
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))          # .../verification
for d, _, files in os.walk(ROOT):
    if "front_ref.py" in files:
        sys.path.insert(0, d)
        break
import front_ref as F
import blocks_ref as B
import rs_ref as RS
import decode_ref as D

ALNUM = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:"
LEVELS = {"M": 0, "L": 1, "H": 2, "Q": 3}          # same field values as the format information
VERSIONS = [1, 2, 3, 6, 7, 9, 10, 14, 20, 21, 26, 27, 30, 35, 40]
MODE_BITS = {"num": 1, "alnum": 2, "byte": 4}


def count_bits(mode, version):
    table = {"num": (10, 12, 14), "alnum": (9, 11, 13), "byte": (8, 16, 16)}[mode]
    return table[0 if version <= 9 else (1 if version <= 26 else 2)]


def seg_bits(mode, text, version):
    bits = [int(x) for x in format(MODE_BITS[mode], "04b")]
    bits += [int(x) for x in format(len(text), "0%db" % count_bits(mode, version))]
    if mode == "num":
        for i in range(0, len(text), 3):
            g = text[i:i + 3]
            bits += [int(x) for x in format(int(g), "0%db" % {1: 4, 2: 7, 3: 10}[len(g)])]
    elif mode == "alnum":
        for i in range(0, len(text), 2):
            g = text[i:i + 2]
            if len(g) == 2:
                bits += [int(x) for x in format(ALNUM.index(g[0]) * 45 + ALNUM.index(g[1]), "011b")]
            else:
                bits += [int(x) for x in format(ALNUM.index(g[0]), "06b")]
    else:
        for ch in text:
            bits += [int(x) for x in format(ord(ch), "08b")]
    return bits


def make_text(mode, n, rng):
    if mode == "num":
        return "".join(rng.choice("0123456789") for _ in range(n))
    if mode == "alnum":
        return "".join(rng.choice(ALNUM) for _ in range(n))
    return "".join(chr(rng.randint(32, 126)) for _ in range(n))


def build_message(segmode_list, version, cap_bits, rng, full):
    """Return (segments, bits). Segments = [(mode, text)]; fills up to cap_bits-4 when full."""
    segs = []
    for mode in segmode_list:
        n = rng.randint(1, 12)
        segs.append((mode, make_text(mode, n, rng)))
    if full:                      # grow the last segment until the next char would not fit
        mode = segs[-1][0]
        while True:
            t = segs[-1][1] + make_text(mode, 1, rng)
            trial = segs[:-1] + [(mode, t)]
            if sum(len(seg_bits(m, x, version)) for m, x in trial) > cap_bits - 4:
                break
            segs = trial
    bits = []
    for m, x in segs:
        bits += seg_bits(m, x, version)
    while sum(len(seg_bits(m, x, version)) for m, x in segs) > cap_bits - 4 and len(segs[-1][1]) > 1:
        segs[-1] = (segs[-1][0], segs[-1][1][:-1])
        bits = []
        for m, x in segs:
            bits += seg_bits(m, x, version)
    return segs, bits


def pack_data(bits, total_data):
    cap = total_data * 8
    bits = bits + [0] * min(4, cap - len(bits))
    while len(bits) % 8:
        bits.append(0)
    out = [int("".join(map(str, bits[i:i + 8])), 2) for i in range(0, len(bits), 8)]
    pad = [0xEC, 0x11]
    i = 0
    while len(out) < total_data:
        out.append(pad[i % 2]); i += 1
    return out


def build_symbol(version, level, mask, segs, bits, damage, rng):
    lf = LEVELS[level]
    n = 17 + 4 * version
    bp = B.get_block_params(version, lf)
    data = pack_data(bits, bp.totalData)
    blocks, off = [], 0
    for b in range(bp.nb):
        d = bp.d1 if b < bp.n1 else bp.d1 + 1
        blocks.append(data[off:off + d]); off += d
    enc = [RS.encode_block(bl, bp.ecLen) for bl in blocks]
    t = bp.ecLen // 2
    nbad = 0
    if damage in ("limit", "over"):
        for bi, e in enumerate(enc):
            k = t + (1 if (damage == "over" and bi == len(enc) // 2) else 0)
            for pos in rng.sample(range(len(e)), k):
                e[pos] ^= rng.randint(1, 255)
            nbad += k
    raw = B.interleave(enc, version, lf)
    m = [[0] * n for _ in range(n)]
    def finder(r0, c0):
        for dr in range(7):
            for dc in range(7):
                m[r0 + dr][c0 + dc] = 1 if (dr in (0, 6) or dc in (0, 6) or (2 <= dr <= 4 and 2 <= dc <= 4)) else 0
    finder(0, 0); finder(0, n - 7); finder(n - 7, 0)
    for i in range(8, n - 8):
        m[6][i] = 1 if i % 2 == 0 else 0
        m[i][6] = 1 if i % 2 == 0 else 0
    m[4 * version + 9][8] = 1
    ac = F.ALIGN_CENTRES[version]; last = len(ac) - 1
    for i, cr in enumerate(ac):
        for j, cc in enumerate(ac):
            if (i, j) in ((0, 0), (0, last), (last, 0)):
                continue
            for dr in range(-2, 3):
                for dc in range(-2, 3):
                    m[cr + dr][cc + dc] = 1 if (abs(dr) == 2 or abs(dc) == 2 or (dr == 0 and dc == 0)) else 0
    fmt = F.bch_encode((lf << 3) | mask)
    c1, c2 = F.format_positions(n)
    for i in range(15):
        bit = (fmt >> i) & 1
        m[c1[i][0]][c1[i][1]] = bit
        m[c2[i][0]][c2[i][1]] = bit
    rb = [(byte >> k) & 1 for byte in raw for k in range(7, -1, -1)]
    for idx, (r, c) in enumerate(F.data_module_order(version)):
        bit = rb[idx] if idx < len(rb) else 0
        if F.mask_inverts(mask, r, c):
            bit ^= 1
        m[r][c] = bit
    return n, m, nbad, t


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


def main():
    out = sys.argv[1]
    ncases = int(sys.argv[2]) if len(sys.argv) > 2 else 120
    os.makedirs(out, exist_ok=True)
    mode_sets = [["num"], ["alnum"], ["byte"], ["num", "alnum", "byte"], ["alnum", "num"], ["byte", "num"]]
    damages = ["none", "limit", "limit", "over"]
    levels = ["L", "M", "Q", "H"]
    expected = {}
    for i in range(ncases):
        rng = random.Random(1000 + i)
        v = VERSIONS[i % len(VERSIONS)]
        lvl = levels[(i // len(VERSIONS) + i) % 4]
        mask = (i * 3 + i // 8) % 8
        modes = mode_sets[(i // 2) % len(mode_sets)]
        damage = damages[(i // 3) % len(damages)]
        full = (i % 5 == 0)
        bp = B.get_block_params(v, LEVELS[lvl])
        segs, bits = build_message(modes, v, bp.totalData * 8, rng, full)
        n, m, nbad, t = build_symbol(v, lvl, mask, segs, bits, damage, rng)
        res = D.decode_symbol(m)
        text = "".join(x for _, x in segs)
        if damage in ("none", "limit"):
            assert res.success and res.message == text, "model failed on a symbol that must decode: case %d" % i
        name = "TbSweep%03d" % i
        rows = "\n".join("   symbol[%3d] = 'b%s;" % (r, "".join("1" if b else "0" for b in row)) for r, row in enumerate(m))
        with open(os.path.join(out, name + ".bsv"), "w") as f:
            f.write(TB.format(name=name, n=n, rows=rows))
        expected[name] = {"version": v, "level": lvl, "mask": mask, "modes": modes, "damage": damage,
                          "bad_bytes": nbad, "t": t, "full": full, "chars": len(text),
                          "success": bool(res.success),
                          "bytes_hex": [format(ord(c), "02x") for c in res.message] if res.success else []}
    with open(os.path.join(out, "expected.json"), "w") as f:
        json.dump(expected, f, indent=1)
    print("wrote %d test benches and expected.json to %s" % (ncases, out))


if __name__ == "__main__":
    main()
