"""protocol_spec.py -- Person B's independent checker for the PUBLIC interface.

Owner: Person B (Kishore).  It checks the rules C1-C5 and A3 of spec Section
4.3 by reading a simple event log that a testbench prints while it drives the
decoder.  It does NOT copy the decoder's state machine: it only knows what the
spec promises at the interface, so any correct design must pass it.

Log format v1 (one event per line, cycle numbers never go down):
    @<cycle> start <size>          start(size) fired in this cycle
    @<cycle> req <row> <col>       mem.req was taken in this cycle
    @<cycle> byte <hex> <last>     getByte fired; last is 0 or 1
    @<cycle> status <f> <d>        values of failed() and done() in this cycle
                                   (print every cycle, or only when they change)
Lines that do not start with '@' are ignored, so the log can be mixed with
other $display output.

Use:
    from protocol_spec import parse_log, check
    report = check(parse_log(text), expected=[("ok", b"HELLO"), ("fail", None)])
    report.ok, report.problems, report.notes
"""
from typing import Dict, List, Optional, Tuple


# ------------------------------------------------------------------ events
class Event:
    """One line of the log.  kind: start | req | byte | status.
    a = size | row | data | failed      b = - | col | last | done"""

    def __init__(self, cycle: int, kind: str, a: int = 0, b: int = 0):
        self.cycle, self.kind, self.a, self.b = cycle, kind, a, b


def parse_log(text: str) -> List[Event]:
    events = []
    for lineno, line in enumerate(text.splitlines(), 1):
        line = line.strip()
        if not line.startswith("@"):
            continue
        parts = line[1:].split()
        cyc, kind, args = int(parts[0]), parts[1], parts[2:]
        if kind == "start":
            events.append(Event(cyc, kind, int(args[0])))
        elif kind == "req":
            events.append(Event(cyc, kind, int(args[0]), int(args[1])))
        elif kind == "byte":
            events.append(Event(cyc, kind, int(args[0], 16), int(args[1])))
        elif kind == "status":
            events.append(Event(cyc, kind, int(args[0]), int(args[1])))
        else:
            raise ValueError(f"line {lineno}: unknown event '{kind}'")
    for x, y in zip(events, events[1:]):
        if y.cycle < x.cycle:
            raise ValueError(f"cycle numbers go backwards at cycle {y.cycle}")
    return events


# ------------------------------------------------------------------ report
class Transaction:
    """One decode: from a start to its failed/done."""

    def __init__(self, start_cycle: int, size: int):
        self.start_cycle = start_cycle
        self.size = size
        self.bytes_taken = []     # type: List[int]
        self.last_cycle = None    # cycle the byte with last=1 was taken
        self.end = None           # "done" | "failed" | "timeout" | None (never ended)
        self.end_cycle = None
        self.requests = 0


class Report:
    """ok, problems (spec violations), notes (information), transactions."""

    def __init__(self):
        self.ok = True
        self.problems = []        # type: List[str]
        self.notes = []           # type: List[str]
        self.transactions = []    # type: List[Transaction]

    def bad(self, msg: str):
        self.ok = False
        self.problems.append(msg)


