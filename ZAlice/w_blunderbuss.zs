class ToM_Blunderbuss : ToM_BaseWeapon
{
	protected double charge;
	
	Default
	{
		+WEAPON.NOAUTOFIRE
		+WEAPON.BFG
		Weapon.slotnumber 7;
		Tag "Blunderbuss";
	}
	
	States
	{
	Select:
		BBUS A 0 
		{
			A_WeaponOffset(-24, 90+WEAPONTOP);
			A_OverlayPivot(OverlayID(), 0.6, 0.8);
			A_OverlayRotate(OverlayID(), 30);
		}
		#### ###### 1
		{
			A_WeaponOffset(4, -15, WOF_ADD);
			A_OverlayRotate(OverlayID(), -5, WOF_ADD);
			A_WeaponReady(WRF_NOFIRE|WRF_NOBOB);
		}
		goto Ready;
	Deselect:
		BBUS A 0
		{
			A_OverlayPivot(OverlayID(), 0.6, 0.8);
			A_StopSound(CHAN_WEAPON);
		}
		#### ###### 1
		{
			A_ResetZoom();
			A_WeaponOffset(-4, 15, WOF_ADD);
			A_OverlayRotate(OverlayID(), 5, WOF_ADD);
		}
		TNT1 A 0 A_Lower;
		wait;
	Ready:
		TNT1 A 0 A_ResetPsprite;
		BBUS A 1 
		{
			A_ResetZoom();
			A_WeaponReady();
		}
		wait;
	Fire:
		TNT1 A 0 A_StartSound("weapons/blunderbuss/fire");
		BBUS BBBBBBBBBBBBBBBBBBBBBBBBB 1
		{
			A_WeaponOffset(frandom[bbus](-invoker.charge, invoker.charge), WEAPONTOP + frandom[bbus](0, invoker.charge), WOF_INTERPOLATE);
			invoker.charge += 0.2;
			A_Overlay(APSP_Overlayer, "Flash");
			A_SpawnPSParticle("FireParticle", bottom: false, density: 3, xofs: 1.4, yofs: 1);
		}
		BBUS B 1 
		{
			A_FireProjectile("BFGBall");
			invoker.charge = 0;
			A_Recoil(18);
			if (pos.z <= floorz)
				vel.z += 6;
		}
		BBUS DF 1;
		BBUS FFFFFFFFFF 1 
		{
			A_WeaponOffset(30, 20, WOF_ADD);
		}
		TNT1 A 25;
		BBUS B 0 
		{
			A_WeaponOffset(-16, 90+WEAPONTOP);
			A_OverlayPivot(OverlayID(), 0.6, 0.8);
			A_OverlayRotate(OverlayID(), 45);
		}
		#### ########## 1
		{
			A_WeaponOffset(1.6, -9, WOF_ADD);
			A_OverlayRotate(OverlayID(), -4.5, WOF_ADD);
			A_WeaponReady(WRF_NOFIRE|WRF_NOBOB);
		}
		BBUS B 5;
		BBUR ABC 2;
		TNT1 A 0 A_StartSound("weapons/blunderbuss/cock");
		BBUR DE 4;
		goto Ready;
	Flash:
		BBUS X 2 bright
		{
			A_OverlayFlags(OverlayID(), PSPF_RENDERSTYLE|PSPF_FORCEALPHA, true);
			A_OverlayRenderstyle(OverlayID(), Style_Add);
			A_OverlayAlpha(OverlayID(), frandom[bbus](0.2, 1));
		}
		stop;
	FireParticle:
		BBUS S 1 bright 
		{
			A_OverlayPivotAlign(OverlayID(),PSPA_CENTER,PSPA_CENTER);
			A_OverlayFlags(OverlayID(),PSPF_RENDERSTYLE|PSPF_FORCEALPHA,true);
			A_OverlayRenderstyle(OverlayID(),Style_Add);
			double sc = frandom[bbus](0.8, 1.2);
			A_OverlayScale(OverlayID(),sc, sc);
		}
		#### ########## 1 bright 
		{
			double mod = 0.1;
			A_OverlayScale(OverlayID(),-mod,-mod,WOF_ADD);
			let psp = player.FindPSprite(OverlayID());
			if (psp) 
			{
				psp.alpha = Clamp(psp.alpha - mod, 0, 1);
				A_OverlayOffset(OverlayID(),psp.x += frandom[bbus](-0.75, 0.75), psp.y -= frandom[bbus](1.2, 2.4), WOF_INTERPOLATE);
			}
		}
		stop;
	}
}
		