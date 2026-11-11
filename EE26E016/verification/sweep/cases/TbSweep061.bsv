package TbSweep061;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 25 N;
(* synthesize *)
module mkTbSweep061(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b1111111011110111001111111;
   symbol[  1] = 'b1000001011111111001000001;
   symbol[  2] = 'b1011101011010110001011101;
   symbol[  3] = 'b1011101000011011001011101;
   symbol[  4] = 'b1011101011011101001011101;
   symbol[  5] = 'b1000001001001110001000001;
   symbol[  6] = 'b1111111010101010101111111;
   symbol[  7] = 'b0000000000001010000000000;
   symbol[  8] = 'b1001111111000111110010111;
   symbol[  9] = 'b0001110000111010001101011;
   symbol[ 10] = 'b0110111110110010011000101;
   symbol[ 11] = 'b1011000100000011001110111;
   symbol[ 12] = 'b1000101000110110011010000;
   symbol[ 13] = 'b1011110101101000011110100;
   symbol[ 14] = 'b1111111011000011010001001;
   symbol[ 15] = 'b1010100110001110100010100;
   symbol[ 16] = 'b1011111011011001111111111;
   symbol[ 17] = 'b0000000011110000100010111;
   symbol[ 18] = 'b1111111010001111101011011;
   symbol[ 19] = 'b1000001010010101100011010;
   symbol[ 20] = 'b1011101011010100111111101;
   symbol[ 21] = 'b1011101010001100010010101;
   symbol[ 22] = 'b1011101001010100111101011;
   symbol[ 23] = 'b1000001000111101111010101;
   symbol[ 24] = 'b1111111010111101101001111;
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
