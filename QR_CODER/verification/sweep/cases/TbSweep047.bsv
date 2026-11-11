package TbSweep047;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 29 N;
(* synthesize *)
module mkTbSweep047(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b11111110111111010000001111111;
   symbol[  1] = 'b10000010000101010010101000001;
   symbol[  2] = 'b10111010011100100000001011101;
   symbol[  3] = 'b10111010010000111010001011101;
   symbol[  4] = 'b10111010111101110100101011101;
   symbol[  5] = 'b10000010100000101101001000001;
   symbol[  6] = 'b11111110101010101010101111111;
   symbol[  7] = 'b00000000000100101111100000000;
   symbol[  8] = 'b01111111000001101001000110001;
   symbol[  9] = 'b10011001011000010110110101101;
   symbol[ 10] = 'b10100011011011000101001000110;
   symbol[ 11] = 'b11001001010001001111111101100;
   symbol[ 12] = 'b01110111101110010001101010010;
   symbol[ 13] = 'b11100101010001100010010010000;
   symbol[ 14] = 'b11100010111111010010110010110;
   symbol[ 15] = 'b10000100001100011000000011000;
   symbol[ 16] = 'b01111111011101100010110110110;
   symbol[ 17] = 'b11000101000011011000000010011;
   symbol[ 18] = 'b10110010110110100010110111000;
   symbol[ 19] = 'b10110000100111101000000010010;
   symbol[ 20] = 'b10101010111100101010111111000;
   symbol[ 21] = 'b00000000110010110100100011010;
   symbol[ 22] = 'b11111110101100011100101011001;
   symbol[ 23] = 'b10000010101010110111100010011;
   symbol[ 24] = 'b10111010111110111001111111101;
   symbol[ 25] = 'b10111010110011110110110011110;
   symbol[ 26] = 'b10111010101010011101100010110;
   symbol[ 27] = 'b10000010101010110110001001110;
   symbol[ 28] = 'b11111110010001110001111110000;
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
