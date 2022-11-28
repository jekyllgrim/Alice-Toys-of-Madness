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
				target.A_SetBlend("a80a0a", 0.75, 250);
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