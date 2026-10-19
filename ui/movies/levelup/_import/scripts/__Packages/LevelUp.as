class LevelUp
{
   var AddBehaviour;
   var AddChild;
   var Horizontal;
   var HostAnchor;
   var OnButtonAction;
   var Scrollable_mc;
   var Scrollable_mc_init;
   var SetText;
   var Spacing;
   var TextField;
   var TooltipAnchor;
   var TooltipSource;
   var TooltipType;
   var Wrap;
   var WrapSize;
   var m_nSoundType;
   static var CreatureID = 0;
   static var GoingForward = true;
   static var nAbilityType = 0;
   static var nSpecializationPoints = 0;
   static var mcSpecDescription = null;
   static var mcSpecPoints = null;
   static var aNewSpecPoints = new Array();
   static var aUnlearnedSpecs;
   static var nSpecializationsFound = 0;
   static var mcSpecializations = null;
   static var nExitPoint = 0;
   static var LEVELUP_EXIT_ABORT = 0;
   static var LEVELUP_EXIT_COMPLETE = 1;
   static var m_Observers = null;
   function LevelUp()
   {
   }
   static function StartScene()
   {
      LevelUp.CreatureID = Number(ExternalCommands.GetValue("CharGenCreature.ID"));
      LevelUp.aUnlearnedSpecs = new Array();
      LevelUp.nExitPoint = LevelUp.LEVELUP_EXIT_ABORT;
      LevelUp.m_Observers = new TokenObserverGroup();
      SharedLibrary.AbilityIcon.m_AbilityIconObservers = LevelUp.m_Observers;
      var _loc1_ = ExternalCommands.GetValue("CharGenCreature.Stats.AutoLevelUp");
      // A missing token is not "auto-level me". CharGenCreature is only filled
      // in when the engine has a level-up session for this screen, so without
      // one this token is absent -- and "absent != 0" is true in ActionScript,
      // which made the old test auto-level and send GUI.HideFullScreenGUI,
      // hiding the screen again on the frame it opened. Only auto-level on a
      // real value.
      if(_loc1_ != null && Number(_loc1_) != 0)
      {
         LevelUp.SendAutoLevelUpMessage();
      }
      ExternalCommands.SendMessageArgs("GUILevelUp.CharGenStart",LevelUp.CreatureID,1);
      LevelUp.nSpecializationPoints = Number(ExternalCommands.GetValue("CharGenCreature.Attributes.38.Total"));
      AbilityScene.bLevelUp = true;
      AttributesScene.Initialize(true,LevelUp);
      SkillsScene.Initialize(true,LevelUp);
      SpellsTalentsScene.Initialize(true,LevelUp);
      LevelUp.Initialize();
      SharedLibrary.BookContents.SetupShowContents("levelup_intro","Attributes");
      AttributesScene.StartScene();
   }
   static function StartScene_Attributes()
   {
      trace("StartScene_Attributes");
   }
   static function StartScene_Skills()
   {
      trace("StartScene_Skills");
      SkillsScene.StartScene();
   }
   static function StartScene_SpellsTalents()
   {
      trace("StartScene_SpellsTalents");
      SpellsTalentsScene.StartScene();
   }
   static function FinishScene()
   {
      var _loc1_;
      var _loc3_;
      var _loc2_;
      if(LevelUp.nExitPoint == LevelUp.LEVELUP_EXIT_COMPLETE && CreatureUtils.IsHeroByID(LevelUp.CreatureID))
      {
         _loc1_ = 0;
         while(_loc1_ < LevelUp.aNewSpecPoints.length)
         {
            ExternalCommands.SendTelemetryInfo("GAME","LSCL",LevelUp.aNewSpecPoints[_loc1_].toString());
            _loc1_ = _loc1_ + 1;
         }
         _loc1_ = AttributesScene.ATTRIBUTES_BEGIN;
         while(_loc1_ <= AttributesScene.ATTRIBUTES_END)
         {
            if(AttributesScene.m_aAttributes[_loc1_] > 0)
            {
               _loc3_ = ExternalCommands.Get2DAValue(_2DA.TABLE_PROPERTIES,_loc1_,_2DA.HASH_STAT);
               _loc2_ = _loc3_ + " " + AttributesScene.m_aAttributes[_loc1_];
               ExternalCommands.SendTelemetryInfo("GAME","LATR",_loc2_);
            }
            _loc1_ = _loc1_ + 1;
         }
         _loc1_ = 0;
         while(_loc1_ < SkillsScene.aStoredPoints.length)
         {
            ExternalCommands.SendTelemetryInfo("GAME","LSKL",SkillsScene.aStoredPoints[_loc1_].toString());
            _loc1_ = _loc1_ + 1;
         }
         _loc1_ = 0;
         while(_loc1_ < SpellsTalentsScene.aStoredPoints.length)
         {
            ExternalCommands.SendTelemetryInfo("GAME","LABI",SpellsTalentsScene.aStoredPoints[_loc1_].toString());
            _loc1_ = _loc1_ + 1;
         }
      }
      else if(LevelUp.nExitPoint == LevelUp.LEVELUP_EXIT_ABORT)
      {
         LevelUp.RevertAllChanges();
      }
      LevelUp.KillObservers();
      ExternalCommands.SendMessageArgs("GUILevelUp.CharGenEnd",LevelUp.CreatureID,1,LevelUp.nExitPoint);
      ExternalCommands.PlayGUISound(SoundEvents.ST_FINISH_LEVELUP);
   }
   static function Initialize()
   {
      _root.Name_mc_init = function()
      {
         this.SetText(ExternalCommands.GetValue("CharGenCreature.Name"));
      };
      _root.Close_mc_init = function()
      {
         this.m_nSoundType = SoundEvents.ST_NONE;
         this.OnButtonAction = function()
         {
            LevelUp.nExitPoint = LevelUp.LEVELUP_EXIT_ABORT;
            ExternalCommands.SendMessageArgs("GUI.HideFullScreenGUI");
         };
         this.AddBehaviour(Behaviour.DisplayTooltip);
         this.TooltipType = Behaviour.DisplayTooltip.TOOLTIP_TYPE_SIMPLE_FLOATING;
         this.HostAnchor = Behaviour.DisplayTooltip.ANCHOR_TOP;
         this.TooltipAnchor = Behaviour.DisplayTooltip.ANCHOR_BOTTOM;
         this.TooltipSource = Localization.Strings.LOC_CLOSE;
      };
      _root.Header_mc_init = function()
      {
         this.SetText(Localization.Strings.LOC_LEVEL_UP_HEADER_BUTTON);
      };
      _root.Level_mc_init = function()
      {
         var _loc2_ = Number(ExternalCommands.GetValue("CharGenCreature.Attributes.27.Total"));
         var _loc3_ = ExternalCommands.GetTlkString(Number(ExternalCommands.Get2DAValue(_2DA.TABLE_CLASS,_loc2_,_2DA.HASH_NAMESTRREF)));
         this.SetText(Localization.Strings.LOC_LEVEL + " " + ExternalCommands.GetValue("CharGenCreature.Attributes.15.Total") + " " + _loc3_);
      };
      _root.Specialization_mc_init = function()
      {
         this.SetText(Localization.Strings.LOC_SPECIALIZATION);
      };
      _root.specializationPoints_mc_init = function()
      {
         LevelUp.mcSpecPoints = this;
         this.SetText(LevelUp.nSpecializationPoints);
      };
      _root.scrollingSpecDescription_mc_init = function()
      {
         LevelUp.mcSpecDescription = this;
         var _loc2_ = this;
         this.Scrollable_mc_init = function()
         {
            this.AddBehaviour(Behaviour.Scrollable);
            this.TextField.autoSize = "left";
            this.SetText(Localization.Strings.LOC_SPECIALIZATIONS_EXPLAINED);
            if(flash.external.ExternalInterface.call("GetCurrentModuleName") == DAConstants.EP1_MODULE_NAME)
            {
               this.SetText(Localization.Strings.LOC_SPECIALIZATIONS_EXPL_EP1);
            }
            else
            {
               this.SetText(Localization.Strings.LOC_SPECIALIZATIONS_EXPLAINED);
            }
         };
      };
      _root.specializations_mc_init = function()
      {
         LevelUp.mcSpecializations = this.Scrollable_mc;
         this.Scrollable_mc_init = function()
         {
            this.AddBehaviour(Behaviour.Scrollable);
            this.AddBehaviour(Behaviour.ListLayout);
            this.Wrap = true;
            this.Horizontal = true;
            this.Spacing = 20;
            this.WrapSize = 300;
            var _loc10_ = Number(ExternalCommands.GetValue("CharGenCreature.Attributes.27.Total"));
            var _loc7_ = LevelUp.GetBaseClass(_loc10_);
            var _loc11_ = Number(ExternalCommands.Get2DAValueByRowIndexColumnHash(_2DA.TABLE_CLASS,_loc7_,_2DA.HASH_BUSESMANA)) == 1;
            if(_loc11_)
            {
               LevelUp.nAbilityType = CharGen.SPELLS;
            }
            else
            {
               LevelUp.nAbilityType = CharGen.TALENTS;
            }
            var _loc8_ = Number(ExternalCommands.GetValue("CharGenCreature.Attributes.15.Total"));
            var _loc9_ = Number(ExternalCommands.GetNum2DARows(_2DA.TABLE_CLASS));
            LevelUp.nSpecializationsFound = 0;
            var _loc3_ = 0;
            var _loc6_;
            var _loc2_;
            var _loc5_;
            var _loc4_;
            while(_loc3_ < _loc9_)
            {
               _loc6_ = Number(ExternalCommands.Get2DAValueByRowIndexColumnHash(_2DA.TABLE_CLASS,_loc3_,_2DA.HASH_BASECLASS));
               if(_loc6_ == _loc7_)
               {
                  _loc2_ = this.AddChild("ClassButton","icon" + LevelUp.nSpecializationsFound);
                  _loc2_.sName = ExternalCommands.GetTlkString(Number(ExternalCommands.Get2DAValueByRowIndexColumnHash(_2DA.TABLE_CLASS,_loc3_,_2DA.HASH_NAMESTRREF)));
                  _loc2_.sDescription = ExternalCommands.GetTlkString(Number(ExternalCommands.Get2DAValueByRowIndexColumnHash(_2DA.TABLE_CLASS,_loc3_,_2DA.HASH_DESCSTRREF)));
                  _loc2_.nSpecializationAbilityID = Number(ExternalCommands.Get2DAValueByRowIndexColumnHash(_2DA.TABLE_CLASS,_loc3_,_2DA.HASH_STARTINGABILITY1));
                  _loc2_.bSelected = Number(DAExternalCommands.HasAbility(LevelUp.CreatureID,_loc2_.nSpecializationAbilityID)) == 1;
                  _loc2_.sIcon = ExternalCommands.Get2DAValueByRowIndexColumnHash(_2DA.TABLE_CLASS,_loc3_,_2DA.HASH_ICON);
                  _loc2_.sAchievement = ExternalCommands.Get2DAValueByRowIndexColumnHash(_2DA.TABLE_CLASS,_loc3_,_2DA.HASH_ACHIEVEMENT);
                  _loc5_ = DAExternalCommands.HasAchievement(_loc2_.sAchievement);
                  _loc4_ = DAExternalCommands.HasAbilityPreRequisites(LevelUp.CreatureID,_loc2_.nSpecializationAbilityID);
                  _loc2_.bGrey = !_loc2_.bSelected && (!_loc5_ || LevelUp.nSpecializationPoints <= 0 || !_loc4_);
                  trace(_loc2_.sName + " : " + _loc2_.sIcon + ", " + _loc2_.bGrey + ", " + _loc2_.bSelected + ", " + _loc8_);
                  LevelUp.nSpecializationsFound++;
               }
               _loc3_ = _loc3_ + 1;
            }
         };
      };
      _root.Attributes_mc_init = function()
      {
         this.SetText(Localization.Strings.LOC_ATTRIBUTES);
      };
   }
   static function RevertAllChanges()
   {
      LevelUp.RevertSpellsTalents();
      LevelUp.RevertSkills();
      LevelUp.RevertAttributes();
      LevelUp.RevertSpecializations();
   }
   static function RevertSpecializations()
   {
      while(LevelUp.aNewSpecPoints.length > 0)
      {
         LevelUp.UnspendSpecializationPoint(LevelUp.aNewSpecPoints[0]);
      }
      LevelUp.RestoreUnlearnedSpecs();
   }
   static function RevertAttributes()
   {
      AttributesScene.ResetAttributes();
   }
   static function RevertSkills()
   {
      SkillsScene.ClearLearned(false);
   }
   static function RevertSpellsTalents()
   {
      SpellsTalentsScene.ClearLearned(false);
   }
   static function GetBaseClass(a_nClass)
   {
      var _loc1_ = Number(ExternalCommands.Get2DAValue(_2DA.TABLE_CLASS,a_nClass,_2DA.HASH_BASECLASS));
      if(_loc1_ == 0)
      {
         return a_nClass;
      }
      return _loc1_;
   }
   static function SpendSpecializationPoint(a_nID)
   {
      ExternalCommands.SendMessageArgs("GUILevelUp.CharGenAssignAbility",LevelUp.CreatureID,a_nID,1);
      ExternalCommands.PlayGUISound(SoundEvents.ST_STICKYBUTTON_CLICK);
      LevelUp.nSpecializationPoints--;
      LevelUp.aNewSpecPoints.push(a_nID);
      LevelUp.UpdateSpecPoints();
   }
   static function UnspendSpecializationPoint(a_nID)
   {
      var bWasNew = LevelUp.IsNewSpecialization(a_nID);
      ExternalCommands.SendMessageArgs("GUILevelUp.CharGenAssignAbility",LevelUp.CreatureID,-1 * a_nID,1);
      ExternalCommands.PlayGUISound(SoundEvents.ST_STICKYBUTTON_CLICK);
      LevelUp.nSpecializationPoints++;
      LevelUp.UpdateSpecPoints();
      var _loc1_ = 0;
      while(_loc1_ < LevelUp.aNewSpecPoints.length)
      {
         if(LevelUp.aNewSpecPoints[_loc1_] == a_nID)
         {
            LevelUp.aNewSpecPoints.splice(_loc1_,1);
         }
         _loc1_ = _loc1_ + 1;
      }
      if(!bWasNew)
      {
         LevelUp.aUnlearnedSpecs.push(a_nID);
      }
   }
   static function RestoreUnlearnedSpecs()
   {
      var _loc1_;
      if(LevelUp.aUnlearnedSpecs.length == 0)
      {
         return undefined;
      }
      while(LevelUp.aUnlearnedSpecs.length > 0)
      {
         _loc1_ = LevelUp.aUnlearnedSpecs[0];
         ExternalCommands.SendMessageArgs("GUILevelUp.CharGenAssignAbility",LevelUp.CreatureID,_loc1_,1);
         LevelUp.nSpecializationPoints--;
         LevelUp.aUnlearnedSpecs.splice(0,1);
      }
      LevelUp.UpdateSpecPoints();
   }
   static function HasAbilityRequiringSpec(a_nSpecID)
   {
      var aBases = new Array("CharGenCreature.Stats.SkillChains","CharGenCreature.Stats.SpellChains","CharGenCreature.Stats.TalentChains");
      var _loc1_;
      var _loc2_;
      var _loc3_;
      var _loc4_;
      var _loc5_;
      var _loc6_;
      var _loc7_;
      _loc6_ = 0;
      while(_loc6_ < aBases.length)
      {
         _loc1_ = aBases[_loc6_];
         _loc2_ = Number(ExternalCommands.GetNumMembers(_loc1_));
         _loc3_ = 0;
         while(_loc3_ < _loc2_)
         {
            _loc4_ = _loc1_ + "." + _loc3_;
            if(ExternalCommands.GetNumber(_loc4_ + ".DisplayState") == SharedLibrary.Ability.DISPLAYSTATE_HAVE)
            {
               _loc7_ = SharedLibrary.Ability.LoadFromToken(_loc4_,true);
               if(_loc7_.nPrereqAbilityID == a_nSpecID)
               {
                  return true;
               }
            }
            _loc3_ = _loc3_ + 1;
         }
         _loc6_ = _loc6_ + 1;
      }
      return false;
   }
   static function UpdateSpecPoints()
   {
      LevelUp.mcSpecPoints.SetText(LevelUp.nSpecializationPoints);
      var _loc5_ = Number(ExternalCommands.GetValue("CharGenCreature.Attributes.15.Total"));
      var _loc2_ = 0;
      var _loc1_;
      var _loc4_;
      var _loc3_;
      while(_loc2_ < LevelUp.nSpecializationsFound)
      {
         _loc1_ = LevelUp.mcSpecializations["icon" + _loc2_];
         if(_loc1_ && _loc1_.sAchievement)
         {
            _loc4_ = DAExternalCommands.HasAchievement(_loc1_.sAchievement);
            _loc1_.bSelected = DAExternalCommands.HasAbility(LevelUp.CreatureID,_loc1_.nSpecializationAbilityID);
            _loc3_ = DAExternalCommands.HasAbilityPreRequisites(LevelUp.CreatureID,_loc1_.nSpecializationAbilityID);
            _loc1_.bGrey = !_loc1_.bSelected && (!_loc4_ || LevelUp.nSpecializationPoints <= 0 || !_loc3_);
            _loc1_.UpdateSelected();
            _loc1_.UpdateGrey();
         }
         _loc2_ = _loc2_ + 1;
      }
   }
   static function IsNewSpecialization(a_nID)
   {
      var _loc1_ = 0;
      while(_loc1_ < LevelUp.aNewSpecPoints.length)
      {
         if(LevelUp.aNewSpecPoints[_loc1_] == a_nID)
         {
            return true;
         }
         _loc1_ = _loc1_ + 1;
      }
      return false;
   }
   static function SendAutoLevelUpMessage()
   {
      ExternalCommands.SendMessageArgs("GUILevelUp.AutoLevelUp",LevelUp.CreatureID);
      ExternalCommands.SendMessageArgs("GUI.HideFullScreenGUI");
   }
   static function KillObservers()
   {
      if(LevelUp.m_Observers != null)
      {
         LevelUp.m_Observers.RemoveAllTokenObservers();
      }
   }
}
