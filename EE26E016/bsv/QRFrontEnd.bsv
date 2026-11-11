// Package QRFrontEnd: Symbol size validation, format reading & decoding,
// geometric function-module exclusion, 2-column zigzag traversal, and raw codeword packing.
//
// Author: Person A (Frontend RTL)
// Authority: CADForVLSI_2026_Project_Spec.pdf Sections 1.1-1.3, 4.2 (G1, G2), Table 1-2

package QRFrontEnd;

import Vector::*;
import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import GetPut::*;

import QRTypes::*;
import QRTables::*;
import QRInternalTypes::*;

// Frontend State Machine
typedef enum {
   FE_IDLE,
   FE_CHECK_SIZE,
   FE_READ_FMT1,
   FE_READ_FMT2,
   FE_DECODE_FORMAT,
   FE_CHOOSE_FORMAT,
   FE_APPLY_FORMAT,
   FE_CONFIG_BACKEND,
   FE_TRAVERSE,
   FE_DONE,
   FE_FAILED
} FEState deriving (Bits, Eq, FShow);

// Tag for pending memory response
typedef enum {
   TAG_FMT1,
   TAG_FMT2,
   TAG_DATA
} MemReqTag deriving (Bits, Eq, FShow);

interface QRFrontEnd;
   method Action start(Coord size);
   method Action reset();
   method Bool failed();
   method Bool done();
   method BackendConfig getConfig();
   method Bool isConfigValid();
   interface MemPort mem;
endinterface

// =========================================================================
// Pure Helper Functions
// =========================================================================

// Format bit coordinates for Copy 1 (Spec Table 1)
function Tuple2#(Coord, Coord) formatCoord1(UInt#(4) idx);
   Coord r = 0;
   Coord c = 0;
   case (idx)
      0: begin r = 0; c = 8; end
      1: begin r = 1; c = 8; end
      2: begin r = 2; c = 8; end
      3: begin r = 3; c = 8; end
      4: begin r = 4; c = 8; end
      5: begin r = 5; c = 8; end
      6: begin r = 7; c = 8; end
      7: begin r = 8; c = 8; end
      8: begin r = 8; c = 7; end
      9: begin r = 8; c = 5; end
      10: begin r = 8; c = 4; end
      11: begin r = 8; c = 3; end
      12: begin r = 8; c = 2; end
      13: begin r = 8; c = 1; end
      14: begin r = 8; c = 0; end
   endcase
   return tuple2(r, c);
endfunction

// Format bit coordinates for Copy 2 (Spec Table 1)
function Tuple2#(Coord, Coord) formatCoord2(UInt#(4) idx, Coord n);
   Coord r = 0;
   Coord c = 0;
   case (idx)
      0: begin r = 8; c = n - 1; end
      1: begin r = 8; c = n - 2; end
      2: begin r = 8; c = n - 3; end
      3: begin r = 8; c = n - 4; end
      4: begin r = 8; c = n - 5; end
      5: begin r = 8; c = n - 6; end
      6: begin r = 8; c = n - 7; end
      7: begin r = 8; c = n - 8; end
      8: begin r = n - 7; c = 8; end
      9: begin r = n - 6; c = 8; end
      10: begin r = n - 5; c = 8; end
      11: begin r = n - 4; c = 8; end
      12: begin r = n - 3; c = 8; end
      13: begin r = n - 2; c = 8; end
      14: begin r = n - 1; c = 8; end
   endcase
   return tuple2(r, c);
endfunction

