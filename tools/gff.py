"""Read BioWare GFF files as used by Dragon Age (ARE, GIT, IFO, UTP, UTI...).

The layout is the classic BioWare one, with a short magic such as "ARE V3.2"
followed by twelve offset/count words at 0x08. Three details are easy to get
wrong and are the reason this parser exists:

  * a field record is (type, labelIndex, data), not (labelIndex, type, data)
  * a struct's data offset indexes the field index array, which then indexes the
    field records; that array is a permutation, not the identity
  * the last two header words are byte sizes, not entry counts

Reading is lazy: lists and nested structs are returned as placeholders so a file
can be inspected without expanding everything.

    python gff.py <file>                            list top-level fields
    python gff.py <file> PlaceableList              dump one list
    python gff.py <file> PlaceableList Tag,XPosition  only these keys
"""
import struct
import sys

INLINE = {0: "<B", 1: "<b", 2: "<H", 3: "<h", 4: "<I", 5: "<i", 8: "<f"}
BYTE, CHAR, WORD, SHORT, DWORD, INT, DWORD64, INT64, FLOAT, DOUBLE, \
    STRING, RESREF, LOCSTRING, VOID, STRUCT, LIST = range(16)


class Gff:
    def __init__(self, data):
        self.d = data
        (self.struct_off, self.struct_count, self.field_off, self.field_count,
         self.label_off, self.label_count, self.data_off, self.data_size,
         self.fidx_off, self.fidx_size, self.lidx_off, self.lidx_size) = \
            struct.unpack_from("<12I", data, 0x08)
        self._ends = None

    def label(self, i):
        o = self.label_off + i * 16
        return self.d[o:o + 16].split(b"\0")[0].decode("latin-1")

    def fields(self, si):
        _, doff, fcount = struct.unpack_from("<3I", self.d, self.struct_off + si * 12)
        # DataOffset is a byte offset into the field index array, which then gives
        # the field record index.
        if doff % 4:
            return
        base = doff // 4
        limit = self.fidx_size // 4
        for i in range(fcount):
            if base + i >= limit:
                return
            fi = struct.unpack_from("<I", self.d, self.fidx_off + (base + i) * 4)[0]
            if fi >= self.field_count:
                return
            t, li, v = struct.unpack_from("<3I", self.d, self.field_off + fi * 12)
            yield self.label(li), t, v

    def list_range(self, start):
        """List data is a byte offset into the index block, not an entry index."""
        if self._ends is None:
            starts = {v for si in range(self.struct_count) for _, t, v in self.fields(si) if t == LIST}
            ordered = sorted(starts)
            self._ends = dict(zip(ordered, ordered[1:]))
        end = self._ends.get(start, self.lidx_size)
        if end <= start or end > self.lidx_size:
            return 0, 0
        return start // 4, end // 4

    def scalar(self, t, v):
        if t in INLINE:
            raw = struct.pack("<I", v)
            return struct.unpack(INLINE[t], raw[:struct.calcsize(INLINE[t])])[0]
        o = self.data_off + v
        if t in (DWORD64, INT64):
            return struct.unpack_from("<Q", self.d, o)[0]
        if t == DOUBLE:
            return struct.unpack_from("<d", self.d, o)[0]
        if t == STRING:
            n = struct.unpack_from("<I", self.d, o)[0]
            return self.d[o + 4:o + 4 + n].decode("latin-1")
        if t == RESREF:
            return self.d[o + 1:o + 1 + self.d[o]].decode("latin-1")
        if t == LOCSTRING:
            return self.locstring(o)
        if t == VOID:
            return f"<{struct.unpack_from('<I', self.d, o)[0]} bytes>"
        return f"<type {t}>"

    def locstring(self, o):
        """A short LocString is just a TLK strref; a long one carries the text."""
        total = struct.unpack_from("<I", self.d, o)[0]
        if total <= 8:
            return f"strref {struct.unpack_from('<I', self.d, o + 4)[0]}"
        count = struct.unpack_from("<I", self.d, o + 4)[0]
        cur, stop = o + 8, o + min(total, 0x10000)
        for _ in range(count):
            if cur + 8 > stop:
                break
            _ref, ln = struct.unpack_from("<2I", self.d, cur)
            cur += 8
            if cur + ln > stop:
                break
            return self.d[cur:cur + ln].decode("latin-1")
        return ""

    def shallow(self, si):
        """Field values without expanding nested lists or structs."""
        out = {}
        for name, t, v in self.fields(si):
            if t == LIST:
                s, e = self.list_range(v)
                out[name] = ("list", s, e)
            elif t == STRUCT:
                out[name] = ("struct", v)
            else:
                out[name] = self.scalar(t, v)
        return out

    def items(self, si, name):
        s, e = self.shallow(si)[name][1:]
        return [self.shallow(i) for i in
                struct.unpack_from("<%dI" % (e - s), self.d, self.lidx_off + s * 4)]


def show(v):
    if isinstance(v, tuple):
        kind = v[0]
        if kind == "list":
            return f"<list of {v[2] - v[1]}>"
        return f"<struct {v[1]}>"
    return v


def main(argv):
    if not argv:
        print(__doc__)
        return 1
    g = Gff(open(argv[0], "rb").read())
    keys = argv[2].split(",") if len(argv) > 2 else None

    if len(argv) == 1:
        for k, v in g.shallow(0).items():
            print(f"  {k} = {show(v)}")
        return 0

    items = g.items(0, argv[1])
    for i, it in enumerate(items):
        if keys:
            print("  " + " | ".join(f"{k}={it.get(k)}" for k in keys))
        else:
            print(f"  [{i}] " + ", ".join(f"{k}={show(v)}" for k, v in it.items()))
    print(f"-- {len(items)} item(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
