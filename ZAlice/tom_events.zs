class ToM_Mainhandler : EventHandler
{
	
	static bool IsVoodooDoll(PlayerPawn mo) 
	{
		return !mo.player || !mo.player.mo || mo.player.mo != mo;
	}
	
	void GiveStartingItems(int playerNumber)
	{
		if (!PlayerInGame[playerNumber])
			return;
		let plr = players[playerNumber].mo;
		if (!plr)
			return;
		if (IsVoodooDoll(plr))
			return;
		plr.GiveInventory("ToM_CrosshairSpawner", 1);
		plr.GiveInventory("ToM_InvReplacementControl", 1);
		//plr.GiveInventory("ToM_KickWeapon", 1);
	}
	
	override void WorldThingDamaged(worldEvent e)
	{
		if (e.thing && e.Inflictor && e.Inflictor.GetClass() == 'ToM_TeaProjectile')
		{
			e.thing.GiveInventory("ToM_TeaBurnControl", 1);
			if (tom_debugmessages > 0)
				console.printf("%s is damaged by %s", e.thing.GetClassName(), e.inflictor.GetClassName());
		}
	}
	
	override void PlayerSpawned(PlayerEvent e)
	{
		GiveStartingItems(e.PlayerNumber);
	}
	
	override void PlayerRespawned(PlayerEvent e)
	{
		GiveStartingItems(e.PlayerNumber);
	}
	
	override void CheckReplacement (replaceEvent e)
	{
		let clsname = e.Replacee.GetClassName();
		switch (clsname)
		{
		case 'Chainsaw':			e.Replacement = "ToM_HobbyHorse"; break;
		case 'Pistol':				e.Replacement = "ToM_Cards"; break;
		case 'Shotgun':			e.Replacement = "ToM_Cards"; break;
		case 'SuperShotgun':		e.Replacement = "ToM_Cards"; break;
		case 'RocketLauncher':	e.Replacement = "ToM_Teapot"; break;
		case 'PlasmaRifle':		e.Replacement = "ToM_Eyestaff"; break;
		case 'BFG9000':			e.Replacement = "ToM_Blunderbuss"; break;
		}
	}
}