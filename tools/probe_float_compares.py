"""Find per-object float comparisons in a VA range.

A distance cull compares a value derived from the object against a threshold.
When the threshold is a field on the object rather than a global constant, a
constant sweep cannot see it. This reports every float compare that is preceded,
within a short window, by loads from object fields, naming those displacements.
"""
import sys
from capstone import Cs, CS_ARCH_X86, CS_MODE_32, CS_OP_MEM

sys.path.insert(0, __file__.rsplit("\\", 1)[0])
from da_analyze import PE

lo = int(sys.argv[1], 16)
hi = int(sys.argv[2], 16)

pe = PE()
md = Cs(CS_ARCH_X86, CS_MODE_32)
md.detail = True

code = pe.d[pe.va2off(lo): pe.va2off(lo) + (hi - lo)]
window = []
CMP = {"fcom", "fcomp", "fcompp", "fcomi", "fcomip", "fucom", "fucomp", "fucompp"}

for ins in md.disasm(code, lo):
    if ins.mnemonic in CMP:
        fields = []
        for prev in window[-8:]:
            for op in prev.operands:
                if op.type == CS_OP_MEM and op.mem.base != 0:
                    fields.append(f"{prev.mnemonic} [reg+{op.mem.disp & 0xFFFFFFFF:#x}]")
        after = []
        for nxt in md.disasm(pe.d[pe.va2off(ins.address): pe.va2off(ins.address) + 24], ins.address):
            if nxt.address == ins.address:
                continue
            after.append(f"{nxt.mnemonic} {nxt.op_str}")
            if len(after) >= 3:
                break
        if fields:
            print(f"{ins.address:08x} {ins.mnemonic:7s} after: {' ; '.join(after)}")
            print(f"           fed by: {' , '.join(fields)}")
    window.append(ins)
    if len(window) > 16:
        window.pop(0)
