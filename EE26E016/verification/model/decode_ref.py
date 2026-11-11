"""
Top-Level QR Code Decoder Reference Model (Software Glue)
Assembles Person B's frontend & payload models with Person A's blocks & RS models.

Author: Person A (Glue Integration)
Specification: CADForVLSI_2026_Project_Spec.pdf Section 5.1, docs/MODEL_INTERFACE.md
"""

from typing import List, Optional, NamedTuple
import os
import sys

# Ensure local model directory is in sys.path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import front_ref as F
import blocks_ref as B
import rs_ref as RS
import payload_ref as P

class DecodeResult(NamedTuple):
    success: bool
    version: Optional[int]
    level_field: Optional[int]
    mask: Optional[int]
    message: Optional[str]
    bytes_out: List[int]
    errors_corrected: int
    stage_failed: Optional[str]
    error_msg: Optional[str]

def decode_symbol(matrix: List[List[int]]) -> DecodeResult:
    """
    Complete end-to-end decode of an N x N QR symbol matrix (1 = dark, 0 = light).
    Orchestrates the 4 stages without modifying any submodule algorithm.
    """
    # 1. Frontend Stage (Person B)
    # Extracts side length, version, format BCH decode (level, mask),
    # geometric function module exclusion, zigzag traversal, unmasking, and raw codewords.
    front = F.decode_frontend(matrix)
    if front.failed:
        return DecodeResult(
            success=False,
            version=front.version,
            level_field=front.level_field,
            mask=front.mask,
            message=None,
            bytes_out=[],
            errors_corrected=0,
            stage_failed=front.failed_stage if front.failed_stage else "frontend",
            error_msg=front.error_msg
        )

    version = front.version
    level_field = front.level_field
    mask = front.mask

    # 2. Block Parameters & De-interleaving (Person A)
    try:
        bp = B.get_block_params(version, level_field)
    except Exception as e:
        return DecodeResult(
            success=False,
            version=version,
            level_field=level_field,
            mask=mask,
            message=None,
            bytes_out=[],
            errors_corrected=0,
            stage_failed="block_params",
            error_msg=str(e)
        )

    if len(front.raw_codewords) != bp.total:
        return DecodeResult(
            success=False,
            version=version,
            level_field=level_field,
            mask=mask,
            message=None,
            bytes_out=[],
            errors_corrected=0,
            stage_failed="raw_length",
            error_msg=f"Codeword count {len(front.raw_codewords)} != expected {bp.total}"
        )

    blocks = B.deinterleave(front.raw_codewords, version, level_field)

    # 3. Reed-Solomon Error Correction (Person A)
    # Corrects each of the nb blocks independently.
    corrected_blocks = []
    total_errors = 0
    for b_idx, blk in enumerate(blocks):
        corrected, n_err, ok = RS.correct_block(blk, bp.ecLen)
        if not ok:
            return DecodeResult(
                success=False,
                version=version,
                level_field=level_field,
                mask=mask,
                message=None,
                bytes_out=[],
                errors_corrected=total_errors,
                stage_failed="rs_correction",
                error_msg=f"Uncorrectable error in block {b_idx}/{bp.nb} (capacity t={bp.ecLen // 2})"
            )
        corrected_blocks.append(corrected)
        total_errors += n_err

    # 4. Reassemble Corrected Data (Person A)
    data_bytes = B.reassemble(corrected_blocks, version, level_field)

    # 5. Payload Parsing (Person B)
    # Parses modes (numeric, alphanumeric, byte), count indicators, segments, and padding.
    payload = P.decode_payload(data_bytes, version)
    if payload.failed:
        return DecodeResult(
            success=False,
            version=version,
            level_field=level_field,
            mask=mask,
            message=None,
            bytes_out=[],
            errors_corrected=total_errors,
            stage_failed="payload",
            error_msg=payload.error_msg
        )

    return DecodeResult(
        success=True,
        version=version,
        level_field=level_field,
        mask=mask,
        message=payload.message,
        bytes_out=payload.bytes_out,
        errors_corrected=total_errors,
        stage_failed=None,
        error_msg=None
    )

