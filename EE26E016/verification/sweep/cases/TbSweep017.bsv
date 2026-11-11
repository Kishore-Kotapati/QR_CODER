package TbSweep017;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 29 N;
(* synthesize *)
module mkTbSweep017(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b11111110110111100101101111111;
   symbol[  1] = 'b10000010110010101010101000001;
   symbol[  2] = 'b10111010011111011000001011101;
   symbol[  3] = 'b10111010010000011110001011101;
   symbol[  4] = 'b10111010011011001101001011101;
   symbol[  5] = 'b10000010011001001100001000001;
   symbol[  6] = 'b11111110101010101010101111111;
   symbol[  7] = 'b00000000000001100111000000000;
   symbol[  8] = 'b01000011111000111000010000011;
   symbol[  9] = 'b00000001001101100010001011110;
   symbol[ 10] = 'b10000111101100100111011110010;
   symbol[ 11] = 'b10010101100111100011101011000;
   symbol[ 12] = 'b01100010000110101100001101000;
   symbol[ 13] = 'b11111101001111001010111111001;
   symbol[ 14] = 'b11001111011111110010010100000;
   symbol[ 15] = 'b11000001001001110001001001100;
   symbol[ 16] = 'b01000111010011100010110001110;
   symbol[ 17] = 'b10000000001001001100000110010;
   symbol[ 18] = 'b11100111011101101011000001101;
   symbol[ 19] = 'b10010100111100111000001010001;
   symbol[ 20] = 'b10011110100011100000111110100;
   symbol[ 21] = 'b00000000110011010111100010110;
   symbol[ 22] = 'b11111110110110010100101011000;
   symbol[ 23] = 'b10000010001101000111100011011;
   symbol[ 24] = 'b10111010000101010101111110011;
   symbol[ 25] = 'b10111010010011000010110111010;
   symbol[ 26] = 'b10111010010000011001100110010;
   symbol[ 27] = 'b10000010101010001000110011101;
   symbol[ 28] = 'b11111110011111110001111111000;
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
