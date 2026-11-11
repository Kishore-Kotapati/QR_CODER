// Default build = the fast (R4) backend that was synthesised and placed. -D QR_NO_FAST gives the old Day 8 version.
`ifndef QR_NO_FAST
`ifndef QR_FAST
`define QR_FAST
`endif
`endif
// QRRS.bsv -- Reed-Solomon decoding for one QR block (Person B, RTL).
//
// Part 1 (Day 5): the SYNDROME UNIT.
// Part 2 (Day 6): BERLEKAMP-MASSEY (mkBMUnit), further down.
// Part 3 (Day 7): CHIEN SEARCH + FORNEY (mkChienForney), at the end.
// R2 redesign: mkBMUnit2 = the same Berlekamp-Massey in 2 clocks per step
// (shorter critical path).  mkBM picks the version: compile with
// "-D QR_R2_BM" for mkBMUnit2, otherwise the original mkBMUnit (R0).
// R4 redesign: mkBMUnit3 = mkBMUnit2 without its own copy of the 30
// syndromes; it reads them from the syndrome unit.  "-D QR_R4_BM".
//
// Conventions (see docs/RS_CONVENTIONS.md):
//   * A block of n bytes r[0], r[1], ..., r[n-1] is the polynomial
//        R(x) = r[0]*x^(n-1) + r[1]*x^(n-2) + ... + r[n-1]
//     so the FIRST byte is the HIGHEST power of x.
//   * A block with e check bytes is correct when R(alpha^j) = 0 for
//     j = 0, 1, ..., e-1   (first root alpha^0 = 1, "fcr = 0").
//   * Syndrome S_j = R(alpha^j).  All S_j = 0  <=>  no error found.
//
// How it is computed (Horner's rule, one byte per clock):
//   start:      S_j = 0                       for all j
//   each byte:  S_j = S_j * alpha^j  XOR  b   for all j, at the same time
// After the n-th byte, S_j = R(alpha^j).
// "* alpha^j" is a CONSTANT multiply, so it is only a small XOR network
// (gfMulAlphaPow from QRGF.bsv).  30 of them work in parallel.
package QRRS;

import Vector  :: *;
import QRGF    :: *;
import QRTables :: *;     // alphaInvPow (supplied table)

typedef 30 MaxEc;                        // QR never uses more than 30 check bytes
typedef Vector#(MaxEc, Bit#(8)) Syndromes;

interface SyndromeUnit;
   // Begin a new block that has `ecLen` check bytes (7..30).  Clears S.
   method Action start(UInt#(5) ecLen);
   // Next byte of the block, first byte first (highest power of x first).
   method Action put(Bit#(8) b);
   // S_0 .. S_29.  Entries j >= ecLen are always 0 (they are not used).
   method Syndromes syndromes;
   // True when every used syndrome is 0 = "no error in this block".
   method Bool allZero;
endinterface

(* synthesize *)
module mkSyndromeUnit (SyndromeUnit);
   Vector#(MaxEc, Reg#(Bit#(8))) s <- replicateM(mkReg(0));
   Reg#(UInt#(5)) ec <- mkReg(0);

   // The two action methods only leave a note on a wire; ONE rule then
   // updates the registers.  If start and put come in the same cycle,
   // start wins (the byte is dropped) -- the user must not do that.
   PulseWire       clearW <- mkPulseWire;
   RWire#(Bit#(8)) byteW  <- mkRWire;

   (* fire_when_enabled, no_implicit_conditions *)
   rule update (clearW || isValid(byteW.wget));
      Bit#(8) b = fromMaybe(0, byteW.wget);
      for (Integer j = 0; j < valueOf(MaxEc); j = j + 1)
         s[j] <= clearW ? 0 : (gfMulAlphaPow(s[j], j) ^ b);
   endrule

   // Only the first ecLen syndromes matter; the others are shown as 0.
   function Syndromes used();
      Syndromes v = replicate(0);
      for (Integer j = 0; j < valueOf(MaxEc); j = j + 1)
         if (fromInteger(j) < ec) v[j] = s[j];
      return v;
   endfunction

   method Action start(UInt#(5) ecLen);
      ec <= ecLen;
      clearW.send;
   endmethod

   method Action put(Bit#(8) b);
      byteW.wset(b);
   endmethod

   method Syndromes syndromes = used;

   method Bool allZero;
      Bool z = True;
      Syndromes v = used;
      for (Integer j = 0; j < valueOf(MaxEc); j = j + 1)
         if (v[j] != 0) z = False;
      return z;
   endmethod
endmodule

// ===========================================================================
// Part 2 (Day 6): BERLEKAMP-MASSEY
//
// Input : the syndromes S_0..S_(e-1) of one block (e = ecLen check bytes).
// Output: the error-locator polynomial
//            Lambda(x) = 1 + L_1 x + ... + L_L x^L
//         and L = how many errors it found.
// Rule  : RS can fix at most t = e/2 errors.  If L ever gets bigger than t,
//         the block is NOT fixable -> fail (and we stop early: L never drops).
//
// One step per clock, e steps in total (step r = 0 .. e-1):
//   d = S_r + L_1 S_(r-1) + ... + L_L S_(r-L)      ("discrepancy": how wrong
//                                                    the current guess is)
//   d == 0        -> guess is fine; only shift B.
//   d != 0        -> fix the guess:  C = C + (d/b) * B'
//        and if 2L <= r, the guess must grow: L = r+1-L, B' = x*oldC, b = d.
//   B' is kept already multiplied by x^m, so it only ever shifts by one.
// Because L <= t <= 15 whenever we do not fail, 16 coefficients are enough.
// ===========================================================================
typedef 16 LamLen;                              // Lambda_0 .. Lambda_15
typedef Vector#(LamLen, Bit#(8)) Lambda;

interface BMUnit;
   // Start on one block.  Ready when not busy.
   method Action start(Syndromes s, UInt#(5) ecLen);
   method Bool     done;        // True when the result below is valid
   method Lambda   lambda;      // Lambda_0 .. Lambda_15 (Lambda_0 = 1)
   method UInt#(5) errCount;    // L (only meaningful when fail is False)
   method Bool     fail;        // True = more than t errors (block not fixable)
endinterface

typedef enum { BmIdle, BmRun, BmDone } BmState deriving (Bits, Eq, FShow);

// Shift a polynomial up by one power: multiply by x (top coefficient drops).
function Lambda timesX(Lambda p) = shiftInAt0(p, 0);

(* synthesize *)
module mkBMUnit (BMUnit);
   Reg#(BmState)  state <- mkReg(BmIdle);
   Reg#(Lambda)   c     <- mkReg(?);           // current guess Lambda(x)
   Reg#(Lambda)   bx    <- mkReg(?);           // B' = x^m * B(x)
   Reg#(Lambda)   w     <- mkReg(?);           // window: w[i] = S_(r-i)
   Reg#(Syndromes) sq   <- mkReg(?);           // syndromes still to use (sq[0] next)
   Reg#(Bit#(8))  b     <- mkReg(1);           // discrepancy at the last growth
   Reg#(UInt#(6)) l     <- mkReg(0);           // current L
   Reg#(UInt#(5)) r     <- mkReg(0);           // step number
   Reg#(UInt#(5)) ec    <- mkReg(0);
   Reg#(Bool)     failR <- mkReg(False);

   rule step (state == BmRun);
      Lambda wn = shiftInAt0(w, sq[0]);         // window now holds S_r .. S_(r-15)
      // discrepancy d = sum of c[i] * S_(r-i)
      Bit#(8) d = 0;
      for (Integer i = 0; i < valueOf(LamLen); i = i + 1)
         d = d ^ gfMul(c[i], wn[i]);
      w  <= wn;
      sq <= shiftInAtN(sq, 0);

      UInt#(6) rr = zeroExtend(r);
      UInt#(6) t  = zeroExtend(ec) >> 1;
      UInt#(6) lNew = l;
      if (d == 0)
         bx <= timesX(bx);
      else begin
         Bit#(8) scale = gfMul(d, gfInverse(b));    // d / b
         Lambda cn = c;
         for (Integer i = 0; i < valueOf(LamLen); i = i + 1)
            cn[i] = c[i] ^ gfMul(scale, bx[i]);
         c <= cn;
         if (2 * l <= rr) begin                 // the guess must grow
            lNew = rr + 1 - l;
            l  <= lNew;
            bx <= timesX(c);                    // old guess, times x
            b  <= d;
         end
         else
            bx <= timesX(bx);
      end
      Bool tooMany = lNew > t;
      if (tooMany) failR <= True;
      if (tooMany || r + 1 == ec) state <= BmDone;
      r <= r + 1;
   endrule

   method Action start(Syndromes s, UInt#(5) ecLen) if (state != BmRun);
      Lambda one = replicate(0);  one[0] = 1;
      c  <= one;
      bx <= timesX(one);                         // B = 1, m = 1  ->  B' = x
      w  <= replicate(0);
      sq <= s;
      b  <= 1;
      l  <= 0;
      r  <= 0;
      ec <= ecLen;
      failR <= False;
      state <= BmRun;
   endmethod

   method Bool     done     = (state == BmDone);
   method Lambda   lambda   = c;
   method UInt#(5) errCount = truncate(l);
   method Bool     fail     = failR;
endmodule

// ===========================================================================
// R2 redesign: BERLEKAMP-MASSEY, 2 clocks per step  (mkBMUnit2)
//
// R0 (mkBMUnit) did one whole step per clock:
//    discrepancy (16 multipliers + XOR tree) -> inverse table -> d/b
//    -> 16 multipliers -> XOR -> new Lambda
// DC: 1.04 ns, slack -0.07 ns at a 1.0 ns clock.
// Here the step is cut in two, with a register in the middle:
//   clock A: d = discrepancy           and  binv = 1/b  (side by side)
//   clock B: scale = d * binv,  Lambda = Lambda + scale * B',  L / B' / b update
// Same results bit for bit (same tests); at most 2*30+1 clocks per block.
// ===========================================================================
typedef enum { Bm2Idle, Bm2A, Bm2B, Bm2Done } Bm2State deriving (Bits, Eq, FShow);

(* synthesize *)
module mkBMUnit2 (BMUnit);
   Reg#(Bm2State) state <- mkReg(Bm2Idle);
   Reg#(Lambda)   c     <- mkReg(?);
   Reg#(Lambda)   bx    <- mkReg(?);
   Reg#(Lambda)   w     <- mkReg(?);
   Reg#(Syndromes) sq   <- mkReg(?);
   Reg#(Bit#(8))  b     <- mkReg(1);
   Reg#(UInt#(6)) l     <- mkReg(0);
   Reg#(UInt#(5)) r     <- mkReg(0);
   Reg#(UInt#(5)) ec    <- mkReg(0);
   Reg#(Bool)     failR <- mkReg(False);
   Reg#(Bit#(8))  dR    <- mkReg(0);           // NEW: discrepancy, between A and B
   Reg#(Bit#(8))  binvR <- mkReg(1);           // NEW: 1/b, made in A next to d

   // clock A: discrepancy, and the inverse of b at the same time
   rule stepA (state == Bm2A);
      Lambda wn = shiftInAt0(w, sq[0]);
      Bit#(8) d = 0;
      for (Integer i = 0; i < valueOf(LamLen); i = i + 1)
         d = d ^ gfMul(c[i], wn[i]);
      w     <= wn;
      sq    <= shiftInAtN(sq, 0);
      dR    <= d;
      binvR <= gfInverse(b);
      state <= Bm2B;
   endrule

   // clock B: the update (same as mkBMUnit, using the registered d and 1/b)
   rule stepB (state == Bm2B);
      UInt#(6) rr = zeroExtend(r);
      UInt#(6) t  = zeroExtend(ec) >> 1;
      UInt#(6) lNew = l;
      if (dR == 0)
         bx <= timesX(bx);
      else begin
         Bit#(8) scale = gfMul(dR, binvR);       // d / b
         Lambda cn = c;
         for (Integer i = 0; i < valueOf(LamLen); i = i + 1)
            cn[i] = c[i] ^ gfMul(scale, bx[i]);
         c <= cn;
         if (2 * l <= rr) begin
            lNew = rr + 1 - l;
            l  <= lNew;
            bx <= timesX(c);
            b  <= dR;
         end
         else
            bx <= timesX(bx);
      end
      Bool tooMany = lNew > t;
      if (tooMany) failR <= True;
      state <= (tooMany || r + 1 == ec) ? Bm2Done : Bm2A;
      r <= r + 1;
   endrule

   method Action start(Syndromes s, UInt#(5) ecLen) if (state != Bm2A && state != Bm2B);
      Lambda one = replicate(0);  one[0] = 1;
      c  <= one;
      bx <= timesX(one);
      w  <= replicate(0);
      sq <= s;
      b  <= 1;
      l  <= 0;
      r  <= 0;
      ec <= ecLen;
      failR <= False;
      state <= Bm2A;
   endmethod

   method Bool     done     = (state == Bm2Done);
   method Lambda   lambda   = c;
   method UInt#(5) errCount = truncate(l);
   method Bool     fail     = failR;
endmodule

// ===========================================================================
// R4 redesign: BERLEKAMP-MASSEY without its own syndrome copy  (mkBMUnit3)
//
// mkBMUnit / mkBMUnit2 copy all 30 syndromes into a 240-flip-flop shift
// register (sq) at start.  But the syndrome unit keeps the same syndromes
// unchanged until the next block starts, so BM can simply READ them there.
// mkBMUnit3 = mkBMUnit2 (2 clocks per step, R2) with:
//   * sq removed (-240 flip-flops),
//   * syndromesIn: an always-enabled input (a plain input port in Verilog)
//     carrying the syndrome unit's output every clock,
//   * sNext: ONE 8-bit register that fetches the next S_r during clock B,
//     so the 30-to-1 selector is NOT on the clock-A path (timing kept).
// Rule for the user: the syndromes must not change while BM runs (true in
// QRBlocks, TbBM and TbRS: the syndrome unit restarts only for the next block).
// ===========================================================================
interface BMUnit3;
   interface BMUnit bm;
   (* always_ready, always_enabled *)
   method Action syndromesIn(Syndromes s);     // must be driven every clock
endinterface

(* synthesize *)
module mkBMUnit3 (BMUnit3);
   Wire#(Syndromes) sIn <- mkBypassWire;         // this clock's syndromes
   Reg#(Bm2State) state <- mkReg(Bm2Idle);
   Reg#(Lambda)   c     <- mkReg(?);
   Reg#(Lambda)   bx    <- mkReg(?);
   Reg#(Lambda)   w     <- mkReg(?);
   Reg#(Bit#(8))  sNext <- mkReg(0);           // NEW: S_r for the next clock A
   Reg#(Bit#(8))  b     <- mkReg(1);
   Reg#(UInt#(6)) l     <- mkReg(0);
   Reg#(UInt#(5)) r     <- mkReg(0);
   Reg#(UInt#(5)) ec    <- mkReg(0);
   Reg#(Bool)     failR <- mkReg(False);
   Reg#(Bit#(8))  dR    <- mkReg(0);
   Reg#(Bit#(8))  binvR <- mkReg(1);

   rule stepA (state == Bm2A);
      Lambda wn = shiftInAt0(w, sNext);
      Bit#(8) d = 0;
      for (Integer i = 0; i < valueOf(LamLen); i = i + 1)
         d = d ^ gfMul(c[i], wn[i]);
      w     <= wn;
      dR    <= d;
      binvR <= gfInverse(b);
      state <= Bm2B;
   endrule

   rule stepB (state == Bm2B);
      UInt#(6) rr = zeroExtend(r);
      UInt#(6) t  = zeroExtend(ec) >> 1;
      UInt#(6) lNew = l;
      if (dR == 0)
         bx <= timesX(bx);
      else begin
         Bit#(8) scale = gfMul(dR, binvR);
         Lambda cn = c;
         for (Integer i = 0; i < valueOf(LamLen); i = i + 1)
            cn[i] = c[i] ^ gfMul(scale, bx[i]);
         c <= cn;
         if (2 * l <= rr) begin
            lNew = rr + 1 - l;
            l  <= lNew;
            bx <= timesX(c);
            b  <= dR;
         end
         else
            bx <= timesX(bx);
      end
      // fetch S_(r+1) for the next clock A (off the critical path)
      UInt#(6) nx = rr + 1;
      sNext <= (nx < 30) ? sIn[nx] : 0;
      Bool tooMany = lNew > t;
      if (tooMany) failR <= True;
      state <= (tooMany || r + 1 == ec) ? Bm2Done : Bm2A;
      r <= r + 1;
   endrule

   method Action syndromesIn(Syndromes s);
      sIn <= s;
   endmethod

   interface BMUnit bm;
   // s is not stored: the same values are read from sIn while BM runs.
   method Action start(Syndromes s, UInt#(5) ecLen) if (state != Bm2A && state != Bm2B);
      Lambda one = replicate(0);  one[0] = 1;
      c  <= one;
      bx <= timesX(one);
      w  <= replicate(0);
      sNext <= sIn[0];
      b  <= 1;
      l  <= 0;
      r  <= 0;
      ec <= ecLen;
      failR <= False;
      state <= Bm2A;
   endmethod

   method Bool     done     = (state == Bm2Done);
   method Lambda   lambda   = c;
   method UInt#(5) errCount = truncate(l);
   method Bool     fail     = failR;
   endinterface
endmodule

// ===========================================================================
// R4 fast (-D QR_FAST): BERLEKAMP-MASSEY in 4 clocks per step  (mkBMUnit4)
//
// The 1.5 ns trial showed mkBMUnit3 at 1.84 ns (c -> 16 multipliers -> XOR
// tree -> dR), and clock B has 2 multipliers in a row (d*binv, then *B').
// mkBMUnit4 = mkBMUnit3 with every step cut into 4 short clocks:
//   A1: the 16 products c[i]*S_(r-i) into registers, and 1/b (table)
//   A2: XOR of the 16 products = discrepancy d
//   B1: scale = d / b  (one multiplier)
//   B2: Lambda = Lambda + scale * B' (one multiplier per term), L / B' / b update
// Same results bit for bit; at most 4*30+1 clocks per block.
// ===========================================================================
typedef enum { Bm4Idle, Bm4A1, Bm4A2, Bm4B1, Bm4B2, Bm4Done } Bm4State deriving (Bits, Eq, FShow);

(* synthesize *)
module mkBMUnit4 (BMUnit3);
   Wire#(Syndromes) sIn <- mkBypassWire;
   Reg#(Bm4State) state <- mkReg(Bm4Idle);
   Reg#(Lambda)   c     <- mkReg(?);
   Reg#(Lambda)   bx    <- mkReg(?);
   Reg#(Lambda)   w     <- mkReg(?);
   Reg#(Lambda)   prodR <- mkReg(?);           // NEW: the 16 products of clock A1
   Reg#(Bit#(8))  sNext <- mkReg(0);
   Reg#(Bit#(8))  b     <- mkReg(1);
   Reg#(UInt#(6)) l     <- mkReg(0);
   Reg#(UInt#(5)) r     <- mkReg(0);
   Reg#(UInt#(5)) ec    <- mkReg(0);
   Reg#(Bool)     failR <- mkReg(False);
   Reg#(Bit#(8))  dR    <- mkReg(0);
   Reg#(Bit#(8))  binvR <- mkReg(1);
   Reg#(Bit#(8))  scaleR <- mkReg(0);          // NEW: d / b, made in clock B1

   rule stepA1 (state == Bm4A1);
      Lambda wn = shiftInAt0(w, sNext);
      Lambda p  = replicate(0);
      for (Integer i = 0; i < valueOf(LamLen); i = i + 1)
         p[i] = gfMul(c[i], wn[i]);
      w     <= wn;
      prodR <= p;
      binvR <= gfInverse(b);
      state <= Bm4A2;
   endrule

   rule stepA2 (state == Bm4A2);
      Bit#(8) d = 0;
      for (Integer i = 0; i < valueOf(LamLen); i = i + 1)
         d = d ^ prodR[i];
      dR    <= d;
      state <= Bm4B1;
   endrule

   rule stepB1 (state == Bm4B1);
      scaleR <= gfMul(dR, binvR);
      state  <= Bm4B2;
   endrule

   rule stepB2 (state == Bm4B2);
      UInt#(6) rr = zeroExtend(r);
      UInt#(6) t  = zeroExtend(ec) >> 1;
      UInt#(6) lNew = l;
      if (dR == 0)
         bx <= timesX(bx);
      else begin
         Lambda cn = c;
         for (Integer i = 0; i < valueOf(LamLen); i = i + 1)
            cn[i] = c[i] ^ gfMul(scaleR, bx[i]);
         c <= cn;
         if (2 * l <= rr) begin
            lNew = rr + 1 - l;
            l  <= lNew;
            bx <= timesX(c);
            b  <= dR;
         end
         else
            bx <= timesX(bx);
      end
      UInt#(6) nx = rr + 1;
      sNext <= (nx < 30) ? sIn[nx] : 0;
      Bool tooMany = lNew > t;
      if (tooMany) failR <= True;
      state <= (tooMany || r + 1 == ec) ? Bm4Done : Bm4A1;
      r <= r + 1;
   endrule

   method Action syndromesIn(Syndromes s);
      sIn <= s;
   endmethod

   interface BMUnit bm;
   method Action start(Syndromes s, UInt#(5) ecLen)
         if (state == Bm4Idle || state == Bm4Done);
      Lambda one = replicate(0);  one[0] = 1;
      c  <= one;
      bx <= timesX(one);
      w  <= replicate(0);
      sNext <= sIn[0];
      b  <= 1;
      l  <= 0;
      r  <= 0;
      ec <= ecLen;
      failR <= False;
      state <= Bm4A1;
   endmethod

   method Bool     done     = (state == Bm4Done);
   method Lambda   lambda   = c;
   method UInt#(5) errCount = truncate(l);
   method Bool     fail     = failR;
   endinterface
endmodule

// Which BM the decoder uses, chosen when compiling:
//   no flag -> mkBMUnit (R0)   -D QR_R2_BM -> mkBMUnit2 (R2)   -D QR_R4_BM -> mkBMUnit3 (R4)
//   -D QR_FAST -> mkBMUnit4 (R4 fast, 4 clocks per step)
// s = the syndrome unit's output (only mkBMUnit3 reads it continuously).
module mkBM#(Syndromes s) (BMUnit);
`ifdef QR_FAST
   BMUnit3 m3 <- mkBMUnit4;                       // R4 fast: 4 clocks per step
   (* fire_when_enabled, no_implicit_conditions *)
   rule feedSyndromes;
      m3.syndromesIn(s);
   endrule
   BMUnit m = m3.bm;
