package TbSweep032;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 29 N;
(* synthesize *)
module mkTbSweep032(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b11111110001111100001101111111;
   symbol[  1] = 'b10000010001101000011001000001;
   symbol[  2] = 'b10111010100011101110001011101;
   symbol[  3] = 'b10111010011100010100001011101;
   symbol[  4] = 'b10111010100000010101001011101;
   symbol[  5] = 'b10000010110111011100101000001;
   symbol[  6] = 'b11111110101010101010101111111;
   symbol[  7] = 'b00000000001010101001100000000;
   symbol[  8] = 'b01001010110000001000110110100;
   symbol[  9] = 'b11101000111000100111000100000;
   symbol[ 10] = 'b00101111000100001011010110101;
   symbol[ 11] = 'b11001101000111100001110011100;
   symbol[ 12] = 'b10010010101100101000000011100;
   symbol[ 13] = 'b10010100000000010011100010110;
   symbol[ 14] = 'b01101110010111010100111111111;
   symbol[ 15] = 'b00001001000000010110001100001;
   symbol[ 16] = 'b00101110101100010011000110100;
   symbol[ 17] = 'b10110100110011101001110011101;
   symbol[ 18] = 'b00111110110000001100111001000;
   symbol[ 19] = 'b00110000111001000110011100011;
   symbol[ 20] = 'b11011111010101011011111110110;
   symbol[ 21] = 'b00000000101101000101100011100;
   symbol[ 22] = 'b11111110000000010010101011100;
   symbol[ 23] = 'b10000010000000111001100010110;
   symbol[ 24] = 'b10111010101011001000111110111;
   symbol[ 25] = 'b10111010000010000111000000000;
   symbol[ 26] = 'b10111010001101010011111100111;
   symbol[ 27] = 'b10000010100100011000000111110;
   symbol[ 28] = 'b11111110000001000000001101100;
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
