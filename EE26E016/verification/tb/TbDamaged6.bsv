// TbDamaged6.bsv -- the sample with 6 codewords damaged: more than t = 5, decoder must say failed.
// Made from TbLogged.bsv (Person B). Original header:
// TbLogged.bsv -- TbSample plus the 4 protocol-log lines (Person B hook for protocol_spec.py).
// Lines marked "protocol log" are the only additions. Build like TbSample, with -g mkTbLogged.
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
package TbDamaged6;

import Vector::*;

import QRTypes::*;
import QRDecoder::*;

typedef 21 N;   // modules per side

(* synthesize *)
module mkTbDamaged6(Empty);

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
   symbol[10] = 'b100100110010111001001;
   symbol[11] = 'b110101010100110100000;
   symbol[12] = 'b111110100110111010100;
   symbol[13] = 'b000000001100000111011;
   symbol[14] = 'b111111100111011000100;
   symbol[15] = 'b100000101111001110100;
   symbol[16] = 'b101110101011000101101;
   symbol[17] = 'b101110101100111011100;
   symbol[18] = 'b101110101111101101000;
   symbol[19] = 'b100000100101111000101;
   symbol[20] = 'b111111101111100101100;

   Integer n = valueOf(N);

   // ---- the decoder under test -------------------------------------------
   QRDecoder dut <- mkQRDecoder;

   Reg#(Bool)      started <- mkReg(False);
   Reg#(UInt#(32)) cycle   <- mkReg(0);
   Reg#(UInt#(32)) startAt <- mkReg(0);
   Reg#(Bit#(1))   answer  <- mkReg(0);

   Reg#(UInt#(32)) stopAt <- mkReg(0);   // protocol log: delayed finish
   rule stopLater (stopAt != 0 && cycle == stopAt);
      $finish(0);
   endrule

   rule tick;
      cycle <= cycle + 1;
   endrule

   // 1. Give the decoder the side length.  This starts the decode.
   rule go (!started);
      dut.start(fromInteger(n));
      started <= True;
      startAt <= cycle;
      $display("start: %0dx%0d symbol", n, n);
      $display("@%0d start %0d", cycle, n);                       // protocol log
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
      $display("@%0d req %0d %0d", cycle, r, c);                  // protocol log
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule serve_resp;
      dut.mem.resp(answer);
   endrule

   // 3. Collect the message, one byte at a time, until the byte with last.
   rule get (started);
      let b <- dut.getByte;
      $display("@%0d byte %02h %0d", cycle, b.data, b.last ? 1 : 0); // protocol log
      if (!b.last)
         $display("byte: %02h  '%c'", b.data, b.data);
      else begin
         $display("byte: %02h  '%c'   <- last", b.data, b.data);
         $display("decoded in %0d cycles", cycle - startAt);
         stopAt <= cycle + 20;      // protocol log: keep running so 'done' can be seen
      end
   endrule

   // protocol log: print failed/done whenever they change (and in cycle 0)
   Reg#(Bool) logInit <- mkReg(False);
   Reg#(Bool) prevF   <- mkReg(False);
   Reg#(Bool) prevD   <- mkReg(False);
   rule log_status (!logInit || dut.failed != prevF || dut.done != prevD);
      $display("@%0d status %0d %0d", cycle, dut.failed ? 1 : 0, dut.done ? 1 : 0);
      logInit <= True;  prevF <= dut.failed;  prevD <= dut.done;
   endrule

   // 4. Or the decoder gives up ...
   rule fail (started && dut.failed);
      $display("decoder raised failed after %0d cycles", cycle - startAt);
      if (stopAt == 0) stopAt <= cycle + 5;
   endrule

   // ... or finds an empty message (done without any byte) ...
   rule empty (started && dut.done);
      $display("empty message, %0d cycles", cycle - startAt);
      if (stopAt == 0) stopAt <= cycle + 5;
   endrule

   // ... or never finishes.
   rule timeout (started && cycle - startAt > 100000);
      $display("no result after 100000 cycles");
      $finish(1);
   endrule

endmodule

endpackage
