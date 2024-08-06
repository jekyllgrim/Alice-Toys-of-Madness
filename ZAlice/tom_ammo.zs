class ToM_Ammo : Ammo
{
	mixin ToM_CheckParticles;
	mixin ToM_PickupFlashProperties;
	mixin ToM_PickupSound;
	
	class<Ammo> bigPickupClass;
	property bigPickupClass : bigPickupClass;

	color particleColor;
	property particleColor : particleColor;

	Actor manashade;
	double manaBobFactor;
	
	Default 
	{
		xscale 0.4;
		yscale 0.33334;
		+BRIGHT
		+RANDOMIZE
		+ROLLSPRITE
		+ROLLCENTER
		+FORCEXYBILLBOARD
		FloatBobStrength 0.65;
		Inventory.pickupsound "pickups/ammo";
		Renderstyle 'Translucent';
	}

	override Class<Ammo> GetParentAmmo ()
	{
		class<Object> type = GetClass();

		while (type.GetParentClass() && type.GetParentClass() != "ToM_Ammo")
		{
			type = type.GetParentClass();
		}
		return (class<Ammo>)(type);
	}

	void A_SetManaFrame(int startFrame, int endFrame)
	{
		int i = int(round(ToM_Utils.LinearMap(manaBobFactor, -1, 1, startFrame, endFrame+1)));
		if (i > endFrame) i = startFrame;
		frame = i;
	}
	
	override void Tick()
	{
		super.Tick();
		if (!(owner || bNOSECTOR) && !isFrozen())
		{
			manaBobFactor = sin(360.0 * (GetAge() + FloatBobPhase) * 0.01);
			WorldOffset.z = 8 * manaBobFactor * FloatBobStrength;
		}

		if (manashade && (owner || bNOSECTOR))
		{
			manashade.Destroy();
		}
	}

	override string PickupMessage()
	{
		return String.Format("%s \cf+%d\c-", StringTable.Localize(pickupMsg), amount);
	}

	void SpawnManaParticles()
	{		
		int life = random[part](30,40);
		A_SpawnParticleEx(
			particleColor,
			TexMan.CheckForTexture("LENYA0"),
			STYLE_AddShaded,
			SPF_FULLBRIGHT|SPF_RELATIVE,
			lifetime: life,
			size: 4,
			angle: random[part](0, 359),
			xoff: random[part](4, 8),
			zoff: frandom[part](-8, 0) + WorldOffset.z,
			velx: -0.3,
			velz: -frandom(0.2, 0.85),
			sizestep: 4 / double(-life)
		);
	}
	
	States {
	Spawn:
		TNT1 A 0 NoDelay
		{
			if (bTossed)
				return ResolveState("DroppedSpawn");
			return ResolveState("Idle");
		}
		stop;
	DroppedSpawn:
		#### # 0
		{
			state st = FindState("Idle");
			if (st)
			{
				sprite = st.sprite;
				frame = st.frame;
			}
			scale *= 0.2;
			alpha = 0;
			//roll = -120;
			gravity = 0.3;
			//spriteOffset.Y = 8;
			if (!manashade)
			{
				manashade = Spawn("ToM_ManaShade", pos);
				if (manashade)
				{
					manashade.master = self;
				}
			}
			vel.z = 4;
		}
		#### # 1
		{	
			SpawnManaParticles();
			double fac = 0.02;
			scale.x = Clamp(scale.x + default.scale.x * fac, scale.x, default.scale.x);			
			scale.y = Clamp(scale.y + default.scale.y * fac, scale.y, default.scale.y);
			//roll = Clamp(roll + 4, roll, default.roll);
			if (manashade)
				manashade.alpha = Clamp(manashade.alpha - fac, 0., default.alpha);
			alpha = Clamp(alpha + fac, 0., default.alpha);
			if (spriteOffset == default.spriteOffset && scale == default.scale && alpha == default.alpha && roll == 0)
			{
				if (manashade)
					manashade.Destroy();
				gravity = default.gravity;
				return ResolveState("Idle");
			}

			return ResolveState(null);
		}
		wait;	
	}
}

class ToM_ManaShade : ToM_ActorLayer
{
	Default
	{
		Renderstyle 'AddShaded';
		Stencilcolor "FFFFFF";
		alpha 0.999;
		ToM_ActorLayer.fade 0;
	}
}	

