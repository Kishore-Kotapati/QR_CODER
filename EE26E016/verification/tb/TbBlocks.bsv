// TbBlocks.bsv -- checks mkQRBlocks (the whole backend) against
// blocks_vectors.hex (segno-made symbols, all 160 layouts).  Person B.
//
// For each symbol: configure -> send every raw byte (with random pauses) ->
// wait for isReady / isError -> read the data bytes (with random pauses) and
// compare -> reset.  Extra abuse:
//   * every 7th symbol: reset half-way through the raw bytes, then send the
//     whole symbol again (abort + restart);
//   * every 5th symbol: reset after reading only half of the output.
// Symbols with one block beyond t must give isError (a wrong "fix" is
// possible in theory, but far below 1 in a million here).
// Also checks: blockParams in QRTables agrees with segno's sizes, the
// interface status flags, and the decode time (last raw byte -> ready).
package TbBlocks;

import Vector          :: *;
import RegFile         :: *;
import LFSR            :: *;
import QRTables        :: *;
import QRInternalTypes :: *;
import QRBlocks        :: *;

typedef UInt#(21) Addr;

typedef enum { ReadHdr, ReadHdr2, Configure, Send, AbortReset, WaitDone, Read, EndRec, Finish }
        Phase deriving (Bits, Eq);

