class ToM_HobbyHorse : ToM_BaseWeapon
{
	int combo;

	protected array < Actor > swingVictims; //actors hit by the attack
	protected vector2 swingOfs;
	protected vector2 swingStep;
	protected int swingSndCounter; //delay the attack sound...
	const SWINGSTAGGER = 8; // ...by this much

	int fallAttackForce;
	
	Default
	{
		Tag "$TOM_WEAPON_HORSE";
		ToM_BaseWeapon.IsTwoHanded true;
		+WEAPON.MELEEWEAPON
		+WEAPON.NOAUTOFIRE
		Weapon.slotnumber 1;
		Weapon.slotpriority 1;
	}
	
	// Set up the swing: initial coords and the step:
	action void A_PrepareSwing(double startX, double startY, double stepX, double stepY)
	{
		invoker.swingVictims.Clear();
		invoker.swingOfs = (startX, startY);
		invoker.swingStep = (stepX, stepY);
	}
	
	// Do the attack and move the offset one step as defined above:
	action void A_SwingAttack(int damage, double range = 64, class<Actor> pufftype = 'ToM_HorsePuff')
	{
		// Get the screen-relative angle/pitch using Gutamatics:
		ToM_GM_Quaternion view = ToM_GM_Quaternion.createFromAngles(angle, pitch, roll);
		ToM_GM_Quaternion ofs = ToM_GM_Quaternion.createFromAngles(invoker.swingOfs.x, invoker.swingOfs.y, 0);
		ToM_GM_Quaternion res = view.multiplyQuat(ofs);
		double aimAng, aimPch;
		[aimAng, aimPch] = res.toAngles();
		
		FLineTraceData hit;
		LineTrace(
			aimAng, 
			range, 
			aimPch, 
			TRF_NOSKY|TRF_SOLIDACTORS, 
			ToM_Utils.GetPlayerAtkHeight(PlayerPawn(self)), 
			data: hit
		);
		
		let type = hit.HitType;
		// Do this if we hit geometry:
		if (type == TRACE_HitFloor || type == TRACE_HitCeiling || type == TRACE_HitWall)
		{
			if (invoker.swingSndCounter <= 0)
			{
				invoker.swingSndCounter = SWINGSTAGGER;
				A_StartSound("weapons/hhorse/hitwall", CHAN_AUTO);
				int val = 1 * invoker.combo;
				A_QuakeEx(val, val, val, 6, 0, 32, "");
			}
		}
		
		// Do this if we hit an actor:
		else if (type == TRACE_HitActor)
		{
			let victim = hit.HitActor;
			// Check the victim is valid and not yet in the array:
			if (victim && (victim.bSHOOTABLE || victim.bSOLID) && victim.health > 0 && invoker.swingVictims.Find(victim) == invoker.swingVictims.Size())
			{
				invoker.swingVictims.Push(victim);
				// Can be damaged:
				if (!victim.bDORMANT && victim.bSHOOTABLE)
				{
					victim.DamageMobj(self, self, damage, 'normal', angle: self.angle + 180);
					A_StartSound("weapons/hhorse/hitflesh", CHAN_WEAPON);
					// Bleed:
					if (!victim.bNOBLOOD)
					{
						victim.TraceBleed(damage, self);
						victim.SpawnBlood(hit.HitLocation, AngleTo(victim), damage);
					}
				}
				// Can't be damaged:
				else
					A_StartSound("weapons/hhorse/hitwall", CHAN_AUTO);
			}
		}
		// Debug spot:
		// let spot = Spawn("ToM_DebugSpot", hit.hitlocation);
		// spot.A_SetHealth(1);
		
		// Add a step:
		invoker.swingOfs += invoker.swingStep;
	}

	action void A_StartJumpAttack()
	{
		invoker.combo = 0;
		A_ResetPSprite();
		A_OverlayPivot(OverlayID(), 0.2, 0.8);
		A_StartSound("weapons/hhorse/jumpattack", CHAN_BODY);
		vector3 forwarddir = (cos(angle), sin(angle), 0);
		double fwdvel = vel dot forwarddir;
		VelFromAngle(fwdvel + 7);
		// jump has to be reset to not mess with jumping/falling-after-jump gravity:
		player.jumptics = 0;
		if (player.onGround)
		{
			vel.z += 12;
		}
	}