class ToM_WeakMana : ToM_Ammo
{
	Default
	{
		Inventory.pickupmessage "$TOM_MANA_WEAK";
		Tag "$TOM_MANA_WEAK";
		inventory.amount 10;
		inventory.maxamount 300;
		ammo.backpackamount 100;
		ammo.backpackmaxamount 300;
		ToM_Ammo.bigPickupClass "ToM_WeakManaBig";
		ToM_Ammo.particleColor "ffb100";
	}
	
	States {
	Idle:
		AMWS A 1 A_SetManaFrame(0, 8);
		loop;
	}
}

class ToM_WeakManaBig : ToM_WeakMana
{
	Default
	{
		inventory.amount 40;
		ToM_Ammo.bigPickupClass "";
	}
	
	States {
	Idle:
		AMWB A 1 A_SetManaFrame(0, 11);
		loop;
	}
}

// haha it's actually green by default
class ToM_MediumMana : ToM_Ammo
{
	Default
	{
		Inventory.pickupmessage "$TOM_MANA_MEDIUM";
		Tag "$TOM_MANA_MEDIUM";
		inventory.amount 25;
		inventory.maxamount 300;
		ammo.backpackamount 100;
		ammo.backpackmaxamount 300;
		ToM_Ammo.bigPickupClass "ToM_MediumManaBig";
		ToM_Ammo.particleColor "8df500";
	}
	
	States {
	Idle:
		AMMS A 1 A_SetManaFrame(0, 11);
		loop;
	}
}

class ToM_MediumManaBig : ToM_MediumMana
{
	Default
	{
		inventory.amount 60;
		ToM_Ammo.bigPickupClass "";
	}
	
	States {
	Idle:
		AMMB A 1 A_SetManaFrame(0, 11);
		loop;
	}
}

class ToM_StrongMana : ToM_Ammo
{
	Default
	{
		Inventory.pickupmessage "$TOM_MANA_STRONG";
		Tag "$TOM_MANA_STRONG";
		inventory.amount 10;
		inventory.maxamount 300;
		ammo.backpackamount 100;
		ammo.backpackmaxamount 300;
		ToM_Ammo.bigPickupClass "ToM_StrongManaBig";
		ToM_Ammo.particleColor "9734ab";
	}
	
	States {
	Idle:
		AMSS A 1 A_SetManaFrame(0, 8);
		loop;
	}
}

class ToM_StrongManaBig : ToM_StrongMana
{
	Default
	{
		inventory.amount 40;
		ToM_Ammo.bigPickupClass "";
	}
	
	States {
	Idle:
		AMSB A 1 A_SetManaFrame(0, 13);
		loop;
	}
}


/////////////////////
/// AMMO SPAWNERS ///
/////////////////////

class ToM_EquipmentSpawner : Inventory abstract
{
	Class<Ammo> ammo1; //ammo type for the 1st weapon
	Class<Ammo> ammo2; //ammo type for the 2nd weapon
	Class<Weapon> weapon1; //1st weapon class to spawn ammo for
	Class<Weapon> weapon2; //2nd weapon class to spawn ammo for
	// chance of spawning ammo for weapon2 instead of weapon1:
	double otherPickupChance;
	// chance of spawning the big ammo pickup instead of the small one:
	double bigPickupChance;
	// chance of spawning the second ammotype next to 
	// the one chosen to be spawned:
	double twoPickupsChance;	
	// chance that this will be obtainable 
	// if dropped by an enemy:
	double dropChance;
	
	property weapon1 : weapon1;
	property weapon2 : weapon2;
	property otherPickupChance : otherPickupChance;
	property bigPickupChance : bigPickupChance;
	property twoPickupsChance : twoPickupsChance;
	property dropChance : dropChance;

	Default 
	{
		+NOBLOCKMAP
		-SPECIAL
		ToM_EquipmentSpawner.otherPickupChance 50;
		ToM_EquipmentSpawner.bigPickupChance 25;
		ToM_EquipmentSpawner.twoPickupsChance 0;
		ToM_EquipmentSpawner.dropChance 100;
	}
	
	Inventory SpawnInvPickup(vector3 spawnpos, Class<Inventory> itemToSpawn) 
	{
		let toSpawn = itemToSpawn;
		
		if (bigPickupChance >= 1)
		{
			let am = (class<ToM_Ammo>)(itemToSpawn);
			if (am)
			{
				let bigPickupCls = GetDefaultByType(am).bigPickupClass;
				if (bigPickupCls && bigPickupChance >= frandom[ammoSpawn](1,100))
				{
					toSpawn = bigPickupCls;
				}
			}
		}

		return ToM_Utils.SpawnInvPickup(self, spawnPos, toSpawn);
	}
	
