class ToM_Jacks : ToM_BaseWeapon
{
	const JREADYFRAME = 0;
	const JWAITFRAME = 14;
	const JSAFERELOAD = int(ToM_JackDOTControl.DOTTIME * 2);
	const JPROJNUMBER = 6;
	int jackswait;
	bool jacksTossed;

	Default
	{
		weapon.slotnumber 3;
		Tag "Jacks";
	}
	
	action void A_SetJacksFrame()
	{
		let psp = player.FindPSprite(OverlayID());
		if (!psp)
			return;
		
		psp.frame = invoker.jacksTossed ? JWAITFRAME : JREADYFRAME;
	}
	
	action state A_JacksReady()
	{
		A_WeaponReady(invoker.jacksTossed ? WRF_NOFIRE : 0);
		let psp = player.FindPSprite(OverlayID());
		if (psp && psp.frame == JWAITFRAME && !invoker.jacksTossed)
			return ResolveState("JacksReload");
		return ResolveState(null);
	}
	
	action void A_TossJacks()
	{
		A_StartSound("weapons/jacks/toss", CHAN_WEAPON);
		for (int i = JPROJNUMBER; i > 0; i--)
		{
			let proj = ToM_JackProjectile(
				A_Fire3DProjectile(
					"ToM_JackProjectile", 
					forward: 1, 
					leftright: 3.2 + frandom[jp](-3, 3), 
					updown: frandom[jp](-1, 1),
					crosshairConverge: false,
					angleoffs: frandom[jf](-5, 5),
					pitchoffs: -3.5 + frandom[jf](-3, 3)
				)
			);
			if (proj)
			{
				proj.rollstep = frandom[jp](4, 5.5) * randompick[jp](-1, 1);
				proj.angstep = frandom[jp](4, 5.5) * randompick[jp](-1, 1);
				proj.vel *= frandom(0.9, 1);
			}
		}
	}
	
	action void A_FireJackSeekers()
	{
		A_StartSound("weaopons/jacks/toss", CHAN_WEAPON);
		let seeker = ToM_JackSeeker(A_Fire3DProjectile("ToM_JackSeeker"));
		if (!seeker)
			return;
		for (int i = 0; i < JPROJNUMBER; i++)
		{
			let j = ToM_VisualSeeker(
				A_Fire3DProjectile(
					"ToM_VisualSeeker",
					useammo: false,
					forward: 18,
					leftright: frandom[fakejacks](-18, 18),
					updown: frandom[fakejacks](-4, 16)
				)
			);
			if (j)
			{
				j.rollstep = frandom[fakejacks](4, 5.5) * randompick[fakejacks](-1, 1);
				j.angstep = frandom[fakejacks](4, 5.5) * randompick[fakejacks](-1, 1);
				j.master = seeker;
				j.masterofs = j.pos - seeker.pos;
				seeker.followjacks.Push(j);
			}
		}
		invoker.jackswait = JSAFERELOAD;
		invoker.jacksTossed = true;
	}
	
	override void DoEffect()
	{
		super.DoEffect();
		if (jackswait > 0)
		{
			jackswait--;
			if (jackswait <= 0 && jacksTossed)
				jacksTossed = false;
		}
	}
	
	States
	{
	Select:
		AJCK A 0 
		{
			A_WeaponOffset(24, WEAPONTOP + 54);
			A_SetJacksFrame();
		}
		#### ###### 1
		{
			A_WeaponOffset(-4, -9, WOF_ADD);
			A_WeaponReady(WRF_NOFIRE|WRF_NOBOB);
		}
		goto Ready;
	Deselect:
		AJCK A 0 A_SetJacksFrame();
		#### ###### 1
		{
			A_WeaponOffset(4, 9, WOF_ADD);
		}
		TNT1 A 0 A_Lower;
		wait;
	Ready:
		AJCK A 0 A_SetJacksFrame();
		#### # 1 A_JacksReady();
		wait;
	JacksReload:
		AJCK OPQRST 2 A_WeaponReady(WRF_NOFIRE);
		goto Ready;
	Fire:
		AJC1 BC 2;
		AJC1 DDEEFF 1 A_WeaponOffset(2.5, 1, WOF_ADD);
		AJC1 GGG 1 A_WeaponOffset(-20, 0, WOF_ADD);
		TNT1 A 0 A_TossJacks;
		AJC1 HHHH 1 
		{
			A_WeaponOffset(-10, 10, WOF_ADD);
			A_OverlayScale(OverlayID(), -0.03, -0.03, WOF_ADD);
		}
		AJC1 HHH 1 
		{
			A_WeaponOffset(-5, 20, WOF_ADD);
			A_OverlayScale(OverlayID(), -0.03, -0.03, WOF_ADD);
		}
		TNT1 A 10
		{
			A_WeaponOffset(-42, WEAPONTOP + 60);
			A_OverlayScale(OverlayID(), 1, 1);
		}
		AJCK AAAAAA 1
		{
			A_WeaponOffset(7, -10, WOF_ADD);
			A_WeaponReady(WRF_NOFIRE|WRF_NOBOB);
		}
		goto Ready;
	Altfire:
		AJCK GGGHHH 1 A_WeaponOffset(-4, 1.5, WOF_ADD);
		AJCK IIIIIJ 1 A_WeaponOffset(-1.5, 1.5, WOF_ADD);
		AJCK KK 1 A_WeaponOffset(5, -1, WOF_ADD);
		TNT1 A 0 A_FireJackSeekers;
		AJCK LLL 1 A_WeaponOffset(5, -1, WOF_ADD);
		AJCK LLLLLLLLL 1 A_WeaponOffset(3, 1, WOF_ADD);
		AJCK MMMNN 1 A_ResetPSprite(OverlayID(), 5);
		goto Ready;
	}
}


