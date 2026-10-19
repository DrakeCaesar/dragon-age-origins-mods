"""Enumerate and extract resources from a Dragon Age ERF V2.0 archive.

DAO stores module and designer data in "ERF V2.0" archives whose strings are
UTF-16. The layout is:

    0x00  char[16] "ERF V2.0"                 (UTF-16)
    0x10  uint32   entry count
    0x14  uint32   offset to localized strings
    0x18  uint32   offset to ??? (unused here)
    0x1C  uint32   0xFFFFFFFF
    0x20  entries, 72 bytes each:
            char[64] name (UTF-16, includes the extension)
            uint32   absolute file offset of the data
            uint16   resource type
            uint16   unused

Data offsets are absolute, so a resource's size is the next higher offset.

    python daerf.py <archive>                 list entries
    python daerf.py <archive> --match pre100  list matching entries
    python daerf.py <archive> --extract NAME  write NAME to the current directory
"""
import os
import struct
import sys


def read_entries(path):
    d = open(path, "rb").read()
    if d[:8] != b"E\x00R\x00F\x00 \x00":
        raise SystemExit("not an ERF V2.0 archive")
    count = struct.unpack_from("<I", d, 0x10)[0]
    ents = []
    for i in range(count):
        o = 0x20 + i * 0x48
        name = d[o:o + 0x40].decode("utf-16-le").split("\x00")[0]
        off, rtype = struct.unpack_from("<IH", d, o + 0x40)
        ents.append([name, off, rtype, 0])
    starts = sorted(e[1] for e in ents if e[1] < len(d))
    for e in ents:
        nxt = [s for s in starts if s > e[1]]
        e[3] = (nxt[0] if nxt else len(d)) - e[1]
    return d, ents


def main(argv):
    if not argv:
        print(__doc__)
        return 1
    d, ents = read_entries(argv[0])
    if "--extract" in argv:
        want = argv[argv.index("--extract") + 1]
        for name, off, rtype, size in ents:
            if name == want:
                open(name, "wb").write(d[off:off + size])
                print(f"wrote {name} ({size} bytes)")
                return 0
        print("not found")
        return 1

    match = argv[argv.index("--match") + 1].lower() if "--match" in argv else ""
    shown = 0
    for name, off, rtype, size in sorted(ents, key=lambda e: e[0]):
        if match and match not in name.lower():
            continue
        head = d[off:off + 8]
        tag = d[off + 0x0C:off + 0x14].decode("latin-1") if head == b"GFF V4.0" else \
            head.hex(" ")
        print(f"  {name:44s} off=0x{off:08x} size={size:>8} {tag}")
        shown += 1
    print(f"-- {shown} of {len(ents)} entries")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
