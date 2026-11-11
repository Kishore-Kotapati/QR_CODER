package TbSweep047;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 29 N;
(* synthesize *)
module mkTbSweep047(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b11111110101000011100101111111;
   symbol[  1] = 'b10000010010011111101101000001;
   symbol[  2] = 'b10111010011111101111101011101;
   symbol[  3] = 'b10111010000110010000101011101;
   symbol[  4] = 'b10111010110011000110001011101;
   symbol[  5] = 'b10000010111000011010101000001;
   symbol[  6] = 'b11111110101010101010101111111;
   symbol[  7] = 'b00000000000110110110000000000;
   symbol[  8] = 'b01111111011001001000000110001;
   symbol[  9] = 'b11001100000101000010101100010;
   symbol[ 10] = 'b00010110000011000010011111010;
   symbol[ 11] = 'b01111101010000001000101000001;
   symbol[ 12] = 'b10010010011100010011001101011;
   symbol[ 13] = 'b11010001001001100100110011010;
   symbol[ 14] = 'b01011110101110100101001100001;
   symbol[ 15] = 'b01110001110001100111101101011;
   symbol[ 16] = 'b10011111000101011101101011001;
   symbol[ 17] = 'b10001000110101010101001101110;
   symbol[ 18] = 'b10010011101111111101101000100;
   symbol[ 19] = 'b10101000001000110111011101111;
   symbol[ 20] = 'b10000011100110110001111110010;
   symbol[ 21] = 'b00000000110110111011100010000;
   symbol[ 22] = 'b11111110100011000010101010010;
   symbol[ 23] = 'b10000010100001001001100010000;
   symbol[ 24] = 'b10111010111111000010111111010;
   symbol[ 25] = 'b10111010111110111000101100010;
   symbol[ 26] = 'b10111010110000000001010101010;
   symbol[ 27] = 'b10000010111010001111010000010;
   symbol[ 28] = 'b11111110000100100101101111000;
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
