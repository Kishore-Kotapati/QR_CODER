package TbSweep077;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 29 N;
(* synthesize *)
module mkTbSweep077(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b11111110100111101110101111111;
   symbol[  1] = 'b10000010111010010001001000001;
   symbol[  2] = 'b10111010101100011011001011101;
   symbol[  3] = 'b10111010110111010100001011101;
   symbol[  4] = 'b10111010101011011111101011101;
   symbol[  5] = 'b10000010000101111010001000001;
   symbol[  6] = 'b11111110101010101010101111111;
   symbol[  7] = 'b00000000100001101000000000000;
   symbol[  8] = 'b01101011011101010001101011111;
   symbol[  9] = 'b00001100001111000001110010101;
   symbol[ 10] = 'b00001011100011000101110000001;
   symbol[ 11] = 'b10100000011110101000110010111;
   symbol[ 12] = 'b10100111010111110001011100111;
   symbol[ 13] = 'b01110001010110110101110100100;
   symbol[ 14] = 'b11101011100101101010001110111;
   symbol[ 15] = 'b01010001101101000110000110011;
   symbol[ 16] = 'b01100111100001011011101110101;
   symbol[ 17] = 'b00000000000101011110000100011;
   symbol[ 18] = 'b10001010011110011010010110101;
   symbol[ 19] = 'b01110101111000101110011101101;
   symbol[ 20] = 'b10011110001100010011111110000;
   symbol[ 21] = 'b00000000110010110011100011110;
   symbol[ 22] = 'b11111110110111010101101011010;
   symbol[ 23] = 'b10000010001001011000100010011;
   symbol[ 24] = 'b10111010100011000000111110110;
   symbol[ 25] = 'b10111010010100110001000111010;
   symbol[ 26] = 'b10111010110110000101111010001;
   symbol[ 27] = 'b10000010110100010001001101010;
   symbol[ 28] = 'b11111110000011001001000011111;
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
