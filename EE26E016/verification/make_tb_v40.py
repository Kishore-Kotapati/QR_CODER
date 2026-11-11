import sys
import os
import segno

# Generate a version 40 QR code
qr = segno.make("Antigravity Version 40 Verification Test Message for CAD for VLSI Decoder", version=40, error='L')
matrix = qr.matrix
n = len(matrix)
print(f"Matrix size: {n}x{n}")

# Format as BSV testbench
bsv_code = f"""package TbVersion40;

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
    bsv_code += f"   symbol[{r:3d}] = 'b{bits_str};\n"

bsv_code += f"""
   Integer n = {n};
   QRDecoder dut <- mkQRDecoder;

   Reg#(Bool)      started <- mkReg(False);
   Reg#(UInt#(32)) cycle   <- mkReg(0);
   Reg#(UInt#(32)) startAt <- mkReg(0);
   Reg#(Bit#(1))   answer  <- mkReg(0);
   Reg#(UInt#(32)) byteCount <- mkReg(0);

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
      byteCount <= byteCount + 1;
      if (b.last) begin
         $display("Decoded %0d bytes, last byte: %02h", byteCount + 1, b.data);
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
    f.write(bsv_code)
print("Created project/bsv/TbVersion40.bsv successfully.")
