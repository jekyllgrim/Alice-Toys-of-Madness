// Fake weapon for first-person artifact activation animations:
class ToM_ArtifactSelector : ToM_BaseWeapon abstract
{
	Weapon prevWeapon;
	ToM_Powerup power;
	class<ToM_Powerup> powerupType;
	property PowerupType : powerupType;
	
	Default
	{
		Inventory.maxamount 1;
		+WEAPON.CHEATNOTWEAPON
	}

	// Gives the specified player pawn either a 1st-person powerup selector,
	// or the powerup directly. Returns false if the player is receiving this
	// powerup for the first time (they didn't have either the selector,
	// or the powerup):
	static bool GivePower(PlayerPawn who, class<ToM_ArtifactSelector> selector, bool anySelector = true)
	{
		if (!who)
			return false;

		// We'll get the powerup type from the selector class:
		let def = ToM_ArtifactSelector(GetDefaultByType(selector));
		if (!def)
		{
			return false;
		}

		// Check if the player already has either the selector weapon, or the powerup:
		let t_powerup = ToM_Powerup(who.FindInventory(def.powerupType));
		let t_selector = ToM_ArtifactSelector(who.FindInventory(selector));

		// We'll only give the player a first-person selector if they
		// don't already have that selector OR the valid powerup,
		// AND if anySelector is false or they don't have ANY selectors:
		bool hasPower = t_powerup || t_selector || (anySelector && who.FindInventory('ToM_ArtifactSelector', true));
		
		// If the player already has the powerup, update its tics:
		if (t_powerup)
		{
			t_powerup.effectTics = ToM_Powerup(GetDefaultByType(def.poweruptype)).effectTics;
		}

		// Do the rest if they're picking it up for the first time:
		if (!hasPower)
		{
			// Give selector:
			t_selector = ToM_ArtifactSelector(who.GiveInventoryType(def.GetClass()));
			// Give powerup. This could be done sooner, but I
			// want powerup to be given AFTER the selector in
			// case the powerup needs to check if selector is
			// in inventory or not in its InitEffect():
			t_powerup = ToM_Powerup(who.GiveInventoryType(def.powerupType));
			// Set the powerup as inactive, so that the selector
			// can activate it. Store the current readyweapon in 
			// the selector, then switch to selector:
			if (t_selector && t_powerup)
			{
				t_powerup.waitForSelector = true;
				t_selector.power = t_powerup;
				t_selector.prevWeapon = who.player.readyweapon;
				who.player.readyweapon = null;
				who.player.pendingweapon = t_selector;
			}
		}
		
		// Return true if the player had the selector or its powerup
		// before this:
		return hasPower;
	}

	virtual void EndSelectorAnimation()
	{
		if (prevWeapon)
		{
			owner.player.pendingweapon = prevWeapon;
		}
		// Double-check the owner has the necessary powerup:
		if (!power)
		{
			owner.GiveInventory(powerupType, 1);
			power = ToM_Powerup(owner.FindInventory(powerupType));
		}
		if (power && power.waitForSelector)
		{
			power.Activate(owner);
		}
	}

	override void DetachFromOwner()
	{
		if (owner && owner.player)
		{
			EndSelectorAnimation();
		}
		super.DetachFromOwner();
	}

	States
	{
	Select:
		TNT1 A 0 { return ResolveState("Ready"); }
		wait;
	Deselect:
		TNT1 A 0 A_Lower();
		wait;
	Fire:
		TNT1 A 0 { return ResolveState("Ready"); }
	Ready:
		TNT1 A 1;
	EndEffect:
		TNT1 A 0 A_TakeInventory(invoker.GetClass(), invoker.amount);
		stop;
	}
}

class ToM_Powerup : Powerup abstract
{
	bool waitForSelector;

	virtual void ToM_DoEffect()
	{}

	override void DoEffect()
	{
		if (waitForSelector || !owner || !owner.player)
		{
			return;
		}
		Super.DoEffect();
		ToM_DoEffect();
	}

	virtual void ToM_Tick()
	{}

	override void Activate(Actor activator)
	{
		waitForSelector = false;
	}

	override void Tick()
	{
		if (waitForSelector || !owner || !owner.player)
		{
			return;
		}
		// Painsound is played when the time runs out, every second:
		if (painsound && (EffectTics <= TICRATE * 5) && (EffectTics % TICRATE == 0))
		{
			owner.A_StartSound(painsound, CHAN_AUTO);
		}
		Super.Tick();
		ToM_Tick();
	}

	override void EndEffect()
	{
		// Deathsound is used when the effect runs out:
		if (deathsound && owner)
		{
			owner.A_StartSound(deathsound, CHAN_AUTO);
		}
		Super.EndEffect();
	}
}

// The in-world prop that activates the whole Rage Box effect:
class ToM_RageBox : Actor replaces Berserk
{
	vector3 smokedir;
	protected Actor flare;

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
			let diff = LevelLocals.Vec3Diff(pos + (0,0,24), target.pos + (0,0, ToM_Utils.GetPlayerAtkHeight(target.player.mo)));
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

