package TbSweep077;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 29 N;
(* synthesize *)
module mkTbSweep077(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b11111110110111101000101111111;
   symbol[  1] = 'b10000010111010010101101000001;
   symbol[  2] = 'b10111010111100011000101011101;
   symbol[  3] = 'b10111010100111111101001011101;
   symbol[  4] = 'b10111010100001010100001011101;
   symbol[  5] = 'b10000010000101100010001000001;
   symbol[  6] = 'b11111110101010101010101111111;
   symbol[  7] = 'b00000000100011111000100000000;
   symbol[  8] = 'b01101011011101010001101011111;
   symbol[  9] = 'b11011100011110010001110010111;
   symbol[ 10] = 'b10010011100010111101110000001;
   symbol[ 11] = 'b01000000011111101000111010100;
   symbol[ 12] = 'b11000111110110100001010010101;
   symbol[ 13] = 'b00100001111100110101010100100;
   symbol[ 14] = 'b11101010000101101010001010101;
   symbol[ 15] = 'b01110001101101001111000101000;
   symbol[ 16] = 'b01000111100101001010001111001;
   symbol[ 17] = 'b00001000010100011111000101011;
   symbol[ 18] = 'b10001010000110011010001111111;
   symbol[ 19] = 'b01111001101000001111000101010;
   symbol[ 20] = 'b10010010010100010010111111111;
   symbol[ 21] = 'b00000000110011010011100010110;
   symbol[ 22] = 'b11111110110110100100101011010;
   symbol[ 23] = 'b10000010001111110000100011011;
   symbol[ 24] = 'b10111010100010000001111111010;
   symbol[ 25] = 'b10111010000100110001110100110;
   symbol[ 26] = 'b10111010101010100101011010001;
   symbol[ 27] = 'b10000010111101110001001010110;
   symbol[ 28] = 'b11111110000000101001000010111;
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
