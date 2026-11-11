# Verification

Run everything with one command, from this folder (`make test` runs 8 Python test files and 9 Bluespec benches):

```
make test     # about 5 minutes: Python reference-model tests + Bluespec unit test benches
make full     # about 30 minutes: the above + two hardware sweeps of 120 symbols each
```
(`bash run_tests.sh quick` / `bash run_tests.sh full` do the same without `make`.) The runner prints PASS or FAIL for each step and finishes with `ALL VERIFICATION STEPS PASSED`. Needs `bsc` and Python 3 with the `segno` package.

## What is here

| Folder / file | Purpose |
|---|---|
| `model/` | Independent Python reference model, written by the team member who did not write the RTL: front end (`front_ref`), GF(2^8) (`gf_ref`), Reed-Solomon (`rs_ref`), de-interleave (`blocks_ref`), payload (`payload_ref`) and a full decoder (`decode_ref`). |
| `tests/` | Self-tests of the model (against `segno`, the course tables and the protocol in the spec) and of the backend model: 8 files. |
| `vectors/` | Hex vectors from the model (GF products, RS, syndromes, block layout) that the Bluespec benches compare against. |
| `tb/` | Bluespec test benches for the blocks: `TbGF`, `TbGFVectors`, `TbRS`, `TbSyndrome`, `TbBM`, `TbBlocks` (blocks), and full-decoder benches `TbCornerCases` (10 corner cases), `TbPayloadModes` (5 payload-mode and multi-block cases), `TbVersion40Mask3` (177x177, 2,953 bytes), `TbLogged`, `TbDamaged3`, `TbDamaged6`. |
| `sweep/` | Full-decoder hardware sweeps (below). |
| `results/` | Saved logs of earlier runs, kept as evidence. |

## Hardware sweeps (full `mkQRDecoder`, Bluesim, default build)

Each case is one generated bench that holds a whole symbol in a memory model, calls `start(size)`, answers `mem` requests, and compares every output byte with the original text.

| Sweep | Symbols made by | Cases | Result |
|---|---|---|---|
| `sweep/cases` | `segno` library (independent third party); a sample also decoded by `zxing-cpp` | 120 | 30 clean, 60 damaged within limit: all decode exactly; 30 over limit: all report `failed` |
| `sweep/cases_model` | the team model (`gen_sweep.py`), mixed-mode multi-segment messages | 120 | same split, all as required, 0 mismatches |

Coverage: 15 versions spread over 1 to 40 (including versions with version-information blocks), all four error-correction levels, all eight masks, numeric / alphanumeric / byte modes, short and full-capacity messages. "Within limit" means damaged data and check bytes up to the repair capacity of each block (the model sweep damages every block by its maximum); "over limit" damages one block beyond capacity and the decoder must raise `failed` and must not hang (cycle limit 200,000, never reached).

## Other checks

- Unit benches compare the hardware blocks against the model vectors (GF multiplier exhaustively, 65,536 products).
- Model-level tests (`tests/`) cover invalid symbol size, uncorrectable format information, restart without reset, and damaged finder / timing patterns not rejecting the symbol.
- Cycle count for the 177 x 177 version-40 test bench (`TbVersion40`): 38,074 cycles (bsc 2021.12.1, default build).

## Known limits

Message sweeps use at most one run of segments per mode; no symbol with more than 3 damaged format bits is expected to decode; the sweeps do not damage format-information bits (those are covered by the corner-case benches).
