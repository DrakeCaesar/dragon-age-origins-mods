/*===========================================================================
 * respec1.nss  --  Interactive Respec  (skills / talents / spells / attributes)
 *---------------------------------------------------------------------------
 * Opens the level-up screen for the current hero so their build can be
 * reviewed and edited. Optionally also performs a respec, lowering
 * already-allocated points and refunding them.
 *
 * In game (console enabled):
 *     runscript respec1                  open the level-up screen with the
 *                                        character as they are (no changes)
 *     runscript respec1 respec           FULL respec: skills, talents, spells
 *                                        and attributes, then reopen level-up
 *     runscript respec1 <skill>          lower <skill> by 1 rank
 *     runscript respec1 <skill> <n>      lower <skill> by n ranks
 *
 * NOTE: the level-up movie skips its scenes when the creature has no unspent
 * points (bWeHadPointsInitially = nPointsToSpend > 0), so to actually see the
 * screen you need at least one unspent skill/talent point.
 *
 * <skill> is matched loosely and case-insensitively: coercion/persuade,
 * stealing, traps, survival, herbalism, poison, training, tactics.
 *
 * Arguments are read from the module variable RUNSCRIPT_VAR. The engine may
 * or may not prefix the script name, so a leading "respec1" is dropped, and
 * the variable is cleared after reading -- exactly as the game's own
 * GetRunscriptArgs() (core_h.nss) does -- so arguments cannot leak from one
 * invocation into the next.
 *
 * ---------------------------------------------------------------------------
 * CREDITS
 *   The respecialisation mechanism (remove ability -> refund the point pool)
 *   was pioneered by Peter 'weriK' Kovacs in "Character Respecialization"
 *   (Nexus mod 14) and is reused here under that mod's permission grant:
 *   "You are allowed to modify my files and release bug fixes or improve on
 *   the features so long as you credit me as the original creator."
 *
 *   The ability id tables below are NOT copied from that mod -- they are
 *   derived from BioWare's own 2DA sources shipped with the Toolset
 *   (tools\Source\2DA\rules\ABI_base.xls). Deriving them fixed a latent bug:
 *   MASTER_COMBAT_TRAINING is id 100103, not 100104.
 *
 * Build: compile with the Dragon Age Toolset -> respec1.ncs, then
 *        build\build-dazip.ps1 and build\install-dazip.ps1.
 *=========================================================================*/

#include "2da_constants_h"
#include "ability_h"
#include "attributes_h"
#include "sys_rewards_h"
#include "utility_h"
#include "wrappers_h"
#include "core_h"

// ---------------------------------------------------------------------------
// Ability id tables (see CREDITS above).
// ---------------------------------------------------------------------------
// Skill ranks -- 32 ids, derived from BioWare's ABI_base.xls (tools\Source\2DA).
void RES_FillSkillIds(int[] a)
{
    a[0] = 100011; a[1] = 100012; a[2] = 100013; a[3] = 100014; a[4] = 100021; a[5] = 100022; a[6] = 100023; a[7] = 100024;
    a[8] = 100041; a[9] = 100042; a[10] = 100043; a[11] = 100044; a[12] = 100051; a[13] = 100052; a[14] = 100053; a[15] = 100054;
    a[16] = 100061; a[17] = 100062; a[18] = 100063; a[19] = 100064; a[20] = 100071; a[21] = 100072; a[22] = 100073; a[23] = 100074;
    a[24] = 100100; a[25] = 100101; a[26] = 100102; a[27] = 100103; a[28] = 100110; a[29] = 100111; a[30] = 100112; a[31] = 100113;
}

