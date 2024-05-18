class ToM_Mainhandler : EventHandler
{
	ToM_HUDFaceController HUDfaces[MAXPLAYERS];
	array < Class<Weapon> > mapweapons;

	array < Actor > allmonsters;
	
	bool IsVoodooDoll(PlayerPawn mo) 
	{
		return ToM_Utils.IsVoodooDoll(mo);
	}

	override void NetworkProcess(consoleevent e)
	{
		if (!PlayerInGame[e.Player] || e.Player < 0)
			return;
		
		let plr = players[e.Player].mo;
		if (!plr)
			return;
		
		string lcname = e.name.MakeLower();		

// 		//FOV test:
//		if (lcname.IndexOf("weapfov") >= 0)
//		{
//			let weap = plr.player.readyweapon;
//			if (weap)
//			{
//				array < string > fovcmd;
//				lcname.Split(fovcmd, ":");
//				double fov;
//				if (fovcmd.Size() == 2)
//				{				
//					fov = fovcmd[1].ToDouble();
//				}
//				weap.FOVscale = fov;
//				console.printf("%s FOVscale: %.2f", weap.GetTag(), weap.FOVScale);
//			}
//		}
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
		let thing = e.thing;
		if (thing && thing.bISMONSTER && !thing.bFRIENDLY && thing.health > 0)
		{
			allmonsters.Push(thing);
		}
	}

	override void WorldThingDied(worldEvent e)
	{
		let thing = e.thing;
		if (thing && thing.bISMONSTER)
		{
			int i = allmonsters.Find(thing);
			if (i < allmonsters.Size())
			{
				allmonsters.Delete(i);
			}
		}
	}

	override void WorldThingRevived(worldEvent e)
	{
		let thing = e.thing;
		if (thing && thing.bISMONSTER && !thing.bFRIENDLY && thing.health > 0 && allmonsters.Find(thing) != allmonsters.Size())
		{
			allmonsters.Push(thing);
		}
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
		
		if (e.thing.player)
		{
			int pn = e.thing.PlayerNumber();
			if (HUDFaces[pn])
			{
				double dmgAngle = 0;
				Actor who = e.inflictor ? e.inflictor : e.damageSource;
				if (who)
				{
					dmgAngle = e.thing.DeltaAngle(e.thing.angle, e.thing.AngleTo(who));
				}
				HUDFaces[pn].PlayerDamaged(e.damage, dmgAngle);
			}
		}

		if (e.thing.health <= 0 && e.DamageType == 'Eyestaff')
		{
			e.thing.GiveInventory("ToM_EyestaffBurnControl", 1);
		}

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
			double distFac = ToM_Utils.LinearMap(e.thing.Distance3D(e.DamageSource), 128, 0, 0.5, 1.5);
			double massFac = ToM_Utils.LinearMap(e.thing.mass, 300, 1000, 1.0, 0.0, true);
			double forceFac = ToM_Utils.LinearMap(weap.falLAttackForce, 1, 40, 1.0, 3.0);
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
		if (!HUDfaces[e.PlayerNumber])
		{
			HUDfaces[e.PlayerNumber] = ToM_HUDFaceController.Create(players[pn]);
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
			
		case 'ArmorBonus':
			e.Replacement = "ToM_ArmorBonus"; 
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
		case 'Blursphere':
			e.Replacement = "ToM_Invisibility"; 
			break;
		case 'InvulnerabilitySphere':
			e.Replacement = "ToM_GrowthPotion"; 
			break;
		case 'Backpack':
			e.Replacement = "ToM_Backpack"; 
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
			e.Replacement = "ToM_MediumMana"; 
			break;
		case 'RocketBox':
			e.Replacement = "ToM_MediumManaBig"; 
			break;
		case 'Cell':
			e.Replacement = "ToM_StrongMana"; 
			break;
		case 'CellPack':
			e.Replacement = "ToM_StrongManaBig"; 
			break;
		}
	}
}

