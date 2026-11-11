package TbSweep090;
import Vector::*;
import QRTypes::*;
import QRDecoder::*;
typedef 21 N;
(* synthesize *)
module mkTbSweep090(Empty);
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[  0] = 'b111111101010101111111;
   symbol[  1] = 'b100000101011001000001;
   symbol[  2] = 'b101110100111001011101;
   symbol[  3] = 'b101110100111001011101;
   symbol[  4] = 'b101110101110001011101;
   symbol[  5] = 'b100000101110101000001;
   symbol[  6] = 'b111111101010101111111;
   symbol[  7] = 'b000000001001000000000;
   symbol[  8] = 'b111001101000111110011;
   symbol[  9] = 'b011111001100110101010;
   symbol[ 10] = 'b000100110010011101110;
   symbol[ 11] = 'b001010001010110001100;
   symbol[ 12] = 'b011101100001100110011;
   symbol[ 13] = 'b000000001111101001110;
   symbol[ 14] = 'b111111100010001011111;
   symbol[ 15] = 'b100000101000100010101;
   symbol[ 16] = 'b101110100010100011111;
   symbol[ 17] = 'b101110100111010010100;
   symbol[ 18] = 'b101110101001011010111;
   symbol[ 19] = 'b100000101011110000010;
   symbol[ 20] = 'b111111101010100111111;
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
