class ToM_InvReplacementControl : ToM_InventoryToken 
{
	//Class<Inventory> latestPickup; //keep track of the latest pickup
	//string latestPickupName; //the tag of the latest pickup
	//bool codexOpened;
	
	Weapon prevWeapon;
	Weapon prevWeaponToSwitch;

	static const name ReplacementPairs[] = {
		// DOOM
		// weapons:
		"Fist:ToM_Knife",
		"Chainsaw:ToM_HobbyHorse",
		"Pistol:ToM_Cards",
		"Shotgun:ToM_Cards",
		"SuperShotgun:ToM_Jacks",
		"Chaingun:ToM_PepperGrinder",
		"RocketLauncher:ToM_Teapot",
		"PlasmaRifle:ToM_Eyestaff",
		"BFG9000:ToM_Blunderbuss",
		// ammo:
		"Clip:ToM_WeakMana",
		"ClipBox:ToM_WeakManaBig",
		"Shell:ToM_MediumMana",
		"ShellBox:ToM_MediumManaBig",
		"RocketAmmo:ToM_MediumMana",
		"RocketBox:ToM_MediumManaBig",
		"Cell:ToM_StrongMana",
		"CellPack:ToM_StrongManaBig",
		// items:
		"GreenArmor:ToM_SilverArmor",
		"BlueArmor:ToM_GoldArmor",
		"Berserk:ToM_RageBoxEffect",
		"InvulnerabilitySphere:ToM_GrowthPotion",
		"Blursphere:ToM_InvisibilityEffect",
		"Backpack:ToM_Backpack",
		"AllMap:ToM_Allmap",
		"RadSuit:ToM_Radsuit",
		"Infrared:ToM_Infrared",
		
		/*
		// HERETIC
		//weapons:
		"Staff:PK_Painkiller", //fist
		"Gauntlets:PK_Painkiller", //chainsaw
		"Goldwand:PK_Painkiller", //pistol
		"Crossbow:PK_Shotgun", //shotgun
		"Blaster:PK_Chaingun", //chaingun
		"PhoenixRod:PK_Stakegun", //rocket launcher
		"SkullRod:PK_Rifle", // plasma rifle
		"Mace:PK_ElectroDriver" //bfg
		//ammo:
		"BlasterAmmo:PK_Shells",
		"BlasterHefty:PK_BulletAmmo",
		"CrossbowAmmo:PK_StakeAmmo",
		"CrossbowHefty:PK_BoltAmmo",
		"PhoenixRodAmmo:PK_GrenadeAmmo",
		"PhoenixRodHefty:PK_RifleBullets",
		"SkullRodAmmo:PK_ShurikenAmmo",
		"SkullRodHefty:PK_CellAmmo",
		"MaceAmmo:PK_ShurikenAmmo",
		"MaceHefty:PK_CellAmmo",
		// items:
		"SilverShield:PK_SilverArmor",
		"EnchantedShield:PK_GoldArmor",
		"ArtiTomeOfPower:PK_WeaponModifierGiver",
		"InvulnerabilitySphere:PK_Pentagram",
		"BagOfHolding:PK_AmmoPack",
		"SuperMap:PK_AllMap"*/
		
		// VOID:
		"FWeapFist:ToM_Knife",
		"PhoenixRod:ToM_Cards"
	};
	
	void ReadyForQuickSwitch(Weapon readyweapon, PlayerInfo player)
	{
		if (readyweapon)
		{
			if (!prevWeapon)
				prevWeapon = readyweapon;
			if (!prevWeaponToSwitch)
				prevWeaponToSwitch = readyweapon;
			
			if (readyweapon != prevWeapon)
			{
				prevWeaponToSwitch = prevWeapon;
				prevWeapon = readyweapon;
			}
	
			if (readyweapon && 
				player.WeaponState & WF_WEAPONSWITCHOK &&
				prevWeaponToSwitch && 
				readyweapon != prevWeaponToSwitch && 
				player.cmd.buttons & BT_USER3 && 
				!(player.oldbuttons & BT_USER3)
			)
			{
				player.pendingweapon = prevWeaponToSwitch;
			}
		}
	}

