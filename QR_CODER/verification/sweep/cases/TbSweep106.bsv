package TbSweep106;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 25 N;
(* synthesize *)
module mkTbSweep106(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b1111111010001001101111111;
   symbol[  1] = 'b1000001010101011001000001;
   symbol[  2] = 'b1011101001100111001011101;
   symbol[  3] = 'b1011101011001000101011101;
   symbol[  4] = 'b1011101001011100001011101;
   symbol[  5] = 'b1000001001011010001000001;
   symbol[  6] = 'b1111111010101010101111111;
   symbol[  7] = 'b0000000010100110000000000;
   symbol[  8] = 'b1011011100101110101001011;
   symbol[  9] = 'b0111110001110001110001111;
   symbol[ 10] = 'b1110011101110011010111000;
   symbol[ 11] = 'b0110110101011111001001111;
   symbol[ 12] = 'b1101011111000000111100100;
   symbol[ 13] = 'b0101010100010100011110000;
   symbol[ 14] = 'b0110011000001010011001010;
   symbol[ 15] = 'b1010010101001101011010000;
   symbol[ 16] = 'b0011011111110000111111000;
   symbol[ 17] = 'b0000000010001100100010101;
   symbol[ 18] = 'b1111111011011001101011101;
   symbol[ 19] = 'b1000001010001001100011001;
   symbol[ 20] = 'b1011101000111101111111101;
   symbol[ 21] = 'b1011101010101111101001001;
   symbol[ 22] = 'b1011101010111101110111010;
   symbol[ 23] = 'b1000001000000000100101100;
   symbol[ 24] = 'b1111111011001011001011111;
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
