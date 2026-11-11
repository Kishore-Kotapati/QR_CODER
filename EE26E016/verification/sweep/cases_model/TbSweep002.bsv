package TbSweep002;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 29 N;
(* synthesize *)
module mkTbSweep002(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b11111110010010111101101111111;
   symbol[  1] = 'b10000010111100000011001000001;
   symbol[  2] = 'b10111010000100001001001011101;
   symbol[  3] = 'b10111010101001001010101011101;
   symbol[  4] = 'b10111010111001101000001011101;
   symbol[  5] = 'b10000010011110110001001000001;
   symbol[  6] = 'b11111110101010101010101111111;
   symbol[  7] = 'b00000000110001000110000000000;
   symbol[  8] = 'b01011110101100110000011011010;
   symbol[  9] = 'b10100001110001101110001101001;
   symbol[ 10] = 'b01000011101111100001100100011;
   symbol[ 11] = 'b11011001011100010011111001101;
   symbol[ 12] = 'b11001010101001010100011001100;
   symbol[ 13] = 'b10000000000010010011100110110;
   symbol[ 14] = 'b10001011010110011011111001011;
   symbol[ 15] = 'b10111101010100110000111001011;
   symbol[ 16] = 'b01111010111001000110010011010;
   symbol[ 17] = 'b11010001011111000100011110000;
   symbol[ 18] = 'b11010111000010001111011010100;
   symbol[ 19] = 'b11000001001110111001100011100;
   symbol[ 20] = 'b11110011010111000011111110001;
   symbol[ 21] = 'b00000000101000001100100011001;
   symbol[ 22] = 'b11111110001010111000101010001;
   symbol[ 23] = 'b10000010110110101011100011000;
   symbol[ 24] = 'b10111010110111010100111110100;
   symbol[ 25] = 'b10111010100011000111000000000;
   symbol[ 26] = 'b10111010000011110100111111111;
   symbol[ 27] = 'b10000010111011001110110001000;
   symbol[ 28] = 'b11111110010100010101011000110;
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