	static clearscope bool HasRageBox(Actor who)
	{
		return who && (who.CountInv("ToM_RageBoxSelector") || who.CountInv("ToM_RageBoxEffect"));
	}
	
	override bool CanCollideWith(Actor other, bool passive)
	{
		if (passive && other && other.player)
			return true;
		
		return false;
	}
	
	override void Activate(Actor activator)
	{
		if (!activator || !activator.player)
			return;
			
		A_StartSound("ragebox/activate", startTime: 0.5);
		if (!ToM_ArtifactSelector.GivePower(PlayerPawn(activator), 'ToM_RageBoxSelector'))
		{
			activator.A_Stop();
			activator.A_SetAngle(activator.AngleTo(self), SPF_INTERPOLATE);
			activator.A_SetPitch(0, SPF_INTERPOLATE);
			activator.A_StartSound("ragebox/scream", CHAN_AUTO);
		}
		if (flare)
		{
			flare.Destroy();
		}
		A_RemoveLight('rageBoxLight');
		SetStateLabel("Active");
		ToM_CheshireCat.SpawnAndTalk(activator.player.mo, "cheshire/vo/ragebox");
	}
	
	override void PostbeginPlay()
	{
		super.PostbeginPlay();
		double hpos = 25;
		flare = ToM_BaseFlare.Spawn(Vec3Offset(0, 0, hpos), scale: 0.3, alpha: 0.45, col: "FF0000");
		A_AttachLight('rageBoxLight', DynamicLight.PointLight, "cc0000", 48, 0, flags: DYNAMICLIGHT.LF_ATTENUATE|DYNAMICLIGHT.LF_DONTLIGHTSELF, ofs: (0,0, hpos));
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
				target.A_SetBlend("a80a0a", 0.35, 100);
			}
		}
		M000 AAAAAAAAAAAAAAAAAAAAA 2 SpawnRageSmoke();
		M000 A 1 A_FadeOut(0.05);
		wait;
	}
}

// Handles the actual effects of the ragebox:
class ToM_RageBoxEffect : ToM_Powerup 
{
	const PROTFACTOR = 0.15;
	const DMGFACTOR = 4;

	Default
	{
		Powerup.Duration -30;
		Powerup.Strength 5;
		Powerup.Color "FF0000", 0.12;
		Inventory.Icon "APOWRAGE";
		+Inventory.ALWAYSPICKUP
	}

	static void SwapRageModel(Actor who, bool enable)
	{
		let alice = ToM_AlicePlayer(who);
		if (!alice) return;

		if (enable)
		{
			alice.ToM_ChangeModel("", ToM_AlicePlayer.MI_RageParts, modelpath: ToM_AlicePlayer.BASEMODELPATH, model: "alice_rageParts.iqm");
			alice.ToM_ChangeModel("", ToM_AlicePlayer.MI_LeftArm, flags: CMDL_HIDEMODEL);
			alice.ToM_ChangeModel("", skinindex: ToM_AlicePlayer.SI_Head, skinpath: ToM_AlicePlayer.BASEMODELPATH, skin: "rage_face.png", flags: CMDL_USESURFACESKIN);
		}
		else
		{
			alice.ToM_ChangeModel("", ToM_AlicePlayer.MI_RageParts, flags: CMDL_HIDEMODEL);
			alice.ToM_ChangeModel("", ToM_AlicePlayer.MI_LeftArm, modelpath: ToM_AlicePlayer.BASEMODELPATH, model: "alice_leftarm.iqm");
			alice.ToM_ChangeModel("", skinindex: ToM_AlicePlayer.SI_Head, skinpath: ToM_AlicePlayer.BASEMODELPATH, skin: "alice_body3.png", flags: CMDL_USESURFACESKIN);
		}
	}

	override void InitEffect()
	{
		Super.InitEffect();
		if (owner)
		{
			owner.GiveBody(100);
			// assign rage model if this powerup is given directly for some reason
			// (otherwise the selector will activate it)
			if (!owner.FindInventory('ToM_RageBoxSelector'))
			{
				SwapRageModel(owner, true);
			}
		}
	}

	// Increase outgoing damage and reduce incoming damage:
	override void ModifyDamage(int damage, Name damageType, out int newdamage, bool passive, Actor inflictor, Actor source, int flags)
	{
		if (damage <= 0 || waitForSelector)
		{
			return;
		}
		
		if (passive)
		{
			newdamage = max(0, ApplyDamageFactors(GetClass(), damageType, damage, int(damage  * PROTFACTOR)));
		}
		else
		{
			newdamage = max(1, ApplyDamageFactors(GetClass(), damageType, damage, damage * DMGFACTOR));
			if (owner && newdamage > damage) 
			{
				owner.A_StartSound(ActiveSound, CHAN_AUTO, CHANF_DEFAULT, 1.0, ATTN_NONE);
			}
		}
	}

