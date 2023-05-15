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
	
	override void WorldThingDamaged(worldEvent e)
	{
		// Handle DoT from Teapot Cannon projectiles
		// (has to be done here, since that's the only
		// way to make sure the DoT is triggered by
		// explosions, not just a direct hit of the 
		// projectile):
		if (!e.thing)
			return;

		if (e.Inflictor && e.Inflictor.GetClass() == 'ToM_TeaProjectile' && e.Inflictor.target)
		{
			let act = e.thing;
			if (!act.CountInv("ToM_TeaBurnControl"))
				act.GiveInventory("ToM_TeaBurnControl", 1);
			let cont = ToM_TeaBurnControl(act.FindInventory("ToM_TeaBurnControl"));
			if (cont)
			{
				cont.ResetTimer();
				cont.target = e.Inflictor.target;
			}
		}

		if (e.Inflictor && e.DamageSource && e.DamageSource.player && e.DamageFlags & DMG_EXPLOSION)
		{
			let player = e.DamageSource.player;
			if (!player)
				return;
			let weap = ToM_HobbyHorse(player.readyweapon);
			if (!weap)
				return;
		
			double ang = (e.thing.angle + e.thing.AngleTo(e.DamageSource)) + 180;
			double distFac = ToM_UtilsP.LinearMap(e.thing.Distance3D(e.DamageSource), 128, 0, 0.5, 1.5);
			double massFac = ToM_UtilsP.LinearMap(e.thing.mass, 300, 1000, 1.0, 0.0, true);
			double forceFac = ToM_UtilsP.LinearMap(weap.fallAttackDuration, 1, 20, 1.0, 3.0);
			double force = 10 * distFac * massFac * forceFac;
			e.thing.Vel3DFromAngle(force, ang, -50);
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
		let fc = ToM_HUDFaceController(Actor.Spawn("ToM_HUDFaceController", pmo.pos));
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

	ui TextureID mirrortex;	
	override void RenderOverlay(renderEvent e) 
	{
		if (!PlayerInGame[consoleplayer])
			return;
		
		PlayerInfo plr = players[consoleplayer];
		if (plr && plr.readyweapon && plr.readyweapon is 'ToM_InvisibilitySelector')
		{	
			if (!mirrortex)
				mirrortex = TexMan.CheckForTexture("AliceWeapon.camtex", TexMan.Type_Any);
			if (mirrortex.IsValid()) {
				Screen.DrawTexture(mirrortex, false, 0.0, 0.0, DTA_Alpha, 0.0);
			}
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
			e.Replacement = "ToM_AmmoSpawner_RedYellow"; 
			break;
		case 'ClipBox':
			e.Replacement = "ToM_AmmoSpawner_RedYellow_Big"; 
			break;
		case 'Shell':
			e.Replacement = "ToM_AmmoSpawner_RedYellow"; 
			break;
		case 'ShellBox':
			e.Replacement = "ToM_AmmoSpawner_RedYellow_BigOther"; 
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