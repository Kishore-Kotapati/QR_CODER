// QRInternalTypes.bsv -- shared types and the Frontend <-> Backend interface.
// Draft by Person A (Rishi), 23 Oct 2026 (docs/INTERFACES.md).
// Reviewed by Person B (Kishore), 25 Oct 2026: same types and method names;
// open decisions 1-4 answered in docs/INTERFACES.md section 6.
// Version 1.  Change only when BOTH agree, then bump the version.
package QRInternalTypes;

import QRTypes  :: *;
import QRTables :: *;

// Raw 2-bit level field from the format information (spec 1.2):
// 01 = L, 00 = M, 11 = Q, 10 = H.  Passed unchanged to blockParams().
typedef Bit#(2) RawLevel;

// Mask pattern 0..7
typedef UInt#(3) MaskPattern;

// Index of a byte in the whole symbol: up to 3706 bytes -> 12 bits
typedef UInt#(12) ByteIdx;

// Sent by the front end once per symbol, before any raw byte.
typedef struct {
   UInt#(6)     version;       // 1..40
   RawLevel     levelField;    // raw format field
   MaskPattern  mask;          // 0..7 (the backend does not need it; kept for traces)
   BlockParams  params;        // = blockParams(version, levelField)
} BackendConfig deriving (Bits, Eq, FShow);

// Backend state (for debugging and traces; the interface below does not depend on it)
typedef enum {
   BACKEND_IDLE,       // waiting for configure
   BACKEND_RECEIVING,  // taking raw bytes
   BACKEND_DECODING,   // de-interleaving and correcting
   BACKEND_READY,      // all blocks corrected; streaming data bytes
   BACKEND_ERROR       // some block could not be corrected
} BackendState deriving (Bits, Eq, FShow);

// Provided by Person B's mkQRBlocks, used by Person A's mkQRDecoder.
interface QRBackend;
   // 1. Once per symbol.  Ready only in BACKEND_IDLE (call reset first).
   method Action configure(BackendConfig cfg);
   // 2. One raw byte, zigzag (interleaved) order, byte 0 first, exactly
   //    cfg.params.total calls.  Not ready while the backend cannot take it.
   method Action putRawByte(Bit#(8) b);
   // 3. Status.  isError: some block uncorrectable (sticky until reset).
   //    isReady: all blocks corrected (sticky until reset).
   method Bool isError();
   method Bool isReady();
   // 4. One corrected DATA byte, block 0 first, no check bytes, exactly
   //    cfg.params.totalData bytes.  Ready only when isReady and a byte is left.
   method ActionValue#(Bit#(8)) getCorrectedByte();
   // 5. Clear everything; back to BACKEND_IDLE.  Always ready.
   //    If called in the same cycle as another method, reset wins.
   method Action reset();
endinterface

endpackage
