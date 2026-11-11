"""payload_ref.py -- Person B's independent PAYLOAD reference model.

Owner: Person B (Kishore).  Person A writes the matching RTL (QRPayload.bsv)
and must NOT edit this file.  Derived from spec Section 1.5, Table 4 and G4.

Input : the corrected DATA bytes of the whole symbol, block 0 first
        (no check bytes), and the version (1..40).
Output: PayloadResult(ok, out, reason, segments)
          ok       True  -> message decoded; `out` is the full message
          ok       False -> decoder must raise failed; `reason` says why
          out      the bytes produced (on failure: those produced before it)
          segments one entry per segment, for comparing with the RTL
"""
from typing import Dict, List, Optional, Tuple

# Mode indicators (spec Table 4)
NUMERIC, ALNUM, BYTE, TERMINATOR = 0b0001, 0b0010, 0b0100, 0b0000

# Alphanumeric character set, value 0..44 (spec Table 4 caption)
ALNUM_CHARS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:"


def count_width(mode: int, version: int) -> int:
    """Width of the character-count field (spec Table 4)."""
    band = 0 if version <= 9 else (1 if version <= 26 else 2)
    return {NUMERIC: (10, 12, 14),
            ALNUM:   (9, 11, 13),
            BYTE:    (8, 16, 16)}[mode][band]


class BitReader:
    """Reads bits from a byte list, first bit = MSB of byte 0."""

    def __init__(self, data: List[int]):
        self.data = data
        self.pos = 0                          # next bit to read
        self.total = 8 * len(data)            # bits available

    def left(self) -> int:
        return self.total - self.pos

    def read(self, n: int) -> int:
        """Read n bits as an unsigned number.  Caller checks left() first."""
        value = 0
        for _ in range(n):
            byte = self.data[self.pos // 8]
            bit = (byte >> (7 - self.pos % 8)) & 1
            value = (value << 1) | bit
            self.pos += 1
        return value


class Malformed(Exception):
    """The payload breaks a rule of spec G4."""


class PayloadResult:
    """ok, out (bytes produced), reason (why it failed), segments (trace).

    Also readable with the names agreed in docs/MODEL_INTERFACE.md v1:
    failed, bytes_out, message, error_msg."""

    def __init__(self, ok: bool):
        self.ok = ok
        self.out = []        # type: List[int]
        self.reason = ""
        self.segments = []   # type: List[dict]

    @property
    def failed(self) -> bool:
        return not self.ok

    @property
    def bytes_out(self) -> List[int]:
        return self.out

    @property
    def message(self) -> str:
        return bytes(self.out).decode("latin-1")   # byte values 0..255 kept as-is

    @property
    def error_msg(self) -> Optional[str]:
        return self.reason or None

    def to_dict(self) -> dict:
        return {"message": self.message, "bytes_out": self.bytes_out,
                "failed": self.failed, "error_msg": self.error_msg}


def decode_payload(data: List[int], version: int) -> PayloadResult:
    rd = BitReader(data)
    res = PayloadResult(ok=False)

    def need(n, what):                        # every read is checked first
        if rd.left() < n:
            raise Malformed(f"{what}: needs {n} bits, only {rd.left()} left")
        return rd.read(n)

    try:
        while True:
            # End rule 1: fewer than 4 bits left -> message ends normally
            if rd.left() < 4:
                break
            mode = rd.read(4)
            # End rule 2: terminator 0000 -> message ends; rest is padding
            if mode == TERMINATOR:
                break
            if mode not in (NUMERIC, ALNUM, BYTE):
                raise Malformed(f"unknown mode indicator {mode:04b}")

            count = need(count_width(mode, version), "character count")
            seg = {"mode": mode, "count": count, "start_bit": rd.pos}

            if mode == NUMERIC:
                left = count
                while left > 0:
                    if left >= 3:
                        v = need(10, "numeric group of 3")
                        if v > 999:
                            raise Malformed(f"numeric group {v} > 999")
                        res.out += [ord(ch) for ch in f"{v:03d}"]   # keep leading zeros
                        left -= 3
                    elif left == 2:
                        v = need(7, "numeric group of 2")
                        if v > 99:
                            raise Malformed(f"numeric group {v} > 99")
                        res.out += [ord(ch) for ch in f"{v:02d}"]
                        left -= 2
                    else:
                        v = need(4, "numeric group of 1")
                        if v > 9:
                            raise Malformed(f"numeric digit {v} > 9")
                        res.out.append(ord(str(v)))
                        left -= 1

            elif mode == ALNUM:
                left = count
                while left > 0:
                    if left >= 2:
                        v = need(11, "alphanumeric pair")
                        if v > 45 * 45 - 1:            # largest valid pair is 2024
                            raise Malformed(f"alphanumeric pair {v} > 2024")
                        res.out += [ord(ALNUM_CHARS[v // 45]), ord(ALNUM_CHARS[v % 45])]
                        left -= 2
                    else:
                        v = need(6, "alphanumeric single")
                        if v > 44:
                            raise Malformed(f"alphanumeric value {v} > 44")
                        res.out.append(ord(ALNUM_CHARS[v]))
                        left -= 1

            else:  # BYTE
                for _ in range(count):
                    res.out.append(need(8, "byte"))

            seg["end_bit"] = rd.pos
            res.segments.append(seg)
    except Malformed as e:
        res.reason = str(e)
        return res

    res.ok = True
    return res


if __name__ == "__main__":
    import sys, os
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import front_ref as F
    path = sys.argv[1] if len(sys.argv) > 1 else "bsv/TbSample.bsv"
    m = F.load_tb_symbol(path)
    # The sample is version 1-M: one block, 16 data bytes then 10 check bytes.
    # It is undamaged, so the data bytes can be used without error correction.
    raw = F.raw_codewords(m, 1, 2, 26)
    r = decode_payload(raw[:16], 1)
    print("data bytes:", " ".join(f"{b:02x}" for b in raw[:16]))
    print("ok:", r.ok, "| message:", bytes(r.out).decode("latin-1"), "|", r.reason)
