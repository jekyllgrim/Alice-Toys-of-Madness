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
		if (target)
		{
			let diff = LevelLocals.Vec2Diff(pos.xy, target.pos.xy);
			let dir = diff.unit();
			smokedir = (dir.x, dir.y, pos.z);
			
			let smk = ToM_WhiteSmoke.Spawn(
				pos + (0,0, 24),
				vel: smokedir * 5,
				scale: 0.1,
				alpha: 1,
				fade: 0.1,
				dbrake: 0.94,
				dscale: 1.025
			);
			if (smk)
			{
				smk.A_SetRenderstyle(smk.alpha, Style_Shaded);
				smk.SetShade("a80a0a");
				smk.bNOTIMEFREEZE = true;
			}
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
		Powerup.Duration -10; //-40;
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
	ToM_GrowControl growcontrol;

	override void InitEffect()
	{
		if (owner)
		{
			if (tom_debugmessages)
				console.printf("Giving grow control token");
			owner.GiveInventory("ToM_GrowControl", 1);
			growcontrol = ToM_GrowControl(owner.FindInventory("ToM_GrowControl"));
			growcontrol.StartEffect();
		}
		Super.InitEffect();
	}
	
	override void EndEffect()
	{
		if (owner && growcontrol)
			growcontrol.StopEffect();
		
		super.EndEffect();
	}
}

class ToM_GrowControl : ToM_InventoryToken
{
	bool finishEffect;

	protected double prevHeight;
	protected vector2 prevScale;
	protected double prevSpeed;
	protected double prevViewHeight;
	protected vector2 prevWeaponScale;
	
	protected double targetSpeed;
	protected double targetHeight;
	protected double targetViewHeight;
	protected vector2 targetScale;
	protected vector2 targetWeaponScale;
	
	protected double viewHeightStep;
	protected vector2 scaleStep;
	protected vector2 weaponScaleStep;
	protected double zoomStep;
	
	protected int stepCycle;
	
	const GROWFACTOR = 1.5;
	const VIEWFACTOR = 2.;
	const SPEEDFACTOR = 0.5;
	const GROWTIME = 50;
	const GROWZOOM = 1.2;
	
	void StartEffect()
	{
		if (owner && owner.player)
		{
			finishEffect = false;
			let weap = owner.player.readyweapon;
			if (weap)
			{
				let dweap = GetDefaultByType(weap.GetClass());
				prevWeaponScale = (dweap.WeaponScaleX, dweap.WeaponScaleY);
			}
		
			// record current values:
			prevHeight = owner.height;
			prevScale = owner.scale;
			prevSpeed = owner.speed;
			prevViewHeight = owner.player.viewHeight;
			
			// target height (to be set in DoEffect):
			targetHeight = prevHeight * GROWFACTOR;
			
			// target scale and scale step (to be set in DoEffect):
			targetScale = prevScale * GROWFACTOR;
			scaleStep.x = (prevScale.x - targetScale.x) / GROWTIME;
			scaleStep.y = (prevScale.y - targetScale.y) / GROWTIME;
			
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
			
			// zoom step:
			zoomStep = (GROWZOOM - 1) / GROWTIME;
			
			// speed is modified instantly:
			owner.speed *= SPEEDFACTOR;
			
			if (tom_debugmessages)
			{
				console.printf(
					"Growth potion initialized.\n"
					"View height: %.1f | step: %.1f | target: %.1f",
					owner.player.viewheight, viewHeightStep, targetViewHeight
				);
			}
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
		
		int stepFactor = finishEffect ? -2 : 1;
		
		// gradually modify viewheight:
		player.viewHeight = Clamp(
			player.viewHeight + viewHeightStep * stepFactor,
			prevViewHeight, targetViewHeight
		);
		pmo.viewHeight = Clamp(
			pmo.viewHeight + viewHeightStep * stepFactor,
			prevViewHeight, targetViewHeight
		);
	
		// gradually modify zoom:
		if (weap)
		{
			weap.fovscale = Clamp(
				weap.fovscale + zoomStep * stepFactor,
				1, 
				GROWZOOM
			);
		}
		
		// gradually modify weapon scale:
		for(PSprite psp = player.psprites; psp; psp = psp.Next)
		{
			if (psp)
			{
				psp.baseScale.x = Clamp(
					psp.baseScale.x + weaponScaleStep.x * stepFactor, 
					prevWeaponScale.x, 
					targetWeaponScale.x
				);
				psp.baseScale.y = Clamp(
					psp.baseScale.y + weaponScaleStep.y * stepFactor, 
					prevWeaponScale.y, 
					targetWeaponScale.y
				);
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
			if (pmo.Vel.Length() > 4) 
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
			player.viewHeight = prevViewHeight;
			pmo.viewHeight = prevViewHeight;
			//pmo.A_SetSize(pmo.radius, prevHeight);
			pmo.scale = prevScale;
			if (weap)
				weap.fovscale = 1;
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
	
	void StopEffect()
	{
		finishEffect = true;
	}
}