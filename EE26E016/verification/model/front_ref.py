"""front_ref.py -- Person B's independent FRONT-END reference model.

Owner: Person B (Kishore).  Person A writes the matching RTL (QRFrontEnd.bsv)
and must NOT edit this file.  Everything here is derived from the spec PDF
(Sections 1.1-1.3, G1, G2) -- never from A's RTL or A's Python.

Conventions (agree these with A before A imports this file):
  * matrix[r][c] is 0/1, 1 = dark, row 0 = top, col 0 = left, no quiet zone.
  * A 15-bit format word holds f_i at bit i  (f0 = LSB, f14 = MSB).
  * level_field is the RAW 2-bit field: 01=L, 00=M, 11=Q, 10=H.
  * Codewords are ints 0..255, first-read bit = MSB.

Status:  Day 1 (23 Oct) -> version + format functions DONE.
         Day 2 (25 Oct) -> function map, masks, zigzag, raw bytes, trace DONE.
"""
from typing import Dict, List, Optional, Tuple

Matrix = List[List[int]]

FORMAT_GENERATOR = 0b10100110111      # spec 1.2: x^10+x^8+x^5+x^4+x^2+x+1
FORMAT_XOR_MASK = 0b101010000010010   # spec 1.2: 0x5412
LEVEL_NAME = {0b01: "L", 0b00: "M", 0b11: "Q", 0b10: "H"}   # spec 1.2


# =========================================================== G1: version
def version_from_size(n: int) -> Optional[int]:
    """Return v (1..40) if n == 17 + 4v, else None.  Spec G1."""
    if n < 21 or n > 177:          # v=1 gives 21, v=40 gives 177
        return None
    if (n - 17) % 4 != 0:          # must land exactly on 17 + 4v
        return None
    return (n - 17) // 4


# =========================================================== 1.2: format
def format_positions(n: int) -> Tuple[List[Tuple[int, int]], List[Tuple[int, int]]]:
    """(copy1, copy2): element i is the (r, c) of format bit f_i.  Spec Table 1."""
    copy1 = []
    copy1 += [(i, 8) for i in range(0, 6)]          # f0..f5  : down column 8
    copy1 += [(7, 8), (8, 8), (8, 7)]               # f6,f7,f8: hop over timing row/col 6
    copy1 += [(8, 14 - i) for i in range(9, 15)]    # f9..f14 : leftwards along row 8

    copy2 = []
    copy2 += [(8, n - 1 - i) for i in range(0, 6)]  # f0..f5  : row 8, right edge inwards
    copy2 += [(8, n - 7), (8, n - 8)]               # f6, f7  : row 8
    copy2 += [(n - 7, 8)]                           # f8      : column 8, bottom-left
    copy2 += [(n - 15 + i, 8) for i in range(9, 15)]  # f9..f14: column 8, downwards
    return copy1, copy2


def bch_encode(data5: int) -> int:
    """5 data bits -> 15-bit stored word.

    Polynomial long division in GF(2): subtraction is XOR, so we repeatedly
    XOR the generator (shifted under the highest 1 bit) until the remainder
    has fewer than 10 bits.
    """
    assert 0 <= data5 < 32
    rem = data5 << 10                       # append ten zeros  (x^10 * d(x))
    for bit in range(14, 9, -1):            # look at bits 14..10, high to low
        if (rem >> bit) & 1:                # a 1 here must be cancelled
            rem ^= FORMAT_GENERATOR << (bit - 10)
    codeword = (data5 << 10) | rem          # data bits on top, 10 check bits below
    return codeword ^ FORMAT_XOR_MASK       # spec: never all-light


def valid_format_words() -> Dict[int, Tuple[int, int]]:
    """All 32 valid stored words -> (level_field, mask).  data5 = level<<3 | mask."""
    table = {}
    for data5 in range(32):
        level_field = data5 >> 3            # top 2 of the 5 bits
        mask = data5 & 0b111                # low 3 bits
        table[bch_encode(data5)] = (level_field, mask)
    return table


