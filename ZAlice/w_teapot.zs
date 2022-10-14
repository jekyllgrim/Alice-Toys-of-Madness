class ToM_Teapot : ToM_BaseWeapon
{
	double heat;
	int lidframe;	
	double vaporYvel;
	double vaporScaleShift;
	
	enum HeatLevels
	{
		HEAT_STEP = 20,
		HEAT_MED = 35,
		HEAT_MAX = 100,
	}
	
	Default
	{
		weapon.slotnumber 5;
		Tag "Teapot Cannon";
		weapon.ammotype1 "ToM_YellowMana";
		weapon.ammouse1 20;
		weapon.ammogive1 100;
		weapon.ammotype2 "ToM_YellowMana";
		weapon.ammouse2 1;
	}
	
	
	override void DoEffect()
	{
		super.DoEffect();
		if (!owner || !owner.player)
			return;		
		let weap = owner.player.readyweapon;
		
		// Decay heat:
		if (heat > 0 && weap)
		{
			//console.printf("heat : %f", heat);
			double decayRate = 0.5;
			// Decay at 50% rate if different weapon is selected:
			if (weap != self)
			{
				decayRate *= 0.5;
				heat -= decayRate;
			}
			// Otherwise decay only when not firing:
			else
			{
				let psp = owner.player.FindPSprite(PSP_Weapon);
				if (psp && !InStateSequence(psp.curstate, s_fire))
				{
					heat -= decayRate;
				}
			}
		}
		
		// Stop looped sounds if dead or using different weapon:
		if (owner.health <= 0 || !weap)
		{
			owner.A_StopSound(CH_TPOTHEAT);
			owner.A_StopSound(CH_TPOTCHARGE);
			return;
		}
		
		// Overheat sound:
		if (heat >= HEAT_MAX)
		{
			owner.A_StartSound("weapons/teapot/highheat", CH_TPOTCHARGE, CHANF_LOOPING);
		}
		// Heat looped sound:
		if (heat >= HEAT_MED)
		{
			// Do not play over overheat:
			if (!owner.IsActorPlayingSound(CH_TPOTCHARGE))
				owner.A_StartSound("weapons/teapot/heatloop", CH_TPOTHEAT, CHANF_LOOPING);
			// define volume based on heat:
			double heatvol = LinearMap(heat, HEAT_MED, HEAT_MAX, 0, 1.0);
			double chargevol = LinearMap(heat, HEAT_MED, HEAT_MAX, 0, 1.0);
			// reduce by 50% if a different weapon is selected:
			// (since the heat decays while in background,
			// the sound cues should still be heard)
			if (weap != self)
			{
				heatvol *= 0.5;
				chargevol *= 0.6;
			}
			owner.A_SoundVolume(CH_TPOTHEAT, heatvol);
			owner.A_SoundVolume(CH_TPOTCHARGE, chargevol);
		}
		else
		{
			owner.A_StopSound(CH_TPOTHEAT);
			owner.A_StopSound(CH_TPOTCHARGE);
		}
	}
	
	action state A_PickReady()
	{
		if (!player)
			return ResolveState(null);
			
		let heat = invoker.heat;
		if (heat >= HEAT_MAX)
			A_StartSound("weapons/teapot/heatloop", CH_TPOTHEAT, CHANF_LOOPING);
		if (heat >= HEAT_MED)
			return ResolveState("ReadyHeat");
			
		return ResolveState("Ready");
	}
	
	/*action int A_ReduceHeat()
	{
		if (invoker.heat > 0 && level.time % 10 == 0)
			invoker.heat--;	
		return invoker.heat;
	}*/
	
	action void A_TeapotReady(int flags = 0)
	{
		if (invoker.heat >= HEAT_MAX)
			flags |= WRF_NOPRIMARY;			
		A_WeaponReady(flags);
	}
	
	action void A_TeapotFire()
	{
		invoker.heat += HEAT_STEP;
		sound snd = invoker.heat < HEAT_MAX ? "weapons/teapot/fire" : "weapons/teapot/firecharged";
		let proj = A_FireArchingProjectile("ToM_TeaProjectile",spawnofs_xy:1,spawnheight:5,flags:FPF_NOAUTOAIM,pitch:-11);
		if (proj)
			proj.A_StartSound(snd);
		A_StartSound("weapons/teapot/charge", CHAN_AUTO);
		A_QuakeEX(1,1,0,6,0,1, sfx:"world/null", flags:QF_SCALEDOWN);
	}
	
	action void A_PickLidFrame()
	{
		int i = invoker.lidframe;
		while (invoker.lidframe == i)
			invoker.lidframe = randompick[boil](2, 11, 12, 13);
		let psp = player.FindPSprite(OverlayID());
		if (psp)
			psp.frame = invoker.lidframe;
	}
	
	States
	{
	Spawn:
		ALTP A -1;
		stop;
	Select:
		TPOT C 0 
		{
			A_WeaponOffset(-48, 110+WEAPONTOP);
			A_OverlayPivot(OverlayID(), 0.6, 0.8);
			A_OverlayRotate(OverlayID(), 40);
		}
		#### ######## 1
		{
			A_WeaponOffset(6, -13.75, WOF_ADD);
			A_OverlayRotate(OverlayID(), -5, WOF_ADD);
			A_WeaponReady(WRF_NOFIRE|WRF_NOBOB);
		}
		goto Ready;
	Deselect:
		TPOT C 0 
		{
			A_OverlayPivot(OverlayID(), 0.6, 0.8);
			A_StopSound(CHAN_WEAPON);
		}
		#### ###### 1
		{
			A_WeaponOffset(-6, 14, WOF_ADD);
			A_OverlayRotate(OverlayID(), 5, WOF_ADD);
		}
		TNT1 A 0 A_Lower;
		wait;
	Ready:
		TPOT C 1 A_TeapotReady();
		TNT1 A 0 A_PickReady();
		loop;
	ReadyHeat:
		TPOT C 1
		{
			A_TeapotReady();
			A_SetTics(int(invoker.LinearMap(invoker.heat, HEAT_MED, HEAT_MAX, 4, 2)));
			A_PickLidFrame();
			let psp = player.FindPSprite(OverlayID());
			if (psp && psp.frame == 11)
				A_SpawnPSParticle("Vapor", bottom: true, xofs: 7, yofs: 7, chance: 80);
		}
		TNT1 A 1 A_PickReady;
		wait;
	ReadyOverHeat:
		TPOT BA 3;
	ReadyOverHeatLoop:
		TPOT J 3
		{
			A_TeapotReady(WRF_NOPRIMARY);
			A_SpawnPSParticle("Vapor", bottom: true, xofs: 9, yofs: 9);
			if (invoker.heat < HEAT_MED)
				return ResolveState("ReadyOverHeatEnd");
			return ResolveState(null);
		}
		loop;
	ReadyOverHeatEnd:
		TNT1 A 0 A_StartSound("weapons/teapot/close", CHAN_AUTO);
		TPOT AB 4;
		TNT1 A 1 A_PickReady;
		wait;
	Fire:
		TNT1 A 0 A_TeapotFire;
		TPOT CFG 1 
		{
			A_WeaponOffset(4, 4, WOF_ADD);
			A_AttackZoom(0.005, 0.1);
		}
		TPOT HHH 1 
		{
			A_WeaponOffset(4, 4, WOF_ADD);
			A_AttackZoom(0.0035, 0.1);
		}
		TPOT III 3 
		{
			A_WeaponOffset(4, 4, WOF_ADD);
			A_AttackZoom(0.0015, 0.1);
		}
		TNT1 A 0
		{
			if (invoker.heat >= HEAT_MAX)
				return ResolveState("FireEndHeat");
			return ResolveState(null);
		}
		TNT1 A 0 A_ResetPSprite(OverlayID(), 10);
		TPOT IIKKAAABBB 1 A_ResetZoom();
		goto Ready;
	FireEndHeat:
		TNT1 A 0 A_ResetPSprite(OverlayID(), 10);
		TPOT IIKKJJJJJJ 1;
		goto ReadyOverHeatLoop;
	Vapor:
		TNT1 A 0
		{
			let psp = player.FindPSprite(OverlayID());
			if (psp)
			{
				A_OverlayFlags(OverlayID(), PSPF_AddWeapon|PSPF_AddBob, false);
				A_OverlayFlags(OverlayID(), PSPF_Renderstyle|PSPF_ForceAlpha, true);
				A_OverlayRenderstyle(OverlayID(), Style_Translucent);
				A_OverlayPivotAlign(OverlayID(),PSPA_CENTER,PSPA_CENTER);
				psp.alpha = frandom[vapr](0.75,1.0);
				//psp.x = frandom[vapr](-7,7);
				//psp.y = 38 + frandom[vapr](-7,7);
			}
			invoker.vaporYvel = frandom[vapr](-1, -6);
			invoker.vaporScaleShift = frandom[vapr](1.01, 1.025);
		}
		VAPR AABBCCDDEEFFGGHHIIJJKKLLMMNNOOPPQQRR 1
		{
			let psp = player.FindPSprite(OverlayID());
			if (psp)
			{
				psp.alpha -= 0.03;
				psp.y += invoker.vaporYvel;
				psp.scale *= invoker.vaporScaleShift;
				invoker.vaporYvel *= 0.92;
				//invoker.vaporScaleShift *= 0.8;
			}
		}
		stop;
	}
}

