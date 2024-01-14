class ToM_RageBox : Actor replaces Berserk
{
	vector3 smokedir;
	protected Actor flare;
	protected bool used;

	Default
	{
		+BUMPSPECIAL
		+SOLID
		+SPECIAL
		+NOTIMEFREEZE
		Activation THINGSPEC_Activate|THINGSPEC_ThingTargets;
		height 32;
		scale 0.7;
	}
	
	void SpawnRageSmoke()
	{
		if (target && target.player)
		{
			let diff = LevelLocals.Vec3Diff(pos + (0,0,24), target.pos + (0,0, ToM_UtilsP.GetPlayerAtkHeight(target.player.mo)));
			smokedir = diff.unit();
			
			ToM_WhiteSmoke.Spawn(
				pos + (0,0, 24),
				vel: smokedir * 5,
				scale: 0.1,
				alpha: 1,
				fade: 0.1,
				dbrake: 0.94,
				dscale: 1.025,
				style: STYLE_Shaded,
				shade: "a80a0a",
				flags: SPF_NOTIMEFREEZE
			);
		}
	}
	
	override bool CanCollideWith(Actor other, bool passive)
	{
		if (used)
			return true;
	
		if (passive && other && other.player)
			return true;
		
		return false;
	}
	
	override void Activate(Actor activator)
	{
		if (!activator || !activator.player)
			return;
			
		used = true;
		A_StartSound("ragebox/activate", startTime: 0.5);
		if (!activator.CountInv("ToM_RageBoxInitEffect") && !activator.CountInv("ToM_RageBoxMainEffect"))
		{
			let knife = ToM_Knife(activator.FindInventory("ToM_Knife"));
			if (knife)
			{
				activator.A_Stop();
				activator.angle = activator.AngleTo(self);
				activator.pitch = 0;
				activator.GiveInventory("ToM_RageBoxInitEffect", 1);
				activator.player.readyweapon = null;
				activator.player.pendingweapon = knife;
				activator.A_StartSound("ragebox/scream", CHAN_AUTO);
			}
		}
		
		else if (activator.CountInv("ToM_RageBoxMainEffect"))
			activator.GiveInventory("ToM_RageBoxMainEffect", 1);
		
		if (flare)
			flare.Destroy();
		A_RemoveLight('rageBoxLight');
		SetStateLabel("Active");
	}
	
	override void PostbeginPlay()
	{
		super.PostbeginPlay();
		double hpos = 25;
		flare = ToM_BaseFlare.Spawn(pos + (0,0,hpos), scale: 0.3, alpha: 0.45, col: "FF0000");
		A_AttachLight('rageBoxLight', DynamicLight.PointLight, "cc0000", 48, 0, flags: DYNAMICLIGHT.LF_ATTENUATE, ofs: (0,0, hpos));
	}
	
	States
	{
	Spawn:
		M000 A -1;
		stop;
	Active:
		M000 AAAAAAAAAA 2 
		{
			SpawnRageSmoke();
			if (target)
			{
				if  (!target.CountInv("ToM_RageBoxInitEffect") && !target.CountInv("ToM_RageBoxMainEffect"))
					target.A_SetBlend("a80a0a", 0.75, 250);
				else
					target.A_SetBlend("a80a0a", 0.35, 100);
			}
		}
		M000 AAAAAAAAAAAAAAAAAAAAA 2 SpawnRageSmoke();
		TNT1 A 0 A_SetRenderstyle(1, Style_Translucent);
		M000 B 1 A_FadeOut(0.05);
		wait;
	}
}

class ToM_RageBoxInitEffect : Powerup
{
	Default
	{
		Powerup.duration -5;
	}
	