	override void ToM_DoEffect()
	{
		//owner.A_SetMugshotState("RageBoxLoop");
		owner.bNOPAIN = true;
		if (owner.health > 0 && (Level.maptime & 31) == 0)
		{
			owner.GiveBody(5);
		}
	}

	override void EndEffect()
	{
		if (owner)
		{
			owner.bNOPAIN = owner.default.bNOPAIN;
			SwapRageModel(owner, false);
		}
		Super.EndEffect();
	}

	override void OnDestroy()
	{
		SwapRageModel(owner, false);
		Super.OnDestroy();
	}
}

class ToM_RageBoxSelector : ToM_ArtifactSelector
{
	int bloodtics;

	Default
	{
		ToM_ArtifactSelector.PowerupType 'ToM_RageBoxEffect';
	}

	override void DoEffect()
	{
		if (!owner || !owner.player)
			return;

		owner.player.cheats |= CF_TOTALLYFROZEN;
		owner.bNODAMAGE = true;
		owner.vel = (0,0,0);
		if (!multiplayer)
		{
			owner.bNOTIMEFREEZE = true;
			Level.SetFrozen(true);
		}
	}

	override void EndSelectorAnimation()
	{
		if (!CountInv("ToM_Knife"))
		{
			GiveInventory("ToM_Knife", 1);
		}
		prevWeapon = Weapon(owner.FindInventory('ToM_Knife'));
		owner.player.cheats &= ~CF_TOTALLYFROZEN;
		owner.bNODAMAGE = false;
		owner.bNOTIMEFREEZE = false;
		Level.SetFrozen(false);
		super.EndSelectorAnimation();
	}

	States
	{
	SpawnBloodParticle:
		TNT1 A 1
		{
			if (invoker.bloodtics <= 0)
			{
				return ResolveState("Null");
			}
			A_SetTics(random[sfx](1, 10));
			A_SpawnPSParticle("BloodParticle", xofs:frandom[sfx](-400, 400), yofs:frandom(-100, 100));
			invoker.bloodtics--;
			return ResolveState(null);
		}
		loop;
	BloodParticle:
		TNT1 A 1
		{
			let psp = player.FindPSprite(OverlayID());
			psp.frame = random[sfx](0,7);
			A_OverlayPivotAlign(OverlayID(),PSPA_CENTER,PSPA_CENTER);
			A_OverlayFlags(OverlayID(), PSPF_ADDBOB|PSPF_ADDWEAPON, false);
			A_OverlayFlags(OverlayID(), PSPF_RENDERSTYLE|PSPF_FORCEALPHA,true);
			A_OverlayAlpha(OverlayID(), frandom[sfx](0.5, 0.9));
		}
		VKNB # 1 
		{
			A_PSPFadeOut(invoker.bloodtics ? 0.01 : 0.0075);
			A_OverlayOffset(OverlayID(), 0, frandom[sfx](0.1, 0.42), WOF_ADD);
		}
		wait;
	Ready:
		TNT1 A 0 
		{
			invoker.bloodtics = 15;
			A_Overlay(APSP_Overlayer, "SpawnBloodParticle");
			A_WeaponOffset(0, WEAPONTOP);
			vector2 piv = (0.2, 0.3);
			A_OverlayPivot(OverlayID(), piv.x, piv.y);
			A_Overlay(APSP_LeftHand, "SelectRageLeftHand");
			A_OverlayPivot(APSP_LeftHand, -piv.x, piv.y);
			let alice = ToM_AlicePlayer(self);
			A_PlayerAttackAnim(-1, 'rage_start', loopframe: 51, flags:SAF_LOOP);
		}
		VRAG ABCDEF 2 { player.viewheight -= 2; }
		VRAG FFFGGGHHHIIIIIIIIIIIIIIIIIIIIIIIIII 5 A_OverlayOffset(OverlayID(), frandom[sfx](-1,1), frandom[sfx](-1,1), WOF_ADD);
		TNT1 A 0 A_OverlayPivot(OverlayID(), 0.6, 0.6);
		VRAG JKLMNO 2 A_RotatePSprite(OverlayID(), 3, WOF_ADD);
		TNT1 A 0 
		{
			A_RotatePSPrite(OverlayID(), 0, WOF_INTERPOLATE);
			A_WeaponOffset(0, WEAPONTOP, WOF_INTERPOLATE);
		}
		VKRR BCDEFG 1 { player.viewheight += 2; } 
		VKRF A 1;
		wait;
	SelectRageLeftHand:
		TNT1 A 0 A_OverlayFlags(OverlayID(), PSPF_FLIP|PSPF_MIRROR, true);
		VRAG ABCDEF 2;
		VRAG FFFGGGHHHIIIIIIIIIIIIIIIIIIIIIIIIII 5 A_OverlayOffset(OverlayID(), frandom[sfx](-1,1), frandom[sfx](-1,1), WOF_ADD);
		#### # 0 
		{
			A_OverlayPivot(OverlayID(), 0.6, 0.6);
			A_PlayerAttackAnim(41, 'rage_scream', framerate: 30);
			ToM_RageBoxEffect.SwapRageModel(self, true);
		}
		VRAG JKL 2;
		VRAG MMMMM 1 A_OverlayOffset(OverlayID(), frandom(-0.5, 0.5), frandom(-0.5, 0.5), WOF_INTERPOLATE);
		TNT1 A 0 A_OverlayFlags(OverlayID(), PSPF_FLIP|PSPF_MIRROR, false);
		VCLS ABC 1 A_OverlayOffset(OverlayID(), 3, -5, WOF_INTERPOLATE);
		VCLS CCCCCCCCCCCCCCCCCC 1 A_OverlayOffset(OverlayID(), frandom(1, 1), frandom(1, 1), WOF_INTERPOLATE);
		VCLS CCCCCC 1
		{
			//A_OverlayOffset(OverlayID(), -3, 5, WOF_ADD);
			A_OverlayScale(OverlayID(), -0.03, -0.03, WOF_ADD);
			A_OverlayRotate(OverlayID(), -1, WOF_ADD);
		}
		#### # 0 
		{
			A_OverlayScale(OverlayID(), 1.1, 1.1);
			A_ResetPSprite(0, 5);
		}
		VCLW A 5;
		#### # 0 { self.SetState(self.spawnstate); }
		goto EndEffect;
	}
}

