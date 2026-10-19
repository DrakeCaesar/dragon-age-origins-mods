class SpellsTalentsScene extends AbilityScene
{
   var Header_mc_init;
   var Icon_mc_init;
   var OnButtonAction;
   var Scrollable_mc_init;
   var SetGrowUpward;
   var SetMaxHeight;
   var SetText;
   var Text_mc_init;
   var _height;
   var gotoAndPlay;
   var header_txt_mc_init;
   var next_mc_init;
   var points_available_label_mc_init;
   var pointsleft_mc_init;
   var previous_mc_init;
   static var nPointsToSpend = -1;
   static var bWeHadPointsInitially = null;
   static var aStoredPoints = new Array();
   static var aStoredPrereqs = new Array();
   static var aSeededAbilities = new Array();
   static var aUnlearnedPoints;
   static var nInitialPoints = -1;
   static var nType = 0;
   static var mcPointsLeft = null;
   static var bLevelUp = false;
   static var parentClass = null;
   function SpellsTalentsScene()
   {
      super();
   }
   static function Initialize(levelUp, parent)
   {
      SpellsTalentsScene.bLevelUp = levelUp;
      SpellsTalentsScene.parentClass = parent;
      SpellsTalentsScene.aUnlearnedPoints = new Array();
      SpellsTalentsScene.nInitialPoints = -1;
      if(levelUp)
      {
         SpellsTalentsScene.nInitialPoints = Number(ExternalCommands.GetValue("CharGenCreature.Attributes.36.Total"));
      }
      _root.SpellsTalents_header_mc_init = function()
      {
         if(SpellsTalentsScene.nType == CharGen.SPELLS)
         {
            this.header_txt_mc_init = function()
            {
               this.SetText(Localization.Strings.LOC_HEADER_SPELLS);
            };
         }
         else if(SpellsTalentsScene.nType == CharGen.TALENTS)
         {
            this.header_txt_mc_init = function()
            {
               this.SetText(Localization.Strings.LOC_HEADER_TALENTS);
            };
         }
      };
      if(SpellsTalentsScene.bLevelUp)
      {
         _root.spellsTalentsBackground_mc_init = function()
         {
            if(SpellsTalentsScene.nType == CharGen.SPELLS)
            {
               this.gotoAndPlay(1);
            }
            else
            {
               this.gotoAndPlay(2);
            }
         };
         _root.spellsTalentsIcon_mc_init = function()
         {
            if(SpellsTalentsScene.nType == CharGen.SPELLS)
            {
               this.gotoAndPlay(1);
            }
            else
            {
               this.gotoAndPlay(2);
            }
         };
      }
      _root.SpellConceptArt_mc_init = function()
      {
         if(SpellsTalentsScene.nType == CharGen.TALENTS)
         {
            MovieUtils.HideMovie(this);
         }
      };
      _root.TalentConceptArt_mc_init = function()
      {
         if(SpellsTalentsScene.nType == CharGen.SPELLS)
         {
            MovieUtils.HideMovie(this);
         }
      };
      _root.ability_description_mc_init = function()
      {
         this.Text_mc_init = function()
         {
            this.SetText(Localization.Strings.LOC_NO_ABILITY_SELECTED);
         };
         this.Header_mc_init = function()
         {
            this.SetMaxHeight(this._height * 2);
            this.SetGrowUpward(true);
            MovieUtils.HideMovie(this);
         };
         this.Icon_mc_init = function()
         {
            MovieUtils.HideMovie(this);
         };
      };
      _root.spellstalents_points_mc_init = function()
      {
         this.points_available_label_mc_init = function()
         {
            if(!SpellsTalentsScene.bLevelUp)
            {
               this.SetText(Localization.Strings.LOC_POINTS_TO_SPEND);
            }
            else if(SpellsTalentsScene.nType == CharGen.SPELLS)
            {
               this.SetText(Localization.Strings.LOC_HEADER_SPELLS);
            }
            else
            {
               this.SetText(Localization.Strings.LOC_HEADER_TALENTS);
            }
         };
         this.pointsleft_mc_init = function()
         {
            SpellsTalentsScene.mcPointsLeft = this;
            AbilityScene.UpdatePointsToSpend(SpellsTalentsScene);
         };
      };
      _root.SpellsTalents_nav_mc_init = function()
      {
         this.previous_mc_init = function()
         {
            this.SetText(Localization.Strings.LOC_PREVIOUS);
            this.OnButtonAction = function()
            {
               SpellsTalentsScene.parentClass.GoingForward = false;
               SpellsTalentsScene.SkipScene();
            };
         };
         this.next_mc_init = function()
         {
            var _loc2_ = ExternalCommands.GetValue("GUICharGen.CharCreatorRunning");
            if(_loc2_ == true)
            {
               this.SetText(Localization.Strings.LOC_DONE);
            }
            else
            {
               this.SetText(Localization.Strings.LOC_PLAY);
            }
            AbilityScene.mcNextButton = this;
            AbilityScene.CheckNextButtonEnable(SpellsTalentsScene);
            this.OnButtonAction = function()
            {
               SpellsTalentsScene.parentClass.GoingForward = true;
               SpellsTalentsScene.SkipScene();
            };
         };
      };
      _root.learnSpellTalent_mc_init = function()
      {
         this.SetText(Localization.Strings.LOC_LEARN);
         this.OnButtonAction = function()
         {
            SpellsTalentsScene.Learn();
         };
      };
      _root.clearSpellsTalents_mc_init = function()
      {
         this.SetText(Localization.Strings.LOC_CLEAR);
         this.OnButtonAction = function()
         {
            SpellsTalentsScene.ClearLearned(true);
         };
      };
      _root.ScrollingAbilities_mc_init = function()
      {
         this.Scrollable_mc_init = function()
         {
            AbilityScene.SendAbilityChainsRequest(SpellsTalentsScene);
            var scrollable = this;
            var _loc3_;
            if(SpellsTalentsScene.nType == CharGen.SPELLS)
            {
               scrollable.LoadAbilityContainers(SpellsTalentsScene.nType,"CharGenCreature.Stats.SpellChains",true,SpellsTalentsScene);
            }
            else if(SpellsTalentsScene.nType == CharGen.TALENTS)
            {
               scrollable.LoadAbilityContainers(SpellsTalentsScene.nType,"CharGenCreature.Stats.TalentChains",true,SpellsTalentsScene);
            }
            _root.onEnterFrame = function()
            {
               scrollable.UpdateLayout();
               scrollable.UpdateScrollValues();
               _root.onEnterFrame = function()
               {
               };
            };
         };
      };
      _root.AbilityTooltip_mc_init = function()
      {
         MovieUtils.HideMovie(this);
         MovieUtils.DisableHitTest(this);
      };
   }
   static function SkipScene()
   {
      var _loc1_;
      if(SpellsTalentsScene.parentClass.GoingForward)
      {
         _loc1_ = ExternalCommands.GetValue("GUICharGen.CharCreatorRunning");
         if(!SpellsTalentsScene.bLevelUp)
         {
            if(_loc1_ == true)
            {
               CharGen.CompleteChargen(CharGen.CHARGEN_EXIT_ADVANCED);
               SceneManager.PlayScene("Review");
            }
            else
            {
               CharGen.PromptDifficulty(CharGen.CHARGEN_EXIT_ADVANCED);
            }
         }
         else
         {
            LevelUp.nExitPoint = LevelUp.LEVELUP_EXIT_COMPLETE;
            ExternalCommands.SendMessage("GUI.HideFullScreenGUI");
         }
      }
      else
      {
         if(!SpellsTalentsScene.bLevelUp)
         {
            AbilityScene.RevertPoints(SpellsTalentsScene,false);
         }
         SceneManager.PlayScene("Skills");
      }
   }
   static function StartScene()
   {
      var _loc5_ = Number(ExternalCommands.GetValue("CharGenCreature.Attributes.27.Total"));
      var _loc6_ = Number(ExternalCommands.Get2DAValue(_2DA.TABLE_CLASS,_loc5_,_2DA.HASH_BUSESMANA)) == 1;
      if(_loc6_)
      {
         SpellsTalentsScene.nType = CharGen.SPELLS;
      }
      else
      {
         SpellsTalentsScene.nType = CharGen.TALENTS;
      }
      SharedLibrary.AbilityIcon.m_AbilityIconObservers.RemoveAllTokenObservers();
      if(!(SpellsTalentsScene.bLevelUp && SpellsTalentsScene.nType == CharGen.SPELLS))
      {
         MovieUtils.HideMovie(_root.DecorativeSpells_mc);
      }
      if(!(SpellsTalentsScene.bLevelUp && SpellsTalentsScene.nType == CharGen.TALENTS))
      {
         MovieUtils.HideMovie(_root.DecorativeTalents_mc);
      }
      AbilityScene.ClearAbilityDescription(_root.ability_description_mc);
      SpellsTalentsScene.nPointsToSpend = Number(ExternalCommands.GetValue("CharGenCreature.Attributes.36.Total"));
      var _loc4_;
      var _loc3_;
      var _loc2_;
      if(SpellsTalentsScene.bWeHadPointsInitially == null)
      {
         SpellsTalentsScene.bWeHadPointsInitially = SpellsTalentsScene.nPointsToSpend > 0;
         if(OtherImportScene.UseSeeds)
         {
            _loc4_ = "Paperdoll.SeededCharacters." + OtherImportScene.HeroIndex;
            _loc3_ = Number(ExternalCommands.GetNumMembers(_loc4_ + ".Abilities"));
            trace("seeded abilities found : " + _loc3_);
            _loc2_ = 0;
            while(_loc2_ < _loc3_)
            {
               SpellsTalentsScene.aSeededAbilities.push(Number(ExternalCommands.GetValue(_loc4_ + ".Abilities." + _loc2_)));
               _loc2_ = _loc2_ + 1;
            }
         }
      }
      if(!SpellsTalentsScene.bWeHadPointsInitially && !SpellsTalentsScene.bLevelUp)
      {
         SpellsTalentsScene.SkipScene();
      }
      else if(SpellsTalentsScene.bLevelUp)
      {
         AbilityScene.SendAbilityChainsRequest(SpellsTalentsScene);
         var nSpellChains = Number(ExternalCommands.GetNumMembers("CharGenCreature.Stats.SpellChains"));
         var nTalentChains = Number(ExternalCommands.GetNumMembers("CharGenCreature.Stats.TalentChains"));
         if(nSpellChains + nTalentChains == 0)
         {
            SpellsTalentsScene.SkipScene();
         }
      }
   }
   static function Learn(a_mcAbility)
   {
      if(a_mcAbility.m_oAbility.nDisplayState == SharedLibrary.Ability.DISPLAYSTATE_AVAILABLE)
      {
         AbilityScene.SpendPoint(SpellsTalentsScene,a_mcAbility.m_oAbility.nID,a_mcAbility.m_oAbility.nPrereqAbilityID);
      }
   }
   static function Unlearn(a_mcAbility)
   {
      if(a_mcAbility.m_oAbility.nDisplayState == SharedLibrary.Ability.DISPLAYSTATE_HAVE && (AbilityScene.IsNewAbility(SpellsTalentsScene,a_mcAbility.m_oAbility.nID) || SpellsTalentsScene.bLevelUp))
      {
         AbilityScene.UnspendPoint(SpellsTalentsScene,a_mcAbility.m_oAbility.nID);
      }
   }
   static function ClearLearned(a_bSendAbilityChainsRequest)
   {
      AbilityScene.RevertPoints(SpellsTalentsScene,a_bSendAbilityChainsRequest);
   }
}
