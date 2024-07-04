class ToM_Icewand : ToM_BaseWeapon
{
	ToM_ReflectionCamera cam;

	Default
	{
		Tag "$TOM_WEAPON_ICEWAND";
		ToM_BaseWeapon.IsTwoHanded true;
		Weapon.SlotNumber 6;
		weapon.ammotype1 "ToM_MediumMana";
		weapon.ammouse1 1;
		weapon.ammogive1 80;
		weapon.ammotype2 "ToM_MediumMana";
		weapon.ammouse2 20;
	}

	action void A_FireIceWave()
	{
		let def = GetDefaultByType('ToM_IceWandProjectileReal');
		let real = ToM_IceWandProjectileReal(A_Fire3DProjectile("ToM_IceWandProjectileReal"));
		let vis = A_Fire3DProjectile("ToM_IceWandProjectileVisual", useammo: false, forward: 32, leftright:10, updown:-11);
		if (real && vis)
		{
			real.visualProj = vis;
		}
	}

	action void A_FireIcewallWave()
	{
		let psp = player.FindPSprite(PSP_WEAPON);
		if (psp)
		{
			let p = A_Fire3DProjectile("ToM_IceWandProjectileVisual", useammo: false, forward: 32, leftright:40 + psp.x, updown:-11 + -(psp.y - WEAPONTOP), angleoffs: psp.rotation*0.5, pitchoffs: -(psp.y - WEAPONTOP)*0.5);
			if (p)
			{
				p.vel *= 0.5;
			}
		}
	}

	action void A_SpawnIceWall(double width, double distance = 64)
	{
		FLineTraceData tr;
		for (int i = -30; i < 30; i += 10)
		{
			LineTrace(angle + i, distance, 0, TRF_SOLIDACTORS, offsetz: player.viewz - pos.z, data: tr);
			distance = min(distance, tr.distance);
		}
		
		class<Actor> wallelement = 'ToM_IceWallHitBox';
		double step = GetDefaultByType(wallelement).radius*2;
		int segments = round(width / step);
		double startOfs = step * (segments-1) * 0.5;
		double lastOfs = -startOfs;
		bool spawned; Actor wall;
		[spawned, wall] = A_SpawnItemEx('ToM_IceWall', xofs: distance, yofs: 0);
		let wallvis = ToM_IceWall(wall);
		if (wallvis)
		{
			wallvis.A_StartSound("weapons/icewand/icewall");
			while (startOfs >= lastOfs)
			{
				[spawned, wall] = A_SpawnItemEx(wallelement, xofs: distance, yofs: startOfs);
				startOfs -= step;
				if (wall)
				{
					wall.master = wallvis;
					wallvis.hitboxes.Push(ToM_IceWallHitBox(wall));
				}
			}
		}
	}

	override bool DepleteAmmo(bool altFire, bool checkEnough, int ammouse, bool forceammouse)
	{
		if (!altfire && (owner.player.refire % 3 != 0))
		{
			return true;
		}
		return Super.DepleteAmmo(altFire, checkEnough, ammouse, forceammouse);
	}

	override void DoEffect()
	{
		super.DoEffect();
		if (!owner || !owner.player)
		{
			if (cam) cam.Destroy();
			return;
		}
		
		let weap = owner.player.readyweapon;
		if (weap == self)
		{
			if (!cam)
			{
				cam = ToM_ReflectionCamera.Create(
					PlayerPawn(owner), owner.player.fov,
					(owner.radius * 0.5, -12, 40),
					(-20, 15, 0));
			}
		}
		else
		{
			if (cam)
			{
				cam.Destroy();
			}
		}
	}

	States {
	Select:
		AICW A 0 
		{
			A_WeaponOffset(-24, 90+WEAPONTOP);
			A_OverlayPivot(OverlayID(), 0.6, 0.8);
			A_OverlayRotate(OverlayID(), 30);
		}
		#### ###### 1
		{
			A_WeaponOffset(4, -15, WOF_ADD);
			A_OverlayRotate(OverlayID(), -5, WOF_ADD);
			A_WeaponReady(WRF_NOFIRE|WRF_NOBOB);
		}
		goto Ready;
	Deselect:
		AICW A 0
		{
			A_OverlayPivot(OverlayID(), 0.6, 0.8);
			A_StopSound(CHAN_WEAPON);
		}
		#### ###### 1
		{
			A_ResetZoom();
			A_WeaponOffset(-4, 15, WOF_ADD);
			A_OverlayRotate(OverlayID(), 5, WOF_ADD);
		}
		TNT1 A 0 A_Lower;
		wait;
	Ready:
		AICW A 1 A_WeaponReady();
		loop;
	Fire:
		TNT1 A 0 A_OverlayPivot(OverlayID(), 0.3, 0.3);
	Hold:
		AICW A 1
		{
			double sc = 1 + 0.03 * ToM_Utils.SinePulse(40, player.refire);
			double rot = -1 + 2 * ToM_Utils.SinePulse(80, player.refire);
			A_OverlayScale(OverlayID(), sc, sc, WOF_INTERPOLATE);
			A_OverlayRotate(OverlayID(), rot, WOF_INTERPOLATE);
			A_FireIceWave();
		}
		TNT1 A 0 
		{
			if (PressingAttackButton())
			{
				A_startSound("weapons/icewand/fire", CHAN_WEAPON, CHANF_LOOPING);
			}
			else
			{
				A_StopSound(CHAN_WEAPON);
			}
			A_Refire();
		}
		AICW A 4 A_ResetPSprite(OverlayID(), 4, interpolate: true);
		goto Ready;
	AltFire:
		TNT1 A 0 A_OverlayPivot(OverlayID(), 0.8, 0.8);
		AICW AAAAAAAA 1 
		{
			A_OverlayRotate(OverlayID(), 5, WOF_ADD);
			A_WeaponOffset(-5, 5, WOF_ADD);
			A_OverlayScale(OverlayID(), -0.01, -0.01, WOF_ADD);
		}
		AICW AAAA 1 A_OverlayRotate(OverlayID(), 0.5, WOF_ADD);
		#### # 0 
		{
			A_SpawnIceWall(100);
			player.cheats |= CF_TOTALLYFROZEN;
			if (CheckFreeLook())
			{
				A_SetPitch(15, SPF_INTERPOLATE);
			}
			A_Stop();
			A_CameraSway(0, -15, 16);
		}
		AICW AAAAAAAAAAAAAAAA 1 
		{
			A_FireIcewallWave();
			A_OverlayRotate(OverlayID(), -2, WOF_ADD);
			A_WeaponOffset(1.5, -0.5, WOF_ADD);
			A_OverlayScale(OverlayID(), 0.001, 0.001, WOF_ADD);
		}
		AICW A 15 
		{
			A_ResetPSprite(OverlayID(), 10, interpolate: true);
			player.cheats &= ~CF_TOTALLYFROZEN;
		}
		goto Ready;
	}
}

