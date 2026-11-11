// Default build = the fast (R4) backend that was synthesised and placed. -D QR_NO_FAST gives the old Day 8 version.
`ifndef QR_NO_FAST
`ifndef QR_FAST
`define QR_FAST
`endif
`endif
// QRBlocks.bsv -- the real QR backend (Person B, RTL).  Replaces QRBackendStub
// with the same interface (QRBackend, interface v1 in QRInternalTypes.bsv).
//
// What it does, in 3 phases:
//   1. RECEIVE: take the raw bytes in the order the front end reads them
//      (interleaved: data byte 0 of every block, data byte 1 of every block,
//      ..., then check byte 0 of every block, ...).  Each byte is written
//      straight to its place in a byte store that is kept BLOCK BY BLOCK
//      ("de-interleaving" = choosing the right address).
//   2. DECODE: for each block in turn: syndromes -> Berlekamp-Massey ->
//      Chien/Forney (QRRS.bsv), then XOR the fixes into the store.  If any
//      block cannot be fixed -> ERROR (sticky until reset).
//   3. READY: hand out only the DATA bytes, block 0 first.
//
// Block layout (spec / QRTables.blockParams):
//   n1 blocks with d1 data bytes, then n2 blocks with d1+1 data bytes;
//   every block has ecLen check bytes.  In the store, block b starts at
//   base(b) = b*(d1+ecLen) + max(0, b-n1).
//
// The 4 action methods only put a note on a wire.  Small rules (one per
// state) then do the work, so "reset wins" is simple and there are no
// method/rule conflicts.  The decode steps are separate rules that only
// run in the DECODING state.
package QRBlocks;

import Vector          :: *;
import RegFile         :: *;
import QRTables        :: *;
import QRInternalTypes :: *;
import QRRS            :: *;

typedef enum { DInit, DFeed, DStartBM, DWaitBM, DStartCF, DWaitCF, DFix, DNext }
        DecStep deriving (Bits, Eq, FShow);

// ---------------------------------------------------------------------------
// Two versions of mkQRBlocks, chosen when compiling:
//   -D QR_FAST       : R4: every store read and write goes through registers
//                      (1.5 ns trial: store/syndrome paths 2.3 ns)
//   -D QR_STORE_PIPE : store with registered addresses and a registered output
//                      byte (found by the first full-backend synthesis: the
//                      store paths were 0.31 ns too slow at 1.0 ns)
//   no flag          : the Day 8 version (R0..R4 runs)
// Same interface, same results; the piped version needs a few more clocks.
// ---------------------------------------------------------------------------
`ifdef QR_FAST
// ===========================================================================
// R4 "fast" version (-D QR_FAST): every store access goes through registers.
// Found by the 1.5 ns trial synthesis (R3 front end + R4 BM + store pipe):
// the store write data/enable and the syndrome input both came from a store
// READ whose address was worked out in the same clock (from n1/dataLen), so
//   n1_reg -> address -> 3706:1 read -> XOR -> all 29,648 store bits  = 2.32 ns
//   n1_reg -> address -> 3706:1 read -> syndrome update                = 2.31 ns
// Here:
//   * WRITE stage: rules only post (address, byte) on a wire; ONE always-on
//     rule writes the store next clock from registers wrA/wrD.
//   * READ stage: rules only post (who, address); ONE always-on rule reads
//     the store from register rdA into register rdD.  A read asked for in
//     clock t is in rdD in clock t+2 (tag tells who asked).
//   * output: a 4-byte buffer filled by reads ahead; getCorrectedByte returns
//     a buffer register.
// Same interface and results; a few more clocks per block and per fix.
// ===========================================================================
typedef enum { RdFeed, RdFix, RdOut } RdWho deriving (Bits, Eq, FShow);

