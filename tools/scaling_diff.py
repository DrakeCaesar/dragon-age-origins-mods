"""Compare two DAFix creature dumps taken at different party levels.

The scaling probe (`ScalingDiagnostics` in DAFix.ini) logs every creature the game
builds, and for each one the blocks it owns: its own fields, its stats object
(+0x7d0, CCEcreatureStats) and its rank component (+0x4b0). Loading the same area at
two party levels and diffing the two logs is the only handle on the scaling, because
health and damage are floats inside the stats object and moving with party level is
exactly what "scaled" looks like.

Creatures are matched by their world position (creature +0x120), which the template
loader copies from the GFF XPosition/YPosition/ZPosition and which is identical run to
run for the same save and area. Blocks are matched by the label the probe printed
(self, stats, creature+0x4b0, ...).

    python scaling_diff.py level1.log level25.log
    python scaling_diff.py level1.log level25.log --floats-only --top 40
    python scaling_diff.py level1.log level25.log --hits
"""
import argparse
import re
import sys

OBJECT = re.compile(r"object (\d+) at 0x([0-9a-f]+) pos ([-0-9.eE+]+),([-0-9.eE+]+),([-0-9.eE+]+)")
BODY = re.compile(r"Probe:\s+(\S+) at 0x([0-9a-f]+), vtable 0x([0-9a-f]+)")
HIT = re.compile(r"(-?\d+) as (dword|word|byte|float):\s*(.*)$")
INTS = re.compile(r"Probe:\s+ints (.*)$")
FLOATS = re.compile(r"Probe:\s+floats (.*)$")
INT_ENTRY = re.compile(r"\+([0-9a-f]+)=(\d+)")
FLOAT_ENTRY = re.compile(r"\+([0-9a-f]+)=([-0-9.]+)")


def number(text):
    try:
        return round(float(text.rstrip(".")), 2)
    except ValueError:
        return None


def parse(path):
    """-> {(x, y, z): {block label: {"ints": {off: val}, "floats": {off: val}, "hits": set}}}}"""
    creatures = {}
    current = None
    block = None
    with open(path, "r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            marker = line.find("Probe: ")
            if marker < 0:
                continue
            rest = line[marker:]

            match = OBJECT.search(rest)
            if match:
                block = None
                current = None
                position = (number(match.group(3)), number(match.group(4)), number(match.group(5)))
                if None in position:
                    continue
                current = creatures.setdefault(position, {})
                continue
            if current is None:
                continue

            match = BODY.search(rest)
            if match:
                block = current.setdefault(match.group(1), {"ints": {}, "floats": {}, "hits": set()})
                continue
            if block is None:
                continue

            match = INTS.search(rest)
            if match:
                for offset, value in INT_ENTRY.findall(match.group(1)):
                    block["ints"][int(offset, 16)] = int(value)
                continue

            match = FLOATS.search(rest)
            if match:
                for offset, value in FLOAT_ENTRY.findall(match.group(1)):
                    try:
                        block["floats"][int(offset, 16)] = float(value)
                    except ValueError:
                        pass
                continue

            match = HIT.search(rest)
            if match:
                for offset in re.findall(r"\+([0-9a-f]+)", match.group(3)):
                    block["hits"].add(int(offset, 16))
    return creatures


def compare(args):
    low = parse(args.low)
    high = parse(args.high)
    shared = sorted(set(low) & set(high))
    print(f"{args.low}: {len(low)} creatures")
    print(f"{args.high}: {len(high)} creatures")
    print(f"{len(shared)} matched by world position")
    if not shared:
        print("No creature matched - both runs must be the same save's area in the same spot.")
        return 1

    for kind in ("floats", "ints"):
        if args.floats_only and kind == "ints":
            continue
        moved = {}
        for key in shared:
            for label in set(low[key]) & set(high[key]):
                before = low[key][label][kind]
                after = high[key][label][kind]
                for offset in set(before) & set(after):
                    delta = after[offset] - before[offset]
                    if abs(delta) <= args.tolerance:
                        continue
                    entry = moved.setdefault((label, offset), [0, before[offset], after[offset]])
                    entry[0] += 1

        print()
        print(f"--- {kind}: {len(moved)} offsets moved on at least one creature")
        ranked = sorted(moved.items(), key=lambda kv: (-kv[1][0], -abs(kv[1][2] - kv[1][1])))
        print(f"{'block':<18}{'offset':>8}{'moved':>7}{'low':>12}{'high':>12}")
        for (label, offset), (count, before, after) in ranked[:args.top]:
            print(f"{label:<18}+0x{offset:04x}{count:>7}{before:>12.2f}{after:>12.2f}")

    if args.hits:
        print()
        print("Offsets holding the hunt value in both runs:")
        shown = 0
        for key in shared:
            for label in set(low[key]) & set(high[key]):
                common = low[key][label]["hits"] & high[key][label]["hits"]
                for offset in sorted(common):
                    print(f"  {label:<18}+0x{offset:04x} at {key}")
                    shown += 1
                    if shown >= args.top:
                        return 0
        if not shown:
            print("  none")
    return 0


def main(argv):
    parser = argparse.ArgumentParser(description="Diff two DAFix creature dumps.")
    parser.add_argument("low", help="log from the lower party level")
    parser.add_argument("high", help="log from the higher party level")
    parser.add_argument("--top", type=int, default=30, help="how many offsets to print")
    parser.add_argument("--tolerance", type=float, default=0.01, help="ignore smaller changes")
    parser.add_argument("--floats-only", action="store_true", help="skip the integer comparison")
    parser.add_argument("--hits", action="store_true", help="also report shared hunt-value offsets")
    return compare(parser.parse_args(argv))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