// Search a chunk of 4 valid format codewords (BCH 15, 5) with running minimum (R4 high-frequency optimization)
function Tuple2#(UInt#(4), UInt#(5)) search4Format(Bit#(15) word, UInt#(3) chunk, UInt#(4) cur_min, UInt#(5) cur_best);
   UInt#(4) min_dist = cur_min;
   UInt#(5) best_d = cur_best;
   case (chunk)
      0: for (Integer i = 0; i < 4; i = i + 1) begin
            Bit#(15) valid_cw = formatCodeword(i);
            UInt#(4) hd = countOnes(word ^ valid_cw);
            if (hd < min_dist) begin min_dist = hd; best_d = fromInteger(i); end
         end
      1: for (Integer i = 0; i < 4; i = i + 1) begin
            Bit#(15) valid_cw = formatCodeword(4 + i);
            UInt#(4) hd = countOnes(word ^ valid_cw);
            if (hd < min_dist) begin min_dist = hd; best_d = fromInteger(4 + i); end
         end
      2: for (Integer i = 0; i < 4; i = i + 1) begin
            Bit#(15) valid_cw = formatCodeword(8 + i);
            UInt#(4) hd = countOnes(word ^ valid_cw);
            if (hd < min_dist) begin min_dist = hd; best_d = fromInteger(8 + i); end
         end
      3: for (Integer i = 0; i < 4; i = i + 1) begin
            Bit#(15) valid_cw = formatCodeword(12 + i);
            UInt#(4) hd = countOnes(word ^ valid_cw);
            if (hd < min_dist) begin min_dist = hd; best_d = fromInteger(12 + i); end
         end
      4: for (Integer i = 0; i < 4; i = i + 1) begin
            Bit#(15) valid_cw = formatCodeword(16 + i);
            UInt#(4) hd = countOnes(word ^ valid_cw);
            if (hd < min_dist) begin min_dist = hd; best_d = fromInteger(16 + i); end
         end
      5: for (Integer i = 0; i < 4; i = i + 1) begin
            Bit#(15) valid_cw = formatCodeword(20 + i);
            UInt#(4) hd = countOnes(word ^ valid_cw);
            if (hd < min_dist) begin min_dist = hd; best_d = fromInteger(20 + i); end
         end
      6: for (Integer i = 0; i < 4; i = i + 1) begin
            Bit#(15) valid_cw = formatCodeword(24 + i);
            UInt#(4) hd = countOnes(word ^ valid_cw);
            if (hd < min_dist) begin min_dist = hd; best_d = fromInteger(24 + i); end
         end
      7: for (Integer i = 0; i < 4; i = i + 1) begin
            Bit#(15) valid_cw = formatCodeword(28 + i);
            UInt#(4) hd = countOnes(word ^ valid_cw);
            if (hd < min_dist) begin min_dist = hd; best_d = fromInteger(28 + i); end
         end
   endcase
   return tuple2(min_dist, best_d);
endfunction

// Fast constant-reciprocal div and mod 3 functions (zero hardware divider/modulo delay)
function UInt#(8) fastDiv3_8(UInt#(8) x);
   UInt#(16) prod = zeroExtend(x) * 16'd171;
   return truncate(prod >> 9);
endfunction

function UInt#(8) fastMod3_8(UInt#(8) x);
   UInt#(8) q = fastDiv3_8(x);
   return (x - (q << 1) - q);
endfunction

function UInt#(8) fastMod3_16(UInt#(16) x);
   UInt#(32) prod = zeroExtend(x) * 32'd10923;
   UInt#(16) q = truncate(prod >> 15);
   return truncate(x - (q << 1) - q);
endfunction

// Mask pattern condition (Spec Table 2) with fast reciprocal modulo
function Bool maskInverts(MaskPattern mask, Coord r, Coord c);
   UInt#(8) ur = r;
   UInt#(8) uc = c;
   UInt#(9) sumRC = zeroExtend(ur) + zeroExtend(uc);
   UInt#(16) prodRC = zeroExtend(ur) * zeroExtend(uc);

   UInt#(8) mod3Sum  = truncate(sumRC % 3);
   UInt#(8) mod3Prod = fastMod3_16(prodRC);
   UInt#(8) mod2Prod = truncate(prodRC & 1);
   UInt#(8) sumModProd = mod2Prod + mod3Prod;

   Bool inv = False;
   case (mask)
      0: inv = ((sumRC & 1) == 0);
      1: inv = ((ur & 1) == 0);
      2: inv = (fastMod3_8(uc) == 0);
      3: inv = (mod3Sum == 0);
      4: inv = ((((ur >> 1) + fastDiv3_8(uc)) & 1) == 0);
      5: inv = (sumModProd == 0);
      6: inv = ((sumModProd & 1) == 0);
      7: inv = (((truncate(sumRC & 1) + mod3Prod) & 1) == 0);
   endcase
   return inv;
endfunction

