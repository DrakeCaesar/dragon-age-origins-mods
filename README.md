# Interactive Respec â€” Dragon Age: Origins

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

## Packaging both variants

The attribute floor is a behavioural choice, so two distributables exist.
`deploy.ps1` builds both and packages them automatically; each lands in its own
self-contained folder under `build\dist\`, with a `README.txt`:

```
build\dist\vanilla-starting\respec_proto.dazip
build\dist\vanilla-ten\respec_proto_ten.dazip
```

`_ten` marks the flat-10 floor; no suffix means the starting-value floor.
Folders can be zipped or handed out individually; nothing else is needed.

Only one of the two is *installed* â€” the floor you asked for:

```powershell
powershell -File build\deploy.ps1 -AttributeFloor Ten
```

Skip the packaging or the movie rebuild when iterating:

```powershell
powershell -File build\deploy.ps1 -NoBuild -NoPackage
```

`-AttributeFloor` selects the actual movie file that gets packaged and
installed, not just a name â€” `ui\levelup.swf` and `ui\levelup_ten.swf` are
separate builds of the same patches.

## Usage

Open the console and run:

```
runscript respec1
```

That opens the level-up screen for the hero, with the build as it is. Everything
after that is the GUI: the screen is where you undo picks, and the patches make
picks you made outside it editable.

The script does one thing â€” open the screen. It changes nothing on its own, so
there is nothing to get wrong if you run it and then close the screen.

> **The portrait indicator is the other way in.** Clicking it sends
> `GUI.GoToLevelUp`, and that message's handler does start the session â€” it was
> only ever refused because it tests the character's "can level up" predicate
> (`daorigins.exe+2ACBC0`) first, which is false once every point is spent.
> DAFix (`[Level Up] Unlock`) skips that single test at the call site, so the
> handler creates the session and pushes the screen for a fully-spent character.
> The predicate itself is left intact, because it also produces the
> `PortraitLevelUp` token: the indicator stays visible at all times and only
> animates while there is really something to spend. Without DAFix, the script
> below is still the way in.
>
> **Why a session is unavoidable.** The screen is a view onto engine state, not
> a store of its own: it reads `CharGenCreature.*` in 46 places and applies every
> change through the chargen subsystem (`GUILevelUp.CharGenAssignAbility`,
> `GUILevelUp.CharGenAssignAttribute`, committed by `GUILevelUp.CharGenEnd`).
> Only the engine's own level-up flow and `StartCharGen(creature, 1)` create that
> session. Showing the screen by other means (`GUI.GoToGuiWithFollowerMessage
> "LevelUp" <id>`) opens it with no creature: it reads `NaN` for every value and
> has nothing to apply edits to.

> **No unspent points are required to see the screen.** The movie normally skips
> its panes when there is nothing to spend (`bWeHadPointsInitially =
> nPointsToSpend > 0`), which is why a fully-spent character could not be
> edited. The patches disable that in level-up mode.
>
> A pane is still skipped when the creature has nothing it *could* have on it at
> all, which is not the same thing as having no points: a Mabari has attributes
> and talents but no skill list, so the Skills pane is passed over instead of
> shown empty. The test is the pane's own ability chains
> (`CharGenCreature.Stats.SkillChains`, and for the spells/talents pane
> `SpellChains` plus `TalentChains`).

**Cancel is safe.** Closing the screen aborts and restores attributes, skills,
talents/spells and specializations to the state they were in when it opened.

## How it works

Two halves, because a DAO addin's `ExtendedModuleUID` decides where its
resources are mounted and one `AddInItem` can only carry one value:

1. **Script** (`src/respec1.nss` â†’ `respec1.ncs`), extending `Single Player`.
   Calls the engine's `StartCharGen(creature, 1)` â€” `CHARGEN_MODE_LEVELUP` â€” to
   open the level-up process directly. The same screen is shared by character
   creation and levelling.
2. **UI**, extending `core`, which is where the UI movie resources live. Two
   movies are patched: `levelup` (the screen itself) and `inventory` (the
   paperdoll's stat column).

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

### The inventory paperdoll

The inventory screen's left column lists only condition and combat stats ?
health, energy and fatigue above the paperdoll, armour, defence, attack and
damage below it. The patched `inventory` movie adds the six attributes and the
resistances, showing the same numbers as the character record:

```
Str   19  18   +1        Ment  17   0  +10
Dext  24  19   +5        Phys  26   0  +10
Will  11  10   +1        Fire  25   0  +25
Mag   12  11   +1        Cold   0   0   +0
Cun   21  14   +7        Elec   0   0   +0
Cons  19  13   +6        Nat    0   0   +0
                         Spir  10   0  +10
