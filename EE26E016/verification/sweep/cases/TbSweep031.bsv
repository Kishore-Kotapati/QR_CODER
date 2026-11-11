package TbSweep031;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 25 N;
(* synthesize *)
module mkTbSweep031(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b1111111001000100101111111;
   symbol[  1] = 'b1000001010001011101000001;
   symbol[  2] = 'b1011101001000110101011101;
   symbol[  3] = 'b1011101001100111001011101;
   symbol[  4] = 'b1011101010001010001011101;
   symbol[  5] = 'b1000001001001100001000001;
   symbol[  6] = 'b1111111010101010101111111;
   symbol[  7] = 'b0000000000010110100000000;
   symbol[  8] = 'b1010101000100011000010010;
   symbol[  9] = 'b0110110100001011000100111;
   symbol[ 10] = 'b1111011000000100010110000;
   symbol[ 11] = 'b0000010110011001011101000;
   symbol[ 12] = 'b0100101001111000110010000;
   symbol[ 13] = 'b0000000101111101110010111;
   symbol[ 14] = 'b1010001101011011101001000;
   symbol[ 15] = 'b0110000000101110100011110;
   symbol[ 16] = 'b1000111000110011111111001;
   symbol[ 17] = 'b0000000010010010100011010;
   symbol[ 18] = 'b1111111001000100101010010;
   symbol[ 19] = 'b1000001000110001100011011;
   symbol[ 20] = 'b1011101011001000111110101;
   symbol[ 21] = 'b1011101001111100010000110;
   symbol[ 22] = 'b1011101010011010111010001;
   symbol[ 23] = 'b1000001001001111001000100;
   symbol[ 24] = 'b1111111011110011000010101;
   Integer n = 25;
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
