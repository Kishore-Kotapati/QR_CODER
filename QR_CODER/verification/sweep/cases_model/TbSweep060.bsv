package TbSweep060;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 21 N;
(* synthesize *)
module mkTbSweep060(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b111111101001001111111;
   symbol[  1] = 'b100000100100101000001;
   symbol[  2] = 'b101110101011101011101;
   symbol[  3] = 'b101110101111001011101;
   symbol[  4] = 'b101110101011101011101;
   symbol[  5] = 'b100000100110001000001;
   symbol[  6] = 'b111111101010101111111;
   symbol[  7] = 'b000000000001000000000;
   symbol[  8] = 'b111100101011110011101;
   symbol[  9] = 'b100100011101111010100;
   symbol[ 10] = 'b001010100011101100110;
   symbol[ 11] = 'b101110000111001111011;
   symbol[ 12] = 'b011100111001100011000;
   symbol[ 13] = 'b000000001000101000011;
   symbol[ 14] = 'b111111100010000111110;
   symbol[ 15] = 'b100000100011100010001;
   symbol[ 16] = 'b101110100101111000000;
   symbol[ 17] = 'b101110101111010011110;
   symbol[ 18] = 'b101110101011101110100;
   symbol[ 19] = 'b100000101011001111011;
   symbol[ 20] = 'b111111101110111110110;
   Integer n = 21;
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