class ToM_TeaBurnControl : ToM_ControlToken 
{
	protected uint prevtrans;
	
	Default
	{
		ToM_ControlToken.duration 175;
	}
	
	override void AttachToOwner(actor other) 
	{
		super.AttachToOwner(other);
		if (!owner)
			return;
		ResetTimer();
		prevtrans = owner.translation;
		owner.A_SetTranslation("GreenTea");
	}
	
	override void DoEffect() 
	{
		super.DoEffect();
		
		console.printf("timer: %d", timer);
		
		if (!owner)
		{
			Destroy();
			return;
		}

		if (timer % 35 == 0 && owner.target) 
		{
			int fl = (random[tsfx](1,3) == 1) ? 0 : DMG_NO_PAIN;
			owner.DamageMobj(self,owner.target,4,"Normal",flags:DMG_THRUSTLESS|fl);
		}

		if (timer % 4 == 0)
		{
			double rad = owner.radius*0.6;		
			if (!s_particles)
				s_particles = CVar.GetCVar('ToM_particles', players[consoleplayer]);
			if (s_particles.GetInt() >= 1) 
			{
				ToM_WhiteSmoke.Spawn(
					owner.pos + (
						frandom[tsfx](-rad,rad), 
						frandom[tsfx](-rad,rad), 
						frandom[tsfx](owner.pos.z,owner.height*0.75)
					), 
					vel: (frandom[tsfx](-0.2,0.2),frandom[tsfx](-0.2,0.2),frandom[tsfx](0.5,1.2)),
					scale: 0.15,
					alpha: 0.2
				);
			}
		}
	}
	
