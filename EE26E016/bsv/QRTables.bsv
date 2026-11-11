// Lookup tables for QR Code versions 1-40 (ISO/IEC 18004).
package QRTables;

import Vector::*;

// Block structure of one (version, level) combination.
//   n1 blocks hold d1 data bytes, n2 blocks hold d1+1 data bytes,
//   every block has ecLen check bytes.  nb = n1+n2.
typedef struct {
   UInt#(5)  ecLen;
   UInt#(7)  n1;
   UInt#(7)  d1;
   UInt#(7)  n2;
   UInt#(7)  nb;
   UInt#(12) totalData;   // data bytes in the whole symbol
   UInt#(12) total;       // data + check bytes in the whole symbol
} BlockParams deriving (Bits, Eq, FShow);

// levelField is the raw 2-bit field from the format information:
//   1 = L, 0 = M, 3 = Q, 2 = H.
function BlockParams blockParams(UInt#(6) version, Bit#(2) levelField);
   BlockParams p = BlockParams { ecLen: 0, n1: 0, d1: 0, n2: 0, nb: 0, totalData: 0, total: 0 };
   case ({pack(version), levelField})
      8'd5: p = BlockParams { ecLen: 7, n1: 1, d1: 19, n2: 0, nb: 1, totalData: 19, total: 26 };  // 1-L
      8'd4: p = BlockParams { ecLen: 10, n1: 1, d1: 16, n2: 0, nb: 1, totalData: 16, total: 26 };  // 1-M
      8'd7: p = BlockParams { ecLen: 13, n1: 1, d1: 13, n2: 0, nb: 1, totalData: 13, total: 26 };  // 1-Q
      8'd6: p = BlockParams { ecLen: 17, n1: 1, d1: 9, n2: 0, nb: 1, totalData: 9, total: 26 };  // 1-H
      8'd9: p = BlockParams { ecLen: 10, n1: 1, d1: 34, n2: 0, nb: 1, totalData: 34, total: 44 };  // 2-L
      8'd8: p = BlockParams { ecLen: 16, n1: 1, d1: 28, n2: 0, nb: 1, totalData: 28, total: 44 };  // 2-M
      8'd11: p = BlockParams { ecLen: 22, n1: 1, d1: 22, n2: 0, nb: 1, totalData: 22, total: 44 };  // 2-Q
      8'd10: p = BlockParams { ecLen: 28, n1: 1, d1: 16, n2: 0, nb: 1, totalData: 16, total: 44 };  // 2-H
      8'd13: p = BlockParams { ecLen: 15, n1: 1, d1: 55, n2: 0, nb: 1, totalData: 55, total: 70 };  // 3-L
      8'd12: p = BlockParams { ecLen: 26, n1: 1, d1: 44, n2: 0, nb: 1, totalData: 44, total: 70 };  // 3-M
      8'd15: p = BlockParams { ecLen: 18, n1: 2, d1: 17, n2: 0, nb: 2, totalData: 34, total: 70 };  // 3-Q
      8'd14: p = BlockParams { ecLen: 22, n1: 2, d1: 13, n2: 0, nb: 2, totalData: 26, total: 70 };  // 3-H
      8'd17: p = BlockParams { ecLen: 20, n1: 1, d1: 80, n2: 0, nb: 1, totalData: 80, total: 100 };  // 4-L
      8'd16: p = BlockParams { ecLen: 18, n1: 2, d1: 32, n2: 0, nb: 2, totalData: 64, total: 100 };  // 4-M
      8'd19: p = BlockParams { ecLen: 26, n1: 2, d1: 24, n2: 0, nb: 2, totalData: 48, total: 100 };  // 4-Q
      8'd18: p = BlockParams { ecLen: 16, n1: 4, d1: 9, n2: 0, nb: 4, totalData: 36, total: 100 };  // 4-H
      8'd21: p = BlockParams { ecLen: 26, n1: 1, d1: 108, n2: 0, nb: 1, totalData: 108, total: 134 };  // 5-L
      8'd20: p = BlockParams { ecLen: 24, n1: 2, d1: 43, n2: 0, nb: 2, totalData: 86, total: 134 };  // 5-M
      8'd23: p = BlockParams { ecLen: 18, n1: 2, d1: 15, n2: 2, nb: 4, totalData: 62, total: 134 };  // 5-Q
      8'd22: p = BlockParams { ecLen: 22, n1: 2, d1: 11, n2: 2, nb: 4, totalData: 46, total: 134 };  // 5-H
      8'd25: p = BlockParams { ecLen: 18, n1: 2, d1: 68, n2: 0, nb: 2, totalData: 136, total: 172 };  // 6-L
      8'd24: p = BlockParams { ecLen: 16, n1: 4, d1: 27, n2: 0, nb: 4, totalData: 108, total: 172 };  // 6-M
      8'd27: p = BlockParams { ecLen: 24, n1: 4, d1: 19, n2: 0, nb: 4, totalData: 76, total: 172 };  // 6-Q
      8'd26: p = BlockParams { ecLen: 28, n1: 4, d1: 15, n2: 0, nb: 4, totalData: 60, total: 172 };  // 6-H
      8'd29: p = BlockParams { ecLen: 20, n1: 2, d1: 78, n2: 0, nb: 2, totalData: 156, total: 196 };  // 7-L
      8'd28: p = BlockParams { ecLen: 18, n1: 4, d1: 31, n2: 0, nb: 4, totalData: 124, total: 196 };  // 7-M
      8'd31: p = BlockParams { ecLen: 18, n1: 2, d1: 14, n2: 4, nb: 6, totalData: 88, total: 196 };  // 7-Q
      8'd30: p = BlockParams { ecLen: 26, n1: 4, d1: 13, n2: 1, nb: 5, totalData: 66, total: 196 };  // 7-H
      8'd33: p = BlockParams { ecLen: 24, n1: 2, d1: 97, n2: 0, nb: 2, totalData: 194, total: 242 };  // 8-L
      8'd32: p = BlockParams { ecLen: 22, n1: 2, d1: 38, n2: 2, nb: 4, totalData: 154, total: 242 };  // 8-M
      8'd35: p = BlockParams { ecLen: 22, n1: 4, d1: 18, n2: 2, nb: 6, totalData: 110, total: 242 };  // 8-Q
      8'd34: p = BlockParams { ecLen: 26, n1: 4, d1: 14, n2: 2, nb: 6, totalData: 86, total: 242 };  // 8-H
      8'd37: p = BlockParams { ecLen: 30, n1: 2, d1: 116, n2: 0, nb: 2, totalData: 232, total: 292 };  // 9-L
      8'd36: p = BlockParams { ecLen: 22, n1: 3, d1: 36, n2: 2, nb: 5, totalData: 182, total: 292 };  // 9-M
      8'd39: p = BlockParams { ecLen: 20, n1: 4, d1: 16, n2: 4, nb: 8, totalData: 132, total: 292 };  // 9-Q
      8'd38: p = BlockParams { ecLen: 24, n1: 4, d1: 12, n2: 4, nb: 8, totalData: 100, total: 292 };  // 9-H
      8'd41: p = BlockParams { ecLen: 18, n1: 2, d1: 68, n2: 2, nb: 4, totalData: 274, total: 346 };  // 10-L
      8'd40: p = BlockParams { ecLen: 26, n1: 4, d1: 43, n2: 1, nb: 5, totalData: 216, total: 346 };  // 10-M
      8'd43: p = BlockParams { ecLen: 24, n1: 6, d1: 19, n2: 2, nb: 8, totalData: 154, total: 346 };  // 10-Q
      8'd42: p = BlockParams { ecLen: 28, n1: 6, d1: 15, n2: 2, nb: 8, totalData: 122, total: 346 };  // 10-H
      8'd45: p = BlockParams { ecLen: 20, n1: 4, d1: 81, n2: 0, nb: 4, totalData: 324, total: 404 };  // 11-L
      8'd44: p = BlockParams { ecLen: 30, n1: 1, d1: 50, n2: 4, nb: 5, totalData: 254, total: 404 };  // 11-M
      8'd47: p = BlockParams { ecLen: 28, n1: 4, d1: 22, n2: 4, nb: 8, totalData: 180, total: 404 };  // 11-Q
      8'd46: p = BlockParams { ecLen: 24, n1: 3, d1: 12, n2: 8, nb: 11, totalData: 140, total: 404 };  // 11-H
      8'd49: p = BlockParams { ecLen: 24, n1: 2, d1: 92, n2: 2, nb: 4, totalData: 370, total: 466 };  // 12-L
      8'd48: p = BlockParams { ecLen: 22, n1: 6, d1: 36, n2: 2, nb: 8, totalData: 290, total: 466 };  // 12-M
      8'd51: p = BlockParams { ecLen: 26, n1: 4, d1: 20, n2: 6, nb: 10, totalData: 206, total: 466 };  // 12-Q
      8'd50: p = BlockParams { ecLen: 28, n1: 7, d1: 14, n2: 4, nb: 11, totalData: 158, total: 466 };  // 12-H
      8'd53: p = BlockParams { ecLen: 26, n1: 4, d1: 107, n2: 0, nb: 4, totalData: 428, total: 532 };  // 13-L
      8'd52: p = BlockParams { ecLen: 22, n1: 8, d1: 37, n2: 1, nb: 9, totalData: 334, total: 532 };  // 13-M
      8'd55: p = BlockParams { ecLen: 24, n1: 8, d1: 20, n2: 4, nb: 12, totalData: 244, total: 532 };  // 13-Q
      8'd54: p = BlockParams { ecLen: 22, n1: 12, d1: 11, n2: 4, nb: 16, totalData: 180, total: 532 };  // 13-H
      8'd57: p = BlockParams { ecLen: 30, n1: 3, d1: 115, n2: 1, nb: 4, totalData: 461, total: 581 };  // 14-L
      8'd56: p = BlockParams { ecLen: 24, n1: 4, d1: 40, n2: 5, nb: 9, totalData: 365, total: 581 };  // 14-M
      8'd59: p = BlockParams { ecLen: 20, n1: 11, d1: 16, n2: 5, nb: 16, totalData: 261, total: 581 };  // 14-Q
      8'd58: p = BlockParams { ecLen: 24, n1: 11, d1: 12, n2: 5, nb: 16, totalData: 197, total: 581 };  // 14-H
      8'd61: p = BlockParams { ecLen: 22, n1: 5, d1: 87, n2: 1, nb: 6, totalData: 523, total: 655 };  // 15-L
      8'd60: p = BlockParams { ecLen: 24, n1: 5, d1: 41, n2: 5, nb: 10, totalData: 415, total: 655 };  // 15-M
      8'd63: p = BlockParams { ecLen: 30, n1: 5, d1: 24, n2: 7, nb: 12, totalData: 295, total: 655 };  // 15-Q
      8'd62: p = BlockParams { ecLen: 24, n1: 11, d1: 12, n2: 7, nb: 18, totalData: 223, total: 655 };  // 15-H
      8'd65: p = BlockParams { ecLen: 24, n1: 5, d1: 98, n2: 1, nb: 6, totalData: 589, total: 733 };  // 16-L
      8'd64: p = BlockParams { ecLen: 28, n1: 7, d1: 45, n2: 3, nb: 10, totalData: 453, total: 733 };  // 16-M
      8'd67: p = BlockParams { ecLen: 24, n1: 15, d1: 19, n2: 2, nb: 17, totalData: 325, total: 733 };  // 16-Q
      8'd66: p = BlockParams { ecLen: 30, n1: 3, d1: 15, n2: 13, nb: 16, totalData: 253, total: 733 };  // 16-H
      8'd69: p = BlockParams { ecLen: 28, n1: 1, d1: 107, n2: 5, nb: 6, totalData: 647, total: 815 };  // 17-L
      8'd68: p = BlockParams { ecLen: 28, n1: 10, d1: 46, n2: 1, nb: 11, totalData: 507, total: 815 };  // 17-M
      8'd71: p = BlockParams { ecLen: 28, n1: 1, d1: 22, n2: 15, nb: 16, totalData: 367, total: 815 };  // 17-Q
      8'd70: p = BlockParams { ecLen: 28, n1: 2, d1: 14, n2: 17, nb: 19, totalData: 283, total: 815 };  // 17-H
      8'd73: p = BlockParams { ecLen: 30, n1: 5, d1: 120, n2: 1, nb: 6, totalData: 721, total: 901 };  // 18-L
      8'd72: p = BlockParams { ecLen: 26, n1: 9, d1: 43, n2: 4, nb: 13, totalData: 563, total: 901 };  // 18-M
      8'd75: p = BlockParams { ecLen: 28, n1: 17, d1: 22, n2: 1, nb: 18, totalData: 397, total: 901 };  // 18-Q
      8'd74: p = BlockParams { ecLen: 28, n1: 2, d1: 14, n2: 19, nb: 21, totalData: 313, total: 901 };  // 18-H
      8'd77: p = BlockParams { ecLen: 28, n1: 3, d1: 113, n2: 4, nb: 7, totalData: 795, total: 991 };  // 19-L
      8'd76: p = BlockParams { ecLen: 26, n1: 3, d1: 44, n2: 11, nb: 14, totalData: 627, total: 991 };  // 19-M
      8'd79: p = BlockParams { ecLen: 26, n1: 17, d1: 21, n2: 4, nb: 21, totalData: 445, total: 991 };  // 19-Q
      8'd78: p = BlockParams { ecLen: 26, n1: 9, d1: 13, n2: 16, nb: 25, totalData: 341, total: 991 };  // 19-H
      8'd81: p = BlockParams { ecLen: 28, n1: 3, d1: 107, n2: 5, nb: 8, totalData: 861, total: 1085 };  // 20-L
      8'd80: p = BlockParams { ecLen: 26, n1: 3, d1: 41, n2: 13, nb: 16, totalData: 669, total: 1085 };  // 20-M
      8'd83: p = BlockParams { ecLen: 30, n1: 15, d1: 24, n2: 5, nb: 20, totalData: 485, total: 1085 };  // 20-Q
      8'd82: p = BlockParams { ecLen: 28, n1: 15, d1: 15, n2: 10, nb: 25, totalData: 385, total: 1085 };  // 20-H
      8'd85: p = BlockParams { ecLen: 28, n1: 4, d1: 116, n2: 4, nb: 8, totalData: 932, total: 1156 };  // 21-L
      8'd84: p = BlockParams { ecLen: 26, n1: 17, d1: 42, n2: 0, nb: 17, totalData: 714, total: 1156 };  // 21-M
      8'd87: p = BlockParams { ecLen: 28, n1: 17, d1: 22, n2: 6, nb: 23, totalData: 512, total: 1156 };  // 21-Q
      8'd86: p = BlockParams { ecLen: 30, n1: 19, d1: 16, n2: 6, nb: 25, totalData: 406, total: 1156 };  // 21-H
      8'd89: p = BlockParams { ecLen: 28, n1: 2, d1: 111, n2: 7, nb: 9, totalData: 1006, total: 1258 };  // 22-L
      8'd88: p = BlockParams { ecLen: 28, n1: 17, d1: 46, n2: 0, nb: 17, totalData: 782, total: 1258 };  // 22-M
      8'd91: p = BlockParams { ecLen: 30, n1: 7, d1: 24, n2: 16, nb: 23, totalData: 568, total: 1258 };  // 22-Q
      8'd90: p = BlockParams { ecLen: 24, n1: 34, d1: 13, n2: 0, nb: 34, totalData: 442, total: 1258 };  // 22-H
      8'd93: p = BlockParams { ecLen: 30, n1: 4, d1: 121, n2: 5, nb: 9, totalData: 1094, total: 1364 };  // 23-L
      8'd92: p = BlockParams { ecLen: 28, n1: 4, d1: 47, n2: 14, nb: 18, totalData: 860, total: 1364 };  // 23-M
      8'd95: p = BlockParams { ecLen: 30, n1: 11, d1: 24, n2: 14, nb: 25, totalData: 614, total: 1364 };  // 23-Q
      8'd94: p = BlockParams { ecLen: 30, n1: 16, d1: 15, n2: 14, nb: 30, totalData: 464, total: 1364 };  // 23-H
      8'd97: p = BlockParams { ecLen: 30, n1: 6, d1: 117, n2: 4, nb: 10, totalData: 1174, total: 1474 };  // 24-L
      8'd96: p = BlockParams { ecLen: 28, n1: 6, d1: 45, n2: 14, nb: 20, totalData: 914, total: 1474 };  // 24-M
      8'd99: p = BlockParams { ecLen: 30, n1: 11, d1: 24, n2: 16, nb: 27, totalData: 664, total: 1474 };  // 24-Q
      8'd98: p = BlockParams { ecLen: 30, n1: 30, d1: 16, n2: 2, nb: 32, totalData: 514, total: 1474 };  // 24-H
      8'd101: p = BlockParams { ecLen: 26, n1: 8, d1: 106, n2: 4, nb: 12, totalData: 1276, total: 1588 };  // 25-L
      8'd100: p = BlockParams { ecLen: 28, n1: 8, d1: 47, n2: 13, nb: 21, totalData: 1000, total: 1588 };  // 25-M
      8'd103: p = BlockParams { ecLen: 30, n1: 7, d1: 24, n2: 22, nb: 29, totalData: 718, total: 1588 };  // 25-Q
      8'd102: p = BlockParams { ecLen: 30, n1: 22, d1: 15, n2: 13, nb: 35, totalData: 538, total: 1588 };  // 25-H
      8'd105: p = BlockParams { ecLen: 28, n1: 10, d1: 114, n2: 2, nb: 12, totalData: 1370, total: 1706 };  // 26-L
      8'd104: p = BlockParams { ecLen: 28, n1: 19, d1: 46, n2: 4, nb: 23, totalData: 1062, total: 1706 };  // 26-M
      8'd107: p = BlockParams { ecLen: 28, n1: 28, d1: 22, n2: 6, nb: 34, totalData: 754, total: 1706 };  // 26-Q
      8'd106: p = BlockParams { ecLen: 30, n1: 33, d1: 16, n2: 4, nb: 37, totalData: 596, total: 1706 };  // 26-H
      8'd109: p = BlockParams { ecLen: 30, n1: 8, d1: 122, n2: 4, nb: 12, totalData: 1468, total: 1828 };  // 27-L
      8'd108: p = BlockParams { ecLen: 28, n1: 22, d1: 45, n2: 3, nb: 25, totalData: 1128, total: 1828 };  // 27-M
      8'd111: p = BlockParams { ecLen: 30, n1: 8, d1: 23, n2: 26, nb: 34, totalData: 808, total: 1828 };  // 27-Q
      8'd110: p = BlockParams { ecLen: 30, n1: 12, d1: 15, n2: 28, nb: 40, totalData: 628, total: 1828 };  // 27-H
      8'd113: p = BlockParams { ecLen: 30, n1: 3, d1: 117, n2: 10, nb: 13, totalData: 1531, total: 1921 };  // 28-L
      8'd112: p = BlockParams { ecLen: 28, n1: 3, d1: 45, n2: 23, nb: 26, totalData: 1193, total: 1921 };  // 28-M
      8'd115: p = BlockParams { ecLen: 30, n1: 4, d1: 24, n2: 31, nb: 35, totalData: 871, total: 1921 };  // 28-Q
      8'd114: p = BlockParams { ecLen: 30, n1: 11, d1: 15, n2: 31, nb: 42, totalData: 661, total: 1921 };  // 28-H
      8'd117: p = BlockParams { ecLen: 30, n1: 7, d1: 116, n2: 7, nb: 14, totalData: 1631, total: 2051 };  // 29-L
      8'd116: p = BlockParams { ecLen: 28, n1: 21, d1: 45, n2: 7, nb: 28, totalData: 1267, total: 2051 };  // 29-M
      8'd119: p = BlockParams { ecLen: 30, n1: 1, d1: 23, n2: 37, nb: 38, totalData: 911, total: 2051 };  // 29-Q
      8'd118: p = BlockParams { ecLen: 30, n1: 19, d1: 15, n2: 26, nb: 45, totalData: 701, total: 2051 };  // 29-H
      8'd121: p = BlockParams { ecLen: 30, n1: 5, d1: 115, n2: 10, nb: 15, totalData: 1735, total: 2185 };  // 30-L
      8'd120: p = BlockParams { ecLen: 28, n1: 19, d1: 47, n2: 10, nb: 29, totalData: 1373, total: 2185 };  // 30-M
      8'd123: p = BlockParams { ecLen: 30, n1: 15, d1: 24, n2: 25, nb: 40, totalData: 985, total: 2185 };  // 30-Q
      8'd122: p = BlockParams { ecLen: 30, n1: 23, d1: 15, n2: 25, nb: 48, totalData: 745, total: 2185 };  // 30-H
      8'd125: p = BlockParams { ecLen: 30, n1: 13, d1: 115, n2: 3, nb: 16, totalData: 1843, total: 2323 };  // 31-L
      8'd124: p = BlockParams { ecLen: 28, n1: 2, d1: 46, n2: 29, nb: 31, totalData: 1455, total: 2323 };  // 31-M
      8'd127: p = BlockParams { ecLen: 30, n1: 42, d1: 24, n2: 1, nb: 43, totalData: 1033, total: 2323 };  // 31-Q
      8'd126: p = BlockParams { ecLen: 30, n1: 23, d1: 15, n2: 28, nb: 51, totalData: 793, total: 2323 };  // 31-H
      8'd129: p = BlockParams { ecLen: 30, n1: 17, d1: 115, n2: 0, nb: 17, totalData: 1955, total: 2465 };  // 32-L
      8'd128: p = BlockParams { ecLen: 28, n1: 10, d1: 46, n2: 23, nb: 33, totalData: 1541, total: 2465 };  // 32-M
      8'd131: p = BlockParams { ecLen: 30, n1: 10, d1: 24, n2: 35, nb: 45, totalData: 1115, total: 2465 };  // 32-Q
      8'd130: p = BlockParams { ecLen: 30, n1: 19, d1: 15, n2: 35, nb: 54, totalData: 845, total: 2465 };  // 32-H
      8'd133: p = BlockParams { ecLen: 30, n1: 17, d1: 115, n2: 1, nb: 18, totalData: 2071, total: 2611 };  // 33-L
      8'd132: p = BlockParams { ecLen: 28, n1: 14, d1: 46, n2: 21, nb: 35, totalData: 1631, total: 2611 };  // 33-M
      8'd135: p = BlockParams { ecLen: 30, n1: 29, d1: 24, n2: 19, nb: 48, totalData: 1171, total: 2611 };  // 33-Q
      8'd134: p = BlockParams { ecLen: 30, n1: 11, d1: 15, n2: 46, nb: 57, totalData: 901, total: 2611 };  // 33-H
      8'd137: p = BlockParams { ecLen: 30, n1: 13, d1: 115, n2: 6, nb: 19, totalData: 2191, total: 2761 };  // 34-L
      8'd136: p = BlockParams { ecLen: 28, n1: 14, d1: 46, n2: 23, nb: 37, totalData: 1725, total: 2761 };  // 34-M
      8'd139: p = BlockParams { ecLen: 30, n1: 44, d1: 24, n2: 7, nb: 51, totalData: 1231, total: 2761 };  // 34-Q
      8'd138: p = BlockParams { ecLen: 30, n1: 59, d1: 16, n2: 1, nb: 60, totalData: 961, total: 2761 };  // 34-H
      8'd141: p = BlockParams { ecLen: 30, n1: 12, d1: 121, n2: 7, nb: 19, totalData: 2306, total: 2876 };  // 35-L
      8'd140: p = BlockParams { ecLen: 28, n1: 12, d1: 47, n2: 26, nb: 38, totalData: 1812, total: 2876 };  // 35-M
      8'd143: p = BlockParams { ecLen: 30, n1: 39, d1: 24, n2: 14, nb: 53, totalData: 1286, total: 2876 };  // 35-Q
      8'd142: p = BlockParams { ecLen: 30, n1: 22, d1: 15, n2: 41, nb: 63, totalData: 986, total: 2876 };  // 35-H
      8'd145: p = BlockParams { ecLen: 30, n1: 6, d1: 121, n2: 14, nb: 20, totalData: 2434, total: 3034 };  // 36-L
      8'd144: p = BlockParams { ecLen: 28, n1: 6, d1: 47, n2: 34, nb: 40, totalData: 1914, total: 3034 };  // 36-M
      8'd147: p = BlockParams { ecLen: 30, n1: 46, d1: 24, n2: 10, nb: 56, totalData: 1354, total: 3034 };  // 36-Q
      8'd146: p = BlockParams { ecLen: 30, n1: 2, d1: 15, n2: 64, nb: 66, totalData: 1054, total: 3034 };  // 36-H
      8'd149: p = BlockParams { ecLen: 30, n1: 17, d1: 122, n2: 4, nb: 21, totalData: 2566, total: 3196 };  // 37-L
      8'd148: p = BlockParams { ecLen: 28, n1: 29, d1: 46, n2: 14, nb: 43, totalData: 1992, total: 3196 };  // 37-M
      8'd151: p = BlockParams { ecLen: 30, n1: 49, d1: 24, n2: 10, nb: 59, totalData: 1426, total: 3196 };  // 37-Q
      8'd150: p = BlockParams { ecLen: 30, n1: 24, d1: 15, n2: 46, nb: 70, totalData: 1096, total: 3196 };  // 37-H
      8'd153: p = BlockParams { ecLen: 30, n1: 4, d1: 122, n2: 18, nb: 22, totalData: 2702, total: 3362 };  // 38-L
      8'd152: p = BlockParams { ecLen: 28, n1: 13, d1: 46, n2: 32, nb: 45, totalData: 2102, total: 3362 };  // 38-M
      8'd155: p = BlockParams { ecLen: 30, n1: 48, d1: 24, n2: 14, nb: 62, totalData: 1502, total: 3362 };  // 38-Q
      8'd154: p = BlockParams { ecLen: 30, n1: 42, d1: 15, n2: 32, nb: 74, totalData: 1142, total: 3362 };  // 38-H
      8'd157: p = BlockParams { ecLen: 30, n1: 20, d1: 117, n2: 4, nb: 24, totalData: 2812, total: 3532 };  // 39-L
      8'd156: p = BlockParams { ecLen: 28, n1: 40, d1: 47, n2: 7, nb: 47, totalData: 2216, total: 3532 };  // 39-M
      8'd159: p = BlockParams { ecLen: 30, n1: 43, d1: 24, n2: 22, nb: 65, totalData: 1582, total: 3532 };  // 39-Q
      8'd158: p = BlockParams { ecLen: 30, n1: 10, d1: 15, n2: 67, nb: 77, totalData: 1222, total: 3532 };  // 39-H
      8'd161: p = BlockParams { ecLen: 30, n1: 19, d1: 118, n2: 6, nb: 25, totalData: 2956, total: 3706 };  // 40-L
      8'd160: p = BlockParams { ecLen: 28, n1: 18, d1: 47, n2: 31, nb: 49, totalData: 2334, total: 3706 };  // 40-M
      8'd163: p = BlockParams { ecLen: 30, n1: 34, d1: 24, n2: 34, nb: 68, totalData: 1666, total: 3706 };  // 40-Q
      8'd162: p = BlockParams { ecLen: 30, n1: 20, d1: 15, n2: 61, nb: 81, totalData: 1276, total: 3706 };  // 40-H
   endcase
   return p;
endfunction

// Alignment pattern centre coordinates (same list for rows and columns).
typedef struct {
   UInt#(3) count;
   Vector#(7, UInt#(8)) pos;
} AlignParams deriving (Bits, Eq, FShow);

function AlignParams alignParams(UInt#(6) version);
   UInt#(3) n = 0;
   Bit#(56) p = 0;   // pos[0] in the low byte
   case (version)
      1: begin n = 0; p = 56'h00000000000000; end  // []
      2: begin n = 2; p = 56'h00000000001206; end  // [6, 18]
      3: begin n = 2; p = 56'h00000000001606; end  // [6, 22]
      4: begin n = 2; p = 56'h00000000001a06; end  // [6, 26]
      5: begin n = 2; p = 56'h00000000001e06; end  // [6, 30]
      6: begin n = 2; p = 56'h00000000002206; end  // [6, 34]
      7: begin n = 3; p = 56'h00000000261606; end  // [6, 22, 38]
      8: begin n = 3; p = 56'h000000002a1806; end  // [6, 24, 42]
      9: begin n = 3; p = 56'h000000002e1a06; end  // [6, 26, 46]
      10: begin n = 3; p = 56'h00000000321c06; end  // [6, 28, 50]
      11: begin n = 3; p = 56'h00000000361e06; end  // [6, 30, 54]
      12: begin n = 3; p = 56'h000000003a2006; end  // [6, 32, 58]
      13: begin n = 3; p = 56'h000000003e2206; end  // [6, 34, 62]
      14: begin n = 4; p = 56'h000000422e1a06; end  // [6, 26, 46, 66]
      15: begin n = 4; p = 56'h00000046301a06; end  // [6, 26, 48, 70]
      16: begin n = 4; p = 56'h0000004a321a06; end  // [6, 26, 50, 74]
      17: begin n = 4; p = 56'h0000004e361e06; end  // [6, 30, 54, 78]
      18: begin n = 4; p = 56'h00000052381e06; end  // [6, 30, 56, 82]
      19: begin n = 4; p = 56'h000000563a1e06; end  // [6, 30, 58, 86]
      20: begin n = 4; p = 56'h0000005a3e2206; end  // [6, 34, 62, 90]
      21: begin n = 5; p = 56'h00005e48321c06; end  // [6, 28, 50, 72, 94]
      22: begin n = 5; p = 56'h0000624a321a06; end  // [6, 26, 50, 74, 98]
      23: begin n = 5; p = 56'h0000664e361e06; end  // [6, 30, 54, 78, 102]
      24: begin n = 5; p = 56'h00006a50361c06; end  // [6, 28, 54, 80, 106]
      25: begin n = 5; p = 56'h00006e543a2006; end  // [6, 32, 58, 84, 110]
      26: begin n = 5; p = 56'h000072563a1e06; end  // [6, 30, 58, 86, 114]
      27: begin n = 5; p = 56'h0000765a3e2206; end  // [6, 34, 62, 90, 118]
      28: begin n = 6; p = 56'h007a624a321a06; end  // [6, 26, 50, 74, 98, 122]
      29: begin n = 6; p = 56'h007e664e361e06; end  // [6, 30, 54, 78, 102, 126]
      30: begin n = 6; p = 56'h0082684e341a06; end  // [6, 26, 52, 78, 104, 130]
      31: begin n = 6; p = 56'h00866c52381e06; end  // [6, 30, 56, 82, 108, 134]
      32: begin n = 6; p = 56'h008a70563c2206; end  // [6, 34, 60, 86, 112, 138]
      33: begin n = 6; p = 56'h008e72563a1e06; end  // [6, 30, 58, 86, 114, 142]
      34: begin n = 6; p = 56'h0092765a3e2206; end  // [6, 34, 62, 90, 118, 146]
      35: begin n = 7; p = 56'h967e664e361e06; end  // [6, 30, 54, 78, 102, 126, 150]
      36: begin n = 7; p = 56'h9a80664c321806; end  // [6, 24, 50, 76, 102, 128, 154]
      37: begin n = 7; p = 56'h9e846a50361c06; end  // [6, 28, 54, 80, 106, 132, 158]
      38: begin n = 7; p = 56'ha2886e543a2006; end  // [6, 32, 58, 84, 110, 136, 162]
      39: begin n = 7; p = 56'ha68a6e52361a06; end  // [6, 26, 54, 82, 110, 138, 166]
      40: begin n = 7; p = 56'haa8e72563a1e06; end  // [6, 30, 58, 86, 114, 142, 170]
   endcase
   return AlignParams { count: n, pos: unpack(p) };
endfunction

// The 32 valid 15-bit format codewords (BCH(15,5), already XORed with 0x5412).
function Bit#(15) formatCodeword(Integer d);
   Integer t[32] = {21522, 20773, 24188, 23371, 17913, 16590, 20375, 19104, 30660, 29427, 32170, 30877, 26159, 25368, 27713, 26998, 5769, 5054, 7399, 6608, 1890, 597, 3340, 2107, 13663, 12392, 16177, 14854, 9396, 8579, 11994, 11245};
   return fromInteger(t[d]);
endfunction

// alpha^j in GF(256), polynomial 0x11D, alpha = 2.
function Bit#(8) alphaPow(Integer j);
   Integer t[30] = {1, 2, 4, 8, 16, 32, 64, 128, 29, 58, 116, 232, 205, 135, 19, 38, 76, 152, 45, 90, 180, 117, 234, 201, 143, 3, 6, 12, 24, 48};
   return fromInteger(t[j]);
endfunction

// alpha^(-j)
function Bit#(8) alphaInvPow(Integer j);
   Integer t[16] = {1, 142, 71, 173, 216, 108, 54, 27, 131, 207, 233, 250, 125, 176, 88, 44};
   return fromInteger(t[j]);
endfunction

// Multiplicative inverse in GF(256); gfInv(0) = 0.
function Bit#(8) gfInv(Bit#(8) a);
   Bit#(8) r = 0;
   case (a)
      8'd1: r = 8'd1;
      8'd2: r = 8'd142;
      8'd3: r = 8'd244;
      8'd4: r = 8'd71;
      8'd5: r = 8'd167;
      8'd6: r = 8'd122;
      8'd7: r = 8'd186;
      8'd8: r = 8'd173;
      8'd9: r = 8'd157;
      8'd10: r = 8'd221;
      8'd11: r = 8'd152;
      8'd12: r = 8'd61;
      8'd13: r = 8'd170;
      8'd14: r = 8'd93;
      8'd15: r = 8'd150;
      8'd16: r = 8'd216;
      8'd17: r = 8'd114;
      8'd18: r = 8'd192;
      8'd19: r = 8'd88;
      8'd20: r = 8'd224;
      8'd21: r = 8'd62;
      8'd22: r = 8'd76;
      8'd23: r = 8'd102;
      8'd24: r = 8'd144;
      8'd25: r = 8'd222;
      8'd26: r = 8'd85;
      8'd27: r = 8'd128;
      8'd28: r = 8'd160;
      8'd29: r = 8'd131;
      8'd30: r = 8'd75;
      8'd31: r = 8'd42;
      8'd32: r = 8'd108;
      8'd33: r = 8'd237;
      8'd34: r = 8'd57;
      8'd35: r = 8'd81;
      8'd36: r = 8'd96;
      8'd37: r = 8'd86;
      8'd38: r = 8'd44;
      8'd39: r = 8'd138;
      8'd40: r = 8'd112;
      8'd41: r = 8'd208;
      8'd42: r = 8'd31;
      8'd43: r = 8'd74;
      8'd44: r = 8'd38;
      8'd45: r = 8'd139;
      8'd46: r = 8'd51;
      8'd47: r = 8'd110;
      8'd48: r = 8'd72;
      8'd49: r = 8'd137;
      8'd50: r = 8'd111;
      8'd51: r = 8'd46;
      8'd52: r = 8'd164;
      8'd53: r = 8'd195;
      8'd54: r = 8'd64;
      8'd55: r = 8'd94;
      8'd56: r = 8'd80;
      8'd57: r = 8'd34;
      8'd58: r = 8'd207;
      8'd59: r = 8'd169;
      8'd60: r = 8'd171;
      8'd61: r = 8'd12;
      8'd62: r = 8'd21;
      8'd63: r = 8'd225;
      8'd64: r = 8'd54;
      8'd65: r = 8'd95;
      8'd66: r = 8'd248;
      8'd67: r = 8'd213;
      8'd68: r = 8'd146;
      8'd69: r = 8'd78;
      8'd70: r = 8'd166;
      8'd71: r = 8'd4;
      8'd72: r = 8'd48;
      8'd73: r = 8'd136;
      8'd74: r = 8'd43;
      8'd75: r = 8'd30;
      8'd76: r = 8'd22;
      8'd77: r = 8'd103;
      8'd78: r = 8'd69;
      8'd79: r = 8'd147;
      8'd80: r = 8'd56;
      8'd81: r = 8'd35;
      8'd82: r = 8'd104;
      8'd83: r = 8'd140;
      8'd84: r = 8'd129;
      8'd85: r = 8'd26;
      8'd86: r = 8'd37;
      8'd87: r = 8'd97;
      8'd88: r = 8'd19;
      8'd89: r = 8'd193;
      8'd90: r = 8'd203;
      8'd91: r = 8'd99;
      8'd92: r = 8'd151;
      8'd93: r = 8'd14;
      8'd94: r = 8'd55;
      8'd95: r = 8'd65;
      8'd96: r = 8'd36;
      8'd97: r = 8'd87;
      8'd98: r = 8'd202;
      8'd99: r = 8'd91;
      8'd100: r = 8'd185;
      8'd101: r = 8'd196;
      8'd102: r = 8'd23;
      8'd103: r = 8'd77;
      8'd104: r = 8'd82;
      8'd105: r = 8'd141;
      8'd106: r = 8'd239;
      8'd107: r = 8'd179;
      8'd108: r = 8'd32;
      8'd109: r = 8'd236;
      8'd110: r = 8'd47;
      8'd111: r = 8'd50;
      8'd112: r = 8'd40;
      8'd113: r = 8'd209;
      8'd114: r = 8'd17;
      8'd115: r = 8'd217;
      8'd116: r = 8'd233;
      8'd117: r = 8'd251;
      8'd118: r = 8'd218;
      8'd119: r = 8'd121;
      8'd120: r = 8'd219;
      8'd121: r = 8'd119;
      8'd122: r = 8'd6;
      8'd123: r = 8'd187;
      8'd124: r = 8'd132;
      8'd125: r = 8'd205;
      8'd126: r = 8'd254;
      8'd127: r = 8'd252;
      8'd128: r = 8'd27;
      8'd129: r = 8'd84;
      8'd130: r = 8'd161;
      8'd131: r = 8'd29;
      8'd132: r = 8'd124;
      8'd133: r = 8'd204;
      8'd134: r = 8'd228;
      8'd135: r = 8'd176;
      8'd136: r = 8'd73;
      8'd137: r = 8'd49;
      8'd138: r = 8'd39;
      8'd139: r = 8'd45;
      8'd140: r = 8'd83;
      8'd141: r = 8'd105;
      8'd142: r = 8'd2;
      8'd143: r = 8'd245;
      8'd144: r = 8'd24;
      8'd145: r = 8'd223;
      8'd146: r = 8'd68;
      8'd147: r = 8'd79;
      8'd148: r = 8'd155;
      8'd149: r = 8'd188;
      8'd150: r = 8'd15;
      8'd151: r = 8'd92;
      8'd152: r = 8'd11;
      8'd153: r = 8'd220;
      8'd154: r = 8'd189;
      8'd155: r = 8'd148;
      8'd156: r = 8'd172;
      8'd157: r = 8'd9;
      8'd158: r = 8'd199;
      8'd159: r = 8'd162;
      8'd160: r = 8'd28;
      8'd161: r = 8'd130;
      8'd162: r = 8'd159;
      8'd163: r = 8'd198;
      8'd164: r = 8'd52;
      8'd165: r = 8'd194;
      8'd166: r = 8'd70;
      8'd167: r = 8'd5;
      8'd168: r = 8'd206;
      8'd169: r = 8'd59;
      8'd170: r = 8'd13;
      8'd171: r = 8'd60;
      8'd172: r = 8'd156;
      8'd173: r = 8'd8;
      8'd174: r = 8'd190;
      8'd175: r = 8'd183;
      8'd176: r = 8'd135;
      8'd177: r = 8'd229;
      8'd178: r = 8'd238;
      8'd179: r = 8'd107;
      8'd180: r = 8'd235;
      8'd181: r = 8'd242;
      8'd182: r = 8'd191;
      8'd183: r = 8'd175;
      8'd184: r = 8'd197;
      8'd185: r = 8'd100;
      8'd186: r = 8'd7;
      8'd187: r = 8'd123;
      8'd188: r = 8'd149;
      8'd189: r = 8'd154;
      8'd190: r = 8'd174;
      8'd191: r = 8'd182;
      8'd192: r = 8'd18;
      8'd193: r = 8'd89;
      8'd194: r = 8'd165;
      8'd195: r = 8'd53;
      8'd196: r = 8'd101;
      8'd197: r = 8'd184;
      8'd198: r = 8'd163;
      8'd199: r = 8'd158;
      8'd200: r = 8'd210;
      8'd201: r = 8'd247;
      8'd202: r = 8'd98;
      8'd203: r = 8'd90;
      8'd204: r = 8'd133;
      8'd205: r = 8'd125;
      8'd206: r = 8'd168;
      8'd207: r = 8'd58;
      8'd208: r = 8'd41;
      8'd209: r = 8'd113;
      8'd210: r = 8'd200;
      8'd211: r = 8'd246;
      8'd212: r = 8'd249;
      8'd213: r = 8'd67;
      8'd214: r = 8'd215;
      8'd215: r = 8'd214;
      8'd216: r = 8'd16;
      8'd217: r = 8'd115;
      8'd218: r = 8'd118;
      8'd219: r = 8'd120;
      8'd220: r = 8'd153;
      8'd221: r = 8'd10;
      8'd222: r = 8'd25;
      8'd223: r = 8'd145;
      8'd224: r = 8'd20;
      8'd225: r = 8'd63;
      8'd226: r = 8'd230;
      8'd227: r = 8'd240;
      8'd228: r = 8'd134;
      8'd229: r = 8'd177;
      8'd230: r = 8'd226;
      8'd231: r = 8'd241;
      8'd232: r = 8'd250;
      8'd233: r = 8'd116;
      8'd234: r = 8'd243;
      8'd235: r = 8'd180;
      8'd236: r = 8'd109;
      8'd237: r = 8'd33;
      8'd238: r = 8'd178;
      8'd239: r = 8'd106;
      8'd240: r = 8'd227;
      8'd241: r = 8'd231;
      8'd242: r = 8'd181;
      8'd243: r = 8'd234;
      8'd244: r = 8'd3;
      8'd245: r = 8'd143;
      8'd246: r = 8'd211;
      8'd247: r = 8'd201;
      8'd248: r = 8'd66;
      8'd249: r = 8'd212;
      8'd250: r = 8'd232;
      8'd251: r = 8'd117;
      8'd252: r = 8'd127;
      8'd253: r = 8'd255;
      8'd254: r = 8'd126;
      8'd255: r = 8'd253;
   endcase
   return r;
endfunction

// Alphanumeric mode character set (value 0-44 to ASCII).
function Bit#(8) alnumChar(UInt#(6) v);
   Bit#(8) r = 8'h3F;
   case (v)
      0: r = 8'd48;
      1: r = 8'd49;
      2: r = 8'd50;
      3: r = 8'd51;
      4: r = 8'd52;
      5: r = 8'd53;
      6: r = 8'd54;
      7: r = 8'd55;
      8: r = 8'd56;
      9: r = 8'd57;
      10: r = 8'd65;
      11: r = 8'd66;
      12: r = 8'd67;
      13: r = 8'd68;
      14: r = 8'd69;
      15: r = 8'd70;
      16: r = 8'd71;
      17: r = 8'd72;
      18: r = 8'd73;
      19: r = 8'd74;
      20: r = 8'd75;
      21: r = 8'd76;
      22: r = 8'd77;
      23: r = 8'd78;
      24: r = 8'd79;
      25: r = 8'd80;
      26: r = 8'd81;
      27: r = 8'd82;
      28: r = 8'd83;
      29: r = 8'd84;
      30: r = 8'd85;
      31: r = 8'd86;
      32: r = 8'd87;
      33: r = 8'd88;
      34: r = 8'd89;
      35: r = 8'd90;
      36: r = 8'd32;
      37: r = 8'd36;
      38: r = 8'd37;
      39: r = 8'd42;
      40: r = 8'd43;
      41: r = 8'd45;
      42: r = 8'd46;
      43: r = 8'd47;
      44: r = 8'd58;
   endcase
   return r;
endfunction

endpackage
