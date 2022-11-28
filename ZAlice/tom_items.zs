class ToM_InventoryToken : Inventory abstract 
{
	mixin ToM_CheckParticles;
	int age;
	
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
		if (!owner || (owner.player && ToM_Mainhandler.IsVoodooDoll(PlayerPawn(owner)))) 
		{
			Destroy();
			return;
		}
		if (owner && !owner.isFrozen())
			age++;
	}
	
	override void Tick() {}
}

class ToM_ControlToken : ToM_InventoryToken abstract
{
	protected int timer;
	protected int effectFreq;
	protected int duration;
	property duration : duration;
	property EffectFrequency : effectFreq;
	
	Default
	{
		ToM_ControlToken.duration 35;
		ToM_ControlToken.EffectFrequency 35;
	}
	
	void ResetTimer()
	{
		timer = 0;
	}
	
	int GetTimer()
	{
		return timer;
	}
	
	virtual void DoControlEffect()
	{}
	
	override void DoEffect()
	{
		super.DoEffect();
		if (self && owner && !owner.isFrozen())
		{
			timer++;
			
			if (effectFreq > 0 && (timer % effectFreq == 0))
			{
				DoControlEffect();
			}
			
			if (timer >= duration)
			{
				Destroy();
				return;
			}
		}
	}
}

class ToM_InvReplacementControl : ToM_InventoryToken 
{
	//Class<Inventory> latestPickup; //keep track of the latest pickup
	//string latestPickupName; //the tag of the latest pickup
	//bool codexOpened;

	static const Class<Weapon> vanillaWeapons[] = 
	{
		"Fist",
		"Chainsaw",
		"Pistol",
		"Shotgun",
		"SuperShotgun",
		"Chaingun",
		"RocketLauncher",
		"PlasmaRifle",
		"BFG9000"
	};
	
	static const Class<Weapon> modWeapons[] = 
	{
		"ToM_Knife",
		"ToM_HobbyHorse",
		"ToM_Cards",
		"ToM_Cards",
		"ToM_Jacks",
		"ToM_PepperGrinder",
		"ToM_Teapot",
		"ToM_Eyestaff",
		"ToM_Blunderbuss"
	};
	
	static const Class<Inventory> vanillaItems[] = {
		"GreenArmor",
		"BlueArmor"
	};
	static const Class<Inventory> modItems[] = {
		"ToM_SilverArmor",
		"ToM_GoldArmor"
	};
	
	static const Class<Inventory> extraItems[] =
	{
		"FWeapFist"
	};
	
	static const Class<Inventory> modExtraItems[] =
	{
		"ToM_Knife"
	};
	
	//here we make sure that the player will never have vanilla weapons in their inventory:
	override void DoEffect() 
	{
		super.DoEffect();
		if (!owner || !owner.player)
			return;
	
		let plr = owner.player;
		array < int > changeweapons; //stores all weapons that need to be exchanged
		int selweap = -1; //will store readyweapon
		
		//record all weapons that need to be replaced
		for (int i = 0; i < vanillaWeapons.Size(); i++) 
		{
			//if a weapon is found, cache its position in the array:
			Class<Weapon> oldweap = vanillaWeapons[i];
			if (owner.CountInv(oldweap) >= 1) 
			{
				if (tom_debugmessages)  console.printf("found %s that shouldn't be here",oldweap.GetClassName());
				changeweapons.Push(i);
			}
			//also, if it was seleted, cache its number separately:
			if (owner.player.readyweapon && owner.player.readyweapon.GetClass() == oldweap)
				selweap = i;
		}
		
		//if no old weapons were found, do nothing else:
		if (changeweapons.Size() <= 0)
			return;
		
		for (int i = 0; i < vanillaWeapons.Size(); i++) 
		{
			//do nothing if this weapon wasn't cached:
			if (changeweapons.Find(i) == changeweapons.Size())
				continue;
			Class<Weapon> oldweap = vanillaWeapons[i];
			Class<Weapon> newweap = modWeapons[i];
			//remove old weapon
			owner.A_TakeInventory(oldweap);
			if (tom_debugmessages) console.printf("Exchanging %s for %s",oldweap.GetClassName(),newweap.GetClassName());
			if (!owner.CountInv(newweap)) 
			{
				owner.A_GiveInventory(newweap,1);
			}
		}		
		
		//select the corresponding new weapon if an old weapon was selected:
		if (selweap != -1) 
		{
			Class<Weapon> newsel = modWeapons[selweap];
			let wp = Weapon(owner.FindInventory(newsel));
			if (wp) 
			{
				if (tom_debugmessages) console.printf("Selecting %s", wp.GetClassName());
				owner.player.pendingweapon = wp;
			}
		}
		changeweapons.Clear();
	}
	