class ToM_GrowthPotion : PowerupGiver
{
	int waitBounce;
	TextureID partTex;

	Default
	{
		Powerup.Type "ToM_GrowthPotionEffect";
		Powerup.Duration -30;
		Inventory.Pickupmessage "$TOM_ITEM_CAKE";
		Inventory.PickupSound "pickups/cake";
		+Inventory.AUTOACTIVATE
		+Inventory.ALWAYSPICKUP
		scale 0.15;
		Inventory.MaxAmount 1;
	}
	
	States
	{
	Spawn:
		CAKG AABBCCDDEEFFGGHHIIJ 1
		{
			if (waitBounce >= 105)
			{
				waitBounce = 0;
				return ResolveState("Shrink");
			}
			if (waitBounce <= 18 && waitBounce % 4 == 0)
			{
				if (!partTex || !partTex.isValid())
				{
					partTex = TexMan.CheckForTexture('LENYA0');
				}
				for (int i = 0; i < 8; i++)
				{
					A_SpawnParticleEx(0xFFCCCC, partTex,
						STYLE_AddShaded,
						SPF_RELATIVE|SPF_FULLBRIGHT|SPF_REPLACE,
						lifetime: 18,
						size: 4,
						angle: 45*i,
						xoff: (18 - waitbounce) * 0.5,
						zoff: waitBounce * 2,
						velx: 3,
						velz: 3,
						accelx: -0.1,
						accelz: -0.3,
						sizestep: -0.05
					);
				}
			}
			scale.y = default.scale.y + default.scale.y * -0.2 * ToM_Utils.SinePulse(counter: waitBounce);
			scale.x = default.scale.x + default.scale.x * 0.2 * ToM_Utils.SinePulse(counter: waitBounce-2);
			waitBounce++;
			return ResolveState(null);
		}
		wait;
	Shrink:
		CAKG HFDBA 2 { spriteOffset.y -= 4; }
		CAKG AAAAA 1 { spriteOffset.y -= 1; }
		CAKG AAAAA 1 {spriteOffset.y += 5; }
		CAKG A 1 {spriteOffset.y -= 4; }
		CAKG AA 1 {spriteOffset.y += 2; }
		CAKG A 5;
		goto Spawn;
	}
}

class ToM_GrowthPotionEffect : Powerup
{
	protected int growthState;

	protected double prevHeight;
	protected vector2 prevScale;
	protected double prevViewHeight;
	protected double prevAttackZOffset;
	protected vector2 prevWeaponScale;
	protected double prevZoom;
	protected double prevViewBobSpeed;
	protected double prevjumpz;
	protected double prevGravity;
	
	protected double targetHeight;
	protected bool heightChangeSuccess;
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

	enum EGrowthState
	{
		GROWTH_NotStarted,
		GROWTH_Growing,
		GROWTH_Shrinking,
	}
	
	const GROWFACTOR = 1.5;
	const GROWWEAPON = 1.2;
	const VIEWFACTOR = 2.0;
	const SPEEDFACTOR = 0.5;
	const GROWTIME = 50;
	const GROWZOOM = 1.2;
	
	Default
	{
		Powerup.duration -5;
		Inventory.Icon "APOWCAKE";
	}

	override void InitEffect()
	{
		Super.InitEffect();
		growthState = GROWTH_NotStarted;
	}

