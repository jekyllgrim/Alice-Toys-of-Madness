class ToM_PepperGrinder : ToM_BaseWeapon
{
	const APSP_Righthand = APSP_TopFX + 1;
	
	protected int spinframe;
	
	Default
	{
		Weapon.slotnumber 4;
		Tag "Pepper Grinder";
	}
	
	action void A_PepperFlash()
	{
		A_Overlay(APSP_UnderLayer, "Flash");
		A_OverlayFlags(APSP_UnderLayer, PSPF_RenderStyle|PSPF_ForceAlpha, true);
		A_OverlayRenderstyle(APSP_UnderLayer, Style_Add);
		
		A_Overlay(APSP_TopFX, "Highlights");
		A_OverlayFlags(APSP_TopFX, PSPF_RenderStyle|PSPF_ForceAlpha, true);
		A_OverlayRenderstyle(APSP_TopFX, Style_Add);
	}
	
	action void A_PepperRecoil()
	{
		A_OverlayPivot(PSP_Weapon,0, 0);
		A_OverlayPivot(APSP_Righthand, 0, 0);
		A_OverlayPivot(APSP_UnderLayer, 0, 0);
		A_OverlayPivot(APSP_TopFX, 0, 0);
		double sc = frandom[eye](0, 0.028);
		A_OverlayScale(PSP_Weapon, 1 + sc, 1 + sc);
		A_OverlayScale(APSP_Righthand, 1 + sc, 1 + sc);
		A_OverlayScale(APSP_UnderLayer, 1 + sc, 1 + sc);
		A_OverlayScale(APSP_TopFX, 1 + sc, 1 + sc);
		//A_WeaponOffset(2 + frandom[ppgr](-1.4, 1.4), 34 + frandom[ppgr](0, 2), WOF_INTERPOLATE);
		A_AttackZoom(0.002, 0.03, 0.0016);
	}
	
	action void A_ResetPepperSprite()
	{
		A_ResetPSprite(PSP_Weapon);
		A_ResetPSprite(APSP_Righthand);
		A_ResetPSprite(APSP_UnderLayer);
		A_ResetPSprite(APSP_TopFX);
	}
	
	States
	{
	Select:
		PPGR Y 0 
		{
			A_ClearOverlays(APSP_Righthand, APSP_Righthand);
			A_WeaponOffset(-24, 90+WEAPONTOP);
			A_OverlayPivot(OverlayID(), 0.6, 0.8);
			A_RotatePSPrite(OverlayID(), 30);
		}
		#### ###### 1
		{
			A_WeaponOffset(4, -15, WOF_ADD);
			A_RotatePSPrite(OverlayID(), -5, WOF_ADD);
			A_WeaponReady(WRF_NOFIRE|WRF_NOBOB);
		}
		goto Ready;
	Deselect:
		PPGR Y 0
		{
			A_OverlayPivot(OverlayID(), 0.6, 0.8);
		}
		#### ###### 1
		{
			A_ResetZoom();
			A_WeaponOffset(-4, 15, WOF_ADD);
			A_RotatePSPrite(OverlayID(), 5, WOF_ADD);
		}
		TNT1 A 0 A_Lower;
		wait;
	Ready:
		PPGR Z 1
		{
			A_Overlay(APSP_Righthand, "Right.Ready", true);
			A_WeaponReady();
		}
		loop;
	Right.Ready:
		PPGR A -1;
		stop;
	Fire:
		PPGR Z 7 
		{
			A_Overlay(APSP_Righthand, "Right.Spin");
			A_StartSound("weapons/pgrinder/grindloop", CHAN_WEAPON, CHANF_LOOPING);
			A_StartSound("weapons/pgrinder/windup", CHAN_WEAPON);
		}
	Hold:
		PPGR Z 5 
		{
			A_PepperFlash();
			A_FireProjectile("ToM_PepperProjectile", angle: frandom[ppgr](-2,2), spawnofs_xy: frandom[ppgr](5.5,7), frandom[ppgr](4.5,6.5), pitch: frandom[ppgr](-2,2));
		}
		TNT1 A 0 A_ReFire();
		TNT1 A 0 
		{
			A_ResetPepperSprite();
			A_Overlay(APSP_Righthand, "Right.SpinEnd");
			A_StartSound("weapons/pgrinder/stop", CHAN_WEAPON);
		}
		PPGR Z 1;
		wait;
	Right.Spin:
		PPGR ABCDEFGHIJ 2
		{
			let psp = player.FindPSprite(OverlayID());
			if (psp)
			{
				//console.printf("frame: %d", psp.frame);
				invoker.spinframe = psp.frame;
			}
			if (player.refire)
				A_PepperRecoil();
		}
		loop;
	Right.SpinEnd:
		PPGR # 1
		{
			A_ResetZoom();
			A_ResetPSprite(OverlayID());
			let psp = player.FindPSprite(OverlayID());
			if (psp)
			{
				invoker.spinframe = Clamp(invoker.spinframe - 1, 0, 8);
				psp.frame = invoker.spinframe;
				if (invoker.spinframe <= 0)
				{
					//player.SetPSprite(PSP_Weapon, ResolveState("Ready"));
					return ResolveState("Right.End");
				}
			}
			return ResolveState(null);
		}
		wait;
	Right.End:
		PPGR JIHGFEDCB 2 A_ResetZoom();
		PPGR A 2
		{
			player.SetPSprite(PSP_Weapon, ResolveState("Ready"));
		}
		goto Right.Ready;
	Highlights:
		PPGF Z 1 bright;
		#### # 1 bright A_PSPFadeOut(0.25);
		wait;
	Flash:
		PPGF A 1 
		{
			//A_OverlayPivot(OverlayID(), 0.75, 0.75);
			let psp = player.FindPSprite(OverlayID());
			if (psp)
			{
				psp.frame = random[ppgr](0,2);
				//psp.rotation += frandom[ppgr](-8,8);
			}
		}
		#### # 1 bright A_overlayAlpha(OverlayID(),0.75);
		stop;
	}
}

class ToM_PepperProjectile : ToM_Projectile
{
	static const color pcolor[] =
	{
		"ff4242",
		"fb4834",
		"251308"
	};
	
	Default
	{
		seesound "weapons/pgrinder/fire";
		deathsound "";
		ToM_Projectile.flarecolor "fb4834";
		ToM_Projectile.trailcolor "fb4834";
		damage 3;
		translation "0:255=%[0.00,0.00,0.00]:[1.99,0.42,0.09]";
		renderstyle 'Add';
		scale 0.65;
		+BRIGHT
		speed 60;
	}
	
	States
	{
	Spawn:
		BAl7 AB 4;
		loop;
	Death:
		TNT1 A 0
		{
			A_StartSound("weapons/pgrinder/projdie", CHAN_AUTO, attenuation: 6);
			bFORCEXYBILLBOARD = true;			
			for (int i = random[bdsfx](8,12); i > 0; i --) {
				double vx = frandom[ppgr](1,4);
				color col = color(pcolor[random[ppgr](0, pcolor.Size()-1)]);
				A_SpawnParticle(
					col,
					flags: SPF_RELATIVE|SPF_FULLBRIGHT,
					lifetime: 30,
					size: 4,
					angle: random[bdsfx](0,359),
					velx: vx,
					velz: frandom[bdsfx](2,6),
					accelx: -vx * 0.05,
					accelz: -0.5,
					sizestep: 0.08
				);
			}
		}
		BAl7 CDE 3;
		stop;
	}
}