	// This checks the player's inventory for illegal (vanilla) weapons
	// continuously. This helps to account for starting items too,
	// in case Painslayer is played with a project that overrides the 
	// player class, so they don't start with a pistol.
	// It also makes sure to select the replacement weapon that matches
	// the vanilla weapon that was selected:
	override void DoEffect()
	{
		super.DoEffect();
		if (!owner || !owner.player)
			return;
		
		let plr = owner.player;
		
		// We'll store the weapon that the player should switch to here:
		class<Weapon> toSwitch;
		Weapon readyweapon = owner.player.readyweapon;
		
		//ReadyForQuickSwitch(readyweapon, plr);
		
		for (int i = 0; i < ReplacementPairs.Size(); i++)
		{
			// Split the entry to get the replacement
			// an the replacee:
			array<string> classes;
			string str = ReplacementPairs[i];
			str.Split(classes, ":");
			
			// If the split didn't work for some reason,
			// skip this one:
			if (classes.Size() < 2)
				continue;
			
			// Check the class is valid and is a weapon:
			class<Weapon> oldweapon = classes[0];
			if (!oldweapon)
				continue;
			
			// Check the player has it:
			if (owner.CountInv(oldweapon))
			{
				// Remove the original and give the replacement:
				owner.TakeInventory(oldweapon, owner.CountInv(oldweapon));
				owner.GiveInventory(classes[1], 1);
				// If the original weapon was selected, tell the player 
				// to switch to the replacement:
				if (readyweapon && readyweapon.GetClass() == oldweapon)
				{
					toSwitch = classes[1];
				}
			}
			
			// Switch to the new weapon:
			if (toSwitch)
			{
				owner.player.pendingweapon = Weapon(owner.FindInventory(toSwitch));
			}
		}
	}
	
	// This overrides the player's ability to receive vanilla weapons
	// to account for cheats and GiveInventory ACS scripts:
	override bool HandlePickup (Inventory item)
	{
		let oldItemClass = item.GetClassName();
		Class<Inventory> replacement = null;
		
		// Iterate through the array:
		for (int i = 0; i < ReplacementPairs.Size(); i++)
		{
			// Split the entry to get the replacement
			// an the replacee:
			array<string> classes;
			string str = ReplacementPairs[i];
			str.Split(classes, ":");
			
			// If the split didn't work for some reason,
			// skip this one:
			if (classes.Size() < 2)
				continue;
			
			// Otherwise, check against the original class name,
			// and if it matches, replace with the new one:
			if (oldItemClass == classes[0])
			{
				replacement = classes[1];
				break;
			}
		}
		
		// If the item class is not in the replacement array,
		// give it as is:
		if (!replacement) {
			if (tom_debugmessages > 1)
				console.printf("%s doesn't need replacing, giving as is",oldItemClass);
			return false;
		}
		
		// Otherwise give the replacement instead:
		else {
			int r_amount = GetDefaultByType(replacement).amount;
			item.bPickupGood = true;
			owner.A_GiveInventory(replacement,r_amount);
			if (tom_debugmessages) {
				console.printf("Replacing %s with %s (amount: %d)",oldItemClass,replacement.GetClassName(),r_amount);
			}
			//RecordLastPickup(replacement ? replacement : item.GetClass());
			return true;
		}		
		
		return false;
	}
}

class ToM_ArmorPickup : BasicArmorPickup abstract
{
	mixin ToM_PickupSound;
	mixin ToM_ComplexPickupmessage;
	Default
	{	
		Radius 20;
		Height 16;
	}
}

class ToM_SilverArmor : ToM_ArmorPickup
{
	int lastblink;
	
	Default
	{
		Inventory.icon "ACARM_1";
		Inventory.pickupsound "pickups/armor/light";
		Inventory.PickupMessage "$TOM_ITEM_ARMOR_MED";
		Armor.SavePercent 33.335;
		Armor.SaveAmount 100;
		XScale 0.5;
		YScale 0.5 / 1.2;
	}

	override string GetPickupNote() 
	{
		return String.Format("(\cy+%d %s\c-)", saveAmount, StringTable.Localize("$TOM_UNIT_ARMOR"));
	}
	