class ToM_IceWandProjectileReal : ToM_PiercingProjectile
{
	Actor visualProj;

	Default
	{
		speed 16;
		radius 6.5;
		height 10;
		alpha 0.5;
	}

	override int SpecialMissileHit(Actor victim)
	{
		// Hitting an ice wall will increase its strength:
		if (victim is 'ToM_IceWallHitBox' && victim.master)
		{
			let wall = ToM_IceWall(victim.master);
			if (wall)
			{
				wall.wallduration = Clamp(wall.wallduration + ToM_IceWall.RESTOREAMOUNT, 0, ToM_IceWall.MAXDURATION);
			}
		}
		return Super.SpecialMissileHit(victim);
	}

	override void HitVictim(Actor victim)
	{
		ToM_FreezeController.AddFreeze(victim);
		victim.DamageMobj(self, target? target : Actor(self), 3, 'Normal', DMG_THRUSTLESS|DMG_NO_PAIN);
	}

	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		if (target)
		{
			vel += target.vel;
		}
		wrot = frandom[teasmoke](4,7);
	}

	override void Tick()
	{
		super.Tick();
		if (isFrozen())
			return;
		
		if (vel.length() < 5)
			A_FadeOut(0.06);
			
		vel *= 0.93;
		if (visualProj)
		{
			visualProj.vel = visualProj.vel.Unit() * self.vel.length();
		}
	}
	
	States
	{
	Spawn:
		TNT1 A -1;
		stop;
	Death:
		TNT1 A 1;
		stop;
	}
}


class ToM_IceWandProjectileVisual : ToM_IceWandProjectileReal
{
	Default
	{
		Renderstyle 'AddStencil';
		StencilColor '79dfeb';
		+BRIGHT
		+NOCLIP
		+FORCEXYBILLBOARD
		scale 0.1;
		radius 1;
		height 1;
	}

	override bool CheckValid(Actor victim)
	{
		return false;
	}

	override void HitVictim(Actor victim)
	{}

	override void Tick()
	{
		super.Tick();
		if (isFrozen())
			return;
		
		roll += wrot;
		wrot *= 0.95;
		scale *= 1.03;
	}
	
	States
	{
	Spawn:
		SMO2 # -1 NoDelay 
		{
			frame = random[sfx](0,5);
		}
		stop;
	Death:
		#### # 1 A_FadeOut(0.03);
		loop;
	}
}

