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

Open the console and run **once**:

```
runscript respec1
```

That arms the level-up indicator on the hero's portrait. From then on, **click
the portrait icon** whenever you want to edit the character — no console
needed, and it works with every point already spent. (A real level-up clears
the flag, so re-run the command if the button stops responding.)

The other modes are optional extras:

| Command | Effect |
| --- | --- |
| `runscript respec1` | **Main:** arm the portrait's level-up button |
| `runscript respec1 open` | Open the level-up screen directly, bypassing the button |
| `runscript respec1 respec` | Full respec (skills, talents, spells, attributes), then open the screen |
| `runscript respec1 <skill>` | Lower `<skill>` by one rank and refund the point |
| `runscript respec1 <skill> <n>` | Lower `<skill>` by `n` ranks |

`<skill>` is matched loosely and case-insensitively: `coercion`/`persuade`,
`stealing`, `traps`, `survival`, `herbalism`, `poison`, `training`, `tactics`.

> **Why arming is needed.** Clicking the indicator sends `GUI.GoToLevelUp`,
> which the engine refuses unless the creature can level up — the character
> sheet gates its own Level Up button on the same predicate
> (`CanLevelUpFromCharacterSheet`). That check is server-side, so the UI patches
> cannot satisfy it; the script sets the flag instead.

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
2. **UI**, extending `core`, which is where the UI movie resources live. Two
   movies are patched: `levelup` (the screen itself) and `portraits` (the party
   portraits that carry the level-up indicator).

The movies ship with the game as headerless SWFs (`levelup.gfx`, and
`portraits.gfx`) inside the GUI packages. Their ActionScript tracks edits in
session-only arrays (`aStoredPoints`, `m_aAttributes`) that are cleared on every
pane initialise, which is what makes existing picks uneditable. The patches in
`ui/movies/*/patches/` change that for level-up mode only:

- owned abilities become clickable, and unlearnable
- an existing specialization can be removed, refunding the specialization point
- an ability cannot be unlearned while something owned still depends on it
- an attribute cannot be lowered below a requirement an owned ability has
- a specialization cannot be removed while a talent or spell it unlocks is
  still picked
- panes no longer revert when you navigate backwards
- the level-up indicator is always visible, without the flashing animation

Everything is scoped to `bLevelUp` (or to the portrait indicator itself), so
character creation behaves exactly as vanilla.

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
powershell -ExecutionPolicy Bypass -File ui\make-patches.ps1 -Movie portraits

# apply the patches and produce ui\levelup.swf / ui\portraits.swf
powershell -ExecutionPolicy Bypass -File ui\build-movie.ps1 -Movie levelup
powershell -ExecutionPolicy Bypass -File ui\build-movie.ps1 -Movie portraits
```

Both take `-Movie` (default `levelup`). These need
[FFDec (JPEXS Free Flash Decompiler)](https://github.com/jindrapetrik/jpexs-decompiler)
and Java, plus the extracted vanilla movies. See [Notes](#notes).

## Repository layout

```
src/respec1.nss                     the console script (all modes)
dazip/Manifest.xml                  addin manifest: both AddInItems + the credit
ui/movies/levelup/patches/*.patch   level-up screen ActionScript changes
ui/movies/portraits/patches/*.patch level-up indicator changes
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

The same applies to `portraits.gfx`, `quickbar.gfx` and `navbar.gfx`. Patching
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