_VALID = valid_format_words()               # computed once at import


def read_format(matrix: Matrix, n: int) -> Tuple[int, int]:
    """Read both 15-bit copies; bit i of each result is f_i."""
    copy1_pos, copy2_pos = format_positions(n)
    copy1 = 0
    copy2 = 0
    for i in range(15):
        r, c = copy1_pos[i]
        copy1 |= (matrix[r][c] & 1) << i
        r, c = copy2_pos[i]
        copy2 |= (matrix[r][c] & 1) << i
    return copy1, copy2


def hamming(a: int, b: int) -> int:
    """Number of bit positions where a and b differ."""
    return bin(a ^ b).count("1")


def nearest_format(word: int) -> Tuple[int, int, int]:
    """(distance, level_field, mask) of the valid word nearest to `word`.

    Brute force over all 32 valid words -- simple and obviously correct,
    which is what a reference model should be.  Ties between two valid
    words are impossible within distance 3 (minimum distance is 7).
    """
    best = None
    for valid, (level_field, mask) in _VALID.items():
        d = hamming(word, valid)
        if best is None or d < best[0]:
            best = (d, level_field, mask)
    return best


def decode_format(copy1: int, copy2: int) -> Optional[Tuple[int, int]]:
    """Spec G2: take the copy nearer to a valid value (copy 1 on a tie);
    return (level_field, mask), or None if that distance is > 3."""
    d1, lv1, m1 = nearest_format(copy1)
    d2, lv2, m2 = nearest_format(copy2)
    if d2 < d1:                    # strictly nearer -> copy 2 wins
        d, lv, m = d2, lv2, m2
    else:                          # copy 1 nearer OR tie -> copy 1 wins
        d, lv, m = d1, lv1, m1
    if d > 3:
        return None                # format past repair -> decoder must fail
    return lv, m


# =========================================================== 1.1: map of fixed squares
# Alignment-pattern centre list for each version (ISO/IEC 18004 Annex E).
# Typed from the standard on purpose, so it is NOT copied from QRTables.bsv;
# a test then compares the two lists.  Same list is used for rows and columns.
ALIGN_CENTRES = {
    1: [], 2: [6, 18], 3: [6, 22], 4: [6, 26], 5: [6, 30], 6: [6, 34],
    7: [6, 22, 38], 8: [6, 24, 42], 9: [6, 26, 46], 10: [6, 28, 50],
    11: [6, 30, 54], 12: [6, 32, 58], 13: [6, 34, 62],
    14: [6, 26, 46, 66], 15: [6, 26, 48, 70], 16: [6, 26, 50, 74],
    17: [6, 30, 54, 78], 18: [6, 30, 56, 82], 19: [6, 30, 58, 86],
    20: [6, 34, 62, 90],
    21: [6, 28, 50, 72, 94], 22: [6, 26, 50, 74, 98], 23: [6, 30, 54, 78, 102],
    24: [6, 28, 54, 80, 106], 25: [6, 32, 58, 84, 110], 26: [6, 30, 58, 86, 114],
    27: [6, 34, 62, 90, 118],
    28: [6, 26, 50, 74, 98, 122], 29: [6, 30, 54, 78, 102, 126],
    30: [6, 26, 52, 78, 104, 130], 31: [6, 30, 56, 82, 108, 134],
    32: [6, 34, 60, 86, 112, 138], 33: [6, 30, 58, 86, 114, 142],
    34: [6, 34, 62, 90, 118, 146],
    35: [6, 30, 54, 78, 102, 126, 150], 36: [6, 24, 50, 76, 102, 128, 154],
    37: [6, 28, 54, 80, 106, 132, 158], 38: [6, 32, 58, 84, 110, 136, 162],
    39: [6, 26, 54, 82, 110, 138, 166], 40: [6, 30, 58, 86, 114, 142, 170],
}


