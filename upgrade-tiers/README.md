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
runscript upgrade_tiers -      dry run at the tier your level allows
runscript upgrade_tiers -9     dry run at a forced tier
```

A dry run sweeps and reports exactly as a real run does, but never applies a
material, so it can be repeated freely and is the way to preview a target tier
before committing. The leading minus selects it; `-` on its own is enough.

The report is one floaty listing what changed, with identical items collapsed
into a count:

```
4x Magic Staff 1->3
2x Magic Staff 2->3
1x Enchanter's Staff 3->7
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

`MaterialProgress` names a row in the material table (199), and that row's
`Material1` to `Material15` columns list the materials the item may become. The
row is the authority on **which** materials are permitted: a Darkspawn Dagger's
family stops at Steel, so nothing will ever make it Dragonbone.

The row says nothing about how good each material is, and the material types table
(89) carries no rank at all for wood or leather - reading tiers from it silently
skipped every bow, crossbow and piece of light armour. So the ranks are stated here,
as one ladder per family, matching the tiers the game shows: Dragonbone, Dragonthorn
and Drakeskin are all tier 7.

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

The row is then scanned and the best material at or below the target tier is
applied, where the target is the tier a store would stock for the buyer's level.

### A row is a family, not an item

Of the 1016 item templates only 54 distinct rows are in use:

| templates sharing one row | rows |
|---|---|
| 258 | 1 |
| 200 | 1 |
| 134 | 1 |
| 54 | 1 |
| 2-27 | 14 |
| 1 | 12 |

So a row states what a *family* scales through, not that every member exists at
each step. One row covers 258 templates. That is why the Darkspawn Dagger stopping
at Steel is correct - its whole family ends there - and also why a generous family
row must never be applied to a named piece.

## What makes it safe

- **Named items are skipped.** A hand-placed item - a chest reward, a quest gift -
  sits at the material it was authored with and no store ever rerolls it. Its row
  only describes the family it belongs to, so following the row invents tiers the
  piece was never made in. The Helm of Honnleath belongs to a family whose row
  reaches Red Steel while the helm itself was authored in Grey Iron; `GetItemUnique`
  is the test.
- **Items the game cannot name are skipped.** A creature's built-in attack carries a
  real progression row and can sit in the party inventory - the Mabari's bite is
  `gen_im_cweapon_dog_party`, cost 0 - and raising it makes a companion hit harder
  than the designers authored, with nothing in the UI to show it. Its name reference
  resolves to no string at all, so `GetName` returns empty for it; that is also why it
  once printed as a bare `2->7`.
- **Only the material is written.** `ITEM_RUNE_ENABLED`, the slot capability
  variable that other upgrade mods overwrite, is never touched. Applying a material
  drops the runes installed in the item; that is accepted, because a rune is an item
  the player can install again while a tier they have outgrown cannot be recovered.
  Runed items are not special-cased or counted: the material is the only thing written.
- **Uninstalled tiers cannot corrupt an item.** After setting the new material the
  script reads it back; if the engine refused the value the original is restored.
  That is how an install without the Awakening tiers behaves.
- **Materials outside every ladder are left alone.** Star metal and the clothing,
  robe and single-piece materials are not in any ladder, so they are skipped rather
  than pushed into a nonsense tier.
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