	action void A_LandAttack()
	{
		A_StopSound(CHAN_BODY);
		A_StartSound("*land", CHAN_BODY);
		A_CameraSway(0, 30, 4);

		int fallAttackForce = invoker.fallAttackForce;
		//int fallAttackForce = (abs(vel.x) + abs(vel.y)) * 0.5 + abs(vel.z);
		
		int rad = 128 + fallAttackForce;
		vector3 ipos = ToM_Utils.RelativeToGlobalCoords(self, (radius + 8, 0, 0));
		ipos.z = floorz;
		let hi = Spawn("ToM_HorseImpactSpot", ipos);
		if (hi)
		{
			hi.target = self;
			hi.A_Explode(80 + fallAttackForce, rad, 0);
			hi.A_StartSound("weapons/hhorse/hitfloor", CHAN_7);
			double qints = ToM_Utils.LinearMap(fallAttackForce, 4, 32, 1, 4, true);
			int qdur = ToM_Utils.LinearMap(fallAttackForce, 4, 32, 10, 30, true);
			hi.A_Quake(qints, qdur, 0, rad, sfx: "");
			for (int i = random[sfx](12,16); i > 0; i--)
			{
				double randomDebrisVel = 5;
				let debris = Spawn("ToM_RandomDebris", hi.pos + (frandom[sfx](-rad, rad),frandom[sfx](-rad, rad), 0));
				if (debris) 
				{
					double zvel = (pos.z > floorz) ? frandom[sfx](-randomDebrisVel,randomDebrisVel) : frandom[sfx](randomDebrisVel * 0.5, randomDebrisVel);
					debris.vel = (frandom[sfx](-randomDebrisVel,randomDebrisVel),frandom[sfx](-randomDebrisVel,randomDebrisVel),zvel);
					debris.A_SetScale(frandom[sfx](0.5, 1.5));
					debris.gravity *= 0.5;
				}
			}

			FSpawnParticleParams pp;
			pp.texture = TexMan.CheckForTexture("SPRKA0");
			pp.flags = SPF_FULLBRIGHT|SPF_ROLL;
			pp.style = STYLE_Add;
			pp.color1 = "";
			pp.startalpha = 1;
			pp.fadestep = -1;
			for (int i = random[sfx](30,40); i > 0; i--)
			{
				pp.pos = pos + (random[psfx](-rad, rad), random[psfx](-rad, rad), 0);
				pp.lifetime = random[psfx](40, 50);
				Vector2 hvel = (frandom[psfx](0.5, 3), frandom[psfx](-0.5, 0.5));
				double hangle = frandom[psfx](0, 360);
				pp.vel.z = frandom[psfx](0.5, 2);
				pp.vel.xy = Actor.RotateVector(hvel, hangle);
				pp.accel.xy = Actor.RotateVector((hvel.x / pp.lifetime * 0.5, hvel.y * -0.5), hangle);
				pp.size = random[psfx](10, 18);
				pp.sizestep = (pp.size / pp.lifetime) * -0.5;
				Level.SpawnParticle(pp);
			}
		}

		int reps = ToM_Utils.LinearMap(fallAttackForce, 40, 1, 5, 1, true);
		for (int i = 0; i <= reps; i++)
		{
			let iring = ToM_HorseImpact(Spawn("ToM_HorseImpact", ipos));
			iring.scale.x = rad * ToM_Utils.LinearMap(i, 0, reps, 0.3, 1.0);
			iring.scale.y = iring.scale.x;
		}

		if (fallAttackForce >= 29 && pos.z <= floorz)
		{
			let hid = Spawn("ToM_HorseImpactDebris", ipos);
		}

		vel.z = 5;
	}
	
	override void DoEffect()
	{
		super.DoEffect();
		if (!owner || !owner.player)
			return;

		if (swingSndCounter > 0)
			swingSndCounter--;
		
		if (!owner.player.onGround)
		{
			let weap = owner.player.readyweapon;
			if (weap && weap == self)
			{
				let psp = owner.player.FindPSprite(PSP_WEAPON);
				if (!psp)
					return;
				
				if (InStateSequence(psp.curstate, ResolveState("AltFire")))
				{
					fallAttackForce = ceil( (abs(owner.vel.x) + abs(owner.vel.y)) * 0.15 + abs(owner.vel.z) );
				}
			}
		}
	}
	