def alignment_centres(version: int) -> List[int]:
    """Centre coordinate list for this version, e.g. v2 -> [6, 18]."""
    return ALIGN_CENTRES[version]


def function_map(version: int) -> List[List[bool]]:
    """N x N grid, True = fixed (function) square.  Uses positions only,
    never the colours, so a damaged finder is still skipped correctly."""
    n = 17 + 4 * version
    fm = [[False] * n for _ in range(n)]

    def mark(r0, r1, c0, c1):              # mark rows r0..r1, cols c0..c1
        for r in range(r0, r1 + 1):
            for c in range(c0, c1 + 1):
                fm[r][c] = True

    # 1. three corner boxes: finder (7x7) + separator + format strip = 9x9 / 9x8
    mark(0, 8, 0, 8)                       # top-left   (also holds format copy 1)
    mark(0, 8, n - 8, n - 1)               # top-right  (also format copy 2, row part)
    mark(n - 8, n - 1, 0, 8)               # bottom-left (also format copy 2 column part
                                           #   and the always-dark square (n-8, 8))
    # 2. timing lines
    mark(6, 6, 0, n - 1)                   # row 6
    mark(0, n - 1, 6, 6)                   # column 6
    # 3. alignment patterns: every pair of centres except the 3 finder corners
    cs = ALIGN_CENTRES[version]
    last = len(cs) - 1
    for i, rc in enumerate(cs):
        for j, cc in enumerate(cs):
            if (i, j) in ((0, 0), (0, last), (last, 0)):
                continue                   # would sit on a finder: not drawn
            mark(rc - 2, rc + 2, cc - 2, cc + 2)
    # 4. version information (v >= 7): two 6x3 blocks
    if version >= 7:
        mark(0, 5, n - 11, n - 9)          # 6 rows x 3 cols, left of the top-right finder
        mark(n - 11, n - 9, 0, 5)          # 3 rows x 6 cols, above the bottom-left finder
    return fm