`else
`ifdef QR_R4_BM
   BMUnit3 m3 <- mkBMUnit3;
   (* fire_when_enabled, no_implicit_conditions *)
   rule feedSyndromes;                 // every clock: syndrome unit -> BM
      m3.syndromesIn(s);
   endrule
   BMUnit m = m3.bm;
`else
`ifdef QR_R2_BM
   BMUnit m <- mkBMUnit2;
`else
   BMUnit m <- mkBMUnit;
`endif
`endif
`endif
   return m;
endmodule

// ===========================================================================
// Part 3 (Day 7): CHIEN SEARCH + FORNEY
//
// Chien:  try every byte of the block.  Byte at degree d is wrong exactly
//         when Lambda(alpha^-d) = 0.   (degree d = n-1-k for byte index k)
// Forney: size of that error (fcr = 0, the extra X cancels):
//            E = Omega(alpha^-d) / (sum of the ODD terms of Lambda at alpha^-d)
//         Omega(x) = S(x) * Lambda(x)  mod x^ecLen   ("error evaluator").
// Safety: the block FAILS (no change at all) when
//         * fewer than L roots are found inside the block (roots outside the
//           block, or Lambda does not split) -- this is the check that catches
//           most "too many errors" blocks that BM let through, or
//         * the odd-term sum is 0 at a root (repeated root).
//
// Timing: 16 clocks to build Omega (one coefficient per clock), then one
// byte position per clock, stopping as soon as L roots are found.
// ===========================================================================
typedef 15 MaxFix;                               // at most t = 15 fixes
typedef Tuple2#(UInt#(8), Bit#(8)) Fix;          // (byte index k, XOR value E)

