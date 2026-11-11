package TbSweep075;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 21 N;
(* synthesize *)
module mkTbSweep075(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b111111100001101111111;
   symbol[  1] = 'b100000101101001000001;
   symbol[  2] = 'b101110100110001011101;
   symbol[  3] = 'b101110101010001011101;
   symbol[  4] = 'b101110100100101011101;
   symbol[  5] = 'b100000101111001000001;
   symbol[  6] = 'b111111101010101111111;
   symbol[  7] = 'b000000000011000000000;
   symbol[  8] = 'b111110111101110101010;
   symbol[  9] = 'b111001000101111100101;
   symbol[ 10] = 'b111001110010011111101;
   symbol[ 11] = 'b100110010010110010100;
   symbol[ 12] = 'b111110101011111011011;
   symbol[ 13] = 'b000000001001011010110;
   symbol[ 14] = 'b111111101101000110011;
   symbol[ 15] = 'b100000100101111001100;
   symbol[ 16] = 'b101110101000111111111;
   symbol[ 17] = 'b101110101100100101000;
   symbol[ 18] = 'b101110101010010000100;
   symbol[ 19] = 'b100000101011111010001;
   symbol[ 20] = 'b111111101110011101100;
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
