class ClassButton extends GUI.Element
{
   var Down_mc;
   var Grey_mc;
   var HostAnchor;
   var Icon_mc;
   var MaxTooltipWidth;
   var SetTooltipSource;
   var Text_mc;
   var TooltipAnchor;
   var TooltipType;
   var _visible;
   var bGrey;
   var bSelected;
   var nSpecializationAbilityID;
   var sDescription;
   var sIcon;
   var sName;
   var sAchievement = null;
   function ClassButton()
   {
      super();
   }
   function DefineElement()
   {
      super.DefineElement();
      this.AddBehaviour(Behaviour.RollOver);
      this.AddBehaviour(Behaviour.DisplayTooltip);
      this.HostAnchor = Behaviour.DisplayTooltip.ANCHOR_TOPLEFT;
      this.TooltipAnchor = Behaviour.DisplayTooltip.ANCHOR_TOPRIGHT;
      this.TooltipType = Behaviour.DisplayTooltip.TOOLTIP_TYPE_MULTILINE_FLOATING;
      this.MaxTooltipWidth = 200;
   }
   function FinalizeInstance()
   {
      this.SetupInputCallbacks();
      this.Text_mc.SetText(this.sName);
      MovieUtils.LoadImageFixedSize(this.Icon_mc,this.sIcon,56,56);
      this.UpdateGrey();
      if(this.bSelected)
      {
         MovieUtils.ShowMovie(this.Down_mc);
      }
      else
      {
         MovieUtils.HideMovie(this.Down_mc);
      }
      var _loc3_ = "";
      if(this._visible && !(DAExternalCommands.HasAchievement(this.sAchievement) || this.bSelected))
      {
         _loc3_ = "<font color=\'#" + ColorDefines.FAILED_REQUIREMENT_TEXT_RED_ON_DARK.toString(16) + "\'>" + Localization.Strings.LOC_NOT_YET_UNLOCKED + "</font>\r";
      }
      var _loc4_ = Number(ExternalCommands.Get2DAValue(_2DA.TABLE_ABI_BASE,this.nSpecializationAbilityID,_2DA.HASH_PREREQLEVEL));
      var _loc6_ = Number(ExternalCommands.Get2DAValue(_2DA.TABLE_ABI_BASE,this.nSpecializationAbilityID,_2DA.HASH_PREREQATTRIBUTE));
      var _loc5_ = Number(ExternalCommands.Get2DAValue(_2DA.TABLE_ABI_BASE,this.nSpecializationAbilityID,_2DA.HASH_PREREQATTVALUE));
      var _loc2_ = SharedLibrary.Ability.SpecializationAbilityRequirements(_loc4_,_loc6_,_loc5_,"GUI.SelectedChar",ColorDefines.FAILED_REQUIREMENT_TEXT_RED_ON_DARK);
      if(_loc2_ != "" || _loc3_ != "")
      {
         _loc2_ += "\r";
      }
      this.sDescription = this.sName + "\r\r" + _loc3_ + _loc2_ + this.sDescription;
      this.SetTooltipSource(this.sDescription);
   }
   function UpdateGrey()
   {
      if(this.bGrey)
      {
         MovieUtils.ShowMovie(this.Grey_mc);
      }
      else
      {
         MovieUtils.HideMovie(this.Grey_mc);
      }
   }
   function UpdateSelected()
   {
      trace("### UpdateSelected: " + this.bSelected);
      if(this.bSelected)
      {
         MovieUtils.ShowMovie(this.Down_mc);
      }
      else
      {
         MovieUtils.HideMovie(this.Down_mc);
      }
   }
   function onPressHitArea()
   {
      if(!this.bGrey)
      {
         if(this.bSelected)
         {
            if(!LevelUp.HasAbilityRequiringSpec(this.nSpecializationAbilityID))
            {
               LevelUp.UnspendSpecializationPoint(this.nSpecializationAbilityID);
            }
         }
         else if(!this.bSelected && LevelUp.nSpecializationPoints > 0)
         {
            LevelUp.SpendSpecializationPoint(this.nSpecializationAbilityID);
         }
      }
   }
}
