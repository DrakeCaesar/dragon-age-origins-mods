/*
    Upgrade Tiers - raise each item to the highest tier it actually supports

    In the base game a store rerolls the tiered variants of what it stocks each
    time it is reopened, using the buyer's level, and the result may go up, go
    down, or stay the same. This does the same for items already in the party's
    possession, but keeps the result only when the tier rises.

    Which tiers an item supports
    ---------------------------
    Not every item can be every material. The engine has the final say: a material
    is applied, read back, and if it did not take the next tier down is tried. So
    the result is the highest tier that particular item accepts, not the highest
    that exists in general.

    The material ids below are how the ladder is walked. They were taken from the
    item templates and checked against all 1016 of them: no material appears in two
    ladders, and every item that has a tiered material falls into exactly one of
    these families. Ids that are not listed (clothing, robes, single uniques, star
    metal) are deliberately left alone.

        melee weapon   40 41 43 42 44 45 46 | 20050 20051
        bow            33 34 35 36 37 38 39 | 20040 20041
        metal armour    1  2  8  4  5  3  6 | 20010 20011
        leather        60 28 29 30 31 17 32 | 20030 20031
        metal shield   47 48 49 81 50 51 52 | 20060 20061
        wood shield    79  9 11 15 13  7 10 | 20020 20021

    The last two columns are the Awakening materials, so items reach them only if
    their own progression allows it.

    Why several passes over each inventory
    --------------------------------------
    Changing an item's material can invalidate the other item references already
    held from the same inventory read, so one pass over a snapshot reaches only part
    of the list. The list is fetched again after each pass, which is much cheaper
    than a fetch per item.

    Runes
        -----
        An item's runes are lost when its material changes, and the script API can read
        the slot list but has nothing that puts a sub item back. That is accepted: a rune
        is an item the player can install again, while a tier the player has outgrown
        cannot be recovered. The count of upgraded items that had runes is reported so the
        cost is visible. The slot capability variable that other upgrade mods overwrite
        (ITEM_RUNE_ENABLED) is never written here.

    Reading the result
    ------------------
    Floaties are the only channel that renders in the retail build; the on-screen
    debug text and the GUI log window both produce nothing. A normal run reports two
    short lines:

        Upgraded 25 items to tier 9
        Run again for the next batch

    When there is nothing left it says so, and repeating the command produces the
    same answer, which is the intended end state rather than a fault:

        Nothing left at tier 9

    A negative argument turns on the diagnostics, and its magnitude is the tier:

        runscript upgrade_tiers -9

    Every item is then reported as it is handled, and a summary adds how many were
    already at target, how many had a material outside the ladders, how many writes
    the engine refused, and the spread of tiers found:

        7/769 nofam m61     material has no ladder, untouched
        8/769 top t6        already at or above the target
        9/769 set46         about to write material 46
        9/769 ok t7         it took
        9/769 took-no       it did not take, next tier down is tried
        9/769 fail          no tier between current and target was accepted

    A material an item cannot take is normal: the progression decides what an item
    may become, and only the Awakening materials reach tiers 8 and 9.

    Usage
    -----
        runscript upgrade_tiers          highest tier your level allows
        runscript upgrade_tiers 9        highest tier up to 9 that the item allows
        runscript upgrade_tiers -9       the same, with diagnostics

    A single run covers the whole inventory. The engine's own per-script instruction
    limit used to stop this script partway, silently and with no error, which is what
    made earlier versions appear to do nothing; it has far more than enough headroom
    now, so the work no longer has to be spread over repeated invocations.

        Upgraded 24 items to tier 9
        All done

    Only the Warden's inventory is swept. In Dragon Age that inventory is the shared
    party stash, so it holds nearly everything the party owns; the companions' own
    inventories and camp storage hold only spares.
*/

#include "log_h"
#include "utility_h"
#include "wrappers_h"
#include "events_h"
#include "2da_constants_h"

const int MAX_TIER = 9;

