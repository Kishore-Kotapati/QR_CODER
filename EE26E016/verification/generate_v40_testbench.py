import sys
import os

sys.path.append(os.path.abspath("project/verification/model"))
import front_ref as F
import blocks_ref as B
import rs_ref as RS
import decode_ref as D

version = 40
n = 17 + 4 * version  # 177
level_field = 1       # 1 = L
mask = 0

bp = B.get_block_params(version, level_field)
print(f"Version 40-L: N={n}, totalData={bp.totalData}, total={bp.total}, blocks={bp.nb} (n1={bp.n1}, d1={bp.d1}, n2={bp.n2})")

# 1. Payload bitstream: "HELLO CAD FOR VLSI"
msg = "HELLO CAD FOR VLSI"
char_count = len(msg)
ALNUM_CHARS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:"
bit_list = [0, 0, 1, 0] # Mode ALNUM

# 13 bits count for v=40 alnum
for b in range(12, -1, -1):
    bit_list.append((char_count >> b) & 1)

# Pairs
for i in range(0, char_count, 2):
    if i + 1 < char_count:
        val = ALNUM_CHARS.index(msg[i]) * 45 + ALNUM_CHARS.index(msg[i+1])
        for b in range(10, -1, -1):
            bit_list.append((val >> b) & 1)
    else:
        val = ALNUM_CHARS.index(msg[i])
        for b in range(5, -1, -1):
            bit_list.append((val >> b) & 1)

# Terminator 0000
bit_list.extend([0, 0, 0, 0])

# Byte-align with 0s
while len(bit_list) % 8 != 0:
    bit_list.append(0)

# Pack into bytes
data_bytes = []
for i in range(0, len(bit_list), 8):
    byte_val = 0
    for b in bit_list[i:i+8]:
        byte_val = (byte_val << 1) | b
    data_bytes.append(byte_val)

# Pad with alternating 0xEC, 0x11 up to totalData
pad_bytes = [0xEC, 0x11]
p_idx = 0
while len(data_bytes) < bp.totalData:
    data_bytes.append(pad_bytes[p_idx % 2])
    p_idx += 1

assert len(data_bytes) == bp.totalData

# 2. Divide into blocks and RS encode
blocks_data = []
offset = 0
for b in range(bp.nb):
    d = bp.d1 if b < bp.n1 else bp.d1 + 1
    blocks_data.append(data_bytes[offset:offset+d])
    offset += d

encoded_blocks = []
for b in range(bp.nb):
    enc = RS.encode_block(blocks_data[b], bp.ecLen)
    encoded_blocks.append(enc)

# 3. Interleave into raw bytes
raw = B.interleave(encoded_blocks, version, level_field)
assert len(raw) == bp.total

# 4. Construct symbol matrix
matrix = [[0] * n for _ in range(n)]

# Finder patterns:
def put_finder(top_r, left_c):
    for dr in range(7):
        for dc in range(7):
            if dr == 0 or dr == 6 or dc == 0 or dc == 6 or (2 <= dr <= 4 and 2 <= dc <= 4):
                matrix[top_r + dr][left_c + dc] = 1
            else:
                matrix[top_r + dr][left_c + dc] = 0

put_finder(0, 0)
put_finder(0, n - 7)
put_finder(n - 7, 0)

# Timing patterns:
for i in range(8, n - 8):
    matrix[6][i] = 1 if (i % 2 == 0) else 0
    matrix[i][6] = 1 if (i % 2 == 0) else 0

# Dark module:
matrix[4 * version + 9][8] = 1

# Alignment patterns:
align_coords = F.ALIGN_CENTRES[version]
last = len(align_coords) - 1
for i, cr in enumerate(align_coords):
    for j, cc in enumerate(align_coords):
        if (i, j) in ((0, 0), (0, last), (last, 0)):
            continue
        for dr in range(-2, 3):
            for dc in range(-2, 3):
                if abs(dr) == 2 or abs(dc) == 2 or (dr == 0 and dc == 0):
                    matrix[cr + dr][cc + dc] = 1
                else:
                    matrix[cr + dr][cc + dc] = 0

# Format info for level=1 (L), mask=0:
# 5 data bits = (1 << 3) | 0 = 8.
stored_fmt = F.bch_encode(8)
c1, c2 = F.format_positions(n)
for i in range(15):
    bit = (stored_fmt >> i) & 1
    r1, col1 = c1[i]
    matrix[r1][col1] = bit
    r2, col2 = c2[i]
    matrix[r2][col2] = bit

# Data modules:
data_coords = F.data_module_order(version)
raw_bits = []
for byte in raw:
    for b in range(7, -1, -1):
        raw_bits.append((byte >> b) & 1)

for idx, (r, c) in enumerate(data_coords):
    if idx < len(raw_bits):
        bit = raw_bits[idx]
        if (r + c) % 2 == 0:
            bit ^= 1
        matrix[r][c] = bit
    else:
        # Remainder bits
        bit = 0
        if (r + c) % 2 == 0:
            bit ^= 1
        matrix[r][c] = bit

# Verify with software decoder!
res = D.decode_symbol(matrix)
print(f"Software decode_symbol result: success={res.success}, msg='{res.message}'")
assert res.success is True
assert res.message == "HELLO CAD FOR VLSI"

# Write out BSV testbench
bsv = f"""package TbVersion40;

import Vector::*;
import QRTypes::*;
import QRDecoder::*;

typedef {n} N;

(* synthesize *)
module mkTbVersion40(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
"""

for r, row in enumerate(matrix):
    bits_str = "".join("1" if b else "0" for b in row)
    bsv += f"   symbol[{r:3d}] = 'b{bits_str};\n"

bsv += f"""
   Integer n = {n};
   QRDecoder dut <- mkQRDecoder;

   Reg#(Bool)      started <- mkReg(False);
   Reg#(UInt#(32)) cycle   <- mkReg(0);
   Reg#(UInt#(32)) startAt <- mkReg(0);
   Reg#(Bit#(1))   answer  <- mkReg(0);

   rule tick;
      cycle <= cycle + 1;
   endrule

   rule go (!started);
      dut.start(fromInteger(n));
      started <= True;
      startAt <= cycle;
      $display("start: %0dx%0d symbol (Version 40)", n, n);
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
   rule serve_resp;
      dut.mem.resp(answer);
   endrule

   rule get (started);
      let b <- dut.getByte;
      if (!b.last)
         $display("byte: %02h  '%c'", b.data, b.data);
      else begin
         $display("byte: %02h  '%c'   <- last", b.data, b.data);
         $display("SUCCESS: Version 40 decoded in %0d cycles", cycle - startAt);
         $finish(0);
      end
   endrule

   rule fail (started && dut.failed);
      $display("FAIL: Decoder raised failed after %0d cycles", cycle - startAt);
      $finish(1);
   endrule

   rule timeout (started && cycle - startAt > 150000);
      $display("TIMEOUT: after %0d cycles", cycle - startAt);
      $finish(1);
   endrule
endmodule

endpackage
"""

with open("project/bsv/TbVersion40.bsv", "w") as f:
    f.write(bsv)
print("Successfully generated project/bsv/TbVersion40.bsv")
