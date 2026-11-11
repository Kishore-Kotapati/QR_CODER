package TbSweep032;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 29 N;
(* synthesize *)
module mkTbSweep032(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b11111110010011100001101111111;
   symbol[  1] = 'b10000010011001000011001000001;
   symbol[  2] = 'b10111010111011001110001011101;
   symbol[  3] = 'b10111010011100110100101011101;
   symbol[  4] = 'b10111010101000010101001011101;
   symbol[  5] = 'b10000010100101011100001000001;
   symbol[  6] = 'b11111110101010101010101111111;
   symbol[  7] = 'b00000000001000110001000000000;
   symbol[  8] = 'b01001010111000001001110110100;
   symbol[  9] = 'b01101000101001100111000100011;
   symbol[ 10] = 'b10100111001101101011011110001;
   symbol[ 11] = 'b00001101000111100001111011101;
   symbol[ 12] = 'b11000010010100001000100110110;
   symbol[ 13] = 'b11000000100100100111110011000;
   symbol[ 14] = 'b01011110010011000010001001010;
   symbol[ 15] = 'b00011000000100001101111010111;
   symbol[ 16] = 'b00001110101100010101000110111;
   symbol[ 17] = 'b10110100110010110011100011111;
   symbol[ 18] = 'b00110010101001001100100001000;
   symbol[ 19] = 'b00110000111001111110011100000;
   symbol[ 20] = 'b11001111011110010011111110100;
   symbol[ 21] = 'b00000000101101100101100011100;
   symbol[ 22] = 'b11111110000100010010101010100;
   symbol[ 23] = 'b10000010000110110000100011110;
   symbol[ 24] = 'b10111010101001001001111111011;
   symbol[ 25] = 'b10111010010100000110100110110;
   symbol[ 26] = 'b10111010011101010010011110111;
   symbol[ 27] = 'b10000010100011111000000010011;
   symbol[ 28] = 'b11111110001111100000001100101;
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
