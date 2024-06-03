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
		int i = round(ToM_Utils.LinearMap(manaBobFactor, -1, 1, startFrame, endFrame+1));
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

class ToM_EquipmentSpawner : Inventory 
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
	
	Inventory SpawnInvPickup(vector3 spawnpos, Class<Inventory> ammopickup) 
	{
		let toSpawn = ammopickup;
		
		if (bigPickupChance >= 1)
		{
			let am = (class<ToM_Ammo>)(ammopickup);
			if (am)
			{
				let bigPickupCls = GetDefaultByType(am).bigPickupClass;
				if (bigPickupCls && bigPickupChance >= frandom[ammoSpawn](1,100))
				{
					toSpawn = bigPickupCls;
				}
			}
		}
		
		let inv = Inventory(Spawn(toSpawn,spawnpos));
		
		if (inv) 
		{
			inv.vel = vel;
			// Halve the amount if it's dropped by the enemy:
			if (bTOSSED) 
			{
				inv.bTOSSED = true;
				inv.amount = Clamp(inv.amount / 2, 1, inv.amount);
			}
			
			// this is important to make sure that the weapon 
			// that wasn't dropped doesn't get DROPPED flag 
			// (and thus can't be crushed by moving ceilings)
			else
				inv.bDROPPED = false;
		}
		return inv;
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
		TNT1 A 0 NoDelay
		{
			// weapon1 is obligatory; if for whatever 
			// reason it's empty, destroy it:
			if (!weapon1) 
			{
				Destroy();
				return;
			}	
			
			// if dropped by an enemy, the pickusp aren't
			// guaranteed to spawn:
			if (bTOSSED && dropChance < frandom[ammoSpawn](1,100)) 
			{
				Destroy();
				return;
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
				if (tom_debugmessages > 1)
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
		}
		stop;
	}
}

class ToM_AmmoSpawner_RedYellow : ToM_EquipmentSpawner 
{
	Default 
	{
		ToM_EquipmentSpawner.weapon1 "ToM_Cards";
		ToM_EquipmentSpawner.weapon2 "ToM_Jacks";
		ToM_EquipmentSpawner.otherPickupChance 25;
	}
}

class ToM_AmmoSpawner_RedYellow_Big : ToM_AmmoSpawner_RedYellow 
{
	Default 
	{
		ToM_EquipmentSpawner.twoPickupsChance 40;
		ToM_EquipmentSpawner.bigPickupChance 100;
	}
}

class ToM_AmmoSpawner_RedYellow_BigOther : ToM_AmmoSpawner_RedYellow 
{
	Default 
	{
		ToM_EquipmentSpawner.twoPickupsChance 40;
		ToM_EquipmentSpawner.bigPickupChance 100;
		ToM_EquipmentSpawner.otherPickupChance 50;
	}
}