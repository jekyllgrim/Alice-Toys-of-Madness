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
		AICW A 4 A_ResetPSprite(OverlayID(), 4);
		goto ready;
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

	override bool CheckValid(Actor victim)
	{
		return (!target || victim != target) && victim.bSHOOTABLE && !victim.bNonShootable && victim.health > 0;
	}

	override void HitVictim(Actor victim)
	{
		if (!victim.bNoIceDeath && !victim.bBoss)
		{
			let iceman = ToM_FreezeController(victim.FindInventory('ToM_FreezeController'));
			if (iceman)
			{
				iceman.EffectTics += TICRATE;
			}
			else
			{
				victim.GiveInventory('ToM_FreezeController', 1);
			}
		}
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
	int freezeDeathTics;
	Vector2 ownerSpriteOffset;
	ToM_FrozenCase frozenCase;

	Default
	{
		Powerup.Duration -1;
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
		Renderstyle 'Translucent';
		Alpha 0.5;
	}

	static ToM_FrozenCase SpawnCase(Actor victim)
	{
		let a = ToM_FrozenCase(Spawn('ToM_FrozenCase', victim.pos));
		if (a)
		{
			a.A_StartSound("weapons/icewand/flesh");
			a.master = victim;
			a.scale.x = victim.radius*2;
			a.scale.y = victim.default.height + Clamp(victim.projectilePassHeight, 0, 128);
			a.basescale = a.scale;
			a.zofs = frandom[frozencase](0.01, 0.10);
			a.angle = frandom[frozencase](0, 360);
		}
		return a;
	}
	
	override void Tick()
	{
		if (!master)
		{
			A_FadeOut(0.01);
			scale.x *= 1.004;
		}
		else
		{
			SetOrigin(master.pos + (0,0,zofs), true);
			alpha = ToM_Utils.LinearMap(scale.y, 0, basescale.y, 1.0, default.alpha);
		}
	}

	states {
	Spawn:
		M000 A -1;
		stop;
	}
}