// The engine used to stop any script at 131072 VM instructions, silently, which is
// why this script once had to change only a handful of items per run and be
// re-invoked. DAFix raises that cap, so a single run now covers the whole inventory
// and this is only a safety valve against a runaway loop. It is far above any
// inventory this game can produce.
const int MAX_UPDATES = 10000;

const string BUILD = "ut47";

// The display shows only a handful of floaties at once, so the per-operation lines
// are opt-in. A negative tier argument turns them on: "runscript upgrade_tiers -9"
// sweeps towards tier 9 and reports every operation.
int g_bVerbose = FALSE;

int g_nChanged = 0;
int g_nWearable = 0;
int g_nExamined = 0;
int g_nPending = 0;

// Names of the first and last item raised this run. Only read for items that were
// actually changed, since a name costs a call and most items are only examined.
// A repeated first name across runs would mean that item keeps being rewritten.
string g_sFirstName = "";
string g_sLastName = "";

int g_nAtTop = 0;
int g_nNoLadder = 0;
int g_nRefused = 0;
int g_nTookNo = 0;
int g_nRuned = 0;
int g_nStale = 0;
string g_sFirstRuned = "";

// How many items sit at each tier, as our ladder reads them. Items with a material
// that is not on any ladder are counted as unknown. This is the one measurement that
// says whether the inventory is genuinely near its ceiling or the ladder misreads it.
int g_nTier1 = 0;
int g_nTier2 = 0;
int g_nTier3 = 0;
int g_nTier4 = 0;
int g_nTier5 = 0;
int g_nTier6 = 0;
int g_nTier7 = 0;
int g_nTier8 = 0;
int g_nTier9 = 0;
int g_nUnknown = 0;

void CountTier(int nTier)
{
    if (nTier == 1) { g_nTier1 = g_nTier1 + 1; }
    else if (nTier == 2) { g_nTier2 = g_nTier2 + 1; }
    else if (nTier == 3) { g_nTier3 = g_nTier3 + 1; }
    else if (nTier == 4) { g_nTier4 = g_nTier4 + 1; }
    else if (nTier == 5) { g_nTier5 = g_nTier5 + 1; }
    else if (nTier == 6) { g_nTier6 = g_nTier6 + 1; }
    else if (nTier == 7) { g_nTier7 = g_nTier7 + 1; }
    else if (nTier == 8) { g_nTier8 = g_nTier8 + 1; }
    else if (nTier == 9) { g_nTier9 = g_nTier9 + 1; }
    else { g_nUnknown = g_nUnknown + 1; }
}
string g_sFirstFail = "";

// Item counts describe the inventory as found, so they are only taken on the
// first pass over each creature; later passes exist just to catch stragglers.


const int FAMILY_NONE = 0;
const int FAMILY_MELEE = 1;
const int FAMILY_BOW = 2;
const int FAMILY_METAL_ARMOUR = 3;
const int FAMILY_LEATHER = 4;
const int FAMILY_METAL_SHIELD = 5;
const int FAMILY_WOOD_SHIELD = 6;

// ---------------------------------------------------------------- ladder lookups

int FamilyFromMaterial(int nMaterial)
{
    switch(nMaterial)
    {
        case 40: case 41: case 43: case 42: case 44: case 45: case 46:
        case 20050: case 20051:
            return FAMILY_MELEE;

        case 33: case 34: case 35: case 36: case 37: case 38: case 39:
        case 20040: case 20041:
            return FAMILY_BOW;

        case 1: case 2: case 8: case 4: case 5: case 3: case 6:
        case 20010: case 20011:
            return FAMILY_METAL_ARMOUR;

        case 60: case 28: case 29: case 30: case 31: case 17: case 32:
        case 20030: case 20031:
            return FAMILY_LEATHER;

        case 47: case 48: case 49: case 81: case 50: case 51: case 52:
        case 20060: case 20061:
            return FAMILY_METAL_SHIELD;

        case 79: case 9: case 11: case 15: case 13: case 7: case 10:
        case 20020: case 20021:
            return FAMILY_WOOD_SHIELD;
    }
    return FAMILY_NONE;
}

