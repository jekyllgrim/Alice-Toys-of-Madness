class ToM_Mainhandler : EventHandler
{
	ToM_HUDFaceController HUDfaces[MAXPLAYERS];
	array < Class<Weapon> > mapweapons;
	
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
		plr.GiveInventory("ToM_KickWeapon", 1);
	}
	
	override void WorldThingSpawned(worldEvent e)
	{
		if (e.thing && (e.thing is 'Weapon'))
		{
			let weap = (class<Weapon>)(e.thing.GetClass());
			if (weap)
			{
				if (mapweapons.Find(weap) == mapweapons.Size())
					mapweapons.Push(weap);
			}
		}
	}
	
	override void WorldThingDamaged(worldEvent e)
	{
		if (e.thing && e.Inflictor && e.Inflictor.GetClass() == 'ToM_TeaProjectile')
		{
			let cont = ToM_TeaBurnControl(e.thing.FindInventory("ToM_TeaBurnControl"));
			if (cont)
				cont.ResetTimer();
			else
				e.thing.GiveInventory("ToM_TeaBurnControl", 1);
			//if (tom_debugmessages > 0)
				//console.printf("%s is damaged by %s", e.thing.GetClassName(), e.inflictor.GetClassName());
		}
	}
	
	override void PlayerSpawned(PlayerEvent e)
	{
		GiveStartingItems(e.PlayerNumber);
		
		// Spawn HUD face controller for every player:
		int pn = e.PlayerNumber;
		if (!PlayerInGame[pn])
			return;
		let pmo = players[pn].mo;
		if (!pmo)
			return;
		let fc = ToM_HUDFaceController(Actor.Spawn("ToM_HUDFaceController", (0,0,0)));
		if (fc)
		{
			HUDfaces[e.PlayerNumber] = fc;
			fc.HPlayer = players[pn];
			fc.HPlayerPawn = pmo;
		}
	}
	
	override void PlayerRespawned(PlayerEvent e)
	{
		GiveStartingItems(e.PlayerNumber);
	}
	
	override void PlayerDied(playerEvent e)
	{
		if (!PlayerInGame[e.PlayerNumber])
			return;
		PlayerInfo player = players[e.PlayerNumber];				
		if (player) 
		{
			for (int i = 1000; i > 0; i--)
				player.SetPSprite(i,null);
			for (int i = -1000; i < 0; i++)
				player.SetPSprite(i,null);
		}
	}
	
	override void CheckReplacement (replaceEvent e)
	{
		let clsname = e.Replacee.GetClassName();
		switch (clsname)
		{
		case 'Chainsaw':
			e.Replacement = "ToM_HobbyHorse"; 
			break;
		case 'Pistol':
			e.Replacement = "ToM_Cards"; 
			break;
		case 'Shotgun':
			e.Replacement = "ToM_Cards"; 
			break;
		case 'SuperShotgun':
			e.Replacement = "ToM_Jacks"; 
			break;
		case 'Chaingun':
			e.Replacement = "ToM_PepperGrinder"; 
			break;
		case 'RocketLauncher':
			e.Replacement = "ToM_Teapot"; 
			break;
		case 'PlasmaRifle':
			e.Replacement = "ToM_Eyestaff"; 
			break;
		case 'BFG9000':
			e.Replacement = "ToM_Blunderbuss"; 
			break;
			
		case 'GreenArmor':
			e.Replacement = "ToM_SilverArmor"; 
			break;
		case 'BlueArmor':
			e.Replacement = "ToM_GoldArmor"; 
			break;
		case 'HealthBonus':
			e.Replacement = "ToM_HealthBonus"; 
			break;
		case 'Stimpack':
			e.Replacement = "ToM_Stimpack"; 
			break;
		case 'Medikit':
			e.Replacement = "ToM_Medikit"; 
			break;
		case 'Soulsphere':
			e.Replacement = "ToM_Soulsphere"; 
			break;
		case 'Megasphere':
			e.Replacement = "ToM_Megasphere"; 
			break;

		case 'Clip':
			e.Replacement = "ToM_EquipmentSpawner_Clip"; 
			break;
		case 'ClipBox':
			e.Replacement = "ToM_EquipmentSpawner_ClipBox"; 
			break;
		case 'Shell':
			e.Replacement = "ToM_EquipmentSpawner_Shell"; 
			break;
		case 'ShellBox':
			e.Replacement = "ToM_EquipmentSpawner_ShellBox"; 
			break;
		case 'RocketAmmo':
			e.Replacement = "ToM_YellowMana"; 
			break;
		case 'RocketBox':
			e.Replacement = "ToM_YellowManaBig"; 
			break;
		case 'Cell':
			e.Replacement = "ToM_PurpleMana"; 
			break;
		case 'CellPack':
			e.Replacement = "ToM_PurpleManaBig"; 
			break;
		}
	}
}