	override void InitEffect()
	{
		if (owner && owner.player)
		{
			owner.player.cheats |= CF_TOTALLYFROZEN|CF_GODMODE;
			level.SetFrozen(true);
		}
		super.InitEffect();
	}
	
	
	override void EndEffect()
	{
		if (owner && owner.player)
		{
			owner.player.cheats &= ~(CF_TOTALLYFROZEN|CF_GODMODE);
			level.SetFrozen(false);
			owner.GiveInventory("ToM_RageBoxMainEffect", 1);
		}
		super.EndEffect();
	}
}

class ToM_RageBoxMainEffect : PowerRegeneration 
{
	const PROTFACTOR = 0.15;
	const DMGFACTOR = 4;

	Default
	{
		Powerup.Duration -30;
		Powerup.Strength 5;
		Powerup.Color "FF0000", 0.12;
	}
	
	override void InitEffect()
	{
		Super.InitEffect();
		owner.bNOPAIN = true;
	}

	override void ModifyDamage(int damage, Name damageType, out int newdamage, bool passive, Actor inflictor, Actor source, int flags)
	{
		if (damage > 0)
		{
			if (passive)
			{
				newdamage = max(0, ApplyDamageFactors(GetClass(), damageType, damage, int(damage  * PROTFACTOR)));
			}
			else
			{
				newdamage = max(1, ApplyDamageFactors(GetClass(), damageType, damage, damage * DMGFACTOR));
				if (owner && newdamage > damage) 
					owner.A_StartSound(ActiveSound, CHAN_AUTO, CHANF_DEFAULT, 1.0, ATTN_NONE);
			}
		}
	}
}

class ToM_GrowthPotion : PowerupGiver
{
	Default
	{
		Powerup.Type "ToM_GrowthPotionEffect";
		Powerup.Duration -30;
		Inventory.Pickupmessage "Growth potion!";
		+INVENTORY.AUTOACTIVATE
	}
	
	States
	{
	Spawn:
		APOT Z -1;
		stop;
	}
}

class ToM_GrowthPotionEffect : PowerInvulnerable
{
	bool finishEffect;

	protected double prevHeight;
	protected vector2 prevScale;
	protected double prevSpeed;
	protected double prevViewHeight;
	protected double prevAttackZOffset;
	protected vector2 prevWeaponScale;
	protected double prevZoom;
	protected double prevViewBobSpeed;
	
	protected double targetSpeed;
	protected double targetHeight;
	protected double targetViewHeight;
	protected double targetAttackZOffset;
	protected vector2 targetScale;
	protected vector2 targetWeaponScale;
	protected vector2 curWeaponScale;
	
	protected double viewHeightStep;
	protected double attackZOffsetStep;
	protected vector2 scaleStep;
	protected vector2 weaponScaleStep;
	
	protected double zoomStep;
	protected double targetZoom;
	
	protected int stepCycle;
	
	const GROWFACTOR = 1.5;
	const GROWWEAPON = 1.2;
	const VIEWFACTOR = 2.0;
	const SPEEDFACTOR = 0.5;
	const GROWTIME = 50;
	const GROWZOOM = 1.2;
	
	Default
	{
		Powerup.duration -40;
		Inventory.Icon "APOTZ0";
	}

