#!/usr/bin/env bash
# run_icc.sh -- place and route (ICC) of a synthesized decoder netlist.  Person B.
#
#   TAG=r2        which DC run to use: pd/experiments/B2_full/outputs_<TAG>/ (required)
#   PERIOD=6.0    clock period for ICC in ns (DC used 5.0; the extra time is the margin)
#   UTIL=0.6      how full the core is with cells (0.6 = 60 %); sets the core size
#   CORES=8       CPU cores ICC may use
#   DONT_USE="..." library cells ICC must not use (v6; use the same list as DC)
#   DENSITY=      optional local cell density limit for placement, e.g. 0.65
#   NAME=...      run folder name (default <TAG>_<PERIOD>ns) -> pd/icc/run_<NAME>/
#
# Example (inside tmux):  TAG=r2 PERIOD=6.0 bash run_icc.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(cd "$HERE/../.." && pwd)"
TAG="${TAG:?set TAG, e.g. TAG=r2}"
PERIOD="${PERIOD:-6.0}"; UTIL="${UTIL:-0.6}"; CORES="${CORES:-8}"
NAME="${NAME:-${TAG}_${PERIOD}ns}"
DCO="$WORK/pd/experiments/B2_full/outputs_$TAG"; DCR="$WORK/pd/experiments/B2_full/reports_$TAG"
NET="$DCO/mkQRDecoder.verilog_noassign.v"
command -v icc_shell >/dev/null || { echo "icc_shell not found: open a new login shell"; exit 1; }
[ -f "$NET" ] || { echo "STOP: $NET not found (did DC run $TAG finish?)"; exit 1; }
# core size: side L (um) so that cell area / L^2 = UTIL
AREA=$(grep -E "^\s*Cell Area:" "$DCR/dc_compile_ultra_1.qor" | head -1 | awk '{print $3}')
[ -n "$AREA" ] || { echo "STOP: no Cell Area in $DCR/dc_compile_ultra_1.qor"; exit 1; }
L=$(awk -v a="$AREA" -v u="$UTIL" 'BEGIN{l=sqrt(a/u); l=int(l/10+1)*10; print l}')
[ -n "${CORE_L:-}" ] && L=$CORE_L
R="$HERE/run_$NAME"
# B: v4: several runs may go at the same time, but not two in the same folder
if [ -f "$R/RUNNING" ] && kill -0 "$(cat "$R/RUNNING")" 2>/dev/null; then
  echo "STOP: run_$NAME is already running (pid $(cat "$R/RUNNING")); use another NAME"; exit 1
fi
rm -rf "$R"; mkdir -p "$R"/{scripts,work,reports,results,database}
cp "$HERE"/scripts/*.tcl "$R/scripts/"
HALF=$(awk -v t="$PERIOD" 'BEGIN{print t/2}'); IOD=$(awk -v t="$PERIOD" 'BEGIN{print 0.4*t}')
cat > "$R/scripts/qr_icc.sdc" <<SDC
# same constraints as DC (team SDC, 40 % IO delay), period $PERIOD ns
create_clock -name CLK -period $PERIOD -waveform {0.0 $HALF} [get_ports CLK]
set_input_delay  -clock CLK $IOD [all_inputs]
set_output_delay -clock CLK $IOD [all_outputs]
SDC
export QR_DONT_USE="${DONT_USE:-}" QR_DENSITY="${DENSITY:-}" QR_NET="$NET" QR_PERIOD="$PERIOD" QR_L="$L" QR_CORES="$CORES"
echo ">>> ICC mkQRDecoder [$NAME]: DC run $TAG, period $PERIOD ns, cell area $AREA um2 -> core $L x $L um (util $UTIL)"
echo "    started $(date '+%a %d %b %T'); progress: grep 'B: STAGE' $R/icc.log"
t0=$(date +%s)
echo $$ > "$R/RUNNING"
( cd "$R/work" && icc_shell -shared_license -f ../scripts/icc_qr.tcl > ../icc.log 2>&1 )
t1=$(date +%s)
rm -f "$R/RUNNING"
echo "    finished $(date '+%a %d %b %T'), $(( (t1-t0)/3600 )) h $(( (t1-t0)%3600/60 )) min"
bash "$HERE/icc_summary.sh" "$R" | tee "$R/summary.txt"
