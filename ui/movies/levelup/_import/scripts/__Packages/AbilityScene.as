class AbilityScene
{
   static var nAbilityChainSpacing = 0;
   static var bLevelUp = false;
   static var bCharGenOrLevelUp = true;
   static var mcNextButton = null;
   static var m_Observers = new TokenObserverGroup();
   static var UNDEFINED = "?undefined";
   function AbilityScene()
   {
   }
   static function ClearAbilityDescription(a_mcDescription)
   {
      MovieUtils.HideMovie(a_mcDescription.Header_mc);
      a_mcDescription.Text_mc.SetText(Localization.Strings.LOC_NO_ABILITY_SELECTED);
      MovieUtils.HideMovie(a_mcDescription.Icon_mc);
   }
   static function UpdateAbilityDescription(a_oAbility, a_mcDescription)
   {
      MovieUtils.ShowMovie(a_mcDescription.Header_mc);
      MovieUtils.ShowMovie(a_mcDescription.Text_mc);
      MovieUtils.ShowMovie(a_mcDescription.Icon_mc);
      var _loc5_ = a_oAbility.sNameStrRef != AbilityScene.UNDEFINED ? a_oAbility.sNameStrRef : "?" + a_oAbility.sName;
      a_mcDescription.Header_mc.SetText(_loc5_);
      var _loc18_ = Number(ExternalCommands.Get2DAValue(_2DA.TABLE_ABI_BASE,a_oAbility.nID,_2DA.HASH_DAMAGEINFO));
      var _loc15_ = ExternalCommands.GetTlkString(_loc18_);
      var _loc13_ = Number(ExternalCommands.Get2DAValue(_2DA.TABLE_RANGES,a_oAbility.nRange,_2DA.HASH_STRID));
      var _loc11_ = ExternalCommands.GetTlkString(_loc13_);
      var _loc9_ = Number(ExternalCommands.GetValue("GUI.SelectedChar.Attributes.41.Total"));
      var _loc8_ = Number(ExternalCommands.Get2DAValue(_2DA.TABLE_GUITYPES,a_oAbility.nGUIType,_2DA.HASH_STRINGID));
      var _loc19_ = ExternalCommands.GetTlkString(_loc8_);
      var _loc3_ = a_oAbility.nUseType;
      var _loc4_;
      if(_loc3_ == 2)
      {
         _loc4_ = 380402;
      }
      else if(_loc3_ == 3)
      {
         _loc4_ = 380403;
      }
      else if(_loc3_ == 4)
      {
         _loc4_ = 380401;
      }
      var _loc12_ = ExternalCommands.GetTlkString(_loc4_);
      var _loc10_ = a_oAbility.sDescStrRef != AbilityScene.UNDEFINED ? a_oAbility.sDescStrRef : "?AbilityDescription";
      var _loc6_ = SharedLibrary.Ability.AbilityRequirements(a_oAbility,"CharGenCreature",!AbilityScene.bLevelUp ? ColorDefines.FAILED_REQUIREMENT_TEXT_RED_ON_DARK : ColorDefines.FAILED_REQUIREMENT_TEXT_RED_ON_LIGHT);
      var _loc20_ = "";
      var _loc7_ = String(a_oAbility.nCooldown);
      var _loc16_ = Number(ExternalCommands.Get2DAValue(_2DA.TABLE_ABI_BASE,a_oAbility.nID,_2DA.HASH_FATIGUE));
      var _loc14_ = String(_loc16_);
      var _loc17_ = SharedLibrary.Ability.GenerateTooltipText(a_oAbility.sTooltipStrRef,_loc5_,_loc19_,_loc12_,_loc11_,_loc15_,String(Math.round(a_oAbility.nCost * (1 + _loc9_ / 100))),String(Math.round(a_oAbility.nCostUpkeep)),_loc10_,_loc6_,_loc20_,_loc7_,"",_loc14_);
      a_mcDescription.Text_mc.SetText(_loc17_);
      MovieUtils.LoadImageFixedSize(a_mcDescription.Icon_mc,a_oAbility.sIcon,42,42);
   }
   static function CheckNextButtonEnable(oClass)
   {
      if(!oClass.bLevelUp && oClass.nPointsToSpend > 0)
      {
         AbilityScene.mcNextButton.Disable();
      }
      else
      {
         AbilityScene.mcNextButton.Enable();
      }
   }
   static function SendAbilityChainsRequest(oClass)
   {
      ExternalCommands.SendMessageArgs("GameModeController.FindAbilityChains",oClass.parentClass.CreatureID,oClass.nType,!oClass.bLevelUp ? SharedLibrary.Ability.DISPLAYMODE_CHARGEN : SharedLibrary.Ability.DISPLAYMODE_LEVELUP);
   }
   static function SendSelectionMessage(oClass, a_ID, a_bRequestChainsUpdate)
   {
      ExternalCommands.SendMessageArgs("GUICharGen.CharGenAssignAbility",oClass.parentClass.CreatureID,a_ID,0);
      ExternalCommands.SendMessageArgs("Paperdoll.CharGenAssignAbility",oClass.parentClass.CreatureID,a_ID,0);
      if(a_bRequestChainsUpdate)
      {
         AbilityScene.SendAbilityChainsRequest(oClass);
      }
   }
   static function UpdatePointsToSpend(oClass)
   {
      oClass.mcPointsLeft.SetText("" + oClass.nPointsToSpend);
      AbilityScene.CheckNextButtonEnable(oClass);
   }
   static function ResetPoints(oClass, bSendAbilityChainsRequest)
   {
      oClass.nPointsToSpend += oClass.aStoredPoints.length;
      while(oClass.aStoredPoints.length > 0)
      {
         AbilityScene.SendSelectionMessage(oClass,- oClass.aStoredPoints.shift(),false);
         oClass.aStoredPrereqs.shift();
      }
      AbilityScene.UpdatePointsToSpend(oClass);
      if(bSendAbilityChainsRequest)
      {
         AbilityScene.SendAbilityChainsRequest(oClass);
      }
   }
   static function SpendPoint(oClass, a_nID, a_nPrereqID)
   {
      if(oClass.nPointsToSpend > 0)
      {
         oClass.nPointsToSpend = oClass.nPointsToSpend - 1;
         AbilityScene.UpdatePointsToSpend(oClass);
         oClass.aStoredPoints.push(a_nID);
         oClass.aStoredPrereqs.push(a_nPrereqID);
         AbilityScene.RemoveFromSeeded(oClass,a_nID);
         AbilityScene.SendSelectionMessage(oClass,a_nID,true);
         ExternalCommands.PlayGUISound(SoundEvents.ST_LEARN_SKILL);
         return true;
      }
      return false;
   }
   static function UnspendPoint(oClass, a_nID)
   {
      if(AbilityScene.IsPrereqOfOwned(oClass,a_nID))
      {
         return false;
      }
      var _loc4_ = true;
      var _loc5_ = -1;
      var _loc1_ = 0;
      while(_loc1_ < oClass.aStoredPoints.length)
      {
         if(oClass.aStoredPoints[_loc1_] == a_nID)
         {
            _loc5_ = _loc1_;
         }
         if(oClass.aStoredPrereqs[_loc1_] == a_nID)
         {
            _loc4_ = false;
            break;
         }
         _loc1_ = _loc1_ + 1;
      }
      if(_loc4_)
      {
         oClass.nPointsToSpend = oClass.nPointsToSpend + 1;
         AbilityScene.UpdatePointsToSpend(oClass);
         if(_loc5_ >= 0)
         {
            oClass.aStoredPoints.splice(_loc5_,1);
            oClass.aStoredPrereqs.splice(_loc5_,1);
         }
         else if(oClass.aUnlearnedPoints != undefined)
         {
            oClass.aUnlearnedPoints.push(a_nID);
         }
         AbilityScene.SendSelectionMessage(oClass,- a_nID,true);
         ExternalCommands.PlayGUISound(SoundEvents.ST_UNLEARN_SKILL);
      }
      return _loc4_;
   }
   static function ChainTokenBase(oClass)
   {
      if(oClass.nType == CharGen.SKILLS)
      {
         return "CharGenCreature.Stats.SkillChains";
      }
      if(oClass.nType == CharGen.SPELLS)
      {
         return "CharGenCreature.Stats.SpellChains";
      }
      if(oClass.nType == CharGen.TALENTS)
      {
         return "CharGenCreature.Stats.TalentChains";
      }
      return "";
   }
   static function IsPrereqOfOwned(oClass, a_nID)
   {
      if(AbilityScene.IsCombatTrainingPrereqOfOwned(a_nID))
      {
         return true;
      }
      var sBase = AbilityScene.ChainTokenBase(oClass);
      var nCount;
      var _loc3_;
      var _loc2_;
      if(sBase == "")
      {
         return false;
      }
      nCount = Number(ExternalCommands.GetNumMembers(sBase));
      _loc3_ = 0;
      while(_loc3_ < nCount)
      {
         _loc2_ = SharedLibrary.Ability.LoadFromToken(sBase + "." + _loc3_,true);
         if(_loc2_.nDisplayState == SharedLibrary.Ability.DISPLAYSTATE_HAVE && _loc2_.nPrereqAbilityID == a_nID)
         {
            return true;
         }
         _loc3_ = _loc3_ + 1;
      }
      return false;
   }
   static function IsCombatTrainingPrereqOfOwned(a_nID)
   {
      // Combat Training is a skill, but talents and spells do not name it in
      // prereqability. They carry a RequiresCombatTraining flag and the Rank
      // they need, so the prereqability scan in IsPrereqOfOwned cannot see
      // them and would happily refund a rank they still depend on.
      //
      // The four ranks are ABI ids 100100..100103; removing a_nID leaves
      // ranks below it, so the surviving rank is a_nID - 100100.
      if(a_nID < 100100 || a_nID > 100103)
      {
         return false;
      }
      var nRemaining = a_nID - 100100;
      var aBases = new Array("CharGenCreature.Stats.SkillChains","CharGenCreature.Stats.SpellChains","CharGenCreature.Stats.TalentChains");
      var _loc1_ = 0;
      var _loc2_;
      var _loc3_;
      var _loc4_;
      var _loc5_;
      while(_loc1_ < aBases.length)
      {
         _loc2_ = aBases[_loc1_];
         _loc3_ = Number(ExternalCommands.GetNumMembers(_loc2_));
         _loc4_ = 0;
         while(_loc4_ < _loc3_)
         {
            _loc5_ = SharedLibrary.Ability.LoadFromToken(_loc2_ + "." + _loc4_,true);
            if(_loc5_.nDisplayState == SharedLibrary.Ability.DISPLAYSTATE_HAVE)
            {
               _loc5_.LoadDeferredAbilityInfo();
               if(_loc5_.bRequiresCombatTraining && _loc5_.nRank > nRemaining)
               {
                  return true;
               }
            }
            _loc4_ = _loc4_ + 1;
         }
         _loc1_ = _loc1_ + 1;
      }
      return false;
   }
   static function RestoreUnlearned(oClass)
   {
      var _loc1_;
      if(oClass.aUnlearnedPoints == undefined)
      {
         return undefined;
      }
      _loc1_ = 0;
      while(_loc1_ < oClass.aUnlearnedPoints.length)
      {
         AbilityScene.SendSelectionMessage(oClass,oClass.aUnlearnedPoints[_loc1_],false);
         _loc1_ = _loc1_ + 1;
      }
      oClass.aUnlearnedPoints = new Array();
   }
   static function RevertPoints(oClass, bSendAbilityChainsRequest)
   {
      AbilityScene.ResetPoints(oClass,false);
      AbilityScene.RestoreUnlearned(oClass);
      if(oClass.nInitialPoints >= 0)
      {
         oClass.nPointsToSpend = oClass.nInitialPoints;
      }
      AbilityScene.UpdatePointsToSpend(oClass);
      if(bSendAbilityChainsRequest)
      {
         AbilityScene.SendAbilityChainsRequest(oClass);
      }
   }
   static function IsNewAbility(a_oScene, a_nID)
   {
      var _loc1_ = 0;
      while(_loc1_ < a_oScene.aStoredPoints.length)
      {
         if(a_oScene.aStoredPoints[_loc1_] == a_nID)
         {
            return true;
         }
         _loc1_ = _loc1_ + 1;
      }
      return false;
   }
   static function HasSeededAbility(oClass, a_nID)
   {
      var _loc2_ = oClass.aSeededAbilities.length;
      var _loc1_ = 0;
      while(_loc1_ < _loc2_)
      {
         if(oClass.aSeededAbilities[_loc1_] == a_nID)
         {
            return true;
         }
         _loc1_ = _loc1_ + 1;
      }
      return false;
   }
   static function RemoveFromSeeded(oClass, a_nID)
   {
      var _loc3_ = oClass.aSeededAbilities.length;
      var _loc1_ = 0;
      while(_loc1_ < _loc3_)
      {
         if(oClass.aSeededAbilities[_loc1_] == a_nID)
         {
            oClass.aSeededAbilities.splice(_loc1_,1);
         }
         _loc1_ = _loc1_ + 1;
      }
   }
}