	override void InitEffect()
	{
		Super.InitEffect();
		if (!owner || !owner.player)
		{
			Destroy();
			return;
		}
		finishEffect = false;

		prevViewBobSpeed = owner.player.mo.ViewBobSpeed;
		owner.player.mo.ViewBobSpeed *= VIEWFACTOR;

		let weap = owner.player.readyweapon;
		if (weap)
		{
			let dweap = GetDefaultByType(weap.GetClass());
			prevWeaponScale = (dweap.WeaponScaleX, dweap.WeaponScaleY);
			curWeaponScale = prevWeaponScale;
		}
	
		// record current values:
		prevHeight = owner.height;
		prevScale = owner.scale;
		prevSpeed = owner.speed;
		prevViewHeight = owner.player.viewHeight;
		prevAttackZOffset = owner.player.mo.AttackZOffset;
		
		// target height (to be set in DoEffect):
		targetHeight = prevHeight;//prevHeight * GROWFACTOR;
		
		// target scale and scale step (to be set in DoEffect):
		targetScale = prevScale * GROWWEAPON;
		scaleStep.x = (targetScale.x - prevScale.x) / GROWTIME;
		scaleStep.y = (targetScale.y - prevScale.y) / GROWTIME;
		
		// target weapon scale and weapon scale step:
		if (weap)
		{
			targetweaponScale = prevweaponScale * GROWFACTOR;
			weaponScaleStep.x = (targetweaponScale.x - prevweaponScale.x) / GROWTIME;
			weaponScaleStep.y = (targetweaponScale.y - prevweaponScale.y) / GROWTIME;
		}
		
		// target viewheight and viewheight step (to be set in DoEffect):
		targetViewHeight = prevViewHeight * VIEWFACTOR;
		viewHeightStep = (targetViewHeight - prevViewHeight) / GROWTIME;

		// target AttackZOffset and AttackZOffset step (to be set in DoEffect):
		targetAttackZOffset = targetViewHeight - (prevViewHeight - prevAttackZOffset - prevHeight*0.5) - targetHeight*0.5;
		attackZOffsetStep = (targetAttackZOffset - prevAttackZOffset) / GROWTIME;
		
		// zoom step:
		prevZoom = owner.player.fov;
		targetZoom = prevZoom * GROWZOOM;
		zoomStep = (targetZoom - prevZoom) / GROWTIME;
		
		// speed is modified instantly:
		owner.speed *= SPEEDFACTOR;
		
		if (tom_debugmessages)
		{
			console.printf(
				"Growth potion initialized:\n"
				"View height: \cD%.1f\c- | step: \cD%.1f\c- | target: \cD%.1f\c-\n"
				"AttackZOffset: \cD%.1f\c- | step: \cD%.1f\c- | target: \cD%.1f\c-",
				prevViewHeight, viewHeightStep, targetViewHeight,
				prevAttackZOffset, attackZOffsetStep, targetAttackZOffset
			);
		}
	}

	override void Tick()
	{
		if (!owner || !owner.player)
		{
			Destroy();
			return;
		}

		if (!finishEffect && (EffectTics == 0 || (EffectTics > 0 && --EffectTics == 0)))
		{
			finishEffect = true;
		}
	}
	
