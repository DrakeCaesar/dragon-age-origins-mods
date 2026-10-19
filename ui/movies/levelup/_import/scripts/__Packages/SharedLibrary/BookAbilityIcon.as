class SharedLibrary.BookAbilityIcon extends SharedLibrary.AbilityIcon
{
   var AbilityIconImage_mc;
   var AddBehaviour;
   var CanPickup;
   var HostAnchor;
   var Learn_mc;
   var SetTooltipSource;
   var SimulateButtonPush;
   var TooltipAnchor;
   var TooltipType;
   var Unavailable_mc;
   var Usable_mc;
   var UseExternalDrag;
   var _parent;
   var m_DragData;
   var m_bPushButtonEnabled;
   var m_oAbility;
   var m_sAbilityInstanceToken;
   static var USETYPE_PASSIVE = 3;
   static var ABILITY_ICON_SIZE = 42;
   var m_bDraggingAndDropping = false;
   function BookAbilityIcon()
   {
      super();
      this.m_bShouldObserveCooldown = false;
   }
   function onRollOverHitArea()
   {
      super.onRollOverHitArea();
      this.m_oAbility.LoadDeferredAbilityInfo();
      AbilityScene.UpdateAbilityDescription(this.m_oAbility,_root.ability_description_mc);
   }
   function onRollOutHitArea()
   {
   }
   function DefineElement()
   {
      this.AddBehaviour(Behaviour.PushButton);
      this.AddBehaviour(Behaviour.RollOver);
      this.AddBehaviour(Behaviour.DisplayTooltip);
      if(!this.m_oAbility.bChargenMode)
      {
         this.AddBehaviour(Behaviour.DragAndDropable);
      }
   }
   function FinalizeInstance()
   {
      if(this.m_oAbility.sToken)
      {
         super.SetAbilityInstanceToken(this.m_oAbility.sToken + ".AbilityInstance");
      }
      super.FinalizeInstance();
      this.TooltipType = Behaviour.DisplayTooltip.TOOLTIP_TYPE_SIMPLE_FLOATING;
      this.HostAnchor = Behaviour.DisplayTooltip.ANCHOR_BOTTOMLEFT;
      this.TooltipAnchor = Behaviour.DisplayTooltip.ANCHOR_TOPLEFT;
      this.SetTooltipSource(this.m_oAbility.sNameStrRef);
      if(this.m_oAbility.sIcon)
      {
         MovieUtils.LoadImageFixedSize(this.AbilityIconImage_mc,this.m_oAbility.sIcon,SharedLibrary.BookAbilityIcon.ABILITY_ICON_SIZE,SharedLibrary.BookAbilityIcon.ABILITY_ICON_SIZE);
      }
      if(this.m_oAbility.bChargenMode == false && this.m_oAbility.nUseType != SharedLibrary.BookAbilityIcon.USETYPE_PASSIVE && CreatureUtils.IsQuickbarModifiable("GUI.SelectedChar"))
      {
         var mcQuickbarIcon = this;
         this.CanPickup = function()
         {
            return mcQuickbarIcon.m_oAbility.nDisplayState == 1;
         };
         this.m_DragData = new DragData();
         this.m_DragData.DragSource = this._parent;
         this.m_DragData.DragImpostorSymbol = "DragImage";
         this.m_DragData.ImpostorInitData = {ImageName:mcQuickbarIcon.m_oAbility.sIcon};
         this.m_DragData.onPickup = function()
         {
            mcQuickbarIcon.onPickup();
            mcQuickbarIcon.m_bDraggingAndDropping = true;
            mcQuickbarIcon.UpdateEnabledState();
         };
         this.m_DragData.DragAbortAttribute = "GUI.SelectedChar.ID";
         this.m_DragData.onValidDrop = function(a_DropTarget)
         {
            mcQuickbarIcon.onValidDrop(a_DropTarget);
            mcQuickbarIcon.m_bDraggingAndDropping = false;
            mcQuickbarIcon.UpdateEnabledState();
         };
         this.m_DragData.onInvalidDrop = function()
         {
            mcQuickbarIcon.onInvalidDrop();
            mcQuickbarIcon.m_bDraggingAndDropping = false;
            mcQuickbarIcon.UpdateEnabledState();
         };
         this.m_DragData.PlayDestroyAnimation = fnPlayDestroyAnimation;
         this.m_DragData.AbilityToken = this.m_sAbilityInstanceToken;
         this.m_DragData.IsQuickItem = false;
         this.m_DragData.AbilityID = mcQuickbarIcon.m_oAbility.nID;
         this.m_DragData.ItemTag = "";
         this.m_DragData.RefTemplate = "";
         this.m_DragData.ObjectID = 0;
         this.m_DragData.OwnedByBook = true;
         this.UseExternalDrag = true;
      }
      else
      {
         this.CanPickup = function()
         {
            return false;
         };
      }
      this.UpdateEnabledState();
      this.UpdateState(true);
      if(this.m_oAbility.bChargenMode && AbilityScene.HasSeededAbility && AbilityScene.HasSeededAbility(this.m_oAbility.oScene,this.m_oAbility.nID))
      {
         this.SimulateButtonPush();
      }
      if(this.IsNonCharGenAbilityIcon() == false && this.GetLocalIndex() != undefined)
      {
         var self = this;
         SharedLibrary.AbilityIcon.m_AbilityIconObservers.AddTokenObserverWithID(_OBSERVER_ID.ABILITY_ICON_STATE_RANGE + this.GetLocalIndex(),this.m_oAbility.sToken,function()
         {
            self.UpdateState(false);
         }
         );
      }
   }
   function UpdateErrorWarningState()
   {
      if(!this.m_oAbility.bChargenMode)
      {
         super.UpdateErrorWarningState();
      }
   }
   function UpdateEnabledState()
   {
      if(this.m_oAbility.bChargenMode)
      {
         if(this.m_oAbility.nDisplayState == SharedLibrary.Ability.DISPLAYSTATE_UNLOCKABLE || this.m_oAbility.nDisplayState == SharedLibrary.Ability.DISPLAYSTATE_HAVE && !AbilityScene.IsNewAbility(this.m_oAbility.oScene,this.m_oAbility.nID) && !this.m_oAbility.oScene.bLevelUp || this.m_oAbility.nDisplayState == SharedLibrary.Ability.DISPLAYSTATE_AVAILABLE && this.m_oAbility.oScene.nPointsToSpend <= 0)
         {
            this.m_bPushButtonEnabled = false;
            return undefined;
         }
      }
      else
      {
         if(this.m_bDraggingAndDropping)
         {
            this.m_bPushButtonEnabled = false;
            return undefined;
         }
         if(!this.CanPickup())
         {
            this.m_bPushButtonEnabled = false;
            return undefined;
         }
         if(this.m_bErrorWarningSet || this.m_bCoolingDown)
         {
            this.m_bPushButtonEnabled = false;
            return undefined;
         }
         if(this.m_oAbility.nDisplayState != SharedLibrary.Ability.DISPLAYSTATE_HAVE)
         {
            this.m_bPushButtonEnabled = false;
            return undefined;
         }
         if(!CreatureUtils.IsQuickbarModifiable("GUI.SelectedChar"))
         {
            this.m_bPushButtonEnabled = false;
            return undefined;
         }
      }
      this.m_bPushButtonEnabled = true;
   }
   function UpdateValidToken(a_sTokenValid)
   {
      super.UpdateValidToken(a_sTokenValid);
      this.UpdateState(false);
   }
   function UpdateState(bFirstUpdate)
   {
      if(this.m_oAbility.bChargenMode)
      {
         this.UpdateStateChargen(bFirstUpdate);
      }
      else
      {
         this.UpdateStateAbilityBook(bFirstUpdate);
      }
   }
   function UpdateStateChargen(bFirstUpdate)
   {
      var _loc0_;
      var _loc2_ = Number = this.m_oAbility.nDisplayState;
      this.m_oAbility.nDisplayState = ExternalCommands.GetNumber(this.m_oAbility.sToken + ".DisplayState");
      if(!bFirstUpdate)
      {
         if(this.m_oAbility.nDisplayState == SharedLibrary.Ability.DISPLAYSTATE_HAVE && _loc2_ != SharedLibrary.Ability.DISPLAYSTATE_HAVE)
         {
            this._parent._parent._parent.AbilityClassLabelBarContainer_mc.AdjustAffinityInfo(true);
         }
         else if(this.m_oAbility.nDisplayState != SharedLibrary.Ability.DISPLAYSTATE_HAVE && _loc2_ == SharedLibrary.Ability.DISPLAYSTATE_HAVE)
         {
            this._parent._parent._parent.AbilityClassLabelBarContainer_mc.AdjustAffinityInfo(false);
         }
      }
      switch(this.m_oAbility.nDisplayState)
      {
         case SharedLibrary.Ability.DISPLAYSTATE_HAVE:
            if(_loc2_ != SharedLibrary.Ability.DISPLAYSTATE_HAVE)
            {
               MovieUtils.ShowMovie(this.Learn_mc);
               this.Learn_mc.gotoAndPlay(1);
            }
            else
            {
               MovieUtils.HideMovie(this.Learn_mc);
            }
            if(AbilityScene.IsNewAbility(this.m_oAbility.oScene,this.m_oAbility.nID))
            {
               MovieUtils.ShowMovie(this.Usable_mc);
            }
            else
            {
               MovieUtils.HideMovie(this.Usable_mc);
            }
            MovieUtils.HideMovie(this.Unavailable_mc);
            break;
         case SharedLibrary.Ability.DISPLAYSTATE_AVAILABLE:
            if(this.m_oAbility.oScene.nPointsToSpend > 0)
            {
               MovieUtils.ShowMovie(this.Usable_mc);
            }
            else
            {
               MovieUtils.HideMovie(this.Usable_mc);
            }
            MovieUtils.ShowMovie(this.Unavailable_mc);
            MovieUtils.HideMovie(this.Learn_mc);
            break;
         case SharedLibrary.Ability.DISPLAYSTATE_UNLOCKABLE:
            MovieUtils.ShowMovie(this.Unavailable_mc);
            MovieUtils.HideMovie(this.Learn_mc);
            MovieUtils.HideMovie(this.Usable_mc);
      }
      this.UpdateEnabledState();
   }
   function UpdateStateAbilityBook(bFirstUpdate)
   {
      MovieUtils.HideMovie(this.Learn_mc);
      switch(this.m_oAbility.nDisplayState)
      {
         case SharedLibrary.Ability.DISPLAYSTATE_HAVE:
            MovieUtils.HideMovie(this.Usable_mc);
            MovieUtils.HideMovie(this.Unavailable_mc);
            break;
         case SharedLibrary.Ability.DISPLAYSTATE_AVAILABLE:
         case SharedLibrary.Ability.DISPLAYSTATE_UNLOCKABLE:
            MovieUtils.ShowMovie(this.Unavailable_mc);
            MovieUtils.HideMovie(this.Usable_mc);
      }
      this.UpdateEnabledState();
   }
   function OnButtonAction()
   {
      var _loc2_;
      if(this.m_oAbility.nDisplayState == SharedLibrary.Ability.DISPLAYSTATE_AVAILABLE)
      {
         this.m_oAbility.oScene.Learn(this);
      }
      else if(this.m_oAbility.nDisplayState == SharedLibrary.Ability.DISPLAYSTATE_HAVE && (AbilityScene.IsNewAbility(this.m_oAbility.oScene,this.m_oAbility.nID) || this.m_oAbility.oScene.bLevelUp))
      {
         this.m_oAbility.oScene.Unlearn(this);
      }
      else if(this.m_oAbility.nDisplayState == SharedLibrary.Ability.DISPLAYSTATE_HAVE && !this.m_oAbility.bChargenMode)
      {
         if(ExternalCommands.GetBool(this.m_oAbility.sToken + ".IsError") || ExternalCommands.GetNumber(this.m_oAbility.sToken + ".CooldownPercentage") != 0)
         {
            _loc2_ = ExternalCommands.GetNumber("GUI.SelectedChar.ID");
            if(CreatureUtils.IsInParty(_loc2_) != false)
            {
               ExternalCommands.SendMessageArgs("GameModeController.PerformAbility",this.m_oAbility.nID,_loc2_,0);
            }
            else
            {
               ExternalCommands.PlayGUISound(SoundEvents.ST_ERROR,"Click");
            }
         }
      }
   }
   function OnDoubleClickAction()
   {
   }
   function OnSecondaryButtonAction()
   {
   }
   function onValidDrop(a_DropTarget)
   {
      MovieUtils.HideMovie(_root.IconDestroyDropTarget_mc);
   }
   function GetRolloverCursor()
   {
      if(this.m_oAbility.bChargenMode == false && this.m_oAbility.nUseType != SharedLibrary.BookAbilityIcon.USETYPE_PASSIVE && this.m_oAbility.nDisplayState == SharedLibrary.Ability.DISPLAYSTATE_HAVE)
      {
         return "hand";
      }
      return "standard";
   }
   function GetRolloverPressedCursor()
   {
      if(this.m_oAbility.bChargenMode == false && this.m_oAbility.nUseType != SharedLibrary.BookAbilityIcon.USETYPE_PASSIVE && this.m_oAbility.nDisplayState == SharedLibrary.Ability.DISPLAYSTATE_HAVE)
      {
         return "hand2";
      }
      return "standard_pressed";
   }
   function GetLocalIndex()
   {
      return this.m_oAbility.nLocalIndex;
   }
}
