package TbSweep046;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 25 N;
(* synthesize *)
module mkTbSweep046(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b1111111001110100101111111;
   symbol[  1] = 'b1000001000010111001000001;
   symbol[  2] = 'b1011101000110100101011101;
   symbol[  3] = 'b1011101001101111001011101;
   symbol[  4] = 'b1011101001101110101011101;
   symbol[  5] = 'b1000001010111110001000001;
   symbol[  6] = 'b1111111010101010101111111;
   symbol[  7] = 'b0000000000000010000000000;
   symbol[  8] = 'b1001011010100001010100000;
   symbol[  9] = 'b1001100111001011011000000;
   symbol[ 10] = 'b0110111001110000111011111;
   symbol[ 11] = 'b1110110100100011001011001;
   symbol[ 12] = 'b1101101100011000101001011;
   symbol[ 13] = 'b0000000110011001010100111;
   symbol[ 14] = 'b1000101101101001111010011;
   symbol[ 15] = 'b0111100000001110110101001;
   symbol[ 16] = 'b1101111010110111111111100;
   symbol[ 17] = 'b0000000011100000100011111;
   symbol[ 18] = 'b1111111000000100101011001;
   symbol[ 19] = 'b1000001010110101100010111;
   symbol[ 20] = 'b1011101001111010111110010;
   symbol[ 21] = 'b1011101011111100010111010;
   symbol[ 22] = 'b1011101000111110001110101;
   symbol[ 23] = 'b1000001000111101011100000;
   symbol[ 24] = 'b1111111010010011000101011;
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
