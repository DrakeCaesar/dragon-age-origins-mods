/*
    Upgrade Tiers - raise tiered items to the tier your level has earned

    In the base game a store rerolls the tiered variants of what it stocks each
    time the store is reopened, using the buyer's level, and it may go up or down.
    This script performs the same upgrade for items you already own, but keeps the
    result only when the tier actually rises.

    How the tier is read
    --------------------
    Four values describe an item's metal or wood: Material (its current one) and
    MaterialProgress (which ladder it follows). Every material id belongs to
    exactly one ladder, at exactly one position, so the family and the tier are
    both recoverable from the material id alone:

        melee weapon   40 41 43 42 44 45 46 | 20050 20051
        bow            33 34 35 36 37 38 39 | 20040 20041
        metal armour    1  2  8  4  5  3  6 | 20010 20011
        leather        60 28 29 30 31 17 32 | 20030 20031
        metal shield   47 48 49 81 50 51 52 | 20060 20061
        wood shield    79  9 11 15 13  7 10 | 20020 20021

    The last two columns are the Awakening materials, so an install running
    Awakening in the OC can reach them. A material the script does not recognise
    is left alone, which is how star metal (10000) and the odd robe and clothing
    materials stay untouched.

    Why nothing is written but the material
    ---------------------------------------
    Runes are sub items of the weapon or armour that holds them, and the number of
    slots is a per item variable. This script never writes that variable and never
    touches the sub item list: it records the rune count before the change and puts
    the old material back if the count differs afterwards. An item with runes is
    upgraded exactly like one without.

    A material that is not installed cannot silently produce a broken item either:
    after setting it the script reads the material back, and restores the original
    if the engine refused the value. That is what makes the Awakening tiers safe on
    an install that does not have them.

    Usage
    -----
        runscript upgrade_tiers          upgrade to the tier your level allows
        runscript upgrade_tiers 9        force a specific target tier

    Every character is covered: the hero, the current party, and the camp pool, and
    for each of them the whole inventory including equipped gear and both weapon
    sets.
*/

#include "log_h"
#include "utility_h"
#include "wrappers_h"
#include "events_h"
#include "2da_constants_h"

const int FAMILY_NONE = 0;
const int FAMILY_MELEE = 1;
const int FAMILY_BOW = 2;
const int FAMILY_METAL_ARMOUR = 3;
const int FAMILY_LEATHER = 4;
const int FAMILY_METAL_SHIELD = 5;
const int FAMILY_WOOD_SHIELD = 6;

const int MAX_TIER = 9;

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

// The position of a material within its own ladder, 1 based, or 0 if unknown.
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

        // Awakening
        case 20050: case 20040: case 20010: case 20030: case 20060: case 20020:
            return 8;
        case 20051: case 20041: case 20011: case 20031: case 20061: case 20021:
            return 9;
    }
    return 0;
}

