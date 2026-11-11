package TbSweep091;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 25 N;
(* synthesize *)
module mkTbSweep091(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b1111111010101110001111111;
   symbol[  1] = 'b1000001001111100001000001;
   symbol[  2] = 'b1011101001011011001011101;
   symbol[  3] = 'b1011101011100111001011101;
   symbol[  4] = 'b1011101010110011001011101;
   symbol[  5] = 'b1000001011100000001000001;
   symbol[  6] = 'b1111111010101010101111111;
   symbol[  7] = 'b0000000010010100000000000;
   symbol[  8] = 'b1000101110001000111111001;
   symbol[  9] = 'b1101010001100101011101111;
   symbol[ 10] = 'b0101111101001001111111100;
   symbol[ 11] = 'b0111000010110011111011000;
   symbol[ 12] = 'b0100111010100110110100000;
   symbol[ 13] = 'b1110110011001000010100001;
   symbol[ 14] = 'b0011001100111110001100111;
   symbol[ 15] = 'b0010100010110101110001011;
   symbol[ 16] = 'b1100011000101100111110001;
   symbol[ 17] = 'b0000000010100110100011001;
   symbol[ 18] = 'b1111111010100001101010111;
   symbol[ 19] = 'b1000001001101011100010000;
   symbol[ 20] = 'b1011101011110110111110101;
   symbol[ 21] = 'b1011101001101000111101101;
   symbol[ 22] = 'b1011101000111111111110110;
   symbol[ 23] = 'b1000001000110101011100100;
   symbol[ 24] = 'b1111111010101101011010001;
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