    override bool HandlePickup (Inventory item) 
	{
		bool ret = false;
		let oldItemClass = item.GetClassName();
        Class<Inventory> replacement =  null;
		
		// handle weapons:
		for (int i = 0; i < vanillaWeapons.Size(); i++) 
		{
			if (modWeapons[i] && oldItemClass == vanillaWeapons[i]) 
			{
				replacement = modWeapons[i];
				break;
			}
		}
		// handle items:
		if (!replacement)
		{
			for (int i = 0; i < vanillaItems.Size(); i++) 
			{
				if (modItems[i] && oldItemClass == vanillaItems[i]) 
				{
					replacement = modItems[i];
					break;
				}
			}
		}
		// handle extra cases:
		if (!replacement)
		{
			for (int i = 0; i < ExtraItems.Size(); i++) 
			{
				if (modExtraItems[i] && oldItemClass == ExtraItems[i]) 
				{
					replacement = modExtraItems[i];
					break;
				}
			}
		}
		
		// nothing found, giving as is:
        if (!replacement) 
		{
			if (tom_debugmessages > 1)
				console.printf("%s doesn't need replacing, giving as is",oldItemClass);
			ret = super.HandlePickup(item);
		}
		
		// otherwise give the found replacement:
		else 
		{
			int r_amount = GetDefaultByType(replacement).amount;
			item.bPickupGood = true;
			owner.A_GiveInventory(replacement,r_amount);
			if (tom_debugmessages) 
			{
				console.printf("Replacing %s with %s (amount: %d)",oldItemClass,replacement.GetClassName(),r_amount);
			}
			ret = true;
		}
		
		//RecordLastPickup(replacement ? replacement : item.GetClass());
        return ret;
    }
}

mixin class ToM_PickupSound 
{
	//default PlayPickupSound EXCEPT the sounds 
	// can play over each other
	override void PlayPickupSound (Actor toucher)	
	{
		double atten;
		int chan;
		int flags = 0;

		if (bNoAttenPickupSound)
			atten = ATTN_NONE;
		else
			atten = ATTN_NORM;
		if (toucher != NULL && toucher.CheckLocalView()) 
		{
			chan = CHAN_ITEM;
			flags = CHANF_NOPAUSE | CHANF_MAYBE_LOCAL | CHANF_OVERLAP;
		}
		else 
		{
			chan = CHAN_ITEM;
			flags = CHANF_MAYBE_LOCAL;
		}
		
		toucher.A_StartSound(PickupSound, chan, flags, 1, atten);
	}
}

mixin class ToM_PickupFlashProperties
{
	color flashColor;
	int flashDuration;
	double flashAlpha;
	//protected int flashTimer;
	property flashColor : flashColor;
	property flashDuration : flashDuration;
	property flashAlpha : flashAlpha;

	override bool TryPickup (in out Actor toucher)
	{
		let ret = super.TryPickup(toucher);
		if (ret && toucher)
		{
			toucher.A_SetBlend(flashColor, flashAlpha, flashDuration);
		}
		return ret;
	}
}

mixin class ToM_ComplexPickupmessage
{
	string pickupNote;
	property pickupNote : pickupNote;

	override string PickupMessage()
	{
		string finalmsg = StringTable.Localize(pickupMsg);
		
		string note = GetPickupNote();
		if (note)
		{
			finalmsg = String.Format("%s %s", finalmsg, note);
		}
		
		return finalmsg;
	}
	
	virtual string GetPickupNote() 
	{
		return StringTable.Localize(pickupNote);
	}
}

class ToM_Inventory : Inventory
{
	mixin ToM_CheckParticles;
	mixin ToM_PickupFlashProperties;
	mixin ToM_PickupSound;
	mixin ToM_ComplexPickupmessage;
}

class ToM_SilverArmor : GreenArmor
{
	mixin ToM_CheckParticles;
	mixin ToM_PickupFlashProperties;
	mixin ToM_PickupSound;
	mixin ToM_ComplexPickupmessage;
	
	Default
	{
		Inventory.icon "ACARM_1";
		Inventory.pickupsound "pickups/armor/light";
		xscale 0.5;
		yscale 0.45;
	}
	
	States
	{
	Spawn:
		AARM A -1;
		stop;
	}
}

class ToM_GoldArmor : BlueArmor
{
	mixin ToM_CheckParticles;
	mixin ToM_PickupFlashProperties;
	mixin ToM_PickupSound;
	mixin ToM_ComplexPickupmessage;
	
	Default
	{
		Inventory.icon "ACARM_2";
		Inventory.pickupsound "pickups/armor/heavy";
		xscale 0.5;
		yscale 0.45;
	}
	
	States
	{
	Spawn:
		AARM B -1;
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
		ToM_Health.flashcolor "f55d5d";
		ToM_Health.flashDuration 20;
		ToM_Health.flashAlpha 0.5;
	}
}

class ToM_HealthPickup : ToM_Health
{
	Default
	{
		ToM_Health.PickupNote "$TOM_UNIT_HP";
		xscale 0.5;
		yscale 0.415;
	}
	
	override string GetPickupNote()
	{
		return String.Format("(+%d %s)", amount, StringTable.Localize(pickupnote));
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
		xscale 0.6;
		yscale 0.5;
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
		ToM_Health.flashAlpha 0.7;
	}

	override void Tick()
	{
		super.Tick();
		if (owner || isFrozen())
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
		// This seemingly does nothing at all, but
		// the original Megasphere has it, so... :
		+INVENTORY.AUTOACTIVATE
		Inventory.pickupMessage "$TOM_ITEM_HEALTH200";
		Inventory.amount 200;
		Inventory.maxamount 200;
		Inventory.Pickupsound "pickups/health/magicflower";
		FloatBobStrength 0.65;
		ToM_Health.flashDuration 35;
		ToM_Health.flashAlpha 0.7;
	}
	
	override bool TryPickup(in out Actor toucher)
	{
		toucher.GiveInventory("ToM_GoldArmor", 1);
		return super.TryPickup(toucher);
	}
	
	override string GetPickupNote()
	{
		string hp = String.Format("+%d %s", amount, StringTable.Localize("$TOM_UNIT_HP"));
		string ar = String.Format("+200 %s", StringTable.Localize("$TOM_UNIT_ARMOR"));
		return String.Format("(%s, %s)", hp, ar);
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