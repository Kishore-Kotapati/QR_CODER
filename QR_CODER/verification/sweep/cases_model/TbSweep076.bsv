package TbSweep076;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 25 N;
(* synthesize *)
module mkTbSweep076(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b1111111000100111001111111;
   symbol[  1] = 'b1000001011110001001000001;
   symbol[  2] = 'b1011101011011010101011101;
   symbol[  3] = 'b1011101011000011001011101;
   symbol[  4] = 'b1011101000111111001011101;
   symbol[  5] = 'b1000001000110110101000001;
   symbol[  6] = 'b1111111010101010101111111;
   symbol[  7] = 'b0000000010111100000000000;
   symbol[  8] = 'b1000001011110011011001110;
   symbol[  9] = 'b1110110011000010001101011;
   symbol[ 10] = 'b0101001111110000001010111;
   symbol[ 11] = 'b1000100000100011111111001;
   symbol[ 12] = 'b0010011100100110011010001;
   symbol[ 13] = 'b1110010100001110011000011;
   symbol[ 14] = 'b1011111111100111110101011;
   symbol[ 15] = 'b1011100100001110100011100;
   symbol[ 16] = 'b1010111100101011111111101;
   symbol[ 17] = 'b0000000011000000100011110;
   symbol[ 18] = 'b1111111000001111101010011;
   symbol[ 19] = 'b1000001000010011100011000;
   symbol[ 20] = 'b1011101000010000111111011;
   symbol[ 21] = 'b1011101001101100010110101;
   symbol[ 22] = 'b1011101001000110101101001;
   symbol[ 23] = 'b1000001000001101011110001;
   symbol[ 24] = 'b1111111011011100011101101;
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