	override void DoEffect()
	{
		super.DoEffect();
		if (!owner || !owner.player || owner.isFrozen())
			return;
		
		let pmo = PlayerPawn(owner);
		let player = owner.player;
		let weap = owner.player.readyweapon;
		
		double stepFactor = finishEffect ? -2 : 1;
		
		// gradually modify viewheight:
		player.viewHeight = Clamp(
			player.viewHeight + viewHeightStep * stepFactor,
			prevViewHeight, targetViewHeight
		);
		pmo.viewHeight = Clamp(
			pmo.viewHeight + viewHeightStep * stepFactor,
			prevViewHeight, targetViewHeight
		);

		pmo.AttackZOffset = Clamp(
			pmo.AttackZOffset + attackZOffsetStep * stepFactor,
			prevAttackZOffset, targetAttackZOffset
		);
		
		//console.printf("attackZOffset: %.2f | viewheight: %.2f", pmo.attackZOffset, player.viewHeight);
	
		// gradually modify zoom:
		owner.player.desiredFov = Clamp(
			owner.player.fov + zoomStep * stepFactor,
			1, 
			targetZoom
		);
		//console.printf("player fov: %.1f desired: %.1f", owner.player.fov, owner.player.desiredfov);
		
		// gradually modify weapon scale:
		for(PSprite psp = player.psprites; psp; psp = psp.Next)
		{
			if (psp)
			{
				curWeaponScale.x = Clamp(
					curWeaponScale.x + weaponScaleStep.x * stepFactor, 
					prevWeaponScale.x, 
					targetWeaponScale.x
				);
				curWeaponScale.y = Clamp(
					curWeaponScale.y + weaponScaleStep.y * stepFactor, 
					prevWeaponScale.y, 
					targetWeaponScale.y
				);
				psp.baseScale = curWeaponScale;
			}
		}
		
		// gradually modify scale:
		pmo.scale.x = Clamp(
			pmo.scale.x + scaleStep.x * stepFactor,
			prevScale.x, targetScale.x
		);
		pmo.scale.y = Clamp(
			pmo.scale.y + scaleStep.y * stepFactor,
			prevScale.y, targetScale.y
		);
		
		// keep trying to instantly change size:
		//if (pmo.height < targetHeight)
			//pmo.A_SetSize(pmo.radius, targetHeight, true);
		
		// Walking:
		if (!finishEffect)
		{
			if (pmo.player.onground && pmo.Vel.Length() > 4) 
			{
				stepCycle++;
				if (stepCycle % 20 == 0) {
					//do the damage:
					int atkdist = 256;
					BlockThingsIterator itr = BlockThingsIterator.Create(pmo,atkdist);
					while (itr.next()) {
						let next = itr.thing;
						if (!next || next == pmo)
							continue;
						bool isValid = (next.bSHOOTABLE && (next.bIsMonster ||next.player) && next.health > 0);
						if (!isValid)
							continue;
						double zdiff = abs(pmo.pos.z - next.pos.z);
						if (zdiff > 32)
							continue;
						double dist = pmo.Distance3D(next);
						if (dist > atkdist)
							continue;
						next.DamageMobj(pmo,pmo,15,'normal',DMG_THRUSTLESS|DMG_NO_FACTOR);
						next.vel.z += 4;
					}
					pmo.A_Quake(2,5,0,atkdist,"");
					pmo.A_StartSound("growpotion/giantstep", CHAN_AUTO);
				}
			}
			else
				stepCycle = 0;
		}
		
		else if (player.viewHeight <= prevViewHeight)
		{
			owner.player.mo.ViewBobSpeed = prevViewBobSpeed;
			player.viewHeight = prevViewHeight;
			pmo.viewHeight = prevViewHeight;
			//pmo.A_SetSize(pmo.radius, prevHeight);
			pmo.scale = prevScale;
			owner.player.desiredFov = prevZoom;
			for(PSprite psp = player.psprites; psp; psp = psp.Next)
			{
				if (psp)
				{
					psp.baseScale = prevWeaponScale;
				}
			}
			pmo.speed = prevSpeed;
			Destroy();
		}
	}
}

class ToM_Invisibility : PowerupGiver
{
	Default
	{
		Inventory.pickupmessage "Looking-glass mirror";
		Powerup.Type "ToM_InvisibilityEffect";
		Powerup.Duration -40;
		scale 0.25;
		+FLOATBOB
		+INVENTORY.AUTOACTIVATE
	}
	
	States
	{
	Spawn:
		LGMY ABCDEFGHIJKLMN 2;
		loop;
	}
}

class ToM_InvisibilityEffect : Powerup
{
	bool active;
	ToM_Mainhandler handler;
	Actor soundtarget;
	int sndTargetLifeTime;
	const MAXSNDTARGETLIFETIME = 35 * 6;
	const SNDTARGETALPHA = 0.4;

	protected double prevAlpha;
	protected int prevRenderstyle;
	
	Default
	{
		Powerup.duration -40;
		Inventory.Icon "LGMYA0";
	}

