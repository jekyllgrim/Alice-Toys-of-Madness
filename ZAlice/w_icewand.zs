class ToM_Icewand : ToM_BaseWeapon
{
	ToM_ReflectionCamera cam;
	protected double iceWaveSoundVolume;

	Default
	{
		Tag "$TOM_WEAPON_ICEWAND";
		ToM_BaseWeapon.CheshireSound "cheshire/vo/witheringcold";
		ToM_BaseWeapon.IsTwoHanded true;
		ToM_BaseWeapon.LoopedAttackSound "weapons/icewand/fire";
		Weapon.SlotNumber 6;
		weapon.ammotype1 "ToM_StrongMana";
		weapon.ammouse1 1;
		weapon.ammogive1 80;
		weapon.ammotype2 "ToM_StrongMana";
		weapon.ammouse2 10;
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
		[spawned, wall] = A_SpawnItemEx('ToM_IceWall', xofs: distance, flags: SXF_NOCHECKPOSITION);
		let wallvis = ToM_IceWall(wall);
		if (wallvis)
		{
			wallvis.A_StartSound("weapons/icewand/icewall");
			while (startOfs >= lastOfs)
			{
				[spawned, wall] = A_SpawnItemEx(wallelement, xofs: distance, yofs: startOfs, flags: SXF_NOCHECKPOSITION);
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
		// in primary fire mode, only consume 1 mana every 3 tics:
		if (!altfire && owner.player.refire != 0 && owner.player.refire % 3 != 0)
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
					(-20, 15, 0),
					cameraClass: 'ToM_IceWandReflectionCamera');
			}
		}
		else
		{
			if (cam)
			{
				cam.Destroy();
			}
		}

		let psp = owner.player.FindPSprite(PSP_WEAPON);
		if ((weap == self) && psp && psp.curstate.InStateSequence(GetAtkState(true)) && owner.player.refire > 0)
		{
			iceWaveSoundVolume = ToM_Utils.LinearMap(owner.player.refire, 1, 16, 0.1, 1.0, true);
			if (owner.IsActorPlayingSound(CHAN_WEAPON, LoopedAttackSound))
			{
				owner.A_SoundVolume(CHAN_WEAPON, iceWaveSoundVolume);
			}
			else
			{
				owner.A_StartSound(LoopedAttackSound, CHAN_WEAPON, CHANF_LOOPING, iceWaveSoundVolume);
			}
		}
		else if (owner.IsActorPlayingSound(CHAN_WEAPON, LoopedAttackSound))
		{
			iceWaveSoundVolume = Clamp(iceWaveSoundVolume - 0.05, 0.0, 1.0);
			if (iceWaveSoundVolume <= 0)
			{
				owner.A_StopSound(CHAN_WEAPON);
			}
			else
			{
				owner.A_SoundVolume(CHAN_WEAPON, iceWaveSoundVolume);
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
		AICW A 1 A_WeaponReady(player.onGround? 0 : WRF_NOSECONDARY);
		loop;
	Fire:
		TNT1 A 0 
		{
			A_OverlayPivot(OverlayID(), 0.3, 0.3);
			A_PlayerAttackAnim(-1, 'attack_eyestaff', 30, endframe: 1, flags: SAF_LOOP|SAF_NOOVERRIDE);
		}
	Hold:
		AICW A 1
		{
			double sc = 1 + 0.03 * ToM_Utils.SinePulse(40, player.refire);
			double rot = -1 + 2 * ToM_Utils.SinePulse(80, player.refire);
			A_OverlayScale(OverlayID(), sc, sc, WOF_INTERPOLATE);
			A_OverlayRotate(OverlayID(), rot, WOF_INTERPOLATE);
			A_FireIceWave();
		}
		#### # 0 A_Refire();
		AICW A 4 
		{
			A_ResetPSprite(OverlayID(), 4, interpolate: true);
			A_PlayerAttackAnim(1, 'attack_eyestaff');
		}
		goto Ready;
	AltFire:
		TNT1 A 0 
		{
			if (!invoker.DepleteAmmo(true, true))
			{
				return invoker.GetReadyState();
			}
			A_OverlayPivot(OverlayID(), 0.8, 0.8);
			A_PlayerAttackAnim(-1, 'attack_eyestaff', 30, endframe: 1, flags: SAF_LOOP|SAF_NOOVERRIDE);
			return ResolveState(null);
		}
		AICW AAAAAAAA 1 
		{
			A_OverlayRotate(OverlayID(), 5, WOF_ADD);
			A_WeaponOffset(-5, 5, WOF_ADD);
			A_OverlayScale(OverlayID(), -0.01, -0.01, WOF_ADD);
		}
		#### # 0 A_CameraSway(0, 15, 4);
		AICW AAAA 1 A_OverlayRotate(OverlayID(), 0.5, WOF_ADD);
		#### # 0 
		{
			A_SpawnIceWall(100);
			player.cheats |= CF_TOTALLYFROZEN;
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
			A_PlayerAttackAnim(1, 'attack_eyestaff');
			A_ResetPSprite(OverlayID(), 10, interpolate: true);
			player.cheats &= ~CF_TOTALLYFROZEN;
		}
		goto Ready;
	}
}

class ToM_IceWandReflectionCamera : ToM_ReflectionCamera
{
	override void UpdateCameraAngles()
	{
		A_SetAngle(ppawn.angle + cam_angles.x, SPF_INTERPOLATE);
		A_SetPitch(Clamp((cam_angles.y == -1)? -ppawn.pitch : ppawn.pitch + cam_angles.y, -90, 90), SPF_INTERPOLATE);
		double r = ppawn.roll + cam_angles.z;
		let psp = ppawn.player.FindPSprite(PSP_WEAPON);
		if (psp)
		{
			r -= psp.rotation;
		}
		A_SetRoll(r, SPF_INTERPOLATE);
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
		// Hitting an ice wall will repair it:
		if (victim is 'ToM_IceWallHitBox' && victim.master)
		{
			let wall = ToM_IceWall(victim.master);
			if (wall)
			{
				wall.wallduration = Clamp(wall.wallduration + ToM_IceWall.RESTOREAMOUNT, 0, ToM_IceWall.MAXDURATION);
			}
			return MHIT_DEFAULT;
		}
		bool ret = Super.SpecialMissileHit(victim);
		if (victim.bNoIceDeath || victim.bBoss)
		{
			return MHIT_DEFAULT;
		}
		return ret;
	}

	override void HitVictim(Actor victim)
	{
		if (!victim) return;
		int dmg;
		// Bosses, Arch-Viles and +NOICEDEATH actors cannot be frozen
		// and receive *slightly* reduced damage:
		if ((victim.bNoIceDeath || victim.bBoss || victim is 'ArchVile'))
		{
			double v = 0.75;
			ToM_WhiteSmoke.Spawn(pos, 0, (frandom[smk](-v,v),frandom[smk](-v,v),frandom[smk](0.1,v)), alpha: 0.7, fade:0.06, style: STYLE_Add);
			dmg = random[icewand](2,5);
		}
		else
		{
			// The projectile deals Normal damage in order not to trigger
			// the hardcoded freezedeath effects, BUT its damage will still
			// be modified by the victim's resistance to Ice damage:
			dmg = victim.ApplyDamageFactor('Ice', random[icewand](3,5));
			if (dmg > 0)
			{
				ToM_FreezeController.AddFreeze(victim);
			}
		}
		if (dmg > 0)
		{
			victim.DamageMobj(self, target? target : Actor(self), dmg, 'Normal', DMG_THRUSTLESS|DMG_NO_PAIN);
		}
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
	protected ToM_FreezeColorLayer colorLayer;
	protected class<Actor> lastInflictor;

	Default
	{
		Powerup.Duration -1;
	}

	static void AddFreeze(Actor victim)
	{
		if (!victim || victim.bNoIceDeath || victim.bBoss) return;

		let icectrl = ToM_FreezeController(victim.FindInventory('ToM_FreezeController'));
		if (icectrl)
		{
			icectrl.EffectTics = Clamp(icectrl.EffectTics += 2, 0, MAXDURATION);
			//Console.Printf("%s freeze duration: %d", victim.GetClassName(), icectrl.EffectTics);
			if (icectrl.EffectTics % 20 == 0)
			{
				double vh = max(victim.height, victim.projectilePassHeight);
				Vector3 dpos = victim.pos + (0,0,vh*0.5);
				dpos.x += frandom[icedebris](-3,3);
				dpos.y += frandom[icedebris](-3,3);
				dpos.z += frandom[icedebris](-vh*0.35,vh*0.35);
				let deb = ToM_IceCluster(Spawn('ToM_IceCluster', dpos));
				if (deb)
				{
					deb.master = victim;
					deb.controller = icectrl;
					deb.masterOfs = level.Vec3Diff(victim.pos, deb.pos);
					deb.ic_startTime = icectrl.EffectTics;
					deb.ic_endTime = icectrl.EffectTics - TICRATE;
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
			colorLayer = ToM_FreezeColorLayer(Spawn('ToM_FreezeColorLayer', owner.pos));
			if (colorlayer)
			{
				colorlayer.master = owner;
			}
		}
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

	override void DoEffect()
	{
		Super.DoEffect();
		if (!owner) return;

		if (effectTics && owner.health > 0 && owner.curstate != slowstate)
		{
			slowstate = owner.curstate;
			owner.tics = round(owner.curstate.tics * ToM_Utils.LinearMap(effectTics, 0, MAXDURATION, 2, 4));
			if (colorLayer)
			{
				colorLayer.alpha = ToM_Utils.LinearMap(effectTics, 0, MAXDURATION, 0.0, 1.0, true);
			}
		}

		// Post-death effects:
		if (freezeDeathTics > 0 && !owner.IsFrozen())
		{
			freezeDeathTics--;
			if (owner.FindState("Pain"))
			{
				owner.SetStateLabel("Pain");
			}
			owner.A_SetTics(-1);
			//owner.freezetics = freezeDeathTics;
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
				owner.scale.x *= 1.002;
				frozenCase.scale.y = ToM_Utils.LinearMap(freezeDeathTics, 0, FREEZEDEATHTIME*0.5, 0, frozenCase.baseScale.y);
			}
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

	override void OnDestroy()
	{
		if (colorlayer)
		{
			colorLayer.Destroy();
		}
		Super.OnDestroy();
	}

	override void ModifyDamage(int damage, Name damageType, out int newdamage, bool passive, Actor inflictor, Actor source, int flags)
	{
		if (owner && passive && inflictor)
		{
			lastInflictor = inflictor.GetClass();
		}
	}

	override void OwnerDied()
	{
		// Do not apply visual freeze death effects
		// if the victim wasn't killed by Ice Wand:
		if (!owner || lastInflictor != 'ToM_IceWandProjectileReal')
		{
			Destroy();
			return;
		}

		freezeDeathTics = FREEZEDEATHTIME;
		owner.A_NoBlocking();
		owner.A_SetRenderstyle(1, Style_Normal);
		owner.A_SetTranslation('Ice');
		if (colorlayer)
		{
			colorLayer.Destroy();
		}
	}
}

class ToM_IceCluster : Actor
{
	Vector3 masterOfs;
	Powerup controller;
	int ic_startTime;
	int ic_endTime;

	Default
	{
		+NOINTERACTION
		+NOBLOCKMAP
		Height 1;
		Radius 1;
		Renderstyle 'Add';
		Alpha 0.5;
		Scale 7;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		pitch = frandom[icewall](-90, 90);
		angle = frandom[icewall](0,360);
		scale *= frandom[icewall](0.5, 1.0);
	}

	override void Tick()
	{
		Super.Tick();
		if (!master || !controller)
		{
			Destroy();
		}
		else
		{
			Warp(master, 
				masterOfs.x,
				masterOfs.y,
				masterOfs.z - (master.SpriteOffset.y - master.default.SpriteOffset.y),
				flags: WARPF_NOCHECKPOSITION|WARPF_INTERPOLATE);
			if (controller.EffectTics > 0 && controller.owner && controller.owner.health > 0)
			{
				alpha = ToM_Utils.LinearMap(controller.EffectTics, ic_startTime, ic_endTime, default.alpha, 0);
			}
		}
	}

	States {
	Spawn:
		M000 A -1 NoDelay 
		{
			frame = random[icewall](0,2);
		}
		stop;
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
			a.scale.y = max(victim.default.height, victim.projectilePassHeight);
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

class ToM_FreezeColorLayer : ToM_ActorLayer
{
	Default
	{
		Translation "Ice";
		ToM_ActorLayer.fade 0;
	}
}

class ToM_IceWall : Actor
{
	array<ToM_IceWallHitBox> hitboxes;
	const MAXDURATION = TICRATE * 8;
	const MELTDURATION = MAXDURATION / 2;
	const RESTOREAMOUNT = 4;
	const ICEWALLHEIGHT = 80.0;
	int wallduration;

	Default
	{
		Height ICEWALLHEIGHT;
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
			if (mo) mo.SetOrigin((mo.pos.xy, pos.z), false);
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
		+NOGRAVITY
		Height ToM_iceWAll.ICEWALLHEIGHT;
		Radius 10;
	}

	override void CollidedWith(Actor other, bool passive)
	{
		if (!wallready && passive && !(other is self.GetClass()))
		{
			let dir = Vec3To(other).Unit();
			other.vel = dir * radius;
		}
	}
}