class ToM_KickWeapon : Weapon
{
	protected state kickstate;
	
	Default
	{
		Inventory.Maxamount 1;
		Inventory.Icon "TNT1A0";
		+INVENTORY.UNDROPPABLE
		+INVENTORY.UNTOSSABLE
		+INVENTORY.PERSISTENTPOWER		
	}
	
	action void A_AliceKick()
	{
		//A_CustomPunch(30, true, CPF_NOTURN, pufftype: "ToM_Kickpuff", range: 80);
	}
	
	override void DoEffect()
	{
		super.DoEffect();
		if (!owner || !owner.player || owner.health <= 0)
			return;
		
		if (!kickstate)
			kickstate = ResolveState("Kick");
		
		let plr = owner.player;
		if (kickstate && plr && (plr.cmd.buttons & BT_USER4))
		{
			let psp = plr.FindPSprite(APSP_Kick);
			if (!psp || !InStateSequence(psp.curstate, kickstate))
				plr.SetPSprite(APSP_Kick, kickstate);
		}
	}
	
	States
	{
	Ready:Fire:Select:Deselect:
		TNT1 A 1;
		stop;
	Kick:
		AKIK AB 1;
		TNT1 A 0 A_StartSound("weapons/kick/whip", CHAN_AUTO);
		AKIK CDEF 1;
		AKIK G 2 A_AliceKick();
		AKIK HIJKLM 2;
		goto kickEnd;
	KickEnd:
		AKIK NO 2;
		fail;
	}
}


class ToM_Kickpuff : ToM_BasePuff
{
	Default
	{
		Attacksound "weapons/kick/hitwall";
		Seesound "weapons/kick/hitflesh";
	}
}