	States
	{
	Spawn:
		ALHH A -1;
		stop;
	Select:
		HHRS A 0 
		{
			A_WeaponOffset(-24, 90+WEAPONTOP);
			A_OverlayPivot(OverlayID(), 0.6, 0.8);
			A_OverlayRotate(OverlayID(), -18);
		}
		#### ###### 1
		{
			A_WeaponOffset(4, -15, WOF_ADD);
			A_OverlayRotate(OverlayID(), 3, WOF_ADD);
			A_WeaponReady(WRF_NOFIRE|WRF_NOBOB);
		}
		goto Ready;
	Deselect:
		HHRS A 0
		{
			A_OverlayPivot(OverlayID(), 0.6, 0.8);
		}
		#### ###### 1
		{
			A_ResetZoom();
			A_WeaponOffset(-4, 15, WOF_ADD);
			A_OverlayRotate(OverlayID(), -3, WOF_ADD);
		}
		TNT1 A 0 A_Lower;
		wait;
	Ready:
		HHRS A 1 A_WeaponReady();
		wait;
	Fire:
		TNT1 A 0 
		{
			A_ResetPSprite();
			invoker.combo++;
			if (invoker.combo <= 1) {
				A_PlayerAttackAnim(30, 'attack_horse', 25);
				return ResolveState("RightSwing");
			}
			if (invoker.combo == 2) {
				A_PlayerAttackAnim(30, 'attack_horse', 25);
				return ResolveState("LeftSwing");
			}
			A_PlayerAttackAnim(40, 'attack_horse', 20);
			return ResolveState("Overhead");
		}
	RightSwing:
		TNT1 A 0 A_OverlayPivot(OverlayID(), 0.1, 0.6);
		HHRS AAABBBB 1 
		{
			A_WeaponOffset(6, 0, WOF_ADD);
			A_RotatePSprite(OverlayID(), -1.2, WOF_ADD);
		}		
		HHRS CCCC 1 
		{
			A_WeaponOffset(3, 0, WOF_ADD);
			A_RotatePSprite(OverlayID(), -0.5, WOF_ADD);
		}
		TNT1 A 0 
		{
			A_PrepareSwing(-25, -10, 14, 4);
			A_StartSound("weapons/hhorse/swing", CHAN_AUTO);
			A_CameraSway(4, 0, 6);
		}
		HHRS BB 1 
		{
			A_SwingAttack(30);
			A_WeaponOffset(-35, 12, WOF_ADD);
			A_RotatePSprite(OverlayID(), 3, WOF_ADD);
		}
		TNT1 A 0 A_Overlay(APSP_Overlayer, "RightSwingTrail");
		HHRS DD 1 
		{
			A_SwingAttack(30);
			A_WeaponOffset(-50, 22, WOF_ADD);
			A_RotatePSprite(OverlayID(), 3, WOF_ADD);
		}
		HHRS DDD 1 
		{
			A_SwingAttack(30);
			A_WeaponOffset(-50, 22, WOF_ADD);
			A_RotatePSprite(OverlayID(), 4, WOF_ADD);
		}
		goto AttackEnd;
	RightSwingTrail:
		HHRR ABCDA 1 bright
		{
			let from = player.FindPSprite(PSP_WEAPON);
			let to = player.FindPSprite(OverlayID());
			if (from && to)
			{
				to.pivot = from.pivot;
				to.rotation = from.rotation;
			}
		}
		stop;
	LeftSwing:
		TNT1 A 0 A_OverlayPivot(OverlayID(), 0.6, 1);
		HHRS AAAEEEE 1 
		{
			A_WeaponOffset(-6, 0, WOF_ADD);
			A_RotatePSprite(OverlayID(), 1.2, WOF_ADD);
		}
		HHRS GGGG 1 
		{
			A_WeaponOffset(-3, 0, WOF_ADD);
			A_RotatePSprite(OverlayID(), 0.5, WOF_ADD);
		}
		TNT1 A 0 
		{
			A_PrepareSwing(25, -10, -15, 5);
			A_StartSound("weapons/hhorse/swing", CHAN_AUTO);
			A_CameraSway(-4, 0, 6);
		}
		HHRS FF 1 
		{
			A_SwingAttack(30);
			A_WeaponOffset(35, 12, WOF_ADD);
			A_RotatePSprite(OverlayID(), -3, WOF_ADD);
		}
		TNT1 A 0 A_Overlay(APSP_Overlayer, "LeftSwingTrail");
		HHRS HH 1 
		{
			A_SwingAttack(30);
			A_WeaponOffset(45, 18, WOF_ADD);
			A_RotatePSprite(OverlayID(), -3, WOF_ADD);
		}
		HHRS HHH 1 
		{
			A_SwingAttack(30);
			A_WeaponOffset(45, 18, WOF_ADD);
			A_RotatePSprite(OverlayID(), -3, WOF_ADD);
		}
		goto AttackEnd;
	LeftSwingTrail:
		HHRL ABCDA 1 bright
		{
			let from = player.FindPSprite(PSP_WEAPON);
			let to = player.FindPSprite(OverlayID());
			if (from && to)
			{
				to.pivot = from.pivot;
				to.rotation = from.rotation;
			}
		}
		stop;
	Overhead:
		TNT1 A 0 A_OverlayPivot(OverlayID(), 0.2, 0.8);
		HHRS KKKKLLLL 1 
		{
			A_WeaponOffset(1.2, -3, WOF_ADD);
			A_RotatePSprite(OverlayID(), -0.3, WOF_ADD);
			A_ScalePSprite(OverlayID(), 0.0025, 0.0025,WOF_ADD);
		}
		HHRS MMMMMMMM 1 
		{
			A_WeaponOffset(0.6, -1.2, WOF_ADD);
			A_RotatePSprite(OverlayID(), -0.3, WOF_ADD);
			A_ScalePSprite(OverlayID(), 0.0025, 0.0025,WOF_ADD);
		}
		TNT1 A 0 
		{
			A_PrepareSwing(-5, -30, 1.5, 16);
			A_StartSound("weapons/hhorse/heavyswing", CHAN_AUTO);
			A_CameraSway(0, 5, 7);
			A_Overlay(APSP_Overlayer, "OverheadTrail");
		}
		HHRS NOO 1 
		{
			A_SwingAttack(60);
			A_WeaponOffset(-24, 35, WOF_ADD);
			A_RotatePSprite(OverlayID(), 0.1, WOF_ADD);
			A_ScalePSprite(OverlayID(), -0.003, -0.003, WOF_ADD);
		}
		HHRS OO 1 
		{
			A_SwingAttack(60);
			A_WeaponOffset(-24, 35, WOF_ADD);
			A_RotatePSprite(OverlayID(), 0.1, WOF_ADD);
			A_ScalePSprite(OverlayID(), -0.003, -0.003, WOF_ADD);
		}
		TNT1 A 0 { invoker.combo = 0; }
		goto AttackEnd;
	OverheadTrail:
		TNT1 A 1;
		HHRO ABCD 1 bright
		{
			let from = player.FindPSprite(PSP_WEAPON);
			let to = player.FindPSprite(OverlayID());
			if (from && to)
			{
				to.pivot = from.pivot;
				to.rotation = from.rotation;
			}
		}
		stop;
	Altfire:
		TNT1 A 0 
		{
			A_StartJumpAttack();
			A_PlayerAttackAnim(-1, 'attack_horse_alt', 30);//, loopframe: 9, flags: SAF_LOOP);
		}
		HHRS KKKKLLLL 1 
		{
			A_WeaponOffset(1.2, -4, WOF_ADD);
			A_RotatePSprite(OverlayID(), -0.3, WOF_ADD);
			A_ScalePSprite(OverlayID(), 0.0025, 0.0025,WOF_ADD);
		}
		HHRS MMMMMMMM 1 
		{
			A_WeaponOffset(0.6, -1.5, WOF_ADD);
			A_RotatePSprite(OverlayID(), -0.3, WOF_ADD);
			A_ScalePSprite(OverlayID(), 0.0025, 0.0025,WOF_ADD);
		}
		TNT1 A 0 
		{
			//A_PrepareSwing(-5, -30, 1.5, 16);
			A_StartSound("weapons/hhorse/altswing", CHAN_AUTO);
			A_CameraSway(0, 5, 7);
			//A_Overlay(APSP_Overlayer, "OverheadTrail");
		}
		HHRS NNNOOOOOOO 1 
		{
			A_WeaponOffset(-4, 4, WOF_ADD);
			A_RotatePSprite(OverlayID(), 0.03, WOF_ADD);
			A_ScalePSprite(OverlayID(), -0.001, -0.001, WOF_ADD);
		}
	FallLoop:
		HHRS O 1
		{
			let psp = player.FindPSprite(OverlayID());
			if (psp)
			{
				A_WeaponOffset(Clamp(psp.x-2, -68, 0), Clamp(psp.y+2, 32, 68), WOF_INTERPOLATE);
			}
			//invoker.fallAttackForce++;
			if (tom_debugmessages)
				console.printf("fall attack force: %d", invoker.fallAttackForce);
			if (invoker.fallAttackForce > 25)
				A_StartSound("weapons/hhorse/freefall", CHAN_BODY, CHANF_LOOPING);
		}
		TNT1 A 0 
		{
			if (waterlevel >= 2)
			{
				A_StopSound(CHAN_BODY);
				self.tics = 1;
				return ResolveState("AltAttackEnd");
			}
			if (!player.onGround)
			{
				return ResolveState("FallLoop");
			}
			return ResolveState(null);
		}
		TNT1 A 0 
		{
			A_LandAttack();
			A_PlayerAttackAnim(45, 'attack_horse_jump_end', 15);
		}
		HHRS OOOO 1 A_WeaponOffset(3, -6, WOF_ADD);
	AltAttackEnd:
		HHRS OOOOOOOOO 1 
		{
			A_WeaponOffset(-6, 20, WOF_ADD);
			A_RotatePSprite(OverlayID(), 2, WOF_ADD);
		}
		goto AttackEnd;
	AttackEnd:
		TNT1 A 5
		{
			A_WeaponOffset(24, 90+WEAPONTOP);
			A_RotatePSprite(OverlayID(), -30);
			A_WeaponReady(WRF_NOBOB);
		}
		HHRS AAAAAA 1
		{
			A_WeaponOffset(-4, -15, WOF_ADD);
			A_RotatePSprite(OverlayID(), 5, WOF_ADD);
			A_WeaponReady(WRF_NOBOB);
		}
		TNT1 A 0 
		{ 
			A_ResetPSprite();
			invoker.combo = 0;
		}
		goto Ready;
	}
}

