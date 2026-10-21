"""Disassemble a VA range of daorigins.exe with capstone."""
import sys

sys.path.insert(0, __file__.rsplit("\\", 1)[0])
from da_analyze import PE
from capstone import Cs, CS_ARCH_X86, CS_MODE_32

lo = int(sys.argv[1], 16)
hi = int(sys.argv[2], 16)
count = int(sys.argv[3]) if len(sys.argv) > 3 else 400

pe = PE()
off = pe.va2off(lo)
code = pe.d[off: off + (hi - lo)]
md = Cs(CS_ARCH_X86, CS_MODE_32)
md.detail = False

n = 0
for ins in md.disasm(code, lo):
    print(f"{ins.address:08x}  {ins.bytes.hex():<20s} {ins.mnemonic:<8s} {ins.op_str}")
    n += 1
    if n >= count:
        break