(* synthesize *)
module mkQRBlocks (QRBackend);
   RegFile#(ByteIdx, Bit#(8)) store <- mkRegFile(0, 3705);

   Reg#(BackendState) state <- mkReg(BACKEND_IDLE);

   // block layout of this symbol
   Reg#(UInt#(5))  ec       <- mkReg(0);
   Reg#(UInt#(7))  n1       <- mkReg(0);
   Reg#(UInt#(7))  d1       <- mkReg(0);
   Reg#(UInt#(7))  nb       <- mkReg(0);
   Reg#(Bool)      hasLong  <- mkReg(False);
   Reg#(ByteIdx)   total    <- mkReg(0);
   Reg#(ByteIdx)   totalData <- mkReg(0);
   Reg#(ByteIdx)   baseN1   <- mkReg(0);

   function UInt#(8) dataLen(UInt#(7) b) = zeroExtend(d1) + ((b < n1) ? 0 : 1);
   function UInt#(8) blockLen(UInt#(7) b) = dataLen(b) + zeroExtend(ec);

   // ---- receive ----
   Reg#(Bool)      inEc     <- mkReg(False);
   Reg#(UInt#(8))  row      <- mkReg(0);
   Reg#(UInt#(7))  rb       <- mkReg(0);
   Reg#(ByteIdx)   rbase    <- mkReg(0);
   Reg#(ByteIdx)   rcount   <- mkReg(0);
   Reg#(ByteIdx)   rawAddrR <- mkReg(0);
   Reg#(Bool)      lastIn   <- mkReg(False);

   // ---- store write stage ----
   RWire#(Tuple2#(ByteIdx, Bit#(8))) wrReqW <- mkRWire;
   Reg#(Bool)      wrV <- mkReg(False);
   Reg#(ByteIdx)   wrA <- mkReg(0);
   Reg#(Bit#(8))   wrD <- mkReg(0);

   // ---- store read stage ----
   RWire#(Tuple2#(RdWho, ByteIdx)) rdReqW <- mkRWire;
   Reg#(ByteIdx)   rdA   <- mkReg(0);
   Reg#(RdWho)     rdT1  <- mkReg(RdFeed);
   Reg#(Bool)      rdV1  <- mkReg(False);      // rdA holds a request (asked last clock)
   Reg#(Bit#(8))   rdD   <- mkReg(0);
   Reg#(RdWho)     rdT2  <- mkReg(RdFeed);
   Reg#(Bool)      rdV2  <- mkReg(False);      // rdD holds its byte (asked 2 clocks ago)

   // ---- decode ----
   Reg#(DecStep)   dstep  <- mkReg(DInit);
   Reg#(UInt#(7))  blk    <- mkReg(0);
   Reg#(ByteIdx)   base   <- mkReg(0);
   Reg#(UInt#(8))  k      <- mkReg(0);         // feed: bytes asked for
   Reg#(UInt#(8))  kU     <- mkReg(0);         // feed: bytes given to the syndrome unit
   Reg#(ByteIdx)   faddr  <- mkReg(0);
   Reg#(UInt#(5))  fixIdx <- mkReg(0);
   Reg#(UInt#(2))  fph    <- mkReg(0);         // fix phase: 0 address, 1 read, 2 wait, 3 write
   Reg#(ByteIdx)   fixA   <- mkReg(0);
   Reg#(Bit#(8))   fixE   <- mkReg(0);

   // ---- output: read ahead into a 4-byte buffer ----
   Reg#(UInt#(7))  ob     <- mkReg(0);
   Reg#(UInt#(8))  oi     <- mkReg(0);
   Reg#(ByteIdx)   oaddr  <- mkReg(0);
   Reg#(ByteIdx)   oiss   <- mkReg(0);         // data bytes asked for
   Vector#(4, Reg#(Bit#(8))) obuf <- replicateM(mkReg(0));
   Reg#(UInt#(2))  ohead  <- mkReg(0);
   Reg#(UInt#(2))  otail  <- mkReg(0);
   Reg#(UInt#(3))  ocnt   <- mkReg(0);         // bytes in the buffer
   Reg#(UInt#(2))  oinfl  <- mkReg(0);         // reads on the way (at most 2)
   PulseWire       oIssueW <- mkPulseWire;

   // ---- the RS engine ----
   SyndromeUnit syn <- mkSyndromeUnit;
   BMUnit       bm  <- mkBM(syn.syndromes);
   ChienForney  cf  <- mkChienForney;

   PulseWire             resetW <- mkPulseWire;
   RWire#(BackendConfig) cfgW   <- mkRWire;
   RWire#(Bit#(8))       byteW  <- mkRWire;
   PulseWire             deqW   <- mkPulseWire;

   Bool live = !resetW;

   // ---------------- always-on stages ----------------
   (* fire_when_enabled, no_implicit_conditions *)
   rule wrStage;
      if (wrV) store.upd(wrA, wrD);
      case (wrReqW.wget) matches
         tagged Valid {.a, .d}: begin wrA <= a; wrD <= d; end
      endcase
      wrV <= live && isValid(wrReqW.wget);
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule rdStage;
      rdD  <= store.sub(rdA);
      rdT2 <= rdT1;
      rdV2 <= live && rdV1;
      case (rdReqW.wget) matches
         tagged Valid {.who, .a}: begin rdA <= a; rdT1 <= who; end
      endcase
      rdV1 <= live && isValid(rdReqW.wget);
   endrule

   // output buffer: one rule changes it (fill / take / reset)
   Bool oFill = live && state == BACKEND_READY && rdV2 && rdT2 == RdOut;
   (* fire_when_enabled, no_implicit_conditions *)
   rule outBuf;
      if (resetW) begin
         ohead <= 0;  otail <= 0;  ocnt <= 0;  oinfl <= 0;
      end
      else begin
         if (oFill) begin obuf[otail] <= rdD;  otail <= otail + 1; end
         if (deqW) ohead <= ohead + 1;
         ocnt  <= ocnt  + (oFill ? 1 : 0) - (deqW ? 1 : 0);
         oinfl <= oinfl + (oIssueW ? 1 : 0) - (oFill ? 1 : 0);
      end
   endrule

   // ---------------- control ----------------
   (* fire_when_enabled, no_implicit_conditions *)
   rule doReset (resetW);
      state  <= BACKEND_IDLE;
      lastIn <= False;
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule doConfigure (live && state == BACKEND_IDLE &&& cfgW.wget matches tagged Valid .cfg);
      BlockParams p = cfg.params;
      ec        <= p.ecLen;
      n1        <= p.n1;
      d1        <= p.d1;
      nb        <= p.nb;
      hasLong   <= p.n2 != 0;
      total     <= unpack(pack(p.total));
      totalData <= unpack(pack(p.totalData));
      inEc     <= False;
      row      <= 0;
      rb       <= 0;
      rbase    <= 0;
      rcount   <= 0;
      rawAddrR <= 0;
      lastIn   <= False;
      state    <= BACKEND_RECEIVING;
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule calcBase (live && state == BACKEND_RECEIVING);
      UInt#(16) bn1 = zeroExtend(n1) * (zeroExtend(d1) + zeroExtend(ec));
      baseN1 <= truncate(bn1);
   endrule

   // a raw byte: ask the write stage to store it at the address worked out last time
   (* fire_when_enabled, no_implicit_conditions *)
   rule doByte (live && state == BACKEND_RECEIVING && !lastIn &&& byteW.wget matches tagged Valid .b);
      wrReqW.wset(tuple2(rawAddrR, b));
      Bool     nInEc  = inEc;
      UInt#(8) nRow   = row;
      UInt#(7) nRb    = rb;
      ByteIdx  nRbase = rbase;
      if (rb + 1 < nb) begin
         nRb = rb + 1;  nRbase = rbase + zeroExtend(blockLen(rb));
      end
      else if (!inEc && row + 1 < zeroExtend(d1)) begin
         nRow = row + 1;  nRb = 0;  nRbase = 0;
      end
      else if (!inEc && row + 1 == zeroExtend(d1) && hasLong) begin
         nRow = row + 1;  nRb = n1;  nRbase = baseN1;
      end
      else if (!inEc) begin
         nInEc = True;  nRow = 0;  nRb = 0;  nRbase = 0;
      end
      else begin
         nRow = row + 1;  nRb = 0;  nRbase = 0;
      end
      inEc <= nInEc;  row <= nRow;  rb <= nRb;  rbase <= nRbase;
      rawAddrR <= nInEc ? (nRbase + zeroExtend(dataLen(nRb)) + zeroExtend(nRow))
                        : (nRbase + zeroExtend(nRow));
      rcount <= rcount + 1;
      if (rcount + 1 == total) lastIn <= True;
   endrule

   // all raw bytes in (the last one is written next clock) -> decode
   (* fire_when_enabled, no_implicit_conditions *)
   rule doStartDecode (live && state == BACKEND_RECEIVING && lastIn);
      state <= BACKEND_DECODING;
      dstep <= DInit;
      blk   <= 0;
      base  <= 0;
   endrule

   // ===================== decode: one block after another ==================
   Bool decoding = live && state == BACKEND_DECODING;

   rule dInit (decoding && dstep == DInit);
      syn.start(ec);
      k     <= 0;
      kU    <= 0;
      faddr <= base;
      dstep <= DFeed;
   endrule

   // feed = ask for one byte per clock ...
   rule dFeedAsk (decoding && dstep == DFeed && k < blockLen(blk));
      rdReqW.wset(tuple2(RdFeed, faddr));
      faddr <= faddr + 1;
      k     <= k + 1;
   endrule

   // ... and give each byte to the syndrome unit 2 clocks later (from register rdD)
   rule dFeedUse (decoding && dstep == DFeed && rdV2 && rdT2 == RdFeed);
      syn.put(rdD);
      if (kU + 1 == blockLen(blk)) dstep <= DStartBM;
      kU <= kU + 1;
   endrule

   rule dStartBM (decoding && dstep == DStartBM);
      bm.start(syn.syndromes, ec);
      dstep <= DWaitBM;
   endrule

   rule dWaitBM (decoding && dstep == DWaitBM && bm.done);
      if (bm.fail) state <= BACKEND_ERROR;
      else if (bm.errCount == 0) dstep <= DNext;
      else dstep <= DStartCF;
   endrule

   rule dStartCF (decoding && dstep == DStartCF);
      cf.start(bm.lambda, bm.errCount, syn.syndromes, ec, blockLen(blk));
      dstep <= DWaitCF;
   endrule

   rule dWaitCF (decoding && dstep == DWaitCF && cf.done);
      if (cf.fail) state <= BACKEND_ERROR;
      else begin
         fixIdx <= 0;
         fph    <= 0;
         dstep  <= DFix;
      end
   endrule

   // each fix: (0) address, (1) ask to read, (2) wait, (3) XOR and ask to write
   rule dFixAddr (decoding && dstep == DFix && fph == 0);
      match {.pos, .e} = cf.fixes[fixIdx];
      fixA <= base + zeroExtend(pos);
      fixE <= e;
      fph  <= 1;
   endrule

   rule dFixRead (decoding && dstep == DFix && fph == 1);
      rdReqW.wset(tuple2(RdFix, fixA));
      fph <= 2;
   endrule

   rule dFixWait (decoding && dstep == DFix && fph == 2);
      fph <= 3;
   endrule

   rule dFixWrite (decoding && dstep == DFix && fph == 3 && rdV2 && rdT2 == RdFix);
      wrReqW.wset(tuple2(fixA, rdD ^ fixE));
      fph <= 0;
      if (fixIdx + 1 == cf.fixCount) dstep <= DNext;
      fixIdx <= fixIdx + 1;
   endrule

   rule dNext (decoding && dstep == DNext);
      if (blk + 1 == nb) begin
         state <= BACKEND_READY;
         ob    <= 0;
         oi    <= 0;
         oaddr <= 0;
         oiss  <= 0;
      end
      else begin
         base  <= base + zeroExtend(blockLen(blk));
         blk   <= blk + 1;
         dstep <= DInit;
      end
   endrule

   // ===================== output: read data bytes ahead ====================
   rule outAsk (live && state == BACKEND_READY && oiss < totalData
                && zeroExtend(ocnt) + zeroExtend(oinfl) < UInt#(4)'(4));
      rdReqW.wset(tuple2(RdOut, oaddr));
      oIssueW.send;
      if (oi + 1 == dataLen(ob)) begin           // next block: skip its check bytes
         ob <= ob + 1;  oi <= 0;
         oaddr <= oaddr + 1 + zeroExtend(ec);
      end
      else begin
         oi <= oi + 1;
         oaddr <= oaddr + 1;
      end
      oiss <= oiss + 1;
   endrule

   // ===================== the interface =====================================
   method Action configure(BackendConfig cfg) if (state == BACKEND_IDLE);
      cfgW.wset(cfg);
   endmethod

   method Action putRawByte(Bit#(8) b) if (state == BACKEND_RECEIVING && !lastIn);
      byteW.wset(b);
   endmethod

   method Bool isError = (state == BACKEND_ERROR);
   method Bool isReady = (state == BACKEND_READY);

   method ActionValue#(Bit#(8)) getCorrectedByte() if (state == BACKEND_READY && ocnt != 0);
      deqW.send;
      return obuf[ohead];
   endmethod

   method Action reset();
      resetW.send;
   endmethod
endmodule

`else
`ifdef QR_STORE_PIPE
(* synthesize *)
module mkQRBlocks (QRBackend);
   // ---- the byte store: up to 3706 bytes (version 40-L) ----
   RegFile#(ByteIdx, Bit#(8)) store <- mkRegFile(0, 3705);

   Reg#(BackendState) state <- mkReg(BACKEND_IDLE);

   // block layout of this symbol
   Reg#(UInt#(5))  ec       <- mkReg(0);
   Reg#(UInt#(7))  n1       <- mkReg(0);
   Reg#(UInt#(7))  d1       <- mkReg(0);
   Reg#(UInt#(7))  nb       <- mkReg(0);
   Reg#(Bool)      hasLong  <- mkReg(False);
   Reg#(ByteIdx)   total    <- mkReg(0);
   Reg#(ByteIdx)   totalData <- mkReg(0);
   Reg#(ByteIdx)   baseN1   <- mkReg(0);       // base(n1), made by calcBase

   function UInt#(8) dataLen(UInt#(7) b) = zeroExtend(d1) + ((b < n1) ? 0 : 1);
   function UInt#(8) blockLen(UInt#(7) b) = dataLen(b) + zeroExtend(ec);

   // ---- receive: counters + the address of the NEXT byte (registered) ----
   Reg#(Bool)      inEc     <- mkReg(False);
   Reg#(UInt#(8))  row      <- mkReg(0);
   Reg#(UInt#(7))  rb       <- mkReg(0);
   Reg#(ByteIdx)   rbase    <- mkReg(0);
   Reg#(ByteIdx)   rcount   <- mkReg(0);
   Reg#(ByteIdx)   rawAddrR <- mkReg(0);       // NEW: next byte's store address
   Reg#(Bool)      lastIn   <- mkReg(False);   // NEW: all raw bytes taken
   // one-byte write buffer: the store is written one clock after putRawByte
   Reg#(Bool)      pendV    <- mkReg(False);
   Reg#(ByteIdx)   pendA    <- mkReg(0);
   Reg#(Bit#(8))   pendB    <- mkReg(0);

   // ---- decode ----
   Reg#(DecStep)   dstep  <- mkReg(DInit);
   Reg#(UInt#(7))  blk    <- mkReg(0);
   Reg#(ByteIdx)   base   <- mkReg(0);
   Reg#(UInt#(8))  k      <- mkReg(0);
   Reg#(ByteIdx)   faddr  <- mkReg(0);         // NEW: feed address (just +1)
   Reg#(UInt#(5))  fixIdx <- mkReg(0);
   Reg#(Bool)      fixWr  <- mkReg(False);     // NEW: fix in 2 clocks (address, then write)
   Reg#(ByteIdx)   fixA   <- mkReg(0);
   Reg#(Bit#(8))   fixE   <- mkReg(0);

   // ---- output: address register + the byte already read (registered) ----
   Reg#(UInt#(7))  ob      <- mkReg(0);
   Reg#(UInt#(8))  oi      <- mkReg(0);
   Reg#(ByteIdx)   oaddr   <- mkReg(0);
   Reg#(ByteIdx)   ocount  <- mkReg(0);
   Reg#(Bit#(8))   outByte <- mkReg(0);        // NEW: getCorrectedByte returns this

   // ---- the RS engine for one block ----
   SyndromeUnit syn <- mkSyndromeUnit;
   BMUnit       bm  <- mkBM(syn.syndromes);    // R0, R2 or R4 version (QRRS.bsv)
   ChienForney  cf  <- mkChienForney;

   PulseWire             resetW <- mkPulseWire;
   RWire#(BackendConfig) cfgW   <- mkRWire;
   RWire#(Bit#(8))       byteW  <- mkRWire;
   PulseWire             deqW   <- mkPulseWire;

   Bool live = !resetW;

   (* fire_when_enabled, no_implicit_conditions *)
   rule doReset (resetW);
      state  <= BACKEND_IDLE;
      pendV  <= False;
      lastIn <= False;
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule doConfigure (live && state == BACKEND_IDLE &&& cfgW.wget matches tagged Valid .cfg);
      BlockParams p = cfg.params;
      ec        <= p.ecLen;
      n1        <= p.n1;
      d1        <= p.d1;
      nb        <= p.nb;
      hasLong   <= p.n2 != 0;
      total     <= unpack(pack(p.total));
      totalData <= unpack(pack(p.totalData));
      inEc     <= False;
      row      <= 0;
      rb       <= 0;
      rbase    <= 0;
      rcount   <= 0;
      rawAddrR <= 0;
      lastIn   <= False;
      pendV    <= False;
      state    <= BACKEND_RECEIVING;
   endrule

   // base(n1) = n1 * (d1 + ecLen), from registers (not from the input port).
   // Needed only at data row d1, many clocks after configure.
   (* fire_when_enabled, no_implicit_conditions *)
   rule calcBase (live && state == BACKEND_RECEIVING);
      UInt#(16) bn1 = zeroExtend(n1) * (zeroExtend(d1) + zeroExtend(ec));
      baseN1 <= truncate(bn1);
   endrule

   // a raw byte arrives: write the PREVIOUS one, keep this one for next clock
   (* fire_when_enabled, no_implicit_conditions *)
   rule doByte (live && state == BACKEND_RECEIVING &&& byteW.wget matches tagged Valid .b);
      if (pendV) store.upd(pendA, pendB);
      pendA <= rawAddrR;
      pendB <= b;
      pendV <= True;
      // where does the NEXT byte go?
      Bool     nInEc  = inEc;
      UInt#(8) nRow   = row;
      UInt#(7) nRb    = rb;
      ByteIdx  nRbase = rbase;
      if (rb + 1 < nb) begin
         nRb = rb + 1;  nRbase = rbase + zeroExtend(blockLen(rb));
      end
      else if (!inEc && row + 1 < zeroExtend(d1)) begin
         nRow = row + 1;  nRb = 0;  nRbase = 0;
      end
      else if (!inEc && row + 1 == zeroExtend(d1) && hasLong) begin
         nRow = row + 1;  nRb = n1;  nRbase = baseN1;
      end
      else if (!inEc) begin
         nInEc = True;  nRow = 0;  nRb = 0;  nRbase = 0;
      end
      else begin
         nRow = row + 1;  nRb = 0;  nRbase = 0;
      end
      inEc <= nInEc;  row <= nRow;  rb <= nRb;  rbase <= nRbase;
      rawAddrR <= nInEc ? (nRbase + zeroExtend(dataLen(nRb)) + zeroExtend(nRow))
                        : (nRbase + zeroExtend(nRow));
      rcount <= rcount + 1;
      if (rcount + 1 == total) lastIn <= True;
   endrule

   // no new byte this clock: write the waiting one; after the last -> decode
   (* fire_when_enabled, no_implicit_conditions *)
   rule doDrain (live && state == BACKEND_RECEIVING && pendV && !isValid(byteW.wget));
      store.upd(pendA, pendB);
      pendV <= False;
      if (lastIn) begin
         state <= BACKEND_DECODING;
         dstep <= DInit;
         blk   <= 0;
         base  <= 0;
      end
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule doDeq (live && state == BACKEND_READY && deqW);   // one data byte taken
      ByteIdx na;
      if (oi + 1 == dataLen(ob)) begin                    // next block: skip its check bytes
         ob <= ob + 1;  oi <= 0;
         na = oaddr + 1 + zeroExtend(ec);
      end
      else begin
         oi <= oi + 1;
         na = oaddr + 1;
      end
      oaddr   <= na;
      outByte <= store.sub((ocount + 1 < totalData) ? na : 0);   // read ahead
      ocount  <= ocount + 1;
   endrule

   // ===================== decode: one block after another ==================
   Bool decoding = live && state == BACKEND_DECODING;

   rule dInit (decoding && dstep == DInit);
      syn.start(ec);
      k     <= 0;
      faddr <= base;
      dstep <= DFeed;
   endrule

   rule dFeed (decoding && dstep == DFeed);
      syn.put(store.sub(faddr));
      faddr <= faddr + 1;
      if (k + 1 == blockLen(blk)) dstep <= DStartBM;
      k <= k + 1;
   endrule

   rule dStartBM (decoding && dstep == DStartBM);
      bm.start(syn.syndromes, ec);
      dstep <= DWaitBM;
   endrule

   rule dWaitBM (decoding && dstep == DWaitBM && bm.done);
      if (bm.fail) state <= BACKEND_ERROR;
      else if (bm.errCount == 0) dstep <= DNext;
      else dstep <= DStartCF;
   endrule

   rule dStartCF (decoding && dstep == DStartCF);
      cf.start(bm.lambda, bm.errCount, syn.syndromes, ec, blockLen(blk));
      dstep <= DWaitCF;
   endrule

   rule dWaitCF (decoding && dstep == DWaitCF && cf.done);
      if (cf.fail) state <= BACKEND_ERROR;
      else begin
         fixIdx <= 0;
         fixWr  <= False;
         dstep  <= DFix;
      end
   endrule

   // each fix takes 2 clocks: (1) work out the address, (2) read-XOR-write
   rule dFixAddr (decoding && dstep == DFix && !fixWr);
      match {.pos, .e} = cf.fixes[fixIdx];
      fixA  <= base + zeroExtend(pos);
      fixE  <= e;
      fixWr <= True;
   endrule

   rule dFixWrite (decoding && dstep == DFix && fixWr);
      store.upd(fixA, store.sub(fixA) ^ fixE);
      fixWr <= False;
      if (fixIdx + 1 == cf.fixCount) dstep <= DNext;
      fixIdx <= fixIdx + 1;
   endrule

   rule dNext (decoding && dstep == DNext);
      if (blk + 1 == nb) begin
         state   <= BACKEND_READY;
         ob      <= 0;
         oi      <= 0;
         oaddr   <= 0;
         ocount  <= 0;
         outByte <= store.sub(0);                  // first data byte, read ahead
      end
      else begin
         base  <= base + zeroExtend(blockLen(blk));
         blk   <= blk + 1;
         dstep <= DInit;
      end
   endrule

   // ===================== the interface =====================================
   method Action configure(BackendConfig cfg) if (state == BACKEND_IDLE);
      cfgW.wset(cfg);
   endmethod

   method Action putRawByte(Bit#(8) b) if (state == BACKEND_RECEIVING && !lastIn);
      byteW.wset(b);
   endmethod

   method Bool isError = (state == BACKEND_ERROR);
   method Bool isReady = (state == BACKEND_READY);

   method ActionValue#(Bit#(8)) getCorrectedByte()
         if (state == BACKEND_READY && ocount < totalData);
      deqW.send;
      return outByte;                              // a register: no store path to the port
   endmethod

   method Action reset();
      resetW.send;
   endmethod
endmodule

`else
(* synthesize *)
module mkQRBlocks (QRBackend);
   // ---- the byte store: up to 3706 bytes (version 40-L) ----
   RegFile#(ByteIdx, Bit#(8)) store <- mkRegFile(0, 3705);

   Reg#(BackendState) state <- mkReg(BACKEND_IDLE);

   // block layout of this symbol
   Reg#(UInt#(5))  ec       <- mkReg(0);
   Reg#(UInt#(7))  n1       <- mkReg(0);
   Reg#(UInt#(7))  d1       <- mkReg(0);
   Reg#(UInt#(7))  nb       <- mkReg(0);
   Reg#(Bool)      hasLong  <- mkReg(False);   // n2 > 0
   Reg#(ByteIdx)   total    <- mkReg(0);
   Reg#(ByteIdx)   totalData <- mkReg(0);
   Reg#(ByteIdx)   baseN1   <- mkReg(0);       // base(n1) = n1*(d1+ecLen)

   function UInt#(8) dataLen(UInt#(7) b) = zeroExtend(d1) + ((b < n1) ? 0 : 1);
   function UInt#(8) blockLen(UInt#(7) b) = dataLen(b) + zeroExtend(ec);

   // ---- receive counters (where does the next raw byte go?) ----
   Reg#(Bool)      inEc   <- mkReg(False);     // False: data bytes, True: check bytes
   Reg#(UInt#(8))  row    <- mkReg(0);         // data byte i, or check byte j
   Reg#(UInt#(7))  rb     <- mkReg(0);         // block of the next byte
   Reg#(ByteIdx)   rbase  <- mkReg(0);         // base(rb)
   Reg#(ByteIdx)   rcount <- mkReg(0);         // raw bytes received

   // ---- decode counters ----
   Reg#(DecStep)   dstep  <- mkReg(DInit);
   Reg#(UInt#(7))  blk    <- mkReg(0);
   Reg#(ByteIdx)   base   <- mkReg(0);
   Reg#(UInt#(8))  k      <- mkReg(0);
   Reg#(UInt#(5))  fixIdx <- mkReg(0);

   // ---- output counters ----
   Reg#(UInt#(7))  ob     <- mkReg(0);
   Reg#(ByteIdx)   obase  <- mkReg(0);
   Reg#(UInt#(8))  oi     <- mkReg(0);
   Reg#(ByteIdx)   ocount <- mkReg(0);

   // ---- the RS engine for one block ----
   SyndromeUnit syn <- mkSyndromeUnit;
   BMUnit       bm  <- mkBM(syn.syndromes);   // R0, R2 or R4 version (QRRS.bsv)
   ChienForney  cf  <- mkChienForney;

   // ---- wires from the methods to the main rule ----
   PulseWire             resetW <- mkPulseWire;
   RWire#(BackendConfig) cfgW   <- mkRWire;
   RWire#(Bit#(8))       byteW  <- mkRWire;
   PulseWire             deqW   <- mkPulseWire;

   ByteIdx rawAddr = inEc ? (rbase + zeroExtend(dataLen(rb)) + zeroExtend(row))
                          : (rbase + zeroExtend(row));

   // ===================== method actions: receive, output, reset ==========
   // Each rule has its own state test, and every rule except doReset also
   // needs !resetW, so bsc can see they never fire together -> no conflicts,
   // and reset always wins.
   Bool live = !resetW;

   (* fire_when_enabled, no_implicit_conditions *)
   rule doReset (resetW);
      state <= BACKEND_IDLE;
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule doConfigure (live && state == BACKEND_IDLE &&& cfgW.wget matches tagged Valid .cfg);
      BlockParams p = cfg.params;
      ec        <= p.ecLen;
      n1        <= p.n1;
      d1        <= p.d1;
      nb        <= p.nb;
      hasLong   <= p.n2 != 0;
      total     <= unpack(pack(p.total));
      totalData <= unpack(pack(p.totalData));
      UInt#(16) bn1 = zeroExtend(p.n1) * (zeroExtend(p.d1) + zeroExtend(p.ecLen));
      baseN1    <= truncate(bn1);
      inEc   <= False;
      row    <= 0;
      rb     <= 0;
      rbase  <= 0;
      rcount <= 0;
      state  <= BACKEND_RECEIVING;
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule doByte (live && state == BACKEND_RECEIVING &&& byteW.wget matches tagged Valid .b);
      store.upd(rawAddr, b);
      // where does the NEXT byte go?
      if (rb + 1 < nb) begin                         // next block, same row
         rb    <= rb + 1;
         rbase <= rbase + zeroExtend(blockLen(rb));
      end
      else begin                                     // row finished
         UInt#(8) nextRow = row + 1;
         if (!inEc) begin
            // data rows 0..d1-1 use all blocks; row d1 (only if n2 > 0)
            // uses only the long blocks n1..nb-1
            if (nextRow < zeroExtend(d1)) begin
               row <= nextRow;  rb <= 0;  rbase <= 0;
            end
            else if (nextRow == zeroExtend(d1) && hasLong) begin
               row <= nextRow;  rb <= n1;  rbase <= baseN1;
            end
            else begin                               // data done -> check bytes
               inEc <= True;  row <= 0;  rb <= 0;  rbase <= 0;
            end
         end
         else begin
            row <= nextRow;  rb <= 0;  rbase <= 0;
         end
      end
      rcount <= rcount + 1;
      if (rcount + 1 == total) begin                 // all bytes in: decode
         state <= BACKEND_DECODING;
         dstep <= DInit;
         blk   <= 0;
         base  <= 0;
      end
   endrule

   (* fire_when_enabled, no_implicit_conditions *)
   rule doDeq (live && state == BACKEND_READY && deqW);  // one data byte taken
      if (oi + 1 == dataLen(ob)) begin
         obase <= obase + zeroExtend(blockLen(ob));
         ob    <= ob + 1;
         oi    <= 0;
      end
      else oi <= oi + 1;
      ocount <= ocount + 1;
   endrule

   // ===================== decode: one block after another ==================
   Bool decoding = live && state == BACKEND_DECODING;

   rule dInit (decoding && dstep == DInit);
      syn.start(ec);
      k     <= 0;
      dstep <= DFeed;
   endrule

   rule dFeed (decoding && dstep == DFeed);
      syn.put(store.sub(base + zeroExtend(k)));
      if (k + 1 == blockLen(blk)) dstep <= DStartBM;
      k <= k + 1;
   endrule

   rule dStartBM (decoding && dstep == DStartBM);
      bm.start(syn.syndromes, ec);
      dstep <= DWaitBM;
   endrule

   rule dWaitBM (decoding && dstep == DWaitBM && bm.done);
      if (bm.fail) state <= BACKEND_ERROR;           // more than t errors
      else if (bm.errCount == 0) dstep <= DNext;     // clean block
      else dstep <= DStartCF;
   endrule

   rule dStartCF (decoding && dstep == DStartCF);
      cf.start(bm.lambda, bm.errCount, syn.syndromes, ec, blockLen(blk));
      dstep <= DWaitCF;
   endrule

   rule dWaitCF (decoding && dstep == DWaitCF && cf.done);
      if (cf.fail) state <= BACKEND_ERROR;
      else begin
         fixIdx <= 0;
         dstep  <= DFix;
      end
   endrule

   // XOR one fix per clock into the store
   rule dFix (decoding && dstep == DFix);
      match {.pos, .e} = cf.fixes[fixIdx];
      ByteIdx a = base + zeroExtend(pos);
      store.upd(a, store.sub(a) ^ e);
      if (fixIdx + 1 == cf.fixCount) dstep <= DNext;
      fixIdx <= fixIdx + 1;
   endrule

   rule dNext (decoding && dstep == DNext);
      if (blk + 1 == nb) begin                       // all blocks done
         state  <= BACKEND_READY;
         ob     <= 0;
         obase  <= 0;
         oi     <= 0;
         ocount <= 0;
      end
      else begin
         base  <= base + zeroExtend(blockLen(blk));
         blk   <= blk + 1;
         dstep <= DInit;
      end
   endrule

   // ===================== the interface =====================================
   method Action configure(BackendConfig cfg) if (state == BACKEND_IDLE);
      cfgW.wset(cfg);
   endmethod

   method Action putRawByte(Bit#(8) b) if (state == BACKEND_RECEIVING);
      byteW.wset(b);
   endmethod

   method Bool isError = (state == BACKEND_ERROR);
   method Bool isReady = (state == BACKEND_READY);

   method ActionValue#(Bit#(8)) getCorrectedByte()
         if (state == BACKEND_READY && ocount < totalData);
      deqW.send;
      return store.sub(obase + zeroExtend(oi));
   endmethod

   method Action reset();
      resetW.send;
   endmethod
endmodule

`endif
`endif

endpackage