	// returns true if any of the players have the weapon, 
	// or if the weapon exists on the current map:
	bool CheckExistingWeapons(Class<Weapon> checkWeapon) 
	{
		//check players' inventories:
		if (ToM_Utils.CheckPlayersHave(checkWeapon))
			return true;
			
		//check the array that contains all spawned weapon classes:
		ToM_MainHandler handler = ToM_MainHandler(EventHandler.Find("ToM_MainHandler"));
		if (handler && handler.mapweapons.Find(checkWeapon) != handler.mapweapons.Size())
			return true;

		return false;
	}
	
	States {
	Spawn:
		TNT1 A 1 NoDelay
		{
			// weapon1 is obligatory; if for whatever 
			// reason it's empty, destroy it:
			if (!weapon1) 
			{
				return ResolveState("Null");
			}	
			
			// if dropped by an enemy, the pickusp aren't
			// guaranteed to spawn:
			if (bTOSSED && dropChance < frandom[ammoSpawn](1,100)) 
			{
				return ResolveState("Null");
			}
			
			//get ammo classes for weapon1 and weapon2:
			ammo1 = GetDefaultByType(weapon1).ammotype1;
			
			if (weapon2) 
			{
				ammo2 = GetDefaultByType(weapon2).ammotype1;
				// if none of the players have weapon1 and it 
				// doesn't exist on the map, increase the chance 
				// of spawning ammo for weapon2:
				if (!CheckExistingWeapons(weapon1))
					otherPickupChance *= 1.5;
				// if none of the players have weapon2 and it 
				// doesn't exist on the map, decreate the chance 
				// of spawning ammo for weapon2:
				if (!CheckExistingWeapons(weapon2))
					otherPickupChance /= 1.5;
				// if players have neither, both calculations 
				// will happen, ultimately leaving the chance 
				// unchanged!
				if (tom_debugmessages)
					console.printf("alt set chance: %f",otherPickupChance);
			}
			
			//define two possible ammo pickups to spawn:
			class<Ammo> tospawn = ammo1;
			
			//with a chance they'll be replaced with ammo for weapon2:
			if (weapon2 && otherPickupChance >= random[ammoSpawn](1,100)) 
			{
				tospawn = ammo2;
			}
			
			//ammo dropped by enemies should always be small:
			if (bTOSSED)
			{
				bigPickupChance = 0;
			}
			
			// Spawn the ammo:
			SpawnInvPickup(pos,tospawn);
			
			// if the chance for two pickups is high enough, 
			// spawn the other type of ammo:
			if (twoPickupsChance >= frandom[ammoSpawn](1,100)) {
				class<Ammo> tospawn2 = (tospawn == ammo1) ? ammo2 : ammo1;
				// If it's dropped by an enemy, throw the second
				// pickup at a different angle:
				if (bTOSSED)
				{
					let a = SpawnInvPickup(pos,tospawn2);
					if (a)
					{
						a.vel = vel;
						int d = randompick[ammoSpawn](-1, 1);
						a.vel.x *= d;
						a.vel.y *= -d;
					}
				}
				// Otherwise spawn it in a random position in a 32
				// radius around it:
				else 
				{	
					let spawnpos = ToM_Utils.FindRandomPosAround(pos, 128, mindist: 32);
					SpawnInvPickup(spawnpos,tospawn2);
				}
			}
			return ResolveState(null);
		}
		stop;
	}
}

class ToM_AmmoSpawner_WeakMedium : ToM_EquipmentSpawner 
{
	Default 
	{
		ToM_EquipmentSpawner.weapon1 "ToM_Cards";
		ToM_EquipmentSpawner.weapon2 "ToM_PepperGrinder";
		ToM_EquipmentSpawner.otherPickupChance 20;
	}
}

class ToM_AmmoSpawner_WeakMedium_Big : ToM_AmmoSpawner_WeakMedium 
{
	Default 
	{
		ToM_EquipmentSpawner.otherPickupChance 30;
		ToM_EquipmentSpawner.twoPickupsChance 40;
		ToM_EquipmentSpawner.bigPickupChance 100;
	}
}