class ToM_FreezeController : Powerup
{
	const SPEEDFACTOR = 0.5;
	const FREEZEDEATHTIME = TICRATE * 10;
	const MAXDURATION = TICRATE * 6;
	int freezeDeathTics;
	Vector2 ownerSpriteOffset;
	ToM_FrozenCase frozenCase;
	protected State slowstate;

	Default
	{
		Powerup.Duration -1;
	}

	static void AddFreeze(Actor victim)
	{
		if (!victim || victim.bNoIceDeath || victim.bBoss) return;

		let iceman = ToM_FreezeController(victim.FindInventory('ToM_FreezeController'));
		if (iceman)
		{
			iceman.EffectTics = Clamp(iceman.EffectTics += 2, 0, MAXDURATION);
			//Console.Printf("%s freeze duration: %d", victim.GetClassName(), iceman.EffectTics);
			if (iceman.EffectTics % 20 == 0)
			{
				Vector3 dpos = victim.pos + (0,0,victim.height*0.5) + (frandom[icedebris](-3,3),frandom[icedebris](-3,3),frandom[icedebris](-victim.height*0.2,victim.height*0.2));
				let deb = ToM_IceCluster(Spawn('ToM_IceCluster', dpos));
				if (deb)
				{
					deb.master = victim;
					deb.masterOfs = level.Vec3Diff(victim.pos, deb.pos);
				}
			}
		}
		else
		{
			victim.GiveInventory('ToM_FreezeController', 1);
		}
	}

	override void InitEffect()
	{
		Super.InitEffect();
		if (owner)
		{
			owner.speed *= SPEEDFACTOR;
			ownerSpriteOffset = owner.SpriteOffset;
		}
	}

	override void EndEffect()
	{
		if (owner)
		{
			owner.speed /= SPEEDFACTOR;
		}
		Super.EndEffect();
	}

	override void Tick ()
	{
		if (!owner)
		{
			Destroy();
		}
		else if (effectTics > 0)
		{
			effectTics--;
		}
		else if (freezeDeathTics <= 0)
		{
			Destroy();
		}
	}

	override void OwnerDied()
	{
		if (!owner) return;
		freezeDeathTics = FREEZEDEATHTIME;
		owner.A_NoBlocking();
		owner.A_SetRenderstyle(1, Style_Normal);
		owner.A_SetTranslation('Ice');
	}

	override void DoEffect()
	{
		Super.DoEffect();
		if (!owner) return;

		if (effectTics && owner.health > 0 && owner.curstate != slowstate)
		{
			slowstate = owner.curstate;
			owner.tics = round(owner.curstate.tics * ToM_Utils.LinearMap(effectTics, 0, MAXDURATION, 2, 4));
		}

		// Post-death effects:
		if (freezeDeathTics > 0 && !owner.IsFrozen())
		{
			freezeDeathTics--;
			owner.SetStateLabel("Pain");
			owner.A_SetTics(-1);
			if (!frozenCase)
			{
				frozenCase = ToM_FrozenCase.SpawnCase(owner);
			}
			if (freezeDeathTics <= 0)
			{
				if (owner.special)
				{
					owner.A_CallSpecial(owner.special, owner.args[0], owner.args[1], owner.args[2], owner.args[3], owner.args[4]);
					owner.special = 0;
				}
				if (owner.bBossDeath)
				{
					owner.A_BossDeath();
				}
				owner.SetStateLabel("Null");
			}
			else if (freezeDeathTics <= FREEZEDEATHTIME*0.5)
			{
				owner.SpriteOffset.y = ToM_Utils.LinearMap(freezeDeathTics, 0, FREEZEDEATHTIME*0.5, ownerSpriteOffset.y + owner.default.height, ownerSpriteOffset.y);
				
				frozenCase.scale.x *= 1.003;
				frozenCase.scale.y = ToM_Utils.LinearMap(freezeDeathTics, 0, FREEZEDEATHTIME*0.5, 0, frozenCase.baseScale.y);
			}
		}
	}
}

class ToM_IceCluster : Actor
{
	Vector3 masterOfs;

	Default
	{
		+NOINTERACTION
		+NOBLOCKMAP
		Height 1;
		Radius 1;
		Renderstyle 'Add';
		Alpha 0.5;
		Scale 10;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		pitch = frandom[icewall](-90, 90);
		angle = frandom[icewall](0,360);
		scale *= frandom[icewall](0.75, 1.0);
	}

	override void Tick()
	{
		Super.Tick();
		if (!master)
		{
			Destroy();
		}
		else
		{
			Warp(master, masterOfs.x, masterOfs.y, masterOfs.z, flags: WARPF_NOCHECKPOSITION|WARPF_INTERPOLATE);
		}
	}

