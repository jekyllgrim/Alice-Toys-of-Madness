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
		if (owner.health <= 0 || !weap || weap != self)
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
			owner.A_SoundVolume(CH_TPOTHEAT, LinearMap(heat, HEAT_MED, HEAT_MAX, 0, 1.0));
			owner.A_SoundVolume(CH_TPOTCHARGE, LinearMap(heat, HEAT_MED, HEAT_MAX, 0, 1.0));
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
			
		int heat = invoker.heat;
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
	Select:
		TNT1 A 0 
		{
			A_WeaponOffset(-16, WEAPONTOP + 96);
			//A_OverlayPivot(OverlayID(), 0.6, 0.8);
		}
		TPOS DDCCBBAA 1
		{
			A_WeaponOffset(2, -12, WOF_ADD);
			A_WeaponReady(WRF_NOFIRE|WRF_NOBOB);
		}
		goto Ready;
	Deselect:
		TPOS AABBCCDD 1
		{
			A_WeaponOffset(-2, 12, WOF_ADD);
		}
		TNT1 A 0 A_Lower;
		wait;
	Ready:
		TPOT C 1
		{
			A_ResetPSprite();
			A_TeapotReady();
		}
		TNT1 A 0 A_PickReady();
		loop;
	ReadyHeat:
		TPOT C 1
		{
			A_TeapotReady();
			A_SetTics(invoker.LinearMap(invoker.heat, HEAT_MED, HEAT_MAX, 4, 2));
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
		TPOT CFG 1 A_WeaponOffset(4, 4, WOF_ADD);
		TPOT HHH 1 A_WeaponOffset(1.5, 1.5, WOF_ADD);
		TPOT III 3 A_WeaponOffset(1.5, 1.5, WOF_ADD);
		TNT1 A 0
		{
			if (invoker.heat >= HEAT_MAX)
				return ResolveState("FireEndHeat");
			return ResolveState(null);
		}
		TPOT IIKKAAABBB 1 A_ResetPSprite(OverlayID(), 10);
		TNT1 A 0 A_ResetPSprite;
		goto Ready;
	FireEndHeat:
		TPOT IIKKJJJJJJ 1 A_ResetPSprite(OverlayID(), 10);
		TNT1 A 0 A_ResetPSprite;
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

class ToM_TeaBurnControl : ToM_InventoryToken 
{
	protected int timer;
	protected uint prevtrans;
	
	void ResetTimer() 
	{
		timer = 35*5;
	}
	
	override void AttachToOwner(actor other) 
	{
		super.AttachToOwner(other);
		if (!owner)
			return;
		ResetTimer();
		prevtrans = owner.translation;
		owner.A_SetTranslation("GreenTea");
		if (tom_debugmessages > 0)
			console.printf("giving %s to %s", GetClassName(), owner.GetClassName());
	}
	
	override void DoEffect() 
	{
		super.DoEffect();
		if (!owner || !owner.target)
		{
			DepleteOrDestroy();
			return;
		}
		if (owner.isFrozen())
			return;
		if (timer <= 0) 
		{
			DepleteOrDestroy();
			return;
		}
		timer--;
		if (timer % 35 == 0) 
		{
			int fl = (random[tea](1,3) == 1) ? 0 : DMG_NO_PAIN;
			owner.DamageMobj(self,owner.target,4,"Normal",flags:DMG_THRUSTLESS|fl);
		}
		/*if (owner.health <= 0) 
		{
			owner.A_SetTRanslation("Scorched");
		}*/
		double rad = owner.radius*0.75;		
		if (!s_particles)
			s_particles = CVar.GetCVar('ToM_particles', players[consoleplayer]);
		if (s_particles.GetInt() >= 1) 
		{
			ToM_WhiteSmoke.SpawnWhiteSmoke(
				owner, 
				ofs: (frandom[wsmoke](-rad,rad), frandom[wsmoke](-rad,rad), frandom[wsmoke](owner.pos.z,owner.height*0.75)), 
				vel: (frandom[wsmoke](-0.2,0.2),frandom[wsmoke](-0.2,0.2),frandom[wsmoke](0.5,1.2)),
				scale: 0.15,
				alpha: 0.4
			);
		}
	}
	
	override void DetachFromOwner() 
	{
		if (owner)
		{
			owner.translation = prevtrans;
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
		height 8;
		radius 12;
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
				ToM_WhiteSmoke.SpawnWhiteSmoke(
					self, 
					ofs: (frandom[wsmoke](-4,4),frandom[wsmoke](-4,4),frandom[wsmoke](-4,4) + (height * 0.5)), 
					vel: (frandom[wsmoke](-0.2,0.2),frandom[wsmoke](-0.2,0.2),frandom[wsmoke](-0.2,0.2)),
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
				ToM_WhiteSmoke.SpawnWhiteSmoke(
					self, 
					ofs: (frandom[wsmoke](-6,6),frandom[wsmoke](-6,6),frandom[wsmoke](10,16)), 
					vel: (frandom[wsmoke](-0.2,0.2),frandom[wsmoke](-0.2,0.2),frandom[wsmoke](2,3)),
					scale: 0.3,
					alpha: 0.75
				);
			}
			
			for (int i = 20; i > 0; i--)
			{
				A_SpawnItemEx(
					"ToM_TeaSplash",
					xofs: frandom[wsplash](-12,12),
					yofs: frandom[wsplash](-12,12),
					zofs: frandom[wsplash](-4,12),
					xvel: frandom[wsplash](-1,1),
					yvel: frandom[wsplash](-1,1),
					zvel: frandom[wsplash](1,3.5)
				);
			}
			
			
			for (int i = 40; i > 0; i--)
			{
				double vx = frandom[wsplash](2, 6);
				double bx = vx * -0.01;
				A_SpawnParticle(
					"00FF00",
					SPF_RELATIVE,
					lifetime: 50,					
					size: 10,
					angle: frandom[wsplash](0, 359),
					xoff: frandom[wsplash](-8,8),
					yoff: frandom[wsplash](-8,8),
					zoff: frandom[wsplash](-8,8),
					velx: vx,
					velz: frandom[wsplash](3, 10),
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
				ToM_WhiteSmoke.SpawnWhiteSmoke(
					self,
					ofs: (frandom[wsmoke](-64,64),frandom[wsmoke](-64,64), 5), 
					vel: (0, 0, frandom[wsmoke](0.5, 1)),
					scale: 0.08,
					alpha: 0.7,
					fade: 0.01
				);
		}
		wait;
	}
}