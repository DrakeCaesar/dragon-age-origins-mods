"""Sweep the image for reads and writes of scene-node distance fields.

The node visibility test culls on a threshold read from [node+0x2ac], so if
something recomputes that field from a player or camera distance every frame it
is the per-object draw distance, and patching the test can never help because
the value is refreshed afterwards. This reports every static reference to the
field, split into loads and stores.
"""
import sys
from capstone import Cs, CS_ARCH_X86, CS_MODE_32, CS_OP_MEM, CS_OP_IMM

sys.path.insert(0, __file__.rsplit("\\", 1)[0])
from da_analyze import PE

FIELDS = [0x2a8, 0x2ac, 0x2b0, 0x290, 0x294, 0x298, 0x2a0, 0x2a4]
if len(sys.argv) > 1:
    FIELDS = [int(a, 16) for a in sys.argv[1:]]

pe = PE()
text = pe.sec(".text")
md = Cs(CS_ARCH_X86, CS_MODE_32)
md.detail = True

start = text["va"]
end = text["va"] + text["rsz"]
blob = pe.d[text["ra"]:text["ra"] + text["rsz"]]


def store_kind(ins):
    """Return 'store' when the memory operand is the destination."""
    if not ins.operands:
        return None
    dst = ins.operands[0]
    return "store" if dst.type == CS_OP_MEM else "load"


hits = []
addr = start
while addr < end:
    code = blob[addr - start: addr - start + 15]
    if not code:
        break
    got = None
    for ins in md.disasm(code, addr):
        got = ins
        break
    if got is None:
        addr += 1
        continue
    for op in got.operands:
        if op.type != CS_OP_MEM:
            continue
        if (op.mem.disp & 0xFFFFFFFF) in FIELDS:
            hits.append((got.address, store_kind(got), got.mnemonic, got.op_str,
                         op.mem.disp & 0xFFFFFFFF))
    addr += got.size

print(f"{len(hits)} references to the node distance fields\n")
for va, kind, mn, ops, f in hits:
    print(f"{va:08x} {f:#06x} {kind:5s} {mn} {ops}")