```

Each row is **total, base, modifier**; the modifier is signed and coloured the
way the character sheet colours it. Every part of a row is its own text field, so
the three number columns keep a fixed right edge even though the values differ in
width.

**The block sits outside the panel, in the screen margin beside it.** The movie's
stage is 1024x768 and the panel's own art runs all the way to that edge (the item
sort picker reaches x 1034), so there is no room beside the panel *inside* the
stage. The game scales the stage and centres it ? 1.5x at 2560x1440 with DAFix's
`HUD Scale = 0.6666667`, which is 1536x1152 on screen ? so the stage edge is not
the screen edge and the space beyond it is visible. The block is created on
`_root` at stage coordinates (984, 271), i.e. just past the panel's right edge and
centred vertically on the stage.

Because it lives on `_root` instead of in the scene's own timeline, `FinishScene`
removes it ? otherwise it would hang over the game once the panel closes.

Worth knowing:

- Values come from `GUI.SelectedChar.Attributes.<property>.Total/.Base/.Modifier`,
  where `<property>` is the `properties.2da` row id ? 1..6 for the six
  attributes, because row 0 of that table is unused.
- Each cell observes **its own leaf token** and takes the value handed to the
  callback. Observing the parent `GUI.SelectedChar` token does not fire when only
  its children change, which shows up as rows that only refresh when the screen is
  reopened.
- The resistances are not a fixed list: the rows are taken from
  `properties.2da` where `HASH_UIMAPPING` is 1 (Mental, Physical) or 3 (the five
  elemental ones), which is how `CharacterRecord.UpdateResistances` finds them.
- Labels are three letters, keeping a fourth when it is a consonant, so `Dext`,
  `Will` and `Cons` stay readable. `LABEL_OVERRIDES` spells out names that read
  better that way: `Fire` and `Cun`.
- Resistances carry no `%`.

**The layout numbers are constants, not measurements.** `getBounds` does not work
inside this movie ? a runtime measurement silently does nothing, which looks
exactly like "the change had no effect". `ATTRIBUTE_BLOCK_X`,
`ATTRIBUTE_BLOCK_Y`, `ATTRIBUTE_ROW_TOP` and the column right-edges in
`Inventory.as` were all set against the real screen, so change them only together
with a look at the screen.

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
  `"StrengthAdjust"`, which does not exist, and every lookup returns 0 â€” the
  floor then collapses to a flat 10 and looks like it "works".
- **Cunning is called Intelligence in the 2DAs.** It has no `CunAdjust` column
  anywhere; it is `IntAdjust`. Without that mapping Cunning floors at 10 while
  character creation shows 11.

So the id-to-column map is explicit in `AdjustColumnFor`, and the table columns
are read by name via `Get2DAValueByColumnName`. That call is supported â€” vanilla
uses it in `RaceGenderScene.as`.

### The attribute floor is a choice, and both are built

Nothing in the game records "the points this character actually spent", so the
mod has to decide the lowest value it will refund to:

- **starting-value floor** â€” `10 + race adjust + class adjust` per attribute.
  This is what the character was given, so the only thing that can come back is
  what the player spent. A level-1 character who never allocated anything ends
  with nothing to reclaim, which is correct but means the pane is inert for
  them.
- **flat 10 floor** â€” every attribute floors at 10, so a rebuild starts from a
  blank slate. This is more useful for rebuilding, but it hands back the race
  and class points too, which the character never spent.

Since this is a preference rather than a defect, both are built and the
installer picks:

```
powershell -File build\deploy.ps1 -AttributeFloor Starting   # default
powershell -File build\deploy.ps1 -AttributeFloor Ten
```

The two are the same patch set with `UseStartingValueFloor` flipped at build
time, so they cannot drift apart. `ui\build-all.ps1` builds both floors plus
the two movies that have no variants:

```
ui\levelup.swf          starting-value floor
ui\levelup_ten.swf      flat 10 floor
ui\portraits.swf        party-bar portraits (no variants)
ui\inventory.swf        paperdoll stat rows (no variants)
```

`ui\portraits.swf` is the second patched movie, shipped in both the addin's
`core` erf and `packages\core\override\portraits.swf`. It keeps the level-up
indicator on every party portrait visible at all times: frame 29 is where the
icon art is fully opaque, so the clip parks there and only plays its animation
while that creature has a point to spend.

Note that the point counter above the list is the engine's own
(`Attributes.34`, the unspent attribute points), not something this mod seeds.

## UI mods

FtG UI Mod is **not supported**. The level-up movie here is built from the
vanilla screen, and it is installed into `packages\core\override\levelup.swf`.

That placement is deliberate: an addin that ships its own `levelup.swf` in the
same `core` mount point cannot be outranked by `AddIns.xml` priority, but
resources under `packages\core\override` are merged after every addin. So with
`FTG_UIMOD` installed, this mod's screen is the one the game shows — FtG's
level-up changes are replaced, and any other part of FtG that lives in its
movie is gone with it. Disable `FTG_UIMOD` to avoid two mods fighting over the
same file.

The same override trick is used for `portraits.swf`. `inventory.swf` ships only
inside the addin's core ERF, because no UI mod ships that resource.
## Building

The script must be compiled with the **Dragon Age Toolset** â€” there is no
standalone `.nss`/`.ncs` compiler. Open `src/respec1.nss` in the Toolset,
compile it, then:

```powershell
# one command: finds the newest Toolset export, rebuilds both erfs,
# re-registers the addins
powershell -ExecutionPolicy Bypass -File build\deploy.ps1
```

`deploy.ps1` is the one entry point: it builds all four movie variants, packages
all four distributable `.dazip`s, then installs the variant matching your UI
base and `-AttributeFloor`. `dazip.ps1` remains for handling a single package
(`-Install` / `-Uninstall`).

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

**Only the scripts that differ from the pinned base are compiled into the movie.**
`build-movie.ps1` compares each exported script with its patched copy and imports
just the changed ones (usually one to eight files). FFDec recompiles everything it
is given, so importing the whole tree replaces BioWare's bytecode for code we
never meant to touch â€” and that is not a harmless no-op: doing it to the inventory
movie made the game crash with a stack overflow the moment an item was dropped on
an equipment slot, while the patch itself was fine all along. Leaving the rest of
the movie byte-identical to the shipped one removes that whole class of bug, and
makes builds much faster.

## Repository layout

```
src/respec1.nss                     the console script (opens the screen)
dazip/Manifest.xml                  addin manifest: both AddInItems + the credit
ui/movies/levelup/patches/*.patch   level-up screen ActionScript changes
ui/movies/portraits/patches/*.patch  party-bar portrait indicator
ui/movies/inventory/patches/*.patch  paperdoll attribute and resistance rows
ui/build-movie.ps1 -Movie <name>     apply patches -> ui\<name>.swf
ui/build-all.ps1                    build all four level-up movies plus portraits and inventory
ui/make-patches.ps1 -Movie <name>    regenerate patches from the edited scripts
build/deploy.ps1                    build all four, package all four, install one
build/dazip.ps1                     package (or install/uninstall) a single .dazip
ref/                                engine API and ability-id references
```

## Notes

**Machine-specific paths.** `deploy.ps1` and `dazip.ps1` locate the Toolset's
compile output and the Documents folder automatically. Both accept overrides
(`-Ncs`).

**Not in this repo, by design.** The vanilla movie, the decompiled BioWare
ActionScript and the engine `.ldf` files are build *inputs* and are `.gitignore`d
â€” they are BioWare's and are not redistributed here. Only our own patches
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

The `guiexport` copies are not merely older, they are a different revision that
looks pre-release: `portraits.gfx` there has no portrait background art at all
(which is why a build against it lost the character-sheet background) and its
`Attributes.8` token wiring predates the `AbilityUpkeepCost` token that
`patch003` uses. A build against the wrong copy therefore silently reverts
BioWare's own fixes.

These are headerless SWFs: prepending an 8-byte `FWS` header (`"FWS"` + version
`9` + total length) makes them parseable by FFDec.

**No third-party UI mod is required or bundled.**

## Credits and licence

- Respecialisation mechanism (remove ability â†’ refund the point pool) is
  credited to **Peter 'weriK' Kovacs**, *Character Respecialization*
  (Nexus mod 14), reused under that mod's permission grant: modification and
  redistribution of improvements allowed **with credit**. No selling and no
  Donation Points.
- The ability id tables are **not** copied from that mod. They are derived from
  BioWare's own 2DA sources shipped with the Toolset
  (`tools\Source\2DA\rules\ABI_base.xls`). Deriving them corrected a latent bug
  in the original tables: `MASTER_COMBAT_TRAINING` is id `100103`, not `100104`.
- Dragon Age: Origins and its assets are Â© BioWare / Electronic Arts. This is an
  unofficial fan modification and is not affiliated with or endorsed by them.
