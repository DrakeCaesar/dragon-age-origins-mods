/*===========================================================================
 * respec1.nss  --  Open the level-up screen for the current hero
 *---------------------------------------------------------------------------
 * Dragon Age only lets you undo what you spent inside the level-up screen, so
 * a character with every point already spent cannot be adjusted. This opens
 * that screen directly, and the UI patches shipped with it make an existing
 * build editable once the screen is up.
 *
 * In game (console enabled):
 *     runscript respec1
 *
 * This is the only reliable entry point. The level-up indicator on the hero's
 * portrait is left untouched: the engine refuses its GUI.GoToLevelUp message
 * unless the character has something left to spend, and no message a movie can
 * send creates the level-up session the screen reads CharGenCreature from and
 * applies its edits through (GUILevelUp.CharGenAssignAbility/-Attribute/-End).
 * Showing the screen without that session fills it with NaN, so a UI-side
 * trigger cannot work.
 *
 * Build: compile with the Dragon Age Toolset -> respec1.ncs, then
 *        build\deploy.ps1   (or build\dazip.ps1 -Install for a distributable)
 *=========================================================================*/

void main()
{
    object oPC = GetHero();

    if (oPC == OBJECT_INVALID) { return; }

    // nMode 1 is CHARGEN_MODE_LEVELUP (sys_chargen_engine.nss). StartCharGen
    // is the engine's own entry point, so no unspent points are required.
    StartCharGen(oPC, 1);
}
