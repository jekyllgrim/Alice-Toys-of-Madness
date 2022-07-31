class ToM_Jacks : ToM_BaseWeapon
{
	const JREADYFRAME = 0; //frame when ready for firing
	const JWAITFRAME = 14; //frame when waiting for jacks to return 
	const JPROJNUMBER = 6; //number of jacks used by altfire
	// In case jacks don't return for some reason, restore
	// then automatically after x2 the regular DOT duration:
	const JSAFERELOAD = int(ToM_JackDOTControl.DOTTIME * 2);
	bool jacksTossed; //true after using altfire until jacks return
	int jackswait; //wait time for safe reload

	Default
	{
		weapon.slotnumber 3;
		Tag "Jacks";
	}
	
	// Set frame based on jacksTossed value:
	action void A_SetJacksFrame()
	{
		let psp = player.FindPSprite(OverlayID());
		if (!psp)
			return;
		
		psp.frame = invoker.jacksTossed ? JWAITFRAME : JREADYFRAME;
		//console.printf("tossed: %d", invoker.jacksTossed);
	}
	
	action state A_JacksReady()
	{
		A_WeaponReady(invoker.jacksTossed ? WRF_NOFIRE : 0);
		let psp = player.FindPSprite(OverlayID());
		if (psp && psp.frame == JWAITFRAME && !invoker.jacksTossed)
			return ResolveState("JacksReload");
		return ResolveState(null);
	}
	
	// Primary fire:
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
			// Set randomized rotation and vel:
			if (proj)
			{
				proj.rollstep = frandom[jp](4, 5.5) * randompick[jp](-1, 1);
				proj.angstep = frandom[jp](4, 5.5) * randompick[jp](-1, 1);
				proj.vel *= frandom(0.9, 1);
			}
		}
	}
	
	// Alt fire:
	action void A_FireJackSeekers()
	{
		A_StartSound("weaopons/jacks/toss", CHAN_WEAPON);
		// Spawn the invisible seeker:
		let seeker = ToM_JackSeeker(A_Fire3DProjectile("ToM_JackSeeker"));
		if (!seeker)
		{
			if (tom_debugmessages)
				console.printf("Couldn't spawn jack seeker");
			return;
		}
		// Spawn visual dummy projectiles:
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
			// Attach dummy projs to seeker and put them in its array:
			if (j)
			{
				j.rollstep = frandom[fakejacks](4, 5.5) * randompick[fakejacks](-1, 1);
				j.angstep = frandom[fakejacks](4, 5.5) * randompick[fakejacks](-1, 1);
				j.master = seeker;
				j.masterofs = j.pos - seeker.pos;
				seeker.followjacks.Push(j);
			}
		}
		// The weapon is no longer ready for firing:
		invoker.jackswait = JSAFERELOAD;
		invoker.jacksTossed = true;
	}
	
	// Safe reload for edge cases when jacks can't return:
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
		// Scale the hand down a bit to make it move away:
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
			// Scale out of existence:
			scale *= 0.92;
			if (scale.x <= default.scale.x * 0.08)
				Destroy();
		}
		wait;
	}
}

class ToM_JackSeeker : ToM_Projectile
{
	array <ToM_VisualSeeker> followjacks; //array of visual dummy projs

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
		// When a valid target is hit, give it a DOT effect:
		if (victim && victim.bSHOOTABLE && target && target != victim)
		{
			victim.GiveInventory("ToM_JackDOTControl", 1);
			let inv = victim.FindInventory("ToM_JackDOTControl");
			if (inv)
				inv.target = target;
			// Attach visual projs to the victim:
			for (int i = 0; i < followjacks.Size(); i++)
			{
				if (followjacks[i])
				{
					followjacks[i].tracer = victim;
					followjacks[i].target = target; //record target (player) to return to
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
			// Make visible for debug purposes:
			if (tom_debugmessages)
				sprite = GetSpriteIndex("AMRK");
		}
		loop;
	Death:
		TNT1 A 1;
		stop;
	}
}

// Visual projectile used by alt fire
// Doesn't do any collision or damage

class ToM_VisualSeeker : ToM_JackProjectile
{
	vector3 masterofs; //offset from the seeker position
	vector3 tracerofs; //offset from the victim position
	int targetdelay; //how long to wait until next movement
	int delay; //counter for the movement delay

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
		// Follow the invisible seeker while flying:
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
			// After attaching to a monster, move around it randomly
			// to imitate the victim being struck by the jacks:
			if (tracer)
			{
				//A_Stop();
				// Decide how long the next movement will be:
				targetdelay = random[fakejacks](7, 11);
				// Set the target point of the next movement
				// to some point around the victim:
				tracerofs.x = (tracer.radius + frandom[jt](0, 10)) * randompick[jt](-1, 1);
				tracerofs.y = (tracer.radius + frandom[jt](0, 10)) * randompick[jt](-1, 1);
				tracerofs.z = tracer.height * 0.5 + tracer.height * 0.5 * randompick[jt](-1, 1);
				// Get the vector from current to target position:
				vector3 vec = level.Vec3Diff(pos, tracer.pos + tracerofs);
				// Calculate velocity based on vector length and 
				// movement delay:
				double flyspeed = vec.length() / targetdelay;
				// Set the velocity:
				vel = vec / flyspeed;
				// Play the sound (without overlapping/cutoff):
				A_StartSound("weapons/jacks/ricochet", CHAN_BODY, CHANF_NOSTOP);
			}
		}
		AMRK A 1
		{
			// If no master, or victim, or the DOT effect ended,
			// return to the shooter:
			if (!master && (!tracer || !tracer.CountInv("ToM_JackDOTControl")))
			{
				return ResolveState("ReturnToShooter");
			}
			// If the movement delay is up, back to Spawn:
			if (delay >= targetdelay)
			{
				delay = 0;
				return ResolveState("Spawn");
			}
			// otherwise continue moving:
			delay++;
			return ResolveState(null);
		}
		wait;
	ReturnToShooter:
		AMRK A 1
		{
			if (!target)
				A_FadeOut(0.05);
			// Return to the player:
			else
			{
				// fly back to the player with a fixed speed:
				vel = Vec3to(target).Unit() * 35;
				// If close enough, reload the jacks and disappear:
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

// This deals the actual damage over time
// from the secondary attack:
class ToM_JackDOTControl : ToM_InventoryToken
{
	const SEEKERTICDAMAGE = 25; // damage per one effect tick
	const DOTTIME = 35 * 4; // duration of the DOT effect
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
		// Do the counter:
		if (dotcounter < DOTTIME)
		{
			dotcounter++;
			// Destroy the token if time is up:
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
		// Deal the damage with randomized delay (make sure the delay isn't 0):
		if (GetAge() % Clamp(dmgdelay, 1, 100) == 0)
		{
			dmgdelay = random[jackdamage](10, 15);
			owner.A_StartSound("weapons/jacks/flesh", CHAN_BODY, CHANF_NOSTOP);
			owner.DamageMobj(self, target, SEEKERTICDAMAGE, "Normal", DMG_PLAYERATTACK|DMG_THRUSTLESS);
		}
	}
}
