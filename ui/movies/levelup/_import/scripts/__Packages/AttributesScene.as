class AttributesScene
{
   var AddBehaviour;
   var Image_mc;
   var OnButtonAction;
   var SetText;
   var Spacing;
   var attrib_modifier_mc_init;
   var header_txt_mc_init;
   var next_mc_init;
   var pointsleft_mc_init;
   var previous_mc_init;
   static var m_aAttributes;
   static var m_aSeedAttributes;
   static var mcDescription;
   static var mcDescriptionHeader;
   static var ATTRIBUTES_BEGIN = 1;
   static var ATTRIBUTES_END = 6;
   static var ATTRIBUTE_NAME_HASH = 2972972793;
   static var ATTRIBUTE_DESCRIPTION_HASH = 898872317;
   static var ATTRIBUTE_TOOLSET_NAME_HASH = 3450871232;
   static var NewAttributePoints = 3;
   static var AttributePointsToSpend = -1;
   static var SELECT_ATTRIBUTE_STRREF = 239724;
   static var m_bPointsReadIn = false;
   static var bLevelUp = false;
   // true  : refundable floor is 10 + race + class, i.e. the character's real
   //         starting values, so nothing the player never spent comes back.
   // false : floor is a flat 10 on every attribute, letting you rebuild from
   //         scratch. Costs a debug point per attribute on most characters.
   static var UseStartingValueFloor = false;
   static var parentClass = null;
   static var m_mcNextButton = null;
   function AttributesScene()
   {
   }
   static function Initialize(levelUp, parent)
   {
      AttributesScene.bLevelUp = levelUp;
      AttributesScene.parentClass = parent;
      AttributesScene.m_aAttributes = new Array();
      AttributesScene.m_aSeedAttributes = new Array();
      var _loc3_ = AttributesScene.ATTRIBUTES_BEGIN;
      while(_loc3_ <= AttributesScene.ATTRIBUTES_END)
      {
         AttributesScene.m_aAttributes[_loc3_] = 0;
         AttributesScene.m_aSeedAttributes[_loc3_] = 0;
         _loc3_ = _loc3_ + 1;
      }
      if(levelUp)
      {
         AttributesScene.SeedExistingAllocations();
      }
      _root.PortraitPicture_mc_init = function()
      {
         var _loc2_ = ExternalCommands.GetValue("CharGenCreature.Portrait");
         MovieUtils.LoadImageFixedSize(this.Image_mc,_loc2_,146,146);
      };
      _root.PortraitBg_mc_init = function()
      {
         var self = this;
         var _loc2_ = "Paperdoll.PaperCreature";
         if(ExternalCommands.GetValue(_loc2_ + ".PortraitProperties.PortraitTint") == undefined)
         {
            _loc2_ = "CharGenCreature";
         }
         TokenManager.AddTokenObserverWithID(_OBSERVER_ID.PORTRAIT_TINT,_loc2_ + ".PortraitProperties.PortraitTint",function(a_nTintIndex)
         {
            self.gotoAndStop(a_nTintIndex);
         }
         );
      };
      _root.points_available_label_mc_init = function()
      {
         this.SetText(Localization.Strings.LOC_POINTS_TO_SPEND);
      };
      _root.attribute_description_header_mc_init = function()
      {
         this.SetText(Localization.Strings.LOC_ATTRIBUTES);
         AttributesScene.mcDescriptionHeader = this;
      };
      _root.attribute_description_mc_init = function()
      {
         this.SetText(ExternalCommands.GetTlkString(AttributesScene.SELECT_ATTRIBUTE_STRREF));
         AttributesScene.mcDescription = this;
      };
      _root.Attributes_header_mc_init = function()
      {
         this.header_txt_mc_init = function()
         {
            this.SetText(Localization.Strings.LOC_HEADER_ATTRIBUTES);
         };
      };
      _root.attributes_nav_mc_init = function()
      {
         if(!AttributesScene.bLevelUp)
         {
            this.previous_mc_init = function()
            {
               this.SetText(Localization.Strings.LOC_PREVIOUS);
               this.OnButtonAction = function()
               {
                  CharGen.GoingForward = false;
                  AttributesScene.SkipScene();
               };
            };
            this.next_mc_init = function()
            {
               this.SetText(Localization.Strings.LOC_NEXT);
               AttributesScene.m_mcNextButton = this;
               AttributesScene.CheckNextButtonEnable();
               this.OnButtonAction = function()
               {
                  CharGen.GoingForward = true;
                  AttributesScene.SkipScene();
               };
            };
         }
         else
         {
            this.previous_mc_init = function()
            {
               this.SetText(Localization.Strings.LOC_RESET);
               this.OnButtonAction = function()
               {
                  // Revert EVERYTHING, not just specializations and
                  // attributes. Reverting a subset can leave the character
                  // inconsistent: lowering an attribute back while a talent
                  // learned this session still requires the higher value, or
                  // dropping a specialization whose talents were just picked.
                  // A full revert lands on exactly the state the screen was
                  // opened in, which is valid by construction.
                  LevelUp.RevertAllChanges();
               };
            };
            this.next_mc_init = function()
            {
               this.SetText(Localization.Strings.LOC_NEXT);
               AttributesScene.m_mcNextButton = this;
               AttributesScene.CheckNextButtonEnable();
               this.OnButtonAction = function()
               {
                  LevelUp.GoingForward = true;
                  AttributesScene.SkipScene();
               };
            };
         }
      };
      _root.AttributeList_mc_init = function()
      {
         this.AddBehaviour(Behaviour.ListLayout);
         if(!AttributesScene.bLevelUp)
         {
            this.Spacing = 2;
         }
         else
         {
            this.Spacing = 10;
         }
         var _loc3_ = AttributesScene.ATTRIBUTES_BEGIN;
         var _loc10_;
         var _loc5_;
         var _loc9_;
         var _loc4_;
         var _loc6_;
         var _loc7_;
         var _loc11_;
         while(_loc3_ <= AttributesScene.ATTRIBUTES_END)
         {
            _loc5_ = Number(ExternalCommands.Get2DAValue(_2DA.TABLE_PROPERTIES,_loc3_,AttributesScene.ATTRIBUTE_NAME_HASH));
            if(_loc5_ == 0)
            {
               _loc10_ = ExternalCommands.Get2DAValue(_2DA.TABLE_PROPERTIES,_loc3_,AttributesScene.ATTRIBUTE_TOOLSET_NAME_HASH);
            }
            else
            {
               _loc10_ = ExternalCommands.GetTlkString(_loc5_);
            }
            _loc4_ = Number(ExternalCommands.Get2DAValue(_2DA.TABLE_PROPERTIES,_loc3_,AttributesScene.ATTRIBUTE_DESCRIPTION_HASH));
            if(_loc4_ == 0)
            {
               _loc9_ = _loc10_ + " description unavailable";
            }
            else
            {
               _loc9_ = ExternalCommands.GetTlkString(_loc4_);
            }
            _loc6_ = Number(ExternalCommands.GetValue("CharGenCreature.Attributes." + _loc3_ + ".Total"));
            _loc7_ = Number(ExternalCommands.GetValue("CharGenCreature.Attributes." + _loc3_ + ".Modifier"));
            _loc11_ = _loc6_ - _loc7_;
            _root.content_attributes_mc.AttributeList_mc.AddChild("AttributeAdjuster",null,{sName:_loc10_,sDescription:_loc9_,nID:_loc3_,nBase:_loc11_,nPoints:AttributesScene.m_aAttributes[_loc3_]});
            _loc3_ = _loc3_ + 1;
         }
      };
      _root.attribute_points_mc_init = function()
      {
         this.attrib_modifier_mc_init = function()
         {
            this.SetText(Localization.Strings.LOC_MODIFIER);
         };
         this.pointsleft_mc_init = function()
         {
            AttributesScene.UpdatePointsToSpend();
         };
      };
   }
   static function SkipScene()
   {
      var _loc1_;
      if(AttributesScene.parentClass.GoingForward)
      {
         SceneManager.PlayScene("Skills");
      }
      else
      {
         AttributesScene.ResetAttributes();
         _loc1_ = flash.external.ExternalInterface.call("GetCurrentModuleName");
         if(_loc1_ == DAConstants.EP1_MODULE_NAME || _loc1_ == DAConstants.ED1_MODULE_NAME || _loc1_ == DAConstants.ED2_MODULE_NAME)
         {
            SceneManager.PlayScene("Specialization");
         }
         else
         {
            SceneManager.PlayScene("SoundsetAppearance");
         }
      }
   }
   static function StartScene()
   {
      var _loc4_;
      var _loc6_;
      var _loc5_;
      var _loc1_;
      var _loc2_;
      var _loc3_;
      if(AttributesScene.m_bPointsReadIn == false)
      {
         AttributesScene.m_bPointsReadIn = true;
         AttributesScene.NewAttributePoints = Number(ExternalCommands.GetValue("CharGenCreature.Attributes.34.Total"));
         AttributesScene.AttributePointsToSpend = AttributesScene.NewAttributePoints;
         trace("read in " + AttributesScene.NewAttributePoints + " attribute points to spend");
         if(OtherImportScene.UseSeeds)
         {
            _loc4_ = "Paperdoll.SeededCharacters." + OtherImportScene.HeroIndex;
            _loc6_ = Number(ExternalCommands.GetNumMembers(_loc4_ + ".AttributeIDs"));
            _loc5_ = Number(ExternalCommands.GetNumMembers(_loc4_ + ".AttributePoints"));
            if(_loc6_ == _loc5_)
            {
               _loc1_ = 0;
               while(_loc1_ < _loc5_)
               {
                  _loc2_ = Number(ExternalCommands.GetValue(_loc4_ + ".AttributeIDs." + _loc1_));
                  _loc3_ = Number(ExternalCommands.GetValue(_loc4_ + ".AttributePoints." + _loc1_));
                  AttributesScene.SpendPoints(_loc2_,_loc3_);
                  _loc1_ = _loc1_ + 1;
               }
            }
         }
      }
      if(AttributesScene.NewAttributePoints <= 0 && !AttributesScene.bLevelUp)
      {
         AttributesScene.SkipScene();
      }
      AttributesScene.UpdatePointsToSpend();
   }
   static function CheckNextButtonEnable()
   {
      if(!AttributesScene.bLevelUp && AttributesScene.AttributePointsToSpend > 0)
      {
         AttributesScene.m_mcNextButton.Disable();
      }
      else
      {
         AttributesScene.m_mcNextButton.Enable();
      }
   }
   static function ResetAttributes()
   {
      var _loc1_ = AttributesScene.ATTRIBUTES_BEGIN;
      while(_loc1_ <= AttributesScene.ATTRIBUTES_END)
      {
         AttributesScene.RefundPoints(_loc1_,AttributesScene.m_aAttributes[_loc1_] - AttributesScene.m_aSeedAttributes[_loc1_]);
         _loc1_ = _loc1_ + 1;
      }
   }
   static function SeedExistingAllocations()
   {
      var _loc1_ = AttributesScene.ATTRIBUTES_BEGIN;
      var _loc2_;
      var _loc3_;
      var _loc4_;
      while(_loc1_ <= AttributesScene.ATTRIBUTES_END)
      {
         _loc2_ = Number(ExternalCommands.GetValue("CharGenCreature.Attributes." + _loc1_ + ".Total"));
         _loc3_ = Number(ExternalCommands.GetValue("CharGenCreature.Attributes." + _loc1_ + ".Modifier"));
         _loc4_ = _loc2_ - _loc3_ - AttributesScene.AttributeFloor(_loc1_);
         if(_loc4_ < 0)
         {
            _loc4_ = 0;
         }
         AttributesScene.m_aAttributes[_loc1_] = _loc4_;
         AttributesScene.m_aSeedAttributes[_loc1_] = _loc4_;
         _loc1_ = _loc1_ + 1;
      }
   }
   static function AttributeFloor(nID)
   {
      // The lowest a "spent" allocation can be refunded to. Points below this
      // were never the player's to spend, so they must not come back.
      if(!AttributesScene.UseStartingValueFloor)
      {
         return 10;
      }
      return 10 + AttributesScene.RaceAttributeBonus(nID) + AttributesScene.ClassAttributeBonus(nID);
   }

   static function RaceAttributeBonus(nID)
   {
      // nID here is a properties.2da row id (1 Str, 2 Dex, 3 Will, 4 Mag,
      // 5 Cun, 6 Con), NOT an attributes.2da id (which orders Con 3,
      // Int 4, Will 5, Mag 6). The two id spaces disagree, so never map
      // ids directly to RACE_base columns: resolve the stat name first and
      // look the adjust column up by name.
      var _loc1_ = Number(ExternalCommands.GetValue("CharGenCreature.Stats.Race"));
      if(_loc1_ < 1)
      {
         return 0;
      }
      return AttributesScene.AdjustFromTable(_2DA.TABLE_RACE,_loc1_,nID);
   }

   static function ClassAttributeBonus(nID)
   {
      var _loc1_ = Number(ExternalCommands.GetValue("CharGenCreature.Attributes.27.Total"));
      if(_loc1_ < 1)
      {
         return 0;
      }
      return AttributesScene.AdjustFromTable(_2DA.TABLE_CLASS,_loc1_,nID);
   }
   static function AdjustFromTable(nTable, nRow, nID)
   {
      // RACE_base and CLA_base abbreviate their columns (StrAdjust, DexAdjust,
      // WillAdjust, MagAdjust, ConAdjust) and have no Cunning column at all.
      // They also order those columns by attributes.2da's ids, while nID is a
      // properties.2da row id, so the column has to be chosen by name here
      // rather than derived from the stat's display name.
      var _loc1_ = AttributesScene.AdjustColumnFor(nID);
      if(_loc1_ == "")
      {
         return 0;
      }
      var _loc2_ = ExternalCommands.Get2DAValueByColumnName(nTable,nRow,_loc1_);
      if(_loc2_ == "" || _loc2_ == undefined || _loc2_ == "****")
      {
         return 0;
      }
      return Number(_loc2_);
   }
   static function AdjustColumnFor(nID)
   {
      if(nID == 1)
      {
         return "StrAdjust";
      }
      if(nID == 2)
      {
         return "DexAdjust";
      }
      if(nID == 3)
      {
         return "WillAdjust";
      }
      if(nID == 4)
      {
         return "MagAdjust";
      }
      if(nID == 5)
      {
         // Cunning is called Intelligence in the 2DAs, so its column is IntAdjust.
         return "IntAdjust";
      }
      if(nID == 6)
      {
         return "ConAdjust";
      }
      return "";
   }
   static function CanRemovePoint(nID)
   {
      var _loc1_ = Number(ExternalCommands.GetValue("CharGenCreature.Attributes." + nID + ".Base"));
      if(_loc1_ - 1 < AttributesScene.AttributeFloor(nID))
      {
         return false;
      }
      return !AttributesScene.IsAttributeRequiredAbove(nID,_loc1_ - 1);
   }
   static function IsAttributeRequiredAbove(nID, fValue)
   {
      var aBases = new Array("CharGenCreature.Stats.SkillChains","CharGenCreature.Stats.SpellChains","CharGenCreature.Stats.TalentChains");
      var _loc2_;
      var _loc3_;
      var _loc4_;
      var _loc5_;
      var _loc6_;
      var _loc7_;
      _loc6_ = 0;
      while(_loc6_ < aBases.length)
      {
         _loc2_ = aBases[_loc6_];
         _loc3_ = Number(ExternalCommands.GetNumMembers(_loc2_));
         _loc4_ = 0;
         while(_loc4_ < _loc3_)
         {
            _loc5_ = _loc2_ + "." + _loc4_;
            if(ExternalCommands.GetNumber(_loc5_ + ".DisplayState") == SharedLibrary.Ability.DISPLAYSTATE_HAVE)
            {
               _loc7_ = ExternalCommands.GetNumber(_loc5_ + ".AbilityTemplate.PrereqAttributeID");
               if(_loc7_ == nID && ExternalCommands.GetNumber(_loc5_ + ".AbilityTemplate.PrereqAttributeValue") > fValue)
               {
                  return true;
               }
            }
            _loc4_ = _loc4_ + 1;
         }
         _loc6_ = _loc6_ + 1;
      }
      return false;
   }
   static function CanAddMore(A)
   {
      return AttributesScene.AttributePointsToSpend > 0;
   }
   static function UpdatePointsToSpend()
   {
      _root.attribute_points_mc.top_frame_mc.pointsleft_mc.SetText("" + AttributesScene.AttributePointsToSpend);
      AttributesScene.CheckNextButtonEnable();
   }
   static function SpendPoints(nAttributeID, nAmount)
   {
      if(nAmount == 0)
      {
         return undefined;
      }
      AttributesScene.m_aAttributes[nAttributeID] += nAmount;
      AttributesScene.AttributePointsToSpend -= nAmount;
      AttributesScene.UpdatePointsToSpend();
      ExternalCommands.SendMessageArgs("GUICharGen.CharGenAssignAttribute",AttributesScene.parentClass.CreatureID,nAttributeID,nAmount);
      ExternalCommands.SendMessageArgs("Paperdoll.CharGenAssignAttribute",AttributesScene.parentClass.CreatureID,nAttributeID,nAmount);
   }
   static function RefundPoints(nAttributeID, nAmount)
   {
      if(nAmount == 0)
      {
         return undefined;
      }
      AttributesScene.m_aAttributes[nAttributeID] -= nAmount;
      AttributesScene.AttributePointsToSpend += nAmount;
      AttributesScene.UpdatePointsToSpend();
      ExternalCommands.SendMessageArgs("GUICharGen.CharGenAssignAttribute",AttributesScene.parentClass.CreatureID,nAttributeID,-1 * nAmount);
      ExternalCommands.SendMessageArgs("Paperdoll.CharGenAssignAttribute",AttributesScene.parentClass.CreatureID,nAttributeID,-1 * nAmount);
   }
   static function SetDescriptionText(sHeader, sDescription)
   {
      AttributesScene.mcDescriptionHeader.SetText(sHeader);
      AttributesScene.mcDescription.SetText(sDescription);
   }
   static function PointsSpentOnAttribute(nID)
   {
      return AttributesScene.m_aAttributes[nID];
   }
}