# =========================================================== 1.3: masks + reading order
def mask_inverts(mask: int, r: int, c: int) -> bool:
    """True where Table 2's rule holds (that data square was flipped)."""
    if mask == 0:
        return (r + c) % 2 == 0
    if mask == 1:
        return r % 2 == 0
    if mask == 2:
        return c % 3 == 0
    if mask == 3:
        return (r + c) % 3 == 0
    if mask == 4:
        return (r // 2 + c // 3) % 2 == 0
    if mask == 5:
        return (r * c) % 2 + (r * c) % 3 == 0
    if mask == 6:
        return ((r * c) % 2 + (r * c) % 3) % 2 == 0
    if mask == 7:
        return (((r + c) % 2) + (r * c) % 3) % 2 == 0
    raise ValueError(f"mask must be 0..7, got {mask}")


def data_module_order(version: int) -> List[Tuple[int, int]]:
    """Every data square, in zigzag reading order (spec 1.3 rules 1-5)."""
    n = 17 + 4 * version
    fm = function_map(version)
    order = []
    right = n - 1                          # right-hand column of the current strip
    going_up = True                        # rule 1: start at the bottom, move up
    while right > 0:
        if right == 6:                     # rule 4: column 6 is never in a strip
            right = 5
        rows = range(n - 1, -1, -1) if going_up else range(n)
        for r in rows:
            for c in (right, right - 1):   # rule 2: right square first
                if not fm[r][c]:           # rule 5: skip fixed squares
                    order.append((r, c))
        going_up = not going_up            # rule 3: reverse direction ...
        right -= 2                         # ... and move two columns left
    return order


def raw_codewords(matrix: Matrix, version: int, mask: int, total: int) -> List[int]:
    """Read data squares in order, undo the mask, pack 8 bits per byte
    (first bit = MSB), return exactly `total` bytes; extra bits ignored."""
    bits = []
    for r, c in data_module_order(version):
        b = matrix[r][c] & 1
        if mask_inverts(mask, r, c):
            b ^= 1                         # flip it back
        bits.append(b)
    if len(bits) < 8 * total:
        raise ValueError("symbol has fewer data bits than the table says")
    out = []
    for k in range(total):
        byte = 0
        for b in bits[8 * k: 8 * k + 8]:
            byte = (byte << 1) | b         # first bit ends up as the MSB
        out.append(byte)
    return out


# =========================================================== whole front end
def total_codewords(version: int) -> int:
    """Bytes in the symbol = data squares // 8 (the < 8 leftover bits are
    ignored).  Found from the geometry alone, so no table is needed; a test
    checks it against BlockParams.total in QRTables.bsv for all 160 entries."""
    return len(data_module_order(version)) // 8


def trace(matrix: Matrix, total_for=None) -> dict:
    """Run the whole front end and return every intermediate value.
    total_for(version, level_field) -> bytes in the symbol; if not given,
    total_codewords(version) is used."""
    if total_for is None:
        total_for = lambda v, lv: total_codewords(v)
    t = {"n": len(matrix), "failed_stage": None}
    v = version_from_size(t["n"])
    t["version"] = v
    if v is None:
        t["failed_stage"] = "size"
        return t
    c1, c2 = read_format(matrix, t["n"])
    t["copy1"], t["copy2"] = c1, c2
    t["dist1"], t["dist2"] = nearest_format(c1)[0], nearest_format(c2)[0]
    fmt = decode_format(c1, c2)
    if fmt is None:
        t["failed_stage"] = "format"
        return t
    t["level_field"], t["mask"] = fmt
    t["total"] = total_for(v, fmt[0])
    t["raw"] = raw_codewords(matrix, v, fmt[1], t["total"])
    return t


# =========================================================== API for decode_ref.py
class FrontendResult:
    """What decode_frontend returns (agreed in docs/MODEL_INTERFACE.md v1).
    Read it as attributes (r.version) or as a dict (r.to_dict())."""

    def __init__(self, t: dict):
        self.failed = t["failed_stage"] is not None
        self.error_msg = {None: None,
                          "size": "invalid side length (spec G1)",
                          "format": "format information more than 3 bits from every valid word (spec G2)",
                          }[t["failed_stage"]]
        self.failed_stage = t["failed_stage"]
        self.version = t.get("version")
        self.level_field = t.get("level_field")
        self.mask = t.get("mask")
        self.raw_codewords = t.get("raw", [])
        self.trace = t                      # every intermediate value, for debugging

    def to_dict(self) -> dict:
        return {"version": self.version, "level_field": self.level_field,
                "mask": self.mask, "raw_codewords": self.raw_codewords,
                "failed": self.failed, "error_msg": self.error_msg}


def decode_frontend(matrix: Matrix) -> FrontendResult:
    """Person A's decode_ref.py calls this.  matrix[r][c], 1 = dark, N x N."""
    return FrontendResult(trace(matrix))


# =========================================================== demo
def load_tb_symbol(path: str) -> Matrix:
    """Parse the  symbol[i] = 'b0101...;  rows out of a TbSample-style file."""
    import re
    rows = re.findall(r"symbol\[\s*\d+\] = 'b([01]+);", open(path).read())
    return [[int(ch) for ch in row] for row in rows]


if __name__ == "__main__":
    import sys
    path = sys.argv[1] if len(sys.argv) > 1 else "bsv/TbSample.bsv"
    m = load_tb_symbol(path)
    n = len(m)
    v = version_from_size(n)
    print(f"size N = {n}  ->  version {v}")
    c1, c2 = read_format(m, n)
    for name, w in (("copy 1", c1), ("copy 2", c2)):
        d, lv, mk = nearest_format(w)
        print(f"{name}: f14..f0 = {w:015b}  nearest distance {d}  "
              f"-> level {LEVEL_NAME[lv]} ({lv:02b}), mask {mk}")
    res = decode_format(c1, c2)
    print("decision:", "FAIL (format unreadable)" if res is None
          else f"level {LEVEL_NAME[res[0]]}, mask {res[1]}")
