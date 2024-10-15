class ToM_Teapot : ToM_BaseWeapon
{
	double heat;
	int lidframe;	
	const OPENLIDFRAME = 7;
	const RAISEDLIDFRAME = 11;
	double vaporYvel;
	double vaporScaleShift;
	bool overheated;
	
	const STEAMFRAMES = 10;
	private double prevAngle[STEAMFRAMES];
	private double prevPitch[STEAMFRAMES];
	private int steamFrame;
	private vector2 preSteamOfs;
	
	enum HeatLevels
	{
		HEAT_STEP = 25,
		HEAT_MED = 35,
		HEAT_MAX = 100,
	}
	
	Default
	{
		Tag "$TOM_WEAPON_TEAPOT";
		ToM_BaseWeapon.CheshireSound "cheshire/vo/realtea";
		ToM_BaseWeapon.LoopedAttackSound "weapons/teapot/altfire";
		Inventory.Icon "AWICTPOT";
		weapon.slotnumber 5;
		weapon.ammotype1 "ToM_MediumMana";
		weapon.ammouse1 20;
		weapon.ammogive1 100;
		+WEAPON.ALT_AMMO_OPTIONAL
	}

	override void UpdateCrosshairSpot()
	{
		let teaProjDef = GetDefaultByType('ToM_TeaProjectile');
		if (!teaProjDef) return;
		Vector3 ppos = owner.Vec3Offset(0, 0, ToM_Utils.GetPlayerAtkHeight(owner.player.mo) + 5);
		let hook = Spawn('ToM_TeapotAimHook', ppos);
		if (!hook) return;
		hook.target = owner;
		hook.A_SetSize(teaProjDef.radius, teaProjDef.height);
		hook.gravity = teaProjDef.gravity;
		// a copy of how the original projectile is launched, more or less:
		double pitchOfs = -11;
		if (owner.pitch < 0)
			pitchOfs = ToM_Utils.LinearMap(owner.pitch, 0, -90, pitchOfs, 0);
		hook.Vel3DFromAngle(teaProjDef.speed, owner.angle, owner.pitch + pitchOfs);
	}
	
	override void DoEffect()
	{
		super.DoEffect();
		if (!owner || !owner.player) return;
			
		let weap = owner.player.readyweapon;
		if (!weap) return;
		
		/*if (tom_debugmessages > 1 && weap == self)
		{
			console.midprint(smallfont, String.Format("Heat : %1.f. Overheated: %d", heat, overheated));
		}*/
		
		// Highest priority: determine overheated state,
		// doesn't matter if the owner is alive or dead,
		// using a different weapon or currently firing:
		if (heat >= HEAT_MAX)
			overheated = true;
		if (heat <= HEAT_MED)
			overheated = false;
		
		// Priority 2: stop looped sounds if owner is dead,
		// and do nothing else:
		if (owner.health <= 0)
		{
			owner.A_StopSound(CH_TPOTHEAT);
			owner.A_StopSound(CH_TPOTCHARGE);
			return;
		}
		
		// The other behavior (heat decay and sounds) is not
		// handled at all when altfiring (pushing out steam):
		let psp = owner.player.FindPSprite(PSP_WEAPON);
		if (weap == self && psp && (InStateSequence(psp.curstate, s_altfire) || InStateSequence(psp.curstate, s_althold)))
		{
			return;
		}
		
		// Priority 3: decay heat, as long as we're not altfiring,
		// regardless of which weapon is actually in use:
		if (heat > 0 && weap)
		{
			double decayRate = 0.5;
			// Decay at 50% rate if different weapon is selected:
			if (weap != self)
			{
				decayRate *= 0.5;
				heat -= decayRate;
			}
			// Otherwise decay only when not primary-firing:
			else
			{
				if (psp && !InStateSequence(psp.curstate, s_fire))
				{
					heat = Clamp(heat - decayRate, 0, HEAT_MAX);
				}
			}
		}
		
		// Finally, handle looped heat sounds, regardless of
		// currently used weapon:
		
		// "Strong" overheat sound:
		if (heat >= HEAT_MAX)
		{
			owner.A_StartSound("weapons/teapot/highheat", CH_TPOTCHARGE, CHANF_LOOPING);
		}
		
		// "Medium" overheat sound:
		if (heat >= HEAT_MED)
		{
			// Do not play over the "strong" one:
			if (!owner.IsActorPlayingSound(CH_TPOTCHARGE))
			{
				owner.A_StartSound("weapons/teapot/heatloop", CH_TPOTHEAT, CHANF_LOOPING);
			}
			
			// define volume based on heat level:
			double heatvol = ToM_Utils.LinearMap(heat, HEAT_MED, HEAT_MAX, 0, 1.0);
			double chargevol = ToM_Utils.LinearMap(heat, HEAT_MED, HEAT_MAX, 0, 1.0);
			
			// Reduce by 50% if a different weapon is selected:
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
		// If heat is under HEAT_MED value, stop 
		// the sounds:
		else
		{
			owner.A_StopSound(CH_TPOTHEAT);
			owner.A_StopSound(CH_TPOTCHARGE);
		}
	}
	
	override void OnDeselect(Actor dropper)
	{
		super.OnDeselect(dropper);
		if (dropper)
		{
			dropper.A_StopSound(CH_TPOTHEAT);
			dropper.A_StopSound(CH_TPOTCHARGE);
		}
	}
	
	action state A_PickReady()
	{
		if (!player)
			return ResolveState(null);
			
		let heat = invoker.heat;
		if (heat >= HEAT_MAX || invoker.overheated)
		{
			A_StartSound("weapons/teapot/heatloop", CH_TPOTHEAT, CHANF_LOOPING);
			return ResolveState("ReadyOverHeat");
		}
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
	
	action void A_TeapotReady(int flags = WRF_NOSECONDARY)
	{
		A_ClearRefire();
		if (invoker.heat >= HEAT_MAX)
		{
			flags |= WRF_NOPRIMARY;
		}
		if (invoker.heat >= HEAT_MED)
		{	
			flags &= ~WRF_NOSECONDARY;
		}
		A_ResetZoom();
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
	
	action void A_FireSteam()
	{
		A_Fire3DProjectile("ToM_SteamProjectile", forward: 64, leftright:16, updown:-20);
		invoker.heat = Clamp(invoker.heat - 0.8, 0, HEAT_MAX);
		double pp = ToM_Utils.LinearMap(invoker.heat, 0, HEAT_MAX, 1, 1.2);
		double vol = ToM_Utils.LinearMap(invoker.heat, 0, HEAT_MAX, 0.25, 0.75);
		A_StartSound(invoker.loopedAttackSound, CHAN_WEAPON, CHANF_LOOPING);
		A_SoundPitch(CHAN_WEAPON, pp);
		A_SoundVolume(CHAN_WEAPON, vol);
		int freq = int(ToM_Utils.LinearMap(invoker.heat, 0, HEAT_MAX, 5, 1, true));
	}
	
	static const int lidframes[] = { 2, 11, 12, 13 };
	action void A_JitterLid()
	{
		int i = invoker.lidframe;
		while (invoker.lidframe == i)
		{
			int i = random[boil](0, invoker.lidframes.Size() - 1);
			invoker.lidframe = invoker.lidframes[i];
		}
		let psp = player.FindPSprite(OverlayID());
		if (psp)
		{
			psp.frame = invoker.lidframe;
			if (psp.frame == RAISEDLIDFRAME)
			{
				A_SpawnPSParticle("Vapor", bottom: true, xofs: 7, yofs: 7, chance: 80);
			}
		}
	}
	
	States
	{
	/*Spawn:
		ALTP A -1;
		stop;*/
	Select:
		TPOT C 0 
		{
			if (invoker.overheated)
			{
				let psp = player.FindPSprite(OverlayID());
				if (psp)
					psp.frame = OPENLIDFRAME;
			}
			A_SetSelectPosition(-48, 110+WEAPONTOP);
			A_OverlayPivot(OverlayID(), 0.6, 0.8);
			A_OverlayRotate(OverlayID(), 40);
		}
		#### ######## 1
		{
			A_WeaponOffset(6, -13.75, WOF_ADD);
			A_OverlayRotate(OverlayID(), -5, WOF_ADD);
			A_WeaponReady(WRF_NOFIRE|WRF_NOBOB);
		}
		TNT1 A 0
		{
			if (invoker.overheated)
				return ResolveState("ReadyOverHeatLoop");
			return ResolveState(null);
		}
		goto Ready;
	Deselect:
		TPOT C 0 
		{
			if (invoker.overheated)
			{
				let psp = player.FindPSprite(OverlayID());
				if (psp)
					psp.frame = OPENLIDFRAME;
				let tip = player.FindPSprite(APSP_BottomParticle-1);
				if (tip)
					tip.Destroy();
			}
			A_ResetZoom(0);
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
		TPOT A 1
		{
			A_TeapotReady();
			A_SetTics(int(ToM_Utils.LinearMap(invoker.heat, HEAT_MED, HEAT_MAX, 4, 2)));
			A_JitterLid();
		}
		TNT1 A 1 A_PickReady;
		wait;
	ReadyOverHeat:
		TPOT BA 3;
	ReadyOverHeatLoop:
		TPOH A 3
		{
			A_TeapotReady(WRF_NOPRIMARY);
			A_SpawnPSParticle("Vapor", bottom: true, xofs: 9, yofs: 9);
			if (!invoker.overheated)
			{
				return ResolveState("ReadyOverHeatEnd");
			}
			// Draw the teapot's nose just below the vapor:
			A_Overlay(APSP_BottomParticle-1, "ReadyOverHeatTip");
			return ResolveState(null);
		}
		loop;
	ReadyOverHeatTip:
		TPOH B 3;
		stop;
	ReadyOverHeatEnd:
		TNT1 A 0 A_StartSound("weapons/teapot/close", CHAN_AUTO);
		TPOT AB 4;
		TNT1 A 1 A_PickReady;
		wait;
	Fire:
		TNT1 A 0 
		{
			A_TeapotFire();
			A_PlayerAttackAnim(35, 'attack_teapot', 20);
		}
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
		TPOT IIKKAABBCC 1 A_ResetZoom();
		goto Ready;
	FireEndHeat:
		TNT1 A 0 
		{
			A_ResetPSprite(OverlayID(), 10);
			//invoker.overheated = true;
		}
		TPOT IIKKJJJJJJ 1 A_ResetZoom();
		goto ReadyOverHeatLoop;
	Vapor:
		TNT1 A 0
		{
			let psp = player.FindPSprite(OverlayID());
			if (psp)
			{
				A_OverlayFlags(OverlayID(), PSPF_AddWeapon, false);
				A_PSPMakeTranslucent(OverlayID(), 0.6);
				A_OverlayPivotAlign(OverlayID(),PSPA_CENTER,PSPA_CENTER);
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
				if (psp.alpha <= 0)
					return ResolveState("Null");
				psp.y += invoker.vaporYvel;
				psp.scale *= invoker.vaporScaleShift;
				invoker.vaporYvel *= 0.92;
			}
			return ResolveState(null);
		}
		stop;
	AltFire:
		TNT1 A 0 A_JumpIf(invoker.overheated == false, "AltFireDo");
		TNT1 A 0 A_StartSound("weapons/teapot/close", CHAN_AUTO);
		TPOT AB 2;
	AltFireDo:
		TPOT OOPP 1 
		{
			A_WeaponOffset(-7, 4, WOF_ADD);
			A_ScalePSprite(OverlayID(), -0.02, -0.02, WOF_ADD);
		}
		TNT1 A 0 
		{
			A_StopSound(CH_TPOTCHARGE);
			A_StopSound(CH_TPOTHEAT);
			A_StartSound("weapons/teapot/charge", CHAN_7);
			let psp = Player.FindPSprite(OverlayID());
			invoker.preSteamOfs = (psp.x, psp.y);
		}
	AltHold:
		TPOT P 1
		{
			if (invoker.heat <= 0)
			{
				return ResolveState("AltFireEnd");
			}
			A_PlayerAttackAnim(-1, 'attack_teapot', 10, endFrame:2, flags:SAF_LOOP|SAF_NOOVERRIDE);
			
			let psp = Player.FindPSprite(OverlayID());
			A_FireSteam();
			
			int steamfr = Clamp( ToM_Utils.LinearMap(invoker.heat, 0, HEAT_MAX, 4, 1), 1, 4);
			if (GetAge() % steamfr == 0)
			{
				A_WeaponOffset(invoker.preSteamOfs.x + frandom(-0.5,0.5), invoker.preSteamOfs.y + frandom(0,1), WOF_INTERPOLATE);
				invoker.steamFrame++;
				if (invoker.steamFrame >= STEAMFRAMES)
					invoker.steamFrame = 0;
				A_Overlay(APSP_BottomParticle + invoker.steamFrame, "SteamOverlay");
			}
			return ResolveState(null);
		}
		TNT1 A 0 A_ReFire();
	AltFireEnd:
		TNT1 A 0 
		{
			A_StartSound("weapons/teapot/discharge", CHAN_WEAPON, volume: 0.4);
			A_ResetPSprite(OverlayID(), 6);
			A_PlayerAttackAnim(1, 'attack_teapot', 0);
		}
		TPOT PO 3;
		TNT1 A 0 A_PickReady();
		wait;
	SteamOverlay:
		TPSM A 0
		{
			A_PSPMakeTranslucent();
			A_OverlayFlags(OverlayID(), PSPF_AddWeapon|PSPF_AddBob, false);
			A_OverlayPivotAlign(OverlayID(),PSPA_CENTER,PSPA_CENTER);
			A_OverlayRotate(OverlayID(), frandom[tsfx](0, 359));
			A_OverlayOffset(OverlayID(), -16, 14);
			invoker.prevAngle[invoker.steamFrame] = angle;
			invoker.prevPitch[invoker.steamFrame] = pitch;
			let psp = player.FindPSprite(OverlayID());
			if (psp)
			{
				psp.frame = random[tsfx](0, 5);
			}
		}
		TPSM # 1
		{
			A_OverlayRotate(OverlayID(), 4, WOF_ADD);
			A_OverlayScale(OverlayID(), 0.085, 0.08, WOF_ADD);
			A_OverlayOffset(OverlayID(),-5 - (invoker.prevAngle[invoker.steamFrame] - angle),-5 + (invoker.prevPitch[invoker.steamFrame] - pitch),WOF_ADD);
			invoker.prevAngle[invoker.steamFrame] = angle;
			invoker.prevPitch[invoker.steamFrame] = pitch;
			A_PSPFadeOut(0.2);
		}
		wait;
	}
}

class ToM_TeaBurnControl : ToM_BurnController 
{
	ToM_ActorLayer burnlayer;
	
	Default
	{
		ToM_ControlToken.duration 175;
		ToM_ControlToken.EffectFrequency 4;
		Alpha 0.7;
	}
	
	override void InitController()
	{
		ResetTimer();
		if (!burnlayer)
			burnlayer = ToM_ActorLayer(Spawn("ToM_TeaBurnLayer", owner.pos));

		if (burnlayer)
		{
			burnlayer.bISMONSTER = owner.bISMONSTER;
			burnlayer.master = owner;
			burnlayer.fade = 0;
		}
	}

	override color GetFlameColor()
	{
		return 0x24e23f;
	}

	override TextureID GetFlameTexture()
	{
		return TexMan.CheckForTexture(ToM_BaseActor.GetRandomWhiteSmoke());
	}
	
	override void DoEffect() 
	{
		super.DoEffect();

		if (self && owner && target && (timer % TICRATE == 0))
		{
			int fl = (random[tsfx](1,3) == 1) ? 0 : DMG_NO_PAIN;
			owner.DamageMobj(self, target, 4, "Normal", flags:DMG_THRUSTLESS|fl);
		}
	}
	
	override void EndController() 
	{
		if (burnlayer)
		{
			burnlayer.fade = burnlayer.default.fade;
		}
	}
}

class ToM_TeaBurnLayer : ToM_ActorLayer
{
	Default
	{
		Translation "ToM_GreenTea";
		ToM_ActorLayer.Fade 0.075;
	}
}

class ToM_TeapotAimHook : Actor
{
	Default
	{
		+NOBLOCKMAP
	}

	override void Tick()
	{
		while (self && !self.bDestroyed)
		{
			A_FaceMovementDirection();
			Vector3 nextpos = Vec3Offset(vel.x, vel.y, vel.z);
			FCheckPosition checkpos;
			if (!TryMove(nextpos.xy, 0, true, tm: checkpos) || !level.IsPointInLevel(nextpos) || !TestMobjLocation())
			{
				SecPlane plane;
				Line hitline;
				/*String report;
				// Try detecting the line/plane this collided with
				// with a linetrace first:
				FLineTraceData tr;
				LineTrace(angle, vel.Length () + radius * 2, pitch, data: tr);
				switch (tr.HitType)
				{
				case TRACE_HitWall:
					hitline = tr.hitline;
					report = "a wall";
					break;
				case TRACE_HitFloor:
					if (tr.Hit3DFloor)
					{
						plane = tr.hitsector.ceilingplane;
						report = "a 3D floor top";
					}
					else
					{
						plane = tr.hitsector.floorplane;
						report = "a regular floor";
					}
					break;
				case TRACE_HitCeiling:
					if (tr.Hit3DFloor)
					{
						plane = tr.hitsector.floorplane;
						report = "a 3D floor bottom";
					}
					else
					{
						plane = tr.hitsector.ceilingplane;
						report = "a regular ceiling";
					}
					break;
				// If that didn't work, try reading relevant data
				// off the actor:
				default:
					hitline = checkpos.ceilingline? checkpos.ceilingline : blockingline;
					if (!hitline)
					{
						if (blockingFloor)
						{
							plane = blockingFloor.floorplane;
							report = "a blockingFloor";
						}
						else if (blockingCeiling)
						{
							plane = blockingceiling.ceilingplane;
							report = "a blockingCeiling";
						}
					}
					else
					{
						report = checkpos.ceilingline? "a FCheckPosition ceilingline" : "a blockingline";
					}
					break;
				}
				ToM_DebugMessage.Print(String.Format("Teapot Aim Hook hit %s", report));
				if (tom_debugobjects)
				{
					ToM_DebugSpot.Spawn(pos, 0.2, 2);
				}*/
				HookDie(hitline, plane);
				Destroy();
				return;
			}
			SetZ(pos.z + vel.z);
			vel.z -= GetGravity();
		}
	}

	void HookDie(Line hitline = null, SecPlane hitplane = null)
	{
		let alice = ToM_AlicePlayer(target);
		if (target)
		{
			let spot = alice.GetCrosshairSpot();
			if (spot)
			{
				Vector3 dir = (0,0,1);
				/*if (hitline)
				{
					dir.xy = ToM_Utils.GetLineNormal(pos.xy, hitline);
					dir.z = 0.1;
				}
				else if (hitplane)
				{
					dir = hitplane.normal;
				}*/
				spot.Update(ToM_CrosshairSpot.CMODE_AoE, newRadius: 64, newPos: pos, newDir: dir);
			}
		}
	}
}
	
class ToM_TeaProjectile : ToM_Projectile
{
	Default
	{
		ToM_Projectile.trailcolor "32a856";
		ToM_Projectile.trailtexture "LENYA0";
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
		Decal "TeapotScorchBurn";
	}
	
	States
	{
	Spawn:
		TGLO ABCDEFGHIJ 2
		{
			if (GetAge() > 8)
			{
				FSpawnParticleParams smoke;
				smoke.pos = pos;
				smoke.color1 = "";
				smoke.texture = TexMan.CheckForTexture(ToM_BaseActor.GetRandomWhiteSmoke());
				smoke.vel = (frandom[tpotsmk](-0.2,0.2),frandom[tpotsmk](-0.2,0.2),frandom[tpotsmk](-0.2,0.2));
				smoke.size = TexMan.GetSize(smoke.texture) * 0.15;
				smoke.flags = SPF_ROLL|SPF_REPLACE;
				smoke.lifetime = 35;
				smoke.sizestep = smoke.size * 0.03;
				smoke.startalpha = 0.4;
				smoke.fadestep = -1;
				smoke.startroll = random[sfx](0, 359);
				smoke.rollvel = frandom[sfx](0.5,1) * randompick[sfx](-1,1);
				Level.SpawnParticle(smoke);
			}
		}
		loop;
	Death:
		TNT1 A 1
		{
			A_SetScale(1);
			bNOGRAVITY = true;
			A_Explode(160, 140);
			
			ToM_SphereFX.SpawnExplosion(pos, size: 42, alpha: 0.5, col1: "32a856", boomfactor: 2);
			
			double fz = CurSector.floorplane.ZAtPoint(pos.xy);
			bool onFloor = (pos.z <= fz + 32 && waterlevel <= 0);
			if (onFloor && (!CheckLandingSize(32) || !(CurSector.FloorPlane.Normal == (0,0,1))))
				Spawn("ToM_TeaPool", (pos.x,pos.y, fz+0.5));
				
			for (int i = 4; i > 0; i--)
			{
				ToM_WhiteSmoke.Spawn(
					pos + (frandom[tpotsmk](-6,6),frandom[tpotsmk](-6,6),frandom[tpotsmk](10,16)), 
					vel: (frandom[tpotsmk](-0.2,0.2),frandom[tpotsmk](-0.2,0.2),frandom[tpotsmk](1,2)),
					scale: 0.5,
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
		+BRIGHT
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
		+BRIGHT
		Renderstyle 'Translucent';
		scale 3.4;
	}
	
	override void PostBeginPlay() 
	{
		super.PostBeginPlay();
		wscale = 0.05;
		ToM_Utils.AlignToPlane(self);
	}
	
	States
	{
	Spawn:
		M000 A 1 
		{
			A_FadeOut(0.012);
			scale *= (1 + wscale);
			wscale *= 0.95;
			if (alpha > 0.15)
			{
				ToM_WhiteSmoke.Spawn(
					pos + (frandom[wsmoke](-56,56),frandom[wsmoke](-56,56), 5), 
					vel: (0, 0, frandom[wsmoke](0.5, 1)),
					scale: frandom[wsmoke](0.08, 0.12),
					alpha: alpha,
					fade: 0.01
				);
			}
		}
		wait;
	}
}

class ToM_SteamProjectile : ToM_PiercingProjectile
{
	Default
	{
		speed 12;
		radius 16;
		height 22;
		renderstyle 'Translucent';
		alpha 0.5;
		scale 0.1;
	}
	
	override bool CheckValid(Actor victim)
	{
		return (!target || victim != target) && (victim.bSHOOTABLE || victim.bVULNERABLE) && victim.health > 0;
	}
	
	override int HitVictim(actor victim)
	{
		if (target && victim && !victim.bDontThrust)
		{
			let dir = level.Vec3Diff(pos, level.Vec3Offset(pos, vel)).Unit();
			let fac = ToM_Utils.LinearMap(victim.mass, 100, 1000, 2, 1);
			victim.vel = vel.length() * dir * fac;
			victim.target = null;
			victim.angle += random[teaposteam](20,30);
			if (!victim.bFLOAT)
				victim.vel.z += 3;
		}
		return 0;
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
		roll += wrot;
		wrot *= 0.95;
		scale *= 1.07;
		vel *= 0.93;
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