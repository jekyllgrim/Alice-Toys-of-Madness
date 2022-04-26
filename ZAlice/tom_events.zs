class ToM_Mainhandler : EventHandler
{
	override void WorldThingDamaged(worldEvent e)
	{
		if (e.thing && e.Inflictor && e.Inflictor.GetClass() == 'ToM_TeaProjectile')
		{
			e.thing.GiveInventory("ToM_TeaBurnControl", 1);
			if (tom_debugmessages > 0)
				console.printf("%s is damaged by %s", e.thing.GetClassName(), e.inflictor.GetClassName());
		}
	}
	
	static bool IsVoodooDoll(PlayerPawn mo) 
	{
		return !mo.player || !mo.player.mo || mo.player.mo != mo;
	}
}