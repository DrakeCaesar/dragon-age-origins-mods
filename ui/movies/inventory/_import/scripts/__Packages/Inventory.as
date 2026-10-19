class Inventory
{
   var SetText;
   var AddBehaviour;
   var IsDropAcceptable;
   var AcceptDrop;
   var IsExternalDropAcceptable;
   var AcceptExternalDrop;
   var MessageHandlerToken;
   var TooltipType;
   var HostAnchor;
   var TooltipAnchor;
   var TooltipSource;
   var m_nSoundType;
   var OnButtonAction;
   var SetEquipSlotID;
   var bUseCustomNavTargets;
   var NavDownTarget;
   var _parent;
   var NavRightTarget;
   var OnAction;
   var NavUpTarget;
   var NavLeftTarget;
   static var aCategoryNames;
   static var ms_mcFullOverlayController;
   static var CATEGORY_ALL = 0;
   static var CATEGORY_WEAPONS = 1;
   static var CATEGORY_ARMOR = 2;
   static var CATEGORY_ACCESSORIES = 3;
   static var CATEGORY_OTHER = 4;
   static var CATEGORY_CRAFTING = 5;
   static var CATEGORY_PLOT = 6;
   static var NUM_ITEM_CATEGORIES = 7;
   static var ShowContainer = false;
   static var ContainerHasPlotItems = false;
   static var CanAddItemsToContainer = false;
   static var ms_mcEquipment = null;
   static var ms_nEquipSlotHighlight = -1;
   static var ms_nFullOverlayIntervalID = 0;
   static var NUM_ATTRIBUTES = 6;
   // Four observer ids per row: one per number column, so every field watches
   // its own leaf token. Watching the parent "GUI.SelectedChar" token does not
   // fire when only its children change, so equipment never refreshed the rows.
   static var ATTRIBUTE_OBSERVER_BASE = 63000;
   static var ATTRIBUTE_ROW_DEPTH = 1;
   // The panel art runs to the edge of the movie's 1024x768 stage, so anything
   // "beside" it has to sit past the stage edge: the game scales the stage by
   // height and centres it, which leaves that margin of screen visible.
   static var ATTRIBUTE_BLOCK_DEPTH = 6000;
   static var ATTRIBUTE_BLOCK_X = 984;
   static var ATTRIBUTE_BLOCK_Y = 271;
   // Names that read better spelled out than abbreviated; everything else follows
   // the three-letter rule below.
   static var LABEL_OVERRIDES = {Fire:"Fire",Cunning:"Cun"};
   static var RESISTANCE_UIMAPPING = 1;
   static var ELEMENTAL_RESISTANCE_UIMAPPING = 3;
   // properties.2da has an unused row 0, so the six attributes are 1..6.
   static var ATTRIBUTE_FIRST_PROPERTY = 1;
   // The stat field's inner text field is 60 pixels wide, so a column is
   // placed by the position of its right edge. The SWF's placement data is
   // in twips, but ActionScript's _x/_y are pixels.
   static var ATTRIBUTE_FIELD_WIDTH = 60;
   static var ATTRIBUTE_FIELD_HEIGHT = 20;
   static var ATTRIBUTE_TEXT_INSET = 2;
   static var ATTRIBUTE_ROW_TOP = 0;
   static var ATTRIBUTE_ROW_HEIGHT = 17;
   static var ATTRIBUTE_RESISTANCE_GAP = 9;
   static var ATTRIBUTE_LABEL_X = 2;
   static var ATTRIBUTE_LABEL_WIDTH = 46;
   static var ATTRIBUTE_TOTAL_RIGHT = 66;
   static var ATTRIBUTE_BASE_RIGHT = 84;
   static var ATTRIBUTE_MODIFIER_RIGHT = 102;
   function Inventory()
   {
   }
   static function ShortLabel(a_sLabel)
   {
      // Three letters is the usual abbreviation, but a fourth is kept when it is a
      // consonant: "Str" but "Dext", "Will", "Cons".
      if(a_sLabel == null)
      {
         return a_sLabel;
      }
      var sOverride = Inventory.LABEL_OVERRIDES[a_sLabel];
      if(sOverride != undefined)
      {
         return sOverride;
      }
      if(a_sLabel.length <= 4)
      {
         return a_sLabel;
      }
      var sFourth = a_sLabel.substr(3,1).toLowerCase();
      var bVowel = sFourth == "a" || sFourth == "e" || sFourth == "i" || sFourth == "o" || sFourth == "u";
      return a_sLabel.substr(0,bVowel ? 3 : 4);
   }
   static function BuildAttributeRowList()
   {
      var aRows = new Array();
      var nRow = 0;
      while(nRow < Inventory.NUM_ATTRIBUTES)
      {
         aRows.push(Inventory.ATTRIBUTE_FIRST_PROPERTY + nRow);
         nRow = nRow + 1;
      }
      // The resistances are found the way the character record finds them: rows of
      // properties.2da whose UI mapping marks them as a resistance.
      var nProperties = Number(ExternalCommands.GetNum2DARows(_2DA.TABLE_PROPERTIES));
      var nProperty = 1;
      while(nProperty < nProperties)
      {
         var nMapping = Number(ExternalCommands.Get2DAValueByRowIndexColumnHash(_2DA.TABLE_PROPERTIES,nProperty,_2DA.HASH_UIMAPPING));
         if(nMapping == Inventory.RESISTANCE_UIMAPPING || nMapping == Inventory.ELEMENTAL_RESISTANCE_UIMAPPING)
         {
            aRows.push(nProperty);
         }
         nProperty = nProperty + 1;
      }
      return aRows;
   }
   static function AddAttributeRows()
   {
      if(_root.AttributeBlock_mc != undefined)
      {
         return;
      }
      var mcStats = _root.createEmptyMovieClip("AttributeBlock_mc",Inventory.ATTRIBUTE_BLOCK_DEPTH);
      mcStats._x = Inventory.ATTRIBUTE_BLOCK_X;
      mcStats._y = Inventory.ATTRIBUTE_BLOCK_Y;
      var aRows = Inventory.BuildAttributeRowList();
      mcStats.AttributeRows = new Array();
      var nY = Inventory.ATTRIBUTE_ROW_TOP;
      var nRow = 0;
      while(nRow < aRows.length)
      {
         if(nRow == Inventory.NUM_ATTRIBUTES)
         {
            nY = nY + Inventory.ATTRIBUTE_RESISTANCE_GAP;
         }
         var nDepth = Inventory.ATTRIBUTE_ROW_DEPTH + nRow * 4;
         // Each part of a row is its own text field so the three number columns
         // keep a fixed right edge even though the values differ in width.
         var mcLabel = Inventory.MakeAttributeColumn(mcStats,"AttributeLabel" + nRow,nDepth,Inventory.ATTRIBUTE_LABEL_X,nY,false);
         var mcTotal = Inventory.MakeAttributeColumn(mcStats,"AttributeTotal" + nRow,nDepth + 1,Inventory.ATTRIBUTE_TOTAL_RIGHT,nY,true);
         var mcBase = Inventory.MakeAttributeColumn(mcStats,"AttributeBase" + nRow,nDepth + 2,Inventory.ATTRIBUTE_BASE_RIGHT,nY,true);
         var mcModifier = Inventory.MakeAttributeColumn(mcStats,"AttributeModifier" + nRow,nDepth + 3,Inventory.ATTRIBUTE_MODIFIER_RIGHT,nY,true);
         Inventory.SetAttributeText(mcLabel,Inventory.ShortLabel(CreatureUtils.LabelForProperty(aRows[nRow])),false);
         Inventory.ObserveAttributeRow(nRow,aRows[nRow],mcTotal,mcBase,mcModifier);
         mcStats.AttributeRows.push({property:aRows[nRow],total:mcTotal,base:mcBase,modifier:mcModifier});
         nY = nY + Inventory.ATTRIBUTE_ROW_HEIGHT;
         nRow = nRow + 1;
      }
      Inventory.UpdateAttributeRows();
   }
   static function ObserveAttributeRow(a_nRow, a_nProperty, a_mcTotal, a_mcBase, a_mcModifier)
   {
      // Each field watches its own leaf token and takes the value handed to the
      // callback, the way the paperdoll's own rows do: reading a token back inside
      // a notification re-enters the token evaluation.
      var nID = Inventory.ATTRIBUTE_OBSERVER_BASE + a_nRow * 4;
      var sToken = "GUI.SelectedChar.Attributes." + a_nProperty;
      TokenManager.AddTokenObserverWithID(nID + 1,sToken + ".Total",function(a_vValue)
      {
         Inventory.SetAttributeText(a_mcTotal,CreatureUtils.FormatPrecisionByProperty(Number(a_vValue),a_nProperty),true);
      }
      );
      TokenManager.AddTokenObserverWithID(nID + 2,sToken + ".Base",function(a_vValue)
      {
         Inventory.SetAttributeText(a_mcBase,CreatureUtils.FormatPrecisionByProperty(Number(a_vValue),a_nProperty),true);
      }
      );
      TokenManager.AddTokenObserverWithID(nID + 3,sToken + ".Modifier",function(a_vValue)
      {
         Inventory.SetModifierText(a_mcModifier,Number(a_vValue));
      }
      );
   }
   static function SetModifierText(a_mcField, a_nModifier)
   {
      var sPrefix = "";
      var sSuffix = "";
      var sSign = "+";
      if(a_nModifier < 0)
      {
         sPrefix = SharedLibrary.CoreStats.NegativeColorPrefix();
         sSuffix = SharedLibrary.CoreStats.ColorSuffix();
         sSign = "-";
      }
      else if(a_nModifier > 0)
      {
         sPrefix = SharedLibrary.CoreStats.PositiveColorPrefix();
         sSuffix = SharedLibrary.CoreStats.ColorSuffix();
      }
      Inventory.SetAttributeText(a_mcField,sPrefix + sSign + Math.abs(a_nModifier) + sSuffix,true);
   }
   static function MakeAttributeColumn(a_mcParent, a_sName, a_nDepth, a_nX, a_nY, a_bRightAligned)
   {
      // A plain engine text field, not an instance of the paperdoll's stat symbol:
      // that symbol is a SharedLibrary.TextField element, so every attached copy
      // runs the movie's element framework (init lookup, OnAdded, parent
      // ChildAdded) and that is what sent the game into a stack overflow.
      var nWidth = a_bRightAligned ? Inventory.ATTRIBUTE_FIELD_WIDTH : Inventory.ATTRIBUTE_LABEL_WIDTH;
      var mcField = a_mcParent.createTextField(a_sName,a_nDepth,a_bRightAligned ? a_nX - nWidth : a_nX,a_nY + Inventory.ATTRIBUTE_TEXT_INSET,nWidth,Inventory.ATTRIBUTE_FIELD_HEIGHT);
      mcField.html = true;
      mcField.multiline = false;
      mcField.wordWrap = false;
      mcField.selectable = false;
      return mcField;
   }
   static function SetAttributeText(a_mcField, a_sText, a_bRightAligned)
   {
      // Same markup the paperdoll's own rows use, so the rows look native.
      a_mcField.htmlText = "<p align=\"" + (a_bRightAligned ? "right" : "left") + "\"><font face=\"$BodyFont\" size=\"12\" color=\"#ffffff\">" + a_sText + "</font></p>";
   }
   static function RemoveAttributeRows()
   {
      if(_root.AttributeBlock_mc == undefined)
      {
         return;
      }
      _root.AttributeBlock_mc.removeMovieClip();
   }
   static function UpdateAttributeRows()
   {
      var mcStats = _root.AttributeBlock_mc;
      if(mcStats == undefined || mcStats.AttributeRows == undefined)
      {
         return;
      }
      var nRow = 0;
      while(nRow < mcStats.AttributeRows.length)
      {
         var oRow = mcStats.AttributeRows[nRow];
         var sToken = "GUI.SelectedChar.Attributes." + oRow.property;
         Inventory.SetAttributeText(oRow.total,CreatureUtils.FormatPrecisionByProperty(Number(ExternalCommands.GetValue(sToken + ".Total")),oRow.property),true);
         Inventory.SetAttributeText(oRow.base,CreatureUtils.FormatPrecisionByProperty(Number(ExternalCommands.GetValue(sToken + ".Base")),oRow.property),true);
         Inventory.SetModifierText(oRow.modifier,Number(ExternalCommands.GetValue(sToken + ".Modifier")));
         nRow = nRow + 1;
      }
   }
   static function StartScene()
   {
      if(GUISystem.RunningInGame == false)
      {
         ExternalCommands.GetNumMembers = function(x)
         {
            return 25;
         };
         ExternalCommands.GetValue = function(x)
         {
            return x;
         };
      }
      Inventory.aCategoryNames = Array(Localization.Strings.LOC_CATEGORY_ALL,Localization.Strings.LOC_CATEGORY_WEAPONS,Localization.Strings.LOC_CATEGORY_ARMOR,Localization.Strings.LOC_CATEGORY_ACCESSORIES,Localization.Strings.LOC_CATEGORY_OTHER,Localization.Strings.LOC_CATEGORY_CRAFTING,Localization.Strings.LOC_CATEGORY_PLOT);
      Inventory.SetupInitFunctions();
      Inventory.AddAttributeRows();
      ContextSystem.CreateContext("Inventory");
      ContextSystem.CreateContext("PaperDoll");
      ContextSystem.CreateContext("SelectInventoryItemForEquipSlot");
      ContextSystem.CreateContext("PlaceItemIntoEquipmentSlot");
      ContextSystem.CreateContext("WeaponSetSelector");
      ContextSystem.CreateContext("BrowsePlotItems");
      ContextSystem.CreateContext("BrowseInventory");
      ContextSystem.SETUP_FOCUS_MANAGER_INPUTS_INVENTORY("Inventory");
      ContextSystem.SETUP_FOCUS_MANAGER_INPUTS_SELECT_EQUIP_SLOT_ITEM_FROM_INVENTORY("SelectInventoryItemForEquipSlot");
      ContextSystem.SETUP_FOCUS_MANAGER_INPUTS_PLACE_ITEM_INTO_EQUIPMENT_SLOT("PlaceItemIntoEquipmentSlot");
      ContextSystem.SETUP_FOCUS_MANAGER_INPUTS_PAPER_DOLL("PaperDoll");
      ContextSystem.SETUP_FOCUS_MANAGER_INPUTS_WEAPON_SET_SELECTOR("WeaponSetSelector");
      ContextSystem.SETUP_FOCUS_MANAGER_INPUTS_BROWSE_PLOT_ITEMS("BrowsePlotItems");
      ContextSystem.SETUP_FOCUS_MANAGER_INPUTS_BROWSE_INVENTORY("BrowseInventory");
      MovieUtils.HideMovie(_root.EquipmentHighlight_mc);
      MovieUtils.HideMovie(_root.ItemListHighlight_mc);
      MovieUtils.HideMovie(_root.WeaponSetHighlight_mc);
      Inventory.ShowContainer = Number(ExternalCommands.GetValue("GUIInventory.ShowContainer")) != 0;
      Inventory.ContainerHasPlotItems = Number(ExternalCommands.GetValue("GUIInventory.ContainerHasPlotItems")) != 0;
      Inventory.CanAddItemsToContainer = Number(ExternalCommands.GetValue("GUIInventory.CanAddItemsToContainer")) != 0;
      if(Inventory.ShowContainer)
      {
         ExternalCommands.PlayGUISound(SoundEvents.ST_OPEN_CONTAINER);
         SharedLibrary.BookContents.SetupShowContents("container_intro","container");
      }
      else
      {
         SharedLibrary.BookContents.SetupShowContents("equipment_intro","equipment");
      }
      _root.ExperienceLabel_mc_init = function()
      {
         this.SetText(Localization.Strings.LOC_XP);
      };
      _root.Black_mc_init = function()
      {
         this.AddBehaviour(Behaviour.ScaleToScreen);
         MovieUtils.BlockInput(this);
         MovieUtils.HideMovie(this);
      };
      _root.RuneTooltip_mc_init = function()
      {
         MovieUtils.HideMovie(this);
      };
      _root.ItemCategoryTooltip_mc_init = function()
      {
         MovieUtils.HideMovie(this);
      };
      ExternalCommands.AdvanceFrame();
      if(Inventory.ShowContainer == false)
      {
         ExternalCommands.PlayGUISound(SoundEvents.ST_OPEN_BOOK);
      }
      _root.IconDestroyDropTarget_mc_init = function()
      {
         this.AddBehaviour(Behaviour.ScaleToScreen);
         this.IsDropAcceptable = function()
         {
            var _loc2_ = Mouse.getTopMostEntity();
            return _loc2_ == this;
         };
         this.AcceptDrop = function(a_ObjectData)
         {
            if(a_ObjectData.IsIndestructible == false)
            {
               ItemUtils.PromptDestroyItem(a_ObjectData.Item,a_ObjectData.ObjectID);
            }
         };
         this.IsExternalDropAcceptable = function()
         {
            var _loc2_ = Mouse.getTopMostEntity();
            return _loc2_ == this;
         };
         this.AcceptExternalDrop = function(a_sDragDataToken)
         {
            var _loc1_ = ExternalCommands.GetNumber(a_sDragDataToken + ".ObjectID");
            var _loc2_ = ExternalCommands.GetBool(a_sDragDataToken + ".Indestructible");
            if(_loc2_ == false)
            {
               ItemUtils.PromptDestroyItem(null,_loc1_);
            }
         };
      };
      _root.ItemSortPicker_mc_init = function()
      {
         this.MessageHandlerToken = "GUIInventory";
      };
      TokenManager.AddTokenObserverWithID(_OBSERVER_ID.INVENTORY_HIGHLIGHT_EQUIP_SLOT,"GUI.GuiHighlights." + DAConstants.GUI_HIGHLIGHT_EQUIPMENT_SLOT + ".Highlight",function(a_nHighlight)
      {
         Inventory.UpdateEquipSlotHighlight(a_nHighlight != 0);
      }
      );
   }
   static function FinishScene()
   {
      // The rows live on _root rather than in the scene's own timeline, so they
      // have to be taken down with the scene or they would hang over the game.
      Inventory.RemoveAttributeRows();
      var _loc1_ = ExternalCommands.GetValue("GameMode.CloseSceneCompletely");
      if(Boolean(Number(_loc1_)) == true || _loc1_ == null)
      {
         ExternalCommands.PlayGUISound(SoundEvents.ST_CLOSE_BOOK);
      }
   }
   static function StartScene_Default()
   {
      ContextSystem.PushContext("Inventory");
      var _loc2_ = new GUI.FocusContainer.ListContainer();
      FocusManager.AddContainer(_root,_loc2_);
      ExternalCommands.SetValue("GUI.SelectedBookPage",GUISystem.GUI_INVENTORY);
   }
   static function FinishScene_Default()
   {
      ContextSystem.PopContext("Inventory");
      if(ExternalCommands.GetValue("GUI.SelectedBookPage") == GUISystem.GUI_INVENTORY)
      {
         ExternalCommands.SetValue("GUI.SelectedBookPage",-1);
      }
   }
   static function OutroScene()
   {
   }
   static function TogglePlotItems()
   {
      _root.PlotItemsToggle.ToggleSelectedState();
   }
   static function FocusOnEquipment()
   {
      if(GUISystem.Platform != "PC")
      {
         MovieUtils.ShowMovie(_root.EquipmentHighlight_mc);
         MovieUtils.HideMovie(_root.ItemListHighlight_mc);
         MovieUtils.HideMovie(_root.WeaponSetHighlight_mc);
      }
   }
   static function FocusOnItemList()
   {
      if(GUISystem.Platform != "PC")
      {
         MovieUtils.HideMovie(_root.EquipmentHighlight_mc);
         MovieUtils.ShowMovie(_root.ItemListHighlight_mc);
         MovieUtils.HideMovie(_root.WeaponSetHighlight_mc);
      }
   }
   static function FocusOnWeaponSet()
   {
      if(GUISystem.Platform != "PC")
      {
         MovieUtils.HideMovie(_root.EquipmentHighlight_mc);
         MovieUtils.HideMovie(_root.ItemListHighlight_mc);
         MovieUtils.ShowMovie(_root.WeaponSetHighlight_mc);
      }
   }
   static function SetupInitFunctions()
   {
      _root.Scrollable_mc_init = function()
      {
      };
      _root.PlayerName_mc_init = function()
      {
         var mcName = this;
         TokenManager.AddTokenObserverWithID(_OBSERVER_ID.INVENTORY_PLAYERNAME,"GUI.SelectedChar.Name",function(a_sName)
         {
            mcName.SetText(a_sName);
         }
         );
      };
      _root.CloseButton_init = function()
      {
         this.AddBehaviour(Behaviour.DisplayTooltip);
         this.TooltipType = Behaviour.DisplayTooltip.TOOLTIP_TYPE_SIMPLE_FLOATING;
         this.HostAnchor = Behaviour.DisplayTooltip.ANCHOR_TOP;
         this.TooltipAnchor = Behaviour.DisplayTooltip.ANCHOR_BOTTOM;
         this.TooltipSource = Localization.Strings.LOC_CLOSE;
         this.m_nSoundType = SoundEvents.ST_NONE;
         this.OnButtonAction = function()
         {
            ExternalCommands.SendMessageArgs("GUI.HideFullScreenGUI");
         };
      };
      Inventory.SetupEquipmentSlots();
      _root.ItemCategories_mc_init = function()
      {
         var _loc5_ = this;
         var _loc3_ = 0;
         var _loc4_;
         while(_loc3_ < Inventory.NUM_ITEM_CATEGORIES)
         {
            _loc4_ = _loc5_["icon" + _loc3_];
            _loc4_.nIndex = _loc3_;
            _loc4_.sName = Inventory.aCategoryNames[_loc3_];
            _loc4_.mControlledList = _root.InventoryContents_mc.Scrollable_mc;
            if(Inventory.ContainerHasPlotItems && _loc3_ == Inventory.CATEGORY_PLOT)
            {
               _loc4_.SetSelected = true;
            }
            else if(!Inventory.ContainerHasPlotItems && _loc3_ == Inventory.CATEGORY_ALL)
            {
               _loc4_.SetSelected = true;
            }
            _loc3_ = _loc3_ + 1;
         }
      };
      _root.Money_mc_init = function()
      {
         var field = this;
         TokenManager.AddTokenObserverWithID(_OBSERVER_ID.INVENTORY_GOLD,"Party.Money.Total",function(sTotal)
         {
            field.SetText(ItemUtils.FormatMoneyString(Number(sTotal)));
            trace(ItemUtils.FormatMoneyString(Number(sTotal)));
         }
         );
      };
      _root.Capacity_mc_init = function()
      {
         var _capacity = this;
         this.AddBehaviour(Behaviour.DisplayTooltip);
         this.TooltipType = Behaviour.DisplayTooltip.TOOLTIP_TYPE_SIMPLE_FLOATING;
         this.HostAnchor = Behaviour.DisplayTooltip.ANCHOR_TOP;
         this.TooltipAnchor = Behaviour.DisplayTooltip.ANCHOR_BOTTOM;
         this.TooltipSource = Localization.Strings.LOC_CAPACITY;
         TokenManager.AddTokenObserverWithID(_OBSERVER_ID.INVENTORY_BACKPACKSIZE,"Party.BackpackSize",function()
         {
            Inventory.UpdateCapacity(_capacity);
         }
         );
         TokenManager.AddTokenObserverWithID(_OBSERVER_ID.INVENTORY_BACKPACKMAXSIZE,"Party.BackpackMaxSize",function()
         {
            Inventory.UpdateCapacity(_capacity);
         }
         );
      };
      _root.FullOverlay_mc_init = function()
      {
         Inventory.ms_mcFullOverlayController = new DataType.MovieController(this);
      };
      _root.Equipment_mc_init = function()
      {
         Inventory.ms_mcEquipment = this;
         TokenManager.AddTokenObserverWithID(_OBSERVER_ID.EQUIPMENT_LAYOUT,"GUI.SelectedChar.EquipmentLayout",function(v)
         {
            Inventory.UpdateEquipmentLayout(Inventory.ms_mcEquipment,v);
         }
         );
      };
      _root.WeaponSetToggleButton_mc_init = function()
      {
         var button = this;
         TokenManager.AddTokenObserverWithID(_OBSERVER_ID.INVENTORY_CANCHANGEEQUIPMENT,"SelectedChar.CanChangeEquipment",function()
         {
            Inventory.UpdateWeaponSetToggleButton(button);
         }
         );
         TokenManager.AddTokenObserverWithID(_OBSERVER_ID.INVENTORY_CANSWITCHWEAPONS,"SelectedChar.CanSwitchWeaponSets",function()
         {
            Inventory.UpdateWeaponSetToggleButton(button);
         }
         );
      };
   }
   static function UpdateWeaponSetToggleButton(a_mcButton)
   {
      if(Number(ExternalCommands.GetValue("SelectedChar.CanChangeEquipment")) == 1 && Number(ExternalCommands.GetValue("SelectedChar.CanSwitchWeaponSets")) == 1)
      {
         a_mcButton.Enable();
      }
      else
      {
         a_mcButton.Disable();
      }
   }
   static function UpdateEquipmentLayout(a_mcEquipment, a_nEquipmentLayout)
   {
      if(a_nEquipmentLayout == GUISystem.EQUIPMENT_LAYOUT_SHALE)
      {
         MovieUtils.HideMovie(a_mcEquipment.WeaponSetToggleButton_mc);
         MovieUtils.HideMovie(a_mcEquipment.InventorySlots_mc);
         MovieUtils.ShowMovie(a_mcEquipment.InventorySlotsShale_mc);
         MovieUtils.HideMovie(a_mcEquipment.InventorySlotsDog_mc);
      }
      else if(a_nEquipmentLayout == GUISystem.EQUIPMENT_LAYOUT_DOG)
      {
         MovieUtils.HideMovie(a_mcEquipment.WeaponSetToggleButton_mc);
         MovieUtils.HideMovie(a_mcEquipment.InventorySlots_mc);
         MovieUtils.HideMovie(a_mcEquipment.InventorySlotsShale_mc);
         MovieUtils.ShowMovie(a_mcEquipment.InventorySlotsDog_mc);
      }
      else
      {
         MovieUtils.ShowMovie(a_mcEquipment.WeaponSetToggleButton_mc);
         MovieUtils.ShowMovie(a_mcEquipment.InventorySlots_mc);
         MovieUtils.HideMovie(a_mcEquipment.InventorySlotsShale_mc);
         MovieUtils.HideMovie(a_mcEquipment.InventorySlotsDog_mc);
      }
   }
   static function UpdateCapacity(a_mcCapacity)
   {
      var _loc2_ = Number(ExternalCommands.GetValue("Party.BackpackSize"));
      var _loc1_ = Number(ExternalCommands.GetValue("Party.BackpackMaxSize"));
      a_mcCapacity.CapacityNumber_mc.SetText(_loc2_ + " / " + _loc1_);
      var _loc4_ = _loc2_ / _loc1_;
      a_mcCapacity.gotoAndStop(_loc4_ * a_mcCapacity._totalframes);
   }
   static function SetupEquipmentSlots()
   {
      _root.SlotWeapon1_mc_init = function()
      {
         this.SetEquipSlotID(0);
         this.bUseCustomNavTargets = true;
         this.NavDownTarget = this._parent.SlotHelm_mc;
         this.NavRightTarget = this._parent.SlotWeapon2_mc;
         this.OnAction = FuncUtils.Bind(this,Inventory.EquipSlotAction,this);
         if(GUISystem.InConsoleMode())
         {
            FocusManager.SetCurrentFocus(this);
         }
      };
      _root.SlotWeapon2_mc_init = function()
      {
         this.SetEquipSlotID(1);
         this.bUseCustomNavTargets = true;
         this.NavUpTarget = this._parent.SlotAmmo_mc;
         this.NavDownTarget = this._parent.SlotBelt_mc;
         this.NavLeftTarget = this._parent.SlotWeapon1_mc;
         this.OnAction = FuncUtils.Bind(this,Inventory.EquipSlotAction,this);
      };
      _root.SlotAmmo_mc_init = function()
      {
         this.SetEquipSlotID(2);
         this.bUseCustomNavTargets = true;
         this.NavDownTarget = this._parent.SlotWeapon2_mc;
      };
      _root.SlotArmor_mc_init = function()
      {
         this.SetEquipSlotID(4);
         this.bUseCustomNavTargets = true;
         this.NavUpTarget = this._parent.SlotGloves_mc;
         this.NavDownTarget = this._parent.SlotBoots_mc;
         this.NavRightTarget = this._parent.SlotRing1_mc;
         this.OnAction = FuncUtils.Bind(this,Inventory.EquipSlotAction,this);
      };
      _root.SlotHelm_mc_init = function()
      {
         this.SetEquipSlotID(5);
         this.bUseCustomNavTargets = true;
         this.NavUpTarget = this._parent.SlotWeapon1_mc;
         this.NavDownTarget = this._parent.SlotGloves_mc;
         this.NavRightTarget = this._parent.SlotBelt_mc;
         this.OnAction = FuncUtils.Bind(this,Inventory.EquipSlotAction,this);
      };
      _root.SlotBoots_mc_init = function()
      {
         this.SetEquipSlotID(6);
         this.bUseCustomNavTargets = true;
         this.NavUpTarget = this._parent.SlotArmor_mc;
         this.NavRightTarget = this._parent.SlotRing2_mc;
         this.OnAction = FuncUtils.Bind(this,Inventory.EquipSlotAction,this);
      };
      _root.SlotGloves_mc_init = function()
      {
         this.SetEquipSlotID(7);
         this.bUseCustomNavTargets = true;
         this.NavUpTarget = this._parent.SlotHelm_mc;
         this.NavDownTarget = this._parent.SlotArmor_mc;
         this.NavRightTarget = this._parent.SlotAmulet_mc;
         this.OnAction = FuncUtils.Bind(this,Inventory.EquipSlotAction,this);
      };
      _root.SlotRing1_mc_init = function()
      {
         this.SetEquipSlotID(9);
         this.bUseCustomNavTargets = true;
         this.NavUpTarget = this._parent.SlotAmulet_mc;
         this.NavDownTarget = this._parent.SlotRing2_mc;
         this.NavLeftTarget = this._parent.SlotArmor_mc;
         this.OnAction = FuncUtils.Bind(this,Inventory.EquipSlotAction,this);
      };
      _root.SlotRing2_mc_init = function()
      {
         this.SetEquipSlotID(10);
         this.bUseCustomNavTargets = true;
         this.NavUpTarget = this._parent.SlotRing1_mc;
         this.NavLeftTarget = this._parent.SlotBoots_mc;
         this.OnAction = FuncUtils.Bind(this,Inventory.EquipSlotAction,this);
      };
      _root.SlotAmulet_mc_init = function()
      {
         this.SetEquipSlotID(11);
         this.bUseCustomNavTargets = true;
         this.NavUpTarget = this._parent.SlotBelt_mc;
         this.NavDownTarget = this._parent.SlotRing1_mc;
         this.NavLeftTarget = this._parent.SlotGloves_mc;
         this.OnAction = FuncUtils.Bind(this,Inventory.EquipSlotAction,this);
      };
      _root.SlotBelt_mc_init = function()
      {
         this.SetEquipSlotID(12);
         this.bUseCustomNavTargets = true;
         this.NavUpTarget = this._parent.SlotWeapon2_mc;
         this.NavDownTarget = this._parent.SlotAmulet_mc;
         this.NavLeftTarget = this._parent.SlotHelm_mc;
         this.OnAction = FuncUtils.Bind(this,Inventory.EquipSlotAction,this);
      };
      _root.SlotShaleShoulders_mc_init = function()
      {
         this.SetEquipSlotID(14);
      };
      _root.SlotShaleChest_mc_init = function()
      {
         this.SetEquipSlotID(15);
      };
      _root.SlotShaleRightArm_mc_init = function()
      {
         this.SetEquipSlotID(16);
      };
      _root.SlotShaleLeftArm_mc_init = function()
      {
         this.SetEquipSlotID(17);
      };
      _root.SlotDogWarpaint_mc_init = function()
      {
         this.SetEquipSlotID(18);
      };
      _root.SlotDogCollar_mc_init = function()
      {
         this.SetEquipSlotID(19);
      };
   }
   static function EquipSlotAction(a_mcSlot, a_sAction)
   {
      var _loc3_;
      switch(a_sAction)
      {
         case "UnEquipItem":
            if(a_mcSlot.GetContainedItemID() != null)
            {
               ExternalCommands.SendMessage("GUI.SelectedChar.UnequipItem " + a_mcSlot.GetContainedItemID());
            }
            return true;
         case "EquipItem":
            _root.InventoryContents_mc.Scrollable_mc.SetFilterSlot(a_mcSlot);
            _loc3_ = _root.InventoryContents_mc.Scrollable_mc.GetItemCount();
            if(_loc3_ == 0)
            {
               return true;
            }
            ContextSystem.PushContext("SelectInventoryItemForEquipSlot");
            FocusManager.GetFocusContainer(a_mcSlot).enabled = false;
            FocusManager.GetFocusContainer(_root.WeaponSets_mc).enabled = false;
            FocusManager.GetFocusContainer(_root.InventoryContents_mc.Scrollable_mc).enabled = true;
            FocusManager.SetCurrentFocus(_root.InventoryContents_mc.Scrollable_mc);
            return true;
            break;
         case "Cancel":
            return true;
         default:
            return false;
      }
   }
   static function ShowFullOverlay(a_sMessage)
   {
      ExternalCommands.PlayGUISound(SoundEvents.ST_INVENTORY_FULL);
      Inventory.ms_mcFullOverlayController.PlayForward();
   }
   static function HideFullOverlay()
   {
      clearInterval(Inventory.ms_nFullOverlayIntervalID);
      Inventory.ms_mcFullOverlayController.PlayBackward();
   }
   static function FlashFullOverlay(a_sMessage)
   {
      Inventory.ShowFullOverlay(a_sMessage);
      clearInterval(Inventory.ms_nFullOverlayIntervalID);
      Inventory.ms_nFullOverlayIntervalID = setInterval(Inventory.HideFullOverlay,1500);
   }
   static function UpdateEquipSlotHighlight(a_bHighlight)
   {
      var _loc1_;
      if(Inventory.ms_nEquipSlotHighlight != -1)
      {
         _loc1_ = Inventory.GetEquipSlotBySlotID(Inventory.ms_nEquipSlotHighlight);
         if(_loc1_ != null)
         {
            _loc1_.UnHighlight();
         }
         Inventory.ms_nEquipSlotHighlight = -1;
      }
      if(a_bHighlight)
      {
         Inventory.ms_nEquipSlotHighlight = ExternalCommands.GetNumber("GUI.GuiHighlights." + DAConstants.GUI_HIGHLIGHT_EQUIPMENT_SLOT + ".HighlightArg");
         _loc1_ = Inventory.GetEquipSlotBySlotID(Inventory.ms_nEquipSlotHighlight);
         if(_loc1_ != null)
         {
            _loc1_.Highlight();
         }
      }
   }
   static function GetEquipSlotBySlotID(a_nSlotID)
   {
      var _loc3_ = null;
      var _loc2_ = Inventory.ms_mcEquipment.InventorySlots_mc.GetChildren();
      var _loc1_ = 0;
      while(_loc1_ < _loc2_.length)
      {
         if(_loc2_[_loc1_].m_nSlotID == a_nSlotID)
         {
            _loc3_ = _loc2_[_loc1_];
            break;
         }
         _loc1_ = _loc1_ + 1;
      }
      return _loc3_;
   }
}
