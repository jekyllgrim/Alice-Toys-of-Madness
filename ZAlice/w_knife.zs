class ToM_Knife : ToM_BaseWeapon
{
	bool rightSlash;
	int combo;
	int trailFrame;
	
	const PSP_KnifeTrail = -30;
	
	Default 
	{
		+WEAPON.MELEEWEAPON;
		+WEAPON.NOAUTOFIRE;
		//Obituary "";
		Tag "Vorpal Knife";
		weapon.slotnumber 1;
		//inventory.icon "";
		//weapon.upsound "weapons/knife/draw";
	}
	
	States
	{
	Select:
		TNT1 A 0 
		{
			A_WeaponOffset(-24, 86);
			A_OverlayPivot(OverlayID(), 0.6, 0.8);
			A_OverlayRotate(OverlayID(), 30);
		}
		VKNF AAAAAA 1
		{
			A_WeaponOffset(4, -9, WOF_ADD);
			A_OverlayRotate(OverlayID(), -5, WOF_ADD);
			A_WeaponReady(WRF_NOFIRE|WRF_NOBOB);
		}
		TNT1 A 0
		{
			A_WeaponOffset(0, 32);
			A_OverlayRotate(OverlayID(), 0);
		}
		goto Ready;
	Deselect:
		TNT1 A 0 A_OverlayPivot(OverlayID(), 1, 1);
		VKNF AAAAAA 1
		{
			A_WeaponOffset(-4, 9, WOF_ADD);
			A_OverlayRotate(OverlayID(), 5, WOF_ADD);
		}
		TNT1 A 0 A_Lower;
		wait;
	Ready:
		TNT1 A 0 
		{
			ResetPSprite(OverlayID());
			invoker.rightSlash = false;
			invoker.combo = 0;
		}
		VKNF A 1 A_WeaponReady;
		wait;
	Fire:
		VKNF A 0 
		{
			invoker.trailFrame = 0;
			invoker.combo++;
			if (invoker.combo >= 5)
			{
				invoker.combo = 0;
				return ResolveState("DownSlash");
			}
			invoker.rightSlash = !invoker.rightSlash;
			let st = invoker.rightSlash ? ResolveState("RightSlash") : ResolveState("LeftSlash");			
			return st;
		}
	RightSlash:
		TNT1 A 0 
		{
			ResetPSprite(OverlayID());
			A_OverlayPivot(OverlayID(), 0.5, 0.5);
			//A_OverlayRotate(OverlayID(), frandom[wrot](-30,0), WOF_INTERPOLATE);
		}
		VKNF ###BB 1
		{
			A_WeaponOffset(16, 0, WOF_ADD);
			//A_OverlayRotate(OverlayID(), -5, WOF_ADD);
		}
		TNT1 A 0 A_StartSound("weapons/knife/swing", CHAN_AUTO);
		VKNF BBB 1
		{
			A_WeaponOffset(-42, 0, WOF_ADD);
			//A_OverlayRotate(OverlayID(), 5, WOF_ADD);
		}
		TNT1 C 0
		{
			A_CustomPunch(15, true, CPF_NOTURN, "ToM_KnifePuff");
		}
		VKNF CCC 1
		{
			A_WeaponOffset(-42, 0, WOF_ADD);
			//A_OverlayRotate(OverlayID(), 3, WOF_ADD);
			A_Overlay(PSP_KnifeTrail, "AfterImage");
		}
		VKNF CCCCCAAAAA 1
		{
			A_WeaponOffset(17.2, 0, WOF_ADD);
			//A_OverlayRotate(OverlayID(), -0.1, WOF_ADD);
			A_WeaponReady(WRF_NOBOB);
		}
		goto ready;
	LeftSlash:
		TNT1 A 0 
		{
			ResetPSprite(OverlayID());
			A_OverlayPivot(OverlayID(), 0.9, 0.7);
			//A_OverlayRotate(OverlayID(), frandom[wrot](0,30), WOF_INTERPOLATE);
		}
		VKNF ###DD 1
		{
			A_WeaponOffset(-32, -4, WOF_ADD);
			//A_OverlayRotate(OverlayID(), 5, WOF_ADD);
		}
		TNT1 A 0 A_StartSound("weapons/knife/swing", CHAN_AUTO);
		VKNF DDD 1
		{
			A_WeaponOffset(44, 4, WOF_ADD);
			//A_OverlayRotate(OverlayID(), -5, WOF_ADD);
		}		
		TNT1 E 0 
		{
			A_CustomPunch(15, true, CPF_NOTURN, "ToM_KnifePuff");
		}
		VKNF EEE 1
		{
			A_WeaponOffset(44, 4, WOF_ADD);
			//A_OverlayRotate(OverlayID(), -3, WOF_ADD);
			A_Overlay(PSP_KnifeTrail, "AfterImage");
		}
		VKNF EEEEFFFAAA 1
		{
			A_WeaponOffset(-10.4, -0.4, WOF_ADD);
			//A_OverlayRotate(OverlayID(), 0.1, WOF_ADD);
			A_WeaponReady(WRF_NOBOB);
		}
		goto ready;
	DownSlash:
		TNT1 A 0 
		{
			ResetPSprite(OverlayID());
			A_OverlayPivot(OverlayID(), 0.5, 1);
			//A_OverlayRotate(OverlayID(), frandom[wrot](-10,10), WOF_INTERPOLATE);
		}
		VKNF FFFF 1
		{
			A_WeaponOffset(5, -4, WOF_ADD);
		}
		TNT1 A 0 A_StartSound("weapons/knife/swing", CHAN_AUTO);		
		VKNF FFG 1
		{
			A_WeaponOffset(-12, 18, WOF_ADD);
		}		
		TNT1 G 0 
		{
			A_CustomPunch(25, true, CPF_NOTURN, "ToM_KnifePuff");
		}
		VKNF GGG 1
		{
			A_Overlay(PSP_KnifeTrail, "AfterImage");
			A_WeaponOffset(-18, 18, WOF_ADD);
		}
		VKNF GGGFFFAA 1
		{
			A_WeaponOffset(8.75, -7.5, WOF_ADD);
			A_WeaponReady(WRF_NOBOB);
		}
		goto ready;
	AfterImage:
		VKNA # 0
		{
			let psp = player.FindPSprite(PSP_Weapon);
			let ps1 = player.FindPSprite(OverlayID());
			if (psp && ps1)
			{
				ps1.pivot = psp.pivot;
				ps1.HAlign = psp.HAlign;
				ps1.VAlign = psp.VAlign;
				ps1.rotation = psp.rotation;
			}
		}
		VKNA # 1
		{
			let psp = player.FindPSprite(PSP_Weapon);
			let ps1 = player.FindPSprite(OverlayID());
			if (psp && ps1)
			{
				ps1.frame = psp.frame;
			}
		}
		stop;
	}
}


class ToM_KnifePuff : ToM_BasePuff
{
	Default
	{
		+NOINTERACTION
		+PUFFONACTORS
		seesound "weapons/knife/hitflesh";
		attacksound "weapons/knife/hitwall";
	}
}