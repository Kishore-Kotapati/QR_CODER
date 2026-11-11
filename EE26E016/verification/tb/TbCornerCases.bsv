// Comprehensive Corner-Case Testbench for QRDecoder
// Systematically exercises:
//   Test 1: Pristine Symbol Baseline
//   Test 2: Format Copy 1 Bit Error (1 flip, Hamming dist = 1) -> Corrected
//   Test 3: Format Copy 1 Bit Error (2 flips, Hamming dist = 2) -> Corrected
//   Test 4: Format Copy 1 Bit Error (3 flips, Hamming dist = 3) -> Corrected
//   Test 5: Format Tie-Breaker (1 flip in Copy 1, 1 flip in Copy 2) -> Copy 1 chosen
//   Test 6: Format Uncorrectable (>3 flips in both copies) -> failed() asserted
//   Test 7: Invalid Dimension (N = 22 != 17 + 4v) -> failed() asserted
//   Test 8: Consecutive Start Recovery (Re-start after failure without HW reset) -> Success
//   Test 9: Consumer Backpressure (Intermittent getByte reads) -> Success
//   Test 10: Hardware Reed-Solomon Error Correction (2 corrupted data bytes) -> Corrected
package TbCornerCases;

import Vector::*;
import QRTypes::*;
import QRDecoder::*;

typedef 21 N;

typedef enum {
   TEST_START,
   TEST_RUN,
   TEST_NEXT
} TestState deriving (Bits, Eq, FShow);