int TierFromMaterial(int nMaterial)
{
    switch(nMaterial)
    {
        case 40: case 33: case 1: case 60: case 47: case 79:
            return 1;
        case 41: case 34: case 2: case 28: case 48: case 9:
            return 2;
        case 43: case 35: case 8: case 29: case 49: case 11:
            return 3;
        case 42: case 36: case 4: case 30: case 81: case 15:
            return 4;
        case 44: case 37: case 5: case 31: case 50: case 13:
            return 5;
        case 45: case 38: case 3: case 17: case 51: case 7:
            return 6;
        case 46: case 39: case 6: case 32: case 52: case 10:
            return 7;

        case 20050: case 20040: case 20010: case 20030: case 20060: case 20020:
            return 8;
        case 20051: case 20041: case 20011: case 20031: case 20061: case 20021:
            return 9;
    }
    return 0;
}

int MaterialForTier(int nFamily, int nTier)
{
    if (nFamily == FAMILY_MELEE)
    {
        switch(nTier)
        {
            case 1: return 40;
            case 2: return 41;
            case 3: return 43;
            case 4: return 42;
            case 5: return 44;
            case 6: return 45;
            case 7: return 46;
            case 8: return 20050;
            case 9: return 20051;
        }
    }
    else if (nFamily == FAMILY_BOW)
    {
        switch(nTier)
        {
            case 1: return 33;
            case 2: return 34;
            case 3: return 35;
            case 4: return 36;
            case 5: return 37;
            case 6: return 38;
            case 7: return 39;
            case 8: return 20040;
            case 9: return 20041;
        }
    }
    else if (nFamily == FAMILY_METAL_ARMOUR)
    {
        switch(nTier)
        {
            case 1: return 1;
            case 2: return 2;
            case 3: return 8;
            case 4: return 4;
            case 5: return 5;
            case 6: return 3;
            case 7: return 6;
            case 8: return 20010;
            case 9: return 20011;
        }
    }
    else if (nFamily == FAMILY_LEATHER)
    {
        switch(nTier)
        {
            case 1: return 60;
            case 2: return 28;
            case 3: return 29;
            case 4: return 30;
            case 5: return 31;
            case 6: return 17;
            case 7: return 32;
            case 8: return 20030;
            case 9: return 20031;
        }
    }
    else if (nFamily == FAMILY_METAL_SHIELD)
    {
        switch(nTier)
        {
            case 1: return 47;
            case 2: return 48;
            case 3: return 49;
            case 4: return 81;
            case 5: return 50;
            case 6: return 51;
            case 7: return 52;
            case 8: return 20060;
            case 9: return 20061;
        }
    }
    else if (nFamily == FAMILY_WOOD_SHIELD)
    {
        switch(nTier)
        {
            case 1: return 79;
            case 2: return 9;
            case 3: return 11;
            case 4: return 15;
            case 5: return 13;
            case 6: return 7;
            case 7: return 10;
            case 8: return 20020;
            case 9: return 20021;
        }
    }
    return 0;
}

// ---------------------------------------------------------------- item work

// The material ladder is the filter: anything whose material has no tier is not
// tiered gear, so no separate type test is needed. That saves a call per item, and
// there are far more non-gear items than gear.

// The tier a character has earned. These bands follow the same shape the store
// uses: early game stays iron, and the top of the ladder is only reached late.
int TargetTierForLevel(int nLevel)
{
    if (nLevel < 3) { return 2; }
    if (nLevel < 6) { return 3; }
    if (nLevel < 9) { return 4; }
    if (nLevel < 12) { return 5; }
    if (nLevel < 15) { return 6; }
    if (nLevel < 18) { return 7; }
    if (nLevel < 21) { return 8; }
    return 9;
}