int MaterialForTier(int nFamily, int nTier)
{
    if (nTier < 1 || nTier > MAX_TIER)
    {
        return 0;
    }

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

// ---------------------------------------------------------------- helpers

int IsUpgradableType(int nType)
{
    if (nType == ITEM_TYPE_ARMOUR) { return TRUE; }
    if (nType == ITEM_TYPE_SHIELD) { return TRUE; }
    if (nType == ITEM_TYPE_WEAPON_MELEE) { return TRUE; }
    if (nType == ITEM_TYPE_WEAPON_RANGED) { return TRUE; }
    return FALSE;
}

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

// ---------------------------------------------------------------- the reroll

// The one place that decides what an item becomes. This is the script side
// equivalent of what a store does when it reopens: pick the material for the
// target tier. Returning 0 means "no change".
int RerollItemMaterial(object oItem, int nTargetTier)
{
    int nCurrent = GetItemMaterialType(oItem);
    int nFamily = FamilyFromMaterial(nCurrent);
    if (nFamily == FAMILY_NONE)
    {
        return 0;
    }

    int nCurrentTier = TierFromMaterial(nCurrent);
    if (nTargetTier <= nCurrentTier)
    {
        // Keep what is there: the roll did not improve on it.
        return 0;
    }

    return MaterialForTier(nFamily, nTargetTier);
}

void UpgradeItem(object oItem, object oOwner, int nTargetTier)
{
    if (oItem == OBJECT_INVALID)
    {
        return;
    }
    if (IsUpgradableType(GetItemType(oItem)) == FALSE)
    {
        return;
    }

    int nOld = GetItemMaterialType(oItem);
    if (TierFromMaterial(nOld) == 0)
    {
        return;
    }

    int nNew = RerollItemMaterial(oItem, nTargetTier);
    if (nNew == 0 || nNew == nOld)
    {
        return;
    }

    // Runes are sub items. Count them so the change can be proven not to have
    // disturbed them, and never write the slot count variable that other upgrade
    // mods overwrite.
    int nRunesBefore = GetArraySize(GetItemSubItems(oItem));

    SetItemMaterialType(oItem, nNew);

    if (GetItemMaterialType(oItem) != nNew)
    {
        // The engine rejected the material: it is not installed here, which is how
        // an install without the Awakening tiers behaves. Put the original back.
        SetItemMaterialType(oItem, nOld);
        return;
    }

    int nRunesAfter = GetArraySize(GetItemSubItems(oItem));
    if (nRunesAfter != nRunesBefore)
    {
        SetItemMaterialType(oItem, nOld);
        PrintToLogAndFlush("Upgrade Tiers: reverted " + GetTag(oItem) + ", rune count changed from " + IntToString(nRunesBefore) + " to " + IntToString(nRunesAfter));
        return;
    }

    PrintToLogAndFlush("Upgrade Tiers: " + GetTag(oItem) + " tier " + IntToString(TierFromMaterial(nOld)) + " -> " + IntToString(TierFromMaterial(nNew)) + " (" + IntToString(nOld) + " -> " + IntToString(nNew) + "), runes " + IntToString(nRunesBefore));
    DisplayFloatyMessage(oOwner, "Upgraded: " + GetName(oItem), FLOATY_MESSAGE, 16777215, 2.0);
}

void UpgradeCreature(object oCreature, int nTargetTier)
{
    if (oCreature == OBJECT_INVALID)
    {
        return;
    }

    object[] aItems = GetItemsInInventory(oCreature, GET_ITEMS_OPTION_ALL);
    int nCount = GetArraySize(aItems);
    int nIndex = 0;
    while (nIndex < nCount)
    {
        UpgradeItem(aItems[nIndex], oCreature, nTargetTier);
        nIndex = nIndex + 1;
    }
}

// ---------------------------------------------------------------- entry point

void main()
{
    int nTargetTier = 0;

    // "runscript upgrade_tiers 9" forces a tier; anything else uses the level.
    string sArgument = GetLocalString(GetModule(), "RUNSCRIPT_VAR");
    int nForced = StringToInt(sArgument);
    if (nForced >= 1 && nForced <= MAX_TIER)
    {
        nTargetTier = nForced;
    }

    int nUpgradedCharacters = 0;

    // Hero, then the active party, then the camp pool, which is where companions
    // who are not currently travelling keep their gear.
    object oHero = GetHero();
    if (oHero != OBJECT_INVALID)
    {
        if (nTargetTier == 0)
        {
            nTargetTier = TargetTierForLevel(CreatureLevel(oHero));
        }
        UpgradeCreature(oHero, nTargetTier);
        nUpgradedCharacters = nUpgradedCharacters + 1;
    }

    object[] aParty = GetPartyList();
    int nParty = GetArraySize(aParty);
    int nIndex = 0;
    while (nIndex < nParty)
    {
        UpgradeCreature(aParty[nIndex], nTargetTier);
        nUpgradedCharacters = nUpgradedCharacters + 1;
        nIndex = nIndex + 1;
    }

    object[] aPool = GetPartyPoolList();
    int nPool = GetArraySize(aPool);
    nIndex = 0;
    while (nIndex < nPool)
    {
        UpgradeCreature(aPool[nIndex], nTargetTier);
        nUpgradedCharacters = nUpgradedCharacters + 1;
        nIndex = nIndex + 1;
    }

    PrintToLogAndFlush("Upgrade Tiers: target tier " + IntToString(nTargetTier) + " across " + IntToString(nUpgradedCharacters) + " characters.");
    DisplayFloatyMessage(oHero, "Upgrade Tiers: tier " + IntToString(nTargetTier), FLOATY_MESSAGE, 16777215, 3.0);
}
