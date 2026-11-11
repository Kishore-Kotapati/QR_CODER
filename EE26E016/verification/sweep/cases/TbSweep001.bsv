package TbSweep001;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 25 N;
(* synthesize *)
module mkTbSweep001(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b1111111011011111001111111;
   symbol[  1] = 'b1000001010010100101000001;
   symbol[  2] = 'b1011101001011000101011101;
   symbol[  3] = 'b1011101011101011001011101;
   symbol[  4] = 'b1011101000011010101011101;
   symbol[  5] = 'b1000001000100101101000001;
   symbol[  6] = 'b1111111010101010101111111;
   symbol[  7] = 'b0000000011010001100000000;
   symbol[  8] = 'b1011011101001101001001011;
   symbol[  9] = 'b0101100010110111011001001;
   symbol[ 10] = 'b0011011010110100101110010;
   symbol[ 11] = 'b0110110010111000101100110;
   symbol[ 12] = 'b1001101010101011010001011;
   symbol[ 13] = 'b0011110001111010110101110;
   symbol[ 14] = 'b0101001111010101100110001;
   symbol[ 15] = 'b1011100111010010111110100;
   symbol[ 16] = 'b0010101111001011111110010;
   symbol[ 17] = 'b0000000011000011100010101;
   symbol[ 18] = 'b1111111011100111101010001;
   symbol[ 19] = 'b1000001011010110100010000;
   symbol[ 20] = 'b1011101001100110111111100;
   symbol[ 21] = 'b1011101010100000001100101;
   symbol[ 22] = 'b1011101011000010000010110;
   symbol[ 23] = 'b1000001001011110111001010;
   symbol[ 24] = 'b1111111010110000100001001;
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