	void SpawnSoundTarget()
	{
		if (!owner || owner.health <= 0)
			return;

		sndTargetLifeTime = 0;
		if (soundtarget)
		{
			soundtarget.SetOrigin(owner.pos, true);
			soundtarget.angle = owner.angle;
			soundtarget.alpha = SNDTARGETALPHA;
			//ToM_BaseActor.CopyAppearance(soundtarget, owner, false);
		}

		else 
		{
			soundtarget = Actor.Spawn("ToM_PlayerSoundTarget", owner.pos);
			/*if (soundtarget)
			{
				soundtarget.bNOINTERACTION = true;
				soundtarget.bISMONSTER = true;
				soundtarget.bFRIENDLY = true;
				soundtarget.bNODAMAGE = true;
				soundtarget.bNOBLOOD = true;
				soundtarget.bNONSHOOTABLE = true;
				soundtarget.A_SetRenderstyle(SNDTARGETALPHA, STYLE_Shaded);
				soundtarget.SetShade("FFFFFF");
				//ToM_BaseActor.CopyAppearance(soundtarget, owner, false);
				soundtarget.tics = -1;
			}*/
		}
	}

	override void Activate(Actor activator)
	{
		SpawnSoundTarget();
		active = true;
	}

	void UpdateSoundTarget()
	{
		if (soundtarget && !soundtarget.isFrozen())
		{
			sndTargetLifeTime++;
			soundtarget.A_FadeOut(SNDTARGETALPHA / MAXSNDTARGETLIFETIME);
			//soundtarget.scale.x -= soundtarget.default.scale.x / MAXSNDTARGETLIFETIME * 0.5;
			//soundtarget.scale.y -= soundtarget.default.scale.y / MAXSNDTARGETLIFETIME * 0.5;
			if (soundtarget && sndTargetLifeTime >= MAXSNDTARGETLIFETIME)
			{
				soundtarget.Destroy();
				sndTargetLifeTime = 0;
			}
		}
	}
	
	override void InitEffect()
	{
		if (owner && owner.player)
		{
			prevAlpha = owner.alpha;
			prevRenderstyle = owner.GetRenderstyle();
			
			owner.GiveInventory("ToM_InvisibilitySelector", 1);
			let invs = ToM_InvisibilitySelector(owner.FindInventory("ToM_InvisibilitySelector"));
			if (invs)
			{
				invs.prevWeapon = owner.player.readyweapon;
				owner.player.pendingweapon = invs;
			}

			/*let ti = ThinkerIterator.Create("Actor");
			Actor mo;
			while (mo = Actor(ti.Next()))
			{
				if (mo && mo.bISMONSTER && mo.health > 0 && mo.target == owner)
				{
					//console.printf("%s target: %s", mo.GetTag(), mo.target ? mo.target.GetTag() : "none");
					mo.bSeeFriendlyMonsters = true;
					mo.target = soundtarget;
					mo.lastheard = soundtarget;
					mo.lastenemy = soundtarget;
				}
			}*/
		}
		super.InitEffect();
	}

	override void Tick()
	{
		if (!active)
			return;
		
		super.Tick();
	}
	
	override void DoEffect()
	{
		if (!active)
			return;
		
		super.DoEffect();		
		if (owner && owner.player)
		{
			//owner.player.cheats |= CF_NOTARGET;
			owner.bNOTARGET = true;
			owner.bNEVERTARGET = true;
			
			let psp = owner.player.FindPSprite(PSP_WEAPON);
			let weap = owner.player.readyweapon;
			if (owner.health > 0 && weap && psp && (InStateSequence(psp.curstate, weap.FindState("Fire")) || InStateSequence(psp.curstate, weap.FindState("AltFire"))))
			{
				SpawnSoundTarget();
			}
			else
			{
				UpdateSoundTarget();
			}

			if (!handler)
				handler = ToM_Mainhandler(EventHandler.Find("ToM_Mainhandler"));

			for (int i = 0; i < handler.allmonsters.Size(); i++)
			{
				let mo = handler.allmonsters[i];
				if (mo && mo.health > 0)
				{
					mo.bSeeFriendlyMonsters = true;
					if (mo.target == owner)
					{
						mo.target = soundtarget;
						mo.lastheard = soundtarget;
						mo.lastenemy = soundtarget;
					}
				}
			}
		}
	}
	