// The jack projectile used by primary attack.
// It's bouncing, subjected to gravity,
// and can deal damage to the same actor multiple times,
// but not more often than once per RIPDELAY tics.

class ToM_JackProjectile : ToM_Projectile
{
	const JACKDAMAGE = 10; // the damage to deal (see SpecialMissileHit)
	const RIPDELAY = 8; // can't deal damage to same actor more than this many tics
	double rollstep; // roll change per tic (visual)
	double angstep; // angle change per tic (visual)
	protected Actor ripvictim;
	protected int ripwait;

	Default
	{
		ToM_Projectile.trailcolor "FFAAAA";
		ToM_Projectile.trailscale 0.07;
		ToM_Projectile.trailfade 0.01;
		ToM_Projectile.trailalpha 0.14;
		ToM_Projectile.DelayTraceDist 80;
		-NOGRAVITY
		+NODECAL
		+CANBOUNCEWATER
		speed 24;
		gravity 0.3;
		bouncetype 'Hexen';
		bouncesound "weapons/jacks/bounce";
		bouncefactor 0.6;
	}
	
	override int SpecialMissileHit(Actor victim)
	{
		// Do this if victim is valid, not equal to ripvictim,
		// not equal to target:
		if (victim && victim.bSHOOTABLE && target)
		{
			if (victim != ripvictim && target != victim)
			{
				ripvictim = victim; //record victim 
				ripwait = RIPDELAY; //start the targetdelay counter
				// deal damage:
				victim.DamageMobj(self, target, JACKDAMAGE, "Normal");
				A_StartSound("weapons/jacks/flesh", CHAN_AUTO);
				// spawn blood decal/sprite (DamageMobj doesn't do it automatically):
				if (!victim.bNOBLOOD)
				{
					victim.TraceBleed(JACKDAMAGE, self);
					victim.SpawnBlood(pos, AngleTo(victim), JACKDAMAGE);
				}
			}
			if (!victim.bBOSS)
			{
				return 1; // fly through
			}
		}
		return -1; // do the usual behavior
	}
	
	override void Tick()
	{
		super.Tick();
		if (!isFrozen())
		{
			if (GetAge() < 10)
				scale *= 1.03;
			double v = Clamp(vel.length(), 0, 5);
			roll += rollstep * v;
			angle += angstep * v;		
			// Clear rip victim after a targetdelay,
			// so that the same actor can be damaged again:
			if (ripwait > 0)
				ripwait--;
			else if (ripvictim)
				ripvictim = null;
		}
	}
	
	States
	{
	Spawn:
		AMRK A 1
		{
			if (vel.length() < 3) 
			{
				bMISSILE = false;	//stop bouncing and start sliding
				return ResolveState("Death");
			}
			return ResolveState(null);
		}
		loop;
	Death:
		AMRK A 60;
		AMRK A 1 
		{
			scale *= 0.92;
			if (scale.x <= default.scale.x * 0.08)
				Destroy();
		}
		wait;
	}
}

class ToM_JackSeeker : ToM_Projectile
{
	array <ToM_VisualSeeker> followjacks;

