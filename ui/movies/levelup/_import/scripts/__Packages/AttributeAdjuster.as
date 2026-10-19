class AttributeAdjuster extends GUI.Element
{
   var ActionOnPress;
   var AddBehaviour;
   var DelayBeforeRepeatAction;
   var HostAnchor;
   var Label_mc;
   var MaxTooltipWidth;
   var Minus_mc_init;
   var Modifier_mc;
   var OnButtonAction;
   var Plus_mc_init;
   var PointsLabel_mc;
   var RepeatActionWhilePressed;
   var SetTooltipSource;
   var SetupInputCallbacks;
   var TooltipAnchor;
   var TooltipType;
   var _parent;
   var m_bHideRollOverOnDown;
   var nBase;
   var nID;
   var sDescription;
   var sName;
   function AttributeAdjuster()
   {
      super();
   }
   static function GetModifier(n)
   {
      return n >= 10 ? n - 10 : 0;
   }
   function SpendPoint()
   {
      this.UpdatePointsLabel();
      AttributesScene.SpendPoints(this.nID,1);
   }
   function RefundPoint()
   {
      this.UpdatePointsLabel();
      AttributesScene.RefundPoints(this.nID,1);
   }
   function UpdatePointsLabel()
   {
      this.PointsLabel_mc.SetText("" + this.nBase);
      this.Modifier_mc.SetText(AttributeAdjuster.GetModifier(this.nBase));
   }
   function DefineElement()
   {
      this.AddBehaviour(Behaviour.DisplayTooltip);
      this.HostAnchor = Behaviour.DisplayTooltip.ANCHOR_TOPRIGHT;
      this.TooltipAnchor = Behaviour.DisplayTooltip.ANCHOR_TOPLEFT;
      this.TooltipType = Behaviour.DisplayTooltip.TOOLTIP_TYPE_MULTILINE_FLOATING;
      this.MaxTooltipWidth = 200;
   }
   function GetBaseValue()
   {
      var _loc2_ = "CharGenCreature.Attributes." + this.nID;
      var _loc3_ = Number(ExternalCommands.GetValue(_loc2_ + ".Total"));
      var _loc4_ = Number(ExternalCommands.GetValue(_loc2_ + ".Modifier"));
      return _loc3_ - _loc4_;
   }
   function FinalizeInstance()
   {
      this.SetupInputCallbacks();
      this.Label_mc.SetText(this.sName);
      var self = this;
      TokenManager.AddTokenObserverWithID(_OBSERVER_ID.ATTRIBUTE_ADJUSTER_RANGE + self.nID,"CharGenCreature.Attributes." + self.nID + ".Total",function()
      {
         self.nBase = self.GetBaseValue();
         self.UpdatePointsLabel();
      }
      );
      this.UpdatePointsLabel();
      this.Minus_mc_init = function()
      {
         this.m_bHideRollOverOnDown = true;
         this.ActionOnPress = true;
         this.RepeatActionWhilePressed = true;
         this.DelayBeforeRepeatAction = true;
         FuncUtils.ChainFunction(this,"onRollOverHitArea",function()
         {
            AttributesScene.SetDescriptionText(this._parent.sName,this._parent.sDescription);
         }
         );
         this.OnButtonAction = function()
         {
            if(AttributesScene.PointsSpentOnAttribute(this._parent.nID) > 0 && AttributesScene.CanRemovePoint(this._parent.nID))
            {
               this._parent.RefundPoint();
            }
         };
      };
      this.Plus_mc_init = function()
      {
         this.m_bHideRollOverOnDown = true;
         this.ActionOnPress = true;
         this.RepeatActionWhilePressed = true;
         this.DelayBeforeRepeatAction = true;
         FuncUtils.ChainFunction(this,"onRollOverHitArea",function()
         {
            AttributesScene.SetDescriptionText(this._parent.sName,this._parent.sDescription);
         }
         );
         this.OnButtonAction = function()
         {
            if(AttributesScene.CanAddMore(AttributesScene.PointsSpentOnAttribute(this._parent.nID)))
            {
               this._parent.SpendPoint();
            }
         };
      };
      this.SetTooltipSource(this.sDescription);
   }
}