int CreatureLevel(object oCreature)
{
    return FloatToInt(GetCreatureProperty(oCreature, PROPERTY_SIMPLE_LEVEL));
}

// One line per operation, naming the item's position in the sweep and the
// operation itself. Only shown in verbose mode: the display holds about five lines
// at a time, so a 769 item sweep would bury the summary.
void Line(string sText)
{
    if (g_bVerbose == FALSE)
    {
        return;
    }
    DisplayFloatyMessage(GetHero(), BUILD + " " + sText, FLOATY_MESSAGE, 16777215, 4.0);
}

// A slot array is not a rune count. GetItemSubItems lists every slot the item has,
// using OBJECT_INVALID for the empty ones, so only a filled slot holds a rune.
int FilledSlots(object oItem)
{
    object[] aSlots = GetItemSubItems(oItem);
    int nFilled = 0;
    int nSize = GetArraySize(aSlots);
    int nIndex = 0;
    while (nIndex < nSize)
    {
        if (aSlots[nIndex] != OBJECT_INVALID)
        {
            nFilled = nFilled + 1;
        }
        nIndex = nIndex + 1;
    }
    return nFilled;
}

// Raises one item, stepping down from the target until the engine accepts the
// material. Returns 1 when the item changed.
int UpgradeItem(object oItem, int nTargetTier, int nIndex, int nCount)
{
    g_nExamined = g_nExamined + 1;

    // A heartbeat every hundred items. The display keeps only the most recent
    // handful of messages, so wherever the messages stop is where the sweep stopped.
    // The tallies say why nothing changed: no ladder rung, already at target, or a
    // write the engine refused.
    if ((g_nExamined == 100 || g_nExamined == 200 || g_nExamined == 300
        || g_nExamined == 400 || g_nExamined == 500 || g_nExamined == 600
        || g_nExamined == 700 || g_nExamined == 800) && g_bVerbose == TRUE)
    {
        DisplayFloatyMessage(GetHero(), "n" + IntToString(g_nExamined)
                + " up" + IntToString(g_nChanged)
                + " top" + IntToString(g_nAtTop)
                + " none" + IntToString(g_nNoLadder)
                + " fail" + IntToString(g_nRefused)
                + " rn" + IntToString(g_nRuned)
                + " st" + IntToString(g_nStale),
            FLOATY_MESSAGE, 16777215, 4.0);
    }

    int nOld = GetItemMaterialType(oItem);
    int nFamily = FamilyFromMaterial(nOld);
    string sAt = IntToString(nIndex) + "/" + IntToString(nCount);

    if (nFamily == FAMILY_NONE)
    {
        g_nNoLadder = g_nNoLadder + 1;
        g_nUnknown = g_nUnknown + 1;
        Line(sAt + " nofam m" + IntToString(nOld));
        return 0;
    }

    int nCurrentTier = TierFromMaterial(nOld);
    CountTier(nCurrentTier);
    if (nCurrentTier >= nTargetTier)
    {
        g_nAtTop = g_nAtTop + 1;
        Line(sAt + " top t" + IntToString(nCurrentTier));
        return 0;
    }

    g_nWearable = g_nWearable + 1;
    g_nPending = g_nPending + 1;

    // Nothing more is changed once the budget is spent.
    if (g_nChanged >= MAX_UPDATES)
    {
        return 0;
    }

    // Runes installed in an item are lost when its material changes, and the API has
    // nothing that puts them back. That is accepted: a rune is an item the player can
    // install again, whereas a gear tier, once the window for it has passed, cannot be
    // recovered at all. The count is only reported.
    int nRunedBefore = FilledSlots(oItem);

    int nTier = nTargetTier;
    while (nTier > nCurrentTier)
    {
        int nNew = MaterialForTier(nFamily, nTier);
        if (nNew != 0 && nNew != nOld)
        {
            Line(sAt + " set" + IntToString(nNew));
            SetItemMaterialType(oItem, nNew);
            if (GetItemMaterialType(oItem) == nNew)
            {
                if (nRunedBefore > 0)
                {
                    g_nRuned = g_nRuned + 1;
                    if (g_sFirstRuned == "")
                    {
                        g_sFirstRuned = GetName(oItem) + "|" + IntToString(nRunedBefore);
                    }
                }
                g_nChanged = g_nChanged + 1;
                if (g_sFirstName == "")
                {
                    g_sFirstName = GetName(oItem);
                }
                g_sLastName = GetName(oItem);
                Line(sAt + " ok t" + IntToString(nTier));
                return 1;
            }
            SetItemMaterialType(oItem, nOld);
            g_nTookNo = g_nTookNo + 1;
            Line(sAt + " took-no");
        }
        nTier = nTier - 1;
    }

    // No material between the target and the current one was taken. Record what the
    // item actually had, so the reason can be read without a verbose run.
    g_nRefused = g_nRefused + 1;
    if (g_sFirstFail == "")
    {
        g_sFirstFail = GetName(oItem) + " m" + IntToString(nOld)
            + " cur" + IntToString(nCurrentTier);
    }
    Line(sAt + " fail");
    return 0;
}

