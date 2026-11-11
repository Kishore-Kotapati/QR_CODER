"""
Reed-Solomon Decoder Reference Model over GF(2^8)
Specification: CADForVLSI_2026_Project_Spec.pdf Section 1.4
Generator: g(x) = prod_{i=0}^{e-1} (x - alpha^i)
Field Polynomial: 0x11D, Primitive: alpha = 2

Author: Person A (Independent Reference Model)
"""

from typing import List, Tuple, Optional
import gf_ref as gf

def compute_syndromes(block: List[int], ec_len: int) -> List[int]:
    """
    Compute e syndromes: S_i = r(alpha^i) for i = 0 ... ec_len - 1.
    Codeword polynomial r(x) has highest degree first (block[0] is x^{n-1}).
    """
    n = len(block)
    syndromes = [0] * ec_len
    for i in range(ec_len):
        alpha_i = gf.alpha_pow(i)
        # Horner evaluation: r(alpha_i)
        val = 0
        for byte in block:
            val = gf.gf_add(gf.gf_mul(val, alpha_i), byte)
        syndromes[i] = val
    return syndromes

def berlekamp_massey(syndromes: List[int], ec_len: int) -> Tuple[List[int], int]:
    """
    Berlekamp-Massey algorithm to find error locator polynomial Lambda(x).
    Returns (Lambda, L) where Lambda = [1, Lambda_1, ..., Lambda_L] (low degree first).
    """
    Lambda = [1]
    B = [1]
    L = 0
    m = 1
    b = 1  # Previous discrepancy

    for n in range(ec_len):
        # Discrepancy delta_n = S_n + sum_{i=1}^L Lambda_i * S_{n-i}
        delta = syndromes[n]
        for i in range(1, len(Lambda)):
            delta = gf.gf_add(delta, gf.gf_mul(Lambda[i], syndromes[n - i]))

        if delta == 0:
            m += 1
        else:
            T = list(Lambda)
            # Factor = delta * b^(-1)
            factor = gf.gf_mul(delta, gf.gf_inv(b))
            scaled_B = [0] * m + [gf.gf_mul(factor, c) for c in B]

            # Lambda(x) = Lambda(x) ^ scaled_B(x)
            max_len = max(len(Lambda), len(scaled_B))
            new_Lambda = [0] * max_len
            for i in range(len(Lambda)):
                new_Lambda[i] = gf.gf_add(new_Lambda[i], Lambda[i])
            for i in range(len(scaled_B)):
                new_Lambda[i] = gf.gf_add(new_Lambda[i], scaled_B[i])
            Lambda = new_Lambda

            if 2 * L <= n:
                L = n + 1 - L
                B = T
                b = delta
                m = 1
            else:
                m += 1

    # Strip trailing zeros
    while len(Lambda) > 1 and Lambda[-1] == 0:
        Lambda.pop()

    return Lambda, L

def chien_search(Lambda: List[int], n: int) -> Optional[List[int]]:
    """
    Find error positions p in 0 ... n-1 by testing roots of Lambda(x) at x = alpha^{-(n - 1 - p)}.
    Returns list of error indices p, or None if root count != degree of Lambda.
    """
    deg = len(Lambda) - 1
    if deg == 0:
        return []

    error_positions = []
    for p in range(n):
        # Root test: evaluate Lambda(alpha^{-(n - 1 - p)})
        inv_X = gf.alpha_pow((255 - (n - 1 - p)) % 255)
        val = 0
        pwr = 1
        for coef in Lambda:
            val = gf.gf_add(val, gf.gf_mul(coef, pwr))
            pwr = gf.gf_mul(pwr, inv_X)
        if val == 0:
            error_positions.append(p)

    if len(error_positions) != deg:
        # Number of roots does not match polynomial degree -> uncorrectable error!
        return None

    return error_positions

