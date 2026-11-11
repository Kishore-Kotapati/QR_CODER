#!/usr/bin/env bash
# One-command verification runner.
#   bash verification/run_tests.sh quick   Python model tests + Bluespec unit test benches (a few minutes)
#   bash verification/run_tests.sh full    quick + 2 hardware sweeps of 120 full-decoder symbols each (~30 min)
# Run from the folder that holds bsv/ and verification/ (or from anywhere; it finds its own way).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"
MODE="${1:-quick}"; cd "$ROOT"
FAIL=0; B="$HERE/_build"; rm -rf "$B"; mkdir -p "$B"
say() { printf '%-44s %s\n' "$1" "$2"; }

echo "== 1. Python reference models and their self-tests"
for t in "$HERE"/tests/test_*.py; do
  n=$(basename "$t")
  if (cd "$HERE" && timeout 600 python3 "tests/$n" < /dev/null > "$B/$n.out" 2>&1); then say "$n" PASS; else say "$n" FAIL; FAIL=$((FAIL+1)); fi
done

echo "== 2. Bluespec test benches (GF, RS, syndrome, Berlekamp-Massey, de-interleave, corner cases, payload modes, version 40)"
for tb in TbGF TbGFVectors TbRS TbSyndrome TbBM TbBlocks TbCornerCases TbPayloadModes TbVersion40Mask3; do
  [ -f "$HERE/tb/$tb.bsv" ] || { say "$tb" "MISSING"; FAIL=$((FAIL+1)); continue; }
  W="$B/$tb"; mkdir -p "$W/o"; cp "$ROOT"/bsv/QR*.bsv "$HERE/tb/$tb.bsv" "$W/"
  ( cd "$W" && bsc -u -sim -bdir o -simdir o -info-dir o -g mk$tb $tb.bsv > compile.log 2>&1 \
      && bsc -sim -e mk$tb -bdir o -simdir o -o run > link.log 2>&1 \
      && (cd "$HERE/vectors/backend" && timeout 1800 "$W/run" > "$W/run.log" 2>&1) )
  if [ -s "$W/run.log" ] && ! grep -qE 'RESULT: FAIL|MISMATCH|\[FAIL\]|ERROR|Error:|error:|TESTS? FAILED|assertion' "$W/run.log"; then say "$tb" "PASS ($(grep -c . "$W/run.log") lines)"; else say "$tb" "FAIL (see $W/run.log)"; FAIL=$((FAIL+1)); fi
done

if [ "$MODE" = "full" ]; then
  for S in cases cases_model; do
    echo "== 3. Full-decoder hardware sweep: $S"
    D="$HERE/sweep/$S"
    if [ ! -f "$D/expected.json" ]; then
      if [ "$S" = cases ]; then python3 "$HERE/sweep/gen_sweep_segno.py" "$D" 120; else python3 "$HERE/sweep/gen_sweep.py" "$D" 120; fi
    fi
    rm -rf "$D/logs"
    for s in 0 1 2 3; do bash "$HERE/sweep/run_sweep.sh" "$D" $s 4 > "$D/shard$s.out" 2>&1 & done; wait
    if python3 "$HERE/sweep/check_sweep.py" "$D" | tee "$D/SWEEP_RESULT.txt" | tail -1 | grep -q 'MISMATCHES: 0'; then say "sweep $S" PASS; else say "sweep $S" FAIL; FAIL=$((FAIL+1)); fi
    rm -rf "$D"/work_*
  done
fi
[ $FAIL -eq 0 ] && rm -rf "$B"
echo; [ $FAIL -eq 0 ] && echo "ALL VERIFICATION STEPS PASSED" || echo "$FAIL STEP(S) FAILED"
exit $FAIL