	override void EndEffect()
	{
		if (owner && owner.player)
		{
			if (soundtarget)
				soundtarget.Destroy();
			
			owner.A_SetRenderstyle(prevAlpha, prevRenderstyle);
			// Don't override the notarget console cheat if active:
			/*CVar nt = CVar.GetCVar('notarget', owner.player);
			if (nt && nt.GetBool() == false)
			{
				owner.player.cheats &= ~CF_NOTARGET;
			}*/
			
			owner.bNOTARGET = owner.default.bNOTARGET;
			owner.bNEVERTARGET = owner.default.bNEVERTARGET;
			
			/*let ti = ThinkerIterator.Create("Actor");
			Actor mo;
			while (mo = Actor(ti.Next()))
			{
				if (mo && mo.bISMONSTER && mo.health > 0 && mo.target == owner)
				{
					mo.bSeeFriendlyMonsters = mo.default.bSeeFriendlyMonsters;
				}
			}*/

			if (!handler)
				handler = ToM_Mainhandler(EventHandler.Find("ToM_Mainhandler"));

			for (int i = 0; i < handler.allmonsters.Size(); i++)
			{
				let mo = handler.allmonsters[i];
				if (mo)
				{
					mo.bSeeFriendlyMonsters = mo.default.bSeeFriendlyMonsters;
				}
			}
		}
		super.EndEffect();
	}
}

class ToM_PlayerSoundTarget : Actor
{
	Default
	{
		+NOINTERACTION
		+ISMONSTER
		+FRIENDLY
		+NODAMAGE
		+SHOOTABLE
		+NONSHOOTABLE
		+NOBLOOD
		+NOSPRITESHADOW
		renderstyle 'Translucent';
		//renderstyle 'STYLE_Shaded';
		//stencilcolor "FFFFFF";
		XScale 0.8;
		YScale 0.65;
	}

	States {
	Spawn:
		INVH Z -1;
		stop;
	}
}

class ToM_InvisibilitySelector : ToM_BaseWeapon
{
	ToM_ReflectionCamera cam;
	Weapon prevWeapon;
	
	enum TIPsprites
	{
		TIP_Mirror = -10,
		TIP_Face = 10,
		TIP_Frame = 20,
		TIP_Arm = 30,
	}

	override void DoEffect()
	{
		super.DoEffect();
		if (!owner || !owner.player)
			return;
		
		owner.player.WeaponState |= WF_WEAPONBOBBING;
		
		if (!cam)
		{
			cam = ToM_ReflectionCamera(Spawn("ToM_ReflectionCamera", owner.pos));
			cam.ppawn = PlayerPawn(owner);
			TexMan.SetCameraToTexture(cam, "AliceWeapon.camtex", 60);
		}
	}
	
	override void DetachFromOwner()
	{
		if (cam)
			cam.Destroy();
		super.DetachFromOwner();
	}
	
	Default
	{
		Inventory.maxamount 1;
		+WEAPON.CHEATNOTWEAPON
	}
	
