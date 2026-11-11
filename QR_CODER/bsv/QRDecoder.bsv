// Package QRDecoder: Top-level QR Code Decoder Controller
//
// Author: Person A (Top-Level Controller RTL)
// Authority: CADForVLSI_2026_Project_Spec.pdf Section 2-4, QRTypes.bsv, docs/INTERFACES.md

package QRDecoder;

import QRTypes::*;
import QRTables::*;
import QRInternalTypes::*;
import QRFrontEnd::*;
import QRPayload::*;
import QRBlocks::*; // Person B's complete Backend

typedef enum {
   DEC_IDLE,
   DEC_ACTIVE,
   DEC_DONE,
   DEC_FAILED
} DecState deriving (Bits, Eq, FShow);

(* synthesize *)
module mkQRDecoder (QRDecoder);

   Reg#(DecState) state          <- mkReg(DEC_IDLE);
   Reg#(Bool)     payloadStarted <- mkReg(False);

   // Instantiate Person B's backend (QRBlocks)
   QRBackend backend <- mkQRBlocks;

   // Instantiate Person A's Frontend and Payload modules
   QRFrontEnd frontend <- mkQRFrontEnd(backend);
   QRPayload  payload  <- mkQRPayload(backend);

   // Sticky status flags per C2
   Reg#(Bool) isFailed <- mkReg(False);
   Reg#(Bool) isDone   <- mkReg(False);

   // ----------------------------------------------------------------------
   // Start payload parser once frontend configuration is valid
   // ----------------------------------------------------------------------
   (* descending_urgency = "startPayload, monitorFailure, monitorDone" *)
   rule startPayload (state == DEC_ACTIVE && !payloadStarted && frontend.isConfigValid());
      let cfg = frontend.getConfig();
      payload.start(cfg.version, cfg.params.totalData);
      payloadStarted <= True;
   endrule

   // ----------------------------------------------------------------------
   // Monitor failure across all subsystems
   // Guard includes failure conditions so it only fires when an actual failure occurs
   // ----------------------------------------------------------------------
   rule monitorFailure (state == DEC_ACTIVE && !isFailed &&
                        (frontend.failed() || backend.isError() || payload.failed()));
      isFailed <= True;
      state <= DEC_FAILED;
   endrule

   // ----------------------------------------------------------------------
   // Monitor completion
   // ----------------------------------------------------------------------
   rule monitorDone (state == DEC_ACTIVE && !isFailed && !isDone && payload.done());
      isDone <= True;
      state <= DEC_DONE;
   endrule

   // ----------------------------------------------------------------------
   // Public Interface Methods (Spec Section 3 & 4.3)
   // ----------------------------------------------------------------------
   method Action start(Coord size) if (state == DEC_IDLE || state == DEC_DONE || state == DEC_FAILED);
      isFailed <= False;
      isDone <= False;
      payloadStarted <= False;

      backend.reset();
      payload.reset();
      frontend.start(size);
      state <= DEC_ACTIVE;
   endmethod

   method ActionValue#(OutByte) getByte() if (!isFailed);
      let b <- payload.getByte();
      return b;
   endmethod

   method Bool failed = isFailed;
   method Bool done   = isDone;

   interface MemPort mem;
      method ActionValue#(Tuple2#(Coord, Coord)) req() if (state == DEC_ACTIVE);
         let r <- frontend.mem.req();
         return r;
      endmethod
      method Action resp(Bit#(1) b);
         frontend.mem.resp(b);
      endmethod
   endinterface

endmodule

endpackage
