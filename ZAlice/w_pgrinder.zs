class ToM_PepperGrinder : ToM_BaseWeapon
{
	const APSP_Righthand = APSP_TopFX + 1;
	const FULLFRAME = 25;
	double crunchpitch;
	
	protected int spinframe;
	
	Default
	{
		Weapon.slotnumber 4;
		Tag "Pepper Grinder";
		weapon.ammotype1 "ToM_YellowMana";
		weapon.ammouse1 2;
		weapon.ammogive1 100;
		weapon.ammotype2 "ToM_YellowMana";
		weapon.ammouse2 20;
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
	
	action void A_FirePepperGun(double spread = 2, double spawnheight = 5.5, double spawnofs_xy = 5.7, bool hitscan = true)
	{
		double angleofs = frandom[ppgr](-spread,spread);
		double pitchofs = frandom[ppgr](-spread,spread);
		A_StartSound("weapons/pgrinder/fire", flags: CHANF_OVERLAP);
		let proj = A_FireProjectile(
			"ToM_PepperProjectile", 
			angle: angleofs,
			spawnofs_xy: spawnofs_xy + frandom[ppgr](-0.5,0.5),
			spawnheight: spawnheight + frandom[ppgr](-1,1),
			pitch: pitchofs
		);		
		if (hitscan)
		{
			A_FireBullets(angleofs, pitchofs, -1, int(3 * frandom(1., 8.)), "", FBF_NORANDOM|FBF_EXPLICITANGLE);
			FLineTraceData pp;
			double atkheight = ToM_BaseActor.GetPlayerAtkHeight(PlayerPawn(self));
			LineTrace(angle + angleofs, 4096, pitch + pitchofs, TRF_SOLIDACTORS, atkheight, data: pp);
			double pvel = Clamp(pp.Distance / 12.0, 160, 300);
			if (proj)
			{
				proj.SetDamage(0);
				proj.vel = proj.vel.unit() * pvel;
				proj.A_SetSize(1, 1);
			}
		}
	}
	
	States
	{
	Spawn:
		ALPG A -1;
		stop;
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
			A_FirePepperGun();
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
			let psp = player.FindPSprite(OverlayID());
			if (psp)
			{
				psp.frame = random[ppgr](0,2);
			}
		}
		#### # 1 bright A_overlayAlpha(OverlayID(),0.75);
		stop;
	AltFire:
		TNT1 A 0 
		{
			A_Overlay(APSP_Righthand, "Right.Chargealt");
			invoker.crunchpitch = 0.9;
			A_StartSound("weapons/pgrinder/windup", CHAN_7, CHANF_LOOPING, volume: 0.3, pitch: invoker.crunchpitch);
		}
		PPGR Z 1 
		{
			invoker.crunchpitch -= 0.003;
			A_SoundPitch(CHAN_7, invoker.crunchpitch);
		}
		wait;
	AltFireDo:
		PPGR Y 1 
		{
			let proj = A_FireArchingProjectile("ToM_PepperBomb", spawnofs_xy:8, spawnheight:2, flags:FPF_NOAUTOAIM, pitch:-8);
			if (proj)
			{
				A_StartSound("weapons/pgrinder/projdie", pitch:0.75, starttime: 0.2);
				proj.A_StartSound("weapons/pgrinder/projdie", pitch:0.6, starttime: 0.2);
			}
			A_QuakeEX(1,1,0,4,0,1, sfx:"world/null", flags:QF_SCALEDOWN);
			
			A_OverlayPivot(OverlayID(), 0.1, 0.8);
		}
		PPGR YYYY 1 
		{			
			A_RotatePSprite(OverlayID(), -0.85, WOF_ADD);
			A_ScalePsprite(OverlayID(), 0.03, 0.03, WOF_ADD);
		}
		TNT1 A 0 
		{
			A_ResetPSprite(OverlayID(), 30);
		}
		PPGR Y 30 A_WeaponReady(WRF_NOFIRE|WRF_NOBOB);
		PPGR Y 20 A_WeaponReady(WRF_NOFIRE);
		goto Ready;
	Right.Chargealt:
		TNT1 A 0 A_StartSound("weapons/pgrinder/crunch");
		PPGR JIHGFE 2 A_Weaponoffset(frandom(-1,1), WEAPONTOP + frandom(0, 2));
		PPGR DC 3 A_Weaponoffset(frandom(-1,1), WEAPONTOP + frandom(0, 2));
		PPGR BA 4 A_Weaponoffset(frandom(-1,1), WEAPONTOP + frandom(0, 2));
		//TNT1 A 0 A_StartSound("weapons/pgrinder/crunch", pitch:0.9);
		PPGR JIHGFE 4 A_Weaponoffset(frandom(-1,1), WEAPONTOP + frandom(0, 2));
		PPGR DC 5 A_Weaponoffset(frandom(-1,1), WEAPONTOP + frandom(0, 2));
		PPGR BA 6 A_Weaponoffset(frandom(-1,1), WEAPONTOP + frandom(0, 2));
		TNT1 A 0 
		{
			A_StopSound(CHAN_7);
			player.SetPSprite(PSP_Weapon, ResolveState("AltFireDo"));
		}
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
		renderstyle 'Normal';
		scale 0.16;
		+FORCEXYBILLBOARD
		+ROLLCENTER
		seesound "";
		deathsound "";
		//ToM_Projectile.ShouldActivateLines true;
		ToM_Projectile.flarecolor "fb4834";
		ToM_Projectile.trailcolor "fb4834";
		damage 3;
		speed 60;
	}
	
	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		wrot = frandompick[ppsfx](-5, 5);
		roll = frandom[ppsfx](0, 359);
	}
	
	States
	{
	Spawn:
		APPC A 1 { roll + wrot; }
		loop;
	Death:
		TNT1 A 1
		{
			A_StartSound("weapons/pgrinder/projdie", CHAN_AUTO, attenuation: 6);
			for (int i = random[ppsfx](8,12); i > 0; i --) {
				double vx = frandom[ppgr](1,4);
				color col = color(pcolor[random[ppgr](0, pcolor.Size()-1)]);
				A_SpawnParticle(
					col,
					flags: SPF_RELATIVE|SPF_FULLBRIGHT,
					lifetime: 30,
					size: 4,
					angle: random[ppsfx](0,359),
					velx: vx,
					velz: frandom[ppsfx](2,6),
					accelx: -vx * 0.05,
					accelz: -0.5,
					sizestep: 0.08
				);
			}
		}
		stop;
	}
}
					