class ToM_HorsePuff : ToM_BasePuff
{
	Default
	{
		+NOINTERACTION
		+PUFFONACTORS
		seesound "weapons/hhorse/hitflesh";
		attacksound "weapons/hhorse/hitwall";
	}
	
	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		int val = 1;
		if (target && target.player)
		{
			let wpn = ToM_HobbyHorse(target.player.readyweapon);
			if (wpn)
				val *= wpn.combo;
			target.A_QuakeEx(val, val, val, 6, 0, 32, "");
		}
	}
	
	States
	{
	Spawn:
		TNT1 A 10;
		stop;
	}
}

class ToM_HorseImpactSpot : ToM_BaseActor
{
	Default
	{
		+NOBLOCKMAP
		+NOINTERACTION
	}

	States {
	Spawn:
		TNT1 A 70;
		stop;
	}
}

class ToM_HorseImpact : ToM_SmallDebris
{
	int delay;
	Default
	{
		+NOINTERACTION
		+BRIGHT
		renderstyle 'Add';
	}

	States {
	Spawn:
		TNT1 A 0 A_SetTics(delay);
		M000 A 1
		{
			scale *= 1.05;
			A_FadeOut(0.05);
		}
		wait;
	}
}

class ToM_HorseImpactDebris : ToM_BaseActor
{
	Default
	{
		+NOINTERACTION
		+NOBLOCKMAP
		+MOVEWITHSECTOR
	}

	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		A_StartSound("weapons/hhorse/hitfloor_heavy");
		if (waterlevel > 0 || CheckLiquidFlat() || ToM_Animated_Handler.isAnimated(floorpic))
		{
			Destroy();
			return;
		}
		name texname = TexMan.GetName(floorpic);
		A_ChangeModel("", skinindex: 0, skin: texname, flags: CMDL_USESURFACESKIN);
	}

	override void Tick()
	{
		super.Tick();
		SetZ(floorz);
		if (target)
			target.SetZ(floorz + 0.5);
	}

	States {
	Spawn:
		M000 A 100;
		TNT1 A 0 
		{
			if (target)
				target.Destroy();
		}
		M000 A 1 A_FadeOut(0.05);
		wait;
	}
}