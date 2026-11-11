"""
QR Code Codeword De-interleaving and Reassembly Reference Model
Handles block partitioning, de-interleaving raw codewords into blocks, and reassembly.

Author: Person A (Independent Reference Model)
Authority: CADForVLSI_2026_Project_Spec.pdf Section 1.4, QRTables.bsv
"""

from typing import List, Tuple, Dict, NamedTuple

class BlockParams(NamedTuple):
    ecLen: int      # Error correction bytes per block
    n1: int         # Number of blocks in group 1
    d1: int         # Data bytes per block in group 1
    n2: int         # Number of blocks in group 2
    nb: int         # Total blocks = n1 + n2
    totalData: int  # Total data bytes across all blocks
    total: int      # Total codewords (data + check) across all blocks

# Level field mapping: 01=L(1), 00=M(0), 11=Q(3), 10=H(2)
LEVEL_MAP = {
    'L': 1, 'M': 0, 'Q': 3, 'H': 2,
    1: 1, 0: 0, 3: 3, 2: 2
}

# Load/construct block table directly matching QRTables.bsv
# Key: (version, levelField) where levelField is int 0..3
BLOCK_TABLE: Dict[Tuple[int, int], BlockParams] = {}

def _init_block_table():
    # Table directly transcribed from ISO/IEC 18004 & QRTables.bsv
    # (ecLen, n1, d1, n2, nb, totalData, total)
    table_data = {
        (1, 1): (7, 1, 19, 0, 1, 19, 26),     # 1-L
        (1, 0): (10, 1, 16, 0, 1, 16, 26),    # 1-M
        (1, 3): (13, 1, 13, 0, 1, 13, 26),    # 1-Q
        (1, 2): (17, 1, 9, 0, 1, 9, 26),      # 1-H
        (2, 1): (10, 1, 34, 0, 1, 34, 44),    # 2-L
        (2, 0): (16, 1, 28, 0, 1, 28, 44),    # 2-M
        (2, 3): (22, 1, 22, 0, 1, 22, 44),    # 2-Q
        (2, 2): (28, 1, 16, 0, 1, 16, 44),    # 2-H
        (3, 1): (15, 1, 55, 0, 1, 55, 70),    # 3-L
        (3, 0): (26, 1, 44, 0, 1, 44, 70),    # 3-M
        (3, 3): (18, 2, 17, 0, 2, 34, 70),    # 3-Q
        (3, 2): (22, 2, 13, 0, 2, 26, 70),    # 3-H
        (4, 1): (20, 1, 80, 0, 1, 80, 100),   # 4-L
        (4, 0): (18, 2, 32, 0, 2, 64, 100),   # 4-M
        (4, 3): (26, 2, 24, 0, 2, 48, 100),   # 4-Q
        (4, 2): (16, 4, 9, 0, 4, 36, 100),    # 4-H
        (5, 1): (26, 1, 108, 0, 1, 108, 134), # 5-L
        (5, 0): (24, 2, 43, 0, 2, 86, 134),   # 5-M
        (5, 3): (18, 2, 15, 2, 4, 62, 134),   # 5-Q
        (5, 2): (22, 2, 11, 2, 4, 46, 134),   # 5-H
        (6, 1): (18, 2, 68, 0, 2, 136, 172),
        (6, 0): (16, 4, 27, 0, 4, 108, 172),
        (6, 3): (24, 4, 19, 0, 4, 76, 172),
        (6, 2): (28, 4, 15, 0, 4, 60, 172),
        (7, 1): (20, 2, 78, 0, 2, 156, 196),
        (7, 0): (18, 4, 31, 0, 4, 124, 196),
        (7, 3): (18, 2, 14, 4, 6, 88, 196),
        (7, 2): (26, 4, 13, 1, 5, 66, 196),
        (8, 1): (24, 2, 97, 0, 2, 194, 242),
        (8, 0): (22, 2, 38, 2, 4, 154, 242),
        (8, 3): (22, 4, 18, 2, 6, 110, 242),
        (8, 2): (26, 4, 14, 2, 6, 86, 242),
        (9, 1): (30, 2, 116, 0, 2, 232, 292),
        (9, 0): (22, 3, 36, 2, 5, 182, 292),
        (9, 3): (20, 4, 16, 4, 8, 132, 292),
        (9, 2): (24, 4, 12, 4, 8, 100, 292),
        (10, 1): (18, 2, 68, 2, 4, 274, 346),
        (10, 0): (26, 4, 43, 1, 5, 216, 346),
        (10, 3): (24, 6, 19, 2, 8, 154, 346),
        (10, 2): (28, 6, 15, 2, 8, 122, 346),
        (40, 1): (30, 25, 118, 0, 25, 2950, 3706), # 40-L (corrected in spec: 25*118 + 0 = 2950? Wait, let's load exact QRTables)
    }
    # Rather than hardcoding only a few, let's parse QRTables.bsv for exact match
    import os, re
    bsv_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../bsv/QRTables.bsv"))
    if os.path.exists(bsv_path):
        with open(bsv_path, "r") as f:
            content = f.read()
        # Pattern e.g.: 8'd5: p = BlockParams { ecLen: 7, n1: 1, d1: 19, n2: 0, nb: 1, totalData: 19, total: 26 };
        pat = re.compile(r"8'd(\d+):\s*p\s*=\s*BlockParams\s*\{\s*ecLen:\s*(\d+),\s*n1:\s*(\d+),\s*d1:\s*(\d+),\s*n2:\s*(\d+),\s*nb:\s*(\d+),\s*totalData:\s*(\d+),\s*total:\s*(\d+)\s*\};")
        for m in pat.finditer(content):
            code = int(m.group(1))
            v = code >> 2
            lvl = code & 0x03
            bp = BlockParams(
                ecLen=int(m.group(2)),
                n1=int(m.group(3)),
                d1=int(m.group(4)),
                n2=int(m.group(5)),
                nb=int(m.group(6)),
                totalData=int(m.group(7)),
                total=int(m.group(8))
            )
            BLOCK_TABLE[(v, lvl)] = bp