// Player talents -- 99 ids, derived from BioWare's ABI_base.xls (tools\Source\2DA).
void RES_FillTalentIds(int[] a)
{
    a[0] = 1; a[1] = 2; a[2] = 3; a[3] = 4; a[4] = 5; a[5] = 6; a[6] = 7; a[7] = 8;
    a[8] = 9; a[9] = 10; a[10] = 11; a[11] = 12; a[12] = 13; a[13] = 14; a[14] = 17; a[15] = 19;
    a[16] = 20; a[17] = 21; a[18] = 23; a[19] = 25; a[20] = 27; a[21] = 28; a[22] = 33; a[23] = 34;
    a[24] = 35; a[25] = 36; a[26] = 37; a[27] = 38; a[28] = 42; a[29] = 48; a[30] = 52; a[31] = 56;
    a[32] = 91; a[33] = 92; a[34] = 93; a[35] = 500; a[36] = 603; a[37] = 617; a[38] = 700; a[39] = 701;
    a[40] = 704; a[41] = 705; a[42] = 708; a[43] = 709; a[44] = 713; a[45] = 717; a[46] = 718; a[47] = 777;
    a[48] = 800; a[49] = 801; a[50] = 802; a[51] = 803; a[52] = 804; a[53] = 805; a[54] = 808; a[55] = 1000;
    a[56] = 1004; a[57] = 3000; a[58] = 3001; a[59] = 3002; a[60] = 3006; a[61] = 3009; a[62] = 3016; a[63] = 3017;
    a[64] = 3021; a[65] = 3023; a[66] = 3024; a[67] = 3025; a[68] = 3026; a[69] = 3028; a[70] = 3030; a[71] = 3031;
    a[72] = 3032; a[73] = 3035; a[74] = 3036; a[75] = 3037; a[76] = 3038; a[77] = 3039; a[78] = 3041; a[79] = 3043;
    a[80] = 3044; a[81] = 3045; a[82] = 3049; a[83] = 3050; a[84] = 3051; a[85] = 3058; a[86] = 3059; a[87] = 3060;
    a[88] = 3065; a[89] = 3066; a[90] = 3067; a[91] = 3069; a[92] = 3071; a[93] = 3072; a[94] = 3073; a[95] = 3074;
    a[96] = 3080; a[97] = 12007; a[98] = 12010;
}

// Player spells -- 87 ids, derived from BioWare's ABI_base.xls (tools\Source\2DA).
void RES_FillSpellIds(int[] a)
{
    a[0] = 10001; a[1] = 10002; a[2] = 10003; a[3] = 10009; a[4] = 10104; a[5] = 10200; a[6] = 10202; a[7] = 10203;
    a[8] = 10204; a[9] = 10206; a[10] = 10207; a[11] = 10208; a[12] = 10209; a[13] = 10210; a[14] = 10211; a[15] = 10400;
    a[16] = 10401; a[17] = 10500; a[18] = 10504; a[19] = 10506; a[20] = 10507; a[21] = 10508; a[22] = 10509; a[23] = 10510;
    a[24] = 10601; a[25] = 10700; a[26] = 10701; a[27] = 10702; a[28] = 10703; a[29] = 10704; a[30] = 10900; a[31] = 11000;
    a[32] = 11001; a[33] = 11002; a[34] = 11003; a[35] = 11004; a[36] = 11005; a[37] = 11006; a[38] = 11007; a[39] = 11100;
    a[40] = 11101; a[41] = 11106; a[42] = 11107; a[43] = 11108; a[44] = 11109; a[45] = 11110; a[46] = 11111; a[47] = 11112;
    a[48] = 11113; a[49] = 11114; a[50] = 11115; a[51] = 11116; a[52] = 11121; a[53] = 11122; a[54] = 11123; a[55] = 11124;
    a[56] = 11126; a[57] = 11131; a[58] = 12004; a[59] = 12005; a[60] = 12006; a[61] = 12008; a[62] = 12011; a[63] = 13000;
    a[64] = 13001; a[65] = 13002; a[66] = 14000; a[67] = 14001; a[68] = 14002; a[69] = 14004; a[70] = 14005; a[71] = 15002;
    a[72] = 15003; a[73] = 17000; a[74] = 17001; a[75] = 17002; a[76] = 17007; a[77] = 17008; a[78] = 17009; a[79] = 17010;
    a[80] = 17019; a[81] = 17020; a[82] = 17021; a[83] = 17022; a[84] = 17023; a[85] = 17028; a[86] = 17029;
}