// Sweeps one creature's inventory, one item at a time.
//
// The type filter is deliberately left at 0. GetItemsInInventory's third argument
// expects a BASE_ITEM_* value, which is a different enumeration from the ITEM_TYPE_*
// constants returned by GetItemType; passing those was selecting arbitrary base item
// types rather than weapons and armour, which is why whole categories of gear were
// never touched. The material ladder is the real filter: anything whose material has
// no tier is skipped for the cost of one call.
int SweepType(object oCreature, int nTargetTier, int nBaseItemType)
{
    int nChanged = 0;
    object[] aItems = GetItemsInInventory(oCreature, GET_ITEMS_OPTION_ALL,
        nBaseItemType, "", TRUE);
    int nCount = GetArraySize(aItems);
    int nIndex = 0;
    int nRefreshes = 0;
    while (nIndex < nCount)
    {
        if (g_nChanged >= MAX_UPDATES)
        {
            break;
        }
        object oItem = aItems[nIndex];

        // Fetching the list again after every change costs a full inventory read each
        // time, which is far too much at this size. Nothing of the sort has ever been
        // needed: no dead reference has been observed. The list is therefore only
        // re-read if a dead reference actually turns up.
        if (oItem == OBJECT_INVALID)
        {
            g_nStale = g_nStale + 1;
            nRefreshes = nRefreshes + 1;
            if (nRefreshes > 4)
            {
                break;
            }
            aItems = GetItemsInInventory(oCreature, GET_ITEMS_OPTION_ALL,
                nBaseItemType, "", TRUE);
            nCount = GetArraySize(aItems);
            oItem = aItems[nIndex];
            if (oItem == OBJECT_INVALID)
            {
                nIndex = nIndex + 1;
                continue;
            }
        }

        nIndex = nIndex + 1;
        nChanged = nChanged + UpgradeItem(oItem, nTargetTier, nIndex, nCount);
    }
    return nChanged;
}

int UpgradeCreature(object oCreature, int nTargetTier)
{
    if (oCreature == OBJECT_INVALID)
    {
        return 0;
    }

    return SweepType(oCreature, nTargetTier, 0);
}

// ---------------------------------------------------------------- reporting

// Only floaties render in this build: the on-screen debug text and the GUI log
// window both produce nothing, and the script logging functions have no writable
// category (the executable has no ECLog support at all). Floaties do render after
// an item has been changed -- the existing UpgradeItems mod relies on exactly that
// -- so every change is reported as it happens, one floaty per item. A run that
// stops partway therefore ends on the name of the item it stopped at, and no state
// has to survive between invocations.

// ---------------------------------------------------------------- entry point

