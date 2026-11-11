package TbSweep107;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 29 N;
(* synthesize *)
module mkTbSweep107(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b11111110000100110011001111111;
   symbol[  1] = 'b10000010100011001100101000001;
   symbol[  2] = 'b10111010010110000110101011101;
   symbol[  3] = 'b10111010101111001001001011101;
   symbol[  4] = 'b10111010110001111110101011101;
   symbol[  5] = 'b10000010000100000110101000001;
   symbol[  6] = 'b11111110101010101010101111111;
   symbol[  7] = 'b00000000110011000001100000000;
   symbol[  8] = 'b01011110110000010011111011010;
   symbol[  9] = 'b01110100101100110000111010101;
   symbol[ 10] = 'b01110010100110111110010011110;
   symbol[ 11] = 'b10101101010100001100011110011;
   symbol[ 12] = 'b10100011011011110111111110100;
   symbol[ 13] = 'b10110100011000011101010101100;
   symbol[ 14] = 'b00110111100111110100000001000;
   symbol[ 15] = 'b01111000001001010111000100100;
   symbol[ 16] = 'b10111010000001111101101110101;
   symbol[ 17] = 'b10011101011001001010101001111;
   symbol[ 18] = 'b11110111010011110000100101001;
   symbol[ 19] = 'b11011101000000100110001100010;
   symbol[ 20] = 'b11000110000111111000111111011;
   symbol[ 21] = 'b00000000101010100011100011011;
   symbol[ 22] = 'b11111110000011100110101010010;
   symbol[ 23] = 'b10000010111101010100100011111;
   symbol[ 24] = 'b10111010110010101111111111111;
   symbol[ 25] = 'b10111010101110001000111111100;
   symbol[ 26] = 'b10111010001000001011011010011;
   symbol[ 27] = 'b10000010110011010001101110101;
   symbol[ 28] = 'b11111110010001001110100111100;
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
