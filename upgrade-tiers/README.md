# Upgrade Tiers

Raises the tier of every tiered weapon and armour you own to the tier your level
has earned, and keeps the result only when the tier rises.

Base game behaviour this mirrors: a store rerolls the tiered variants of what it
stocks each time the store is reopened, using the buyer's level, and the result
may go up, go down, or stay the same. This does the same for items already in the
party's possession.

## Usage

```
runscript upgrade_tiers        upgrade to the tier your level allows
runscript upgrade_tiers 9      force a specific target tier (1-9)
runscript upgrade_tiers -9     the same, with per item diagnostics
```

Covers the Warden's inventory. In Dragon Age that inventory is the shared party
stash, so it holds nearly everything the party owns; the companions' own
inventories and camp storage hold only spares and are not swept.

**Requires DAFix** with `[Script Engine] InstructionLimit` raised. Without it the
engine truncates the script silently - see below.

## Status

Script only, installed to `packages\core\override\UpgradeTiers\`. It becomes a
dazip later without any change to the script: the `.nss` compiles into a module
erf the same way the respec mod's does.

**The `.ncs` must be compiled with the Toolset.** The source is in place but the
script cannot run until `upgrade_tiers.ncs` sits next to it.

## The engine limit that shaped this mod

The script VM stops a script once it has executed 131072 instructions, and it does
so **silently**: the interpreter leaves its loop without raising an error, so
`runscript` still reports success and the script just stops partway through. The
check is a signed comparison against a per-run counter at `[vm+0x60]`:

```
0xa3029b  add  dword [esi+0x60], 1          ; 83 46 60 01
0xa3029f  cmp  dword [esi+0x60], 0x20000    ; 81 7E 60 00 00 02 00
0xa302a6  jge  0xa31b95                     ; 0F 8D, silent exit
```

A sweep over a full inventory needs far more than 131072, so every earlier version
appeared to "work for a while and then do nothing". DAFix rewrites the immediate to
2147483647 (the largest value a signed comparison can take), which removes the cap.
With that in place a single run covers the whole inventory.

## How it works

Four fields describe an item's metal or wood: `Material` (its current one) and
`MaterialProgress` (which ladder it follows). Every material id belongs to exactly
one ladder at exactly one position, so family and tier are both recoverable from
the material alone - no 2DA lookup is involved, so nothing can go stale when the
Awakening tables are merged in.

| ladder | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|
| melee weapon | 40 | 41 | 43 | 42 | 44 | 45 | 46 | 20050 | 20051 |
| bow | 33 | 34 | 35 | 36 | 37 | 38 | 39 | 20040 | 20041 |
| metal armour | 1 | 2 | 8 | 4 | 5 | 3 | 6 | 20010 | 20011 |
| leather | 60 | 28 | 29 | 30 | 31 | 17 | 32 | 20030 | 20031 |
| metal shield | 47 | 48 | 49 | 81 | 50 | 51 | 52 | 20060 | 20061 |
| wood shield | 79 | 9 | 11 | 15 | 13 | 7 | 10 | 20020 | 20021 |

Columns 8 and 9 are the Awakening materials, so they are reachable when Awakening
in the OC is installed.

### What makes it safe

- **Only the material is written.** `ITEM_RUNE_ENABLED`, the slot capability
  variable that other upgrade mods overwrite, is never touched. Applying a material
  drops the runes installed in the item; that is accepted, because a rune is an item
  the player can install again while a tier they have outgrown cannot be recovered.
  The count of upgraded items that held runes is reported so the cost is visible.
- **Uninstalled tiers cannot corrupt an item.** After setting the new material the
  script reads it back; if the engine refused the value the original is restored.
  That is how an install without the Awakening tiers behaves.
- **Unknown materials are left alone.** Star metal and the clothing, robe and
  unique-piece materials are not in any ladder, so they are skipped rather than
  pushed into a nonsense tier.
- **The change is bounded.** A run stops after `MAX_UPDATES` changes (10000, far
  above any real inventory) purely as a guard against a runaway loop.

### Verified against the game's own data

Checked against all 1016 item templates in `designeritems.erf`:

- no material appears in two ladders,
- 520 templates match a ladder and are upgradeable,
- every remaining material id is clothing (61-66, 76-78, 82-85) or a single unique
  piece (87, 88), all correctly skipped.

## Planned

Package as a dazip alongside a Toolset-compiled `upgrade_tiers.ncs`.