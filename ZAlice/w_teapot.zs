class ToM_Teapot : ToM_BaseWeapon
{
	int heat;
	int lidframe;	
	
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
		
		if (owner.health <= 0 || owner.player.readyweapon != self)
		{
			owner.A_StopSound(CH_TPOTHEAT);
			owner.A_StopSound(CH_TPOTCHARGE);
			return;
		}
		
		if (heat >= HEAT_MAX)
		{
			owner.A_StartSound("weapons/teapot/highheat", CH_TPOTCHARGE, CHANF_LOOPING);
		}
		if (heat >= HEAT_MED)
		{
			//console.printf("Heat: %d", heat);
			owner.A_StartSound("weapons/teapot/heatloop", CH_TPOTHEAT, CHANF_LOOPING);
			owner.A_SoundVolume(CH_TPOTHEAT, LinearMap(heat, HEAT_MED, HEAT_MAX, 0, 1.0));
			owner.A_SoundVolume(CH_TPOTCHARGE, LinearMap(heat, HEAT_MAX - 10, HEAT_MAX, 0, 1.0));
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
	
	action int A_ReduceHeat()
	{
		if (invoker.heat > 0 && level.time % 10 == 0)
			invoker.heat--;	
		return invoker.heat;
	}
	
	action void A_TeapotReady(int flags = 0)
	{
		if (invoker.heat >= HEAT_MAX)
			flags |= WRF_NOPRIMARY;		
		
		/*if (invoker.heat >= HEAT_MED)
		{
			A_StartSound("weapons/teapot/heatloop", CH_TPOTHEAT, CHANF_LOOPING);
			A_SoundVolume(CH_TPOTHEAT, invoker.LinearMap(invoker.heat, HEAT_MED, HEAT_MAX, 0.05, 1.0));
		}
		else
			A_StopSound(CH_TPOTHEAT);*/
		
		if (invoker.heat > 0 /*&& level.time % 10 == 0*/)
			invoker.heat--;
			
		A_WeaponReady(flags);
	}
	
	action void A_TeapotFire()
	{
		invoker.heat += HEAT_STEP;
		sound snd = invoker.heat < HEAT_MAX ? "weapons/teapot/fire" : "weapons/teapot/firecharged";
		let proj = A_FireArchingProjectile("ToM_TeaProjectile",spawnofs_xy:1,spawnheight:5,flags:FPF_NOAUTOAIM,pitch:-17);
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
		TPOT C 2
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
		}
		TNT1 A 1 A_PickReady;
		wait;
	ReadyOverHeat:
		TPOT BA 3;
	ReadyOverHeatLoop:
		TPOT J 3
		{
			A_TeapotReady(WRF_NOPRIMARY);
			if (invoker.heat < HEAT_MAX)
				return ResolveState("ReadyOverHeatEnd");
			return ResolveState(null);
		}
		loop;
	ReadyOverHeatEnd:
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
	}
}
	
	
class ToM_TeaProjectile : ToM_Projectile
{
	Default
	{
		ToM_Projectile.trailcolor "32a856";
		ToM_Projectile.trailscale 0.08;
		ToM_Projectile.trailfade 0.055;
		ToM_Projectile.trailalpha 0.4;
		translation "0:255=%[0.00,0.22,0.00]:[0.01,2.00,0.26]";
		-NOGRAVITY
		+BRIGHT
		gravity 0.4;
		deathsound "weapons/teapot/explode";
		height 8;
		radius 12;
		speed 22;		
		damage (25);		
	}
	
	States
	{
	Spawn:
		BAL1 A -1;
		stop;
	Death:
		TNT1 A 0 
		{
			bNOGRAVITY = true;
			A_Explode();
		}
		MISL BCDE 5;
		stop;
	}
}