	// Using custom init run from DoEffect() instead of
	// an InitEffect() override, bceause as of 4.12.2
	// InitEffect() obtains incorrect information about
	// the owner when a powerup is received through a
	// powerup giver placed in the world (pending a bug
	// report on gzdoom repo).
	void GrowthInit()
	{
		if (growthState != GROWTH_NotStarted) return;

		if (!owner || !owner.player)
		{
			Destroy();
			return;
		}

		growthState = GROWTH_Growing;

		PlayerInfo player = owner.player;
		PlayerPawn pmo = owner.player.mo;

		pmo.bRespawnInvul = false;
	
		// record current values:
		prevHeight = pmo.height;
		prevScale = pmo.scale;
		prevViewHeight = pmo.viewHeight;
		prevAttackZOffset = pmo.AttackZOffset;
		prevjumpz = pmo.jumpz;
		prevGravity = pmo.gravity;
		prevViewBobSpeed = pmo.ViewBobSpeed;
		prevZoom = player.fov;
		let weap = player.readyweapon;
		if (weap)
		{
			let dweap = GetDefaultByType(weap.GetClass());
			prevWeaponScale = (dweap.WeaponScaleX, dweap.WeaponScaleY);
			curWeaponScale = prevWeaponScale;
		}
		/*PSprite psp = pmo.player.psprites;
		if (psp)
		{
			prevWeaponScale = curWeaponScale = psp.basescale;
		}*/

		// slower view bob:
		pmo.ViewBobSpeed *= VIEWFACTOR;
		
		// target height (to be set in DoEffect):
		targetHeight = prevHeight * GROWFACTOR;
		
		// target viewheight and viewheight step (to be set in DoEffect):
		targetViewHeight = targetHeight - (prevHeight - prevViewHeight);
		viewHeightStep = (targetViewHeight - prevViewHeight) / GROWTIME;
		
		// target scale and scale step (to be set in DoEffect):
		targetScale = prevScale * GROWFACTOR;
		scaleStep.x = (targetScale.x - prevScale.x) / GROWTIME;
		scaleStep.y = (targetScale.y - prevScale.y) / GROWTIME;

		// target AttackZOffset and AttackZOffset step (to be set in DoEffect):
		double diff = prevViewHeight - prevHeight*0.5 - prevAttackZOffset;
		targetAttackZOffset = targetViewHeight - diff - targetHeight*0.5; //prevAttackZOffset * GROWFACTOR;
		attackZOffsetStep = (targetAttackZOffset - prevAttackZOffset) / GROWTIME;
		
		// target weapon scale and weapon scale step:
		if (weap)
		{
			targetweaponScale = prevweaponScale * GROWWEAPON;
			weaponScaleStep.x = (targetweaponScale.x - prevweaponScale.x) / GROWTIME;
			weaponScaleStep.y = (targetweaponScale.y - prevweaponScale.y) / GROWTIME;
		}
		
		// zoom step:
		targetZoom = prevZoom * GROWZOOM;
		zoomStep = (targetZoom - prevZoom) / GROWTIME;
		
		// speed is modified instantly:
		pmo.speed *= SPEEDFACTOR;
		
		if (tom_debugmessages)
		{
			console.printf(
				"Growth potion initialized:\n"
				"Height: \cD%.1f\c- | step: \cDinstant\c- | target: \cD%.1f\c-\n"
				"View height: \cD%.1f\c- | step: \cD%.1f\c- | target: \cD%.1f\c-\n"
				"AttackZOffset: \cD%.1f\c- | step: \cD%.1f\c- | target: \cD%.1f\c-",
				prevHeight, targetHeight,
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

		if (growthState == GROWTH_Growing && (EffectTics == 0 || (EffectTics > 0 && --EffectTics == 0)))
		{
			growthState = GROWTH_Shrinking;
		}
	}
	
	override void DoEffect()
	{
		super.DoEffect();
		if (!owner || !owner.player)
			return;
		
		GrowthInit();
		
		owner.bInvulnerable = (growthState == GROWTH_Growing);
		
		if (owner.isFrozen())
			return;

		let pmo = PlayerPawn(owner);
		let player = owner.player;
		let weap = owner.player.readyweapon;

		pmo.jumpz = (player.viewHeight >= ceilingz)? 0 : prevjumpz;
		owner.gravity = player.jumptics != 0 ? prevGravity / 2 : prevGravity;
		
		double stepFactor = (growthState == GROWTH_Shrinking)? -2 : 1;
		
		// gradually modify viewheight:
		pmo.viewHeight = Clamp(
			pmo.viewHeight + viewHeightStep * stepFactor,
			prevViewHeight, targetViewHeight
		);
		player.viewHeight = pmo.viewHeight;

		// gradually modify attack height (AttackZOffset):
		pmo.AttackZOffset = Clamp(
			pmo.AttackZOffset + attackZOffsetStep * stepFactor,
			prevAttackZOffset, targetAttackZOffset
		);
	
		// gradually modify zoom:
		owner.player.desiredFov = Clamp(
			owner.player.fov + zoomStep * stepFactor,
			1, 
			targetZoom
		);
		
		// gradually modify weapon scale:
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
		// We need to modify BOTH the WeaponScaleX/Y properties
		// AND change the basescale of each active PSprite;
		// without doing the latter, the currently active PSprites
		// won't get updated until they are recreated or A_WeaponReady
		// is called on them (which works only for PSP_WEAPON):
		if (weap)
		{
			weap.WeaponScaleX = curWeaponScale.x;
			weap.WeaponScaleY = curWeaponScale.Y;
		}
		for (PSprite psp = pmo.player.psprites; psp; psp = psp.next)
		{
			psp.basescale = curWeaponScale;
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
		if (!heightChangeSuccess && pmo.height < targetHeight)
		{
			pmo.A_SetSize(pmo.radius, targetHeight, true);
			if (!pmo.TestMobjLocation())
			{
				pmo.A_SetSize(pmo.radius, prevHeight);
			}
			else
			{
				heightChangeSuccess = true;
			}
		}
		
		// Walking:
		if (growthState == GROWTH_Growing)
		{
			if (pmo.player.onground && pmo.Vel.Length() > 4) 
			{
				stepCycle++;
				if (stepCycle % 20 == 0) {
					//do the damage:
					DoStepDamage(pmo, damage: 20, visualImpact: false);
				}
			}
			else
			{
				stepCycle = 0;
			}
		}
		
		else if (pmo.viewHeight <= prevViewHeight)
		{
			Destroy();
		}
	}

	static void DoStepDamage(Actor source, int damage = 15, double distance = 256, bool visualImpact = true)
	{
		BlockThingsIterator itr = BlockThingsIterator.Create(source,distance);
		while (itr.next()) {
			let next = itr.thing;
			if (!next || next == source)
				continue;
			bool isValid = ((next.bSHOOTABLE || next.bVULNERABLE) && (next.bIsMonster ||next.player) && next.health > 0);
			if (!isValid)
				continue;
			double zdiff = abs(source.pos.z - next.pos.z);
			if (zdiff > 32)
				continue;
			if (source.Distance3D(next) > distance)
				continue;
			next.DamageMobj(source, source, damage,'normal',DMG_THRUSTLESS|DMG_NO_FACTOR);
			next.vel.z += 4;
		}
		source.A_Quake(2, 5, 0, distance, "");
		let hi = Spawn("ToM_HorseImpact", (source.pos.xy, source.floorz));
		if (hi)
		{
			hi.A_StartSound("growpotion/giantstep", CHAN_AUTO);
			if (visualImpact)
			{
				hi.scale.x = distance;
			}
			else
			{
				hi.Destroy();
			}
		}
	}

	override void EndEffect()
	{
		if (owner && owner.player)
		{
			owner.bInvulnerable = false;

			let pmo = owner.player.mo;
			let weap = owner.player.readyweapon;

			pmo.A_SetSize(pmo.radius, prevHeight);
			pmo.jumpz = prevjumpz;
			pmo.gravity = prevGravity;
			pmo.ViewBobSpeed = prevViewBobSpeed;
			pmo.viewHeight = prevViewHeight;
			pmo.player.viewHeight = pmo.viewHeight;
			pmo.attackZOffset = prevAttackZOffset;
			pmo.scale = prevScale;
			pmo.player.desiredFov = prevZoom;
			pmo.speed /= SPEEDFACTOR;
			for (Inventory item = owner.inv; item; item = item.inv)
			{
				let weap = Weapon(item);
				if (weap)
				{
					weap.WeaponScaleX = weap.default.WeaponScaleX;
					weap.WeaponScaleY = weap.default.WeaponScaleY;
				}
			}
			for (PSprite psp = pmo.player.psprites; psp; psp = psp.next)
			{
				psp.basescale = weap? (weap.WeaponScaleX, weap.WeaponScaleY) : (1.0, 1.2);
			}
			if (tom_debugmessages)
			{
				console.printf(
					"Growth potion ended:\n"
					"height: \cD%.1f\c- | was: \cD%.1f\c-\n"
					"View height: \cD%.1f\c- | was: \cD%.1f\c-\n"
					"AttackZOffset: \cD%.1f\c- | was: \cD%.1f\c-",
					pmo.height, targetHeight,
					pmo.viewHeight, targetViewHeight,
					pmo.attackZOffset, targetAttackZOffset
				);
			}
		}
		Super.EndEffect();
	}
}

class ToM_Invisibility : PowerupGiver
{
	double pickupBobFactor;

	Default
	{
		Inventory.pickupmessage "$TOM_ITEM_MIRROR";
		Inventory.pickupsound "mirror/pickup";
		Powerup.Duration -40;
		scale 0.25;
		+Inventory.AUTOACTIVATE
		+Inventory.ALWAYSPICKUP
		FloatBobStrength 0.5;
	}

	override bool Use (bool pickup)
	{
		if (owner && owner.player)
		{
			ToM_ArtifactSelector.GivePower(PlayerPawn(owner), 'ToM_InvisibilitySelector');
			return true;
		}
		return false;
	}
	
	States
	{
	Spawn:
		LGMY # 1
		{
			pickupBobFactor = sin(360.0 * (GetAge() + FloatBobPhase) * 0.015);
			WorldOffset.z = 8 * pickupBobFactor * FloatBobStrength;
			int i = round(ToM_Utils.LinearMap(pickupBobFactor, -1, 1, 0, 14));
			if (i >= 14) i = 0;
			frame = i;
		}
		loop;
	}
}

class ToM_InvisibilityEffect : ToM_Powerup
{
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
		DeathSound "mirror/appear";
		Inventory.Icon "APOWGLAS";
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
		}
	}

	override void Activate(Actor activator)
	{
		SpawnSoundTarget();
		super.Activate(activator);
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
		}
		super.InitEffect();
	}
	
