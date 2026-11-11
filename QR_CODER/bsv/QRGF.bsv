// QRGF.bsv -- GF(2^8) arithmetic for the QR decoder (Person B, RTL).
//
// Field rules from spec section 1.4:
//   * a byte is a polynomial with 0/1 coefficients (bit i = coefficient of x^i)
//   * addition = XOR
//   * multiplication = polynomial multiply, then reduce by x^8+x^4+x^3+x^2+1 (0x11D)
//   * alpha = 2 (the polynomial x)
// Everything here is a pure function: no registers.  bsc "unrolls" the for
// loops when it compiles, so each call becomes a block of XOR/AND gates.
package QRGF;

import QRTables :: *;     // gfInv, alphaPow, alphaInvPow (supplied tables)

// Multiply by alpha (= x): shift left; if a 1 fell off the top (x^8),
// replace it by x^4+x^3+x^2+1 (0x1D), because x^8 = x^4+x^3+x^2+1 here.
function Bit#(8) gfMulAlpha(Bit#(8) a);
   Bit#(8) shifted = a << 1;
   return (a[7] == 1) ? (shifted ^ 8'h1D) : shifted;
endfunction

// General multiply, "shift and add":
//   a*b = sum over the 1-bits i of b of  a * x^i
// x keeps a * x^i (one more gfMulAlpha each step); p collects the sum (XOR).
function Bit#(8) gfMul(Bit#(8) a, Bit#(8) b);
   Bit#(8) p = 0;
   Bit#(8) x = a;
   for (Integer i = 0; i < 8; i = i + 1) begin
      if (b[i] == 1) p = p ^ x;
      x = gfMulAlpha(x);
   end
   return p;
endfunction

// Addition is XOR (and subtraction is the same thing).
function Bit#(8) gfAdd(Bit#(8) a, Bit#(8) b) = a ^ b;

// Inverse: the supplied 256-entry table (gfInv(0) = 0, which is NOT a real
// inverse -- callers must never divide by 0; use gfDivSafe).
function Bit#(8) gfInverse(Bit#(8) a) = gfInv(a);

// a / b, plus a flag that is False when b == 0 (division not allowed).
function Tuple2#(Bool, Bit#(8)) gfDivSafe(Bit#(8) a, Bit#(8) b);
   return tuple2(b != 0, gfMul(a, gfInv(b)));
endfunction

// Multiply by a CONSTANT alpha^j (j known when compiling, 0..29).
// Same function as gfMul, but with one input fixed: the synthesis tool
// removes all the gates that do not matter, leaving a small XOR network.
function Bit#(8) gfMulAlphaPow(Bit#(8) a, Integer j) = gfMul(a, alphaPow(j));

endpackage
