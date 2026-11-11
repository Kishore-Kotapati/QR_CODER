package TbSweep046;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 25 N;
(* synthesize *)
module mkTbSweep046(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b1111111001001100101111111;
   symbol[  1] = 'b1000001000111111001000001;
   symbol[  2] = 'b1011101001111100101011101;
   symbol[  3] = 'b1011101000110111001011101;
   symbol[  4] = 'b1011101001100110101011101;
   symbol[  5] = 'b1000001010000110001000001;
   symbol[  6] = 'b1111111010101010101111111;
   symbol[  7] = 'b0000000000101010000000000;
   symbol[  8] = 'b1001011010101001110100000;
   symbol[  9] = 'b1100010011110011011101111;
   symbol[ 10] = 'b1010011001000000010111101;
   symbol[ 11] = 'b0010000110001011000110011;
   symbol[ 12] = 'b0111011011101000110110110;
   symbol[ 13] = 'b0111110000011001100000000;
   symbol[ 14] = 'b1010001011101001111100001;
   symbol[ 15] = 'b0110010001001111100000010;
   symbol[ 16] = 'b1100101111110110111110010;
   symbol[ 17] = 'b0000000011101000100011101;
   symbol[ 18] = 'b1111111001100100101010011;
   symbol[ 19] = 'b1000001010011101100010010;
   symbol[ 20] = 'b1011101001001011111111110;
   symbol[ 21] = 'b1011101011010101010011101;
   symbol[ 22] = 'b1011101001000110001010011;
   symbol[ 23] = 'b1000001001011100111111000;
   symbol[ 24] = 'b1111111010010010111011010;
   Integer n = 25;
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