class ToM_AmmoSpawner_WeakMedium_Other : ToM_AmmoSpawner_WeakMedium 
{
	Default 
	{
		ToM_EquipmentSpawner.otherPickupChance 50;
		ToM_EquipmentSpawner.twoPickupsChance 50;
	}
}

class ToM_AmmoSpawner_WeakMedium_Other_Big : ToM_AmmoSpawner_WeakMedium_Other 
{
	Default 
	{
		ToM_EquipmentSpawner.bigPickupChance 100;
	}
}

class ToM_WeaponSpawner : ToM_EquipmentSpawner abstract
{
	Class<Inventory> toSpawn;
	ToM_MainHandler rhandler;
	bool onlyMapPlaced1;
	bool onlyMapPlaced2;
	Property OnlyMapPlaced1 : onlyMapPlaced1;
	Property OnlyMapPlaced2 : onlyMapPlaced2;

	Default
	{
		// If the dropped weapon gets replaced by ammo,
		// there's a 20% chance that ammo will be big:
		ToM_EquipmentSpawner.BigPickupChance 20;
	}

	States {
	Spawn:
		TNT1 A 1 Nodelay
		{
			if (!weapon1)
			{
				return ResolveState("Null");
			}	

			// First round only checks the players' inventories to determine what to spawn
			
			tospawn = weapon1;
			//check if players have weapon1 and weapon2 or those exist on the map:
			bool have1 = (ToM_Utils.CheckPlayersHave(weapon1, true));
			bool have2 = weapon2 && (ToM_Utils.CheckPlayersHave(weapon2, true));
			if (weapon2)
			{
				//if none of the players have weapon1, it should always spawn:
				//same if this is tossed but weapon2 can't be spawned tossed:
				if (!have1 || (bTossed && onlyMapPlaced2))
				{
					otherPickupChance = 0;
				}
				//otherwise, if none of the players have weapon2, that should always spawn:
				//same if this is tossed but weapon1 can't be spawned tossed:
				else if (!have2 || (bTossed && onlyMapPlaced1))
				{
					otherPickupChance = 100;
				}
				//(if players have both weapons, otherPickupChance is unchanged by this point)
				//set to spawn weapon2 if check passed:
				if (otherPickupChance >= frandom[ammoSpawn](1,100))
				{
					tospawn = weapon2;
				}
			}
			//if weapon2 is true and the item was NOT dropped, stagger spawning:
			bool stagger = weapon2 && !bTOSSED;
			if (tom_debugmessages)
			{
				string phave1 = have1 ? "have" : "don't have";
				string phave2 = have2 ? "have" : "don't have";	
				string wclass1 = weapon1.GetClassName();
				string wclass2 = "weapon2 (not defined)";
				if (weapon2) wclass2 = weapon2.GetClassName();
				string dr = bTOSSED ? "It was dropped." : "It was placed on the map.";
				console.printf("Players %s %s | Players %s %s | Secondary chance: %d, spawning %s. %s",phave1,wclass1,phave2,wclass2,otherPickupChance,tospawn.GetClassName(),dr);
			}
			/* 
			If it was  dropped by an enemy and ALL players have the chosen weapon, 
			OR this weapon is explicitly told to not be spawnable as an enemy drop,
			spawn ammo instead.
			(this is mainly because weapons, being 3D and all, look very "prominent"
			and I just don't want many of them to exist on the map at once)
			*/
			if (bTOSSED && (ToM_Utils.CheckPlayersHave(tospawn, true)) || (toSpawn == weapon1 && onlyMapPlaced1) || (toSpawn == weapon2 && onlyMapPlaced2))
			{
				if (tom_debugmessages)
				{
					string reason;
					if (ToM_Utils.CheckPlayersHave(tospawn, true)) 
						reason = String.Format("All players have %s", toSpawn.GetClassName());
					else if ((toSpawn == weapon1 && onlyMapPlaced1) || (toSpawn == weapon2 && onlyMapPlaced2))
						reason = String.Format("This was dropped, but %s can only spawn map-placed", toSpawn.GetClassName());
					Console.Printf("Spawning ammo instead of %s because %s", toSpawn.GetClassName(), reason);
				}
				// For ammo drops, recalculate chances again.
				// Increase chances of dropping ammo for the
				// weapon you actually have:
				otherPickupChance = default.otherPickupChance;
				if (!have1)
					otherPickupChance += 30;
				else if (!have2)
					otherPickupChance -= 30;
				otherPickupChance = Clamp(otherPickupChance, 0, 100);
				toSpawn = (otherPickupChance >= frandom[ammoSpawn](1,100))? weapon2 : weapon1;
				Class<Weapon> weap = (Class<Weapon>)(tospawn);
				if (!weap) return ResolveState("Null");
				Class<Ammo> amToSpawn = GetDefaultByType(weap).ammotype1;
				if (amToSpawn)
				{
					tospawn = amToSpawn;
					stagger = false;
				}
			}		
			if (!stagger)
			{
				SpawnInvPickup(pos,tospawn);
				return ResolveState("Null");
			}
			/*if we stagger spawning, push the desired weapon into array
			of all weapons on the map instead of spawning directly:
			*/
			if (tospawn is 'Weapon')
			{
				rhandler = ToM_MainHandler(EventHandler.Find("ToM_MainHandler"));	
				rhandler.mapweapons.Push((class<Weapon>)(toSpawn));
			}
			return ResolveState(null);
		}
		TNT1 A 0 {
			/*	Iterate through the array of the weapon classes that
				have been spawned on the map. If there are at least 2
				weapons of the chosen class in the array, simply spawn
				the other weapon instead:
			*/
			Class<Inventory> toSpawnFinal = (toSpawn == weapon2) ? weapon1 : weapon2;
			int wcount;
			foreach (mapweapon : rhandler.mapweapons)
			{
				if (mapweapon && mapweapon == toSpawn)
				{
					wcount++;
					if (wcount >= 3)
					{
						break;
					}
				}
			}
			//if there are 3 or more weapons of this class, spawn primary or secondary randomly:
			if (wcount >= 3 && random[ammoSpawn](0,1) == 1)
				toSpawnFinal = toSpawn;
			//if there's only current weapon, spawn it:
			else if (wcount <= 1)
				toSpawnFinal = toSpawn;
			if (tom_debugmessages)
				Console.PrintF("There are at least %d instaces of %s on this map. Spawning %s",wcount,toSpawn.GetClassName(),toSpawnFinal.GetClassName());
			SpawnInvPickup(pos,toSpawnFinal);
		}
		stop;
	}
}

