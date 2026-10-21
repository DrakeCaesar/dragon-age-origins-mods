"""Report call sites of given target VAs, with a few instructions of context."""
import sys
from capstone import Cs, CS_ARCH_X86, CS_MODE_32

sys.path.insert(0, __file__.rsplit("\\", 1)[0])
from da_analyze import PE

targets = {int(a, 16) for a in sys.argv[1:]}
pe = PE()
text = pe.sec(".text")
md = Cs(CS_ARCH_X86, CS_MODE_32)
md.skipdata = True

code = pe.d[text["ra"]: text["ra"] + text["rsz"]]
base = text["va"]

hits = {t: [] for t in targets}
for ins in md.disasm(code, base):
    if ins.mnemonic not in ("call", "jmp"):
        continue
    try:
        tgt = int(ins.op_str, 16)
    except ValueError:
        continue
    if tgt in targets:
        hits[tgt].append(ins.address)

for t in sorted(targets):
    print(f"=== {t:08x}: {len(hits[t])} call sites")
    for site in hits[t]:
        print(f"    {site:08x}")
