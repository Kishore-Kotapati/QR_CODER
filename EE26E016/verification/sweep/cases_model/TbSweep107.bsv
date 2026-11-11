package TbSweep107;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 29 N;
(* synthesize *)
module mkTbSweep107(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b11111110000011111001101111111;
   symbol[  1] = 'b10000010100101100001001000001;
   symbol[  2] = 'b10111010011100101001001011101;
   symbol[  3] = 'b10111010111000001110101011101;
   symbol[  4] = 'b10111010110011110100001011101;
   symbol[  5] = 'b10000010011100100100001000001;
   symbol[  6] = 'b11111110101010101010101111111;
   symbol[  7] = 'b00000000110101000001100000000;
   symbol[  8] = 'b01011110101010100001011011010;
   symbol[  9] = 'b10101001100010101010001101000;
   symbol[ 10] = 'b00000111100100100111101100010;
   symbol[ 11] = 'b11011101000111110111101001110;
   symbol[ 12] = 'b00010110000011110110001001101;
   symbol[ 13] = 'b10010101100000001001111110100;
   symbol[ 14] = 'b11001011110010111011111100010;
   symbol[ 15] = 'b00101100010000011001011011101;
   symbol[ 16] = 'b10111010111001010110010000100;
   symbol[ 17] = 'b11011001001110001100011110010;
   symbol[ 18] = 'b11011011000011101001001010110;
   symbol[ 19] = 'b11000001001110110101100111100;
   symbol[ 20] = 'b11100111110111101001111110010;
   symbol[ 21] = 'b00000000101100101110100010001;
   symbol[ 22] = 'b11111110001100110001101010101;
   symbol[ 23] = 'b10000010110111000010100011000;
   symbol[ 24] = 'b10111010110110010101111110000;
   symbol[ 25] = 'b10111010110010100011110000000;
   symbol[ 26] = 'b10111010001010010110001111111;
   symbol[ 27] = 'b10000010101011001010100110101;
   symbol[ 28] = 'b11111110010100111101011100100;
   Integer n = 29;
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
