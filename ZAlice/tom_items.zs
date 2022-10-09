class ToM_InventoryToken : Inventory abstract 
{
	mixin ToM_Math;
	int age;
	protected transient CVar s_particles;
	
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
		if (!owner || (owner.player && ToM_Mainhandler.IsVoodooDoll(PlayerPawn(owner)))) {
			Destroy();
			return;
		}
		if (owner && !owner.isFrozen())
			age++;
	}
	
	override void Tick() {}
}

Class ToM_InvReplacementControl : ToM_InventoryToken {
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
	
	/*
	static const Class<Inventory> vanillaItems[] = {
		"GreenArmor",
		"BlueArmor",
		"BasicArmorPickup"
	};
	static const Class<Inventory> pkItems[] = {
		"PK_SilverArmor",
		"PK_GoldArmor",
		"PK_GoldArmor"
	};*/
	
	//here we make sure that the player will never have vanilla weapons in their inventory:
	override void DoEffect() {
		super.DoEffect();
		if (!owner || !owner.player)
			return;
		let plr = owner.player;
		array < int > changeweapons; //stores all weapons that need to be exchanged
		int selweap = -1; //will store readyweapon
		//record all weapons that need to be replaced
		for (int i = 0; i < vanillaWeapons.Size(); i++) {
			//if a weapon is found, cache its position in the array:
			Class<Weapon> oldweap = vanillaWeapons[i];
			if (owner.CountInv(oldweap) >= 1) {
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
		for (int i = 0; i < vanillaWeapons.Size(); i++) {
			//do nothing if this weapon wasn't cached:
			if (changeweapons.Find(i) == changeweapons.Size())
				continue;
			Class<Weapon> oldweap = vanillaWeapons[i];
			Class<Weapon> newweap = modWeapons[i];
			//remove old weapon
			owner.A_TakeInventory(oldweap);
			if (tom_debugmessages) console.printf("Exchanging %s for %s",oldweap.GetClassName(),newweap.GetClassName());
			if (!owner.CountInv(newweap)) {
				owner.A_GiveInventory(newweap,1);
			}
		}		
		//select the corresponding new weapon if an old weapon was selected:
		if (selweap != -1) {
			Class<Weapon> newsel = modWeapons[selweap];
			let wp = Weapon(owner.FindInventory(newsel));
			if (wp) {
				if (tom_debugmessages) console.printf("Selecting %s", wp.GetClassName());
				owner.player.pendingweapon = wp;
			}
		}
		changeweapons.Clear();
	}
	
    override bool HandlePickup (Inventory item) {
		bool ret = false;
		let oldItemClass = item.GetClassName();
        Class<Inventory> replacement =  null;
		for (int i = 0; i < vanillaWeapons.Size(); i++) {
			if (modWeapons[i] && oldItemClass == vanillaWeapons[i]) {
				replacement = modWeapons[i];
				break;
			}
		}
        if (!replacement) {
			if (tom_debugmessages > 1)
				console.printf("%s doesn't need replacing, giving as is",oldItemClass);
			ret = super.HandlePickup(item);
		}
		else {
			int r_amount = GetDefaultByType(replacement).amount;
			item.bPickupGood = true;
			owner.A_GiveInventory(replacement,r_amount);
			if (tom_debugmessages) {
				console.printf("Replacing %s with %s (amount: %d)",oldItemClass,replacement.GetClassName(),r_amount);
			}
			ret = true;
		}		
		//RecordLastPickup(replacement ? replacement : item.GetClass());
        return ret;
    }
	/*
	// This function records the latest item the player has picked up
	// for the first time. Used by the Codex to display the tab
	// for that item (if available).		
	void RecordLastPickup(class<Inventory> toRecord) {
		if (!toRecord || !owner || !owner.player)
			return;
		bool isInCodex = false;
		for (int i = 0; i < CodexCoveredClasses.Size(); i++) {
			if (toRecord is CodexCoveredClasses[i]) {
				isInCodex = true;
				break;
			}
		}
		if (!isInCodex)
			return;
		int pnum = owner.PlayerNumber();
		if (pnum < 0)
		  return;

		let it = ThinkerIterator.Create("PK_PickupsTracker", STAT_STATIC);	
		let tracker = PK_PickupsTracker(it.Next());
		if (!tracker) {
			if (tom_debugmessages)
				console.printf("Item track Thinker not found");
			return;
		}
		

		// We use a dynamic array to check that the player hasn't
		// picked up this item before, because CountInv won't catch
		// the items that don't actually get placed in the inventory,
		// such as armor.		
		if (toRecord is "PK_GoldPickup" && tracker.pickups[pnum].pickups.Find((class<Inventory>)("PK_GoldPickup")) == tracker.pickups[pnum].pickups.Size()) {
			tracker.pickups[pnum].pickups.Push((class<Inventory>)("PK_GoldPickup"));
			latestPickup = toRecord;
			latestPickupName = GetDefaultByType(toRecord).GetTag();
			codexOpened = false;
			if (tom_debugmessages) {
				console.printf("Latest pickup is %s",latestPickup.GetClassName());
			}
		}
		
		else if (tracker.pickups[pnum].pickups.Find(toRecord) == tracker.pickups[pnum].pickups.Size()) {
			tracker.pickups[pnum].pickups.Push(toRecord);
			latestPickup = toRecord;
			latestPickupName = GetDefaultByType(toRecord).GetTag();
			codexOpened = false;
			if (tom_debugmessages) {
				console.printf("Latest pickup is %s",latestPickup.GetClassName());
			}
		}
	}
	
	static const Class<Actor> CodexCoveredClasses[] = {
		'PK_Painkiller',
		'PK_Shotgun',
		'PK_Stakegun',
		'PK_Chaingun',
		'PK_ElectroDriver',
		'PK_Rifle',
		'PK_Boltgun',
		'PK_Soul',
		'PK_GoldSoul',
		'PK_MegaSoul',
		'PK_BronzeArmor',
		'PK_SilverArmor',
		'PK_GoldArmor',
		'PK_AmmoPack',
		'PK_PowerAntiRad',
		'PK_AllMap',
		'PowerChestOfSoulsRegen',
		'PK_WeaponModifier',
		'PK_PowerDemonEyes',
		'PK_PowerPentagram',
		'PK_GoldPickup'
	};*/
}