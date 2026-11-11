// TbGFVectors.bsv -- exhaustive check of gfMul against Person A's model.
// Needs the file  gf_mul.hex  in the folder you run the simulation from:
// 65,536 lines, line number n = a*256 + b, each line = product a*b as 2 hex
// digits (made by Person A's gf_ref.py -- NOT by Person B).
package TbGFVectors;

import RegFile :: *;
import QRGF    :: *;

(* synthesize *)
module mkTbGFVectors (Empty);
   RegFile#(Bit#(16), Bit#(8)) want <- mkRegFileFullLoad("gf_mul.hex");
   Reg#(UInt#(17)) i    <- mkReg(0);
   Reg#(UInt#(32)) errs <- mkReg(0);

   rule check (i < 65536);
      Bit#(16) ab = truncate(pack(i));
      Bit#(8) got = gfMul(ab[15:8], ab[7:0]);
      if (got != want.sub(ab)) begin
         if (errs < 10) $display("MISMATCH a=%02h b=%02h rtl=%02h model=%02h", ab[15:8], ab[7:0], got, want.sub(ab));
         errs <= errs + 1;
      end
      i <= i + 1;
   endrule

   rule report (i == 65536);
      $display("gfMul vs model: 65536 pairs, %0d mismatches", errs);
      $display(errs == 0 ? "RESULT: PASS" : "RESULT: FAIL");
      $finish(0);
   endrule
endmodule

endpackage