# ------------------------------------------------------------------ checker
def check(events: List[Event], expected=None, cycle_limit: Optional[int] = None) -> Report:
    """Check the log against C1-C5 (and A3).

    expected: optional list, one entry per start, each ("ok", bytes) or
              ("fail", None).  If given, outcomes and bytes are compared.
    cycle_limit: optional; a decode not ended within this many cycles of its
              start is reported (the spec's 'generous cycle limit').
    """
    rep = Report()
    failed = done = 0          # current values of the two status signals
    cur: Optional[Transaction] = None

    # Group events by cycle so that same-cycle events are judged together.
    by_cycle = {}   # type: Dict[int, List[Event]]
    for e in events:
        by_cycle.setdefault(e.cycle, []).append(e)

    for cyc in sorted(by_cycle):
        evs = by_cycle[cyc]
        starts = [e for e in evs if e.kind == "start"]
        reqs = [e for e in evs if e.kind == "req"]
        byts = [e for e in evs if e.kind == "byte"]
        stats = [e for e in evs if e.kind == "status"]

        # status seen in this cycle (values hold until the next status line)
        if stats:
            failed, done = stats[-1].a, stats[-1].b
            if failed and done:
                rep.bad(f"@{cyc}: failed and done are both high (C2)")

        # ---- C2: the status before the first start must be low
        if cur is None and not starts and (failed or done):
            rep.bad(f"@{cyc}: failed/done high before any start (C2)")

        # ---- C4: at most one request per cycle
        if len(reqs) > 1:
            rep.bad(f"@{cyc}: {len(reqs)} memory requests in one cycle (C4)")
        if len(byts) > 1:
            rep.bad(f"@{cyc}: getByte fired {len(byts)} times in one cycle")

        # ---- the open transaction: status rules, then bytes
        if cur is not None and cur.start_cycle < cyc:
            ended = cur.end is not None
            if not ended:
                if failed:
                    cur.end, cur.end_cycle = "failed", cyc
                elif done:
                    cur.end, cur.end_cycle = "done", cyc
                    # C2: done only after the last byte was taken, or empty message
                    if any(b.b for b in byts):
                        rep.bad(f"@{cyc}: done rose in the same cycle as the last byte (C2)")
                    elif cur.bytes_taken and cur.last_cycle is None:
                        rep.bad(f"@{cyc}: done rose but the byte with last was never taken (C2)")
            else:
                # C2: once high, it must stay high until the next start
                if cur.end == "failed" and not failed:
                    rep.bad(f"@{cyc}: failed fell before the next start (C2)")
                if cur.end == "done" and not done:
                    rep.bad(f"@{cyc}: done fell before the next start (C2)")
                if cur.end == "failed" and done:
                    rep.bad(f"@{cyc}: done rose after failed (C2: exactly one rises)")
                if cur.end == "done" and failed:
                    rep.bad(f"@{cyc}: failed rose after done (C2: exactly one rises)")

        for e in byts:
            if cur is None:
                rep.bad(f"@{cyc}: getByte fired before any start (C1)")
                continue
            if cur.end == "failed" and cur.end_cycle <= cyc:
                rep.bad(f"@{cyc}: getByte fired after failed rose (C3)")
            if cur.end == "done" and cur.end_cycle < cyc:
                rep.bad(f"@{cyc}: getByte fired after done rose (C1)")
            if cur.last_cycle is not None:
                rep.bad(f"@{cyc}: getByte fired after the byte with last (C1)")
            cur.bytes_taken.append(e.a)
            if e.b:
                cur.last_cycle = cyc

        if cur is not None and reqs:
            cur.requests += len(reqs)
            if cur.end is not None and cur.end_cycle < cyc:
                rep.notes.append(f"@{cyc}: memory request after the decode ended (allowed, but wasteful)")

        # ---- a new start (A3: only when idle)
        for e in starts:
            if cur is not None and cur.end is None:
                if cur.last_cycle is not None:
                    rep.bad(f"@{cyc}: previous decode took its last byte but done never rose (C2)")
                else:
                    rep.bad(f"@{cyc}: start fired while a decode was still running (A3: testbench error)")
            cur = Transaction(start_cycle=cyc, size=e.a)
            rep.transactions.append(cur)

        if cur is not None and cycle_limit and cur.end is None and cyc - cur.start_cycle > cycle_limit:
            rep.bad(f"@{cyc}: decode started at @{cur.start_cycle} has not ended after {cycle_limit} cycles")
            cur.end, cur.end_cycle = "timeout", cyc

    # ---- end of log
    if cur is not None and cur.end is None:
        rep.bad(f"decode started at @{cur.start_cycle} never ended (no failed/done in the log)")

    # ---- compare with the expected outcomes
    if expected is not None:
        if len(expected) != len(rep.transactions):
            rep.bad(f"{len(rep.transactions)} decodes in the log, {len(expected)} expected")
        for i, (t, (want, msg)) in enumerate(zip(rep.transactions, expected)):
            if want == "fail":
                if t.end != "failed":
                    rep.bad(f"decode #{i} (@{t.start_cycle}): expected failed, got {t.end}")
            else:
                if t.end != "done":
                    rep.bad(f"decode #{i} (@{t.start_cycle}): expected success, got {t.end}")
                elif bytes(t.bytes_taken) != bytes(msg):
                    rep.bad(f"decode #{i} (@{t.start_cycle}): bytes differ: got {bytes(t.bytes_taken)!r}, "
                            f"want {bytes(msg)!r}")
                if msg and t.last_cycle is None:
                    rep.bad(f"decode #{i}: no byte had last set")
                if not msg and t.bytes_taken:
                    rep.bad(f"decode #{i}: empty message expected but bytes were returned")
    for t in rep.transactions:
        if t.end == "done" and t.last_cycle is not None:
            rep.notes.append(f"decode @{t.start_cycle}: latency {t.last_cycle - t.start_cycle} cycles "
                             f"(start to last byte taken), {t.requests} memory reads")
    return rep


# ------------------------------------------------------------------ C5
def check_c5_verilog(verilog_text: str) -> List[str]:
    """C5 and the supplied attributes, checked in the Verilog bsc generates.
    bsc drops the RDY_ port of an always_ready method and the EN_ port of an
    always_enabled one, so the port names tell us which attributes were used."""
    problems = []
    has = lambda port: port in verilog_text
    if not has("RDY_start"):
        problems.append("start has no RDY_start port: always_ready was added (C5)")
    if not has("RDY_getByte"):
        problems.append("getByte has no RDY_getByte port: always_ready was added (C5)")
    if not has("EN_start"):
        problems.append("start has no EN_start port: always_enabled was added (C5)")
    if not has("EN_getByte"):
        problems.append("getByte has no EN_getByte port: always_enabled was added (C5)")
    if has("EN_mem_resp"):
        problems.append("mem_resp has an EN port: the supplied always_enabled is missing")
    if "module mkQRDecoder" not in verilog_text:
        problems.append("no 'module mkQRDecoder' found: wrong file or renamed module")
    return problems


if __name__ == "__main__":
    import sys
    rep = check(parse_log(open(sys.argv[1]).read()))
    print("OK" if rep.ok else "PROBLEMS FOUND")
    for p in rep.problems:
        print("  problem:", p)
    for n in rep.notes:
        print("  note:   ", n)
