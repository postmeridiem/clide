#!/usr/bin/env python3
"""Merge lcov files into one, on stdout.

clide runs coverage in two passes — the parallel pool and a serial
(`--tags serial --concurrency=1`) pass for tests that can't share the
parallel runner (T-193). Each `flutter test --coverage` pass overwrites
coverage/lcov.info, and the coverage gate naively sums LF:/LH: across
records, so a source file appearing in BOTH passes would double-count.

This unions DA (line→hits) per source file, taking the MAX hit count (a
line executed in EITHER pass counts as hit), then recomputes LF/LH. Line
coverage only — which is all flutter emits and all the gate reads. No
`lcov` dependency.

Usage: merge_lcov.py a.info b.info [...] > merged.info
"""
import sys

files = {}   # source path -> {line: hits}
order = []   # first-seen order, for stable output

for path in sys.argv[1:]:
    cur = None
    with open(path) as fh:
        for raw in fh:
            line = raw.rstrip("\n")
            if line.startswith("SF:"):
                cur = line[3:]
                if cur not in files:
                    files[cur] = {}
                    order.append(cur)
            elif line.startswith("DA:") and cur is not None:
                num, _, hits = line[3:].partition(",")
                num, hits = int(num), int(hits)
                files[cur][num] = max(files[cur].get(num, 0), hits)
            elif line == "end_of_record":
                cur = None

out = []
for sf in order:
    da = files[sf]
    out.append("SF:" + sf)
    for num in sorted(da):
        out.append(f"DA:{num},{da[num]}")
    out.append(f"LF:{len(da)}")
    out.append(f"LH:{sum(1 for h in da.values() if h > 0)}")
    out.append("end_of_record")

sys.stdout.write("\n".join(out) + "\n")