(* synthesize *)
module mkTbCornerCases(Empty);

   // Handout symbol (Version 1-M holding "HELLO CAD FOR VLSI")
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

   // Expected string: "HELLO CAD FOR VLSI" (18 bytes)
   Vector#(18, Bit#(8)) expectedMsg = newVector();
   expectedMsg[ 0] = 8'h48; // 'H'
   expectedMsg[ 1] = 8'h45; // 'E'
   expectedMsg[ 2] = 8'h4C; // 'L'
   expectedMsg[ 3] = 8'h4C; // 'L'
   expectedMsg[ 4] = 8'h4F; // 'O'
   expectedMsg[ 5] = 8'h20; // ' '
   expectedMsg[ 6] = 8'h43; // 'C'
   expectedMsg[ 7] = 8'h41; // 'A'
   expectedMsg[ 8] = 8'h44; // 'D'
   expectedMsg[ 9] = 8'h20; // ' '
   expectedMsg[10] = 8'h46; // 'F'
   expectedMsg[11] = 8'h4F; // 'O'
   expectedMsg[12] = 8'h52; // 'R'
   expectedMsg[13] = 8'h20; // ' '
   expectedMsg[14] = 8'h56; // 'V'
   expectedMsg[15] = 8'h4C; // 'L'
   expectedMsg[16] = 8'h53; // 'S'
   expectedMsg[17] = 8'h49; // 'I'

   QRDecoder dut <- mkQRDecoder;

   Reg#(UInt#(5))   testNum     <- mkReg(1);
   Reg#(TestState)  testState   <- mkReg(TEST_START);
   Reg#(UInt#(32))  cycle       <- mkReg(0);
   Reg#(UInt#(32))  startCycle  <- mkReg(0);
   Reg#(UInt#(5))   byteIdx     <- mkReg(0);
   Reg#(Bit#(1))    answer      <- mkReg(0);

   rule countCycle;
      cycle <= cycle + 1;
   endrule

   // Error injection function based on test number and coordinate
   function Bit#(1) isFlipped(UInt#(5) t, Coord r, Coord c);
      Bit#(1) flip = 0;
      case (t)
         // Test 1: Clean symbol
         1: flip = 0;

         // Test 2: 1-bit format error in Copy 1 at (8, 0)
         2: if (r == 8 && c == 0) flip = 1;

         // Test 3: 2-bit format error in Copy 1 at (8, 0) and (8, 1)
         3: if (r == 8 && (c == 0 || c == 1)) flip = 1;

         // Test 4: 3-bit format error in Copy 1 at (8, 0), (8, 1), (8, 2)
         4: if (r == 8 && (c == 0 || c == 1 || c == 2)) flip = 1;

         // Test 5: Tie-breaker test: 1 error in Copy 1 at (8,0), 1 error in Copy 2 at (20,8)
         5: if ((r == 8 && c == 0) || (r == 20 && c == 8)) flip = 1;

         // Test 6: Uncorrectable format (>3 errors in both copies)
         // Copy 1: (8,0), (8,1), (8,2), (8,3) - 4 errors
         // Copy 2: (20,8), (19,8), (18,8), (17,8) - 4 errors
         6: if ((r == 8 && c <= 3) || (c == 8 && r >= 17 && r <= 20)) flip = 1;

         // Test 7: Invalid dimension (start with N=22)
         7: flip = 0;

         // Test 8: Consecutive start after failure (clean symbol)
         8: flip = 0;

         // Test 9: Consumer backpressure (clean symbol)
         9: flip = 0;

         // Test 10: Reed-Solomon Error Correction (flip 2 bits in data byte 0, 2 bits in data byte 1)
         10: if ((r == 20 && c == 20) || (r == 19 && c == 20) ||
                 (r == 16 && c == 20) || (r == 15 && c == 20)) flip = 1;

         default: flip = 0;
      endcase
      return flip;
   endfunction

   rule serve_req;
      match {.r, .c} <- dut.mem.req;
      Bit#(1) b = 0;
      if (r < 21 && c < 21) begin
         Bit#(N) row = symbol[r];
         b = row[20 - c];
      end
      Bit#(1) corrupted = b ^ isFlipped(testNum, r, c);
      answer <= corrupted;
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule serve_resp;
      dut.mem.resp(answer);
   endrule

   // FSM Step 1: Initialize and Start Test
   rule startTest (testState == TEST_START);
      startCycle <= cycle;
      byteIdx <= 0;
      case (testNum)
         1: begin
            $display("\n[TEST 1/10] Clean Handout Symbol Baseline (21x21)...");
            dut.start(21);
         end
         2: begin
            $display("\n[TEST 2/10] Format Bit Error (1 flip in Copy 1, dist=1)...");
            dut.start(21);
         end
         3: begin
            $display("\n[TEST 3/10] Format Bit Error (2 flips in Copy 1, dist=2)...");
            dut.start(21);
         end
         4: begin
            $display("\n[TEST 4/10] Format Bit Error (3 flips in Copy 1, dist=3)...");
            dut.start(21);
         end
         5: begin
            $display("\n[TEST 5/10] Format Tie-Breaker (1 flip in Copy 1, 1 flip in Copy 2)...");
            dut.start(21);
         end
         6: begin
            $display("\n[TEST 6/10] Uncorrectable Format (>3 flips in both copies: Expect FAILED)...");
            dut.start(21);
         end
         7: begin
            $display("\n[TEST 7/10] Invalid Grid Dimension (N=22 != 17+4v: Expect FAILED)...");
            dut.start(22); // Invalid side length!
         end
         8: begin
            $display("\n[TEST 8/10] Consecutive Start Recovery (Re-start after failed without HW reset)...");
            dut.start(21);
         end
         9: begin
            $display("\n[TEST 9/10] Consumer Backpressure (Stalling getByte reads)...");
            dut.start(21);
         end
         10: begin
            $display("\n[TEST 10/10] Reed-Solomon Hardware Correction (2 corrupted data bytes in memory)...");
            dut.start(21);
         end
         default: begin
            $display("\nALL 10 TESTS FINISHED!");
            $finish(0);
         end
      endcase
      testState <= TEST_RUN;
   endrule

   // FSM Step 2: Handle Successful Byte Reads
   // In Test 9, apply backpressure: only read when (cycle % 7 == 0)
   Bool backpressureAllow = (testNum != 9) || (pack(cycle)[2:0] == 0);

   rule getByte (testState == TEST_RUN && backpressureAllow);
      let b <- dut.getByte;
      Bit#(8) expected = expectedMsg[byteIdx];
      if (testNum == 9) $display("   [Test 9 Backpressure] Read byte %0d ('%c') at cycle %0d", byteIdx, b.data, cycle - startCycle);

      if (b.data != expected) begin
         $display("ERROR [Test %0d]: Byte %0d mismatch! Expected 0x%02h ('%c'), got 0x%02h ('%c')",
                  testNum, byteIdx, expected, expected, b.data, b.data);
         $finish(1);
      end

      if (byteIdx == 17) begin
         if (!b.last) begin
            $display("ERROR [Test %0d]: Byte 17 missing last flag!", testNum);
            $finish(1);
         end
         $display("  -> Test %0d PASSED! Decoded full message in %0d cycles.", testNum, cycle - startCycle);
         testState <= TEST_NEXT;
      end
      else begin
         if (b.last) begin
            $display("ERROR [Test %0d]: Premature last flag at byte %0d!", testNum, byteIdx);
            $finish(1);
         end
         byteIdx <= byteIdx + 1;
      end
   endrule

   // FSM Step 3: Handle DUT Failure
   rule handleFailure (testState == TEST_RUN && dut.failed);
      if (testNum == 6) begin
         $display("  -> Test 6 PASSED! Expected failure correctly asserted for uncorrectable format (%0d cycles).",
                  cycle - startCycle);
         testState <= TEST_NEXT;
      end
      else if (testNum == 7) begin
         $display("  -> Test 7 PASSED! Expected failure correctly asserted for invalid dimension N=22 (%0d cycles).",
                  cycle - startCycle);
         testState <= TEST_NEXT;
      end
      else begin
         $display("ERROR [Test %0d]: Unexpected DUT failure asserted after %0d cycles!",
                  testNum, cycle - startCycle);
         $finish(1);
      end
   endrule

   // Advance to next test
   rule nextTest (testState == TEST_NEXT);
      if (testNum == 10) begin
         $display("\n==============================================================");
         $display("  VERIFICATION COMPLETE: ALL 10 CORNER-CASE TESTS PASSED!");
         $display("==============================================================\n");
         $finish(0);
      end
      else begin
         testNum <= testNum + 1;
         testState <= TEST_START;
      end
   endrule

   // Timeout watchdog: 200,000 cycles per test
   rule timeout (testState == TEST_RUN && cycle - startCycle > 200000);
      $display("ERROR [Test %0d]: TIMEOUT after 200,000 cycles!", testNum);
      $finish(1);
   endrule

endmodule

endpackage
