package TbSweep001;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 25 N;
(* synthesize *)
module mkTbSweep001(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b1111111011000111001111111;
   symbol[  1] = 'b1000001011110100101000001;
   symbol[  2] = 'b1011101000010000101011101;
   symbol[  3] = 'b1011101011001011001011101;
   symbol[  4] = 'b1011101001011010101011101;
   symbol[  5] = 'b1000001000111101101000001;
   symbol[  6] = 'b1111111010101010101111111;
   symbol[  7] = 'b0000000010010001100000000;
   symbol[  8] = 'b1011011100111101001001011;
   symbol[  9] = 'b1100100000000111011001001;
   symbol[ 10] = 'b1011101000001100101111001;
   symbol[ 11] = 'b0011010000000000101100101;
   symbol[ 12] = 'b1101011111011011010000010;
   symbol[ 13] = 'b0010110010111010110101110;
   symbol[ 14] = 'b0110111000010101100110000;
   symbol[ 15] = 'b1010100011010010111110101;
   symbol[ 16] = 'b0010101001101011111110001;
   symbol[ 17] = 'b0000000010100011100010100;
   symbol[ 18] = 'b1111111011000111101010011;
   symbol[ 19] = 'b1000001011010110100010010;
   symbol[ 20] = 'b1011101001100110111111100;
   symbol[ 21] = 'b1011101010100000001100101;
   symbol[ 22] = 'b1011101010100010000010110;
   symbol[ 23] = 'b1000001000011110111001010;
   symbol[ 24] = 'b1111111010010000100001001;
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
