package TbSweep016;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 25 N;
(* synthesize *)
module mkTbSweep016(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b1111111001110001101111111;
   symbol[  1] = 'b1000001000110000001000001;
   symbol[  2] = 'b1011101011011010101011101;
   symbol[  3] = 'b1011101011100000101011101;
   symbol[  4] = 'b1011101011111111001011101;
   symbol[  5] = 'b1000001011101111101000001;
   symbol[  6] = 'b1111111010101010101111111;
   symbol[  7] = 'b0000000010111101000000000;
   symbol[  8] = 'b1011111001100011001111100;
   symbol[  9] = 'b1100010011101001110011000;
   symbol[ 10] = 'b1111111101101000001011111;
   symbol[ 11] = 'b0011010011000010111100111;
   symbol[ 12] = 'b1111001011100000101100101;
   symbol[ 13] = 'b1111000111101011011000110;
   symbol[ 14] = 'b1001001011100111110101001;
   symbol[ 15] = 'b1000010101001111000000010;
   symbol[ 16] = 'b1011101001101101111110100;
   symbol[ 17] = 'b0000000010100011100010110;
   symbol[ 18] = 'b1111111001111001101010011;
   symbol[ 19] = 'b1000001010110010100010000;
   symbol[ 20] = 'b1011101010110000111111111;
   symbol[ 21] = 'b1011101011101111110000001;
   symbol[ 22] = 'b1011101010100110101110101;
   symbol[ 23] = 'b1000001001001100001011001;
   symbol[ 24] = 'b1111111010001011011111011;
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
