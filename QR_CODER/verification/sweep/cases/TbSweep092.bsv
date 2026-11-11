package TbSweep092;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 29 N;
(* synthesize *)
module mkTbSweep092(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b11111110110000100110001111111;
   symbol[  1] = 'b10000010011100010011001000001;
   symbol[  2] = 'b10111010100011010011101011101;
   symbol[  3] = 'b10111010110010011110101011101;
   symbol[  4] = 'b10111010001010111011101011101;
   symbol[  5] = 'b10000010111011100001001000001;
   symbol[  6] = 'b11111110101010101010101111111;
   symbol[  7] = 'b00000000101110101110000000000;
   symbol[  8] = 'b01010111100101010110111101101;
   symbol[  9] = 'b10001001010011001111000101011;
   symbol[ 10] = 'b10101011110010001011001110100;
   symbol[ 11] = 'b10011100110010010011110001110;
   symbol[ 12] = 'b00100110110110100010101101100;
   symbol[ 13] = 'b01011001001011010010101110111;
   symbol[ 14] = 'b01110011010010111001010111110;
   symbol[ 15] = 'b10110100110010110000111010111;
   symbol[ 16] = 'b11001110010000101000111011011;
   symbol[ 17] = 'b01101000100111110101010110010;
   symbol[ 18] = 'b10100010010110100101101000000;
   symbol[ 19] = 'b00101000100110111001101011101;
   symbol[ 20] = 'b10010111011001001101111110011;
   symbol[ 21] = 'b00000000110011011101100011100;
   symbol[ 22] = 'b11111110110010110011101010000;
   symbol[ 23] = 'b10000010100010101011100010100;
   symbol[ 24] = 'b10111010000111111010111111101;
   symbol[ 25] = 'b10111010100001110110011010011;
   symbol[ 26] = 'b10111010010100011111100001001;
   symbol[ 27] = 'b10000010111101001110010001011;
   symbol[ 28] = 'b11111110011100111011110100100;
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
