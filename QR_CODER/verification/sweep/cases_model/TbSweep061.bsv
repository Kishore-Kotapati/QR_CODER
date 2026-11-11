package TbSweep061;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 25 N;
(* synthesize *)
module mkTbSweep061(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b1111111010100111001111111;
   symbol[  1] = 'b1000001010011111001000001;
   symbol[  2] = 'b1011101010101110001011101;
   symbol[  3] = 'b1011101001100011001011101;
   symbol[  4] = 'b1011101010011101001011101;
   symbol[  5] = 'b1000001000101110001000001;
   symbol[  6] = 'b1111111010101010101111111;
   symbol[  7] = 'b0000000000110010000000000;
   symbol[  8] = 'b1001111110101111110010111;
   symbol[  9] = 'b1010100100110010001100001;
   symbol[ 10] = 'b1011011110110010011001001;
   symbol[ 11] = 'b1100110010011011001111110;
   symbol[ 12] = 'b1011001101110110011011010;
   symbol[ 13] = 'b1011110110001000011110101;
   symbol[ 14] = 'b1100101101000011010001000;
   symbol[ 15] = 'b1001010101101110100010100;
   symbol[ 16] = 'b1011111001011001111111011;
   symbol[ 17] = 'b0000000011110000100011010;
   symbol[ 18] = 'b1111111011001111101011001;
   symbol[ 19] = 'b1000001011010101100011100;
   symbol[ 20] = 'b1011101011110100111111101;
   symbol[ 21] = 'b1011101010101100010010101;
   symbol[ 22] = 'b1011101000010100111100011;
   symbol[ 23] = 'b1000001001111101111010101;
   symbol[ 24] = 'b1111111010111101101000111;
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
