// A minimal testbench: decodes one QR symbol and prints the message.
//
// The symbol is written out below, one row per line, 1 = dark, column 0 on
// the left.  It is a version-1 (21x21) code holding "HELLO CAD FOR VLSI";
// sample_qr.png in the handout shows it as an image.
// To try another symbol, replace the rows; for another version, change N
// as well (N = 17 + 4 * version) and write N rows of N bits.
//
// README.md has the commands to build and run it.
//
// Our grading test bench drives the decoder the same way, for many symbols
// in a row, and compares the bytes with the expected ones.
package TbSample;

import Vector::*;

import QRTypes::*;
import QRDecoder::*;

typedef 21 N;   // modules per side

(* synthesize *)
module mkTbSample(Empty);

   // ---- the symbol -------------------------------------------------------
   Vector#(N, Bit#(N)) symbol = replicate(0);
   symbol[ 0] = 'b111111100111101111111;
   symbol[ 1] = 'b100000100011101000001;
   symbol[ 2] = 'b101110101101001011101;
   symbol[ 3] = 'b101110101101001011101;
   symbol[ 4] = 'b101110101110101011101;
   symbol[ 5] = 'b100000101001001000001;
   symbol[ 6] = 'b111111101010101111111;
   symbol[ 7] = 'b000000001010000000000;
   symbol[ 8] = 'b101111100101001111100;
   symbol[ 9] = 'b111010011100110001111;
   symbol[10] = 'b100110110110111001001;
   symbol[11] = 'b110101010100110000000;
   symbol[12] = 'b111110100110111010100;
   symbol[13] = 'b000000001100000111011;
   symbol[14] = 'b111111100111011001100;
   symbol[15] = 'b100000101111001110110;
   symbol[16] = 'b101110101011000101101;
   symbol[17] = 'b101110101100111011100;
   symbol[18] = 'b101110101111101101000;
   symbol[19] = 'b100000100100111000101;
   symbol[20] = 'b111111101111100101100;

   Integer n = valueOf(N);

   // ---- the decoder under test -------------------------------------------
   QRDecoder dut <- mkQRDecoder;

   Reg#(Bool)      started <- mkReg(False);
   Reg#(UInt#(32)) cycle   <- mkReg(0);
   Reg#(UInt#(32)) startAt <- mkReg(0);
   Reg#(Bit#(1))   answer  <- mkReg(0);

   rule tick;
      cycle <= cycle + 1;
   endrule

   // 1. Give the decoder the side length.  This starts the decode.
   rule go (!started);
      dut.start(fromInteger(n));
      started <= True;
      startAt <= cycle;
      $display("start: %0dx%0d symbol", n, n);
   endrule

   // 2. Serve its memory reads: take the (row, col) it asks for in this
   //    cycle, answer in the next.  Outside the symbol the answer is 0.
   rule serve_req;
      match {.r, .c} <- dut.mem.req;
      Bit#(1) b = 0;
      if (r < fromInteger(n) && c < fromInteger(n)) begin
         Bit#(N) row = symbol[r];
         b = row[fromInteger(n - 1) - c];   // column 0 is the leftmost bit
      end
      answer <= b;
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule serve_resp;
      dut.mem.resp(answer);
   endrule

   // 3. Collect the message, one byte at a time, until the byte with last.
   rule get (started);
      let b <- dut.getByte;
      if (!b.last)
         $display("byte: %02h  '%c'", b.data, b.data);
      else begin
         $display("byte: %02h  '%c'   <- last", b.data, b.data);
         $display("decoded in %0d cycles", cycle - startAt);
         $finish(0);
      end
   endrule

   // 4. Or the decoder gives up ...
   rule fail (started && dut.failed);
      $display("decoder raised failed after %0d cycles", cycle - startAt);
      $finish(1);
   endrule

   // ... or finds an empty message (done without any byte) ...
   rule empty (started && dut.done);
      $display("empty message, %0d cycles", cycle - startAt);
      $finish(0);
   endrule

   // ... or never finishes.
   rule timeout (started && cycle - startAt > 100000);
      $display("no result after 100000 cycles");
      $finish(1);
   endrule

endmodule

endpackage
