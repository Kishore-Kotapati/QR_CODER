// Interfaces shared by the decoder and the testbench.
package QRTypes;

// Row / column index, and side length.  Version 40 is 177 modules per side.
typedef UInt#(8) Coord;

// One decoded byte.  'last' marks the final byte of the message.
typedef struct {
   Bit#(8) data;
   Bool    last;
} OutByte deriving (Bits, Eq, FShow);

// The decoder's port to the bitmap memory.  The testbench holds the bitmap
// and serves the decoder's reads through this port:
//   - req() is ready in a cycle in which the decoder wants a module.  The
//     testbench takes the (row, col) in that same cycle.
//   - resp(b) is called by the testbench in every cycle.  It carries the
//     module for the most recent request taken in an earlier cycle, so the
//     answer to a request taken in cycle k arrives in cycle k+1 and holds
//     until the answer to the next request replaces it.
//   - 1 = dark module, 0 = light.  Row 0 is the top, column 0 is the left.
//     Reads outside the matrix return 0.
interface MemPort;
   method ActionValue#(Tuple2#(Coord, Coord)) req();
   (* always_ready, always_enabled *)
   method Action resp(Bit#(1) b);
endinterface

// The decoder.
//   start(size)  : the matrix is loaded; size is the side length in modules.
//                  The latency clock starts on this cycle.  May be called
//                  again once the previous decode has finished or failed.
//   getByte()    : decoded bytes in order.  The byte with last=True stops
//                  the latency clock.
//   failed()     : the symbol could not be decoded (bad size, unreadable
//                  format information, too many errors, malformed payload).
//                  Bytes delivered before failed() rose must be discarded.
//   done()       : decoding succeeded and every byte has been taken.  Only
//                  needed to recognise an empty message, which has no byte
//                  to carry the 'last' flag.
//   mem          : the port to the bitmap memory.
interface QRDecoder;
   method Action                start(Coord size);
   method ActionValue#(OutByte) getByte();
   method Bool                  failed();
   method Bool                  done();
   interface MemPort            mem;
endinterface

endpackage