	States {
	Spawn:
		M000 A 0 NoDelay 
		{
			frame = random[icewall](0,2);
		}
		#### # 1 A_FadeOut(default.alpha / (TICRATE * 3));
		wait;
	}
}

Class ToM_FrozenCase : ToM_BaseActor
{
	Vector2 baseScale;
	double zofs;

	Default 
	{
		+NOINTERACTION
		+NOBLOCKMAP
		+SYNCHRONIZED
		+DONTBLAST
		FloatBobPhase 0;
		Renderstyle 'Add';
		Alpha 0.5;
	}

	static ToM_FrozenCase SpawnCase(Actor victim)
	{
		let a = ToM_FrozenCase(Spawn('ToM_FrozenCase', victim.pos));
		if (a)
		{
			a.A_StartSound("weapons/icewand/flesh");
			a.master = victim;
			a.scale.x = victim.radius*2.15;
			a.scale.y = victim.default.height + Clamp(victim.projectilePassHeight, 0, 128);
			a.basescale = a.scale;
			a.zofs = frandom[frozencase](0.01, 0.10);
			a.angle = frandom[frozencase](0, 360);
			a.alpha = 0;
			victim.A_SetRenderstyle(1.0, STYLE_translucent);
			victim.bCorpse = false;
		}
		return a;
	}
	
	override void Tick()
	{
		Super.Tick();
		if (!master)
		{
			A_FadeOut(0.014);
			scale.x *= 1.004;
		}
		else
		{
			SetOrigin(master.pos + (0,0,zofs), true);
		}
	}

	States {
	Spawn:
		M000 A 1
		{
			alpha += 0.025;
			if (alpha >= default.alpha)
			{
				return ResolveState("Idle");
			}
			return ResolveState(null);
		}
		loop;
	Idle:
		M000 A 1
		{
			if (master)
			{
				double fac = Clamp(scale.y / basescale.y, 0., 1.);
				alpha = default.alpha*0.25 + default.alpha*0.75*fac;
				master.alpha = fac;
			}
		}
		loop;
	}
}

class ToM_IceWall : Actor
{
	array<ToM_IceWallHitBox> hitboxes;
	const MAXDURATION = TICRATE * 8;
	const MELTDURATION = MAXDURATION / 2;
	const RESTOREAMOUNT = 4;
	int wallduration;

	Default
	{
		+NOBLOCKMAP
		Height 80;
		Radius 1;
		Renderstyle 'Add';
		Alpha 0.5;
	}

	void ScaleHeight(double fac)
	{
		height = default.height * fac;
		scale.y = default.scale.y * fac;
		foreach (mo : hitboxes)
		{
			if (mo)
			{
				mo.height = height;
			}
		}
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		scale.y *= 0.25;
		alpha = 0;
		angle += randompick[icewall](0, 180);
		wallduration = MAXDURATION;
	}

	override void OnDestroy()
	{
		foreach (mo : hitboxes)
		{
			if (mo)
			{
				mo.Destroy();
			}
		}
		Super.OnDestroy();
	}

	override void Tick()
	{
		Super.Tick();
		foreach (mo : hitboxes)
		{
			if (mo)
			{
				mo.SetZ(pos.z);
			}
		}
	}

	States {
	Spawn:
		M000 A 1
		{
			scale.y = Clamp(scale.y * 1.05, 0, default.scale.y);
			alpha = Clamp(alpha += 0.05, 0, default.alpha);
			if (scale.y >= default.scale.y)
			{
				foreach (mo : hitboxes)
				{
					if (mo)
					{
						mo.wallReady = true;
					}
				}
				return ResolveState("Idle");
			}
			return ResolveState(null);
		}
		wait;
	Idle:
		M000 A 1
		{
			if (wallduration <= 0)
			{
				return ResolveState("Null");
			}
			wallduration--;
			alpha = ToM_Utils.LinearMap(wallduration, 0, MAXDURATION, 0, default.alpha);
			if (wallduration < MELTDURATION)
			{
				ScaleHeight(ToM_Utils.LinearMap(wallduration, 0, MELTDURATION, 0, 1));
				scale.x = ToM_Utils.LinearMap(wallduration, 0, MELTDURATION, default.scale.x*1.5, default.scale.x);
			}
			return ResolveState(null);
		}
		loop;
	}
}

class ToM_IceWallHitBox : Actor
{
	bool wallReady;

	Default
	{
		+SOLID
		+SHOOTABLE
		+NODAMAGE
		+NODAMAGETHRUST
		+DONTBLAST
		+NOBLOOD
		+DONTRIP
		Height 80;
		Radius 10;
	}

	override void CollidedWith(Actor other, bool passive)
	{
		if (!wallready && passive)
		{
			let dir = Vec3To(other).Unit();
			other.vel = dir * radius;
		}
	}
}