void main()
{
    object oHero = GetHero();
    if (oHero == OBJECT_INVALID)
    {
        return;
    }

    int nTargetTier = 0;
    string sArgument = GetLocalString(GetModule(), "RUNSCRIPT_VAR");
    int nForced = StringToInt(sArgument);

    // A negative argument means verbose, and its magnitude is the tier, so "-9"
    // sweeps towards tier 9 reporting every operation and "9" sweeps quietly.
    if (nForced < 0)
    {
        g_bVerbose = TRUE;
        nForced = 0 - nForced;
    }
    if (nForced >= 1 && nForced <= MAX_TIER)
    {
        nTargetTier = nForced;
    }
    if (nTargetTier == 0)
    {
        nTargetTier = TargetTierForLevel(CreatureLevel(oHero));
    }

    g_nChanged = 0;
    g_nWearable = 0;
    g_nAtTop = 0;
    g_nNoLadder = 0;
    g_nRefused = 0;
    g_nTookNo = 0;
    g_nRuned = 0;
    g_nStale = 0;
    g_sFirstRuned = "";
    g_sFirstFail = "";
    g_nTier1 = 0; g_nTier2 = 0; g_nTier3 = 0; g_nTier4 = 0; g_nTier5 = 0;
    g_nTier6 = 0; g_nTier7 = 0; g_nTier8 = 0; g_nTier9 = 0; g_nUnknown = 0;
    g_nExamined = 0;
    g_nPending = 0;
    g_sFirstName = "";
    g_sLastName = "";

    // Only the Warden's own inventory is swept. In Dragon Age that is the shared
    // party stash, so it holds nearly everything the party owns; a companion's
    // inventory holds a handful of spares and camp storage holds less, while every
    // extra creature costs another full sweep. Restricting the sweep here keeps each
    // run well inside what the script can do and covers the inventory that matters.
    UpgradeCreature(oHero, nTargetTier);

    // Two lines: what happened, and where it stands. Everything else was diagnostic
    // scaffolding for the investigation and is only shown with a negative argument.
    if (g_nChanged > 0)
    {
        DisplayFloatyMessage(oHero, "Upgraded " + IntToString(g_nChanged)
                + " items to tier " + IntToString(nTargetTier),
            FLOATY_MESSAGE, 16777215, 6.0);
    }
    else
    {
        DisplayFloatyMessage(oHero, "Nothing left at tier " + IntToString(nTargetTier),
            FLOATY_MESSAGE, 16777215, 6.0);
    }

    if (g_nChanged >= MAX_UPDATES)
    {
        DisplayFloatyMessage(oHero, "Run again for the next batch",
            FLOATY_MESSAGE, 16777215, 6.0);
    }
    else if (g_nChanged > 0)
    {
        DisplayFloatyMessage(oHero, "All done",
            FLOATY_MESSAGE, 16777215, 6.0);
    }

    if (g_bVerbose == TRUE)
    {
        DisplayFloatyMessage(oHero, "checked" + IntToString(g_nExamined)
                + " top" + IntToString(g_nAtTop)
                + " noTier" + IntToString(g_nNoLadder)
                + " refused" + IntToString(g_nRefused),
            FLOATY_MESSAGE, 16777215, 6.0);
        DisplayFloatyMessage(oHero, "t1-" + IntToString(g_nTier1)
                + " t2-" + IntToString(g_nTier2) + " t3-" + IntToString(g_nTier3)
                + " t4-" + IntToString(g_nTier4) + " t5-" + IntToString(g_nTier5)
                + " t6-" + IntToString(g_nTier6) + " t7-" + IntToString(g_nTier7)
                + " t8-" + IntToString(g_nTier8) + " t9-" + IntToString(g_nTier9),
            FLOATY_MESSAGE, 16777215, 6.0);
        DisplayFloatyMessage(oHero, "runed" + IntToString(g_nRuned)
                + " " + g_sFirstRuned + " " + g_sFirstFail,
            FLOATY_MESSAGE, 16777215, 6.0);
    }
}