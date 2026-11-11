package TbSweep016;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 25 N;
(* synthesize *)
module mkTbSweep016(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b1111111001010111001111111;
   symbol[  1] = 'b1000001001001111101000001;
   symbol[  2] = 'b1011101011110101001011101;
   symbol[  3] = 'b1011101011111011001011101;
   symbol[  4] = 'b1011101011110001101011101;
   symbol[  5] = 'b1000001011111000001000001;
   symbol[  6] = 'b1111111010101010101111111;
   symbol[  7] = 'b0000000010101010100000000;
   symbol[  8] = 'b1011111000110000101111100;
   symbol[  9] = 'b1011010000001111011000111;
   symbol[ 10] = 'b1000111100011111110100111;
   symbol[ 11] = 'b1001000000100101000000011;
   symbol[ 12] = 'b1101001010101011010000001;
   symbol[ 13] = 'b1000110110100001101111110;
   symbol[ 14] = 'b1011111100011000001010001;
   symbol[ 15] = 'b1010100110010010111111010;
   symbol[ 16] = 'b1001001010010000111111010;
   symbol[ 17] = 'b0000000010101110100011000;
   symbol[ 18] = 'b1111111000100111101011001;
   symbol[ 19] = 'b1000001010101101100011001;
   symbol[ 20] = 'b1011101010101011111111011;
   symbol[ 21] = 'b1011101011100000001100101;
   symbol[ 22] = 'b1011101010111001011001101;
   symbol[ 23] = 'b1000001000110011010100101;
   symbol[ 24] = 'b1111111010010000100001011;
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
