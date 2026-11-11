// TbBM.bsv -- checks mkSyndromeUnit + mkBMUnit against rs_vectors.hex.
// (Person B.)  File format: gen_rs_vectors.py / docs/RS_VECTOR_FORMAT.md.
//
// For each record:  feed the received block into the syndrome unit,
// hand the syndromes to Berlekamp-Massey, wait for done, then:
//   status 0 (v <= t errors): fail must be False, L and Lambda_0..15 must match
//   status 1 / 2 (not fixable / > t errors): only "fail OR L <= t" is
//            checked and counted -- BM alone catches few of them; the whole
//            decoder must fail on them, which TbRS checks.
package TbBM;

import Vector  :: *;
import RegFile :: *;
import QRRS    :: *;

typedef UInt#(20) Addr;                 // file has exactly 2^20 lines

typedef enum { ReadHdr, Feed, StartBM, WaitBM, ReadStatus, CheckLam, EndRec, Finish }
        Phase deriving (Bits, Eq);

(* synthesize *)
module mkTbBM ();
   RegFile#(Addr, Bit#(8)) vec <- mkRegFileFullLoad("rs_vectors.hex");
   SyndromeUnit syn <- mkSyndromeUnit;
   BMUnit       bm  <- mkBM(syn.syndromes);   // R0, R2 or R4 version

   Reg#(Phase)     phase  <- mkReg(ReadHdr);
   Reg#(Addr)      p      <- mkReg(0);
   Reg#(UInt#(5))  ecLen  <- mkReg(0);
   Reg#(UInt#(16)) n      <- mkReg(0);
   Reg#(UInt#(16)) left   <- mkReg(0);
   Reg#(Bit#(8))   status <- mkReg(0);
   Reg#(UInt#(5))  idx    <- mkReg(0);
   Reg#(Bool)      recBad <- mkReg(False);

   Reg#(UInt#(32)) recs    <- mkReg(0);
   Reg#(UInt#(32)) fixable <- mkReg(0);     // status 0 records
   Reg#(UInt#(32)) over    <- mkReg(0);     // status 2 records
   Reg#(UInt#(32)) overFail <- mkReg(0);    // ... where BM said fail
   Reg#(UInt#(32)) bad     <- mkReg(0);
   Reg#(UInt#(32)) bmCyc   <- mkReg(0);     // cycles spent inside BM
   Reg#(UInt#(32)) maxCyc  <- mkReg(0);
   Reg#(UInt#(32)) thisCyc <- mkReg(0);

   function Action note(String what, Bit#(8) got, Bit#(8) want) = action
      if (bad < 5)
         $display("  MISMATCH record %0d (ecLen %0d, n %0d, status %0d): %s got %02x want %02x",
                  recs, ecLen, n, status, what, got, want);
   endaction;

   rule readHeader (phase == ReadHdr);
      Bit#(8) e = vec.sub(p);
      if (e == 0) phase <= Finish;
      else begin
         UInt#(16) nn = unpack({vec.sub(p + 1), vec.sub(p + 2)});
         ecLen <= unpack(truncate(e));
         n     <= nn;
         left  <= nn;
         syn.start(unpack(truncate(e)));
         p      <= p + 3;
         recBad <= False;
         phase  <= Feed;
      end
   endrule

   rule feed (phase == Feed);
      syn.put(vec.sub(p));
      p <= p + 1;
      if (left == 1) phase <= StartBM;
      left <= left - 1;
   endrule

   rule startBM (phase == StartBM);
      bm.start(syn.syndromes, ecLen);
      thisCyc <= 0;
      phase   <= WaitBM;
   endrule

   rule waitBM (phase == WaitBM);
      if (bm.done) phase <= ReadStatus;
      else thisCyc <= thisCyc + 1;
   endrule

   rule readStatus (phase == ReadStatus);
      Bit#(8) st = vec.sub(p);
      Bit#(8) wantL = vec.sub(p + 1);
      UInt#(5) t = ecLen >> 1;
      Bool wrong = False;
      bmCyc <= bmCyc + thisCyc + 1;
      if (thisCyc + 1 > maxCyc) maxCyc <= thisCyc + 1;
      status <= st;
      if (st == 0) begin
         fixable <= fixable + 1;
         if (bm.fail) begin wrong = True; note("fail flag", 1, 0); end
         else if (pack(zeroExtend(bm.errCount)) != wantL) begin
            wrong = True; note("L", pack(zeroExtend(bm.errCount)), wantL);
         end
      end
      else begin
         // status 1 (model: not fixable) and 2 (> t errors): BM alone does not
         // have to fail -- most such blocks are only caught later by Chien's
         // root count (TbRS checks that the whole decoder fails on them).
         over <= over + 1;
         if (bm.fail) overFail <= overFail + 1;
         else if (bm.errCount > t) begin wrong = True; note("L > t but no fail", 1, 0); end
      end
      recBad <= wrong;
      p      <= p + 2;
      idx    <= 0;
      phase  <= CheckLam;
   endrule

   // Lambda_0..15, one per cycle (only for status 0)
   rule checkLam (phase == CheckLam);
      Lambda lam = bm.lambda;
      Bit#(8) want = vec.sub(p);
      if (status == 0 && !bm.fail && lam[idx] != want) begin
         recBad <= True;
         note("Lambda", lam[idx], want);
      end
      p <= p + 1;
      if (idx == 15) phase <= EndRec;
      idx <= idx + 1;
   endrule

   rule endRec (phase == EndRec);
      if (recBad) bad <= bad + 1;
      recs  <= recs + 1;
      p     <= p + zeroExtend(n);           // skip the corrected block (Day 7)
      phase <= ReadHdr;
   endrule

   rule finish (phase == Finish);
      $display("BM: %0d blocks: %0d fixable (0..t errors), %0d with more than t errors (BM said fail on %0d)",
               recs, fixable, over, overFail);
      $display("BM cycles: %0d in total, at most %0d for one block", bmCyc, maxCyc);
      $display("records with a mismatch: %0d", bad);
      if (recs == 0)     $display("RESULT: FAIL (no vectors read -- is rs_vectors.hex here?)");
      else if (bad == 0) $display("RESULT: PASS");
      else               $display("RESULT: FAIL");
      $finish(0);
   endrule
endmodule

endpackage
