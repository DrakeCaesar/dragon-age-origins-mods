"""Swap one entry's contents for another inside a DAO .rim archive.

Used to test whether a room's far model (_ll) is what the renderer falls back to:
copy the close model (_lc) over the far entry so both variants hold the same
geometry. Creates a .orig backup on first use.

    python rimswap.py orz702d_6670.rim orz702d_6670_ll.mmh=orz702d_6670_lc.mmh

Revert with:  python rimswap.py --revert orz702d_6670.rim
"""
import os
import shutil
import struct
import sys


def read_rim(path):
    d = open(path, "rb").read()
    count = struct.unpack_from("<I", d, 0x10)[0]
    ents = []
    for i in range(count):
        o = 0x20 + i * 0x48
        name = d[o:o + 0x40].decode("utf-16-le").rstrip("\0")
        off, size = struct.unpack_from("<II", d, o + 0x40)
        ents.append((name, d[off:off + size]))
    return d[:0x20], ents


def write_rim(path, header, ents):
    out = bytearray(header)
    cursor = 0x20 + len(ents) * 0x48
    table = []
    for name, blob in ents:
        table.append((name, cursor, len(blob)))
        cursor += len(blob)
    for name, off, size in table:
        rec = bytearray(0x48)
        nb = name.encode("utf-16-le")[:0x3E]
        rec[0:len(nb)] = nb
        struct.pack_into("<II", rec, 0x40, off, size)
        out += rec
    for name, blob in ents:
        out += blob
    open(path, "wb").write(bytes(out))


def main(argv):
    if not argv:
        print(__doc__)
        return 1
    path = argv[0]
    backup = path + ".orig"

    if argv[1:2] == ["--revert"]:
        if not os.path.exists(backup):
            print("no backup to revert to")
            return 1
        shutil.copy2(backup, path)
        print(f"reverted {os.path.basename(path)} from {os.path.basename(backup)}")
        return 0

    if not os.path.exists(backup):
        shutil.copy2(path, backup)

    header, ents = read_rim(backup)
    body = dict(ents)
    changed = 0
    for spec in argv[1:]:
        old, _, new = spec.partition("=")
        if old in body and new in body:
            body[old] = body[new]
            changed += 1
            print(f"  {old} <- {new} ({len(body[new])} bytes)")
        else:
            print(f"  {spec}: missing entry, skipped")

    write_rim(path, header, [(name, body[name]) for name, _ in ents])
    print(f"{os.path.basename(path)}: rewrote {changed} entries")
    print(f"revert with: python rimswap.py --revert {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