// Geometrical function module check (Spec Section 1.1)
function Bool isFunctionModule(Coord r, Coord c, Coord n, UInt#(6) v, AlignParams ap);
   Bool is_func = False;

   // 1. Finder patterns + separators + format strips (three corners)
   if (r <= 8 && c <= 8) is_func = True;
   else if (r <= 8 && c >= n - 8) is_func = True;
   else if (r >= n - 8 && c <= 8) is_func = True;

   // 2. Timing patterns (Row 6 and Column 6)
   else if (r == 6 || c == 6) is_func = True;

   // 3. Version information areas (Version 7 up: two 6x3 rectangles)
   else if (v >= 7 && ((r <= 5 && c >= n - 11 && c <= n - 9) ||
                       (c <= 5 && r >= n - 11 && r <= n - 9))) is_func = True;

   // 4. Alignment patterns (Version 2 up)
   else if (v >= 2) begin
      Maybe#(UInt#(3)) r_match = tagged Invalid;
      Maybe#(UInt#(3)) c_match = tagged Invalid;

      for (Integer i = 0; i < 7; i = i + 1) begin
         if (fromInteger(i) < ap.count) begin
            UInt#(8) pr = ap.pos[i];
            if (r + 2 >= pr && r <= pr + 2)
               r_match = tagged Valid fromInteger(i);
         end
      end

      for (Integer j = 0; j < 7; j = j + 1) begin
         if (fromInteger(j) < ap.count) begin
            UInt#(8) pc = ap.pos[j];
            if (c + 2 >= pc && c <= pc + 2)
               c_match = tagged Valid fromInteger(j);
         end
      end

      if (r_match matches tagged Valid .ri &&& c_match matches tagged Valid .cj) begin
         UInt#(3) last_idx = ap.count - 1;
         Bool is_corner = (ri == 0 && cj == 0) ||
                          (ri == 0 && cj == last_idx) ||
                          (ri == last_idx && cj == 0);
         if (!is_corner) is_func = True;
      end
   end

   return is_func;
endfunction

// =========================================================================
// Module Implementation
// =========================================================================

module mkQRFrontEnd #(QRBackend backend) (QRFrontEnd);

   Reg#(FEState) state       <- mkReg(FE_IDLE);
   Reg#(Coord)   symbolSize  <- mkReg(0);
   Reg#(UInt#(6)) version    <- mkReg(0);

   // Format reading registers
   Reg#(UInt#(4)) fmtGenIdx  <- mkReg(0);
   Reg#(UInt#(4)) fmtRecIdx  <- mkReg(0);
   Reg#(Bit#(15)) fmtWord1   <- mkReg(0);
   Reg#(Bit#(15)) fmtWord2   <- mkReg(0);

   // Shared format evaluation registers (R3/R4 area and timing optimization)
   Reg#(AlignParams)   alignCfg          <- mkReg(?);
   Reg#(Bit#(15))      fmtToDecode       <- mkReg(0);
   Reg#(Bool)          evaluatingCopy2   <- mkReg(False);
   Reg#(UInt#(4))      bestDist1         <- mkReg(15);
   Reg#(UInt#(5))      bestD1            <- mkReg(0);
   Reg#(UInt#(3))      fmtSearchChunk    <- mkReg(0);
   Reg#(UInt#(4))      fmtMinDist        <- mkReg(15);
   Reg#(UInt#(5))      fmtBestD          <- mkReg(0);
   Reg#(UInt#(4))      lastDist          <- mkReg(15);
   Reg#(UInt#(5))      lastD             <- mkReg(0);
   Reg#(UInt#(5))      chosenReg         <- mkReg(0);

   // Decoded configuration
   Reg#(BackendConfig) currentConfig     <- mkReg(?);
   Reg#(BackendConfig) pendingBackendCfg <- mkReg(?);
   Reg#(Bool)          configValid       <- mkReg(False);

   // Zigzag coordinate generator registers
   Reg#(Coord)    rightCol     <- mkReg(0);
   Reg#(Bit#(1))  colOffset    <- mkReg(0);
   Reg#(Coord)    currRow      <- mkReg(0);
   Reg#(Bool)     goingUp      <- mkReg(True);

   // Codeword packing registers
   Reg#(UInt#(3)) bitCount     <- mkReg(0);
   Reg#(Bit#(8))  byteShift    <- mkReg(0);
   Reg#(ByteIdx)  bytesSent    <- mkReg(0);

   // Pipelined memory traversal queues (8-deep unguarded FIFOs)
   // reqQ carries Tag and Coordinate (pure coordinate generation, zero multiplier delay)
   // pendingCoordQ carries Tag, Coordinate, and precalculated maskBit (computed on FIFO deq, zero response delay)
   FIFOF#(Tuple2#(MemReqTag, Tuple2#(Coord, Coord)))          reqQ          <- mkUGSizedFIFOF(8);
   FIFOF#(Tuple3#(MemReqTag, Tuple2#(Coord, Coord), Bit#(1))) pendingCoordQ <- mkUGSizedFIFOF(8);
   FIFOF#(Bit#(1))                                            respBitQ      <- mkUGSizedFIFOF(8);
   FIFOF#(Bit#(8))                                            rawByteQ      <- mkUGSizedFIFOF(8);

   Reg#(UInt#(18)) totalBits     <- mkReg(0);
   Reg#(UInt#(18)) bitsGenerated <- mkReg(0);

   // Advance coordinate along 2-column zigzag path
   function Action advanceZigzag();
      action
         if (colOffset == 0) begin
            colOffset <= 1;
         end
         else begin
            colOffset <= 0;
            if (goingUp) begin
               if (currRow == 0) begin
                  goingUp <= False;
                  Coord nextRight = rightCol - 2;
                  if (nextRight == 6) nextRight = 5;
                  rightCol <= nextRight;
               end
               else begin
                  currRow <= currRow - 1;
               end
            end
            else begin
               if (currRow == symbolSize - 1) begin
                  goingUp <= True;
                  Coord nextRight = rightCol - 2;
                  if (nextRight == 6) nextRight = 5;
                  rightCol <= nextRight;
               end
               else begin
                  currRow <= currRow + 1;
               end
            end
         end
      endaction
   endfunction

   // ----------------------------------------------------------------------
   // Rule: Stream raw bytes to Backend
   // ----------------------------------------------------------------------
   rule streamToBackend ((state == FE_TRAVERSE || state == FE_DONE) && rawByteQ.notEmpty);
      let b = rawByteQ.first();
      rawByteQ.deq();
      backend.putRawByte(b);
   endrule

   // ----------------------------------------------------------------------
   // Rule: Step 1 - Validate Side Length (G1)
   // ----------------------------------------------------------------------
   rule checkSize (state == FE_CHECK_SIZE);
      Coord n = symbolSize;
      if (n >= 21 && n <= 177) begin
         Coord rem = (n - 17) & 3;
         UInt#(8) v_val = (n - 17) >> 2;
         if (rem == 0 && v_val >= 1 && v_val <= 40) begin
            version <= truncate(v_val);
            alignCfg <= alignParams(truncate(v_val));
            fmtGenIdx <= 0;
            fmtRecIdx <= 0;
            fmtWord1 <= 0;
            fmtWord2 <= 0;
            state <= FE_READ_FMT1;
         end
         else begin
            state <= FE_FAILED;
         end
      end
      else begin
         state <= FE_FAILED;
      end
   endrule

   // ----------------------------------------------------------------------
   // Rules: Step 2 & 3 - Format Generation
   // ----------------------------------------------------------------------
   rule genFmt1 (state == FE_READ_FMT1 && fmtGenIdx < 15 && reqQ.notFull);
      match {.r, .c} = formatCoord1(fmtGenIdx);
      reqQ.enq(tuple2(TAG_FMT1, tuple2(r, c)));
      fmtGenIdx <= fmtGenIdx + 1;
   endrule

   rule genFmt2 (state == FE_READ_FMT2 && fmtGenIdx < 15 && reqQ.notFull);
      match {.r, .c} = formatCoord2(fmtGenIdx, symbolSize);
      reqQ.enq(tuple2(TAG_FMT2, tuple2(r, c)));
      fmtGenIdx <= fmtGenIdx + 1;
   endrule

   // ----------------------------------------------------------------------
   // Rules: Format Response Processing
   // ----------------------------------------------------------------------
   (* descending_urgency = "processFmt1Resp, genFmt1" *)
   rule processFmt1Resp (state == FE_READ_FMT1 && respBitQ.notEmpty && pendingCoordQ.notEmpty);
      let b = respBitQ.first(); respBitQ.deq();
      match {.tag, .coord, .mbit} = pendingCoordQ.first(); pendingCoordQ.deq();

      Bit#(15) mask_bit = 15'b1 << fmtRecIdx;
      Bit#(15) new_w1 = (fmtWord1 & ~mask_bit) | ((b == 1'b1) ? mask_bit : 0);
      fmtWord1 <= new_w1;

      if (fmtRecIdx == 14) begin
         fmtGenIdx <= 0;
         fmtRecIdx <= 0;
         state <= FE_READ_FMT2;
      end
      else begin
         fmtRecIdx <= fmtRecIdx + 1;
      end
   endrule

   rule processFmt2Resp (state == FE_READ_FMT2 && respBitQ.notEmpty && pendingCoordQ.notEmpty);
      let b = respBitQ.first(); respBitQ.deq();
      match {.tag, .coord, .mbit} = pendingCoordQ.first(); pendingCoordQ.deq();

      Bit#(15) mask_bit = 15'b1 << fmtRecIdx;
      Bit#(15) new_w2 = (fmtWord2 & ~mask_bit) | ((b == 1'b1) ? mask_bit : 0);
      fmtWord2 <= new_w2;

      if (fmtRecIdx == 14) begin
         fmtToDecode <= fmtWord1;
         evaluatingCopy2 <= False;
         fmtSearchChunk <= 0;
         fmtMinDist <= 15;
         fmtBestD <= 0;
         state <= FE_DECODE_FORMAT;
      end
      else begin
         fmtRecIdx <= fmtRecIdx + 1;
      end
   endrule

   // ----------------------------------------------------------------------
   // Rule: Step 4 - Decode Format Information (Pipelined 8-Step Chunked Evaluator R4)
   // ----------------------------------------------------------------------
   rule decodeFormat (state == FE_DECODE_FORMAT);
      match {.new_min, .new_best} = search4Format(fmtToDecode, fmtSearchChunk, fmtMinDist, fmtBestD);
      fmtMinDist <= new_min;
      fmtBestD <= new_best;

      if (fmtSearchChunk == 7) begin
         lastDist <= new_min;
         lastD <= new_best;
         state <= FE_CHOOSE_FORMAT;
      end
      else begin
         fmtSearchChunk <= fmtSearchChunk + 1;
      end
   endrule

   rule chooseFormat (state == FE_CHOOSE_FORMAT);
      if (!evaluatingCopy2) begin
         if (lastDist == 0) begin
            chosenReg <= lastD;
            state <= FE_APPLY_FORMAT;
         end
         else begin
            bestDist1 <= lastDist;
            bestD1 <= lastD;
            fmtToDecode <= fmtWord2;
            evaluatingCopy2 <= True;
            fmtSearchChunk <= 0;
            fmtMinDist <= 15;
            fmtBestD <= 0;
            state <= FE_DECODE_FORMAT;
         end
      end
      else begin
         Bool fail = False;
         UInt#(5) chosen_d = 0;
         if (bestDist1 <= lastDist) begin
            if (bestDist1 <= 3) chosen_d = bestD1;
            else if (lastDist <= 3) chosen_d = lastD;
            else fail = True;
         end
         else begin
            if (lastDist <= 3) chosen_d = lastD;
            else if (bestDist1 <= 3) chosen_d = bestD1;
            else fail = True;
         end
         if (fail) state <= FE_FAILED;
         else begin
            chosenReg <= chosen_d;
            state <= FE_APPLY_FORMAT;
         end
      end
   endrule

   // Stage 1: Decode format, lookup block parameters, and latch into pending register
   rule applyFormat (state == FE_APPLY_FORMAT);
      Bit#(5) chosen_bits = pack(chosenReg);
      RawLevel level = chosen_bits[4:3];
      MaskPattern mask = unpack(chosen_bits[2:0]);
      BlockParams bp = blockParams(version, level);

      BackendConfig cfg = BackendConfig {
         version: version,
         levelField: level,
         mask: mask,
         params: bp
      };

      pendingBackendCfg <= cfg;
      currentConfig <= cfg;
      state <= FE_CONFIG_BACKEND;
   endrule

   // Stage 2: Configure backend strictly from registered values (zero logic delay into backend/baseN1)
   rule configBackend (state == FE_CONFIG_BACKEND);
      backend.configure(pendingBackendCfg);
      configValid <= True;

      // Initialize zigzag coordinate traversal
      rightCol <= symbolSize - 1;
      colOffset <= 0;
      currRow <= symbolSize - 1;
      goingUp <= True;
      bitCount <= 0;
      byteShift <= 0;
      bytesSent <= 0;

      // Initialize pipelined traversal registers
      totalBits <= zeroExtend(pendingBackendCfg.params.total) << 3;
      bitsGenerated <= 0;
      reqQ.clear();
      pendingCoordQ.clear();
      respBitQ.clear();

      state <= FE_TRAVERSE;
   endrule

   // ----------------------------------------------------------------------
   // Rules: Step 5 - Pipelined Zigzag Traversal, Unmasking, and Packing (R1/R3/R4)
   // ----------------------------------------------------------------------
   rule generateDataCoords (state == FE_TRAVERSE && bitsGenerated < totalBits && reqQ.notFull);
      Coord c = (colOffset == 0) ? rightCol : (rightCol - 1);
      Coord r = currRow;

      if (isFunctionModule(r, c, symbolSize, version, alignCfg)) begin
         advanceZigzag();
      end
      else begin
         reqQ.enq(tuple2(TAG_DATA, tuple2(r, c)));
         advanceZigzag();
         bitsGenerated <= bitsGenerated + 1;
      end
   endrule

   rule processDataResp (state == FE_TRAVERSE && respBitQ.notEmpty && pendingCoordQ.notEmpty && rawByteQ.notFull);
      let b = respBitQ.first(); respBitQ.deq();
      match {.tag, .coord, .mbit} = pendingCoordQ.first(); pendingCoordQ.deq();

      // Invert using pre-calculated mask bit! Zero multiplier/modulo delay!
      Bit#(1) unmasked = b ^ mbit;
      Bit#(8) nextByte = {byteShift[6:0], unmasked};

      if (bitCount == 7) begin
         rawByteQ.enq(nextByte);
         bitCount <= 0;
         byteShift <= 0;
         ByteIdx nextSent = bytesSent + 1;
         bytesSent <= nextSent;

         if (nextSent == currentConfig.params.total) begin
            // All total codewords transferred!
            state <= FE_DONE;
         end
      end
      else begin
         bitCount <= bitCount + 1;
         byteShift <= nextByte;
      end
   endrule

   // Memory tracking wires and registers
   Wire#(Bool) reqSentWire      <- mkDWire(False);
   Reg#(Bool)  reqSentLastCycle <- mkReg(False);

   rule updateReqSent (state != FE_IDLE);
      reqSentLastCycle <= reqSentWire;
   endrule

   // ----------------------------------------------------------------------
   // Public Interface Methods
   // ----------------------------------------------------------------------
   method Action start(Coord size) if (state == FE_IDLE || state == FE_DONE || state == FE_FAILED);
      symbolSize <= size;
      configValid <= False;
      reqSentLastCycle <= False;
      reqQ.clear();
      pendingCoordQ.clear();
      respBitQ.clear();
      rawByteQ.clear();
      state <= FE_CHECK_SIZE;
   endmethod

   method Action reset();
      state <= FE_IDLE;
      configValid <= False;
      reqSentLastCycle <= False;
      reqQ.clear();
      pendingCoordQ.clear();
      respBitQ.clear();
      rawByteQ.clear();
   endmethod

   method Bool failed() = (state == FE_FAILED);
   method Bool done()   = (state == FE_DONE && !rawByteQ.notEmpty);

   method BackendConfig getConfig() if (configValid) = currentConfig;
   method Bool isConfigValid() = configValid;

   interface MemPort mem;
      method ActionValue#(Tuple2#(Coord, Coord)) req() if (reqQ.notEmpty && pendingCoordQ.notFull && state != FE_DONE && state != FE_FAILED);
         reqSentWire <= True;
         match {.tag, .coord} = reqQ.first();
         reqQ.deq();
         Bit#(1) mbit = 0;
         if (tag == TAG_DATA) begin
            match {.r, .c} = coord;
            mbit = maskInverts(currentConfig.mask, r, c) ? 1'b1 : 1'b0;
         end
         pendingCoordQ.enq(tuple3(tag, coord, mbit));
         return coord;
      endmethod

      method Action resp(Bit#(1) b);
         if (reqSentLastCycle) begin
            respBitQ.enq(b);
         end
      endmethod
   endinterface

endmodule

endpackage