// ---------------------------------------------------------------------------
// Point pools. Skill points and spell/talent points are separate pools; the
// level-up UI reads them as CharGenCreature.Attributes.35 and .36.
// ---------------------------------------------------------------------------
void RES_GivePoints(object oCharacter, int nProperty, float fAmount)
{
    float fUnspent = IntToFloat(GetCreatureAttribute(oCharacter, nProperty, PROPERTY_VALUE_TOTAL));
    SetCreatureProperty(oCharacter, nProperty, fUnspent + fAmount);
}

// Strip every ability in the list that the character owns, refunding
// fPerRank into nProperty for each one removed.
int RES_StripList(object oCharacter, int[] arIds, int nProperty, float fPerRank)
{
    int i;
    int nRemoved = 0;

    for (i = 0; i < GetArraySize(arIds); i++)
    {
        if (HasAbility(oCharacter, arIds[i]))
        {
            RemoveAbility(oCharacter, arIds[i]);
            RES_GivePoints(oCharacter, nProperty, fPerRank);
            nRemoved = nRemoved + 1;
        }
    }

    return nRemoved;
}

// ---------------------------------------------------------------------------
// Attributes. A humanoid's attributes start at 10 each plus the race
// adjustment, so the baseline total is always 64. Sources:
//   ABI.. attributes.xls  (Str=1, Dex=2, Con=3, Int=4, Will=5, Magic=6)
//   RACE_base.xls         (Dwarf 1, Elf 2, Human 3; each sums to +4)
// ---------------------------------------------------------------------------
int RES_RaceAdjustment(int nRace, int nAttribute)
{
    if (nRace == 1)   // Dwarf: +1 Str, +1 Dex, +2 Con
    {
        if (nAttribute == PROPERTY_ATTRIBUTE_STRENGTH)     { return 1; }
        if (nAttribute == PROPERTY_ATTRIBUTE_DEXTERITY)    { return 1; }
        if (nAttribute == PROPERTY_ATTRIBUTE_CONSTITUTION) { return 2; }
        return 0;
    }
    if (nRace == 2)   // Elf: +2 Willpower, +2 Magic
    {
        if (nAttribute == PROPERTY_ATTRIBUTE_WILLPOWER) { return 2; }
        if (nAttribute == PROPERTY_ATTRIBUTE_MAGIC)     { return 2; }
        return 0;
    }
    if (nRace == 3)   // Human: +1 Str, +1 Dex, +1 Int, +1 Magic
    {
        if (nAttribute == PROPERTY_ATTRIBUTE_STRENGTH)  { return 1; }
        if (nAttribute == PROPERTY_ATTRIBUTE_DEXTERITY) { return 1; }
        if (nAttribute == PROPERTY_ATTRIBUTE_INTELLIGENCE) { return 1; }
        if (nAttribute == PROPERTY_ATTRIBUTE_MAGIC)     { return 1; }
        return 0;
    }
    return 0;
}

// Reset each attribute back to its chargen baseline and return how many
// points that freed.
float RES_ResetAttributes(object oCharacter)
{
    int[] arAttrs;
    int   nRace = GetCreatureRacialType(oCharacter);
    int   i;
    float fFreed = 0.0f;

    arAttrs[0] = PROPERTY_ATTRIBUTE_STRENGTH;
    arAttrs[1] = PROPERTY_ATTRIBUTE_DEXTERITY;
    arAttrs[2] = PROPERTY_ATTRIBUTE_CONSTITUTION;
    arAttrs[3] = PROPERTY_ATTRIBUTE_INTELLIGENCE;
    arAttrs[4] = PROPERTY_ATTRIBUTE_WILLPOWER;
    arAttrs[5] = PROPERTY_ATTRIBUTE_MAGIC;

    for (i = 0; i < GetArraySize(arAttrs); i++)
    {
        float fBase   = GetCreatureProperty(oCharacter, arAttrs[i], PROPERTY_VALUE_BASE);
        float fTarget = IntToFloat(10 + RES_RaceAdjustment(nRace, arAttrs[i]));

        if (fBase > fTarget)
        {
            fFreed = fFreed + (fBase - fTarget);
            SetCreatureProperty(oCharacter, arAttrs[i], fTarget, PROPERTY_VALUE_BASE);
        }
    }

    return fFreed;
}

