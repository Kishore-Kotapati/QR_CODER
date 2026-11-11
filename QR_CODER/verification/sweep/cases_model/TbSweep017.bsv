package TbSweep017;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 29 N;
(* synthesize *)
module mkTbSweep017(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b11111110100100110011001111111;
   symbol[  1] = 'b10000010100010101101001000001;
   symbol[  2] = 'b10111010000110101111101011101;
   symbol[  3] = 'b10111010000111000001001011101;
   symbol[  4] = 'b10111010011111000010001011101;
   symbol[  5] = 'b10000010001110000010101000001;
   symbol[  6] = 'b11111110101010101010101111111;
   symbol[  7] = 'b00000000010100101000000000000;
   symbol[  8] = 'b01000011111001011010110000011;
   symbol[  9] = 'b01111100101101110000111010111;
   symbol[ 10] = 'b00011110000011111100100111000;
   symbol[ 11] = 'b00100101000001100110011010010;
   symbol[ 12] = 'b00110011111000111111111110111;
   symbol[ 13] = 'b11000000010101001100101111000;
   symbol[ 14] = 'b11010010101000101101001110101;
   symbol[ 15] = 'b00011101101001011111000100100;
   symbol[ 16] = 'b11111111100101011001001011101;
   symbol[ 17] = 'b10101101000100011110100100111;
   symbol[ 18] = 'b11110010011010110000100101101;
   symbol[ 19] = 'b10010100000001110111110100100;
   symbol[ 20] = 'b10010111010100010001111111111;
   symbol[ 21] = 'b00000000100100101110100010011;
   symbol[ 22] = 'b11111110100111011010101010010;
   symbol[ 23] = 'b10000010010001001010100010010;
   symbol[ 24] = 'b10111010010010111011111111011;
   symbol[ 25] = 'b10111010011111101001010010011;
   symbol[ 26] = 'b10111010010001000011010111111;
   symbol[ 27] = 'b10000010100011110000101010010;
   symbol[ 28] = 'b11111110001101001011001101010;
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
