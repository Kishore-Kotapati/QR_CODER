package TbSweep105;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 21 N;
(* synthesize *)
module mkTbSweep105(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b111111100000101111111;
   symbol[  1] = 'b100000100011101000001;
   symbol[  2] = 'b101110101101101011101;
   symbol[  3] = 'b101110100111001011101;
   symbol[  4] = 'b101110100001101011101;
   symbol[  5] = 'b100000100111101000001;
   symbol[  6] = 'b111111101010101111111;
   symbol[  7] = 'b000000001101000000000;
   symbol[  8] = 'b111011111011011000100;
   symbol[  9] = 'b100100001101011111100;
   symbol[ 10] = 'b010100110010010101001;
   symbol[ 11] = 'b100101001110010110001;
   symbol[ 12] = 'b010100101111100111100;
   symbol[ 13] = 'b000000001111000100010;
   symbol[ 14] = 'b111111101110010110000;
   symbol[ 15] = 'b100000101001110010010;
   symbol[ 16] = 'b101110101111010011101;
   symbol[ 17] = 'b101110100011100000001;
   symbol[ 18] = 'b101110101000000110100;
   symbol[ 19] = 'b100000101011000010011;
   symbol[ 20] = 'b111111101000100111001;
   Integer n = 21;
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
      match {.r, .c} <- dut.mem.req;
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
