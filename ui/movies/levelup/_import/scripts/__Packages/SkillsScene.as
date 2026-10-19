class SkillsScene extends AbilityScene
{
   var Header_mc_init;
   var Icon_mc_init;
   var OnButtonAction;
   var Scrollable_mc_init;
   var SetGrowUpward;
   var SetMaxHeight;
   var SetText;
   var Spacing;
   var Text_mc_init;
   var _height;
   var header_txt_mc_init;
   var next_mc_init;
   var points_available_label_mc_init;
   var pointsleft_mc_init;
   var previous_mc_init;
   static var nPointsToSpend = -1;
   static var aStoredPoints = new Array();
   static var aStoredPrereqs = new Array();
   static var aSeededAbilities = new Array();
   static var aUnlearnedPoints;
   static var nInitialPoints = -1;
   static var nType = CharGen.SKILLS;
   static var mcPointsLeft = null;
   static var bLevelUp = false;
   static var parentClass = null;
   static var bWeHadPointsInitially = null;
   function SkillsScene()
   {
      super();
   }
   static function Initialize(levelUp, parent)
   {
      SkillsScene.bLevelUp = levelUp;
      SkillsScene.parentClass = parent;
      SkillsScene.aUnlearnedPoints = new Array();
      SkillsScene.nInitialPoints = -1;
      if(levelUp)
      {
         SkillsScene.nInitialPoints = Number(ExternalCommands.GetValue("CharGenCreature.Attributes.35.Total"));
      }
      _root.Skills_header_mc_init = function()
      {
         this.header_txt_mc_init = function()
         {
            this.SetText(Localization.Strings.LOC_HEADER_SKILLS);
         };
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
      _root.skills_points_mc_init = function()
      {
         this.points_available_label_mc_init = function()
         {
            if(!SkillsScene.bLevelUp)
            {
               this.SetText(Localization.Strings.LOC_POINTS_TO_SPEND);
            }
            else
            {
               this.SetText(Localization.Strings.LOC_HEADER_SKILLS);
            }
         };
         this.pointsleft_mc_init = function()
         {
            SkillsScene.mcPointsLeft = this;
            AbilityScene.UpdatePointsToSpend(SkillsScene);
         };
      };
      _root.skills_category_mc_init = function()
      {
         this.SetText(Localization.Strings.LOC_HEADER_SKILLS);
      };
      _root.learnSkill_mc_init = function()
      {
         this.SetText(Localization.Strings.LOC_LEARN);
         this.OnButtonAction = function()
         {
            SkillsScene.Learn();
         };
      };
      _root.clearSkills_mc_init = function()
      {
         this.SetText(Localization.Strings.LOC_CLEAR);
         this.OnButtonAction = function()
         {
            SkillsScene.ClearLearned(true);
         };
      };
      _root.Skills_nav_mc_init = function()
      {
         this.previous_mc_init = function()
         {
            this.SetText(Localization.Strings.LOC_PREVIOUS);
            this.OnButtonAction = function()
            {
               SkillsScene.parentClass.GoingForward = false;
               SkillsScene.SkipScene();
            };
         };
         this.next_mc_init = function()
         {
            this.SetText(Localization.Strings.LOC_NEXT);
            AbilityScene.mcNextButton = this;
            AbilityScene.CheckNextButtonEnable(SkillsScene);
            this.OnButtonAction = function()
            {
               SkillsScene.parentClass.GoingForward = true;
               SkillsScene.SkipScene();
            };
         };
      };
      _root.ScrollingSkills_mc_init = function()
      {
         this.Scrollable_mc_init = function()
         {
            var scrollable = this;
            scrollable.AddBehaviour(Behaviour.ListLayout);
            scrollable.AddBehaviour(Behaviour.Scrollable);
            this.Spacing = AbilityScene.nAbilityChainSpacing;
            AbilityScene.SendAbilityChainsRequest(SkillsScene);
            var _loc6_ = "CharGenCreature.Stats.SkillChains";
            var _loc7_ = Number(ExternalCommands.GetNumMembers(_loc6_));
            var _loc3_ = 0;
            var _loc5_;
            var _loc4_;
            while(_loc3_ < _loc7_)
            {
               _loc5_ = _loc6_ + "." + _loc3_;
               _loc4_ = SharedLibrary.Ability.LoadFromToken(_loc5_,true);
               _loc4_.oScene = SkillsScene;
               _loc4_.nLocalIndex = _loc3_;
               scrollable.AddAbility(_loc4_);
               _loc3_ = _loc3_ + 1;
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
      if(SkillsScene.parentClass.GoingForward)
      {
         SceneManager.PlayScene("SpellsTalents");
      }
      else
      {
         if(!SkillsScene.bLevelUp)
         {
            AbilityScene.ResetPoints(SkillsScene,false);
         }
         SceneManager.PlayScene("Attributes");
      }
   }
   static function StartScene()
   {
      AbilityScene.ClearAbilityDescription(_root.ability_description_mc);
      SharedLibrary.AbilityIcon.m_AbilityIconObservers.RemoveAllTokenObservers();
      SkillsScene.nPointsToSpend = Number(ExternalCommands.GetValue("CharGenCreature.Attributes.35.Total"));
      var _loc4_;
      var _loc3_;
      var _loc2_;
      if(SkillsScene.bWeHadPointsInitially == null)
      {
         SkillsScene.bWeHadPointsInitially = SkillsScene.nPointsToSpend > 0;
         if(OtherImportScene.UseSeeds)
         {
            _loc4_ = "Paperdoll.SeededCharacters." + OtherImportScene.HeroIndex;
            _loc3_ = Number(ExternalCommands.GetNumMembers(_loc4_ + ".Abilities"));
            trace("seeded abilities found : " + _loc3_);
            _loc2_ = 0;
            while(_loc2_ < _loc3_)
            {
               SkillsScene.aSeededAbilities.push(Number(ExternalCommands.GetValue(_loc4_ + ".Abilities." + _loc2_)));
               _loc2_ = _loc2_ + 1;
            }
         }
      }
      if(!SkillsScene.bWeHadPointsInitially && !SkillsScene.bLevelUp)
      {
         SkillsScene.SkipScene();
      }
      else if(SkillsScene.bLevelUp)
      {
         AbilityScene.SendAbilityChainsRequest(SkillsScene);
         if(Number(ExternalCommands.GetNumMembers("CharGenCreature.Stats.SkillChains")) == 0)
         {
            SkillsScene.SkipScene();
         }
      }
   }
   static function Learn(a_mcAbility)
   {
      if(a_mcAbility.m_oAbility.nDisplayState == SharedLibrary.Ability.DISPLAYSTATE_AVAILABLE)
      {
         AbilityScene.SpendPoint(SkillsScene,a_mcAbility.m_oAbility.nID,a_mcAbility.m_oAbility.nPrereqAbilityID);
      }
   }
   static function Unlearn(a_mcAbility)
   {
      if(a_mcAbility.m_oAbility.nDisplayState == SharedLibrary.Ability.DISPLAYSTATE_HAVE && (AbilityScene.IsNewAbility(SkillsScene,a_mcAbility.m_oAbility.nID) || SkillsScene.bLevelUp))
      {
         AbilityScene.UnspendPoint(SkillsScene,a_mcAbility.m_oAbility.nID);
      }
   }
   static function ClearLearned(a_bSendAbilityChainsRequest)
   {
      AbilityScene.RevertPoints(SkillsScene,a_bSendAbilityChainsRequest);
   }
}
