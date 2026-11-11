package TbSweep062;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 29 N;
(* synthesize *)
module mkTbSweep062(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b11111110000101110011001111111;
   symbol[  1] = 'b10000010011001101111001000001;
   symbol[  2] = 'b10111010000011100010001011101;
   symbol[  3] = 'b10111010110101100011101011101;
   symbol[  4] = 'b10111010011100010111101011101;
   symbol[  5] = 'b10000010101110000000101000001;
   symbol[  6] = 'b11111110101010101010101111111;
   symbol[  7] = 'b00000000110100110010000000000;
   symbol[  8] = 'b01100010010000110111001101000;
   symbol[  9] = 'b11010100010110011010010000000;
   symbol[ 10] = 'b10111111110111010111011010100;
   symbol[ 11] = 'b00100001000011000010010000000;
   symbol[ 12] = 'b11100111101011010111111110110;
   symbol[ 13] = 'b00010000110101111110110110000;
   symbol[ 14] = 'b00100010100101000000100101100;
   symbol[ 15] = 'b11010001100001111101101110001;
   symbol[ 16] = 'b11010010001100100100100111100;
   symbol[ 17] = 'b00010001000110000100100111101;
   symbol[ 18] = 'b11110011010011110000100101011;
   symbol[ 19] = 'b00110000110010000101101111110;
   symbol[ 20] = 'b11110110111011011100111111111;
   symbol[ 21] = 'b00000000100100101001100011110;
   symbol[ 22] = 'b11111110001000101111101011011;
   symbol[ 23] = 'b10000010010011011010100011110;
   symbol[ 24] = 'b10111010010110101111111111111;
   symbol[ 25] = 'b10111010011100101011011100000;
   symbol[ 26] = 'b10111010100101001111111110111;
   symbol[ 27] = 'b10000010111000011011000100001;
   symbol[ 28] = 'b11111110001001100111101110111;
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