(* synthesize *)
module mkTbBlocks ();
   RegFile#(Addr, Bit#(8)) vec <- mkRegFileFullLoad("blocks_vectors.hex");
   QRBackend dut <- mkQRBlocks;
   LFSR#(Bit#(16)) rnd <- mkLFSR_16;

   Reg#(Phase)     phase   <- mkReg(ReadHdr);
   Reg#(Addr)      p       <- mkReg(0);       // record start
   Reg#(UInt#(6))  ver     <- mkReg(0);
   Reg#(Bit#(2))   lvl     <- mkReg(0);
   Reg#(Bit#(8))   status  <- mkReg(0);
   Reg#(UInt#(12)) total   <- mkReg(0);
   Reg#(UInt#(12)) tdata   <- mkReg(0);
   Reg#(UInt#(12)) i       <- mkReg(0);
   Reg#(Bool)      aborted <- mkReg(False);   // already did the abort for this symbol
   Reg#(Bool)      recBad  <- mkReg(False);
   Reg#(UInt#(32)) cyc     <- mkReg(0);
   Reg#(UInt#(32)) tStart  <- mkReg(0);

   Reg#(UInt#(32)) recs    <- mkReg(0);
   Reg#(UInt#(32)) mustOk  <- mkReg(0);
   Reg#(UInt#(32)) okDone  <- mkReg(0);
   Reg#(UInt#(32)) over    <- mkReg(0);
   Reg#(UInt#(32)) overErr <- mkReg(0);
   Reg#(UInt#(32)) aborts  <- mkReg(0);
   Reg#(UInt#(32)) halfRd  <- mkReg(0);
   Reg#(UInt#(32)) bytesOut <- mkReg(0);
   Reg#(UInt#(32)) bad     <- mkReg(0);
   Reg#(UInt#(32)) maxDec  <- mkReg(0);
   Reg#(UInt#(32)) maxDecV <- mkReg(0);

   rule tick; cyc <= cyc + 1; rnd.next; endrule

   Bool pause = rnd.value[2:0] == 0;           // ~1 cycle in 8: do nothing
   Addr rawBase  = p + 7;
   Addr dataBase = p + 7 + zeroExtend(total);
   Bool halfRead = recs % 5 == 4;

   function Action note(String what, UInt#(32) got, UInt#(32) want) = action
      if (bad < 5)
         $display("  MISMATCH symbol %0d (version %0d, level field %0d, status %0d): %s got %0d want %0d",
                  recs, ver, lvl, status, what, got, want);
   endaction;

   rule readHeader (phase == ReadHdr);
      Bit#(8) v = vec.sub(p);
      if (v == 0) phase <= Finish;
      else begin
         ver    <= unpack(truncate(v));
         lvl    <= truncate(vec.sub(p + 1));
         status <= vec.sub(p + 2);
         recBad  <= False;
         aborted <= False;
         phase   <= ReadHdr2;
      end
   endrule

   rule readHeader2 (phase == ReadHdr2);           // (the file has only 5 read ports)
      total <= unpack(truncate({vec.sub(p + 3), vec.sub(p + 4)}));
      tdata <= unpack(truncate({vec.sub(p + 5), vec.sub(p + 6)}));
      phase <= Configure;
   endrule

   rule configure (phase == Configure);
      BlockParams bp = blockParams(ver, lvl);
      if (unpack(pack(bp.total)) != total || unpack(pack(bp.totalData)) != tdata) begin
         recBad <= True;
         note("QRTables total vs segno", unpack(zeroExtend(pack(bp.total))), zeroExtend(total));
      end
      dut.configure(BackendConfig { version: ver, levelField: lvl, mask: 0, params: bp });
      i     <= 0;
      phase <= Send;
   endrule

   rule send (phase == Send && !pause);
      if (recs % 7 == 3 && !aborted && i == total / 2) begin
         phase <= AbortReset;                       // abort in the middle
      end
      else begin
         dut.putRawByte(vec.sub(rawBase + zeroExtend(i)));
         if (i + 1 == total) begin
            tStart <= cyc;
            phase  <= WaitDone;
         end
         i <= i + 1;
      end
   endrule

   rule abortReset (phase == AbortReset);
      dut.reset;
      aborted <= True;
      aborts  <= aborts + 1;
      phase   <= Configure;                         // start the same symbol again
   endrule

   (* descending_urgency = "waitDone, timeout" *)
   rule waitDone (phase == WaitDone && (dut.isReady || dut.isError));
      UInt#(32) dec = cyc - tStart;
      if (dec > maxDec) begin maxDec <= dec; maxDecV <= zeroExtend(ver); end
      Bool wrong = recBad;
      if (dut.isReady && dut.isError) begin wrong = True; note("isReady and isError both", 1, 0); end
      i <= 0;
      if (status == 0) begin
         mustOk <= mustOk + 1;
         if (dut.isError) begin
            wrong = True;  note("isError on a fixable symbol", 1, 0);
            phase <= EndRec;
         end
         else phase <= Read;
      end
      else begin
         over <= over + 1;
         if (dut.isError) begin overErr <= overErr + 1; phase <= EndRec; end
         else begin
            // RS may land on another codeword, but for these symbols the
            // chance is below 1 in a million -- treat it as a bug.
            wrong = True;  note("no isError with > t errors in a block", 0, 1);
            phase <= Read;
         end
      end
      recBad <= wrong;
   endrule

   rule timeout (phase == WaitDone && cyc - tStart > 200000);
      recBad <= True;
      note("no isReady/isError after 200000 cycles", 0, 1);
      phase <= EndRec;
   endrule

   rule readByte (phase == Read && !pause);
      let b <- dut.getCorrectedByte;
      Bit#(8) want = vec.sub(dataBase + zeroExtend(i));
      if (status == 0 && b != want) begin
         recBad <= True;
         note("data byte", unpack(zeroExtend(b)), unpack(zeroExtend(want)));
      end
      bytesOut <= bytesOut + 1;
      Bool stopHalf = halfRead && i + 1 == tdata / 2;
      if (i + 1 == tdata || stopHalf) phase <= EndRec;
      if (stopHalf) halfRd <= halfRd + 1;
      i <= i + 1;
   endrule

   rule endRec (phase == EndRec);
      dut.reset;
      if (recBad) bad <= bad + 1;
      if (status == 0 && !recBad) okDone <= okDone + 1;
      recs  <= recs + 1;
      p     <= p + 7 + zeroExtend(total) + zeroExtend(tdata);
      phase <= ReadHdr;
   endrule

   rule finish (phase == Finish);
      $display("QRBlocks: %0d symbols: %0d must decode -> %0d decoded exactly; %0d with a block beyond t -> %0d gave isError",
               recs, mustOk, okDone, over, overErr);
      $display("abuse: %0d resets in the middle of the input, %0d resets after half the output; %0d data bytes read",
               aborts, halfRd, bytesOut);
      $display("decode time (last raw byte -> ready/error): at most %0d cycles (version %0d)", maxDec, maxDecV);
      $display("symbols with a mismatch: %0d", bad);
      if (recs == 0)     $display("RESULT: FAIL (no vectors read -- is blocks_vectors.hex here?)");
      else if (bad == 0) $display("RESULT: PASS");
      else               $display("RESULT: FAIL");
      $finish(0);
   endrule
endmodule

endpackage