	States {
	Spawn:
		ABR1 A 0 NoDelay { return ResolveState("Idle"); }
		stop;
	Idle:
		#### A random(3, 35);
		#### A 0 
		{
			int i = 1;
			while (i == lastblink)
			{
				i = random[ammochest](1, 5);
			}
			lastblink = i;
			return FindStateByString("Blink"..i);
		}
	Blink1:
		#### BCBD 4;
		#### A 0 { return spawnstate; }
	Blink2:
		#### EFEG 4;
		#### A 0 { return spawnstate; }
	Blink3:
		#### HIHJ 4;
		#### A 0 { return spawnstate; }
	Blink4:
		#### KLKM 4;
		#### A 0 { return spawnstate; }
	Blink5:
		#### NONP 4;
		#### A 0 { return spawnstate; }
		stop;
	}
}

class ToM_GoldArmor : ToM_SilverArmor
{	
	Default
	{
		Inventory.icon "ACARM_2";
		Inventory.pickupsound "pickups/armor/heavy";
		Inventory.PickupMessage "$TOM_ITEM_ARMOR_BIG";
		Armor.SavePercent 50;
		Armor.SaveAmount 200;
	}
	
	States {
	Spawn:
		ABR2 A 0 NoDelay { return ResolveState("Idle"); }
		stop;
	}
}

class ToM_ArmorBonus : ArmorBonus
{
	mixin ToM_PickupSound;
	mixin ToM_ComplexPickupmessage;
	
	Default
	{
		Inventory.icon "ACARM_0";
		Inventory.pickupsound "pickups/armor/bonus";
		Inventory.PickupMessage "$TOM_ITEM_ARMOR_SMALL";
		XScale 0.5;
		YScale 0.5 / 1.2;
	}

	override void BeginPlay()
	{
		Super.BeginPlay();
		pickupNote = String.Format("(\cy+%d %s\c-)", amount, StringTable.Localize("$TOM_UNIT_ARMOR"));
	}
	
	States
	{
	Spawn:
		ABR0 A -1;
		stop;
	}
}

class ToM_Health : Health abstract
{
	mixin ToM_CheckParticles;
	mixin ToM_PickupFlashProperties;
	mixin ToM_PickupSound;
	mixin ToM_ComplexPickupmessage;
	
	Default
	{
		ToM_Health.flashcolor "ed9090";
		ToM_Health.flashDuration 20;
		ToM_Health.flashAlpha 0.15;
	}
}

class ToM_HealthPickup : ToM_Health
{
	Default
	{
		ToM_Health.PickupNote "$TOM_UNIT_HP";
		XScale 0.5;
		YScale 0.5 / 1.2;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		scale.y = default.scale.x / level.pixelstretch;
	}
	
	override string GetPickupNote()
	{
		return String.Format("(\ca+%d %s\c-)", amount, StringTable.Localize(pickupnote));
	}
}

class ToM_HealthBonus : ToM_HealthPickup
{
	Default
	{
		+COUNTITEM
		+INVENTORY.ALWAYSPICKUP
		Inventory.pickupMessage "$TOM_ITEM_HEALTH1";
		Inventory.amount 1;
		Inventory.maxamount 200;
		Inventory.Pickupsound "pickups/health/petal";
		XScale 0.6;
		YScale 0.6 / 1.2;
	}
	
	States {
	Spawn:
		AROS A -1 NoDelay
		{
			frame += random[rosesprite](0,4);
		}
		stop;
	}
}

class ToM_StimPack : ToM_HealthPickup
{
	Default
	{
		Inventory.pickupMessage "$TOM_ITEM_HEALTH10";
		Inventory.amount 10;
		Inventory.maxamount 100;
		Inventory.Pickupsound "pickups/health/bud";
		XScale 0.4;
		YScale 0.4 / 1.2;
	}
	
	States {
	Spawn:
		AROS F -1 NoDelay
		{
			frame += random[rosesprite](0,2);
		}
		stop;
	}
}

class ToM_Medikit : ToM_HealthPickup
{
	Default
	{
		Inventory.pickupMessage "$TOM_ITEM_HEALTH25";
		Inventory.amount 25;
		Inventory.maxamount 100;
		Inventory.Pickupsound "pickups/health/flower";
	}
	
