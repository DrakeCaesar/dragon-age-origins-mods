"""Offline PE analysis for daorigins.exe: sections, strings, xref index."""
import struct, sys, os, pickle, re

EXE = r"C:\Steam\steamapps\common\Dragon Age Ultimate Edition\bin_ship\daorigins.exe"
CACHE = r"C:\Users\domin\dev\dao-respec-mod\tools\xrefs.pkl"


class PE:
    def __init__(self, path=EXE):
        self.d = open(path, "rb").read()
        d = self.d
        pe = struct.unpack_from("<I", d, 0x3C)[0]
        nsec, = struct.unpack_from("<H", d, pe + 6)
        optsz, = struct.unpack_from("<H", d, pe + 20)
        self.base, = struct.unpack_from("<I", d, pe + 24 + 28)
        self.image_size, = struct.unpack_from("<I", d, pe + 24 + 56)
        sec = pe + 24 + optsz
        self.secs = []
        for i in range(nsec):
            o = sec + i * 40
            name = d[o:o + 8].rstrip(b"\0").decode("latin1")
            vsz, va, rsz, ra = struct.unpack_from("<IIII", d, o + 8)
            self.secs.append(dict(name=name, va=self.base + va, vsz=vsz, ra=ra, rsz=rsz))

    def sec(self, name):
        for s in self.secs:
            if s["name"] == name:
                return s
        raise KeyError(name)

    def off2va(self, off):
        for s in self.secs:
            if s["ra"] <= off < s["ra"] + s["rsz"]:
                return s["va"] + (off - s["ra"])
        return None

    def va2off(self, va):
        for s in self.secs:
            if s["va"] <= va < s["va"] + max(s["vsz"], s["rsz"]):
                return s["ra"] + (va - s["va"])
        return None

    def read(self, va, n):
        o = self.va2off(va)
        return self.d[o:o + n] if o is not None else None

    def cstr(self, va, maxlen=200):
        o = self.va2off(va)
        if o is None:
            return None
        e = self.d.find(b"\0", o, o + maxlen)
        if e < 0:
            return None
        try:
            return self.d[o:e].decode("ascii")
        except UnicodeDecodeError:
            return None

    def wstr(self, va, maxlen=400):
        o = self.va2off(va)
        if o is None:
            return None
        e = o
        while e + 1 < o + maxlen and self.d[e:e + 2] != b"\0\0":
            e += 2
        try:
            return self.d[o:e].decode("utf-16-le")
        except UnicodeDecodeError:
            return None


def find_string(pe, needle, utf16=False):
    """Return list of (va, text) for strings containing needle."""
    out = []
    if utf16:
        pat = needle.encode("utf-16-le")
    else:
        pat = needle.encode("ascii")
    i = 0
    while True:
        i = pe.d.find(pat, i)
        if i < 0:
            break
        va = pe.off2va(i)
        if va:
            out.append((va, pe.wstr(va) if utf16 else pe.cstr(va)))
        i += 1
    return out


def build_xrefs(pe, limit_lo=None, limit_hi=None):
    """Linear-sweep .text and index every instruction referencing an absolute
    address inside the image. Returns dict target_va -> [(src_va, text)]."""
    from capstone import Cs, CS_ARCH_X86, CS_MODE_32, CS_OP_IMM, CS_OP_MEM
    text = pe.sec(".text")
    lo = limit_lo if limit_lo is not None else pe.base
    hi = limit_hi if limit_hi is not None else pe.base + pe.image_size
    md = Cs(CS_ARCH_X86, CS_MODE_32)
    md.detail = True
    xr = {}
    start = text["va"]
    end = text["va"] + text["rsz"]
    blob = pe.d[text["ra"]:text["ra"] + text["rsz"]]
    addr = start
    while addr < end:
        code = blob[addr - start: addr - start + 16]
        got = False
        for ins in md.disasm(code, addr):
            got = True
            for op in ins.operands:
                val = None
                if op.type == CS_OP_IMM:
                    val = op.imm & 0xFFFFFFFF
                elif op.type == CS_OP_MEM:
                    m = op.mem
                    if m.base == 0 and m.index == 0:
                        val = m.disp & 0xFFFFFFFF
                if val is not None and lo <= val < hi:
                    xr.setdefault(val, []).append((ins.address, f"{ins.mnemonic} {ins.op_str}"))
            nxt = ins.address + ins.size
            if nxt <= addr:
                break
            addr = nxt
        if not got or addr <= start:
            addr += 1
    return xr


def get_xrefs(pe=None, rebuild=False):
    if not rebuild and os.path.exists(CACHE):
        return pickle.load(open(CACHE, "rb"))
    pe = pe or PE()
    xr = build_xrefs(pe)
    pickle.dump(xr, open(CACHE, "wb"))
    return xr


if __name__ == "__main__":
    pe = PE()
    for s in pe.secs:
        print(s)
    if len(sys.argv) > 1 and sys.argv[1] == "build":
        import time
        t = time.time()
        xr = get_xrefs(pe, rebuild=True)
        print("xrefs", len(xr), "entries in %.1fs" % (time.time() - t))
