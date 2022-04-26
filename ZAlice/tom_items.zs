class ToM_InventoryToken : Inventory abstract 
{
	mixin ToM_Math;
	protected int age;
	protected transient CVar s_particles;
	Default 
	{
		+INVENTORY.UNDROPPABLE;
		+INVENTORY.UNTOSSABLE;
		+INVENTORY.PERSISTENTPOWER;
		inventory.amount 1;
		inventory.maxamount 1;
	}
	override void DoEffect() 
	{
		super.DoEffect();
		if (!owner || (owner.player && ToM_Mainhandler.IsVoodooDoll(PlayerPawn(owner)))) {
			Destroy();
			return;
		}
		if (owner && !owner.isFrozen())
			age++;
	}
	override void Tick() {}
}