	States {
	Spawn:
		AROS I -1 NoDelay
		{
			frame += random[rosesprite](0,5);
		}
		stop;
	}
}

class ToM_Soulsphere : ToM_HealthPickup
{
	static const color MagicBudCol[] =
	{
		"9f1b1b",
		"d84848",
		"ff4343"
	};

	Default
	{
		+COUNTITEM
		+INVENTORY.ALWAYSPICKUP
		Inventory.pickupMessage "$TOM_ITEM_HEALTH100";
		Inventory.amount 100;
		Inventory.maxamount 200;
		Inventory.Pickupsound "pickups/health/magicbud";
		FloatBobStrength 0.65;
		ToM_Health.flashDuration 30;
		ToM_Health.flashAlpha 0.4;
	}

	override void Tick()
	{
		super.Tick();
		if (owner || isFrozen() || bNOSECTOR)
			return;
		
		WorldOffset.z = BobSin(FloatBobPhase + 0.85 * level.maptime) * FloatBobStrength;
		
		if (GetAge() % 2 == 0)
		{
			double vx = frandom[mbcol](0.5, 1.5);
			double vz = frandom[mbcol](0.85, 1.5);
			int lt = random[mbcol](15, 23);
			A_SpawnParticle(
				MagicBudCol[random[mbcol](0, MagicBudCol.Size () -1)],
				flags: SPF_RELATIVE|SPF_FULLBRIGHT,
				lifetime: lt,
				size: random[mbcol](3,5),
				angle: random[mbcol](0, 359),
				xoff: frandom[mbcol](-12,12),
				zoff: frandom[mbcol](24, 30) +  WorldOffset.z,
				velx: vx,
				velz: vz,
				accelx: -(vx * 0.1),
				accelz: -(vz * 0.05),
				sizestep: -0.03
			);
		}
	}
	
	States {
	Spawn:
		AROS O -1;
		stop;
	}
}

class ToM_Megasphere : ToM_HealthPickup
{
	int timer;

	Default
	{
		+COUNTITEM
		+INVENTORY.ALWAYSPICKUP
		+INVENTORY.AUTOACTIVATE
		Inventory.pickupMessage "$TOM_ITEM_HEALTH200";
		Inventory.amount 200;
		Inventory.maxamount 200;
		Inventory.Pickupsound "pickups/health/magicflower";
		FloatBobStrength 0.65;
		ToM_Health.flashDuration 35;
		ToM_Health.flashAlpha 0.4;
	}
	
	override bool TryPickup(in out Actor toucher)
	{
		bool ret = Super.TryPickup(toucher);
		if (ret && toucher)
		{
			toucher.GiveInventory("ToM_GoldArmor", 1);
		}
		return ret;
	}
	
	override string GetPickupNote()
	{
		string hp = String.Format("+%d %s", amount, StringTable.Localize("$TOM_UNIT_HP"));
		string ar = String.Format("+200 %s", StringTable.Localize("$TOM_UNIT_ARMOR"));
		return String.Format("(\ca%s\c-, \cy%s\c-)", hp, ar);
	}

	override void Tick()
	{
		super.Tick();
		if (owner || isFrozen())
			return;
		
		timer--;
		if (timer <= 0)
		{
			timer = random[mbcol](8, 30);
			double vx = frandom[mbcol](0.5, 1.5);
			double vz = frandom[mbcol](0.85, 1.5);
			int lt = random[mbcol](15, 23);
			A_SpawnParticle(
				ToM_Soulsphere.MagicBudCol[random[mbcol](0, ToM_Soulsphere.MagicBudCol.Size () -1)],
				flags: SPF_RELATIVE|SPF_FULLBRIGHT,
				lifetime: lt,
				size: random[mbcol](3,5),
				angle: random[mbcol](0, 359),
				xoff: frandom[mbcol](-12,12),
				zoff: frandom[mbcol](36, 38),
				velx: vx,
				velz: vz,
				accelx: -(vx * 0.1),
				accelz: -(vz * 0.05),
				sizestep: -0.03
			);
		}
	}
	