	override void DetachFromOwner() 
	{
		if (owner)
		{
			owner.translation = prevtrans;
			let al = Spawn("ToM_TeaBurnLayer", owner.pos);
			if (al)
				al.master = owner;
		}	
		super.DetachFromOwner();
	}
}
	
class ToM_TeaProjectile : ToM_Projectile
{
	Default
	{
		ToM_Projectile.trailcolor "32a856";
		ToM_Projectile.trailscale 0.2;
		ToM_Projectile.trailfade 0.07;
		ToM_Projectile.trailalpha 0.75;
		ToM_Projectile.trailz 10;
		+FORCEXYBILLBOARD
		translation "0:255=%[0.00,0.22,0.00]:[0.01,2.00,0.26]";
		-NOGRAVITY
		+BRIGHT
		gravity 0.4;
		deathsound "weapons/teapot/explode";
		height 16;
		radius 8;
		speed 22;		
		damage (25);
		Renderstyle 'Translucent';
		alpha 0.7;
		xscale 0.3;
		yscale 0.28;
	}
	
	States
	{
	Spawn:
		TGLO ABCDEFGHIJ 2
		{
			if (GetAge() > 8)
				ToM_WhiteSmoke.Spawn(
					pos,
					ofs:4,
					vel: (frandom[tpotsmk](-0.2,0.2),frandom[tpotsmk](-0.2,0.2),frandom[tpotsmk](-0.2,0.2)),
					scale: 0.15,
					alpha: 0.4
				);
		}
		loop;
	Death:
		TNT1 A 1
		{
			A_SetScale(1);
			bNOGRAVITY = true;
			A_Explode();
			
			double fz = CurSector.floorplane.ZAtPoint(pos.xy);
			bool onFloor = (pos.z <= fz + 32 && waterlevel <= 0);			
			if (onFloor && (!CheckLandingSize(32) || !(CurSector.FloorPlane.Normal == (0,0,1))))
				Spawn("ToM_TeaPool", (pos.x,pos.y, fz+0.5));
				
			for (int i = 4; i > 0; i--)
			{
				ToM_WhiteSmoke.Spawn(
					pos + (frandom[tpotsmk](-6,6),frandom[tpotsmk](-6,6),frandom[tpotsmk](10,16)), 
					vel: (frandom[tpotsmk](-0.2,0.2),frandom[tpotsmk](-0.2,0.2),frandom[tpotsmk](2,3)),
					scale: 0.3,
					alpha: 0.75
				);
			}
			
			for (int i = 20; i > 0; i--)
			{
				A_SpawnItemEx(
					"ToM_TeaSplash",
					xofs: frandom[tsplash](-12,12),
					yofs: frandom[tsplash](-12,12),
					zofs: frandom[tsplash](-4,12),
					xvel: frandom[tsplash](-1,1),
					yvel: frandom[tsplash](-1,1),
					zvel: frandom[tsplash](1,3.5)
				);
			}
			
			
			for (int i = 40; i > 0; i--)
			{
				double vx = frandom[tsplash](2, 6);
				double bx = vx * -0.01;
				A_SpawnParticle(
					"00FF00",
					SPF_RELATIVE,
					lifetime: 50,					
					size: 10,
					angle: frandom[tsplash](0, 359),
					xoff: frandom[tsplash](-8,8),
					yoff: frandom[tsplash](-8,8),
					zoff: frandom[tsplash](-8,8),
					velx: vx,
					velz: frandom[tsplash](3, 10),
					accelx: bx,
					accelz: -0.3,
					sizestep: -0.2			
				);
			}
		}
		/*TGLO ABCDEFGHIJ 2 
		{
			scale *= 1.1;
			A_FadeOut(0.1);
		}*/
		stop;
	}
}

