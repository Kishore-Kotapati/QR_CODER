package TbSweep106;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 25 N;
(* synthesize *)
module mkTbSweep106(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b1111111010000100001111111;
   symbol[  1] = 'b1000001010001100101000001;
   symbol[  2] = 'b1011101000111000101011101;
   symbol[  3] = 'b1011101011101011001011101;
   symbol[  4] = 'b1011101001110010101011101;
   symbol[  5] = 'b1000001001001101101000001;
   symbol[  6] = 'b1111111010101010101111111;
   symbol[  7] = 'b0000000011011001100000000;
   symbol[  8] = 'b1011011101011101001001011;
   symbol[  9] = 'b0000000100101111001000000;
   symbol[ 10] = 'b0101111110110100111011110;
   symbol[ 11] = 'b1001100010010000100101101;
   symbol[ 12] = 'b0111011101101011111100000;
   symbol[ 13] = 'b0111010110100011111011110;
   symbol[ 14] = 'b0110101111000101000010110;
   symbol[ 15] = 'b1010100010111011101011001;
   symbol[ 16] = 'b0010001110111011111111100;
   symbol[ 17] = 'b0000000011000011100010011;
   symbol[ 18] = 'b1111111010000111101010110;
   symbol[ 19] = 'b1000001010010110100011011;
   symbol[ 20] = 'b1011101001101110111110011;
   symbol[ 21] = 'b1011101010001000001111001;
   symbol[ 22] = 'b1011101010001010010010010;
   symbol[ 23] = 'b1000001001110110111000000;
   symbol[ 24] = 'b1111111010000000100000011;
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
