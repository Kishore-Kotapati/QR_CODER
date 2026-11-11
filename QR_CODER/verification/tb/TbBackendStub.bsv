// TbBackendStub.bsv -- does interface v1 compile and behave?
// Sends the sample's 26 raw bytes (version 1-M), expects the 16 data bytes
// back under back-pressure, checks isReady/isError, then tests reset in the
// middle of a second run.
package TbBackendStub;

import Vector          :: *;
import QRTables        :: *;
import QRInternalTypes :: *;
import QRBackendStub   :: *;

(* synthesize *)
module mkTbBackendStub (Empty);
   QRBackend dut <- mkQRBackendStub;

   // 16 data bytes of the sample (from front_ref.py) + 10 placeholder check bytes
   Integer d[16] = {'h20,'h93,'h0b,'h78,'hd1,'h71,'h13,'h26,'hd5,'h77,'h38,'hec,'h44,'hfe,'h00,'hec};
   Vector#(26, Bit#(8)) raw = newVector;
   for (Integer i = 0; i < 26; i = i + 1)
      raw[i] = (i < 16) ? fromInteger(d[i]) : fromInteger(i);

   function BackendConfig cfgFor(UInt#(6) v, Bit#(2) lv) =
      BackendConfig { version: v, levelField: lv, mask: 2, params: blockParams(v, lv) };

   Reg#(UInt#(8))  step   <- mkReg(0);
   Reg#(UInt#(8))  sent   <- mkReg(0);
   Reg#(UInt#(8))  got    <- mkReg(0);
   Reg#(UInt#(8))  errors <- mkReg(0);
   Reg#(UInt#(16)) cycle  <- mkReg(0);

   rule tick; cycle <= cycle + 1; endrule

   rule cfg1 (step == 0);
      dut.configure(cfgFor(1, 2'b00));                 // version 1, level M
      step <= 1;
   endrule
   rule send1 (step == 1 && sent < 26);
      dut.putRawByte(raw[sent]);
      sent <= sent + 1;
   endrule
   rule recv1 (step == 1 && pack(cycle)[2:0] == 0);    // back-pressure: every 8th cycle
      let b <- dut.getCorrectedByte;
      if (b != raw[got]) begin
         $display("MISMATCH byte %0d: got %02h want %02h", got, b, raw[got]);
         errors <= errors + 1;
      end
      got <= got + 1;
      if (got == 15) step <= 2;
   endrule
   rule status2 (step == 2);
      if (!dut.isReady || dut.isError) begin
         $display("STATUS wrong after all bytes: isReady=%0d isError=%0d", dut.isReady, dut.isError);
         errors <= errors + 1;
      end
      step <= 3;
   endrule
   rule reset3 (step == 3);  dut.reset;                    step <= 4; endrule
   rule cfg4   (step == 4);  dut.configure(cfgFor(1, 2'b00)); step <= 5; endrule
   rule send5  (step == 5);  dut.putRawByte('h55);         step <= 6; endrule
   rule reset6 (step == 6);  dut.reset;                    step <= 7; endrule
   rule cfg7   (step == 7);  dut.configure(cfgFor(1, 2'b01)); step <= 8; endrule  // only if idle again
   rule finish (step == 8);
      $display("16 data bytes received, %0d problems, reset+reconfigure OK", errors);
      $display(errors == 0 ? "RESULT: PASS" : "RESULT: FAIL");
      $finish(0);
   endrule
   rule timeout (cycle > 2000);
      $display("RESULT: FAIL (timeout at step %0d)", step);
      $finish(0);
   endrule
endmodule

endpackage