class ToM_TeaSplash : ToM_SmallDebris
{
	double wscale;
	
	Default 
	{
		renderstyle 'Translucent';
		alpha 0.6;
		gravity 0.23;
		scale 0.35;
		+NOINTERACTION
	}

	override void PostBeginPlay() 
	{
		super.PostBeginPlay();
		wscale = frandom[wsplash](0.025, 0.08);
		roll = frandom[wsplash](-40,40);
		wrot = frandom[wsplash](-2.4,2.4);
		scale *= frandom[wsplash](0.5, 1.2);
		frame = random[wsplash](0,4);
		bSPRITEFLIP = randompick[wsplash](0,1);
	}
	
	override void Tick()
	{
		if (isFrozen())
			return;
		super.Tick();
		if (waterlevel > 0)
			vel.xy *= 0.9;
		scale *= (1 + wscale);
		wscale *= 0.97;
		roll += wrot;
		wrot *= 0.97;
		vel.z -= gravity;
		A_FadeOut(0.015);
	}
	
	States 
	{
	Spawn:
		WFSP # -1;
		stop;
	Cache:
		WFSP ABCD 0;
	}
}

class ToM_TeaPool : ToM_SmallDebris
{
	double wscale;
	
	Default
	{
		+NOINTERACTION
		Renderstyle 'Translucent';
		scale 3.4;
	}
	
	override void PostBeginPlay() 
	{
		super.PostBeginPlay();
		wscale = 0.05;
		AlignToPlane(self);
	}
	
	States
	{
	Spawn:
		AMRK A 1 
		{
			A_FadeOut(0.012);
			scale *= (1 + wscale);
			wscale *= 0.95;
			if (alpha > 0.15 && random[vapr](1,3) == 3)
				ToM_WhiteSmoke.Spawn(
					pos + (frandom[wsmoke](-64,64),frandom[wsmoke](-64,64), 5), 
					vel: (0, 0, frandom[wsmoke](0.5, 1)),
					scale: 0.08,
					alpha: 0.7,
					fade: 0.01
				);
		}
		wait;
	}
}