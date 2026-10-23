// All module events
#include "2da_constants_h"
#include "utility_h"
#include "wrappers_h"
#include "events_h"

void bodini_level_item(object oItem, int iLevel, object oToon);
void bodini_level_toon(object oToon, int iLevel);

void main()
{
    event ev   = GetCurrentEvent();
    int nEvent = GetEventType(ev);
    Log_Events("", ev);
    switch (nEvent)
    {
        case EVENT_TYPE_UNIQUE_POWER:
        {
            object oItem = GetEventObject(ev,0);
            string sTag =  GetTag(oItem);
            if(sTag == "bodini_upgrade_item_trigger")
            {
                object oToon = GetEventCreator(ev);
                int nRace = GetCreatureRacialType(oToon);
                if(nRace == RACE_HUMAN || nRace == RACE_ELF ||
                   nRace == RACE_DWARF || nRace == RACE_QUNARI)
                    bodini_level_toon(oToon, GetLevel(oToon));
            }
            else if(sTag == "bodini_upgrade_rune_gui")
            {
                OpenItemUpgradeGUI();
            }
            break;
        }

        case EVENT_TYPE_MODULE_LOAD:
        {
            // bail out if already run
            int iModuleLoaded = GetLocalInt(OBJECT_SELF, "bodini_mod");
            if (iModuleLoaded == 1) {
                break;
            } else {
                SetLocalInt(OBJECT_SELF, "bodini_mod", 1);
            }

            // get the object which contains the player
            object oPlayer = GetHero();

            // create items
            if(! CountItemsByTag(oPlayer,"bodini_upgrade_item_trigger"))
                UT_AddItemToInventory(R"bodini_upgrade_item_trigger.uti",1);
            if(! CountItemsByTag(oPlayer,"bodini_upgrade_rune_gui"))
                UT_AddItemToInventory(R"bodini_upgrade_rune_gui.uti",1);
                
            break;
        }
        default:
        {
            break;
        }
    }
}

void bodini_level_toon(object oToon, int iLevel)
{
    // scale equiped items
    bodini_level_item(GetItemInEquipSlot(INVENTORY_SLOT_CHEST, oToon), iLevel, oToon);
    bodini_level_item(GetItemInEquipSlot(INVENTORY_SLOT_BOOTS, oToon), iLevel, oToon);
    bodini_level_item(GetItemInEquipSlot(INVENTORY_SLOT_GLOVES, oToon), iLevel, oToon);
    bodini_level_item(GetItemInEquipSlot(INVENTORY_SLOT_HEAD, oToon), iLevel, oToon);
    bodini_level_item(GetItemInEquipSlot(INVENTORY_SLOT_MAIN, oToon, 0), iLevel, oToon);
    bodini_level_item(GetItemInEquipSlot(INVENTORY_SLOT_OFFHAND, oToon, 0), iLevel, oToon);
    bodini_level_item(GetItemInEquipSlot(INVENTORY_SLOT_MAIN, oToon, 1), iLevel, oToon);
    bodini_level_item(GetItemInEquipSlot(INVENTORY_SLOT_OFFHAND, oToon, 1), iLevel, oToon);
    return;
}

void bodini_level_item(object oItem, int iLevel, object oToon)
{
    if(oItem == OBJECT_INVALID)
      return;
    int nItemType;
    int nMaterialProgression;
    int nCurMaterial = GetItemMaterialType(oItem);
    int nCurValue = GetItemValue(oItem);
    int nNewValue;
    int nColumn;
    int nRunes;
    int nMaterial;
    // set column based on level
    if(iLevel < 3) {
        nColumn = 2;
        nRunes = 0;
    } else if (iLevel < 6) {
        nColumn = 3;
        nRunes = 1;
    } else if (iLevel < 9) {
        nColumn = 4;
        nRunes = 2;
    } else if (iLevel < 12) {
        nColumn = 5;
        nRunes = 2;
    } else if (iLevel < 15) {
        nColumn = 6;
        nRunes = 3;
    } else {
        nColumn = 7;
        nRunes = 3;
    }
    nItemType = GetItemType(oItem);
    if ((nItemType == ITEM_TYPE_ARMOUR) || (nItemType == ITEM_TYPE_SHIELD) || (nItemType == ITEM_TYPE_WEAPON_MELEE) || (nItemType == ITEM_TYPE_WEAPON_RANGED))
    {
        nMaterialProgression = GetItemMaterialProgression(oItem);
        SetLocalInt(oItem, "ITEM_RUNE_ENABLED", nRunes);
        nMaterial = GetM2DAInt(TABLE_MATERIAL, "Material" + ToString(nColumn), nMaterialProgression);
        SetItemMaterialType(oItem, nMaterial);
        // make sure we didn't downgrade an item.
        nNewValue = GetItemValue(oItem);
        if(nNewValue < nCurValue)
            SetItemMaterialType(oItem, nCurMaterial);
        // make sure we can still use the item.
        while(CanUseItem(oToon, oItem) == FALSE && nColumn > 0)
        {
            nColumn--;
            nMaterial = GetM2DAInt(TABLE_MATERIAL, "Material" + ToString(nColumn), nMaterialProgression);
            SetItemMaterialType(oItem, nMaterial);
        }
    }
}