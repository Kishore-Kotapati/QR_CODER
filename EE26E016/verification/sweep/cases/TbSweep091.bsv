package TbSweep091;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 25 N;
(* synthesize *)
module mkTbSweep091(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b1111111011100110101111111;
   symbol[  1] = 'b1000001001011111001000001;
   symbol[  2] = 'b1011101000100010001011101;
   symbol[  3] = 'b1011101011000000001011101;
   symbol[  4] = 'b1011101011000000001011101;
   symbol[  5] = 'b1000001011101000101000001;
   symbol[  6] = 'b1111111010101010101111111;
   symbol[  7] = 'b0000000011100101100000000;
   symbol[  8] = 'b1000101111001100011111001;
   symbol[  9] = 'b0001100110010110111101001;
   symbol[ 10] = 'b1000001011001000111101000;
   symbol[ 11] = 'b0100010100010010010101010;
   symbol[ 12] = 'b1111101011100111101001101;
   symbol[ 13] = 'b1010100000101000001011100;
   symbol[ 14] = 'b0001111001011111001000010;
   symbol[ 15] = 'b0001010000010101111111110;
   symbol[ 16] = 'b1100001101001100111110011;
   symbol[ 17] = 'b0000000010000110100011101;
   symbol[ 18] = 'b1111111011000001101011001;
   symbol[ 19] = 'b1000001000101010100010100;
   symbol[ 20] = 'b1011101010010111111111111;
   symbol[ 21] = 'b1011101001101000110110101;
   symbol[ 22] = 'b1011101001011110010010010;
   symbol[ 23] = 'b1000001001010100110010100;
   symbol[ 24] = 'b1111111011101100011111001;
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
