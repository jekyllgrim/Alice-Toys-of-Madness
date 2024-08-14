class ToM_PepperGrinder : ToM_BaseWeapon
{
	const APSP_Righthand = APSP_TopFX + 1;
	const FULLFRAME = 25;
	double crunchpitch;
	
	protected int spinframe;
	
	Default
	{
		Tag "$TOM_WEAPON_PGRINDER";
		ToM_BaseWeapon.CheshireSound "cheshire/vo/duchessnearby";
		Inventory.Icon "AWICPPGR";
		ToM_BaseWeapon.IsTwoHanded true;
		Weapon.slotnumber 4;
		weapon.ammotype1 "ToM_MediumMana";
		weapon.ammouse1 1;
		weapon.ammogive1 100;
		weapon.ammotype2 "ToM_MediumMana";
		weapon.ammouse2 1;
	}

	action void A_PepperReady()
	{
		A_Overlay(APSP_Righthand, "Right.Ready", true);
		A_ResetZoom();
		A_WeaponReady();
	}
	
	action void A_PepperFlash()
	{
		bool alt = invoker.bAltFire;
		state fl = alt ? ResolveState("AltFlash") : ResolveState("Flash");
		player.SetPSprite(APSP_UnderLayer, fl);
		A_OverlayFlags(APSP_UnderLayer, PSPF_RenderStyle|PSPF_ForceAlpha, true);
		A_OverlayRenderstyle(APSP_UnderLayer, Style_Add);
		A_OverlayPivot(APSP_UnderLayer, 0.36, 0.59);
		if (!alt)
		{
			double sc = frandom[pflash](0.7, 1.0);
			A_OverlayScale(APSP_UnderLayer, sc, sc, WOF_INTERPOLATE);
		}
		
		A_Overlay(APSP_TopFX, "Highlights");
		A_OverlayFlags(APSP_TopFX, PSPF_RenderStyle|PSPF_ForceAlpha, true);
		A_OverlayRenderstyle(APSP_TopFX, Style_Add);
	}

	action void A_ProgressSpinFrame(bool reverse = false)
	{
		invoker.spinframe += reverse ? -1 : 1;
		if (invoker.spinframe > 9)
			invoker.spinframe = 0;
		if (invoker.spinframe < 0)
			invoker.spinframe = 9;
		if (reverse)
			A_ResetZoom();
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
	
	action Actor A_FirePepperGun(double spread = 2, double spawnheight = 5.5, double spawnofs_xy = 5.7, bool hitscan = true)
	{
		double angleofs = frandom[ppgr](-spread,spread);
		double pitchofs = frandom[ppgr](-spread,spread);
		A_StartSound("weapons/pgrinder/fire", CHAN_WEAPON);

		// spawn projectiles unconditionally:
		Actor p1, proj;
		[p1, proj] = A_FireProjectile(
			"ToM_PepperProjectile", 
			angle: angleofs,
			spawnofs_xy: spawnofs_xy + frandom[ppgr](-0.5,0.5),
			spawnheight: spawnheight + frandom[ppgr](-1,1),
			pitch: pitchofs
		);		

		// in hitscan mode (primary attack) the projectilles
		// are still used but only for visuals:
		if (hitscan)
		{
			A_FireBullets(angleofs, pitchofs, -1, int(3 * frandom(5., 8.)), "ToM_PepperPuff", FBF_NORANDOM|FBF_EXPLICITANGLE);
			FLineTraceData pp;
			double atkheight = ToM_Utils.GetPlayerAtkHeight(PlayerPawn(self));
			LineTrace(angle + angleofs, 4096, pitch + pitchofs, TRF_SOLIDACTORS, atkheight, data: pp);
			double pvel = Clamp(pp.Distance / 12.0, 160, 300);
			if (proj)
			{
				proj.SetDamage(0);
				proj.vel = proj.vel.unit() * pvel;
				proj.A_SetSize(1, 1);
			}
		}
		return proj;
	}

	action void A_FirePepperSpray(double spread = 2, double spawnheight = 5.5, double spawnofs_xy = 5.7, int projectiles = 10)
	{
		A_PepperFlash();
		for (int i = 0; i < projectiles; i++)
		{
			let proj = A_FirePepperGun(spread, spawnheight, spawnofs_xy, hitscan: false);
			if (proj)
			{
				proj.vel = proj.vel.Unit() * 35;
				proj.bNOGRAVITY = false;
				proj.gravity = 0.5;
				proj.bBOUNCEONFLOORS = true;
				proj.bBOUNCEONWALLS = true;
				proj.bBOUNCEONCEILINGS = true;
			}
		}
		A_StartSound("weapons/pgrinder/fire", CHAN_WEAPON, CHANF_OVERLAP, startTime: 0.1);
		A_StartSound("weapons/pgrinder/fire", CHAN_WEAPON, CHANF_OVERLAP, startTime: 0.3);
		A_StartSound("weapons/pgrinder/fire", CHAN_WEAPON, CHANF_OVERLAP, startTime: 0.6);
		A_QuakeEX(1,1,0,4,0,1, sfx:"world/null", flags:QF_SCALEDOWN);
	}

	override void OnDeselect(Actor dropper)
	{
		super.OnDeselect(dropper);
		if (dropper)
		{
			dropper.A_StopSound(CHAN_7);
		}
	}
	
	States
	{
	/*Spawn:
		ALPG A -1;
		stop;*/
	Select:
		PPGR Y 0 
		{
			A_ClearOverlays(APSP_Righthand, APSP_Righthand);
			A_SetSelectPosition(-24, 90+WEAPONTOP);
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
			A_StopSound(CHAN_7);
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
		PPGR Z 1 A_PepperReady();
		loop;
	Right.Ready:
		PPGR A -1;
		stop;
	Fire:
		PPGR Z 5 
		{
			A_Overlay(APSP_Righthand, "Right.Spin");
			A_StartSound("weapons/pgrinder/grindloop", CHAN_7, CHANF_LOOPING);
			A_StartSound("weapons/pgrinder/windup", CHAN_WEAPON);
			player.refire++;
			A_PlayerAttackAnim(-1, 'attack_peppergrinder', 30, flags: SAF_LOOP|SAF_NOOVERRIDE);
		}
	Hold:
		PPGR Z 5
		{
			A_PepperFlash();
			A_FirePepperGun(1.3);
		}
		TNT1 A 0 A_ReFire();
		TNT1 A 0 
		{
			A_ResetPepperSprite();
			//A_Overlay(APSP_Righthand, "Right.SpinEnd");
			A_StopSound(CHAN_7);
			A_StartSound("weapons/pgrinder/stop", CHAN_WEAPON);
		}
		PPGR ZZZ 1
		{
			if (invoker.spinframe == 0)
			{
				let psp = player.FindPSprite(APSP_Righthand);
				if (psp)
					psp.Destroy();
				A_PlayerAttackAnim(1, 'attack_peppergrinder', 0);
				return ResolveState("Ready");
			}
			return ResolveState(null);
		}
		PPGR Z 1
		{
			if (invoker.spinframe == 0)
			{
				let psp = player.FindPSprite(APSP_Righthand);
				if (psp)
					psp.Destroy();
				A_PlayerAttackAnim(1, 'attack_peppergrinder', 0);
				return ResolveState("Ready");
			}
			A_ReFire();
			return ResolveState(null);
		}
		wait;
	Right.Spin:
		PPGR # 2
		{
			if (player.refire)
			{
				A_PepperRecoil();
			}
			A_ProgressSpinFrame(player.refire == 0);
			let psp = player.FindPSprite(OverlayID());
			if (psp)
			{
				psp.frame = invoker.spinframe;
			}
		}
		loop;
//	Right.SpinEnd:
//		PPGR # 1
//		{
//			A_ResetZoom();
//			let psp = player.FindPSprite(OverlayID());
//			if (psp)
//			{
//				invoker.spinframe = Clamp(invoker.spinframe - 1, 0, 8);
//				psp.frame = invoker.spinframe;
//				if (invoker.spinframe <= 0)
//				{
//					return ResolveState("Right.End");
//				}
//			}
//			return ResolveState(null);
//		}
//		wait;
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
	AltFlash:
		PPGF A 1 
		{
			A_OverlayPivot(OverlayID(), 0.36, 0.59);
			let psp = player.FindPSprite(OverlayID());
			if (psp)
			{
				psp.frame = random[ppgr](0,2);
			}
		}
		#### #### 1 bright 
		{
			let psp = player.FindPSprite(OverlayID());
			if (psp)
			{
				psp.alpha -= 0.1;
				psp.scale *= 0.86;
			}
		}
		stop;
	AltFire:
		TNT1 A 0 
		{
			A_Overlay(APSP_Righthand, "Right.Chargealt");
			invoker.crunchpitch = 0.9;
			A_PlayerAttackAnim(40, 'attack_peppergrinder_alt', 30);
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
			A_FirePepperSpray(6, projectiles: 8);
			A_OverlayPivot(OverlayID(), 0.1, 0.8);
		}
		PPGR YYYY 1 
		{
			A_RotatePSprite(OverlayID(), -0.85, WOF_ADD);
			A_ScalePsprite(OverlayID(), 0.03, 0.03, WOF_ADD);
		}
		TNT1 A 0 
		{
			A_ResetPSprite(OverlayID(), 10);
		}
		PPGR Y 6 A_WeaponReady(WRF_NOFIRE|WRF_NOBOB);
		PPGR Y 4 A_WeaponReady(WRF_NOSECONDARY);
		goto Ready;
	Right.Chargealt:
		TNT1 A 0 A_StartSound("weapons/pgrinder/crunch");
		PPGR JIHGFE 1 A_Weaponoffset(frandom(-1,1), WEAPONTOP + frandom(0, 2));
		PPGR DCB 1 A_Weaponoffset(frandom(-1,1), WEAPONTOP + frandom(0, 2));
		PPGR AAA 1 A_Weaponoffset(frandom(-2,2), WEAPONTOP + frandom(0, 2.5));
		TNT1 A 0 
		{
			player.SetPSprite(PSP_Weapon, ResolveState("AltFireDo"));
		}
		stop;
	}
}

class ToM_PepperProjectile : ToM_PiercingProjectile
{
	static const color pcolor[] =
	{
		"ff4242",
		"fb4834",
		"251308"
	};
	
	Default
	{
		mass 1;
		renderstyle 'Normal';
		scale 0.16;
		+FORCEXYBILLBOARD
		+ROLLCENTER
		BounceFactor 0.2;
		seesound "";
		deathsound "";
		damagetype 'Pepper';
		//ToM_Projectile.ShouldActivateLines true;
		ToM_Projectile.flarecolor "fb4834";
		ToM_Projectile.trailcolor "fb4834";
		ToM_Projectile.flarescale 0.12;
		damage 16;
		speed 60;
	}

	override void HitVictim(Actor victim)
	{
		if (self && victim)
		{
			victim.DamageMobj(self, target? target : Actor(self), damage, 'Pepper');
			if (!victim.bNoBlood)
			{
				victim.TraceBleed(damage, self);
				victim.SpawnBlood(pos, AngleTo(victim), damage);
			}
			SetDamage(damage - int(round(ToM_Utils.LinearMap(victim.GetMaxHealth(true), 60, 500, 1, 10))));
		}
	}
	override int SpecialMissileHit(actor victim)
	{
		// Primary-fire projectiles have bNOGRAVITY,
		// and they shouldn't exhibit any piercing
		// behavior:
		if (bNOGRAVITY)
		{
			return MHIT_DEFAULT;
		}

		int ret = super.SpecialMissileHit(victim);
		if (damage <= 0)
		{
			return MHIT_DEFAULT;
		}
		return ret;
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
		APPC A 1 
		{
			A_SetRoll(roll + wrot, SPF_INTERPOLATE);
			if (bMISSILE && !bNOGRAVITY && vel.length() <= 3)
			{
				bMISSILE = false;
				bCORPSE = true;
				if (flare)
					flare.A_FadeOut(0.2);
			}
		}
		loop;
	Crash:
		TNT1 A 0 
		{ 
			trailcolor = "";
		}
		APPC A 1 
		{
			A_SetTics(random[ppsfx](1,3));
			if (flare)
				flare.A_FadeOut(0.2);

			FSpawnParticleParams pp;
			pp.color1 = color(pcolor[random[ppsfx](0, pcolor.Size()-1)]);
			pp.lifetime = random[ppsfx](20,35);
			pp.pos = level.Vec3Offset(pos, (frandom[ppsfx](-5,5), frandom[ppsfx](-5,5), 0));
			pp.vel.x = frandom[ppsfx](-0.5, 0.5);
			pp.vel.y = frandom[ppsfx](-0.5, 0.5);
			pp.vel.z = frandom[ppsfx](0.5, 1.2);
			pp.size = 6;
			pp.sizestep = -(pp.size / pp.lifetime);
			pp.startalpha = ToM_Utils.LinearMap(scale.x, default.scale.x*0.1, default.scale.x, 0.1, 1);
			pp.accel.xy = -(pp.vel.xy * 0.05);
			pp.accel.z = -(pp.vel.z / pp.lifetime);
			Level.SpawnParticle(pp);
			
			scale *= bCorpse? 0.92 : 0.65;

			if (scale.x < default.scale.x * 0.1)
			{
				return ResolveState("Null");
			}
			return ResolveState(null);
		}
		wait;
	Death:
		TNT1 A 1
		{
			if (!bNOGRAVITY)
			{
				bNOGRAVITY = true;
				A_Stop();
				return ResolveState("Crash");
			}
			return ResolveState(null);
		}
		stop;
	}
}

class ToM_PepperPuff : ToM_BasePuff
{
	Default
	{
		Damagetype 'Pepper';
		Decal 'PepperDecal';
		+PUFFONACTORS
	}
	
	States
	{
	Spawn:
		TNT1 A 1 NoDelay
		{
			A_StartSound("weapons/pgrinder/projdie", CHAN_AUTO, attenuation: 6);
			for (int i = random[ppsfx](8,12); i > 0; i --) {
				double vx = frandom[ppgr](1,4);
				color col = color(ToM_PepperProjectile.pcolor[random[ppgr](0, ToM_PepperProjectile.pcolor.Size()-1)]);
				A_SpawnParticle(
					col,
					flags: SPF_RELATIVE|SPF_FULLBRIGHT,
					lifetime: 30,
					size: 4,
					angle: random[ppsfx](0,359),
					velx: vx,
					velz: frandom[ppsfx](2,6) * ((pos.z >= ceilingz - height)? 0 : 1.0),
					accelx: -vx * 0.05,
					accelz: -0.5,
					sizestep: -0.08
				);
			}
			FSpawnParticleParams sm;
			sm.color1 = "ff4242";
			sm.texture = TexMan.CheckForTexture("SMO2A0");
			sm.flags = SPF_ROLL|SPF_REPLACE;
			sm.style = STYLE_Add;
			sm.fadestep = -1;
			sm.startalpha = 0.75;
			sm.pos = pos;
			double v = 0.5;
			for (int i = 0; i < 3; i++)
			{
				sm.vel.x = frandom[ppsfx](-v, v);
				sm.vel.y = frandom[ppsfx](-v, v);
				sm.vel.z = frandom[ppsfx](-v, v);
				sm.lifetime = random[ppsfx](30,40);
				sm.size = frandom(12, 18);
				sm.sizestep = 0.1;
				sm.accel = -(sm.vel / sm.lifetime);
				sm.startroll = frandom[ppsfx](0,360);
				sm.rollvel = frandom[ppsfx](-5,5);
				Level.SpawnParticle(sm);
			}
		}
		stop;
	}
}

// Unused alt attack that causes monsters to stumble and cough

/*

class ToM_PepperBomb : ToM_PiercingProjectile
{
	Default
	{
		ToM_Projectile.flarecolor "";
		ToM_Projectile.trailcolor "";
		renderstyle 'Shaded';
		stencilcolor "120403";
		speed 20;
		+ROLLSPRITE
		+ROLLCENTER
		scale 0.1;
		radius 40;
		height 60;
	}
	
	override void HitVictim(Actor victim)
	{
		let cont = ToM_PepperDOT(victim.FindInventory("ToM_PepperDOT"));
		if (cont)
		{
			cont.age = 0;
		}
		else 
		{
			victim.GiveInventory("ToM_PepperDOT", 1);
		}
	}
	
	override bool CheckValid(Actor victim)
	{
		return (!target || victim != target) && (victim.bISMONSTER || victim.player) && (victim.bSHOOTABLE || victim.bVULNERABLE) && victim.health > 0;
	}
	
	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		if (target)
			vel += target.vel;
	}
	
	override void Tick()
	{
		super.Tick();
		if (isFrozen())
			return;
		
		vel *= 0.9;

		double v = vel.length();
		
		if (!InStateSequence(curstate, s_death))
		{
			alpha = ToM_Utils.LinearMap(v, speed, 0, 1, 0.2);
			if (v <= 1.1)
			{
				SetStateLabel("Death");
				return;
			}
		}
		
		roll += ToM_Utils.LinearMap(v, speed, 0, 10, 0.01);
		A_SetScale(ToM_Utils.LinearMap(v, speed, 0, 0.1, 0.15));
				
		double svel = 2.4;//LinearMap(v, speed, 0, 1, 8);
		double sofs = 10;//LinearMap(v, speed, 0, 0, 18);
		double sscale = ToM_Utils.LinearMap(v, speed, 0, 0.1, 0.15);
		double salpha = 0.35;// ToM_Utils.LinearMap(v, speed, 0, 0.5, 0.85);
		
		let smk = ToM_WhiteSmoke.Spawn(
			pos,
			ofs: sofs,
//			vel: (
//				frandom[pbom](-svel,svel),
//				frandom[pbom](-svel,svel),
//				frandom[pbom](-svel,svel)
//			),
			scale: sscale,
			alpha: salpha,
			fade: 0.02,
			dbrake: 0.85,
			//cheap: true,
			smoke: "ToM_PepperCloud"
		);
		if (smk)
		{
			smk.master = self;
			smk.A_SetRenderstyle(smk.alpha, Style_Shaded);
			smk.SetShade("120403");
		}
		
		for (int i = 4; i > 0; i--)
		{
			A_SpawnParticle(
				"120403",
				flags: SPF_RELPOS,
				lifetime: frandom[ppart](25,40),
				size: 3,
				xoff: frandom[ppart](-sofs, sofs),
				yoff: frandom[ppart](-sofs, sofs),
				zoff: frandom[ppart](-sofs, sofs),
				velx: frandom[ppart](-svel, svel) * 0.5,
				vely: frandom[ppart](-svel, svel) * 0.5,
				velz: frandom[ppart](-svel, svel) * 0.5
			);
		}
	}
	
	States
	{
	Spawn:
		SMO2 A 1;
		wait;
	Death:
		SMO2 A 1 A_FadeOut(0.08);
		loop;
	}
}

class ToM_PepperCloud : ToM_WhiteSmoke
{
	vector3 masterofs;	
	
	override void Tick()
	{
		super.Tick();
		if (master)
		{
			SetOrigin(pos + masterofs, true);
		}
	}
}

class ToM_PepperDOT : ToM_InventoryToken
{
	const DOTDUR = 35 * 6;
	const SNEEZEDUR = 38;
	
	protected double sneezepitch;
	protected double prevSpeed;
	protected int prevReactionTime;
	protected int nexttic;
	
	override void ModifyDamage(int damage, Name damageType, out int newdamage, bool passive, Actor inflictor, Actor source, int flags)
	{
		if (damageType == 'Pepper')
			newdamage = damage * 1.25;
	}
	
	override void AttachToOwner(actor other)
	{
		super.AttachToOwner(other);
		
		nexttic = random[dotc](20, SNEEZEDUR);
		
		if (owner)
		{
			prevSpeed = owner.speed;
			prevReactionTime = owner.reactiontime;
			
			owner.speed *= 0.6;
			owner.reactiontime *= 10;
			
			sneezepitch = ToM_Utils.LinearMap(owner.spawnhealth(), 100, 1000, 0.9, 0.5);
			sneezepitch = Clamp(sneezepitch, 0.25, 0.9);
		}
	}
	
	override void DoEffect()
	{
		super.DoEffect();
		
		if (!owner || owner.health <= 0 || age >= DOTDUR)
		{
			Destroy();
			return;
		}
		
		if (owner.isFrozen())
			return;
		
		if (nexttic > 0)
		{
			nexttic--;
			for (int i = 3; i > 0; i--)
			{
				owner.A_SpawnParticle(
					"120403",
					flags:SPF_RELVEL|SPF_RELACCEL,
					lifetime:35,
					size:5,
					angle:frandom[dotcpart](0,359),
					xoff:frandom[dotcpart](-6,6),
					yoff:frandom[dotcpart](-6,6),
					zoff:owner.height * 0.7 + frandom[dotcpart](-8,4),
					velx:frandom[dotcpart](1,2),
					velz:frandom[dotcpart](0.5,2),
					accelx:frandom[dotcpart](-0.1,-0.3),
					accelz:-0.05,
					sizestep:-0.2
				);
			}
		}
		
		// attempt to sneeze:
		else
		{
			// set next interval:
			nexttic = random[dotc](30, 70);
			// Calculate chance for effect based on painchance:
			int dotchance = random[dotc](0, 140);
			
			// do the sneeze:
			if (dotchance <= owner.painchance)
			{
				owner.A_StartSound("weapons/pgrinder/sneeze", CHAN_AUTO,pitch: sneezepitch);
				owner.target = null;
				owner.angle += (randompick[dotc](40, 60, 90) * randompick[dotc](-1, 1));
				
				for (int i = 10; i > 0; i--)
				{
					double fwvel = frandom[dotcpart](2, 4);
					double sidevel = frandom[dotcpart](-1.5, 1.5);
					owner.A_SpawnParticle(
						"120403",
						flags: SPF_RELATIVE,
						lifetime: 25,
						size: 10,
						yoff: frandom[dotcpart](-4, 4),
						zoff: owner.height * 0.8 + frandom[dotcpart](-2, 2),
						velx: fwvel,
						vely: sidevel,
						velz: frandom[dotcpart](0, 1.2),
						accelx: -fwvel * 0.05,
						accely: -sidevel * 0.05,
						accelz: -0.5,
						sizestep: -0.2
					);
				}
				owner.SetState(owner.FindState("See"));
				owner.movecount = 25;
				owner.A_SetTics(SNEEZEDUR);
				double pstrength = ToM_Utils.LinearMap(owner.mass, 300, 1000, 5, 1.5);
				owner.A_Recoil(Clamp(pstrength, 1.5 ,5));
				if (!owner.bFLOAT && !owner.bNOGRAVITY)
				{
					owner.vel.z += 3;
				}
				let sl = Spawn("ToM_SneezeLayer", owner.pos);
				if (sl)
				{
					sl.master = owner;
				}
			}
		}
	}
	
	override void DetachFromOwner()
	{
		if (owner)
		{
			owner.speed = prevSpeed;
			owner.reactiontime = prevReactionTime;
		}
		
		super.DetachFromOwner();
	}
}

class ToM_SneezeLayer : ToM_ActorLayer
{
	Default
	{
		Renderstyle 'Stencil';
		stencilcolor "120403";
		ToM_ActorLayer.Fade 0.08;
	}
}