	States {
	Spawn:
		AROS P -1;
		stop;
	}
}

class ToM_JackBombPickup : ToM_Inventory
{
	Default
	{
		+DECOUPLEDANIMATIONS
		Tag "$TOM_ITEM_JACKBOMB";
		Inventory.pickupmessage "$TOM_ITEM_JACKBOMB";
		Inventory.amount 1;
		Inventory.maxamount 15;
		Scale 1.5;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		SetAnimation('handle_turn', endframe: 0, flags: SAF_INSTANT);
	}

	States {
	Spawn:
		M000 A -1;
		stop;
	}
}

class ToM_JackBombProjectile : ToM_Projectile
{
	double rotangle;

	static const color popcolors[] = 
	{
		"ff0000",
		"2448ff",
		"ffed24",
		"ff8124",
		"11ea11"
	};

	Default
	{
		Projectile;
		-NOGRAVITY
		+BOUNCEONFLOORS
		+BOUNCEONCEILINGS
		+BOUNCEONWALLS
		+ALLOWBOUNCEONACTORS
		+BOUNCEONACTORS
		+CANBOUNCEWATER
		+DECOUPLEDANIMATIONS
		BounceFactor 0.5;
		WallBounceFactor 0.8;
		Damage 0;
		SeeSound "weapons/jackbomb/throw";
		Speed 20;
		Scale 1.5;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		SetAnimation('handle_turn', endframe: 0, flags: SAF_INSTANT);
	}

	States {
	Spawn:
		M000 A 1 
		{
			if (vel.Length() < 3)
			{
				bMissile = false;
				SetStateLabel("Death");
			}
			rotangle += vel.xy.Length();
			A_SetAngle(rotangle, SPF_INTERPOLATE);
		}
		loop;
	Death:
		M000 A 80 
		{
			SetAnimation('handle_turn', flags: SAF_LOOP);
			A_StartSound("weapons/jackbomb/music");
		}
		M000 A 25
		{
			SetAnimation('doll_popout', 22);
			A_StartSound("weapons/jackbomb/dollpop");
			FSpawnParticleParams pp;
			pp.style = STYLE_Normal;
			pp.size = 5;
			pp.flags = SPF_FULLBRIGHT;
			pp.startalpha = 1;
			pp.fadestep = -1;
			pp.lifetime = 35;
			pp.pos = pos+(0,0,10);
			double v = 3;
			for (int i = 25; i > 0; i--)
			{
				pp.color1 = popcolors[random[popc](0, popcolors.Size()-1)];
				pp.vel.x = frandom[popc](-v, v);
				pp.vel.y = frandom[popc](-v, v);
				pp.vel.z = frandom[popc](4, 7);
				pp.accel.xy = pp.vel.xy*-0.03;
				pp.accel.z = -0.35;
				Level.SpawnParticle(pp);
			}
		}
	DeathFlame:
		M000 A TICRATE * 3 
		{
			rotangle = angle;
			SetAnimation('doll_lean', 30, flags:SAF_LOOP);
		}
	DeathFlameRotate:
		M001 ABCDEFGHIJKLMNOPQRSTUVWX 1
		{
			bDECOUPLEDANIMATIONS = false;
			rotangle -= 360.0 / (TICRATE * 3);
			let p = A_SpawnProjectile('DoomImpBall', 32, angle: rotangle, flags: CMF_AimDirection);
			if (target && p)
			{
				p.target = target;
			}
		}
		loop;
	DeathBoom:
		M000 A 42 SetAnimation('doll_lean', 32, flags:SAF_LOOP);
		TNT1 A 0
		{
			A_StartSound("weapons/jackbomb/explode");
			A_Explode();
			ToM_GenericExplosion.Create(pos, scale: 0.8, randomdebris: 5, smokingdebris: 0);
		}
		stop;
	}
}

class ToM_Backpack : Backpack
{
	array <ToM_Ammo> floatingAmmo;
	int lastblink;
	int jiggleStartTic;

	static const class<ToM_Ammo> manaClasses[] =
	{
		'ToM_WeakMana',
		'ToM_WeakManaBig',
		'ToM_MediumMana',
		'ToM_MediumManaBig',
		'ToM_StrongMana',
		'ToM_StrongManaBig'
	};

