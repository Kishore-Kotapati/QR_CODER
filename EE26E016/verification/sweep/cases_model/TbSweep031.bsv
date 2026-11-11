package TbSweep031;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 25 N;
(* synthesize *)
module mkTbSweep031(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b1111111000111001101111111;
   symbol[  1] = 'b1000001010001000101000001;
   symbol[  2] = 'b1011101000011101001011101;
   symbol[  3] = 'b1011101000001001101011101;
   symbol[  4] = 'b1011101011000010101011101;
   symbol[  5] = 'b1000001000100010001000001;
   symbol[  6] = 'b1111111010101010101111111;
   symbol[  7] = 'b0000000000110010100000000;
   symbol[  8] = 'b1010101000001010100010010;
   symbol[  9] = 'b1101100011001101111100100;
   symbol[ 10] = 'b0011111110000110100100110;
   symbol[ 11] = 'b0110000001100100000101010;
   symbol[ 12] = 'b1000011111111010110011001;
   symbol[ 13] = 'b0110110001011110001000001;
   symbol[ 14] = 'b1010101010111101100110010;
   symbol[ 15] = 'b0101010111101000101111101;
   symbol[ 16] = 'b1000111001111100111111010;
   symbol[ 17] = 'b0000000011001100100011101;
   symbol[ 18] = 'b1111111001101000101010001;
   symbol[ 19] = 'b1000001000010001100011001;
   symbol[ 20] = 'b1011101010011111111110101;
   symbol[ 21] = 'b1011101001111100100111110;
   symbol[ 22] = 'b1011101011111011101010101;
   symbol[ 23] = 'b1000001000101101110101000;
   symbol[ 24] = 'b1111111010111010001100101;
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