class ToM_PepperProjectileVisual : ToM_PepperProjectile
{	
	Default
	{
		speed 150;
		damage 0;
	}
}

class ToM_PepperBomb : ToM_Projectile
{
	bool cheap;
	
	Default
	{
		ToM_Projectile.flarecolor "";
		ToM_Projectile.trailcolor "";
		renderstyle 'None';
		speed 14;
	}
	
	override void Tick()
	{
		super.Tick();
		if (isFrozen())
			return;
		
		vel *= 0.93;

		double v = vel.length();
		
		if (v <= 1.1 && GetAge() > 60)
		{
			Destroy();
			return;
		}
		
		if (GetAge() % 4 != 0)
			return;
			
		double svel = 10;// LinearMap(v, speed, 0, 3, 18);
		double sofs = 0;//LinearMap(v, speed, 0, 0, 18);
		double sscale = 0.5;//LinearMap(v, speed, 0, 0.22, 0.8);
		double salpha = 0.85;//LinearMap(v, speed, 0, 0.12, 0.75);
		
		let smk = ToM_WhiteSmoke.Spawn(
			pos,
			ofs: sofs,
			vel: (
				frandom[pbom](-svel,svel),
				frandom[pbom](-svel,svel),
				frandom[pbom](-svel,svel)
			),
			scale: sscale,
			alpha: salpha,
			fade: 0.002,
			dbrake: 0.85,
			//cheap: true,
			smoke: "ToM_PepperCloud"
		);
		if (smk)
		{
			smk.master = self;
			smk.A_SetRenderstyle(smk.alpha, Style_Shaded);
			smk.SetShade("000000");
		}
	}
	
	States
	{
	Spawn:
		TNT1 A 1;
		wait;
	Death:
		TNT1 A -1;
		stop;
	}
}


class ToM_PepperCloud : ToM_WhiteSmoke
{
	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		if (master)
		{
			vel += master.vel;
		}
	}
}