	array <color> particleColors;
	uint colorDelay;
	bool isVisible;
	TextureID partTex;

	Default
	{
		+FORCEXYBILLBOARD
		+ROLLSPRITE
		+Inventory.AUTOACTIVATE
		Inventory.pickupsound "pickups/manachest";
		Inventory.pickupmessage "$TOM_ITEM_BACKPACK";
		XScale 0.75;
		YScale 0.75 / 1.2;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		scale.y = default.scale.x / level.pixelstretch;

		for (int i = 0; i < manaClasses.Size(); i++)
		{
			let def = GetDefaultByType(manaClasses[i]);
			if (def)
			{
				particleColors.Push(def.particleColor);
			}
		}
	}

	override void Tick()
	{
		Super.Tick();
		if (!(owner || bNOSECTOR) && !isFrozen())
		{
			if (GetAge() % 10 == 0)
			{
				isVisible = Distance3D(players[consoleplayer].mo) <= 400;
			}

			if (InStateSequence(curstate, FindState("Jiggle")))
			{
				int fr = int(round(ToM_Utils.LinearMap(roll, -5, 5, 0, 6, true)));
				frame = fr;
				int time = level.time - jiggleStartTic;
				roll = sin(360.0 * time * 0.05) * 5;
				spriteOffset.y = -abs(roll)*0.5;
				if (abs(roll) >= 5)
				{
					//A_StartSound("pickups/manachest/gemspawn", CHAN_AUTO, volume: 0.4, pitch:frandom[managem](1, 1.08));
					SpawnManaGem(-roll, -roll * 12 + frandom[managem](-15, 15));
				}
			}
		}
	}

	void SpawnManaGem(double horOffset = 0, double angdir = 0)
	{
		if (!partTex || !partTex.IsValid())
		{
			partTex = TexMan.CheckForTexture("LENYA0");
		}

		int i = random[managem](0, manaClasses.Size() - 1);
		let def = GetDefaultByType(manaClasses[i]);
		TextureID tex = def.FindState("Idle").GetSpriteTexture(0);
		double pang = players[consoleplayer].mo.angle + 180;
		Vector2 hofs = Actor.RotateVector((6, horOffset), pang);
		Vector2 hdir = Actor.RotateVector((frandom[managem](0.25, 0.8), 0), pang + angdir);
		let v = ToM_ManaShard(
			VisualThinker.Spawn('ToM_ManaShard', 
				tex, 
				pos + (hofs, frandom[managem](26, 29)), //pos
				(hdir, frandom[managem](0.5, 2)), //vel
				alpha: 0.5,
				flags: SPF_FULLBRIGHT|SPF_ROLL,
				roll: frandom[managem](0,360),
				scale: def.scale * frandom[managem](0.15, 0.25),
				style: STYLE_Add)
		);
		v.chest = self;
		v.particleColor = def.particleColor;
		v.partTex = partTex;
	}

	enum EManaTypes
	{
		MANA_WEAK,
		MANA_MEDIUM,
		MANA_STRONG,
	}
	int prePickupManaAmounts[3];
	Actor chestReceiver;

	override bool TryPickup(in out Actor toucher)
	{
		if (toucher && toucher.player)
		{
			prePickupManaAmounts[MANA_WEAK] = toucher.CountInv('ToM_WeakMana');
			prePickupManaAmounts[MANA_MEDIUM] = toucher.CountInv('ToM_MediumMana');
			prePickupManaAmounts[MANA_STRONG] = toucher.CountInv('ToM_StrongMana');
		}
		bool ret = Super.TryPickup(toucher);
		if (ret)
		{
			chestReceiver = toucher;
		}
		return ret;
	}

	override bool HandlePickup(Inventory item)
	{
		bool ret = Super.HandlePickup(item);
		if (ret)
		{
			chestReceiver = owner;
		}
		return ret;
	}

