class ToM_Jacks : ToM_BaseWeapon
{
	const RWAITFRAME = 14;
	int jackswait;

	Default
	{
		weapon.slotnumber 3;
		Tag "Jacks";
	}
	
	action void A_SetJacksFrame()
	{
		let psp = player.FindPSprite(OverlayID());
		if (!psp)
			return;
		
		psp.frame = invoker.jackswait <= 0 ? 0 : RWAITFRAME;
	}
	
	action state A_JacksReady()
	{
		A_WeaponReady(invoker.jackswait > 0 ? WRF_NOFIRE : 0);
		let psp = player.FindPSprite(OverlayID());
		if (psp && psp.frame == RWAITFRAME && invoker.jackswait <= 0)
			return ResolveState("JacksReload");
		return ResolveState(null);
	}
	
	override void DoEffect()
	{
		super.DoEffect();
		let weap = owner.player.readyweapon;
		if (weap && weap == self && jackswait > 0)
		{
			jackswait--;
		}
	}
	
	States
	{
	Select:
		AJCK A 0 
		{
			A_WeaponOffset(24, WEAPONTOP + 54);
			A_SetJacksFrame();
		}
		#### ###### 1
		{
			A_WeaponOffset(-4, -9, WOF_ADD);
			A_WeaponReady(WRF_NOFIRE|WRF_NOBOB);
		}
		goto Ready;
	Deselect:
		AJCK A 0 A_SetJacksFrame();
		#### ###### 1
		{
			A_WeaponOffset(4, 9, WOF_ADD);
		}
		TNT1 A 0 A_Lower;
		wait;
	Ready:
		AJCK A 0 A_SetJacksFrame();
		#### # 1 A_JacksReady();
		wait;
	JacksReload:
		AJCK OPRQRST 2;
		goto Ready;
	Fire:
		AJCK BCD 2;
		AJCK DDDD 1 A_WeaponOffset(1.5, 1, WOF_ADD);
		AJCK EEE 1 A_WeaponOffset(-20, 0, WOF_ADD);
		AJCK FFFF 1 A_WeaponOffset(-10, 10, WOF_ADD);
		AJCK FFF 1 A_WeaponOffset(-5, 15, WOF_ADD);
		TNT1 A 5;
		AJCK A 0 
		{
			A_WeaponOffset(40, WEAPONTOP + 60);
		}
		#### ##### 1
		{
			A_WeaponOffset(-8, -12, WOF_ADD);
			A_WeaponReady(WRF_NOFIRE|WRF_NOBOB);
		}
		goto Ready;
	Altfire:
		AJCK GGGHHH 1 A_WeaponOffset(-4, 1.5, WOF_ADD);
		AJCK IIIIIJ 1 A_WeaponOffset(-1.5, 1.5, WOF_ADD);
		AJCK KKLLL 1 A_WeaponOffset(5, -1, WOF_ADD);
		AJCK LLLLLLLLL 1 A_WeaponOffset(3, 1, WOF_ADD);
		AJCK MMMNN 1 A_ResetPSprite(OverlayID(), 5);
		TNT1 A 0 { invoker.jackswait = 70; }
		goto Ready;
	}
}
		