class ToM_WeaponSpawner_Pistol : ToM_WeaponSpawner
{
	Default
	{
		ToM_EquipmentSpawner.Weapon1 'ToM_Knife';
		ToM_EquipmentSpawner.Weapon2 'ToM_Cards';
	}
}

class ToM_WeaponSpawner_Shotgun : ToM_WeaponSpawner
{
	Default
	{
		ToM_EquipmentSpawner.Weapon1 'ToM_Cards';
		ToM_EquipmentSpawner.Weapon2 'ToM_Jacks';
		ToM_WeaponSpawner.OnlyMapPlaced2 true;
	}
}

class ToM_WeaponSpawner_SuperShotgun : ToM_WeaponSpawner
{
	Default
	{
		ToM_EquipmentSpawner.Weapon1 'ToM_Jacks';
		ToM_EquipmentSpawner.Weapon2 'ToM_IceWand';
	}
}

class ToM_WeaponSpawner_Chaingun : ToM_WeaponSpawner
{
	Default
	{
		ToM_EquipmentSpawner.Weapon1 'ToM_PepperGrinder';
		ToM_EquipmentSpawner.Weapon2 'ToM_Jacks';
		ToM_WeaponSpawner.OnlyMapPlaced2 true;
	}
}

class ToM_WeaponSpawner_RocketLauncher : ToM_WeaponSpawner
{
	Default
	{
		ToM_EquipmentSpawner.Weapon1 'ToM_Teapot';
		ToM_EquipmentSpawner.Weapon2 'ToM_IceWand';
		ToM_WeaponSpawner.OnlyMapPlaced2 true;
	}
}

class ToM_WeaponSpawner_PlasmaRifle : ToM_WeaponSpawner
{
	Default
	{
		ToM_EquipmentSpawner.Weapon1 'ToM_Eyestaff';
		ToM_EquipmentSpawner.Weapon2 'ToM_IceWand';
	}
}

class ToM_WeaponSpawner_BFG9000 : ToM_WeaponSpawner
{
	Default
	{
		ToM_EquipmentSpawner.Weapon1 'ToM_Blunderbuss';
	}
}