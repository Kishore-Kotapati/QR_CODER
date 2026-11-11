// Package QRPayload: Bit-stream reader, mode and segment parsing,
// and lookahead final-byte output buffering.
//
// Author: Person A (Payload RTL)
// Authority: CADForVLSI_2026_Project_Spec.pdf Section 1.5, Table 4, Section 4.2 (G4)

package QRPayload;

import Vector::*;
import FIFO::*;
import FIFOF::*;
import GetPut::*;

import QRTypes::*;
import QRTables::*;
import QRInternalTypes::*;

typedef enum {
   PL_IDLE,
   PL_PARSE_MODE,
   PL_PARSE_COUNT,
   PL_DECODE_NUMERIC,
   PL_DECODE_ALNUM,
   PL_DECODE_BYTE,
   PL_FINISH_MSG,
   PL_DONE,
   PL_FAILED
} PLState deriving (Bits, Eq, FShow);

interface QRPayload;
   method Action start(UInt#(6) version, ByteIdx totalData);
   method Action reset();
   method ActionValue#(OutByte) getByte();
   method Bool failed();
   method Bool done();
endinterface

// =========================================================================
// Helper Functions
// =========================================================================

function UInt#(5) getCountWidth(Bit#(4) mode, UInt#(6) v);
   UInt#(2) band = (v <= 9) ? 0 : ((v <= 26) ? 1 : 2);
   UInt#(5) w = 0;
   case (mode)
      4'b0001: // Numeric
         case (band)
            0: w = 10;
            1: w = 12;
            2: w = 14;
         endcase
      4'b0010: // Alphanumeric
         case (band)
            0: w = 9;
            1: w = 11;
            2: w = 13;
         endcase
      4'b0100: // Byte
         case (band)
            0: w = 8;
            1: w = 16;
            2: w = 16;
         endcase
      default: w = 0;
   endcase
   return w;
endfunction

function Tuple2#(Bit#(8), Bit#(8)) split2DecDigits(UInt#(7) val);
   UInt#(16) prod = zeroExtend(val) * 16'd205;
   UInt#(4) d1 = truncate(prod >> 11);
   UInt#(4) d2 = truncate(val - zeroExtend(d1) * 7'd10);
   return tuple2(8'h30 + zeroExtend(pack(d1)),
                 8'h30 + zeroExtend(pack(d2)));
endfunction

function Tuple3#(Bit#(8), Bit#(8), Bit#(8)) split3Digits(UInt#(10) v);
   UInt#(16) prod = zeroExtend(v) * 16'd41;
   UInt#(4) d1 = truncate(prod >> 12);
   UInt#(7) rem1 = truncate(v - zeroExtend(d1) * 10'd100);
   match {.d2, .d3} = split2DecDigits(rem1);
   return tuple3(8'h30 + zeroExtend(pack(d1)), d2, d3);
endfunction

function Tuple2#(Bit#(8), Bit#(8)) split2Digits(UInt#(7) v);
   return split2DecDigits(v);
endfunction

function Tuple2#(Bit#(8), Bit#(8)) split2Alnum(UInt#(11) v);
   UInt#(32) prod = zeroExtend(v) * 32'd1457;
   UInt#(6) c1 = truncate(prod >> 16);
   UInt#(6) c2 = truncate(v - zeroExtend(c1) * 11'd45);
   return tuple2(alnumChar(c1), alnumChar(c2));
endfunction

// =========================================================================
// Module Implementation
// =========================================================================

module mkQRPayload#(QRBackend backend) (QRPayload);

   Reg#(PLState) state <- mkReg(PL_IDLE);

   // Configuration
   Reg#(UInt#(6)) symbolVersion <- mkReg(0);
   Reg#(ByteIdx)  totalBytes    <- mkReg(0);
   Reg#(ByteIdx)  bytesPulled   <- mkReg(0);
   Reg#(UInt#(18)) totalBitsLeft  <- mkReg(0);
   Reg#(Bool)      allBytesPulled <- mkReg(False);

   // Method wires to avoid method-rule scheduling conflicts (G0010 elimination)
   RWire#(Tuple2#(UInt#(6), ByteIdx)) startW <- mkRWire;
   PulseWire                          resetW <- mkPulseWire;

   // Bit-stream buffer: up to 32 bits, left-aligned
   Reg#(Bit#(32)) bitBuf   <- mkReg(0);
   Reg#(UInt#(6)) bitCount <- mkReg(0);

   // Current segment parsing registers
   Reg#(Bit#(4))   currMode      <- mkReg(0);
   Reg#(UInt#(16)) currCharCount <- mkReg(0);

   // Sub-counters and staging registers for partial digit and alnum groups
   Reg#(UInt#(2)) numSubIdx   <- mkReg(0);
   Reg#(Bit#(8))  numSubD2    <- mkReg(0);
   Reg#(Bit#(8))  numSubD3    <- mkReg(0);

   Reg#(UInt#(1)) alnumSubIdx <- mkReg(0);
   Reg#(Bit#(8))  alnumSubC2  <- mkReg(0);

   // Internal FIFO of decoded character bytes before lookahead
   FIFOF#(Bit#(8)) charQ <- mkFIFOF;

   // Lookahead register for 'last' flag determination
   Reg#(Maybe#(Bit#(8))) pendingChar  <- mkReg(tagged Invalid);

   // Final output FIFO exposed through getByte()
   FIFOF#(OutByte) outQ <- mkFIFOF;

   // ----------------------------------------------------------------------
   // Bit-Stream Top-Up Rule
   // Pulls bytes from backend whenever bit buffer has space for another byte
   // ----------------------------------------------------------------------
   rule pullByteFromBackend (state != PL_IDLE && state != PL_DONE && state != PL_FAILED &&
                             !allBytesPulled && bitCount <= 24);
      let b <- backend.getCorrectedByte();
      Bit#(32) shiftedIn = zeroExtend(b) << (24 - bitCount);
      bitBuf <= bitBuf | shiftedIn;
      bitCount <= bitCount + 8;
      bytesPulled <= bytesPulled + 1;
      if (bytesPulled + 1 == totalBytes) allBytesPulled <= True;
   endrule

   // Total available bits remaining in the message (registered, zero combinational subtraction delay)
   function UInt#(18) totalBitsRemaining();
      return totalBitsLeft;
   endfunction

   // Helper: peek top n bits
   function Bit#(16) peekBits(UInt#(5) n);
      UInt#(6) shift_amt = 32 - zeroExtend(n);
      return truncate(bitBuf >> shift_amt);
   endfunction

   // Helper: consume n bits
   function Action consumeBits(UInt#(5) n);
      action
         bitBuf <= bitBuf << n;
         bitCount <= bitCount - zeroExtend(n);
         totalBitsLeft <= totalBitsLeft - zeroExtend(n);
      endaction
   endfunction

   // ----------------------------------------------------------------------
   // Lookahead Rule: Manages 'last' byte determination
   // ----------------------------------------------------------------------
   rule pipelineChar;
      let new_ch = charQ.first();
      charQ.deq();

      if (pendingChar matches tagged Valid .prev_ch) begin
         outQ.enq(OutByte { data: prev_ch, last: False });
      end
      pendingChar <= tagged Valid (new_ch);
   endrule

   rule emitFinalByte (state == PL_FINISH_MSG && !charQ.notEmpty);
      if (pendingChar matches tagged Valid .final_ch) begin
         outQ.enq(OutByte { data: final_ch, last: True });
         pendingChar <= tagged Invalid;
      end
      state <= PL_DONE;
   endrule

   // ----------------------------------------------------------------------
   // FSM Step 1: Parse Mode Indicator (4 bits)
   // ----------------------------------------------------------------------
   (* descending_urgency = "pullByteFromBackend, parseMode" *)
   (* descending_urgency = "emitFinalByte, parseMode" *)
   rule parseMode (state == PL_PARSE_MODE);
      if (totalBitsRemaining() < 4) begin
         // Fewer than 4 bits left -> message ends normally
         state <= PL_FINISH_MSG;
      end
      else if (bitCount >= 4 || allBytesPulled) begin
         Bit#(4) mode = truncate(peekBits(4));
         consumeBits(4);

         if (mode == 4'b0000) begin
            // Terminator 0000 -> message ends; rest is padding
            state <= PL_FINISH_MSG;
         end
         else if (mode == 4'b0001 || mode == 4'b0010 || mode == 4'b0100) begin
            currMode <= mode;
            state <= PL_PARSE_COUNT;
         end
         else begin
            // Unknown mode -> G4 failure
            state <= PL_FAILED;
         end
      end
   endrule

   // ----------------------------------------------------------------------
   // FSM Step 2: Parse Character Count Indicator
   // ----------------------------------------------------------------------
   (* descending_urgency = "pullByteFromBackend, parseCount" *)
   (* descending_urgency = "emitFinalByte, parseCount" *)
   rule parseCount (state == PL_PARSE_COUNT);
      UInt#(5) w = getCountWidth(currMode, symbolVersion);
      if (totalBitsRemaining() < zeroExtend(w)) begin
         // Not enough bits left for count field -> malformed payload
         state <= PL_FAILED;
      end
      else if (bitCount >= zeroExtend(w) || allBytesPulled) begin
         Bit#(16) countVal = peekBits(w);
         consumeBits(w);
         currCharCount <= unpack(countVal);

         if (countVal == 0) begin
            // Zero-length segment: return to mode parsing
            state <= PL_PARSE_MODE;
         end
         else if (currMode == 4'b0001) state <= PL_DECODE_NUMERIC;
         else if (currMode == 4'b0010) state <= PL_DECODE_ALNUM;
         else state <= PL_DECODE_BYTE;
      end
   endrule

   // ----------------------------------------------------------------------
   // FSM Step 3A: Decode Numeric Mode
   // ----------------------------------------------------------------------
   (* descending_urgency = "emitFinalByte, drainNumericSubDigits" *)
   rule drainNumericSubDigits (state == PL_DECODE_NUMERIC && numSubIdx > 0 && charQ.notFull);
      if (numSubIdx == 2) begin
         charQ.enq(numSubD2);
         numSubIdx <= 1;
      end
      else if (numSubIdx == 1) begin
         charQ.enq(numSubD3);
         numSubIdx <= 0;
         if (currCharCount == 0) state <= PL_PARSE_MODE;
      end
   endrule

   (* descending_urgency = "pullByteFromBackend, parseNumericGroup" *)
   (* descending_urgency = "emitFinalByte, parseNumericGroup" *)
   rule parseNumericGroup (state == PL_DECODE_NUMERIC && numSubIdx == 0 && charQ.notFull);
      if (currCharCount >= 3) begin
         if (totalBitsRemaining() < 10) begin
            state <= PL_FAILED;
         end
         else if (bitCount >= 10 || allBytesPulled) begin
            UInt#(10) v = unpack(truncate(peekBits(10)));
            consumeBits(10);
            if (v > 999) begin
               state <= PL_FAILED;
            end
            else begin
               match {.d1, .d2, .d3} = split3Digits(v);
               charQ.enq(d1);
               numSubD2 <= d2;
               numSubD3 <= d3;
               numSubIdx <= 2;
               currCharCount <= currCharCount - 3;
            end
         end
      end
      else if (currCharCount == 2) begin
         if (totalBitsRemaining() < 7) begin
            state <= PL_FAILED;
         end
         else if (bitCount >= 7 || allBytesPulled) begin
            UInt#(7) v = unpack(truncate(peekBits(7)));
            consumeBits(7);
            if (v > 99) begin
               state <= PL_FAILED;
            end
            else begin
               match {.d1, .d2} = split2Digits(v);
               charQ.enq(d1);
               numSubD3 <= d2;
               numSubIdx <= 1;
               currCharCount <= 0;
            end
         end
      end
      else if (currCharCount == 1) begin
         if (totalBitsRemaining() < 4) begin
            state <= PL_FAILED;
         end
         else if (bitCount >= 4 || allBytesPulled) begin
            UInt#(4) v = unpack(truncate(peekBits(4)));
            consumeBits(4);
            if (v > 9) begin
               state <= PL_FAILED;
            end
            else begin
               charQ.enq(8'h30 + zeroExtend(pack(v)));
               currCharCount <= 0;
               state <= PL_PARSE_MODE;
            end
         end
      end
      else begin
         state <= PL_PARSE_MODE;
      end
   endrule

   // ----------------------------------------------------------------------
   // FSM Step 3B: Decode Alphanumeric Mode
   // ----------------------------------------------------------------------
   (* descending_urgency = "emitFinalByte, drainAlnumSubChar" *)
   rule drainAlnumSubChar (state == PL_DECODE_ALNUM && alnumSubIdx > 0 && charQ.notFull);
      charQ.enq(alnumSubC2);
      alnumSubIdx <= 0;
      if (currCharCount == 0) state <= PL_PARSE_MODE;
   endrule

   (* descending_urgency = "pullByteFromBackend, parseAlnumGroup" *)
   (* descending_urgency = "emitFinalByte, parseAlnumGroup" *)
   rule parseAlnumGroup (state == PL_DECODE_ALNUM && alnumSubIdx == 0 && charQ.notFull);
      if (currCharCount >= 2) begin
         if (totalBitsRemaining() < 11) begin
            state <= PL_FAILED;
         end
         else if (bitCount >= 11 || allBytesPulled) begin
            UInt#(11) v = unpack(truncate(peekBits(11)));
            consumeBits(11);
            if (v > 2024) begin
               state <= PL_FAILED;
            end
            else begin
               match {.c1, .c2} = split2Alnum(v);
               charQ.enq(c1);
               alnumSubC2 <= c2;
               alnumSubIdx <= 1;
               currCharCount <= currCharCount - 2;
            end
         end
      end
      else if (currCharCount == 1) begin
         if (totalBitsRemaining() < 6) begin
            state <= PL_FAILED;
         end
         else if (bitCount >= 6 || allBytesPulled) begin
            UInt#(6) v = unpack(truncate(peekBits(6)));
            consumeBits(6);
            if (v > 44) begin
               state <= PL_FAILED;
            end
            else begin
               charQ.enq(alnumChar(v));
               currCharCount <= 0;
               state <= PL_PARSE_MODE;
            end
         end
      end
      else begin
         state <= PL_PARSE_MODE;
      end
   endrule

   // ----------------------------------------------------------------------
   // FSM Step 3C: Decode Byte Mode
   // ----------------------------------------------------------------------
   (* descending_urgency = "pullByteFromBackend, parseByteMode" *)
   (* descending_urgency = "emitFinalByte, parseByteMode" *)
   rule parseByteMode (state == PL_DECODE_BYTE && charQ.notFull);
      if (currCharCount > 0) begin
         if (totalBitsRemaining() < 8) begin
            state <= PL_FAILED;
         end
         else if (bitCount >= 8 || allBytesPulled) begin
            Bit#(8) b = truncate(peekBits(8));
            consumeBits(8);
            charQ.enq(b);
            UInt#(16) nextLeft = currCharCount - 1;
            currCharCount <= nextLeft;
            if (nextLeft == 0) state <= PL_PARSE_MODE;
         end
      end
      else begin
         state <= PL_PARSE_MODE;
      end
   endrule

   (* descending_urgency = "doReset, doStart, emitFinalByte" *)
   rule doReset (resetW);
      state <= PL_IDLE;
      bytesPulled <= 0;
      bitBuf <= 0;
      bitCount <= 0;
      numSubIdx <= 0;
      alnumSubIdx <= 0;
      charQ.clear();
      outQ.clear();
      pendingChar <= tagged Invalid;
      totalBitsLeft <= 0;
      allBytesPulled <= False;
   endrule

   rule doStart (startW.wget matches tagged Valid {.ver, .totData});
      symbolVersion <= ver;
      totalBytes <= totData;
      bytesPulled <= 0;
      bitBuf <= 0;
      bitCount <= 0;
      currMode <= 0;
      currCharCount <= 0;
      numSubIdx <= 0;
      alnumSubIdx <= 0;
      charQ.clear();
      outQ.clear();
      pendingChar <= tagged Invalid;
      totalBitsLeft <= zeroExtend(totData) << 3;
      allBytesPulled <= (totData == 0);
      state <= PL_PARSE_MODE;
   endrule

   // ----------------------------------------------------------------------
   // Public Interface Methods
   // ----------------------------------------------------------------------
   method Action start(UInt#(6) version, ByteIdx totalData) if (state == PL_IDLE || state == PL_DONE || state == PL_FAILED);
      startW.wset(tuple2(version, totalData));
   endmethod

   method Action reset();
      resetW.send();
   endmethod

   method ActionValue#(OutByte) getByte();
      let b = outQ.first();
      outQ.deq();
      return b;
   endmethod

   method Bool failed() = (state == PL_FAILED);
   method Bool done()   = (state == PL_DONE && !outQ.notEmpty);

endmodule

endpackage
