class ToM_HobbyHorse : ToM_BaseWeapon
{
	protected int combo;
	
	Default
	{
		Weapon.slotnumber 1;
		Weapon.slotpriority 1;
		Tag "Hobby Horse";
	}
	
	States
	{
	Select:
		HRS1 A 0 
		{
			A_WeaponOffset(-24, 90+WEAPONTOP);
			A_OverlayPivot(OverlayID(), 0.6, 0.8);
			A_OverlayRotate(OverlayID(), -18);
		}
		#### ###### 1
		{
			A_WeaponOffset(4, -15, WOF_ADD);
			A_OverlayRotate(OverlayID(), 3, WOF_ADD);
			A_WeaponReady(WRF_NOFIRE|WRF_NOBOB);
		}
		goto Ready;
	Deselect:
		HRS1 A 0
		{
			A_OverlayPivot(OverlayID(), 0.6, 0.8);
		}
		#### ###### 1
		{
			A_ResetZoom();
			A_WeaponOffset(-4, 15, WOF_ADD);
			A_OverlayRotate(OverlayID(), -3, WOF_ADD);
		}
		TNT1 A 0 A_Lower;
		wait;		
	Ready:
		HRS1 A 1 A_WeaponReady();
		loop;
	Fire:
		TNT1 A 0 
		{
			A_ResetPSprite();
			invoker.combo++;
			if (invoker.combo <= 1)
				return ResolveState("RightSwing");
			if (invoker.combo == 2)
				return ResolveState("LeftSwing");
			invoker.combo = 0;
			return ResolveState("Overhead");			
		}
	RightSwing:			
		HRS1 ABCDE 3;
		HRS1 FG 1;
		HRS1 H 3 A_Punch();
		HRS1 IJ 3;
		goto AttackEnd;
	LeftSwing:			
		HRS2 ABCDE 3;
		HRS2 FG 1;
		HRS2 H 3 A_Punch();
		HRS2 IJ 3;
		goto AttackEnd;
	Overhead:				
		HRS3 ABC 3;
		HRS3 DE 4;
		HRS3 F 5;
		HRS3 GH 1;
		HRS3 I 3 A_Punch();
		HRS3 J 3;
		TNT1 A 5;
		goto AttackEnd;
	AttackEnd:
		TNT1 A 5
		{
			A_WeaponOffset(24, 90+WEAPONTOP);
			//A_OverlayRotate(OverlayID(), -18);
		}
		HRS1 AAAAAA 1
		{
			A_WeaponOffset(-4, -15, WOF_ADD);
			//A_OverlayRotate(OverlayID(), 3, WOF_ADD);
			A_WeaponReady(WRF_NOBOB);
		}
		TNT1 A 0 { invoker.combo = 0; }		
		goto Ready;
	}
}