	override string PickupMessage()
	{
		String basemsg = StringTable.Localize(pickupMsg);
		if (!chestReceiver) return basemsg;

		String note;
		for (int i = 0; i < prePickupManaAmounts.Size(); i++)
		{
			Ammo mana;
			switch (i)
			{
			case MANA_WEAK:
				mana = Ammo(chestReceiver.FindInventory('ToM_WeakMana'));
				break;
			case MANA_MEDIUM:
				mana = Ammo(chestReceiver.FindInventory('ToM_MediumMana'));
				break;
			case MANA_STRONG:
				mana = Ammo(chestReceiver.FindInventory('ToM_StrongMana'));
				break;
			}
			if (mana)
			{
				bool needComma = (note != "");
				note.AppendFormat("%s%s \cf+%d\c-", needComma? ", " : "", StringTable.Localize(mana.GetTag()), mana.amount - prePickupManaAmounts[i]);
			}
		}

		return String.Format("%s (%s)", basemsg, note);
	}

	States {
	Spawn:
		AMPA A random(3, 35) NoDelay
		{
			A_SetRoll(0, SPF_INTERPOLATE);
			spriteOffset.y = 0;
		}
		TNT1 A 0 
		{
			if (isVisible && random[ammochest](0, 100) >= 75)
			{
				jiggleStartTic = level.maptime;
				return ResolveState("Jiggle");
			}
			int i = 1;
			while (i == lastblink)
			{
				i = random[ammochest](1, 5);
			}
			lastblink = i;
			return FindStateByString("Blink"..i);
		}
	Blink1:
		AMPA BCBD 4;
		TNT1 A 0 { return spawnstate; }
	Blink2:
		AMPA EFEG 4;
		TNT1 A 0 { return spawnstate; }
	Blink3:
		AMPA HIHJ 4;
		TNT1 A 0 { return spawnstate; }
	Blink4:
		AMPA KLKM 4;
		TNT1 A 0 { return spawnstate; }
	Blink5:
		AMPA NONP 4;
		TNT1 A 0 { return spawnstate; }
		stop;
	Jiggle:
		AMBA # random(25, 50);
		AMBA # 1
		{
			if (abs(roll) < 0.1)
			{
				return spawnstate;
			}
			return ResolveState(null);
		}
		wait;
	}
}

class ToM_ManaShard : VisualThinker
{
	Actor chest;
	color particleColor;
	double particleOfs;
	TextureID partTex;
	double rollstep;

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		rollstep = frandom[partcol](-7, 7);
		Vector2 size = TexMan.GetScaledSize(texture);
		particleOfs = size.y * scale.y * 0.75;
	}

	override void Tick()
	{
		Super.Tick();
		if (!chest)
		{
			Destroy();
			return;
		}

		if (IsFrozen()) return;

		if (pos.z > chest.floorz)
		{
			roll += rollstep;
			vel.z -= 0.1;
			rollstep *= 0.97;
		}
		else
		{
			vel.z = 0;
			vel.xy *= 0.95;
			rollstep *= 0.9;
			alpha -= 0.05;
		}

		FSpawnParticleParams p;
		p.lifetime = 25;
		p.color1 =  particleColor;
		p.texture = partTex;
		p.style = STYLE_AddShaded;
		p.flags = SPF_FULLBRIGHT;
		p.pos = pos + (0,0,particleOfs);
		p.size = 56 * scale.x;
		p.sizestep = p.size / double(-p.lifetime);
		p.startalpha = alpha;
		p.fadestep = -1;
		Level.SpawnParticle(p);

		if (alpha <= 0)
		{
			Destroy();
		}
	}
}

class ToM_Allmap : AllMap
{
	Default
	{
		XScale 0.14;
		YScale 0.14 / 1.2;
		+ROLLSPRITE
		+ROLLCENTER
		Inventory.PickupSound "pickups/allmap";
		Inventory.PickupMessage "$TOM_ITEM_ALLMAP";
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		scale.y = default.scale.x / level.pixelstretch;
	}

	States {
	Spawn:
		MAGU A 1
		{
			double phase = 360.0 * (GetAge() + FloatBobPhase);
			double bob = sin(phase * 0.01);
			double bobroll = sin(phase * 0.005);
			WorldOffset.z = 4 * bob;
			A_SetRoll(8 * bobroll, SPF_INTERPOLATE);
		}
		loop;
	}
}