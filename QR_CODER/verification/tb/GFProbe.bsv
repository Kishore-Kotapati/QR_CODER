// GFProbe.bsv -- a tiny wrapper ONLY for a first synthesis test of QRGF.
// Registers on the inputs and outputs, so the multiplier and the inverse
// table sit on a flop-to-flop (f2f) path, like they will inside the decoder.
// Not part of the decoder.
package GFProbe;

import QRGF :: *;

interface GFProbe;
   method Action put(Bit#(8) a, Bit#(8) b);
   method Bit#(8) product;
   method Bit#(8) inverse;
endinterface

(* synthesize *)
module mkGFProbe (GFProbe);
   Reg#(Bit#(8)) ra   <- mkReg(0);
   Reg#(Bit#(8)) rb   <- mkReg(0);
   Reg#(Bit#(8)) rmul <- mkReg(0);
   Reg#(Bit#(8)) rinv <- mkReg(0);

   rule compute;
      rmul <= gfMul(ra, rb);
      rinv <= gfInverse(ra);
   endrule

   method Action put(Bit#(8) a, Bit#(8) b);
      ra <= a;  rb <= b;
   endmethod
   method Bit#(8) product = rmul;
   method Bit#(8) inverse = rinv;
endmodule

endpackage