interface ChienForney;
   // lam/l from BM (only when BM did not fail), s from the syndrome unit,
   // n = block length in bytes (<= 153 in QR).
   method Action start(Lambda lam, UInt#(5) l, Syndromes s, UInt#(5) ecLen, UInt#(8) n);
   method Bool     done;
   method Bool     fail;                          // block cannot be fixed
   method UInt#(5) fixCount;                      // = L when not failed
   method Vector#(MaxFix, Fix) fixes;             // first fixCount entries used
endinterface

`ifdef QR_FAST
// ===========================================================================
// R4 fast (-D QR_FAST): CHIEN SEARCH + FORNEY with short clocks
//
// The 1.5 ns trial showed 1.97 ns for s16 -> 16 multipliers -> XOR tree -> h
// (building Omega), and the search step had inverse table + multiplier in a row.
// This version:
//   Omega : 2 clocks per coefficient (16 products into registers, then XOR)
//   Search: one degree per clock; a root only RECORDS (k, Omega value, odd sum)
//   Mag   : afterwards, 2 clocks per error: 1/odd (table), then Omega*(1/odd)
// Same results bit for bit (same fail rules).
// ===========================================================================
typedef enum { CfIdle, CfOmegaP, CfOmegaS, CfSearch, CfMag, CfDone } CfState deriving (Bits, Eq, FShow);

(* synthesize *)
module mkChienForney (ChienForney);
   Reg#(CfState)  state <- mkReg(CfIdle);
   Reg#(Lambda)   lam   <- mkReg(?);
   Reg#(Lambda)   lq    <- mkReg(?);
   Reg#(Lambda)   lsh   <- mkReg(?);
   Reg#(Lambda)   s16   <- mkReg(?);
   Reg#(Lambda)   prodR <- mkReg(?);    // NEW: S_j * Lambda_(i-j) products
   Reg#(Lambda)   g     <- mkReg(?);
   Reg#(Lambda)   h     <- mkReg(?);
   Reg#(UInt#(5)) i     <- mkReg(0);
   Reg#(UInt#(8)) d     <- mkReg(0);
   Reg#(UInt#(8)) nLen  <- mkReg(0);
   Reg#(UInt#(5)) lReg  <- mkReg(0);
   Reg#(UInt#(5)) ec    <- mkReg(0);
   Reg#(UInt#(5)) cnt   <- mkReg(0);
   Reg#(Vector#(MaxFix, Fix)) fx <- mkReg(?);       // (k, Omega value) -> (k, E)
   Reg#(Vector#(MaxFix, Bit#(8))) oddV <- mkReg(?); // NEW: odd sum at each root
   Reg#(UInt#(5)) mi    <- mkReg(0);    // NEW: Mag phase: which error
   Reg#(UInt#(2)) mph   <- mkReg(0);      // R4F+: Mag phase 0: select, 1: 1/odd, 2: multiply
   Reg#(Bit#(8))  oddR  <- mkReg(0);      // R4F+: odd sum of error mi (own register: mux apart from the inverse)
   Reg#(Bit#(8))  invR  <- mkReg(0);
   Reg#(Bit#(8))  omR   <- mkReg(0);
   Reg#(Bool)     failR <- mkReg(False);

   rule omegaProd (state == CfOmegaP);
      Lambda p = replicate(0);
      for (Integer j = 0; j < valueOf(LamLen); j = j + 1)
         p[j] = gfMul(s16[j], lsh[j]);
      prodR <= p;
      state <= CfOmegaS;
   endrule

   rule omegaSum (state == CfOmegaS);
      Bit#(8) v = 0;
      for (Integer j = 0; j < valueOf(LamLen); j = j + 1)
         v = v ^ prodR[j];
      Lambda hn = h;
      hn[i] = (i < ec) ? v : 0;
      h   <= hn;
      lsh <= shiftInAt0(lsh, lq[0]);
      lq  <= shiftInAtN(lq, 0);
      if (i == 15) begin
         g     <= lam;
         d     <= 0;
         state <= CfSearch;
      end
      else state <= CfOmegaP;
      i <= i + 1;
   endrule

   rule search (state == CfSearch);
      Bit#(8) lamVal = 0;  Bit#(8) odd = 0;  Bit#(8) omVal = 0;
      for (Integer k = 0; k < valueOf(LamLen); k = k + 1) begin
         lamVal = lamVal ^ g[k];
         if (k % 2 == 1) odd = odd ^ g[k];
         omVal = omVal ^ h[k];
      end
      Bool finished = False;
      Bool ok       = False;
      if (lamVal == 0) begin
         if (odd == 0) begin
            failR <= True;  finished = True;
         end
         else begin
            Vector#(MaxFix, Fix) f = fx;
            f[cnt] = tuple2(nLen - 1 - d, omVal);      // E is made in the Mag phase
            fx <= f;
            Vector#(MaxFix, Bit#(8)) o = oddV;
            o[cnt] = odd;
            oddV <= o;
            cnt <= cnt + 1;
            if (cnt + 1 == lReg) begin finished = True; ok = True; end
         end
      end
      if (!finished && d + 1 == nLen) begin
         failR <= True;  finished = True;
      end
      Lambda gn = g;  Lambda hn = h;
      for (Integer k = 0; k < valueOf(LamLen); k = k + 1) begin
         gn[k] = gfMul(g[k], alphaInvPow(k));
         hn[k] = gfMul(h[k], alphaInvPow(k));
      end
      g <= gn;  h <= hn;
      d <= d + 1;
      if (finished) begin
         state <= ok ? CfMag : CfDone;
         mi    <= 0;
         mph   <= 0;
      end
   endrule

   // E = Omega(root) / odd(root): (0) pick odd sum and Omega value into registers,
   // (1) 1/odd into a register, (2) multiply.  (R4F+: the 15:1 pick and the inverse table
   // were one 1.76 ns path in r4f; now two short ones.  One extra clock per error.)
   rule magSel (state == CfMag && mph == 0);
      oddR <= oddV[mi];
      omR  <= tpl_2(fx[mi]);
      mph  <= 1;
   endrule

   rule magInv (state == CfMag && mph == 1);
      invR <= gfInverse(oddR);
      mph  <= 2;
   endrule

   rule magMul (state == CfMag && mph == 2);
      Vector#(MaxFix, Fix) f = fx;
      f[mi] = tuple2(tpl_1(fx[mi]), gfMul(omR, invR));
      fx  <= f;
      mph <= 0;
      if (mi + 1 == cnt) state <= CfDone;
      mi <= mi + 1;
   endrule

   method Action start(Lambda lm, UInt#(5) l, Syndromes s, UInt#(5) ecLen, UInt#(8) n)
         if (state == CfIdle || state == CfDone);
      Lambda first = replicate(0);  first[0] = lm[0];
      lam   <= lm;
      lsh   <= first;
      lq    <= shiftInAtN(lm, 0);
      s16   <= take(s);
      h     <= replicate(0);
      i     <= 0;
      nLen  <= n;
      lReg  <= l;
      ec    <= ecLen;
      cnt   <= 0;
      failR <= False;
      state <= (l == 0) ? CfDone : CfOmegaP;
   endmethod

   method Bool     done     = (state == CfDone);
   method Bool     fail     = failR;
   method UInt#(5) fixCount = cnt;
   method Vector#(MaxFix, Fix) fixes = fx;
endmodule

`else
typedef enum { CfIdle, CfOmega, CfSearch, CfDone } CfState deriving (Bits, Eq, FShow);

(* synthesize *)
module mkChienForney (ChienForney);
   Reg#(CfState)  state <- mkReg(CfIdle);
   Reg#(Lambda)   lam   <- mkReg(?);
   Reg#(Lambda)   lq    <- mkReg(?);    // Lambda coefficients still to slide in
   Reg#(Lambda)   lsh   <- mkReg(?);    // lsh[j] = Lambda_(i-j) while building Omega
   Reg#(Lambda)   s16   <- mkReg(?);    // S_0 .. S_15
   Reg#(Lambda)   g     <- mkReg(?);    // g[i] = Lambda_i * alpha^(-i*d)
   Reg#(Lambda)   h     <- mkReg(?);    // h[i] = Omega_i  * alpha^(-i*d)
   Reg#(UInt#(5)) i     <- mkReg(0);
   Reg#(UInt#(8)) d     <- mkReg(0);    // degree being tested
   Reg#(UInt#(8)) nLen  <- mkReg(0);
   Reg#(UInt#(5)) lReg  <- mkReg(0);
   Reg#(UInt#(5)) ec    <- mkReg(0);
   Reg#(UInt#(5)) cnt   <- mkReg(0);
   Reg#(Vector#(MaxFix, Fix)) fx <- mkReg(?);
   Reg#(Bool)     failR <- mkReg(False);

   // Omega_i = S_0*Lambda_i + S_1*Lambda_(i-1) + ... + S_i*Lambda_0   (i < ecLen)
   rule omega (state == CfOmega);
      Bit#(8) v = 0;
      for (Integer j = 0; j < valueOf(LamLen); j = j + 1)
         v = v ^ gfMul(s16[j], lsh[j]);
      Lambda hn = h;
      hn[i] = (i < ec) ? v : 0;
      h   <= hn;
      lsh <= shiftInAt0(lsh, lq[0]);
      lq  <= shiftInAtN(lq, 0);
      if (i == 15) begin
         g     <= lam;
         d     <= 0;
         state <= CfSearch;
      end
      i <= i + 1;
   endrule

   rule search (state == CfSearch);
      Bit#(8) lamVal = 0;  Bit#(8) odd = 0;  Bit#(8) omVal = 0;
      for (Integer k = 0; k < valueOf(LamLen); k = k + 1) begin
         lamVal = lamVal ^ g[k];
         if (k % 2 == 1) odd = odd ^ g[k];
         omVal = omVal ^ h[k];
      end
      Bool finished = False;
      if (lamVal == 0) begin                       // degree d is wrong
         if (odd == 0) begin
            failR <= True;  finished = True;       // repeated root: give up
         end
         else begin
            Bit#(8) mag = gfMul(omVal, gfInverse(odd));
            Vector#(MaxFix, Fix) f = fx;
            f[cnt] = tuple2(nLen - 1 - d, mag);
            fx  <= f;
            cnt <= cnt + 1;
            if (cnt + 1 == lReg) finished = True;  // all L errors found
         end
      end
      if (!finished && d + 1 == nLen) begin        // end of block, too few roots
         failR <= True;  finished = True;
      end
      // next degree: multiply term i by alpha^-i
      Lambda gn = g;  Lambda hn = h;
      for (Integer k = 0; k < valueOf(LamLen); k = k + 1) begin
         gn[k] = gfMul(g[k], alphaInvPow(k));
         hn[k] = gfMul(h[k], alphaInvPow(k));
      end
      g <= gn;  h <= hn;
      d <= d + 1;
      if (finished) state <= CfDone;
   endrule

   method Action start(Lambda lm, UInt#(5) l, Syndromes s, UInt#(5) ecLen, UInt#(8) n)
         if (state != CfOmega && state != CfSearch);
      Lambda first = replicate(0);  first[0] = lm[0];
      lam   <= lm;
      lsh   <= first;                    // i = 0: lsh[0] = Lambda_0
      lq    <= shiftInAtN(lm, 0);        // next to slide in: Lambda_1
      s16   <= take(s);
      h     <= replicate(0);
      i     <= 0;
      nLen  <= n;
      lReg  <= l;
      ec    <= ecLen;
      cnt   <= 0;
      failR <= False;
      state <= (l == 0) ? CfDone : CfOmega;   // no errors: nothing to do
   endmethod

   method Bool     done     = (state == CfDone);
   method Bool     fail     = failR;
   method UInt#(5) fixCount = cnt;
   method Vector#(MaxFix, Fix) fixes = fx;
endmodule

`endif

endpackage
