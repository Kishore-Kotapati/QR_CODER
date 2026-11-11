// TbRS.bsv -- whole RS decoder for one block: syndromes -> BM -> Chien/Forney.
// (Person B.)  Reads rs_vectors.hex (format: docs/RS_VECTOR_FORMAT.md).
//
// For each record the received block is decoded, the fixes are applied, and:
//   status 0 (v <= t): must succeed, fixCount = L, corrected block = c exactly
//   status 1 (model: not fixable): must fail
//   status 2 (> t errors): may fail; if it "succeeds", the output must still
//            be a valid codeword (all syndromes 0) with at most t changes.
// Every successful output is also re-checked by a 2nd syndrome unit.
package TbRS;

import Vector  :: *;
import RegFile :: *;
import QRRS    :: *;

typedef UInt#(20) Addr;

typedef enum { ReadHdr, Feed, StartBM, WaitBM, StartCF, WaitCF, ReadStatus,
               Compare, Recheck, EndRec, Finish } Phase deriving (Bits, Eq);

(* synthesize *)
module mkTbRS ();
   RegFile#(Addr, Bit#(8)) vec <- mkRegFileFullLoad("rs_vectors.hex");
   SyndromeUnit syn  <- mkSyndromeUnit;
   BMUnit       bm   <- mkBM(syn.syndromes);  // R0, R2 or R4 version
   ChienForney  cf   <- mkChienForney;
   SyndromeUnit syn2 <- mkSyndromeUnit;        // re-checks the corrected block

   Reg#(Phase)     phase  <- mkReg(ReadHdr);
   Reg#(Addr)      p      <- mkReg(0);
   Reg#(Addr)      pBlk   <- mkReg(0);         // start of received block
   Reg#(UInt#(5))  ecLen  <- mkReg(0);
   Reg#(UInt#(16)) n      <- mkReg(0);
   Reg#(UInt#(16)) k      <- mkReg(0);
   Reg#(Bit#(8))   status <- mkReg(0);
   Reg#(Bool)      decFail <- mkReg(False);
   Reg#(Bool)      recBad  <- mkReg(False);
   Reg#(Bool)      differs <- mkReg(False);    // corrected != c somewhere
   Reg#(UInt#(32)) cyc     <- mkReg(0);

   Reg#(UInt#(32)) recs     <- mkReg(0);
   Reg#(UInt#(32)) fixable  <- mkReg(0);
   Reg#(UInt#(32)) fixedOk  <- mkReg(0);
   Reg#(UInt#(32)) bytesFixed <- mkReg(0);
   Reg#(UInt#(32)) over     <- mkReg(0);
   Reg#(UInt#(32)) overFail <- mkReg(0);
   Reg#(UInt#(32)) overMis  <- mkReg(0);      // > t errors, decoded to another codeword
   Reg#(UInt#(32)) bad      <- mkReg(0);
   Reg#(UInt#(32)) decCyc   <- mkReg(0);      // BM + Chien/Forney cycles
   Reg#(UInt#(32)) maxCyc   <- mkReg(0);

   function Action note(String what, Bit#(8) got, Bit#(8) want) = action
      if (bad < 5)
         $display("  MISMATCH record %0d (ecLen %0d, n %0d, status %0d): %s got %02x want %02x",
                  recs, ecLen, n, status, what, got, want);
   endaction;

   // XOR value for byte index kk (0 if not fixed)
   function Bit#(8) fixFor(UInt#(16) kk);
      Bit#(8) e = 0;
      Vector#(MaxFix, Fix) f = cf.fixes;
      for (Integer j = 0; j < valueOf(MaxFix); j = j + 1)
         if (fromInteger(j) < cf.fixCount && zeroExtend(tpl_1(f[j])) == kk)
            e = e ^ tpl_2(f[j]);
      return e;
   endfunction

   rule readHeader (phase == ReadHdr);
      Bit#(8) e = vec.sub(p);
      if (e == 0) phase <= Finish;
      else begin
         UInt#(16) nn = unpack({vec.sub(p + 1), vec.sub(p + 2)});
         ecLen <= unpack(truncate(e));
         n     <= nn;
         k     <= 0;
         syn.start(unpack(truncate(e)));
         p     <= p + 3;
         pBlk  <= p + 3;
         recBad  <= False;
         differs <= False;
         phase <= Feed;
      end
   endrule

   rule feed (phase == Feed);
      syn.put(vec.sub(p));
      p <= p + 1;
      if (k + 1 == n) phase <= StartBM;
      k <= k + 1;
   endrule

   rule startBM (phase == StartBM);
      bm.start(syn.syndromes, ecLen);
      cyc   <= 0;
      phase <= WaitBM;
   endrule

   rule waitBM (phase == WaitBM);
      cyc <= cyc + 1;
      if (bm.done) phase <= StartCF;
   endrule

   rule startCF (phase == StartCF);
      if (bm.fail) begin
         decFail <= True;
         phase   <= ReadStatus;
      end
      else begin
         cf.start(bm.lambda, bm.errCount, syn.syndromes, ecLen, truncate(n));
         phase <= WaitCF;
      end
   endrule

   rule waitCF (phase == WaitCF);
      cyc <= cyc + 1;
      if (cf.done) begin
         decFail <= cf.fail;
         phase   <= ReadStatus;
      end
   endrule

   rule readStatus (phase == ReadStatus);
      Bit#(8) st    = vec.sub(p);
      Bit#(8) wantL = vec.sub(p + 1);
      status <= st;
      decCyc <= decCyc + cyc;
      if (cyc > maxCyc) maxCyc <= cyc;
      Bool wrong = False;
      if (st == 0) begin
         fixable <= fixable + 1;
         if (decFail) begin wrong = True; note("decoder failed", 1, 0); end
         else if (pack(zeroExtend(cf.fixCount)) != wantL) begin
            wrong = True; note("fixCount", pack(zeroExtend(cf.fixCount)), wantL);
         end
      end
      else if (st == 1) begin
         if (!decFail) begin wrong = True; note("decoder did not fail", 0, 1); end
      end
      else begin
         over <= over + 1;
         if (decFail) overFail <= overFail + 1;
         else if (cf.fixCount > (ecLen >> 1)) begin
            wrong = True; note("more than t fixes", pack(zeroExtend(cf.fixCount)), 0);
         end
      end
      recBad <= wrong;
      syn2.start(ecLen);
      k <= 0;
      p <= p + 18;                     // skip status, L, Lambda -> corrected block c
      phase <= Compare;
   endrule

   // one byte per cycle: corrected = received XOR fix; compare with c
   rule compare (phase == Compare);
      Bit#(8) r    = vec.sub(pBlk + zeroExtend(k));
      Bit#(8) want = vec.sub(p);
      Bit#(8) got  = decFail ? r : (r ^ fixFor(k));
      syn2.put(got);
      if (got != want) begin
         differs <= True;
         if (status == 0) begin
            recBad <= True;
            note("corrected byte", got, want);
         end
      end
      p <= p + 1;
      if (k + 1 == n) phase <= Recheck;
      k <= k + 1;
   endrule

   rule recheck (phase == Recheck);
      Bool wrong = recBad;
      if (!decFail && !syn2.allZero) begin
         wrong = True;
         note("output is not a codeword", 0, 0);
      end
      if (status == 0 && !wrong) begin
         fixedOk    <= fixedOk + 1;
         bytesFixed <= bytesFixed + zeroExtend(cf.fixCount);
      end
      if (status == 2 && !decFail) overMis <= overMis + 1;
      if (wrong) bad <= bad + 1;
      recs  <= recs + 1;
      phase <= ReadHdr;
   endrule

   rule finish (phase == Finish);
      $display("RS: %0d blocks: %0d fixable -> %0d fixed exactly (%0d bytes corrected)",
               recs, fixable, fixedOk, bytesFixed);
      $display("RS: %0d blocks with more than t errors -> %0d failed, %0d decoded to another valid codeword (allowed)",
               over, overFail, overMis);
      $display("decode cycles (BM + Chien/Forney): %0d in total, at most %0d for one block", decCyc, maxCyc);
      $display("records with a mismatch: %0d", bad);
      if (recs == 0)     $display("RESULT: FAIL (no vectors read -- is rs_vectors.hex here?)");
      else if (bad == 0) $display("RESULT: PASS");
      else               $display("RESULT: FAIL");
      $finish(0);
   endrule
endmodule

endpackage