// By 3saster:
// This searches ANIMDEFS and ANIMATED lumps to see if a given texture name is 
// defined in any of those as an animated texture.

Class ToM_Animated_Handler : StaticEventHandler
{
	// These must be stored as numbers, in order to get the textures
	// from ANIMATED in between the start and end
	// Oddly, we can convert a TextureID to int, but not the other way
	Array<int> animNums;
	
	clearscope static bool isAnimated(textureID tex)
	{
		ToM_Animated_Handler event = ToM_Animated_Handler(StaticEventHandler.Find("ToM_Animated_Handler"));
		if (!event)
			return false;
		
		return ( event.animNums.Find(int(tex)) != event.animNums.Size() );
	}

	override void OnRegister()
	{
		// ANIMATED
		int currLump = Wads.FindLump("ANIMATED",0,1);
		while( currLump != -1 )
		{
			addANIMATED(currLump);
			currLump = Wads.FindLump("ANIMATED",currLump+1,1);
		}
		
		// ANIMDEFS
		currLump = Wads.FindLump("ANIMDEFS",0,1);
		while( currLump != -1 )
		{
			addANIMDEFS(currLump);
			currLump = Wads.FindLump("ANIMDEFS",currLump+1,1);
		}
	}
	
	void addANIMATED(int lump)
	{
		string data = Wads.ReadLump(lump);
		// Read each record
		for(int pos = 0; data.ByteAt(pos) != 255; pos += 23 )
		{
			string start = data.Mid(pos+10,9);
			string end   = data.Mid(pos+1 ,9);
			
			int texStart = int(TexMan.CheckForTexture(start, TexMan.Type_Any));
			int texEnd   = int(TexMan.CheckForTexture(end,   TexMan.Type_Any));
				
			// If animated texture exists and is not in array, add it
			if( texStart > 0 && texEnd > 0 && texStart != texEnd )
				for(int i = texStart; i <= texEnd; i++)
				{
					if( animNums.Find(i) == animNums.Size() )
						animNums.Push(i);
				}
		}
	}
	
	void addANIMDEFS(int lump)
	{
		string data = Wads.ReadLump(lump);
		// Delete comments
		while(data.IndexOf("//") != -1)
		{
			int start = data.IndexOf("//");
			int end   = data.IndexOf("\n",start)+1;
			data.Remove(start,end-start);
		}
		while(data.IndexOf("/*") != -1)
		{
			int start = data.IndexOf("/*");
			int end   = data.IndexOf("*/",start)+2;
			data.Remove(start,end-start);
		}
		// Remove non-space whitespace
		for(int i = 0; i <= 31; i++)
			data.Replace(string.format("%c",i)," ");
		data.Replace(string.format("%c",127)," ");
		// Remove superflous spaces
		string cleandata = data;
		cleandata.Replace("  "," ");
		while(data != cleandata)
		{
			data = cleandata;
			cleandata.Replace("  "," ");
		}
		
		// Tokenize
		Array<String> tokens;
		data.Split(tokens, " ");
		
		// Search for token after texture/flat
		int i = 0;
		while(i < tokens.Size())
		{
			// texture.flat appears as next token; skip that
			if(tokens[i] ~== "warp" || tokens[i] ~== "warp2")
				i += 2;
			// Found an animated texture; read "pic" stuff until another token is found
			else if(tokens[i] ~== "texture" || tokens[i] ~== "flat")
			{
				while( i < tokens.Size() && !(tokens[i] ~== "pic") )
					i++;
				while( i < tokens.Size() && tokens[i] ~== "pic" )
				{
					int texture = int(TexMan.CheckForTexture(tokens[i+1], TexMan.Type_Any));
					if( texture > 0 && animNums.Find(texture) == animNums.Size() )
						animNums.Push(texture);
					i += 4;
				}
			}
			else
				i++;
		}
	}
	
}