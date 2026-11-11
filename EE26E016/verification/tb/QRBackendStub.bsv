// QRBackendStub.bsv -- NOT the real backend (Person B).  A stand-in with the
// agreed QRBackend interface v1, so Person A can build the top level now.
// It does NO error correction and NO de-interleaving: it passes on the first
// cfg.params.totalData raw bytes and drops the rest.  That is right only for
// UNDAMAGED symbols with ONE block (e.g. the 21x21 sample).  The real module
// mkQRBlocks will replace it with the same interface.
package QRBackendStub;

import FIFOF           :: *;
import QRTables        :: *;
import QRInternalTypes :: *;

(* synthesize *)
module mkQRBackendStub (QRBackend);
   Reg#(BackendState) state     <- mkReg(BACKEND_IDLE);
   Reg#(ByteIdx)      count     <- mkReg(0);      // raw bytes received
   Reg#(ByteIdx)      total     <- mkReg(0);
   Reg#(ByteIdx)      totalData <- mkReg(0);
   FIFOF#(Bit#(8))    outQ      <- mkSizedFIFOF(4);

   method Action configure(BackendConfig cfg) if (state == BACKEND_IDLE);
      total     <= unpack(pack(cfg.params.total));
      totalData <= unpack(pack(cfg.params.totalData));
      count     <= 0;
      state     <= BACKEND_RECEIVING;
   endmethod

   method Action putRawByte(Bit#(8) b) if (state == BACKEND_RECEIVING && outQ.notFull);
      if (count < totalData) outQ.enq(b);               // data byte: pass on
      if (count + 1 == total) state <= BACKEND_READY;   // implicit end (decision 2)
      count <= count + 1;
   endmethod

   method Bool isError = (state == BACKEND_ERROR);       // the stub never fails
   // Ready once every raw byte is in.  (The stub forwards data bytes early;
   // the real module will hold them until all blocks are corrected.)
   method Bool isReady = (state == BACKEND_READY);

   method ActionValue#(Bit#(8)) getCorrectedByte();     // ready when outQ has a byte
      outQ.deq;
      return outQ.first;
   endmethod

   method Action reset();
      outQ.clear;
      count <= 0;
      state <= BACKEND_IDLE;
   endmethod
endmodule

endpackage
