# Interactive Respec — Dragon Age: Origins

Open the **level-up screen for a character you have already built**, pre-filled
with their existing skills, talents, spells and attributes, and edit it in
place. Lower a pick, re-spend the point, walk back and forth between the panes
as much as you like.

The vanilla level-up screen only lets you undo what you spent *during that
screen*, so a finished character cannot be adjusted. This mod lifts that
restriction.

## Requirements

- Dragon Age: Origins (Ultimate Edition tested)
- The developer console enabled in game
- PowerShell 5.1+ to run the build/packaging scripts

## Install

Compile the script first (see [Building](#building)); the usual one-liner is
then:

```powershell
powershell -ExecutionPolicy Bypass -File build\dazip.ps1 -Install
```

That builds `build\respec_proto.dazip` and installs it: it extracts both addins
into `Documents\BioWare\Dragon Age\AddIns\` and registers them in `AddIns.xml`,
backing that file up first. To remove the mod again:

```powershell
powershell -ExecutionPolicy Bypass -File build\dazip.ps1 -Uninstall
```

The `.dazip` is a normal DAO package, so DAO-Modmanager / DAModder work too.

## Usage

Open the console and run:

```
runscript respec1
```

That opens the level-up screen for the hero, with the build as it is. Everything
after that is the GUI: the screen is where you undo picks, and the patches make
picks you made outside it editable.

The script does one thing — open the screen. It changes nothing on its own, so
there is nothing to get wrong if you run it and then close the screen.

> **Why the level-up indicator is not the trigger.** The obvious button is the
> indicator on the hero's portrait, and it cannot work with every point spent:
> clicking it sends `GUI.GoToLevelUp`, which the engine refuses unless the
> character has unspent points. Everything a movie can reach was tried — the
> flag cannot be set from the UI, `GUI.RunConsoleCommand` is ignored, and every
> message that might start a session was tested. The screen *can* be shown
> without one (`GUI.GoToGuiWithFollowerMessage "LevelUp" <id>` does open it),
> but then the engine has no `CharGenCreature`: the screen reads `NaN` for every
> value and has nothing to apply edits to.
>
> **Why a session is unavoidable.** The screen is a view onto engine state, not
> a store of its own: it reads `CharGenCreature.*` in 46 places and applies every
> change through the chargen subsystem (`GUILevelUp.CharGenAssignAbility`,
> `GUILevelUp.CharGenAssignAttribute`, committed by `GUILevelUp.CharGenEnd`).
> Only the engine's own level-up flow and `StartCharGen(creature, 1)` create that
> session, and both are script-only. So the script is the entry point, and the
> indicator still behaves exactly as vanilla.

> **No unspent points are required to see the screen.** The movie normally skips
> its panes when there is nothing to spend (`bWeHadPointsInitially =
> nPointsToSpend > 0`), which is why a fully-spent character could not be
> edited. The patches disable that in level-up mode.

**Cancel is safe.** Closing the screen aborts and restores attributes, skills,
talents/spells and specializations to the state they were in when it opened.

## How it works

Two halves, because a DAO addin's `ExtendedModuleUID` decides where its
resources are mounted and one `AddInItem` can only carry one value:

1. **Script** (`src/respec1.nss` → `respec1.ncs`), extending `Single Player`.
   Calls the engine's `StartCharGen(creature, 1)` — `CHARGEN_MODE_LEVELUP` — to
   open the level-up process directly. The same screen is shared by character
   creation and levelling.
2. **UI**, extending `core`, which is where the UI movie resources live. One
   movie is patched: `levelup` (the screen itself).

The movie ships with the game as a headerless SWF (`levelup.gfx`) inside the
GUI packages. Its ActionScript tracks edits in
session-only arrays (`aStoredPoints`, `m_aAttributes`) that are cleared on every
pane initialise, which is what makes existing picks uneditable. The patches in
`ui/movies/levelup/patches/` change that for level-up mode only:

- owned abilities become clickable, and unlearnable
- an existing specialization can be removed, refunding the specialization point
- an ability cannot be unlearned while something owned still depends on it
- an attribute cannot be lowered below a requirement an owned ability has
- a specialization cannot be removed while a talent or spell it unlocks is
  still picked
- panes no longer revert when you navigate backwards
- existing attributes are seeded so they can be taken back down, minus the
  race bonus the character never spent
- Reset reverts every pane, so it cannot leave the character inconsistent
- `LevelUp.StartScene` no longer auto-levels when the engine never filled
  `CharGenCreature` in. The test was `GetValue("CharGenCreature.Stats.AutoLevelUp") != 0`,
  and in ActionScript a missing token fails a `!= 0` test, so showing the screen
  without a session made the movie fire `GUILevelUp.AutoLevelUp` and hide the
  screen again on the frame it opened. It now auto-levels only on a real value.

Everything is scoped to `bLevelUp`, so character creation behaves exactly as
vanilla.

### Attribute ids, column names, and Cunning

Three different naming schemes meet here, and getting them crossed silently
produces a bonus of 0 rather than an error.

The screen walks six attribute rows by numeric id and takes the display name
from `properties.2da`: **1 Str, 2 Dex, 3 Will, 4 Mag, 5 Cun, 6 Con**.
`attributes.2da` numbers the same six differently (**3 Con, 4 Int, 5 Will,
6 Mag**), and the adjust columns in `RACE_base.2da` and `CLA_base.2da` follow
*that* order.

Two further traps:

- The columns are **abbreviated**: `StrAdjust`, `DexAdjust`, `WillAdjust`,
  `MagAdjust`, `ConAdjust`. Appending `Adjust` to a display name builds
  `"StrengthAdjust"`, which does not exist, and every lookup returns 0 — the
  floor then collapses to a flat 10 and looks like it "works".
- **Cunning is called Intelligence in the 2DAs.** It has no `CunAdjust` column
  anywhere; it is `IntAdjust`. Without that mapping Cunning floors at 10 while
  character creation shows 11.

So the id-to-column map is explicit in `AdjustColumnFor`, and the table columns
are read by name via `Get2DAValueByColumnName`. That call is supported — vanilla
uses it in `RaceGenderScene.as`.

### The attribute floor is a choice, and both are built

Nothing in the game records "the points this character actually spent", so the
mod has to decide the lowest value it will refund to:

- **starting-value floor** — `10 + race adjust + class adjust` per attribute.
  This is what the character was given, so the only thing that can come back is
  what the player spent. A level-1 character who never allocated anything ends
  with nothing to reclaim, which is correct but means the pane is inert for
  them.
- **flat 10 floor** — every attribute floors at 10, so a rebuild starts from a
  blank slate. This is more useful for rebuilding, but it hands back the race
  and class points too, which the character never spent.

Since this is a preference rather than a defect, both are built and the
installer picks:

```
powershell -File build\deploy.ps1 -Ftg -AttributeFloor Starting   # default
powershell -File build\deploy.ps1 -Ftg -AttributeFloor Ten
```

The two are the same patch set with `UseStartingValueFloor` flipped at build
time, so they cannot drift apart. `ui\build-all.ps1` builds all four
combinations of movie base and floor:

```
ui\levelup.swf          vanilla base, starting-value floor
ui\levelup_ten.swf      vanilla base, flat 10 floor
ui\levelup_ftg.swf      FtG base,     starting-value floor
ui\levelup_ftg_ten.swf  FtG base,     flat 10 floor
```

Note that the point counter above the list is the engine's own
(`Attributes.34`, the unspent attribute points), not something this mod seeds.

## Using this with FtG UI Mod

FtG UI Mod ships its **own** `levelup.swf`, in the same `core` mount point as
this mod's. Two addins cannot both own that resource, so whichever loads last
wins — and a stock build of this mod would either throw away that mod's
level-up changes (if ours wins) or lose this mod's patches (if theirs wins).

So the mod builds **on top of theirs** when it is enabled. The same eight
patches, ported to their ActionScript, are applied to their movie:

```
ui\movies\levelup\      patches against the vanilla movie
ui\movies\levelup_ftg\  the same intent, ported to FtG UI Mod's movie
```

`deploy.ps1` checks `AddIns.xml` for `FTG_UIMOD ... Enabled="1"` and picks the
right base automatically; `-Ftg` forces the FtG base, and `dazip.ps1 -Ftg`
packages it.

**The erfs alone are not enough.** Two addins can ship the same `core` resource
and `AddIns.xml` does not decide who wins: with FtG UI Mod enabled its
`levelup.swf` is the one the game used, even though this mod's `AddInItem` has a
higher `Priority` (160 vs 100) and sits last in the list. So the install also
writes the movie to the core override folder:

```
Documents\BioWare\Dragon Age\packages\core\override\levelup.swf
```

Resources there are merged after the addins, so that copy cannot be outranked.
It is always the same build as the erf, and an unrelated file already sitting at
that path is backed up to `levelup.swf.bak` rather than silently replaced.

**Re-run the install whenever you enable or disable FtG UI Mod.** The base is
chosen at install time, so the override file holds whichever movie was correct
when the install last ran. Toggle the mod, re-run, restart the game — one
install covers both cases, no second package to keep track of.

`build\ui-base.ps1` makes that choice, and both `deploy.ps1` and
`dazip.ps1 -Install` use it, so they cannot disagree about which movie to ship.

**A distributable package is always the vanilla-based build.** Packaging
(`dazip.ps1` without `-Install`) never auto-detects: the movie is the other mod's
work and is not ours to redistribute, so a `.dazip` intended for other people is
the vanilla-based build, which works for everyone. Anyone running FtG UI Mod can
get its level-up screen *and* these patches by running `deploy.ps1`, which
rebuilds that variant locally from their own copy — or by copying
`ui\levelup_ftg.swf` to `packages\core\override\levelup.swf` after installing.
A `.dazip` cannot carry that file itself, because it lives outside the addin
folder.

Our UI addin is registered at `Priority="160"`, above FtG UI Mod's `100`; that
is kept for tidiness, but the override file is what actually decides.

Three of the eight files FtG's movie is patched in are byte-identical to
vanilla's, so those patches apply untouched; `LevelUp.as` is restructured
(their book-menu scaling), so that one is ported by hand.

To rebuild the FtG variant, its movie has to be extracted from
`AddIns\FTG_UIMOD\core\data\FTG_UIMOD_modcore.erf` into
`ui\movies\levelup_ftg\vanilla.swf` first (it is a compressed `CWS` SWF, unlike
the headerless vanilla ones), then:

```powershell
powershell -ExecutionPolicy Bypass -File ui\make-patches.ps1 -Movie levelup_ftg -Refresh
powershell -ExecutionPolicy Bypass -File ui\build-movie.ps1 -Movie levelup_ftg
```

Nothing of that mod is redistributed: its movie is a local build input and is
`.gitignore`d, and only our own patches against it are in this repo.

## Building

The script must be compiled with the **Dragon Age Toolset** — there is no
standalone `.nss`/`.ncs` compiler. Open `src/respec1.nss` in the Toolset,
compile it, then:

```powershell
# one command: finds the newest Toolset export, rebuilds both erfs,
# re-registers the addins
powershell -ExecutionPolicy Bypass -File build\deploy.ps1
```

`deploy.ps1` is the fast iteration path (it writes straight into the installed
addin folders). `dazip.ps1` is the distributable path.

To rebuild the patched movies from source:

```powershell
# regenerate patches from the edited scripts (_work) vs the pinned base
powershell -ExecutionPolicy Bypass -File ui\make-patches.ps1 -Movie levelup

# apply the patches and produce ui\levelup.swf
powershell -ExecutionPolicy Bypass -File ui\build-movie.ps1 -Movie levelup
```

These need
[FFDec (JPEXS Free Flash Decompiler)](https://github.com/jindrapetrik/jpexs-decompiler)
and Java, plus the extracted vanilla movie. See [Notes](#notes).

## Repository layout

```
src/respec1.nss                     the console script (opens the screen)
dazip/Manifest.xml                  addin manifest: both AddInItems + the credit
ui/movies/levelup/patches/*.patch   level-up screen ActionScript changes
ui/movies/levelup_ftg/patches/*.patch  the same changes, ported to FtG UI Mod's movie
ui/build-movie.ps1 -Movie <name>     apply patches -> ui\<name>.swf
ui/make-patches.ps1 -Movie <name>    regenerate patches from the edited scripts
build/dazip.ps1                     build, install and uninstall the .dazip
build/deploy.ps1                    one-command deploy into the installed addin
ref/                                engine API and ability-id references
```

## Notes

**Machine-specific paths.** `deploy.ps1` and `dazip.ps1` locate the Toolset's
compile output and the Documents folder automatically. Both accept overrides
(`-Ncs`).

**Not in this repo, by design.** The vanilla movie, the decompiled BioWare
ActionScript and the engine `.ldf` files are build *inputs* and are `.gitignore`d
— they are BioWare's and are not redistributed here. Only our own patches
against them are.

**Take the movies from the newest patch, not from `guiexport.erf`.** The game
ships several revisions of the UI and patches override the base package:

```
packages\core\data\guiexport.erf      levelup.gfx   <- base game, PRE-patch
packages\core\patch\patch002.erf      levelup.gfx
packages\core\patch\patch003.erf      levelup.gfx   <- the one the game uses
```

The same applies to any other UI resource you patch, such as `quickbar.gfx` or
`navbar.gfx`. Patching
the `guiexport` copies produces movies that render without the post-patch art
fixes (button skins, specialization icons, portrait framing), so always base
the build on the highest-numbered patch that ships the resource.

These are headerless SWFs: prepending an 8-byte `FWS` header (`"FWS"` + version
`9` + total length) makes them parseable by FFDec.

**No third-party UI mod is required or bundled.**

## Credits and licence

- Respecialisation mechanism (remove ability → refund the point pool) is
  credited to **Peter 'weriK' Kovacs**, *Character Respecialization*
  (Nexus mod 14), reused under that mod's permission grant: modification and
  redistribution of improvements allowed **with credit**. No selling and no
  Donation Points.
- The ability id tables are **not** copied from that mod. They are derived from
  BioWare's own 2DA sources shipped with the Toolset
  (`tools\Source\2DA\rules\ABI_base.xls`). Deriving them corrected a latent bug
  in the original tables: `MASTER_COMBAT_TRAINING` is id `100103`, not `100104`.
- Dragon Age: Origins and its assets are © BioWare / Electronic Arts. This is an
  unofficial fan modification and is not affiliated with or endorsed by them.
