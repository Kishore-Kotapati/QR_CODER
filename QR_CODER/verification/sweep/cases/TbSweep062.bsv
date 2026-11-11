package TbSweep062;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 29 N;
(* synthesize *)
module mkTbSweep062(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b11111110000100110011001111111;
   symbol[  1] = 'b10000010000000001111001000001;
   symbol[  2] = 'b10111010010010000010001011101;
   symbol[  3] = 'b10111010100101001011101011101;
   symbol[  4] = 'b10111010010010101111101011101;
   symbol[  5] = 'b10000010101010010000101000001;
   symbol[  6] = 'b11111110101010101010101111111;
   symbol[  7] = 'b00000000110110100010000000000;
   symbol[  8] = 'b01100010010100100111001101000;
   symbol[  9] = 'b11010100000110011010010000000;
   symbol[ 10] = 'b00110111110111010111011010101;
   symbol[ 11] = 'b10100101010010000010010000000;
   symbol[ 12] = 'b01101111100001110111111110111;
   symbol[ 13] = 'b00100100010101111110110110000;
   symbol[ 14] = 'b00100010000111011000100101100;
   symbol[ 15] = 'b11110001000111111101101110001;
   symbol[ 16] = 'b11010010001100100100100111100;
   symbol[ 17] = 'b00010001000110000100100111100;
   symbol[ 18] = 'b11110111010011110000100101011;
   symbol[ 19] = 'b00111000111011000101101111110;
   symbol[ 20] = 'b11110110100001111100111111111;
   symbol[ 21] = 'b00000000101110001001100011110;
   symbol[ 22] = 'b11111110001000101111101011011;
   symbol[ 23] = 'b10000010010101011010100011110;
   symbol[ 24] = 'b10111010010110101111111111111;
   symbol[ 25] = 'b10111010011101101011011100000;
   symbol[ 26] = 'b10111010110100101111111110111;
   symbol[ 27] = 'b10000010100000111011000100001;
   symbol[ 28] = 'b11111110011000100111101110111;
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
