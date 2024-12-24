class ToM_Jacks : ToM_BaseWeapon
{
	enum JacksWeapFlags
	{
		JREADYFRAME = 0, //frame when ready for firing
		JWAITFRAME = 14, //frame when waiting for jacks to return 
		JPROJNUMBER = 6, //number of jacks used by altfire
		// In case jacks don't return for some reason, restore
		// then automatically after x2 the regular DOT duration:
		JSAFERELOAD = TICRATE * 8,
	}
	int jackswait; //wait time for safe reload
	Actor jackball;
	array<ToM_RealSeeker> thrownSeekers;

	Default
	{
		Tag "$TOM_WEAPON_JACKS";
		ToM_BaseWeapon.CheshireSound "cheshire/vo/nastygame";
		Inventory.Icon "AWICJACK";
		weapon.slotnumber 3;
		weapon.ammotype1 "ToM_WeakMana";
		weapon.ammouse1 6;
		weapon.ammogive1 60;
		weapon.ammotype2 "ToM_WeakMana";
		weapon.ammouse2 12;
	}
	
	// Set frame based on wasThrown value:
	action void A_SetJacksFrame()
	{
		let psp = player.FindPSprite(OverlayID());
		if (!psp)
			return;
		
		psp.frame = invoker.wasThrown ? JWAITFRAME : JREADYFRAME;
		//console.printf("tossed: %d", invoker.wasThrown);
	}
	
	action state A_JacksReady()
	{
		A_WeaponReady(invoker.wasThrown ? WRF_NOFIRE : 0);
		let psp = player.FindPSprite(OverlayID());
		if (psp && psp.frame == JWAITFRAME && !invoker.wasThrown)
			return ResolveState("JacksReload");
		return ResolveState(null);
	}
	
	// Primary fire:
	action void A_TossJacks()
	{
		if (!invoker.DepleteAmmo(invoker.bAltFire, true))
			return;
		A_StartSound("weapons/jacks/toss", CHAN_WEAPON);
		for (int i = JPROJNUMBER; i > 0; i--)
		{
			let proj = ToM_JackProjectile(
				A_Fire3DProjectile(
					"ToM_JackProjectile", 
					useammo: false,
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
		if (!invoker.DepleteAmmo(invoker.bAltFire, true))
			return;
		A_StartSound("weaopons/jacks/toss", CHAN_WEAPON);
		for (int i = JPROJNUMBER; i > 0; i--)
		{
			let proj = ToM_RealSeeker(
				A_Fire3DProjectile(
					"ToM_RealSeeker", 
					useammo: false,
					forward: 1, 
					leftright: 3.2 + frandom[jp](-4, 4), 
					updown: frandom[jp](-2.5, 2.5),
					crosshairConverge: false,
					angleoffs: frandom[jf](-10, 10),
					pitchoffs: -3.5 + frandom[jf](-6, 6)
				)
			);
			// Set randomized rotation and vel:
			if (proj)
			{
				invoker.thrownSeekers.Push(proj);
				proj.rollstep = frandom[jp](4, 5.5) * randompick[jp](-1, 1);
				proj.angstep = frandom[jp](4, 5.5) * randompick[jp](-1, 1);
				proj.vel *= frandom(0.9, 1);
			}
		}
		
		// The weapon is no longer ready for firing:
		invoker.jackswait = JSAFERELOAD;
		invoker.wasThrown = true;
		Vector2 horOfs = (28, -32);
		horOfs = RotateVector(horOfs, angle);
		invoker.jackball = Spawn('ToM_JackBall', pos+(horOfs, height*0.5));
		invoker.jackball.master = self;
	}

	void RecallSeekerJacks()
	{
		for (int i = thrownSeekers.Size() - 1; i >= 0; i--)
		{
			let jack = thrownSeekers[i];
			if (jack)
			{
				jack.tracer = null;
				jack.bMissile = null;
				jack.bNoInteraction = true;
				jack.returnspeed = owner? jack.Distance3D(owner) / jack.JRETURNTIME : 0;
				jack.SetStateLabel("ReturnToShooter");
			}
		}
	}
	
	override void DoEffect()
	{
		super.DoEffect();
		// Safe reload for edge cases when jacks can't return:
		if (jackswait > 0)
		{
			jackswait--;
			if (jackswait <= 0 && wasThrown)
			{
				wasThrown = false;
				RecallSeekerJacks();
				thrownSeekers.Clear();
			}
		}
		// Reload if all seekers have returned:
		if (wasThrown)
		{
			if (thrownSeekers.Size() > 0)
			{
				for (int i = thrownSeekers.Size() - 1; i >= 0; i--)
				{
					if (!thrownSeekers[i])
					{
						thrownSeekers.Delete(i);
					}
				}
			}
			if (thrownSeekers.Size() <= 0)
			{
				wasThrown = false;
			}
		}
		// Remove ball:
		if (!wasThrown && jackball)
		{
			jackball.Destroy();
			jackball = null;
		}
	}
	
	States
	{
	Select:
		AJCK A 0 
		{
			A_SetSelectPosition(24, WEAPONTOP + 54);
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
		TNT1 A 0 A_PlayerAttackAnim(30, 'attack_knife_alt', 30);
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
		TNT1 A 0 A_CheckReload();
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
		TNT1 A 0 A_PlayerAttackAnim(32, 'attack_cards', 25);
		AJCK GGGHHH 1 A_WeaponOffset(-4, 1.5, WOF_ADD);
		AJCK IIIIIJ 1 A_WeaponOffset(-1.5, 1.5, WOF_ADD);
		AJCK KK 1 A_WeaponOffset(5, -1, WOF_ADD);
		TNT1 A 0 A_FireJackSeekers;
		AJCK LLL 1 A_WeaponOffset(5, -1, WOF_ADD);
		AJCK LLLLLLLLL 1 A_WeaponOffset(3, 1, WOF_ADD);
		TNT1 A 0 A_CheckReload();
		TNT1 A 0 A_ResetPSprite(OverlayID(), 5);
		AJCK MMMNN 1;
		goto Ready;
	}
}


// The jack projectile used by primary attack.
// It's bouncing, subjected to gravity,
// and can deal damage to the same actor multiple times,
// but not more often than once per RIPDELAY tics.

class ToM_JackProjectile : ToM_Projectile
{
	enum JACKPFLAGS
	{
		RIPDELAY = 8,
		JLIFETIME = 35 * 3,
	}
	
	double rollstep; // roll change per tic (visual)
	double angstep; // angle change per tic (visual)
	protected Actor ripvictim;
	protected int ripwait;
	protected int JackDamage;
	property JackDamage : JackDamage;

	Default
	{
		ToM_Projectile.trailcolor "FFAAAA";
		ToM_Projectile.trailscale 0.07;
		ToM_Projectile.trailfade 0.01;
		ToM_Projectile.trailalpha 0.14;
		ToM_JackProjectile.JackDamage 32;
		ProjectileKickback 40;
		-NOGRAVITY
		+NODECAL
		+CANBOUNCEWATER
		+BOUNCEONWALLS
		+BOUNCEONFLOORS
		+BOUNCEONCEILINGS
		speed 24;
		gravity 0.3;
		bouncesound "weapons/jacks/bounce";
		bouncefactor 0.6;
	}
	
	override int SpecialMissileHit(Actor victim)
	{
		if (!victim)
			return MHIT_DEFAULT;
		
		if (target && victim == target)
			return MHIT_PASS;

		if (victim.bSHOOTABLE && !victim.bNONSHOOTABLE)
		{
			// Check that victim isn't the shooter,
			// and that it's either a new victim,
			// or the ripping delay has passed and we 
			// can damage the victim again:
			if (target && victim != target && (victim != ripvictim || ripwait <= 0))
			{
				ripvictim = victim; //record victim 
				ripwait = RIPDELAY; //start the rip delay counter
				// deal damage:
				int dealtDmg = victim.DamageMobj(self, target, JackDamage, 'normal');
				if (dealtDmg > 0)
				{
					A_StartSound("weapons/jacks/flesh", CHAN_VOICE, CHANF_NOSTOP);
					// spawn blood decal and actor
					// because DamageMobj doesn't do it automatically:
					if (!victim.bNOBLOOD)
					{
						victim.TraceBleed(JackDamage, self);
						victim.SpawnBlood(pos, AngleTo(victim), JackDamage);
					}
				}
			}
			if (!victim.bBOSS && !victim.bDontRip)
			{
				return MHIT_PASS; // fly through
			}
		}
		return MHIT_DEFAULT; // do the usual behavior
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
			// Count down ripwait so that 
			// the same actor can be damaged again:
			if (ripwait > 0)
				ripwait--;
		}
	}
	
	States
	{
	Spawn:
		M000 A 1
		{
			if (bMISSILE && vel.length() < 3 || age >= JLIFETIME)
			{
				bMISSILE = false;	//stop bouncing and start sliding
				return ResolveState("Death");
			}
			return ResolveState(null);
		}
		loop;
	Death:
		M000 A 35;
		M000 A 1 
		{
			// Scale out of existence:
			scale *= 0.92;
			if (scale.x <= default.scale.x * 0.08)
			{
				return ResolveState("Null");
			}
			return ResolveState(null);
		}
		wait;
	}
}

// Seeking, bouncing jacks used by the 
// alt attack (primary attack int the original
// game, but I made it into alt because
// it's more powerful and harder to use):
class ToM_RealSeeker : ToM_JackProjectile
{
	enum JVALUES
	{
		JSLIFETIME = 35 * 6,
		JRETURNSPEED = 35,
		JRETURNTIME = 20,
		JMAXSEEKDIST = 800,
		JMINFLYTIME = 5,
		JMAXFLYTIME = 30,
	}
	
	double returnspeed;

	Default
	{
		ToM_JackProjectile.JackDamage 20;
		ProjectileKickback 20;
		speed 20;
		bouncefactor 0.75;
		gravity 0.6;
		bouncesound "weapons/jacks/ricochet";
		Radius 4;
		Height 4;
	}
	
	override void Tick()
	{
		super.Tick();
		//Console.Printf("\cyJACKS\c- age: \cd%d\c-/%d | tracer: \cd%d\c- | bMissile: \cd%d\c-", age, JSLIFETIME, tracer != null, bMISSILE);
		if (isFrozen() || bNoInteraction) return;
		
		// Reduce duration faster if the jack
		// is resting and still haven't found
		// a suitable target:
		if (!tracer && !bMISSILE)
		{
			age += 2;
		}
	}
	
	// Reuse collision rules from the regular jack (ToM_JackProjectile),
	// but with some new rules:
	override int SpecialMissileHit(Actor victim)
	{
		let ret = super.SpecialMissileHit(victim);

		if (!victim || (target && victim == target))
		{
			return ret;
		}

		// Extra rule: seeking jacks CAN rip through bosses and DONTRIP,
		// in contrast to regular jacks:
		if (ret == MHIT_DEFAULT && (victim.bBoss || victim.bDontRip))
		{
			ret = MHIT_PASS;
		}

		// We hit something valid:
		if (ret == MHIT_PASS && (victim.bSolid || victim.default.bShootable))
		{
			// If the jacks hit a valid enemy without having obtained
			// a tracer yet, set this actor as the tracer:
			if (!tracer)
			{
				if (victim.health > 0 && (victim.bIsMonster || victim.player))
				{
					tracer = ripvictim = victim;
				}
				else
				{
					GetTracer();
				}
			}
			// When successfully hitting something shootable,
			// seeker jacks bounce off it upwards, with a little horizontal
			// momentum.
			// (Imitates the fact that in AMA jacks aim at victims not only 
			// after bouncing off a surface, but also after bouncing off
			// a victim and losing velocity in the air).
			// If this was a monster/player, it also got damaged earlier in
			// the Super.SpecialMissileHit call. Otherwise (shootable but
			// not a monster or a player) jacks will just bounce of this:
			vel.xy = ( frandom[vicbounce](-4, 4), frandom[vicbounce](-4, 4) );
			vel.z = frandom[vicbounce](5, 10);
		}
		return ret;
	}
	
	void GetTracer(double atkdist = 400)
	{
		tracer = null;
		double closestDist = atkdist;
		BlockThingsIterator itr = BlockThingsIterator.Create(self,atkdist);
		while (itr.next()) 
		{
			let next = itr.thing;
			if (!next || next == self || 
				next == target || 
				!next.bSHOOTABLE || 
				!(next.bIsMonster || next.player) || 
				next.health <= 0)
				continue;
			double dist = Distance3D(next);
			if (dist > closestDist)
				continue;
			if (!CheckSight(next,SF_IGNOREWATERBOUNDARY))
				continue;
			closestDist = dist;
			tracer = next;
		}
	}
	
	// Every time the jack bounces off a surface, it'll aim at its
	// tracer (or try to find a new one) and "bounce" towards it:
	override int SpecialBounceHit(Actor bounceMobj, Line bounceLine, readonly<SecPlane> bouncePlane)
	{
		if (!tracer || !CheckSight(tracer, SF_IGNOREWATERBOUNDARY) || tracer.health <= 0 || Distance3D(tracer) > JMAXSEEKDIST)
		{
			GetTracer();
		}

		if (tracer)
		{
			// 2D vector to victim:
			vector2 diff = LevelLocals.Vec2Diff(pos.xy, tracer.pos.xy);
			vector2 dir = diff.unit(); //normalized (direction)
			double dist = diff.length(); //distance
			// vertical pos difference:
			double vdiff = tracer.pos.z - pos.z + (tracer.height * 0.8);
			
			// Calculate how long it'll take the jack to reach
			// its victim (between JMINFLYTIME-JMAXFLYTIME,
			// depending on the distance):
			double flytime = ToM_Utils.LinearMap(dist, 32, JMAXSEEKDIST, JMINFLYTIME, JMAXFLYTIME, clampit: true);
			
			// fly, baby!
			vel.xy = dir * dist / flytime;
			vel.z = (vdiff + 0.5 * flytime**2) / flytime;
			vel *= GetGravity();
			
			ToM_DebugMessage.Print(String.Format("\cyJACKS\c- victim: %s | Distance: %.1f | Vel: %.1f", tracer.GetClassName(), dist, vel.length()), 2);
			
			return MHIT_PASS;
		}

		tracer = null;
		if (vel.length() < 3)
		{
			bMissile = false;
		}
		return MHIT_DEFAULT;
	}

	void ReturnToShooter()
	{
		if (!target)
			return;
		
		let jacks = ToM_Jacks(target.FindInventory('ToM_Jacks'));
		if (jacks)
		{
			jacks.RecallSeekerJacks();
		}
	}
	
	States
	{
	Spawn:
		M000 A 1
		{
			// If time's up, return to the shooter:
			if (age >= JSLIFETIME)
			{
				ReturnToShooter();
			}
			if (!target)
			{
				tracer = null;
			}
		}
		wait;
	ReturnToShooter:
		M000 A 1
		{
			if (!target)
				A_FadeOut(0.05);
			// Return to the player:
			else
			{
				// fly back to the player at the previously
				// calculated speed:
				vel = Vec3to(target).Unit() * returnspeed;
				// If close enough, reload the jacks and disappear:
				if (Distance3D(target) < 64)
				{
					let weap = ToM_Jacks(target.FindInventory("ToM_Jacks"));
					if (weap)
					{
						int id = weap.thrownSeekers.Find(self);
						if (id != weap.thrownSeekers.Size())
						{
							weap.thrownSeekers.Delete(id);
						}
					}
					Destroy();
				}
			}
		}
		wait;
	}
}

class ToM_JackBall : ToM_BaseActor
{
	Vector3 posOffset;

	Default
	{
		+NOINTERACTION
		+NOBLOCKMAP
		Scale 0.5;
		speed 15;
	}

	override void Tick()
	{
		Super.Tick();
		if (!master)
		{
			Destroy();
			return;
		}
		if (isFrozen())
		{
			return;
		}

		// Horizontal position:
		Vector2 targetXY = master.pos.xy + RotateVector((28, -32), master.angle);
		Vector2 hDiff = Level.Vec2Diff(pos.xy, targetXY);
		posOffset.xy = pos.xy + hdiff*0.5;

		// Vertical position:
		double top = master.height * 1.2;
		double ofsZ = top * ToM_Utils.SinePulse(time:age);
		posOffset.z = master.pos.z + ofsZ;

		if (ofsZ <= 0.1)
		{
			A_StartSound("weapons/jacks/ballbounce", flags:CHANF_NOSTOP);
		}

		// Apply position:
		SetOrigin(posOffset, true);

		// Apply bouncy scale:
		if (ofsZ <= top*0.2)
		{
			scale.x = ToM_Utils.LinearMap(ofsZ, 0, top*0.2, default.scale.x*1.4, default.scale.x);
			scale.y = ToM_Utils.LinearMap(ofsZ, 0, top*0.2, default.scale.y*0.65, default.scale.y);
		}
		else
		{
			scale.x = ToM_Utils.LinearMap(ofsZ, top*0.2, top*0.6, default.scale.x, default.scale.x*0.75, true);
			scale.y = ToM_Utils.LinearMap(ofsZ, top*0.2, top*0.6, default.scale.y, default.scale.y*1.15, true);
		}
	}

	States 
	{
	Spawn:
		M000 A -1;
		stop;
	}
}