	States
	{
	Select:
		TNT1 A 0 { return ResolveState("Ready"); }
		wait;
	Deselect:
		TNT1 A 0 A_Lower();
		wait;
	Mirror:
		LGMR C -1
		{
			A_OverlayFlags(OverlayID(), PSPF_RenderStyle|PSPF_ForceStyle|PSPF_ForceAlpha, true);
			A_OverlayRenderstyle(OverlayID(), Style_Translucent);
		}
		stop;
	Arm:
		LGMR A -1
		{
			A_OverlayFlags(OverlayID(), PSPF_RenderStyle|PSPF_ForceStyle|PSPF_ForceAlpha, true);
			A_OverlayRenderstyle(OverlayID(), Style_Translucent);
		}
		stop;
	Fire:
	Ready:
		TNT1 A 0
		{
			A_Overlay(TIP_Face, "Face");
			A_Overlay(TIP_Frame, "Frame");
			A_Overlay(TIP_Mirror, "Mirror");
			A_Overlay(TIP_Arm, "Arm");
			A_WeaponOffset(-22.5, 108+WEAPONTOP);
		}
		TNT1 AAAAAAAAA 1
		{
			A_WeaponOffset(2.5, -12, WOF_ADD);
		}
		TNT1 A 1
		{
			if (player.cmd.buttons & BT_ATTACK)
				return A_Jump(256, 1);
			return ResolveState(null);
		}
		wait;
		TNT1 AAAAAAAAAAAAAAAAAAAA 1 
		{
			let psp = player.FindPSprite(TIP_Arm);
			let psf = player.FindPSprite(TIP_Face);
			if (psp && psf)
			{
				double fac = 0.0425;
				psp.alpha = Clamp(psp.alpha - fac, 0.15, 1);
				psf.alpha = Clamp(psp.alpha - fac, 0.15, 1);
				A_SetRenderstyle(psp.alpha, Style_Shaded);
				SetShade("FFFFFF");
			}
		}		
		TNT1 A 0
		{
			let invs = FindInventory("ToM_InvisibilityEffect");
			if (invs)
				invs.Activate(self);
			player.SetPSprite(TIP_Face, ResolveState("FaceBack"));
			player.SetPSprite(TIP_Frame, ResolveState("FrameBack"));
		}
		TNT1 AAAAAAAAA 1
		{
			A_WeaponOffset(-3, 14, WOF_ADD);
		}
		TNT1 A 0
		{
			player.pendingweapon = invoker.prevWeapon;
			A_TakeInventory(invoker.GetClass(), invoker.amount);
		}
		stop;
	Face:
		TNT1 A 1
		{
			A_OverlayFlags(OverlayID(), PSPF_RenderStyle|PSPF_ForceAlpha, true);
			A_OverlayRenderstyle(OverlayID(), Style_Translucent);
		}
		//LGMT ABCDEFGH 1;
		wait;
	Frame:
		TNT1 A 0
		{
			A_OverlayFlags(OverlayID(), PSPF_RenderStyle|PSPF_ForceStyle, true);
			A_OverlayRenderstyle(OverlayID(), Style_Normal);
		}
		LGMS ABCDEFGHI 1;
		wait;
	FaceBack:
		//LGMT HGFEDCBA 1;
		TNT1 A 1;
		stop;
	FrameBack:
		TNT1 A 0 
		{
			A_OverlayFlags(OverlayID(), PSPF_RenderStyle|PSPF_ForceStyle|PSPF_ForceAlpha, true);
			A_OverlayRenderstyle(OverlayID(), Style_Translucent);
		}
		LGMS IHGFEDCBA 1  
		{
			let psp = player.FindPSprite(OverlayID());
			let psm = player.FindPSprite(TIP_Mirror);
			if (psp)
				psp.alpha -= 0.125;
			if (psm)
				psm.alpha -= 0.125;
		}
		stop;
	}
}

class ToM_ReflectionCamera : Actor
{
	PlayerPawn ppawn;

	Default	
	{
		+NOINTERACTION
		+NOTIMEFREEZE
		radius 1;
		height 1;
	}
	
	override void Tick() 
	{
		if (!ppawn) 
		{
			Destroy();
			return;
		}
		
		Warp(
			ppawn, 
			xofs: ppawn.radius + 16, 
			yofs: -8,
			zofs: ppawn.player.viewheight - 16
		);
		
		A_SetRoll(ppawn.roll, SPF_INTERPOLATE);
		A_SetAngle(ppawn.angle + 180, SPF_INTERPOLATE);
		A_SetPitch(-ppawn.pitch, SPF_INTERPOLATE);
	}
}