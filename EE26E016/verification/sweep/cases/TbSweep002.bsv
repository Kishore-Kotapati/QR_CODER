package TbSweep002;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 29 N;
(* synthesize *)
module mkTbSweep002(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b11111110000010111101101111111;
   symbol[  1] = 'b10000010110100000111001000001;
   symbol[  2] = 'b10111010011101001011001011101;
   symbol[  3] = 'b10111010101001101110101011101;
   symbol[  4] = 'b10111010110001100001001011101;
   symbol[  5] = 'b10000010011110110001001000001;
   symbol[  6] = 'b11111110101010101010101111111;
   symbol[  7] = 'b00000000110011001110100000000;
   symbol[  8] = 'b01011110101100110001011011010;
   symbol[  9] = 'b00100001100000101110001101000;
   symbol[ 10] = 'b10001111110110100101111100001;
   symbol[ 11] = 'b11010101001101110011101001101;
   symbol[ 12] = 'b10010010111010110110100011100;
   symbol[ 13] = 'b11000101101100100001001001110;
   symbol[ 14] = 'b10101011110110011010011100011;
   symbol[ 15] = 'b10001101110000111001011000011;
   symbol[ 16] = 'b01011010111001000111010011010;
   symbol[ 17] = 'b11011001011111000100011110011;
   symbol[ 18] = 'b11011111010011101111011010101;
   symbol[ 19] = 'b11001101011111111011110011110;
   symbol[ 20] = 'b11111011010101000011111110010;
   symbol[ 21] = 'b00000000100010001110100011001;
   symbol[ 22] = 'b11111110001000111000101011001;
   symbol[ 23] = 'b10000010110100101010100010100;
   symbol[ 24] = 'b10111010110111010101111111000;
   symbol[ 25] = 'b10111010110011000111110110000;
   symbol[ 26] = 'b10111010000010110101010101111;
   symbol[ 27] = 'b10000010100010001110110001000;
   symbol[ 28] = 'b11111110011110110101011100110;
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
