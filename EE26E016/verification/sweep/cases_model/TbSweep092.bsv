package TbSweep092;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 29 N;
(* synthesize *)
module mkTbSweep092(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b11111110110000100110001111111;
   symbol[  1] = 'b10000010000100010101001000001;
   symbol[  2] = 'b10111010100011110101101011101;
   symbol[  3] = 'b10111010101011110110001011101;
   symbol[  4] = 'b10111010000011010011001011101;
   symbol[  5] = 'b10000010110101111001101000001;
   symbol[  6] = 'b11111110101010101010101111111;
   symbol[  7] = 'b00000000110001000111100000000;
   symbol[  8] = 'b01010111101100001111011101101;
   symbol[  9] = 'b10001001010010010110100101011;
   symbol[ 10] = 'b01101011111010101001010110111;
   symbol[ 11] = 'b01010000111010111000111001101;
   symbol[ 12] = 'b01111110111101111010100001100;
   symbol[ 13] = 'b00010101101100011000011111111;
   symbol[ 14] = 'b01000110110111001001001111110;
   symbol[ 15] = 'b10110101010101001000100001011;
   symbol[ 16] = 'b11000110010101111001100010111;
   symbol[ 17] = 'b01100100110110010101000110100;
   symbol[ 18] = 'b10101010001110000101111001111;
   symbol[ 19] = 'b00101100100110011001101010101;
   symbol[ 20] = 'b10010011101011101101111110100;
   symbol[ 21] = 'b00000000110101011100100010100;
   symbol[ 22] = 'b11111110110000111011101011100;
   symbol[ 23] = 'b10000010100100100011100010100;
   symbol[ 24] = 'b10111010000011111010111110001;
   symbol[ 25] = 'b10111010100001110110011110011;
   symbol[ 26] = 'b10111010001100011100011111001;
   symbol[ 27] = 'b10000010111100101100011001011;
   symbol[ 28] = 'b11111110001110110100011100100;
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
