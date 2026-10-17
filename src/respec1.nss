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
 * The same screen can be opened by clicking the level-up indicator on the
 * hero's portrait, but only while the character has something left to spend.
 * The engine refuses that button's GUI.GoToLevelUp message otherwise, and
 * nothing in the UI can change that -- GUI.RunScript, GUI.RunClientScript and
 * GUI.RunConsoleCommand are all ignored, and the level-up flag cannot be set
 * from the UI. Use this command in that case.
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