def forney(syndromes: List[int], Lambda: List[int], error_positions: List[int], n: int, ec_len: int) -> List[Tuple[int, int]]:
    """
    Compute error magnitudes using Forney's algorithm.
    Returns list of (position, magnitude) pairs.
    """
    # 1. Error evaluator polynomial Omega(x) = S(x) * Lambda(x) mod x^ec_len
    omega = [0] * ec_len
    for i in range(ec_len):
        for j in range(len(Lambda)):
            if i + j < ec_len:
                omega[i + j] = gf.gf_add(omega[i + j], gf.gf_mul(syndromes[i], Lambda[j]))

    # 2. Compute error magnitudes
    errors = []
    for p in error_positions:
        X = gf.alpha_pow(n - 1 - p)
        inv_X = gf.gf_inv(X)

        # Omega(X^-1)
        omega_val = 0
        pwr = 1
        for c in omega:
            omega_val = gf.gf_add(omega_val, gf.gf_mul(c, pwr))
            pwr = gf.gf_mul(pwr, inv_X)

        # Formal derivative Lambda'(x) = sum_{j odd} Lambda_j * x^{j-1}
        # In char 2, even power derivatives are 0
        lam_prime = 0
        for j in range(1, len(Lambda), 2):
            lam_prime = gf.gf_add(lam_prime, gf.gf_mul(Lambda[j], gf.gf_pow(inv_X, j - 1)))

        if lam_prime == 0:
            raise ValueError(f"Lambda'(X^-1) = 0 at position {p}")

        # Magnitude Y = X * Omega(X^-1) / Lambda'(X^-1)
        Y = gf.gf_mul(X, gf.gf_div(omega_val, lam_prime))
        errors.append((p, Y))

    return errors

def correct_block(block: List[int], ec_len: int) -> Tuple[List[int], int, bool]:
    """
    Correct a single Reed-Solomon codeword block of length n = data_len + ec_len.
    Returns (corrected_block, num_errors, success).
    If uncorrectable, returns (original_block, -1, False).
    """
    n = len(block)
    t = ec_len // 2  # Error correction capacity

    syndromes = compute_syndromes(block, ec_len)
    if all(s == 0 for s in syndromes):
        return list(block), 0, True

    Lambda, L = berlekamp_massey(syndromes, ec_len)
    if L > t or len(Lambda) - 1 != L:
        # Errors exceed capacity t
        return list(block), -1, False

    error_positions = chien_search(Lambda, n)
    if error_positions is None:
        # Chien search failed to locate all roots in the code length
        return list(block), -1, False

    try:
        errors = forney(syndromes, Lambda, error_positions, n, ec_len)
    except Exception:
        return list(block), -1, False

    corrected = list(block)
    for p, Y in errors:
        corrected[p] = gf.gf_sub(corrected[p], Y)

    # Validation: recompute syndromes on the corrected block
    check_syndromes = compute_syndromes(corrected, ec_len)
    if not all(s == 0 for s in check_syndromes):
        # Miscorrection detected
        return list(block), -1, False

    return corrected, len(errors), True

# --- Reference RS Encoder for test vector generation ---
def generate_generator_poly(ec_len: int) -> List[int]:
    """Compute g(x) = prod_{i=0}^{ec_len-1} (x - alpha^i). Highest degree first."""
    g = [1]
    for i in range(ec_len):
        g = gf.poly_mul(g, [1, gf.alpha_pow(i)])
    return g

def encode_block(data_bytes: List[int], ec_len: int) -> List[int]:
    """
    Encode data_bytes into a complete RS codeword (data + check bytes).
    Check bytes are remainder of (data(x) * x^ec_len) / g(x).
    """
    g = generate_generator_poly(ec_len)
    msg = list(data_bytes) + [0] * ec_len
    for i in range(len(data_bytes)):
        lead = msg[i]
        if lead != 0:
            for j in range(len(g)):
                msg[i + j] = gf.gf_add(msg[i + j], gf.gf_mul(lead, g[j]))
    check_bytes = msg[len(data_bytes):]
    return list(data_bytes) + check_bytes

