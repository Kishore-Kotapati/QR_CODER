#!/usr/bin/env python3
"""check_sweep.py <sweep_dir>: compares each hardware log with what the generator expected.

none / limit : hardware MUST decode and the bytes must equal the original text.
over         : hardware may report FAILED, or (rarely, by chance) decode something else;
               it must NOT time out or fail to compile.
"""
import json, os, sys, collections
sw = sys.argv[1]
exp = json.load(open(os.path.join(sw, "expected.json")))
bad, cnt = [], collections.Counter()
notes = collections.Counter()
for name, e in sorted(exp.items()):
    p = os.path.join(sw, "logs", name + ".log")
    desc = "[v%d %s mask%d %s damage=%s]" % (e["version"], e["level"], e["mask"], "+".join(e["modes"]), e["damage"])
    if not os.path.exists(p):
        bad.append((name, "not run " + desc)); cnt["not run"] += 1; continue
    lines = open(p, errors="replace").read().splitlines()
    got = [l.split()[1] for l in lines if l.startswith("BYTE ")]
    res = [l for l in lines if l.startswith("RESULT")]
    r = res[0].split()[1] if res else "NONE"
    if e["damage"] == "over":
        ok = r in ("FAILED", "DONE")
        if ok:
            notes["over: hardware reported failed" if r == "FAILED" else "over: hardware decoded something"] += 1
    else:
        ok = (r == "DONE" and got == e["bytes_hex"])
    cnt[e["damage"] + (" PASS" if ok else " FAIL")] += 1
    if not ok:
        bad.append((name, "hw=%s %d bytes, expected %d bytes %s" % (r, len(got), len(e["bytes_hex"]), desc)))
print("cases: %d" % len(exp))
for k in sorted(cnt):
    print("  %-14s %d" % (k, cnt[k]))
for k in sorted(notes):
    print("  (%s: %d)" % (k, notes[k]))
print("MISMATCHES: %d" % len(bad))
for n, m in bad[:40]:
    print("  ", n, m)
sys.exit(1 if bad else 0)