	override void ToM_DoEffect()
	{
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
		{
			handler = ToM_Mainhandler(EventHandler.Find("ToM_Mainhandler"));
		}

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
	
	override void EndEffect()
	{
		if (owner && owner.player)
		{
			if (soundtarget)
				soundtarget.Destroy();
			
			owner.A_SetRenderstyle(prevAlpha, prevRenderstyle);
			owner.bNOTARGET = owner.default.bNOTARGET;
			owner.bNEVERTARGET = owner.default.bNEVERTARGET;

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
		alpha 0.2;
		XScale 0.8;
		YScale 0.65;
	}

	override void BeginPlay()
	{
		super.BeginPlay();
		if (!tom_debugmessages)
		{
			A_SetRenderstyle(alpha, STYLE_None);
		}
	}

	States {
	Spawn:
		INVH Z -1;
		stop;
	}
}

class ToM_InvisibilitySelector : ToM_ArtifactSelector
{
	ToM_ReflectionCamera cam;
	
	enum TIPsprites
	{
		TIP_Mirror = -10,
		TIP_Frame = 20,
		TIP_Arm = 30,
	}

	Default
	{
		ToM_ArtifactSelector.PowerupType 'ToM_InvisibilityEffect';
		Renderstyle 'Translucent'; //This is passed to the player
	}

	override void DoEffect()
	{
		super.DoEffect();
		if (!owner || !owner.player)
			return;
		
		owner.player.WeaponState |= WF_WEAPONBOBBING;
		
		if (!cam)
		{
			cam = ToM_ReflectionCamera.Create(
				PlayerPawn(owner), 60, 
				(owner.radius + 16, -8, -16),
				(180, -1, 0));
		}
	}
	
	override void EndSelectorAnimation()
	{
		if (cam)
			cam.Destroy();
		super.EndSelectorAnimation();
	}
	
	States
	{
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
			//A_OverlayFlags(OverlayID(), PSPF_RenderStyle|PSPF_ForceStyle|PSPF_ForceAlpha, true);
			//A_OverlayRenderstyle(OverlayID(), Style_Translucent);
		}
		stop;
	Ready:
		TNT1 A 0
		{
			A_Overlay(TIP_Frame, "Frame");
			A_Overlay(TIP_Mirror, "Mirror");
			A_Overlay(TIP_Arm, "Arm");
			A_WeaponOffset(-24, WEAPONTOP + 80);
			A_OverlayPivot(TIP_Frame, 0.6, 0.8);
			A_OverlayPivot(TIP_Mirror, 0.6, 0.8);
			A_OverlayPivot(TIP_Arm, 0.6, 0.8);
			A_RotatePSprite(TIP_Frame, 40);
			A_RotatePSprite(TIP_Mirror, 40);
			A_RotatePSprite(TIP_Arm, 40);
		}
		#### ######## 1
		{
			A_WeaponOffset(3, -10, WOF_ADD);
			A_RotatePSprite(TIP_Frame, -5, WOF_ADD);
			A_RotatePSprite(TIP_Mirror, -5, WOF_ADD);
			A_RotatePSprite(TIP_Arm, -5, WOF_ADD);
		}
		/*TNT1 A 1
		{
			if (player.cmd.buttons & BT_ATTACK)
				return A_Jump(256, 1);
			return ResolveState(null);
		}
		wait;*/
		TNT1 A 15;
		TNT1 A 0 A_StartSound("mirror/disappear", CHAN_AUTO);
		TNT1 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA 1 
		{
			let psp = player.FindPSprite(TIP_Arm);
			if (psp)
			{
				double fac = (0.85 / 40);
				psp.alpha = Clamp(psp.alpha - fac, 0.15, 1);
				A_SetRenderstyle(psp.alpha, invoker.GetRenderstyle());
				//SetShade("FFFFFF");
			}
			double f = 0.0025;
			A_ScalePSprite(TIP_Frame, f, f, WOF_ADD);
			A_ScalePSprite(TIP_Mirror, f, f, WOF_ADD);
			A_ScalePSprite(TIP_Arm, f, f, WOF_ADD);
		}
		TNT1 A 10
		{
			if (invoker.power)
			{
				invoker.power.Activate(self);
			}
			player.SetPSprite(TIP_Frame, ResolveState("FrameBack"));
			A_ResetPSprite(TIP_Frame, 10);
			A_ResetPSprite(TIP_Mirror, 10);
			A_ResetPSprite(TIP_Arm, 10);
		}
		#### ###### 1
		{
			A_WeaponOffset(-4, 9, WOF_ADD);
			A_RotatePSprite(TIP_Frame, 5, WOF_ADD);
			A_RotatePSprite(TIP_Mirror, 5, WOF_ADD);
			A_RotatePSprite(TIP_Arm, 5, WOF_ADD);
		}
		goto EndEffect;
	Frame:
		TNT1 A 0
		{
			A_OverlayFlags(OverlayID(), PSPF_RenderStyle|PSPF_ForceStyle, true);
			A_OverlayRenderstyle(OverlayID(), Style_Normal);
		}
		LGMS ABCDEFGHI 1;
		wait;
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

class ToM_Infrared : Infrared
{
	array <int> blinks;

	Default
	{
		XScale 0.2;
		YScale 0.16667;
		Powerup.Type "ToM_MadVisionEffect";
		Powerup.Duration -40;
		Inventory.PickupSound "pickups/infrared";
		Inventory.PickupMessage "$TOM_ITEM_INFRARED";
	}

	States {
	CogReset:
		HGL1 DCBA 4;
		HGL1 DCBA 4;
		HGL1 DCBA 4;
		HGL1 DCBA 4;
		HGL1 A 20;
	Spawn:
		HGL1 A 15;
		TNT1 A 0 
		{
			if (blinks.Size() >= 9)
			{
				blinks.Clear();
				return FindState("CogReset");
			}
			int i = 1;
			while (blinks.Find(i) != blinks.Size())
			{
				i = random[lightamp](1, 9);
			}
			blinks.Push(i);
			return FindStateByString("Blink"..i);
		}
	Blink1:
		HGL1 EFGH 3;
		goto Spawn;
	Blink2:
		HGL1 IJKL 3;
		goto Spawn;
	Blink3:
		HGL1 MNOP 3;
		goto Spawn;
	Blink4:
		HGL1 QRST 3;
		goto Spawn;
	Blink5:
		HGL1 UVWX 3;
		goto Spawn;
	Blink6:
		HGL1 YZ 3;
		HGL2 AB 3;
		goto Spawn;
	Blink7:
		HGL2 CDEF 3;
		goto Spawn;
	Blink8:
		HGL2 GHIJ 3;
		goto Spawn;
	Blink9:
		HGL2 KLMN 3;
		goto Spawn;
	}
}

class ToM_MadVisionEffect : PowerTorch
{
	Default
	{
		Inventory.Icon "APOWVISI";
	}

	override void InitEffect()
	{
		Super.InitEffect();
		if (owner && owner.player && owner.player == players[consoleplayer])
		{
			PPShader.SetEnabled("Alice_ScreenWarp", true);
		}
	}

	override void EndEffect()
	{
		if (owner && owner.player && owner.player == players[consoleplayer])
		{
			PPShader.SetEnabled("Alice_ScreenWarp", false);
		}
		Super.EndEffect();
	}
}

class ToM_Radsuit : Radsuit
{
	Default
	{
		XScale 0.35;
		YScale 0.35 / 1.2;
		+FORCEXYBILLBOARD
		Inventory.PickupMessage "$TOM_ITEM_RADSUIT";
		Inventory.PickupSound "pickups/generic/powerup";
		Powerup.Type "ToM_RadSuitEffect";
	}

	override void Tick()
	{
		Super.Tick();
		if (owner || isFrozen() || bNOSECTOR) return;

		double phase = 360.0 * (GetAge() + FloatBobPhase);
		double bob = sin(phase * 0.01);
		WorldOffset.z = 2.5 * bob;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		A_AttachLight('0', DynamicLight.PointLight, 0x2776df, 40, 40, DYNAMICLIGHT.LF_ATTENUATE, ofs: (0, 0, 20));
	}

	States {
	Spawn:
		AMTS ABCDEFGHIJKLMNOPQRST 2;
		loop;
	}
}

class ToM_RadSuitEffect : PowerIronFeet
{
	Default
	{
		Inventory.Icon "APOWSHEL";
	}

	override void InitEffect()
	{
		Super.InitEffect();
		let alice = ToM_AlicePlayer(owner);
		if (alice)
		{
			alice.ToM_ChangeModel("", ToM_AlicePlayer.MI_MockShell, modelpath: ToM_AlicePlayer.BASEMODELPATH, model: "mockshell.iqm");
		}
	}

	override void EndEffect()
	{
		let alice = ToM_AlicePlayer(owner);
		if (alice)
		{
			alice.ToM_ChangeModel("", ToM_AlicePlayer.MI_MockShell, flags: CMDL_HIDEMODEL);
		}
		Super.EndEffect();
	}
}