// ---------------------------------------------------------------------------
// Console arguments (RUNSCRIPT_VAR), read from the module, area or hero.
//
// The engine leaves RUNSCRIPT_VAR set, so consume it exactly like the game's
// own GetRunscriptArgs() (core_h.nss) does -- otherwise a previous command's
// arguments leak into the next invocation.
// ---------------------------------------------------------------------------
string RES_GetArgs(object oPC)
{
    string sArgs = GetLocalString(GetModule(), "RUNSCRIPT_VAR");
    SetLocalString(GetModule(), "RUNSCRIPT_VAR", "");

    if (GetStringLength(sArgs) == 0) { sArgs = GetLocalString(GetArea(oPC), "RUNSCRIPT_VAR"); }
    if (GetStringLength(sArgs) == 0) { sArgs = GetLocalString(oPC, "RUNSCRIPT_VAR"); }

    return StringLowerCase(sArgs);
}

// Fill arRanks with a skill's ranks ordered highest -> lowest; returns the
// display name, or "" when the keyword is not recognised.
string RES_ResolveSkill(string sKeyword, int[] arRanks)
{
    if (FindSubString(sKeyword, "coerc") >= 0 || FindSubString(sKeyword, "persuad") >= 0)
    {
        arRanks[0] = 100014; arRanks[1] = 100013; arRanks[2] = 100012; arRanks[3] = 100011;
        return "Coercion";
    }
    if (FindSubString(sKeyword, "steal") >= 0)
    {
        arRanks[0] = 100024; arRanks[1] = 100023; arRanks[2] = 100022; arRanks[3] = 100021;
        return "Stealing";
    }
    if (FindSubString(sKeyword, "trap") >= 0)
    {
        arRanks[0] = 100044; arRanks[1] = 100043; arRanks[2] = 100042; arRanks[3] = 100041;
        return "Trap-Making";
    }
    if (FindSubString(sKeyword, "surviv") >= 0)
    {
        arRanks[0] = 100054; arRanks[1] = 100053; arRanks[2] = 100052; arRanks[3] = 100051;
        return "Survival";
    }
    if (FindSubString(sKeyword, "herb") >= 0)
    {
        arRanks[0] = 100064; arRanks[1] = 100063; arRanks[2] = 100062; arRanks[3] = 100061;
        return "Herbalism";
    }
    if (FindSubString(sKeyword, "poison") >= 0)
    {
        arRanks[0] = 100074; arRanks[1] = 100073; arRanks[2] = 100072; arRanks[3] = 100071;
        return "Poison-Making";
    }
    if (FindSubString(sKeyword, "train") >= 0)
    {
        arRanks[0] = 100103; arRanks[1] = 100102; arRanks[2] = 100101; arRanks[3] = 100100;
        return "Combat Training";
    }
    if (FindSubString(sKeyword, "tactic") >= 0)
    {
        arRanks[0] = 100113; arRanks[1] = 100112; arRanks[2] = 100111; arRanks[3] = 100110;
        return "Combat Tactics";
    }

    return "";
}

int RES_LowerSkill(object oPC, int[] arRanks, int nRanks)
{
    int i;
    int nRemoved = 0;

    for (i = 0; i < GetArraySize(arRanks) && nRemoved < nRanks; i++)
    {
        if (HasAbility(oPC, arRanks[i]))
        {
            RemoveAbility(oPC, arRanks[i]);
            RES_GivePoints(oPC, PROPERTY_SIMPLE_SKILL_POINTS, 1.0f);
            nRemoved = nRemoved + 1;
        }
    }

    return nRemoved;
}

void RES_Finish(object oPC, string sMessage)
{
    Chargen_SetNumTactics(oPC);
    SetCanLevelUp(oPC, Chargen_HasPointsToSpend(oPC));
    ApplyEffectVisualEffect(oPC, oPC, 30023, EFFECT_DURATION_TYPE_INSTANT, 0.0);
    DisplayFloatyMessage(oPC, sMessage, FLOATY_MESSAGE, 16777215, 4.0);
}

