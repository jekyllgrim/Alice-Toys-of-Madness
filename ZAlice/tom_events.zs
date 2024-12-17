class ToM_Mainhandler : EventHandler
{ 
	int playerCheshireTimers[MAXPLAYERS]; //individual timer for per-player Chesire Cat animations
	array < Class<Weapon> > mapweapons; //all weapons on the map
	array < Actor > allmonsters; //all monsters on the map
	array < ToM_StakeProjectile > stakeprojectiles; //projectiles that can stick into walls need to reacquire their SecPlane
	array < ToM_JackBombPickup > jackbombPickups; //keeps track of dynamically spawned Jackbomb pickups

	ToM_PlayerDoll alicePlayerDoll;
	
	bool IsVoodooDoll(PlayerPawn mo) 
	{
		return ToM_Utils.IsVoodooDoll(mo);
	}

	// Attempted solution for drawing an Alice 3d model
	// behind the option menu screen. Removed for now,
	// since it's impossible to animate a 3d model when
	// the menu is open and the game is paused.
	// For now this is only done in TITLEMAP.
	override void WorldLoaded(WorldEvent e)
	{
		double left, right, top, bottom;
		foreach (vert : level.Vertexes)
		{
			left = min(left, vert.p.x);
			right = max(right, vert.p.x);
			top = max(top, vert.p.y);
			bottom = min(top, vert.p.y);
		}

		alicePlayerDoll = ToM_PlayerDoll.SpawnDoll((left - 128, top + 128, 0), -90);
	}

	override void NetworkProcess(consoleevent e)
	{
		if (!e.isManual && e.Player == consoleplayer && alicePlayerDoll)
		{
			if (e.name == "AnimatePlayerDoll" && alicePlayerDoll)
			{
				if (e.args[1])
				{
					alicePlayerDoll.Tick();
				}
				alicePlayerDoll.lightlevel = alicePlayerDoll.default.lightlevel + e.args[0];
			}
			if (e.name.IndexOf("StartAliceDollAnimation") >= 0)
			{
				array<String> cmd;
				e.name.Split(cmd, "|");
				if (cmd.Size() != 2) return;
				
				String mAction = cmd[1];
				mAction.Replace("+", "");
				if (mAction.IndexOf("slot") >= 0)
				{
					int slot = mAction.Mid(mAction.Length()-1, 1).ToInt();
					int modelID = -1;
					switch (slot)
					{
						case 1:
							modelID = ToM_AlicePlayer.AW_Knife;
							break;
						case 2:
							modelID = ToM_AlicePlayer.AW_Cards;
							break;
						case 3:
							modelID = ToM_AlicePlayer.AW_Jacks;
							break;
						case 4:
							modelID = ToM_AlicePlayer.AW_PGrinder;
							break;
						case 5:
							modelID = ToM_AlicePlayer.AW_Teapot;
							break;
						case 6:
							modelID = ToM_AlicePlayer.AW_IceWand;
							break;
						case 7:
							modelID = ToM_AlicePlayer.AW_Eyestaff;
							break;
						case 8:
							modelID = ToM_AlicePlayer.AW_Blunderbuss;
							break;
					}
					if (modelID >= 0)
					{
						alicePlayerDoll.A_ChangeModel("", ToM_AlicePlayer.MI_Weapon, "models/alice/weapons", ToM_AlicePlayer.modelnames[modelID]);
						State st = alicePlayerDoll.FindState("Anim_basepose");
						if (st && !Actor.InStateSequence(alicePlayerDoll.curstate, st))
						{
							alicePlayerDoll.SetState(st);
						}
					}
				}

				else 
				{
					alicePlayerDoll.A_ChangeModel("", ToM_AlicePlayer.MI_Weapon, flags: CMDL_HIDEMODEL);
					State st = alicePlayerDoll.FindStateByString(String.Format("Anim_%s", mAction));
					if (st)
					{
						alicePlayerDoll.SetState(st);
					}
					else if (alicePlayerDoll.curstate != alicePlayerDoll.spawnstate)
					{
						alicePlayerDoll.SetState(alicePlayerDoll.spawnstate);
					}
				}
			}

			if (e.name == "ResetAliceDollAnimation")
			{
				alicePlayerDoll.A_ChangeModel("", ToM_AlicePlayer.MI_Weapon, flags: CMDL_HIDEMODEL);
				if (alicePlayerDoll && !Actor.InstateSequence(alicePlayerDoll.curstate, alicePlayerDoll.spawnstate))
				{
					alicePlayerDoll.SetState(alicePlayerDoll.spawnstate);
				}
			}
		}

		if (!PlayerInGame[e.Player] || e.Player < 0)
			return;
		
		let plr = players[e.Player].mo;
		if (!plr)
			return;
		
		// Swap TPP camera shoulder:
		if (e.name ~== "SwapShoulderCamera" && (plr.player.cheats & CF_CHASECAM))
		{
			let alice = ToM_AlicePlayer(plr);
			if (!alice) return;
			alice.isCamShoulderSwapped = !alice.isCamShoulderSwapped;
			alice.camShoulderSwapTics = ToM_AlicePlayer.SHOULDERSWAPTIME;
		}
	}

	override void WorldTick()
	{
		if (gamestate != GS_TITLELEVEL && level.maptime == TICRATE)
		{
			Sound snd = (level.levelnum == 1)? "cheshire/vo/firststep" : "cheshire/vo/levelstart";
			for (int i = 0; i < MAXPLAYERS; i++)
			{
				if (!PlayerInGame[i]) continue;
				PlayerPawn pmo = players[i].mo;
				if (!pmo) continue;
				ToM_CheshireCat.SpawnAndTalk(pmo, snd, rad: 700, mapevent:true);
			}
		}

		for (int i = 0; i < MAXPLAYERS; i++)
		{
			if (playerCheshireTimers[i] > 0)
			{
				playerCheshireTimers[i] -= 1;
			}
		}
	}

	override void WorldThingSpawned(worldEvent e)
	{
		let thing = e.thing;
		if (thing && thing.bISMONSTER && !thing.bFRIENDLY && thing.health > 0)
		{
			allmonsters.Push(thing);
		}

		// Slow down projectiles fired by monsters currently being
		// slowed down by the ice wand:
		if (thing.bMissile && thing.speed > 0 && thing.target && thing.target.bIsMonster)
		{
			let frz = ToM_FreezeController(thing.target.FindInventory('ToM_FreezeController'));
			if (frz && frz.effectTics)
			{
				thing.vel /= frz.GetFreezeFactor();
			}
		}

		let stake = ToM_StakeProjectile(thing);
		if (stake)
		{
			stakeprojectiles.Push(stake);
		}

		let am = ToM_Ammo(thing);
		if (am && !am.bTossed)
		{
			double closestDist = double.infinity;
			foreach (mo : jackbombPickups)
			{
				if (mo && !mo.bNoSector && mo.Distance3D(am) < closestDist)
				{
					closestDist = mo.Distance3D(am);
				}
			}
			double jackchance = ToM_Utils.LinearMap(closestDist, 320, 2048, 0, 7.5, true);
			if (jackchance > frandom[jbombspawn](0, 10))
			{
				Vector3 ppos = ToM_Utils.FindRandomPosAround(am.pos, 256, 48, maxHeightDiff: 32);
				if (ppos != am.pos)
				{
					let jb = ToM_JackbombPickup(Actor.Spawn('ToM_JackbombPickup', ppos));
					if (jb)
					{
						jackbombPickups.Push(jb);
						jb.angle = frandom[jbpk](0,360);
					}
				}
			}
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

	override void WorldThingDestroyed(WorldEvent e)
	{
		let stake = ToM_StakeProjectile(e.thing);
		if (stake)
		{
			int id = stakeprojectiles.Find(stake);
			if (id != stakeprojectiles.Size())
			{
				stakeprojectiles.Delete(id);
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
		if (!e.thing)
			return;

		// Purple smoke above monsters killed by the Eyestaff beam or projectile:
		if (e.thing.health <= 0 && e.DamageType == 'Eyestaff')
		{
			e.thing.GiveInventory("ToM_EyestaffBurnControl", 1);
		}

		// DoT inflicted by from Teapot Cannon projectile explosion:
		if (e.Inflictor && e.Inflictor.GetClass() == 'ToM_TeaProjectile' && e.Inflictor.target && e.thing != e.Inflictor.target)
		{
			ToM_ControlToken.Refresh(e.thing, "ToM_TeaBurnControl", e.Inflictor.target);
		}

		// Radius thrust from Hobby Horse's plunging splash attack:
		if (!e.thing.bDontThrust && e.Damage > 0 && e.Inflictor && e.DamageSource && e.DamageSource.player && e.DamageFlags & DMG_EXPLOSION)
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
			double forceFac = ToM_Utils.LinearMap(weap.fallAttackForce, 1, 40, 1.0, 3.0);
			double force = 10 * distFac * massFac * forceFac;
			e.thing.Vel3DFromAngle(force, ang, -50);
		}
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

		PlayerPawn pmo = player.mo;
		if (pmo)
		{
			ToM_CheshireCat.SpawnAndTalk(pmo, "cheshire/vo/paincomment", mapevent:true);
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
			e.Replacement = "ToM_WeaponSpawner_Pistol"; 
			break;
		case 'Shotgun':
			e.Replacement = "ToM_WeaponSpawner_Shotgun"; 
			break;
		case 'SuperShotgun':
			e.Replacement = "ToM_WeaponSpawner_SuperShotgun"; 
			break;
		case 'Chaingun':
			e.Replacement = "ToM_WeaponSpawner_Chaingun"; 
			break;
		case 'RocketLauncher':
			e.Replacement = "ToM_WeaponSpawner_RocketLauncher"; 
			break;
		case 'PlasmaRifle':
			e.Replacement = "ToM_WeaponSpawner_PlasmaRifle"; 
			break;
		case 'BFG9000':
			e.Replacement = "ToM_WeaponSpawner_BFG9000"; 
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
		case 'Infrared':
			e.Replacement = "ToM_Infrared"; 
			break;
		case 'AllMap':
			e.Replacement = "ToM_AllMap"; 
			break;
		case 'Radsuit':
			e.Replacement = "ToM_Radsuit"; 
			break;

		case 'Clip':
			e.Replacement = "ToM_AmmoSpawner_WeakMedium"; 
			break;
		case 'ClipBox':
			e.Replacement = "ToM_AmmoSpawner_MediumWeak_Big"; 
			break;
		case 'Shell':
			e.Replacement = "ToM_AmmoSpawner_MediumWeak"; 
			break;
		case 'ShellBox':
			e.Replacement = "ToM_AmmoSpawner_WeakMedium_Big"; 
			break;
		case 'RocketAmmo':
			e.Replacement = "ToM_AmmoSpawner_MediumStrong"; 
			break;
		case 'RocketBox':
			e.Replacement = "ToM_AmmoSpawner_MediumStrong_Big"; 
			break;
		case 'Cell':
			e.Replacement = "ToM_AmmoSpawner_StrongMedium"; 
			break;
		case 'CellPack':
			e.Replacement = "ToM_AmmoSpawner_StrongMedium_Big"; 
			break;
		}
	}
}

Class ToM_StaticStuffHandler : StaticEventHandler
{
	// When hitting a wall, stakes get attached to a secplane of the sector
	// behind the wall, so that if the wall moves (as a door/lift), the stake
	// will move with it.
	// Since SecPlane pointers aren't serializable (thus the SecPlane field
	// used by stakes has to be transient) - see ToM_StakeProjectile - 
	// upon loading a save all existing stakes that are parented to a SecPlane
	// call StickToWall() again to *reacquire* that SecPlane:

	override void WorldLoaded(WorldEvent e)
	{
		for (int i = 0; i < MAXPLAYERS; i++)
		{
			if (!PlayerInGame[i]) continue;
			let player = players[i];
			if (!player || !player.mo) continue;
			if (!(player.mo is 'ToM_AlicePlayer'))
			{
				ThrowAbortException(String.Format(
					"Player \cd%d\c- is using \cd%s\c- as their player class. \cyAlice: Toys of Madness\c- requires using \cdToM_AlicePlayer\c- as your player class and cannot function otherwise.\n"
					"If you are currently playing with a mod that defines a custom playerclass through KEYCONF, you will have to edit it manually and remove the \cdclearplayerclasses\c- and \cdaddplayerclass\c- definitions from it.", 
					i, player.mo.GetClassName())
				);
				return;
			}
		}

		if (!e.isSaveGame)
			return;
		let handler = ToM_Mainhandler(EventHandler.Find("ToM_Mainhandler"));
		if (!handler)
			return;
		foreach (stake : handler.stakeprojectiles)
		{
			if (stake && stake.GetStuckType() & ToM_StakeProjectile.STUCK_SECPLANE)
			{
				stake.StickToWall();
			}
		}
	}

	// The rest of the handler by 3saster:
	// This searches ANIMDEFS and ANIMATED lumps to see if a given texture name is 
	// defined in any of those as an animated texture.

	// These must be stored as numbers, in order to get the textures
	// from ANIMATED in between the start and end
	// Oddly, we can convert a TextureID to int, but not the other way
	Array<int> animNums;
	
	clearscope static bool IsAnimatedTexture(textureID tex)
	{
		ToM_StaticStuffHandler event = ToM_StaticStuffHandler(StaticEventHandler.Find("ToM_StaticStuffHandler"));
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

class ToM_UiHandler : StaticEventHandler
{
	ui bool mainMenuOpened;

	const PCTEX_SIZE = 512;
	
	transient Canvas pcCanv_body[MAXPLAYERS];
	transient Canvas pcCanv_body2[MAXPLAYERS];
	transient Canvas pcCanv_arm[MAXPLAYERS];
	
	TextureID pcTex_body_top;
	TextureID pcTex_body2_top;
	TextureID pcTex_arm_top;
	TextureID pcTex_arm_top_rage;

	ui TextureID portraitTex;
	ui TextureID portraitTexBase;
	ui Vector2 portraitSize;
	ui Canvas portraitCanvas;

	ui TextureID mirrortex;
	ToM_ReflectionCamera weaponCameras[MAXPLAYERS];

	override void RenderOverlay(renderEvent e) 
	{
		MMD_Draw(); //see tom_menu.zs

		if (gamestate == GS_LEVEL)
		{
			if (weaponCameras[consoleplayer])
			{
				if (!mirrortex || !mirrortex.IsValid())
					mirrortex = TexMan.CheckForTexture(ToM_ReflectionCamera.TOM_CAMERATEXTURE, TexMan.Type_Any);
				let pmo = players[consoleplayer].mo;
				if (pmo && pmo.player.camera == pmo)
				{
					Screen.DrawTexture(mirrortex, false, 0.0, 0.0, DTA_Alpha, 0.0);
				}
			}
		}

		PrintDebugMessages();
	}

	override void WorldTick()
	{
		if (!pcTex_body_top || !pcTex_body_top.isValid())
			pcTex_body_top = TexMan.CheckForTexture("models/alice/alice_body_trns.png");
		if (!pcTex_body2_top || !pcTex_body2_top.isValid())
			pcTex_body2_top = TexMan.CheckForTexture("models/alice/alice_body2_trns.png");
		if (!pcTex_arm_top || !pcTex_arm_top.isValid())
			pcTex_arm_top = TexMan.CheckForTexture("models/alice/alice_arm_trns.png");
		if (!pcTex_arm_top_rage || !pcTex_arm_top_rage.isValid())
			pcTex_arm_top_rage = TexMan.CheckForTexture("models/alice/alice_arm_trns_rage.png");
			
		for (int i = 0; i < MAXPLAYERS; i++)
		{
			if (!PlayerInGame[i]) continue;

			if (!pcCanv_body[i])
				pcCanv_body[i] = TexMan.GetCanvas(String.Format("%s%d", ToM_PCANTEX_BODY, i));
			if (!pcCanv_body2[i])
				pcCanv_body2[i] = TexMan.GetCanvas(String.Format("%s%d", ToM_PCANTEX_BODY2, i));
			if (!pcCanv_arm[i])
				pcCanv_arm[i] = TexMan.GetCanvas(String.Format("%s%d", ToM_PCANTEX_ARM, i));
			
//			Console.MidPrint(smallfont, String.Format(
//				"Updating canvases for player %d\n"
//				"body: \cd%s\n"
//				"body2: \cd%s\n"
//				"arm: \cd%s\n"
//				"body canvas: %s\n"
//				"body2 canvas: %s\n"
//				"arm canvas: %s",
//				i, TexMan.GetName(pcTex_body_top), TexMan.GetName(pcTex_body2_top), TexMan.GetName(pcTex_arm_top),
//				pcCanv_body[i]? "\cdtrue" : "\cgFALSE",
//				pcCanv_body2[i]? "\cdrue" : "\cgFALSE",
//				pcCanv_arm[i]? "\cdtrue" : "\cgFALSE")
//			);
		}
	}

	ui void UpdatePlayerColorCanvas(Canvas cv, TextureID toptexture, Color playercol, Vector2 texSize = (PCTEX_SIZE, PCTEX_SIZE))
	{
		if (!cv || !toptexture || !toptexture.IsValid()) return;
		
		cv.Clear(0, 0, texSize.x, texSize.y, playerCol);
		cv.DrawTexture(toptexture, false, 0, 0, DTA_FlipY, true);
	}

	override void UiTick()
	{
		let currentMenu = Menu.GetCurrentMenu();

		// Update canvases representing player colors
		for (int i = 0; i < MAXPLAYERS; i++)
		{
			if (!PlayerInGame[i]) continue;
			let pmo = players[i].mo;
			if (!pmo) continue;

			Color playerCol = players[i].GetColor();
			UpdatePlayerColorCanvas(pcCanv_body[i], pcTex_body_top, playerCol);
			UpdatePlayerColorCanvas(pcCanv_body2[i], pcTex_body2_top, playerCol);
			TextureID tex = pcTex_arm_top;
			// Apply rage texture on the arms only for other players
			// or while console player does NOT have the menu open.
			// This is done to avoid applying rage textures to the 
			// player doll model seen in the Options menu background,
			// which still uses canvas textures to have the colors
			// applied:
			if (ToM_RageBox.HasRageBox(pmo) && (i != consoleplayer || !currentMenu || !(currentMenu is 'OptionMenu')))
			{
				tex = pcTex_arm_top_rage;
			}
			UpdatePlayerColorCanvas(pcCanv_arm[i], tex, playerCol);
		}

		if (currentMenu)
		{
			MMD_Tick();

			mainMenuOpened = true;

			// Update portrait showing Player Menu:
			let player = players[consoleplayer];
			if (!portraitTex)
			{
				portraitTex = TexMan.CheckForTexture("graphics/AliceImg.png");
				portraitSize = TexMan.GetScaledSize(portraitTex);
			}
			if (!portraitTexBase)
			{
				portraitTexBase = TexMan.CheckForTexture("graphics/AliceImgBase.png");
			}
			if (!portraitCanvas)
			{
				portraitCanvas = TexMan.GetCanvas("AlicePlayer.menuPortrait");
			}
			
			portraitCanvas.Clear(0, 0, portraitSize.x, portraitSize.y, 0xff000000);
			portraitCanvas.DrawTexture(portraitTexBase, false, 0, 0, DTA_FillColor, player.GetColor());
			portraitCanvas.DrawTexture(portraitTex, false, 0, 0);
		}

		// auto-opem main menu when the title level loads in
		// (because by default GZDoom doesn't do that):
		else if (!mainMenuOpened && gamestate == GS_TITLELEVEL)
		{
			Menu.SetMenu("MainMenu");
		}
	}
}
