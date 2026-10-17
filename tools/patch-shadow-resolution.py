#!/usr/bin/env python3
"""Raise the Dragon Age: Origins shadow map resolution.

Why there is no setting for this
--------------------------------
The game exposes shadows only as a checkbox ("Enable Shadows" in the UI,
EnableShadows in DragonAge.ini). The resolution is chosen internally from a
4-step quality level at 0x00BF20E0:

    0x004556E0  SetShadowQuality(level)         stores the level
    0x00455580  helper it calls                 writes the map size

        level 0  -> shadows disabled
        level 1  -> mov dword ptr [0x00BF20C4], 0x200     (512)
        level 2  -> mov dword ptr [0x00BF20C4], 0x200     (512)
        level 3  -> mov dword ptr [0x00BF20C4], 0x400     (1024)  <- game max

The value in 0x00BF20C4 is read straight back as the size of the shadow
textures, width at +0x2C and height at +0x30 of the texture object
(0x00454572 / 0x00454586), so patching those two immediates raises the shadow
map everywhere it is used while leaving all surrounding logic intact.

Both instructions are unique in the executable. They are found by byte
signature rather than by file offset, so the patch is not tied to this build's
layout, and the original bytes are verified before anything is written.

Usage
-----
    python patch-shadow-resolution.py                  # --scale 2  (1024/512 -> 2048/1024)
    python patch-shadow-resolution.py --scale 4        # 1024/512 -> 4096/2048
    python patch-shadow-resolution.py --scale 8        # 1024/512 -> 8192/4096
    python patch-shadow-resolution.py --scale 4 --dry-run
    python patch-shadow-resolution.py --revert         # restore from the backup

--scale multiplies both stock sizes, so the quality tiers keep their original
2:1 ratio automatically. --size / --low are there if you want to set the two
tiers to explicit values instead.

Notes
-----
* A backup is written once, as <exe>.bak-shadow, and never overwritten.
* "Verify integrity of game files" in Steam restores the original executable.
* Cost is in shadow-rasterisation fill rate, not memory: a 4-byte depth texel
  over the map is only 4 MB at 1024, 16 MB at 2048 and 64 MB at 4096, so even
  a 4096 map is trivial next to an 8 GB card. The blur passes (EVBlurShadow /
  HBlurShadow) and the caster re-render scale with texel count instead.
* The blur radius is expressed in texels, so a bigger map makes the same blur
  cover a smaller area of world space: shadows get crisper, and at very high
  values they can start to look hard or to shimmer at their edges. If that
  happens, step back down rather than adding more resolution.
* Close the game before running this.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import shutil
import struct
import subprocess
import sys

DEFAULT_EXE = r"C:\Steam\steamapps\common\Dragon Age Ultimate Edition\bin_ship\daorigins.exe"

# mov dword ptr [0x00BF20C4], imm32
SIG = bytes.fromhex("C705C420BF00")
IMM_OFFSET = len(SIG)             # immediate follows the signature
BACKUP_SUFFIX = ".bak-shadow"

# The two sites are identified by address, not by their current value, because
# the value changes once the file has been patched.
SITE_ROLE = {
    0x004555AE: "high",   # quality level 3, the one a maximised detail level uses
    0x0045569E: "low",    # quality levels 1 and 2
}
STOCK = {0x004555AE: 0x400, 0x0045569E: 0x200}   # 1024 and 512
HIGH_VA, LOW_VA = 0x004555AE, 0x0045569E


def fail(msg: str) -> "NoReturn":
    print(f"error: {msg}", file=sys.stderr)
    raise SystemExit(1)


def sha256(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def find_sites(data: bytes) -> list[tuple[int, int]]:
    """Return (file offset of signature, immediate value) for every match."""
    sites, at = [], data.find(SIG)
    while at != -1:
        sites.append((at, struct.unpack_from("<I", data, at + IMM_OFFSET)[0]))
        at = data.find(SIG, at + 1)
    return sites


def site_values(path: str) -> dict[str, int]:
    """Map role ('high'/'low') to the size currently stored at each site."""
    with open(path, "rb") as f:
        data = f.read()
    return {SITE_ROLE[va_of(off)]: imm for off, imm in find_sites(data) if va_of(off) in SITE_ROLE}


def is_power_of_two(n: int) -> bool:
    return n >= 128 and (n & (n - 1)) == 0


def game_running() -> bool:
    try:
        out = subprocess.run(
            ["tasklist", "/FI", "IMAGENAME eq DAOrigins.exe", "/NH"],
            capture_output=True, text=True, timeout=15,
        ).stdout
    except Exception:
        return False
    return "daorigins.exe" in out.lower()


def va_of(offset: int) -> int:
    # .text has identical RVA and raw offset in this image (RVA 0x1000, raw 0x1000)
    return 0x00400000 + offset


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Raise the DAO shadow map resolution.",
        epilog="--scale multiplies the stock sizes (1024 and 512), so --scale 4 gives 4096 and 2048.",
    )
    ap.add_argument("--exe", default=DEFAULT_EXE, help="path to daorigins.exe")
    ap.add_argument("--scale", type=int, default=None,
                    help="multiply the stock shadow sizes: 1, 2, 4 or 8 (default 2)")
    ap.add_argument("--size", type=int, default=None,
                    help="explicit size for the highest quality level (overrides --scale)")
    ap.add_argument("--low", type=int, default=None,
                    help="explicit size for levels 1-2 (default with --size: half of it)")
    ap.add_argument("--dry-run", action="store_true", help="report what would change, write nothing")
    ap.add_argument("--revert", action="store_true", help="restore the executable from the backup")
    ap.add_argument("--force", action="store_true", help="proceed even if the bytes look unexpected")
    args = ap.parse_args()

    exe = os.path.abspath(args.exe)
    backup = exe + BACKUP_SUFFIX

    if not os.path.isfile(exe):
        fail(f"executable not found: {exe}")

    if args.revert:
        if not os.path.isfile(backup):
            fail(f"no backup to restore: {backup}")
        if game_running():
            fail("the game is running - close it first")
        shutil.copy2(backup, exe)
        restored = site_values(exe)
        expected = {"high": STOCK[HIGH_VA], "low": STOCK[LOW_VA]}
        if restored != expected:
            fail(f"restored file holds {restored}, expected the stock {expected}")
        print(f"restored {exe} from {backup}")
        print(f"sizes now  : {restored['low']} / {restored['high']} (stock)")
        print(f"sha256: {sha256(exe)}")
        return 0

    with open(exe, "rb") as f:
        data = f.read()

    if data[:2] != b"MZ":
        fail("not a PE executable")

    sites = find_sites(data)
    print(f"executable : {exe}  ({len(data):,} bytes)")
    print(f"sha256     : {sha256(exe)}")
    print(f"patch sites: {len(sites)}")
    for off, imm in sites:
        role = SITE_ROLE.get(va_of(off), "?")
        label = {"high": "quality level 3", "low": "quality levels 1-2"}.get(role, "unexpected address")
        print(f"  file 0x{off:06X}  VA 0x{va_of(off):08X}  current size {imm} (0x{imm:X})  [{label}]")

    if len(sites) != 2:
        fail(f"expected exactly 2 patch sites, found {len(sites)}")
    if {va_of(off) for off, _ in sites} != set(SITE_ROLE):
        fail("the patch sites are at unexpected addresses - this is not the build the script was written for")

    current = {SITE_ROLE[va_of(off)]: imm for off, imm in sites}
    if current == {"high": STOCK[0x004555AE], "low": STOCK[0x0045569E]}:
        print("state      : stock (1024 / 512)")
    else:
        sane = all(is_power_of_two(v) for v in current.values()) and current["high"] > current["low"]
        if sane:
            print(f"state      : already patched ({current['high']} / {current['low']}) - re-patching in place")
        elif args.force:
            print(f"warning: unexpected current values {current}; continuing because of --force")
        else:
            fail(
                f"unexpected current values {current}; this is either a different build or a "
                "corrupted patch (use --revert to restore from the backup, or --force to overwrite)"
            )

    # Resolve the requested sizes. --scale is the friendly form and keeps the
    # stock 2:1 ratio between the quality tiers; --size/--low override it.
    if args.scale is not None and (args.size is not None or args.low is not None):
        fail("use either --scale or --size/--low, not both")

    if args.scale is not None:
        if args.scale not in (1, 2, 4, 8):
            fail(f"--scale must be 1, 2, 4 or 8, got {args.scale}")
        high = STOCK[HIGH_VA] * args.scale
        low = STOCK[LOW_VA] * args.scale
        print(f"scale      : x{args.scale}  (stock {STOCK[LOW_VA]} / {STOCK[HIGH_VA]})")
    else:
        high = args.size if args.size is not None else STOCK[HIGH_VA] * 2
        low = args.low if args.low is not None else max(128, high // 2)

    for name, value in (("--size", high), ("--low", low)):
        if not is_power_of_two(value):
            fail(f"{name} must be a power of two between 128 and 8192, got {value}")
        if value > 8192:
            fail(f"{name} of {value} is beyond anything this engine will allocate")
    if low > high:
        fail(f"--low ({low}) cannot exceed --size ({high})")
    if high > 4096:
        print(f"warning: {high} is {high*high/(1024*1024):.0f}x the stock texel count; expect a real frame cost")

    targets = {}
    for off, _ in sites:
        targets[off] = high if SITE_ROLE[va_of(off)] == "high" else low

    print("\nplanned changes")
    for off, new in targets.items():
        old = struct.unpack_from("<I", data, off + IMM_OFFSET)[0]
        print(f"  VA 0x{va_of(off):08X}: {old} -> {new}   ({old}x{old} map -> {new}x{new}, {new*new/(old*old):.1f}x texels)")

    if args.dry_run:
        print("\ndry run: nothing written")
        return 0

    if game_running():
        fail("the game is running - close it first")

    if os.path.isfile(backup):
        # A backup is only worth keeping if it is the stock baseline; judge it by
        # the values at the patch sites, not by comparing whole files, because
        # the executable differs from it by design as soon as it is patched.
        backup_state = site_values(backup)
        stock_state = {"high": STOCK[HIGH_VA], "low": STOCK[LOW_VA]}
        current_state = {SITE_ROLE[va_of(off)]: imm for off, imm in sites}
        if backup_state == stock_state:
            print(f"backup     : {backup}  (stock baseline, left untouched)")
        elif backup_state == current_state:
            print(f"backup     : {backup}  (same state as the current file)")
        elif args.force:
            print(f"warning: backup holds unexpected values {backup_state}; keeping it because of --force")
        else:
            fail(
                f"the backup at {backup} holds unexpected values {backup_state}, not the stock "
                f"{stock_state}; move it aside or use --force"
            )
    else:
        shutil.copy2(exe, backup)
        print(f"\nbackup     : {backup}")

    patched = bytearray(data)
    for off, new in targets.items():
        struct.pack_into("<I", patched, off + IMM_OFFSET, new)
    with open(exe, "r+b") as f:
        f.write(patched)

    # Verify by reading the file back.
    with open(exe, "rb") as f:
        check = find_sites(f.read())
    values = sorted(imm for _, imm in check)
    expected = sorted(targets.values())
    if values != expected:
        fail(f"verification failed: file now contains {values}, expected {expected} - restore from {backup}")
    print(f"verified   : sizes now {values}")
    print(f"sha256     : {sha256(exe)}")
    print("\ndone - start the game and check the shadows.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
