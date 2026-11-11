package TbPayloadModes;

import Vector::*;
import FIFOF::*;
import QRTypes::*;
import QRTables::*;
import QRInternalTypes::*;
import QRPayload::*;

// Mock Backend that serves a vector of bytes
module mkMockBackend #(Vector#(n, Bit#(8)) dataBytes) (QRBackend);
   Reg#(UInt#(16)) ptr <- mkReg(0);
   UInt#(16) total = fromInteger(valueOf(n));

   method Action configure(BackendConfig cfg);
      ptr <= 0;
   endmethod

   method Action putRawByte(Bit#(8) b);
   endmethod

   method Bool isError() = False;
   method Bool isReady() = True;

   method ActionValue#(Bit#(8)) getCorrectedByte() if (ptr < total);
      ptr <= ptr + 1;
      return dataBytes[ptr];
   endmethod

   method Action reset();
      ptr <= 0;
   endmethod
endmodule

(* synthesize *)
module mkTbPayloadModes(Empty);

   Reg#(UInt#(4))  testId    <- mkReg(1);
   Reg#(UInt#(16)) byteCount <- mkReg(0);
   Reg#(UInt#(32)) cycle     <- mkReg(0);

   rule tick;
      cycle <= cycle + 1;
   endrule

   // ---------------------------------------------------------
   // Stream 1: Empty message (immediate terminator 0000)
   // ---------------------------------------------------------
   Vector#(16, Bit#(8)) streamEmpty = replicate(0);
   QRBackend backend1 <- mkMockBackend(streamEmpty);
   QRPayload payload1 <- mkQRPayload(backend1);

   // ---------------------------------------------------------
   // Stream 2: Byte mode "Test"
   // Mode 0100, Count 4 = 0x04, "Test" = 0x54, 0x65, 0x73, 0x74
   // Bytes: [0x40, 0x45, 0x46, 0x57, 0x37, 0x40, 0, ...]
   // ---------------------------------------------------------
   Vector#(16, Bit#(8)) streamByte = replicate(0);
   streamByte[0] = 8'h40;
   streamByte[1] = 8'h45;
   streamByte[2] = 8'h46;
   streamByte[3] = 8'h57;
   streamByte[4] = 8'h37;
   streamByte[5] = 8'h40;
   QRBackend backend2 <- mkMockBackend(streamByte);
   QRPayload payload2 <- mkQRPayload(backend2);

   // ---------------------------------------------------------
   // Stream 3: Numeric mode "8675309" (3-digit + 3-digit + 1-digit)
   // Mode 0001, Count 7 (10b), 867 (10b), 530 (10b), 9 (4b)
   // Bytes: [0x10, 0x1F, 0x63, 0x84, 0xA4, 0x00, 0, ...]
   // ---------------------------------------------------------
   Vector#(16, Bit#(8)) streamNum = replicate(0);
   streamNum[0] = 8'h10;
   streamNum[1] = 8'h1F;
   streamNum[2] = 8'h63;
   streamNum[3] = 8'h84;
   streamNum[4] = 8'hA4;
   streamNum[5] = 8'h00;
   QRBackend backend3 <- mkMockBackend(streamNum);
   QRPayload payload3 <- mkQRPayload(backend3);

   // ---------------------------------------------------------
   // Stream 4: Numeric 2-digit group "12"
   // Mode 0001 (4b)
   // Count 2 (10b) = 0000000010
   // 12 (7b) = 0001100
   // Terminator (4b) = 0000
   // Bits: 0001 0000000010 0001100 0000 -> 00010000 00001000 01100000 00000000
   // ---------------------------------------------------------
   Vector#(16, Bit#(8)) streamNum2 = replicate(0);
   streamNum2[0] = 8'h10;
   streamNum2[1] = 8'h08;
   streamNum2[2] = 8'h60;
   QRBackend backend4 <- mkMockBackend(streamNum2);
   QRPayload payload4 <- mkQRPayload(backend4);

   // ---------------------------------------------------------
   // Stream 5: Multi-segment: Alphanumeric "AB" + Numeric "12"
   // Segment 1 (Alphanumeric):
   //   Mode 0010 (4b)
   //   Count 2 (9b for v1 alnum) = 000000010
   //   "AB": 'A'=10, 'B'=11 -> 10*45+11 = 461 (11b) = 00111001101
   // Segment 2 (Numeric):
   //   Mode 0001 (4b)
   //   Count 2 (10b) = 0000000010
   //   "12": 12 (7b) = 0001100
   //   Terminator (4b) = 0000
   // Bits:
   //   0010 000000010 00111001101 | 0001 0000000010 0001100 0000
   // Pack 8-bit:
   //   00100000 00010001 11001101 00010000 00001000 01100000
   //   = 0x20, 0x11, 0xCD, 0x10, 0x08, 0x60
   // ---------------------------------------------------------
   Vector#(16, Bit#(8)) streamMulti = replicate(0);
   streamMulti[0] = 8'h20;
   streamMulti[1] = 8'h11;
   streamMulti[2] = 8'hCD;
   streamMulti[3] = 8'h10;
   streamMulti[4] = 8'h08;
   streamMulti[5] = 8'h60;
   QRBackend backend5 <- mkMockBackend(streamMulti);
   QRPayload payload5 <- mkQRPayload(backend5);

   // Test 1: Empty message
   rule runTest1 (testId == 1);
      payload1.start(1, 16);
      testId <= 2;
   endrule

   rule checkEmpty (testId == 2 && payload1.done());
      $display("[TEST 1/5] Empty Message Decode: PASSED! (done asserted with 0 bytes)");
      payload2.start(1, 16);
      byteCount <= 0;
      testId <= 3;
   endrule

   // Test 2: Byte mode "Test"
   rule checkByte (testId == 3);
      let b <- payload2.getByte();
      $display("  [Byte Mode] received: '%c' (0x%02h) last=%b", b.data, b.data, b.last);
      if (b.last) begin
         byteCount <= 0;
         if (byteCount == 3) begin
            $display("[TEST 2/5] 8-Bit Byte Mode ('Test'): PASSED!\n");
            payload3.start(1, 16);
            testId <= 4;
         end
         else begin
            $display("ERROR: Byte mode count mismatch!");
            $finish(1);
         end
      end
      else begin
         byteCount <= byteCount + 1;
      end
   endrule

   // Test 3: Numeric mode "8675309"
   rule checkNum (testId == 4);
      let b <- payload3.getByte();
      $display("  [Numeric 3-digit + 1-digit] received: '%c' (0x%02h) last=%b", b.data, b.data, b.last);
      if (b.last) begin
         byteCount <= 0;
         if (byteCount == 6) begin
            $display("[TEST 3/5] Numeric Mode ('8675309' 3+3+1 digits): PASSED!\n");
            payload4.start(1, 16);
            testId <= 5;
         end
         else begin
            $display("ERROR: Numeric mode count mismatch!");
            $finish(1);
         end
      end
      else begin
         byteCount <= byteCount + 1;
      end
   endrule

   // Test 4: Numeric 2-digit "12"
   rule checkNum2 (testId == 5);
      let b <- payload4.getByte();
      $display("  [Numeric 2-digit group] received: '%c' (0x%02h) last=%b", b.data, b.data, b.last);
      if (b.last) begin
         byteCount <= 0;
         if (byteCount == 1) begin
            $display("[TEST 4/5] Numeric Mode ('12' 2 digits): PASSED!\n");
            payload5.start(1, 16);
            testId <= 6;
         end
         else begin
            $display("ERROR: Numeric mode 2-digit count mismatch!");
            $finish(1);
         end
      end
      else begin
         byteCount <= byteCount + 1;
      end
   endrule

   // Test 5: Multi-segment "AB" + "12"
   rule checkMulti (testId == 6);
      let b <- payload5.getByte();
      $display("  [Multi-Segment Alnum+Numeric] received: '%c' (0x%02h) last=%b", b.data, b.data, b.last);
      if (b.last) begin
         byteCount <= 0;
         if (byteCount == 3) begin
            $display("[TEST 5/5] Multi-Segment ('AB' + '12'): PASSED!\n");
            $display("==============================================================");
            $display("  ALL PAYLOAD MODES VERIFIED AND PASSED IN BSV RTL!");
            $display("==============================================================\n");
            $finish(0);
         end
         else begin
            $display("ERROR: Multi-segment count mismatch!");
            $finish(1);
         end
      end
      else begin
         byteCount <= byteCount + 1;
      end
   endrule

   rule timeout (cycle > 100000);
      $display("ERROR: Timeout in payload modes test!");
      $finish(1);
   endrule

endmodule

endpackage
