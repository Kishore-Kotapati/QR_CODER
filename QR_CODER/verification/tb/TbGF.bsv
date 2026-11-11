// TbGF.bsv -- checks QRGF.bsv in Bluesim (Person B).
//
// These are PROPERTY checks: facts any correct GF(2^8) with 0x11D must obey.
// Several use the course's own tables (gfInv, alphaPow, alphaInvPow), which
// were written by someone else, so a wrong multiplier cannot pass by luck.
// The final exhaustive 65,536-product comparison against Person A's model
// vectors is a separate test (TbGFVectors.bsv) once those vectors exist.
package TbGF;

import QRTables :: *;
import QRGF     :: *;

(* synthesize *)
module mkTbGF (Empty);
   Reg#(UInt#(17)) i      <- mkReg(0);       // 0 .. 65536
   Reg#(UInt#(3))  phase  <- mkReg(0);
   Reg#(UInt#(32)) checks <- mkReg(0);
   Reg#(UInt#(32)) errs   <- mkReg(0);
   Reg#(Bit#(8))   x      <- mkReg(1);       // walks through alpha^k
   Reg#(UInt#(9))  k      <- mkReg(0);
   Reg#(Bit#(256)) seen   <- mkReg(0);

   function Action fail(String what, Bit#(8) a, Bit#(8) b, Bit#(8) got, Bit#(8) want);
      action
         if (errs < 10)
            $display("FAIL %s: a=%02h b=%02h got=%02h want=%02h", what, a, b, got, want);
      endaction
   endfunction

   // ---- phase 0: every pair (a, b)
   rule pairs (phase == 0);
      Bit#(16) ab = truncate(pack(i));
      Bit#(8) a = ab[15:8];
      Bit#(8) b = ab[7:0];
      Bit#(8) p = gfMul(a, b);
      UInt#(32) e = 0;
      UInt#(32) n = 3;
      // 1. order does not matter: a*b = b*a
      if (p != gfMul(b, a)) begin e = e + 1; fail("a*b == b*a", a, b, p, gfMul(b, a)); end
      // 2. multiply spreads over add: a*(b+53) = a*b + a*53
      Bit#(8) l = gfMul(a, b ^ 8'h53);
      Bit#(8) r = p ^ gfMul(a, 8'h53);
      if (l != r) begin e = e + 1; fail("a*(b+53) == a*b + a*53", a, b, l, r); end
      // 3. grouping does not matter: (a*b)*CA = a*(b*CA)
      Bit#(8) l2 = gfMul(p, 8'hCA);
      Bit#(8) r2 = gfMul(a, gfMul(b, 8'hCA));
      if (l2 != r2) begin e = e + 1; fail("(a*b)*CA == a*(b*CA)", a, b, l2, r2); end
      // once per a: zero, one, and the course's inverse table
      if (b == 0) begin
         n = n + 3;
         if (gfMul(a, 0) != 0) begin e = e + 1; fail("a*0 == 0", a, 0, gfMul(a, 0), 0); end
         if (gfMul(a, 1) != a) begin e = e + 1; fail("a*1 == a", a, 1, gfMul(a, 1), a); end
         match {.ok, .q} = gfDivSafe(a, 0);
         if (ok) begin e = e + 1; fail("divide by 0 must be flagged", a, 0, q, 0); end
         if (a != 0) begin
            n = n + 1;
            Bit#(8) one = gfMul(a, gfInverse(a));
            if (one != 1) begin e = e + 1; fail("a * gfInv(a) == 1", a, gfInverse(a), one, 1); end
         end
      end
      checks <= checks + n;
      errs   <= errs + e;
      if (i == 65535) phase <= 1;
      i <= i + 1;
   endrule

   // ---- phase 1: alpha = 2 must reach all 255 non-zero values, then return to 1
   rule powers (phase == 1);
      Bit#(8) nx = gfMul(x, 2);
      UInt#(32) e = 0;
      if (nx != gfMulAlpha(x)) begin e = e + 1; fail("x*2 == gfMulAlpha(x)", x, 2, nx, gfMulAlpha(x)); end
      if (seen[x] == 1)        begin e = e + 1; fail("alpha^k repeats too early", x, 0, x, 0); end
      seen <= seen | (1 << x);
      x <= nx;
      k <= k + 1;
      if (k == 254) begin
         if (nx != 1) begin e = e + 1; fail("alpha^255 == 1", nx, 0, nx, 1); end
         phase <= 2;
      end
      checks <= checks + 2;
      errs   <= errs + e;
   endrule

   // ---- phase 2: the course's alpha tables
   rule tables (phase == 2);
      UInt#(32) e = 0;
      UInt#(32) n = 0;
      for (Integer j = 0; j < 29; j = j + 1) begin
         n = n + 2;
         if (gfMul(alphaPow(j), 2) != alphaPow(j + 1)) begin
            e = e + 1; fail("alphaPow(j)*2 == alphaPow(j+1)", alphaPow(j), 2, gfMul(alphaPow(j), 2), alphaPow(j + 1));
         end
         if (gfMulAlphaPow(1, j) != alphaPow(j)) begin
            e = e + 1; fail("gfMulAlphaPow(1, j)", 1, alphaPow(j), gfMulAlphaPow(1, j), alphaPow(j));
         end
      end
      for (Integer j = 0; j < 16; j = j + 1) begin
         n = n + 1;
         if (gfMul(alphaPow(j), alphaInvPow(j)) != 1) begin
            e = e + 1; fail("alphaPow(j)*alphaInvPow(j) == 1", alphaPow(j), alphaInvPow(j), gfMul(alphaPow(j), alphaInvPow(j)), 1);
         end
      end
      checks <= checks + n;
      errs   <= errs + e;
      phase  <= 3;
   endrule

   rule report (phase == 3);
      $display("QRGF checks: %0d run, %0d failed", checks, errs);
      $display(errs == 0 ? "RESULT: PASS" : "RESULT: FAIL");
      $finish(0);
   endrule
endmodule

endpackage