_init_block_table()

def get_block_params(version: int, level: any) -> BlockParams:
    """Retrieve BlockParams for (version, level). level can be 'L','M','Q','H' or int 0..3."""
    lvl_code = LEVEL_MAP[level]
    if (version, lvl_code) not in BLOCK_TABLE:
        raise ValueError(f"Unknown version {version} or level {level}")
    return BLOCK_TABLE[(version, lvl_code)]

def deinterleave(raw_bytes: List[int], version: int, level: any) -> List[List[int]]:
    """
    De-interleave raw codewords into individual blocks.
    Each block is a list of codewords: data bytes followed by ec bytes.
    Total blocks: nb = n1 + n2.
    """
    bp = get_block_params(version, level)
    if len(raw_bytes) != bp.total:
        raise ValueError(f"raw_bytes length {len(raw_bytes)} does not match total {bp.total} for V{version}-{level}")

    # Prepare empty lists for data and ec bytes per block
    data_blocks = [[] for _ in range(bp.nb)]
    ec_blocks = [[] for _ in range(bp.nb)]

    raw_idx = 0

    # 1. De-interleave data bytes
    # Group 1 blocks have d1 bytes, Group 2 blocks have d1 + 1 bytes.
    max_d = bp.d1 + (1 if bp.n2 > 0 else 0)
    for col in range(max_d):
        for b in range(bp.nb):
            # Block b gets byte col only if col < its data length
            block_d = bp.d1 if b < bp.n1 else bp.d1 + 1
            if col < block_d:
                data_blocks[b].append(raw_bytes[raw_idx])
                raw_idx += 1

    assert raw_idx == bp.totalData, f"Expected {bp.totalData} data bytes read, got {raw_idx}"

    # 2. De-interleave EC check bytes
    # Every block has exactly ecLen check bytes
    for col in range(bp.ecLen):
        for b in range(bp.nb):
            ec_blocks[b].append(raw_bytes[raw_idx])
            raw_idx += 1

    assert raw_idx == bp.total, f"Expected {bp.total} total bytes read, got {raw_idx}"

    # Return combined block codewords [data + ec] for each block
    return [data_blocks[b] + ec_blocks[b] for b in range(bp.nb)]

def reassemble(corrected_blocks: List[List[int]], version: int, level: any) -> List[int]:
    """
    Reassemble corrected data bytes from blocks into a single message byte stream.
    Blocks are taken in block order: all data bytes of block 0, then block 1, etc.
    Check bytes are discarded.
    """
    bp = get_block_params(version, level)
    if len(corrected_blocks) != bp.nb:
        raise ValueError(f"Expected {bp.nb} blocks, got {len(corrected_blocks)}")

    data_stream = []
    for b in range(bp.nb):
        block_d = bp.d1 if b < bp.n1 else bp.d1 + 1
        # Extract only the data portion (first block_d bytes)
        data_stream.extend(corrected_blocks[b][:block_d])

    assert len(data_stream) == bp.totalData, f"Reassembled length {len(data_stream)} != {bp.totalData}"
    return data_stream

def interleave(blocks: List[List[int]], version: int, level: any) -> List[int]:
    """
    Inverse operation: interleave a list of block codewords (each containing data + ec)
    into a raw interleaved byte stream. Used for generating test vectors.
    """
    bp = get_block_params(version, level)
    if len(blocks) != bp.nb:
        raise ValueError(f"Expected {bp.nb} blocks, got {len(blocks)}")

    raw_bytes = []
    max_d = bp.d1 + (1 if bp.n2 > 0 else 0)

    # 1. Interleave data bytes
    for col in range(max_d):
        for b in range(bp.nb):
            block_d = bp.d1 if b < bp.n1 else bp.d1 + 1
            if col < block_d:
                raw_bytes.append(blocks[b][col])

    # 2. Interleave EC check bytes
    for col in range(bp.ecLen):
        for b in range(bp.nb):
            block_d = bp.d1 if b < bp.n1 else bp.d1 + 1
            raw_bytes.append(blocks[b][block_d + col])

    assert len(raw_bytes) == bp.total
    return raw_bytes

