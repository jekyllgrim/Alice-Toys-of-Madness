class ToM_Blunderbuss : ToM_BaseWeapon
{
	protected double charge;
	protected double smokescale;
	protected double smokeofs;
	protected double smokeroll;
	
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
		TNT1 A 0 
		{
			A_StartSound("weapons/blunderbuss/fire");
			A_StartSound("weapons/blunderbuss/pull", CHAN_AUTO);
		}
		BBUS BBBBBBBBBBBBBBBBBBBBBBBBB 1
		{
			A_WeaponOffset(frandom[bbus](-invoker.charge, invoker.charge), WEAPONTOP + frandom[bbus](0, invoker.charge), WOF_INTERPOLATE);
			invoker.charge += 0.2;
			A_Overlay(APSP_Overlayer, "Flint");
			A_SpawnPSParticle("FireParticle", bottom: false, density: 3, xofs: 1.4, yofs: 1);
		}
		BBUS B 1 
		{
			A_Overlay(APSP_UnderLayer, "MuzzleSmoke");
			//A_Overlay(APSP_TopFX, "Flash");
			A_FireProjectile("ToM_Cannonball");
			invoker.charge = 0;
			A_Recoil(14);
			if (pos.z <= floorz)
				vel.z += 6;
		}
		TNT1 A 0 A_CameraSway(0, -12, 10);
		BBUS DF 1;
		BBUS FFFFFFFFFF 1 
		{
			A_WeaponOffset(30, 20, WOF_ADD);
			A_OverlayScale(OverlayID(), 0.08, 0.08, WOF_ADD);
		}
		TNT1 A 25;
		BBUS B 0 
		{
			A_WeaponOffset(-16, 90+WEAPONTOP);
			A_OverlayPivot(OverlayID(), 0.6, 0.8);
			A_OverlayRotate(OverlayID(), 45);
			A_OverlayScale(OverlayID(), 1, 1);
		}
		#### ########## 1
		{
			A_WeaponOffset(1.6, -9, WOF_ADD);
			A_OverlayRotate(OverlayID(), -4.5, WOF_ADD);
			A_WeaponReady(WRF_NOFIRE|WRF_NOBOB);
		}
		BBUS B 5;
		BBUR AB 2;
		TNT1 A 0 A_StartSound("weapons/blunderbuss/cock");
		BBUR CDE 4;
		goto Ready;
	Flint:
		BBUS X 2 bright
		{
			A_OverlayFlags(OverlayID(), PSPF_RENDERSTYLE|PSPF_FORCEALPHA, true);
			A_OverlayRenderstyle(OverlayID(), Style_Add);
			A_OverlayAlpha(OverlayID(), frandom[bbus](0.2, 1));
		}
		stop;
	/*Flash:
		BBUS Y 2 bright;
		stop;*/
	MuzzleSmoke:
		BBUS S 0
		{
			A_OverlayFlags(OverlayID(), PSPF_AddWeapon|PSPF_AddBob, false);
			A_OverlayFlags(OverlayID(), PSPF_ForceAlpha, true);
			A_OverlayOffset(OverlayID(), 0, WEAPONTOP);
			A_OverlayPivotAlign(OverlayID(),PSPA_CENTER,PSPA_CENTER);
			invoker.smokescale = frandom[bbus](0.12, 0.19);
			invoker.smokeofs = frandom[bbus](-1, -2);
			invoker.smokeroll = frandom[bbus](-5,5);
			A_OverlayRotate(OverlayID(), frandom[bbus](0, 359));
		}
		#### # 1
		{
			A_OverlayScale(OverlayID(), invoker.smokescale, invoker.smokescale, WOF_ADD);
			invoker.smokescale *= 0.93;
			A_OverlayRotate(OverlayID(), invoker.smokeroll, WOF_ADD);
			invoker.smokeroll *= 0.93;
			A_OverlayOffset(OverlayID(), invoker.smokeofs, invoker.smokeofs, WOF_ADD);
			invoker.smokeofs *= 0.96;
			A_PSPFadeOut(0.015);
		}
		wait;
	FireParticle:
		BBUS P 1 bright 
		{
			A_OverlayPivotAlign(OverlayID(),PSPA_CENTER,PSPA_CENTER);
			A_OverlayFlags(OverlayID(),PSPF_RENDERSTYLE|PSPF_FORCEALPHA,true);
			A_OverlayRenderstyle(OverlayID(),Style_Add);
			double sc = frandom[bbus](0.8, 1.5);
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

class ToM_Cannonball : ToM_Projectile
{
	Default
	{
		radius 16;
		height 10;
		damage (50);
		xscale 0.25;
		yscale 0.208;
		speed 50;
	}
	States
	{
	Spawn:
		BCAN A 1 NoDelay A_StartSound("weapons/blunderbuss/flyloop", CHAN_BODY, CHANF_LOOPING);
		loop;
	Death:
		TNT1 A 0
		{
			A_StartSound("weapons/blunderbuss/explode", CHAN_BODY, attenuation: 1);
			A_Explode(512, 512, XF_THRUSTZ, fulldamagedistance: 256);
		}
		MISL BCD 5 bright;
		stop;
	}
}