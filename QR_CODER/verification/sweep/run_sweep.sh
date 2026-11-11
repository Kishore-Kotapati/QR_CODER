#!/usr/bin/env bash
# run_sweep.sh <sweep_dir> <shard> <num_shards>
# Compiles and runs every test bench in <sweep_dir> whose index % num_shards == shard,
# using the design in ../bsv (default flags). Logs go to <sweep_dir>/logs/.
set -u
SW="$(cd "$1" && pwd)"; SHARD="${2:-0}"; NSH="${3:-1}"
BSV="$(cd "$(dirname "$0")/../../bsv" && pwd)"
W="$SW/work_$SHARD"; mkdir -p "$W/build" "$SW/logs"
cp "$BSV"/QR*.bsv "$W/"
i=0
for tb in "$SW"/TbSweep*.bsv; do
  name=$(basename "$tb" .bsv)
  if [ $(( i % NSH )) -eq "$SHARD" ]; then
    cp "$tb" "$W/"
    ( cd "$W"
      bsc -u -sim -bdir build -simdir build -info-dir build -g mk$name $name.bsv +RTS -M16g -RTS > "$SW/logs/$name.compile" 2>&1 \
        && bsc -sim -e mk$name -bdir build -simdir build -o build/$name > "$SW/logs/$name.link" 2>&1
      if [ -x build/$name ]; then timeout 900 ./build/$name > "$SW/logs/$name.log" 2>&1; else echo "RESULT COMPILE_FAILED" > "$SW/logs/$name.log"; fi
    )
    echo "$name: $(grep -h RESULT "$SW/logs/$name.log" | head -n 1)"
  fi
  i=$((i+1))
done
echo "shard $SHARD finished"
