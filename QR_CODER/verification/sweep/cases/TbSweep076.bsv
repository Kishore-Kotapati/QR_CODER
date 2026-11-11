package TbSweep076;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 25 N;
(* synthesize *)
module mkTbSweep076(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b1111111001110001101111111;
   symbol[  1] = 'b1000001011110110101000001;
   symbol[  2] = 'b1011101010111101001011101;
   symbol[  3] = 'b1011101010001000101011101;
   symbol[  4] = 'b1011101001011001101011101;
   symbol[  5] = 'b1000001001001001001000001;
   symbol[  6] = 'b1111111010101010101111111;
   symbol[  7] = 'b0000000010101011100000000;
   symbol[  8] = 'b1000001010010000111001110;
   symbol[  9] = 'b0000000000101100111011101;
   symbol[ 10] = 'b0000101111011111110100011;
   symbol[ 11] = 'b0111000011010100000001001;
   symbol[ 12] = 'b1000101100011101100110011;
   symbol[ 13] = 'b1111000100000000101110000;
   symbol[ 14] = 'b1000001001111000001010111;
   symbol[ 15] = 'b1011000101010001011100101;
   symbol[ 16] = 'b1000001110110000111110111;
   symbol[ 17] = 'b0000000010101111100011110;
   symbol[ 18] = 'b1111111000110001101011001;
   symbol[ 19] = 'b1000001000001100100011000;
   symbol[ 20] = 'b1011101001001011111110111;
   symbol[ 21] = 'b1011101001100011101010001;
   symbol[ 22] = 'b1011101000011001011001001;
   symbol[ 23] = 'b1000001000010010010000001;
   symbol[ 24] = 'b1111111010000110010111101;
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