void main()
{
    object oPC = GetHero();
    string sArgs, sKeyword, sCount, sLabel;
    int    nLen, nSplit, nWanted;
    int    nSkills, nTalents, nSpells;
    float  fAttr;
    int[]  arIds;
    int[]  arRanks;

    if (oPC == OBJECT_INVALID) { return; }

    sArgs  = RES_GetArgs(oPC);

    // The engine may or may not prefix the script name to the arguments, so
    // drop a leading "respec1" if it is there. What remains is the real
    // argument (empty for a bare `runscript respec1`).
    nSplit = FindSubString(sArgs, " ");
    if (nSplit < 0)
    {
        if (sArgs == "respec1") { sArgs = ""; }
    }
    else if (SubString(sArgs, 0, nSplit) == "respec1")
    {
        sArgs = SubString(sArgs, nSplit + 1, GetStringLength(sArgs) - nSplit - 1);
    }

    nLen   = GetStringLength(sArgs);
    nSplit = FindSubString(sArgs, " ");

    if (nSplit < 0) { sKeyword = sArgs; sCount = ""; }
    else
    {
        sKeyword = SubString(sArgs, 0, nSplit);
        sCount   = SubString(sArgs, nSplit + 1, nLen - nSplit - 1);
    }

    nWanted = StringToInt(sCount);
    if (nWanted < 1) { nWanted = 1; }

    if (nLen == 0)
    {
        // ---- OPEN THE LEVEL-UP SCREEN --------------------------------------
        // A bare `runscript respec1` opens the level-up screen for the hero,
        // changing nothing. nMode 1 is CHARGEN_MODE_LEVELUP
        // (sys_chargen_engine.nss).
        //
        // The movie skips its scenes when there are no unspent points
        // (bWeHadPointsInitially = nPointsToSpend > 0), so at least one
        // unspent skill/talent point is needed for the screen to show.
        StartCharGen(oPC, 1);
    }
    else if (sKeyword == "respec" || sKeyword == "full")
    {
        // Shale has a hidden Combat Tactics rank that is not a real pick.
        if (GetName(oPC) == "Shale")
        {
            DisplayFloatyMessage(oPC, "Respec: no assignable points.", FLOATY_MESSAGE, 16777215, 4.0);
            return;
        }

        // ---- FULL RESSPEC: skills, talents, spells, attributes -------------
        RES_FillSkillIds(arIds);
        nSkills = RES_StripList(oPC, arIds, PROPERTY_SIMPLE_SKILL_POINTS, 1.0f);

        RES_FillTalentIds(arIds);
        nTalents = RES_StripList(oPC, arIds, PROPERTY_SIMPLE_TALENT_POINTS, 1.0f);

        RES_FillSpellIds(arIds);
        nSpells = RES_StripList(oPC, arIds, PROPERTY_SIMPLE_TALENT_POINTS, 1.0f);

        fAttr = RES_ResetAttributes(oPC);
        if (fAttr > 0.0f) { RES_GivePoints(oPC, PROPERTY_SIMPLE_ATTRIBUTE_POINTS, fAttr); }

        RES_Finish(oPC, "Respec: skills " + IntToString(nSkills)
            + ", talents " + IntToString(nTalents)
            + ", spells " + IntToString(nSpells)
            + ", attributes " + IntToString(FloatToInt(fAttr + 0.5f)));
    }
    else
    {
        // ---- single skill ------------------------------------------------
        sLabel = RES_ResolveSkill(sKeyword, arRanks);
        if (GetStringLength(sLabel) == 0)
        {
            DisplayFloatyMessage(oPC, "Respec: unknown skill '" + sKeyword + "'",
                FLOATY_MESSAGE, 16777215, 4.0);
            return;
        }
        RES_Finish(oPC, sLabel + " lowered; points refunded: "
            + IntToString(RES_LowerSkill(oPC, arRanks, nWanted)));
    }
}