	Default
	{
		+SEEKERMISSILE
		+SCREENSEEKER
		-NOGRAVITY
		gravity 0.2;
		bouncetype 'Hexen';
		bouncefactor 0.75;
		speed 15;
		damage 0;
	}
	
	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		A_StartSound("weapons/jacks/loop", CHAN_BODY, CHANF_LOOPING);
	}
	
	override void Tick()
	{
		super.Tick();
		if (isFrozen())
			return;
		if (vel.length() < 5)
		{
			Destroy();
		}
	}
	
	override int SpecialMissileHit(Actor victim)
	{
		if (victim && victim.bSHOOTABLE && target && target != victim)
		{
			victim.GiveInventory("ToM_JackDOTControl", 1);
			let inv = victim.FindInventory("ToM_JackDOTControl");
			if (inv)
				inv.target = target;
			for (int i = 0; i < followjacks.Size(); i++)
			{
				if (followjacks[i])
				{
					followjacks[i].tracer = victim;
					followjacks[i].target = target;
					followjacks[i].master = null;
				}
			}
			if (tom_debugmessages)
				console.printf("Jacks hit a victim (%s)", victim.GetClassName());
			return 0; //instantly destroy
		}
		if (tom_debugmessages)
			console.printf("Jacks are flying through");
		return 1; //fly through
	}
	
	States
	{
	Spawn:
		TNT1 A 1 
		{
			A_SeekerMissile(0, 5, SMF_LOOK | SMF_PRECISE | SMF_CURSPEED, 256);
			if (tom_debugmessages)
				sprite = GetSpriteIndex("AMRK");
		}
		loop;
	Death:
		TNT1 A 1
		{
			if (target)
			{
				let weap = ToM_Jacks(target.FindInventory("ToM_Jacks"));
				if (weap)
					weap.jacksTossed = false;
			}
		}
		stop;
	}
}

class ToM_VisualSeeker : ToM_JackProjectile
{
	vector3 masterofs;
	vector3 tracerofs;
	int targetdelay;
	int delay;

	Default
	{
		-MISSILE
		+NOINTERACTION
		speed 0;
	}
	
	override void Tick()
	{
		super.Tick();
		if (isFrozen())
			return;		
		if (master)
		{
			SetOrigin(master.pos + masterofs, true);
			vel = master.vel;
		}
	}
	
	States
	{
	Spawn:
		AMRK A 1
		{
			if (tracer)
			{
				//A_Stop();
				targetdelay = random[fakejacks](7, 11);
				tracerofs.x = (tracer.radius + frandom[jt](0, 10)) * randompick[jt](-1, 1);
				tracerofs.y = (tracer.radius + frandom[jt](0, 10)) * randompick[jt](-1, 1);
				tracerofs.z = tracer.height * 0.5 + tracer.height * 0.5 * randompick[jt](-1, 1);
				vector3 vec = level.Vec3Diff(pos, tracer.pos + tracerofs);
				double flyspeed = vec.length() / targetdelay;
				vel = vec / flyspeed;
				A_StartSound("weapons/jacks/ricochet", CHAN_BODY, CHANF_NOSTOP);
			}
		}
		AMRK A 1
		{
			if (!master && (!tracer || !tracer.CountInv("ToM_JackDOTControl")))
			{
				return ResolveState("ReturnToShooter");
			}
			if (delay >= targetdelay)
			{
				delay = 0;
				return ResolveState("Spawn");
			}
			delay++;
			return ResolveState(null);
		}
		wait;
	ReturnToShooter:
		AMRK A 1
		{
			if (!target)
				A_FadeOut(0.05);
			else
			{
				//A_FaceTarget(flags:FAF_MIDDLE);
				vel = Vec3to(target).Unit() * 35;
				if (Distance3D(target) < 64)
				{
					let weap = ToM_Jacks(target.FindInventory("ToM_Jacks"));
					if (weap)
						weap.jacksTossed = false;
					Destroy();
				}
			}
		}
		loop;
	}
}

class ToM_JackDOTControl : ToM_InventoryToken
{
	const SEEKERTICDAMAGE = 20;
	const DOTTIME = 35 * 4;
	int dotcounter;
	int dmgdelay;
	
	override void BeginPlay()
	{
		super.BeginPlay();
		dmgdelay = 10;
	}
	
	override void DoEffect()
	{
		super.DoEffect();
		if (owner && owner.isFrozen())
			return;
		if (dotcounter < DOTTIME)
		{
			dotcounter++;
			if (dotcounter >= DOTTIME)
			{
				/*if (target && target.player)
				{
					let weap = ToM_Jacks(target.FindInventory("ToM_Jacks"));
					if (weap)
						weap.jacksTossed = false;
				}*/
				Destroy();
				return;
			}
		}
		if (!target || !owner || owner.health <= 0)
		{
			if (tom_debugmessages)
				Console.Printf("No valid target/owner, removing jacks DOT effect");
			Destroy();
			return;
		}
		if (GetAge() % Clamp(dmgdelay, 1, 100) == 0)
		{
			dmgdelay = random[jackdamage](10, 15);
			owner.A_StartSound("weapons/jacks/flesh", CHAN_BODY, CHANF_NOSTOP);
			owner.DamageMobj(self, target, SEEKERTICDAMAGE, "Normal", DMG_PLAYERATTACK|DMG_THRUSTLESS);
		}
	}
}
