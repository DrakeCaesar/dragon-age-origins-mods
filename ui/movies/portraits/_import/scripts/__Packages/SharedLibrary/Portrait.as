class SharedLibrary.Portrait extends GUI.Element
{
   var AlertQueue;
   var AlertDamage_mc_init;
   var m_DamageAlertMC;
   var Picture_mc;
   var DeathShroud_mc_init;
   var HealthBar_mc_init;
   var Picture_mc_init;
   var Portrait_mc;
   var PortraitBg_mc_init;
   var AlertPoison_mc_init;
   var AlertParalyze_mc_init;
   var LevelUpIndicator_mc_init;
   var TooltipType;
   var HostAnchor;
   var TooltipAnchor;
   var TooltipSource;
   var SetTooltipSource;
   var ManaStaminaBar_mc_init;
   var m_ProgressBarValue;
   var ManaStaminaBarReserved_mc_init;
   var ManaStaminaBar_mc;
   var ManaStaminaBarReserved_mc;
   var m_nPreviousCreatureID;
   var m_mcDeathShroud;
   var m_nCurrentAlertMovie;
   var CurrentCommandText_mc_init;
   var CurrentCommand_mc_init;
   var CurrentCommand_mc;
   var m_sCreatureToken = "";
   var m_nPreviousHealth = -1;
   var FLASHING_THRESHOLD = 20;
   var m_bCurrentCommandVisible = false;
   var LocalIndex = -1;
   var ALERT_NIL = 0;
   var ALERT_HEALTH_SINGLE = 100;
   var ALERT_HEALTH_CONTINUOUS = 200;
   var ALERT_POISON_CONTINOUS = 300;
   var ALERT_PARALYZE_CONTINOUS = 400;
   var sCurrentImage = null;
   function Portrait()
   {
      super();
   }
   function DefineElement()
   {
      this.AddBehaviour(Behaviour.PushButton);
      this.AddBehaviour(Behaviour.DisplayTooltip);
      this.AddBehaviour(Behaviour.Highlightable);
   }
   function FinalizeInstance()
   {
      this.SetupInputCallbacks();
      var mcPortrait = this;
      this.AlertQueue = new Array();
      this.AlertDamage_mc_init = function()
      {
         this.gotoAndStop(1);
         MovieUtils.DisableHitTest(this);
      };
      this.m_DamageAlertMC = new DataType.MovieController(this.Picture_mc.AlertDamage_mc);
      this.m_DamageAlertMC.GetMovieClip().gotoAndStop(1);
      this.DeathShroud_mc_init = function()
      {
         mcPortrait.m_mcDeathShroud = this;
      };
      FuncUtils.ChainFunction(this,"onRollOverHitArea",function()
      {
         ExternalCommands.SetValue("GameModeExplore.GUITargetedPlayer",Number(ExternalCommands.GetValue(mcPortrait.m_sCreatureToken + ".ID")));
      }
      );
      FuncUtils.ChainFunction(this,"onRollOutHitArea",function()
      {
         ExternalCommands.SetValue("GameModeExplore.GUITargetedPlayer",0);
      }
      );
      FuncUtils.ChainFunction(this,"onDragOutHitArea",function()
      {
         ExternalCommands.SetValue("GameModeExplore.GUITargetedPlayer",0);
      }
      );
      this.SetupCurrentCommandIndicator();
   }
   function SetCreatureToken(a_sCreatureToken)
   {
      this.m_sCreatureToken = a_sCreatureToken;
      var mcPortrait = this;
      TokenManager.AddTokenObserverWithID(_OBSERVER_ID.PORTRAIT_VISIBILITY_RANGE + this.LocalIndex,this.m_sCreatureToken,function(a_sPlayer)
      {
         if(ExternalCommands.GetValue(mcPortrait.m_sCreatureToken) == null)
         {
            MovieUtils.HideMovie(mcPortrait);
         }
         else
         {
            MovieUtils.ShowMovie(mcPortrait);
         }
      }
      );
      this.HealthBar_mc_init = function()
      {
         MovieUtils.DisableHitTest(this);
         DataType.Observable.RegisterListener(this,"m_ProgressBarValue",new DataType.Callback(mcPortrait,mcPortrait.HealthListener));
         mcPortrait.UpdateHealthBar(this);
      };
      TokenManager.AddTokenObserverWithID(_OBSERVER_ID.PORTRAIT_HP_CURRENT_RANGE + this.LocalIndex,mcPortrait.m_sCreatureToken + ".Attributes.7.Current",function()
      {
         mcPortrait.UpdateHealthBar(mcPortrait.HealthBar_mc);
         if(mcPortrait.IsTooltipDisplayed())
         {
            mcPortrait.UpdateTooltip();
         }
      }
      );
      TokenManager.AddTokenObserverWithID(_OBSERVER_ID.PORTRAIT_HP_TOTAL_RANGE + this.LocalIndex,mcPortrait.m_sCreatureToken + ".Attributes.7.Total",function()
      {
         mcPortrait.UpdateHealthBar(mcPortrait.HealthBar_mc);
         if(mcPortrait.IsTooltipDisplayed())
         {
            mcPortrait.UpdateTooltip();
         }
      }
      );
      this.m_nPreviousHealth = ExternalCommands.GetValue(this.m_sCreatureToken + ".Attributes.7.Current");
      if(this.m_nPreviousHealth == null)
      {
         this.m_nPreviousHealth = -1;
      }
      this.SetupManaStaminaBar();
      this.Picture_mc_init = function()
      {
         var mcPicture = this;
         var nWidth = this.Portrait_mc._width;
         var nHeight = this.Portrait_mc._height;
         TokenManager.AddTokenObserverWithID(_OBSERVER_ID.PORTRAIT_PICTURE_RANGE + mcPortrait.LocalIndex,mcPortrait.m_sCreatureToken + ".Portrait",function(a_sPortrait)
         {
            if(a_sPortrait != null && a_sPortrait.length > 0 && a_sPortrait.charAt(a_sPortrait.length - 1) != "?")
            {
               MovieUtils.LoadImageFixedSize(mcPicture.Portrait_mc,a_sPortrait,nWidth,nHeight);
            }
            else
            {
               mcPicture.Portrait_mc.unloadMovie();
            }
         }
         );
      };
      this.PortraitBg_mc_init = function()
      {
         var self = this;
         TokenManager.AddTokenObserverWithID(_OBSERVER_ID.PORTRAIT_TINT_RANGE + mcPortrait.LocalIndex,mcPortrait.m_sCreatureToken + ".PortraitProperties.PortraitTint",function(a_nTintIndex)
         {
            self.gotoAndStop(a_nTintIndex);
         }
         );
      };
      this.Picture_mc.SelectionIndicator_mc_init = function()
      {
         var mcSelectionRing = this;
         TokenManager.AddTokenObserverWithID(_OBSERVER_ID.PORTRAIT_SELECTED_RANGE + mcPortrait.LocalIndex,mcPortrait.m_sCreatureToken + ".UserSelected",function(a_sValue)
         {
            if(Number(a_sValue) == 1)
            {
               mcSelectionRing.gotoAndStop(2);
            }
            else
            {
               mcSelectionRing.gotoAndStop(1);
            }
         }
         );
      };
      this.AlertPoison_mc_init = this.CreateAlertInitFunction(this.m_sCreatureToken + ".Poisoned",this.ALERT_POISON_CONTINOUS);
      this.AlertParalyze_mc_init = this.CreateAlertInitFunction(this.m_sCreatureToken + ".Paralyzed",this.ALERT_PARALYZE_CONTINOUS);
      TokenManager.AddTokenObserverWithID(_OBSERVER_ID.PORTRAIT_LEVELUP_RANGE + this.LocalIndex,mcPortrait.m_sCreatureToken + ".PortraitLevelUp",function(a_bCanLevelUp)
      {
         if(mcPortrait.LevelUpIndicator_mc != undefined)
         {
            MovieUtils.ShowMovie(mcPortrait.LevelUpIndicator_mc);
            if(a_bCanLevelUp != 0)
            {
               mcPortrait.LevelUpIndicator_mc.gotoAndPlay(0);
            }
            else
            {
               mcPortrait.LevelUpIndicator_mc.gotoAndStop(29);
            }
         }
      }
      );
      this.LevelUpIndicator_mc_init = function()
      {
         this.AddBehaviour(Behaviour.DisplayTooltip);
         this.TooltipType = Behaviour.DisplayTooltip.TOOLTIP_TYPE_SIMPLE_FLOATING;
         this.HostAnchor = Behaviour.DisplayTooltip.ANCHOR_RIGHT;
         this.TooltipAnchor = Behaviour.DisplayTooltip.ANCHOR_LEFT;
         this.TooltipSource = Localization.Strings.LOC_LEVEL_UP;
         var self = this;
         TokenManager.AddTokenObserverWithID(_OBSERVER_ID.PORTRAIT_LEVELUP_COMBATCHECKER_RANGE + mcPortrait.LocalIndex,"GameModeController.CurrentGameMode",function(a_nGameMode)
         {
            if(a_nGameMode == GUISystem.GM_COMBAT)
            {
               self.gotoAndPlay(0);
               self.DisableWithEvents();
               self.m_bPushButtonEnabled = false;
               self.SetTooltipSource(Localization.Strings.LOC_LEVEL_UP_DISABLED);
            }
            else
            {
               if(Number(ExternalCommands.GetValue(mcPortrait.m_sCreatureToken + ".PortraitLevelUp")) != 0)
               {
                  self.gotoAndPlay(0);
               }
               else
               {
                  self.gotoAndStop(29);
               }
               self.EnableWithEvents();
               self.m_bPushButtonEnabled = true;
               self.SetTooltipSource(Localization.Strings.LOC_LEVEL_UP);
            }
         }
         );
         this.OnButtonAction = function()
         {
            var _loc1_;
            if(ExternalCommands.GetValue("GameModeController.CurrentGameMode") != GUISystem.GM_COMBAT)
            {
               _loc1_ = ExternalCommands.GetValue(mcPortrait.m_sCreatureToken + ".ID");
               ExternalCommands.SendMessageArgs("GUI.GoToLevelUp",_loc1_,0);
            }
         };
         MovieUtils.ShowMovie(this);
         if(ExternalCommands.GetValue("GameModeController.CurrentGameMode") == GUISystem.GM_COMBAT)
         {
            this.gotoAndPlay(0);
            this.DisableWithEvents();
         }
         else
         {
            if(Number(ExternalCommands.GetValue(mcPortrait.m_sCreatureToken + ".PortraitLevelUp")) != 0)
            {
               this.gotoAndPlay(0);
            }
            else
            {
               this.gotoAndStop(29);
            }
            this.EnableWithEvents();
         }
      };
   }
   function onRollOverHitArea()
   {
      this.UpdateTooltip();
   }
   function UpdateTooltip()
   {
      var _loc7_ = ExternalCommands.GetValue(this.m_sCreatureToken + ".Name");
      var _loc10_ = ExternalCommands.GetValue(this.m_sCreatureToken + ".Attributes.15.Total");
      var _loc8_ = ExternalCommands.GetValue(this.m_sCreatureToken + ".Stats.ClassName");
      var _loc14_ = ExternalCommands.GetValue(this.m_sCreatureToken + ".Stats.ClassHasMana");
      var _loc13_ = Number(_loc14_) == 0 ? Localization.Strings.LOC_STAMINA : Localization.Strings.LOC_MANA;
      var _loc12_ = CreatureUtils.FormatPrecisionByProperty(ExternalCommands.GetValue(this.m_sCreatureToken + ".Attributes.7.Current"),SharedLibrary.CoreStats.PROP_HEALTH);
      var _loc5_ = CreatureUtils.FormatPrecisionByProperty(ExternalCommands.GetValue(this.m_sCreatureToken + ".Attributes.7.Total"),SharedLibrary.CoreStats.PROP_HEALTH);
      var _loc9_ = CreatureUtils.FormatPrecisionByProperty(ExternalCommands.GetValue(this.m_sCreatureToken + ".Attributes.8.Current"),SharedLibrary.CoreStats.PROP_ENERGY);
      var _loc11_ = CreatureUtils.FormatPrecisionByProperty(ExternalCommands.GetValue(this.m_sCreatureToken + ".Attributes.8.Total"),SharedLibrary.CoreStats.PROP_ENERGY);
      var _loc4_ = CreatureUtils.GetExperienceInfo(this.m_sCreatureToken);
      var _loc3_ = "";
      var _loc2_ = Math.abs(ExternalCommands.GetValue(this.m_sCreatureToken + ".AbilityUpkeepCost"));
      if(_loc2_ != 0)
      {
         _loc3_ = " (" + CreatureUtils.FormatPrecisionByProperty(_loc2_,SharedLibrary.CoreStats.PROP_ENERGY) + " " + Localization.Strings.LOC_RESERVED + ")";
      }
      var _loc6_ = "<header>" + _loc7_ + "</header>" + Localization.Strings.LOC_LEVEL + ": " + _loc10_ + "\n" + Localization.Strings.LOC_CLASS + ": " + _loc8_ + "\n" + Localization.Strings.LOC_HEALTH + ": " + _loc12_ + " / " + _loc5_ + "\n" + _loc13_ + ": " + _loc9_ + " / " + _loc11_ + _loc3_ + "\n" + Localization.Strings.LOC_EXPERIENCE + ": " + _loc4_.currentXP + " / " + _loc4_.maxXP;
      this.SetTooltipSource(_loc6_);
   }
   function UpdateHealthBar(a_mcHealthBar)
   {
      var _loc4_ = ExternalCommands.GetValue(this.m_sCreatureToken + ".Attributes.7.Current");
      var _loc2_ = ExternalCommands.GetValue(this.m_sCreatureToken + ".Attributes.7.Total");
      a_mcHealthBar.m_ProgressBarValue.SetUpperBound(_loc2_);
      var _loc3_ = _loc4_ / _loc2_;
      a_mcHealthBar.m_ProgressBarValue.SetFromPercent(_loc3_);
   }
   function CreateAlertInitFunction(a_sAttribute, a_nAlertID)
   {
      var mcPortrait = this;
      return function()
      {
         this.gotoAndStop(1);
         MovieUtils.DisableHitTest(this);
         TokenManager.AddTokenObserverWithID(_OBSERVER_ID.PORTRAIT_ALERT_RANGE + mcPortrait.LocalIndex,a_sAttribute,function(a_sPlay)
         {
            if(a_sPlay == "1")
            {
               mcPortrait.AddAlert(a_nAlertID);
            }
            else
            {
               mcPortrait.RemoveAlert(a_nAlertID);
            }
         }
         );
      };
   }
   function OnButtonAction()
   {
   }
   function SetupManaStaminaBar()
   {
      var mcPortrait = this;
      var mcManaStaminaBar = NULL;
      var mcManaStaminaReserveBar = NULL;
      var nCurrent = ExternalCommands.GetValue(this.m_sCreatureToken + ".Attributes.8.Current",fnCurrentChanged);
      var nModifiedTotal = ExternalCommands.GetValue(this.m_sCreatureToken + ".Attributes.8.Total",fnModifiedTotalChanged);
      var nModifier = ExternalCommands.GetValue(this.m_sCreatureToken + ".AbilityUpkeepCost",fnModifierChanged);
      this.ManaStaminaBar_mc_init = function()
      {
         MovieUtils.DisableHitTest(this);
         this.m_ProgressBarValue.SetFromPercent(1);
         mcManaStaminaBar = this;
         TokenManager.AddTokenObserverWithID(_OBSERVER_ID.PORTRAIT_CLASSHASMANA_RANGE + mcPortrait.LocalIndex,mcPortrait.m_sCreatureToken + ".Stats.ClassHasMana",function(a_sHasMana)
         {
            if(a_sHasMana == 1)
            {
               if(mcManaStaminaBar.Progress_mc)
               {
                  MovieUtils.HideMovie(mcManaStaminaBar.Progress_mc.Stamina_mc);
                  MovieUtils.HideMovie(mcManaStaminaBar.Progress_mc.StaminaBackground_mc);
                  MovieUtils.ShowMovie(mcManaStaminaBar.Progress_mc.Mana_mc);
                  MovieUtils.ShowMovie(mcManaStaminaBar.Progress_mc.ManaBackground_mc);
               }
               else
               {
                  MovieUtils.HideMovie(mcManaStaminaBar.Stamina_mc);
                  MovieUtils.HideMovie(mcManaStaminaBar.StaminaBackground_mc);
                  MovieUtils.ShowMovie(mcManaStaminaBar.Mana_mc);
                  MovieUtils.ShowMovie(mcManaStaminaBar.Mana_Backgroundmc);
               }
            }
            else if(mcManaStaminaBar.Progress_mc)
            {
               MovieUtils.HideMovie(mcManaStaminaBar.Progress_mc.Mana_mc);
               MovieUtils.HideMovie(mcManaStaminaBar.Progress_mc.ManaBackground_mc);
               MovieUtils.ShowMovie(mcManaStaminaBar.Progress_mc.Stamina_mc);
               MovieUtils.ShowMovie(mcManaStaminaBar.Progress_mc.StaminaBackground_mc);
            }
            else
            {
               MovieUtils.HideMovie(mcManaStaminaBar.Mana_mc);
               MovieUtils.HideMovie(mcManaStaminaBar.ManaBackground_mc);
               MovieUtils.ShowMovie(mcManaStaminaBar.Stamina_mc);
               MovieUtils.ShowMovie(mcManaStaminaBar.StaminaBackground_mc);
            }
         }
         );
         mcPortrait.UpdateManaStaminaBar(nCurrent,nModifier,nModifiedTotal);
      };
      this.ManaStaminaBarReserved_mc_init = function()
      {
         MovieUtils.DisableHitTest(this);
         mcManaStaminaReserveBar = this;
         this.m_ProgressBarValue.SetUpperBound(20);
         this.m_ProgressBarValue.SetIntValue(0);
         TokenManager.AddTokenObserverWithID(_OBSERVER_ID.PORTRAIT_CLASSHASMANA_RESERVE_RANGE + mcPortrait.LocalIndex,mcPortrait.m_sCreatureToken + ".Stats.ClassHasMana",function(a_sHasMana)
         {
            if(a_sHasMana == 1)
            {
               if(mcManaStaminaReserveBar.Progress_mc)
               {
                  MovieUtils.HideMovie(mcManaStaminaReserveBar.Progress_mc.Stamina_mc);
                  MovieUtils.ShowMovie(mcManaStaminaReserveBar.Progress_mc.Mana_mc);
               }
               else
               {
                  MovieUtils.HideMovie(mcManaStaminaReserveBar.Stamina_mc);
                  MovieUtils.ShowMovie(mcManaStaminaReserveBar.Mana_mc);
               }
            }
            else if(mcManaStaminaReserveBar.Progress_mc)
            {
               MovieUtils.HideMovie(mcManaStaminaReserveBar.Progress_mc.Mana_mc);
               MovieUtils.ShowMovie(mcManaStaminaReserveBar.Progress_mc.Stamina_mc);
            }
            else
            {
               MovieUtils.HideMovie(mcManaStaminaReserveBar.Mana_mc);
               MovieUtils.ShowMovie(mcManaStaminaReserveBar.Stamina_mc);
            }
         }
         );
         mcPortrait.UpdateManaStaminaBar(nCurrent,nModifier,nModifiedTotal);
      };
      TokenManager.AddTokenObserverWithID(_OBSERVER_ID.PORTRAIT_MANA_CURRENT_RANGE + this.LocalIndex,this.m_sCreatureToken + ".Attributes.8.Current",function(a_nCurrent)
      {
         nCurrent = a_nCurrent;
         mcPortrait.UpdateManaStaminaBar(nCurrent,nModifier,nModifiedTotal);
         if(mcPortrait.IsTooltipDisplayed())
         {
            mcPortrait.UpdateTooltip();
         }
      }
      );
      TokenManager.AddTokenObserverWithID(_OBSERVER_ID.PORTRAIT_MANA_MODIFIED_RANGE + this.LocalIndex,this.m_sCreatureToken + ".Attributes.8.Total",function(a_nModifiedTotal)
      {
         nModifiedTotal = a_nModifiedTotal;
         mcPortrait.UpdateManaStaminaBar(nCurrent,nModifier,nModifiedTotal);
         if(mcPortrait.IsTooltipDisplayed())
         {
            mcPortrait.UpdateTooltip();
         }
      }
      );
      TokenManager.AddTokenObserverWithID(_OBSERVER_ID.PORTRAIT_MANA_MODIFIER_RANGE + this.LocalIndex,this.m_sCreatureToken + ".AbilityUpkeepCost",function(a_nModifier)
      {
         nModifier = a_nModifier;
         mcPortrait.UpdateManaStaminaBar(nCurrent,nModifier,nModifiedTotal);
         if(mcPortrait.IsTooltipDisplayed())
         {
            mcPortrait.UpdateTooltip();
         }
      }
      );
      TokenManager.AddTokenObserverWithID(_OBSERVER_ID.PORTRAIT_EXPERIENCE_RANGE + this.LocalIndex,this.m_sCreatureToken + ".Attributes.19.Total",function()
      {
         mcPortrait.UpdateTooltip();
      }
      );
   }
   function UpdateManaStaminaBar(a_nCurrent, a_nModifier, a_nModifiedTotal)
   {
      if(a_nModifier > 0)
      {
         a_nModifier = 0;
      }
      this.ManaStaminaBar_mc.m_ProgressBarValue.SetUpperBound(a_nModifiedTotal - a_nModifier);
      var _loc4_ = a_nCurrent / (a_nModifiedTotal - a_nModifier);
      this.ManaStaminaBar_mc.m_ProgressBarValue.SetFromPercent(_loc4_);
      this.ManaStaminaBarReserved_mc.m_ProgressBarValue.SetUpperBound(a_nModifiedTotal - a_nModifier);
      var _loc5_ = (- a_nModifier) / (a_nModifiedTotal - a_nModifier);
      this.ManaStaminaBarReserved_mc.m_ProgressBarValue.SetFromPercent(_loc5_);
   }
   function HealthListener(a_OldValue, a_NewValue)
   {
      var _loc3_ = ExternalCommands.GetValue(this.m_sCreatureToken + ".ID");
      if(a_NewValue.GetValue() == null)
      {
         return undefined;
      }
      if(a_NewValue.GetValue() < this.FLASHING_THRESHOLD)
      {
         this.AddAlert(this.ALERT_HEALTH_CONTINUOUS);
      }
      else
      {
         if(this.m_nPreviousHealth < this.FLASHING_THRESHOLD)
         {
            this.RemoveAlert(this.ALERT_HEALTH_SINGLE);
            this.RemoveAlert(this.ALERT_HEALTH_CONTINUOUS);
         }
         if(this.m_nPreviousHealth > a_NewValue.GetValue() && a_NewValue.GetValue() >= this.FLASHING_THRESHOLD)
         {
            if(this.m_nPreviousCreatureID == _loc3_)
            {
               this.AddAlert(this.ALERT_HEALTH_SINGLE);
            }
         }
      }
      if(a_NewValue.GetValue() <= 0)
      {
         this.RemoveAlert(this.ALERT_HEALTH_SINGLE);
         this.RemoveAlert(this.ALERT_HEALTH_CONTINUOUS);
         MovieUtils.ShowMovie(this.m_mcDeathShroud);
      }
      else if(a_NewValue.GetValue() > 0)
      {
         MovieUtils.HideMovie(this.m_mcDeathShroud);
      }
      this.m_nPreviousHealth = a_NewValue.GetValue();
      this.m_nPreviousCreatureID = _loc3_;
   }
   function AddAlert(a_nAlertID)
   {
      if(a_nAlertID == this.ALERT_HEALTH_SINGLE)
      {
         var mcPortrait = this;
         this.m_DamageAlertMC.OnFinished = function()
         {
            mcPortrait.m_DamageAlertMC.OnFinished = function()
            {
            };
            mcPortrait.RemoveAlert(a_nAlertID);
         };
      }
      this.AlertQueue.push(a_nAlertID);
      this.AlertQueue.sort();
      this.UpdateAlertMovie(this.AlertQueue[0]);
   }
   function RemoveAlert(a_nAlertID)
   {
      this.AlertQueue = this.AlertQueue.select(function(nValue)
      {
         return nValue != a_nAlertID;
      }
      );
      this.AlertQueue.sort();
      if(this.AlertQueue.length > 0)
      {
         this.UpdateAlertMovie(this.AlertQueue[0]);
      }
      else
      {
         this.UpdateAlertMovie(this.ALERT_NIL);
      }
   }
   function UpdateAlertMovie(a_nNewAlertID)
   {
      if(this.m_nCurrentAlertMovie != a_nNewAlertID)
      {
         switch(this.m_nCurrentAlertMovie)
         {
            case this.ALERT_HEALTH_SINGLE:
            case this.ALERT_HEALTH_CONTINUOUS:
               this.m_DamageAlertMC.GotoAndStop(1);
               break;
            case this.ALERT_POISON_CONTINOUS:
               this.Picture_mc.AlertPoison_mc.gotoAndStop(1);
               break;
            case this.ALERT_PARALYZE_CONTINOUS:
               this.Picture_mc.AlertParalyze_mc.gotoAndStop(1);
         }
         switch(a_nNewAlertID)
         {
            case this.ALERT_HEALTH_SINGLE:
               this.m_DamageAlertMC.GotoAndPlayForward(1);
               break;
            case this.ALERT_HEALTH_CONTINUOUS:
               this.m_DamageAlertMC.Play();
               break;
            case this.ALERT_POISON_CONTINOUS:
               this.Picture_mc.AlertPoison_mc.gotoAndPlay(1);
               break;
            case this.ALERT_PARALYZE_CONTINOUS:
               this.Picture_mc.AlertParalyze_mc.gotoAndPlay(1);
         }
         this.m_nCurrentAlertMovie = a_nNewAlertID;
      }
   }
   static function DisplayPortraitMessage(a_sArgs)
   {
      var _loc1_ = a_sArgs.split(" ");
      var _loc3_ = Number(_loc1_.shift());
      var _loc5_ = Number(_loc1_.shift());
      var _loc4_ = _loc1_.join("");
      var _loc2_ = SharedLibrary.Portrait.GetPortraitByCharacterID(_loc3_);
      _loc2_.Picture_mc.PortraitTextContainer_mc.PortraitText_mc.SetText(_loc4_);
      _loc2_.Picture_mc.PortraitTextContainer_mc.PortraitText_mc.SetTextColour(_loc5_);
      _loc2_.Picture_mc.PortraitTextContainer_mc.gotoAndPlay(1);
   }
   static function GetPortraitByCharacterID(a_nCharacterID)
   {
      if(ExternalCommands.GetValue("Party.Members.0.ID") == a_nCharacterID)
      {
         return Portraits.cm_mcPortraits.Portrait1_mc;
      }
      if(ExternalCommands.GetValue("Party.Members.1.ID") == a_nCharacterID)
      {
         return Portraits.cm_mcPortraits.Portrait2_mc;
      }
      if(ExternalCommands.GetValue("Party.Members.2.ID") == a_nCharacterID)
      {
         return Portraits.cm_mcPortraits.Portrait3_mc;
      }
      if(ExternalCommands.GetValue("Party.Members.3.ID") == a_nCharacterID)
      {
         return Portraits.cm_mcPortraits.Portrait4_mc;
      }
      if(ExternalCommands.GetValue("Party.Summons.0.ID") == a_nCharacterID)
      {
         return Portraits.cm_mcPortraits.Player1Summon_mc;
      }
      if(ExternalCommands.GetValue("Party.Summons.1.ID") == a_nCharacterID)
      {
         return Portraits.cm_mcPortraits.Player2Summon_mc;
      }
      if(ExternalCommands.GetValue("Party.Summons.2.ID") == a_nCharacterID)
      {
         return Portraits.cm_mcPortraits.Player3Summon_mc;
      }
      if(ExternalCommands.GetValue("Party.Summons.3.ID") == a_nCharacterID)
      {
         return Portraits.cm_mcPortraits.Player4Summon_mc;
      }
      return null;
   }
   function SetupCurrentCommandIndicator()
   {
      var mcPortrait = this;
      this.CurrentCommandText_mc_init = function()
      {
         MovieUtils.DisableHitTest(this);
         mcPortrait.UpdateCurrentCommand();
      };
      TokenManager.AddTokenObserverWithID(_OBSERVER_ID.PORTRAIT_PENDINGACTION_RANGE + this.LocalIndex,mcPortrait.m_sCreatureToken + ".CurrentAction",FuncUtils.Bind(this,this.UpdateCurrentCommand));
      TokenManager.AddTokenObserverWithID(_OBSERVER_ID.PORTRAIT_CURRENTACTION_RANGE + this.LocalIndex,mcPortrait.m_sCreatureToken + ".PendingAction",FuncUtils.Bind(this,this.UpdateCurrentCommand));
      this.m_bCurrentCommandVisible = false;
      this.CurrentCommand_mc_init = function()
      {
         if(!mcPortrait.m_bCurrentCommandVisible)
         {
            this.gotoAndStop(1);
         }
      };
      TokenManager.AddTokenObserverWithID(_OBSERVER_ID.PORTRAIT_ACTIONS_GMSWITCH_RANGE + this.LocalIndex,"GameModeController.CurrentGameMode",function(a)
      {
         mcPortrait.UpdateCurrentCommandVisibility(a);
      }
      );
   }
   function UpdateCurrentCommandVisibility(a_GameMode)
   {
      if(Number(ExternalCommands.GetValue("DebugOptions.SuppressPartyActionDisplay")) == 0 && a_GameMode == GUISystem.GM_COMBAT && !this.m_bCurrentCommandVisible)
      {
         this.CurrentCommand_mc.gotoAndPlay(1);
         this.m_bCurrentCommandVisible = true;
      }
      else if(a_GameMode != GUISystem.GM_COMBAT && this.m_bCurrentCommandVisible)
      {
         this.CurrentCommand_mc.gotoAndStop(1);
         this.m_bCurrentCommandVisible = false;
      }
   }
   function UpdateCurrentCommand()
   {
      currentCommandText = this.CurrentCommand_mc.CurrentCommand_Anim_mc.CurrentCommandText_mc;
      currentCommandIcon = this.CurrentCommand_mc.CurrentCommand_Anim_mc.PartyActionIconAnim_mc.Icon_mc.Icon;
      currentCommandIconAnim = this.CurrentCommand_mc.CurrentCommand_Anim_mc.PartyActionIconAnim_mc;
      currentCommandIconBackground = this.CurrentCommand_mc.CurrentCommand_Anim_mc.PartyActionIcon_Background_mc;
      var _loc3_ = "";
      var _loc2_ = "";
      _loc3_ = ExternalCommands.GetValue(this.m_sCreatureToken + ".CurrentAction");
      _loc2_ = ExternalCommands.GetValue(this.m_sCreatureToken + ".PendingAction");
      sCurrentCommandIcon = ExternalCommands.GetValue(this.m_sCreatureToken + ".CurrentActionIcon");
      sPendingCommandIcon = ExternalCommands.GetValue(this.m_sCreatureToken + ".PendingActionIcon");
      if(_loc2_ == "")
      {
         currentCommandText.SetText(_loc3_);
         if(sCurrentCommandIcon != "" && this.sCurrentImage != sCurrentCommandIcon)
         {
            MovieUtils.ShowMovie(currentCommandIconAnim);
            MovieUtils.LoadImageFixedSize(currentCommandIcon,sCurrentCommandIcon,currentCommandIcon._width,currentCommandIcon._height);
            this.sCurrentImage = sCurrentCommandIcon;
            currentCommandIconBackground.gotoAndStop(1);
            currentCommandIconAnim.gotoAndStop(1);
         }
         else if(sCurrentCommandIcon == "")
         {
            this.sCurrentImage = "";
            if(currentCommandIconBackground._currentFrame == 1)
            {
               currentCommandIconBackground.gotoAndPlay(1);
               currentCommandIconAnim.gotoAndPlay(1);
            }
         }
      }
      else
      {
         currentCommandText.SetText(_loc2_);
         if(sPendingCommandIcon != "" && this.sCurrentImage != sPendingCommandIcon)
         {
            MovieUtils.ShowMovie(currentCommandIconAnim);
            MovieUtils.LoadImageFixedSize(currentCommandIcon,sPendingCommandIcon,currentCommandIcon._width,currentCommandIcon._height);
            this.sCurrentImage = sPendingCommandIcon;
            currentCommandIconBackground.gotoAndStop(1);
            currentCommandIconAnim.gotoAndStop(1);
         }
         else if(sPendingCommandIcon == "")
         {
            this.sCurrentImage = "";
            if(currentCommandIconBackground._currentFrame == 1)
            {
               currentCommandIconBackground.gotoAndPlay(1);
            }
            currentCommandIconAnim.gotoAndPlay(1);
         }
      }
   }
}
