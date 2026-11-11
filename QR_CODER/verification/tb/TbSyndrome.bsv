// TbSyndrome.bsv -- checks mkSyndromeUnit against a vector file (Person B).
//
// Reads syn_vectors.hex (one hex byte per line, format in
// gen_syndrome_vectors.py and docs/RS_VECTOR_FORMAT.md).  For each record:
//   start(ecLen) -> put n bytes, one per cycle -> compare S_0..S_(ecLen-1)
//   (one per cycle) and allZero with the file.  Prints a summary and "RESULT: PASS/FAIL".
package TbSyndrome;

import Vector  :: *;
import RegFile :: *;
import QRRS    :: *;

typedef UInt#(19) Addr;                  // file has exactly 2^19 lines

typedef enum { ReadHdr, Feed, Check, EndBlock, Finish } Phase deriving (Bits, Eq);

(* synthesize *)
module mkTbSyndrome ();
   RegFile#(Addr, Bit#(8)) vec <- mkRegFileFullLoad("syn_vectors.hex");
   SyndromeUnit dut <- mkSyndromeUnit;

   Reg#(Phase)      phase   <- mkReg(ReadHdr);
   Reg#(Addr)       p       <- mkReg(0);       // read position in the file
   Reg#(UInt#(5))   ecLen   <- mkReg(0);
   Reg#(UInt#(16))  left    <- mkReg(0);       // bytes still to feed
   Reg#(UInt#(32))  blocks  <- mkReg(0);
   Reg#(UInt#(32))  cleanN  <- mkReg(0);
   Reg#(UInt#(32))  bytes   <- mkReg(0);
   Reg#(UInt#(32))  synChk  <- mkReg(0);       // syndrome values compared
   Reg#(UInt#(32))  bad     <- mkReg(0);       // blocks with a mismatch
   Reg#(UInt#(32))  cycles  <- mkReg(0);
   Reg#(UInt#(5))   jIdx    <- mkReg(0);       // which syndrome is compared now
   Reg#(Bool)       expZero <- mkReg(True);    // file says "no error"
   Reg#(Bool)       blockBad <- mkReg(False);  // this block had a mismatch

   rule tick; cycles <= cycles + 1; endrule

   rule readHeader (phase == ReadHdr);
      Bit#(8) e = vec.sub(p);
      if (e == 0) phase <= Finish;
      else begin
         UInt#(16) n = unpack({vec.sub(p + 1), vec.sub(p + 2)});
         ecLen <= unpack(truncate(e));
         left  <= n;
         dut.start(unpack(truncate(e)));
         p     <= p + 3;
         jIdx  <= 0;
         expZero  <= True;
         blockBad <= False;
         phase <= Feed;
      end
   endrule

   rule feed (phase == Feed);
      dut.put(vec.sub(p));
      p     <= p + 1;
      bytes <= bytes + 1;
      if (left == 1) phase <= Check;
      left  <= left - 1;
   endrule

   // Compare one syndrome per cycle (the file can be read only a few
   // times per cycle), then the summary checks for this block.
   rule check (phase == Check);
      Syndromes got = dut.syndromes;
      Bit#(8) want = vec.sub(p);
      UInt#(5) j = jIdx;
      Bool wrong = blockBad;
      if (want != 0) expZero <= False;
      if (got[j] != want) begin
         wrong = True;
         if (bad < 5)
            $display("  MISMATCH block %0d: S_%0d got %02x want %02x", blocks, j, got[j], want);
      end
      blockBad <= wrong;
      p <= p + 1;
      if (j + 1 == ecLen) phase <= EndBlock;
      jIdx <= j + 1;
   endrule

   rule endBlock (phase == EndBlock);
      Syndromes got = dut.syndromes;
      Bool wrong = blockBad;
      // Unused syndromes (j >= ecLen) must read as 0.
      for (Integer j = 0; j < 30; j = j + 1)
         if (fromInteger(j) >= ecLen && got[j] != 0) wrong = True;
      if (dut.allZero != expZero) begin
         wrong = True;
         if (bad < 5) $display("  MISMATCH block %0d: allZero got %0d", blocks, pack(dut.allZero));
      end
      if (wrong) bad <= bad + 1;
      if (expZero) cleanN <= cleanN + 1;
      synChk <= synChk + zeroExtend(ecLen);
      blocks <= blocks + 1;
      phase  <= ReadHdr;
   endrule

   rule finish (phase == Finish);
      $display("syndrome unit: %0d blocks (%0d clean, %0d with errors), %0d bytes, %0d syndromes compared, %0d cycles",
               blocks, cleanN, blocks - cleanN, bytes, synChk, cycles);
      $display("blocks with a mismatch: %0d", bad);
      if (blocks == 0)   $display("RESULT: FAIL (no vectors read -- is syn_vectors.hex here?)");
      else if (bad == 0) $display("RESULT: PASS");
      else               $display("RESULT: FAIL");
      $finish(0);
   endrule
endmodule

endpackage
