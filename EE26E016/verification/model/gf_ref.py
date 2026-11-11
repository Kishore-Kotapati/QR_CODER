"""
Galois Field GF(2^8) Reference Model
Field Polynomial: p(x) = x^8 + x^4 + x^3 + x^2 + 1 (0x11D = 285)
Primitive Element: alpha = 2 (0x02)

Author: Person A (Independent Reference Model)
Authority: CADForVLSI_2026_Project_Spec.pdf Section 1.4, ISO/IEC 18004
"""

# Primitive polynomial: x^8 + x^4 + x^3 + x^2 + 1
GF_POLY = 0x11D

# 1. First-principles bitwise multiplication (Russian Peasant algorithm)
def gf_mul_bitwise(a: int, b: int) -> int:
    """
    Multiply two elements a, b in GF(2^8) modulo p(x) = 0x11D using shift-and-add.
    Independent first-principles implementation.
    """
    res = 0
    a &= 0xFF
    b &= 0xFF
    for _ in range(8):
        if b & 1:
            res ^= a
        carry = a & 0x80
        a = (a << 1) & 0xFF
        if carry:
            a ^= 0x1D  # 0x11D without the degree-8 bit
        b >>= 1
    return res

# 2. Build Logarithm and Exponent (Antilog) Tables dynamically from alpha = 2
EXP_TABLE = [0] * 512
LOG_TABLE = [0] * 256

def _init_tables():
    val = 1
    for i in range(255):
        EXP_TABLE[i] = val
        EXP_TABLE[i + 255] = val
        LOG_TABLE[val] = i
        # Multiply val by alpha = 2 using reduction modulo 0x11D
        val <<= 1
        if val & 0x100:
            val ^= GF_POLY
    EXP_TABLE[510] = EXP_TABLE[0]
    LOG_TABLE[0] = None  # Log of zero is undefined mathematically

_init_tables()

def gf_add(a: int, b: int) -> int:
    """Addition in GF(2^8) is bitwise XOR."""
    return (a ^ b) & 0xFF

def gf_sub(a: int, b: int) -> int:
    """Subtraction in GF(2^8) is identical to addition (bitwise XOR)."""
    return (a ^ b) & 0xFF

def gf_mul(a: int, b: int) -> int:
    """Multiplication in GF(2^8) using precomputed exponent/log tables."""
    a &= 0xFF
    b &= 0xFF
    if a == 0 or b == 0:
        return 0
    return EXP_TABLE[LOG_TABLE[a] + LOG_TABLE[b]]

def gf_inv(a: int) -> int:
    """
    Multiplicative inverse in GF(2^8).
    Strict mathematical definition: raises ZeroDivisionError on 0.
    """
    a &= 0xFF
    if a == 0:
        raise ZeroDivisionError("Multiplicative inverse of 0 is undefined in GF(2^8)")
    return EXP_TABLE[255 - LOG_TABLE[a]]

def gf_inv_safe(a: int) -> int:
    """
    Convenience inverse matching QRTables.bsv `gfInv(0) = 0`.
    Documented per Person A brief: must not be used to mask unhandled division by zero.
    """
    a &= 0xFF
    if a == 0:
        return 0
    return EXP_TABLE[255 - LOG_TABLE[a]]

def gf_div(a: int, b: int) -> int:
    """Division a / b in GF(2^8)."""
    a &= 0xFF
    b &= 0xFF
    if b == 0:
        raise ZeroDivisionError("Division by zero in GF(2^8)")
    if a == 0:
        return 0
    return EXP_TABLE[(LOG_TABLE[a] + 255 - LOG_TABLE[b]) % 255]

def gf_pow(a: int, power: int) -> int:
    """Exponentiation a^power in GF(2^8)."""
    a &= 0xFF
    if a == 0:
        return 0 if power > 0 else 1
    if power == 0:
        return 1
    return EXP_TABLE[(LOG_TABLE[a] * power) % 255]

def alpha_pow(j: int) -> int:
    """Return alpha^j in GF(2^8)."""
    return EXP_TABLE[j % 255]

# --- Polynomial Operations over GF(2^8) ---
# Representation: list of coefficients [c_{deg}, c_{deg-1}, ..., c_1, c_0]
# Highest degree first (conventional QR Code order).

def poly_add(p1: list, p2: list) -> list:
    """Add two polynomials over GF(2^8)."""
    l1, l2 = len(p1), len(p2)
    max_len = max(l1, l2)
    res = [0] * max_len
    for i in range(max_len):
        c1 = p1[l1 - max_len + i] if i >= max_len - l1 else 0
        c2 = p2[l2 - max_len + i] if i >= max_len - l2 else 0
        res[i] = gf_add(c1, c2)
    # Strip leading zeros, preserving [0] for zero polynomial
    while len(res) > 1 and res[0] == 0:
        res.pop(0)
    return res

def poly_scale(p: list, scalar: int) -> list:
    """Multiply polynomial p by a constant scalar in GF(2^8)."""
    if scalar == 0:
        return [0]
    return [gf_mul(c, scalar) for c in p]

def poly_mul(p1: list, p2: list) -> list:
    """Multiply two polynomials p1 and p2 over GF(2^8)."""
    if p1 == [0] or p2 == [0]:
        return [0]
    deg1 = len(p1) - 1
    deg2 = len(p2) - 1
    res = [0] * (deg1 + deg2 + 1)
    for i, c1 in enumerate(p1):
        for j, c2 in enumerate(p2):
            res[i + j] = gf_add(res[i + j], gf_mul(c1, c2))
    while len(res) > 1 and res[0] == 0:
        res.pop(0)
    return res

def poly_eval(p: list, x: int) -> int:
    """
    Evaluate polynomial p at element x in GF(2^8) using Horner's method.
    p is [c_{deg}, ..., c_0] representing c_{deg} * x^{deg} + ... + c_0.
    """
    y = 0
    for c in p:
        y = gf_add(gf_mul(y, x), c)
    return y

