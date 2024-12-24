class ToM_InventoryToken : Inventory abstract 
{
	mixin ToM_CheckParticles;
	int age;
	
	Default 
	{
		+INVENTORY.UNDROPPABLE;
		+INVENTORY.UNTOSSABLE;
		+INVENTORY.PERSISTENTPOWER;
		inventory.amount 1;
		inventory.maxamount 1;
	}
	
	override void DoEffect() 
	{
		super.DoEffect();
		if (!owner || (owner.player && ToM_Utils.IsVoodooDoll(PlayerPawn(owner)))) 
		{
			Destroy();
			return;
		}
		if (owner && !owner.isFrozen())
			age++;
	}
	
	override void Tick() {}
}

// Generalized class for dummy items that function
// as controllers for timed effects:
class ToM_ControlToken : ToM_InventoryToken abstract
{
	protected int timer;
	protected int effectFreq;
	protected int duration;
	property duration : duration;
	property EffectFrequency : effectFreq;
	
	Default
	{
		ToM_ControlToken.duration 35;
		ToM_ControlToken.EffectFrequency 35;
		Inventory.amount 1;
		Inventory.maxAmount 1;
	}
	
	virtual void ResetTimer()
	{
		timer = 0;
	}
	
	clearscope int GetTimer()
	{
		return timer;
	}

	void SetDuration(int time)
	{
		duration = time;
	}

	clearscope int GetDuration()
	{
		return duration;
	}

	// Gives the specified controller to the actor,
	// and if it already has one - refreshes its duration:
	static ToM_ControlToken Refresh(Actor victim, class<ToM_ControlToken> controller, Actor newinflictor = null)
	{
		if (!victim) return null;

		ToM_ControlToken cont = ToM_ControlToken(victim.FindInventory(controller));
		if (!cont)
		{
			cont = ToM_ControlToken(victim.GiveInventoryType(controller));
		}
		if (newinflictor)
		{
			cont.target = newinflictor;
		}
		cont.ResetTimer();
		return cont;
	}

	override void AttachToOwner(Actor other)
	{
		Super.AttachToOwner(other);
		if (owner)
		{
			InitController();
		}
		else
		{
			Destroy();
		}
	}

	override void DetachFromOwner()
	{
		if (owner)
		{
			EndController();
		}
		Super.DetachFromOwner();
	}

	virtual void InitController()
	{}

	virtual void EndController()
	{}
	
	virtual void DoControlEffect()
	{}
	
	override void DoEffect()
	{
		super.DoEffect();
		if (self && owner && !owner.isFrozen())
		{
			if (++timer > duration)
			{
				Destroy();
				return;
			}
			
			if (effectFreq > 0 && (timer % effectFreq == 0))
			{
				DoControlEffect();
			}
		}
	}
}

// Generalized subclass for item controllers
// that handles particle-based burning effects:
class ToM_BurnController : ToM_ControlToken
{
	Default
	{
		ToM_ControlToken.duration 200;
		ToM_ControlToken.EffectFrequency 3;
	}

	virtual color GetFlameColor()
	{
		return -1;
	}

	virtual TextureID GetFlameTexture()
	{
		TextureID tex;
		tex.SetInvalid();
		return tex;
	}

	override void DoControlEffect()
	{
		if (GetParticlesQuality() >= TOMPART_MED) 
		{
			FSpawnParticleParams smoke;
			double rad = owner.radius * 0.6;
			smoke.pos = owner.pos + (
				frandom[tsfx](-rad,rad), 
				frandom[tsfx](-rad,rad), 
				frandom[tsfx](owner.height*0.4,owner.height)
			);
			TextureID tex = GetFlameTexture();
			if (tex.IsValid())
			{
				smoke.texture = tex;
			}
			smoke.color1 = GetFlameColor();
			// pass renderstyle from this class if not normal:
			if (GetRenderStyle() != STYLE_Normal)
			{
				smoke.style = GetRenderStyle();
			}
			// otherwise apply based on use of color:
			else if (smoke.color1 != -1)
			{
				smoke.style = STYLE_AddShaded;
			}
			else
			{
				smoke.style = STYLE_Add;
			}
			smoke.vel = (frandom[sfx](-0.2,0.2),frandom[sfx](-0.2,0.2),frandom[sfx](0.5,1.2));
			smoke.size = frandom[sfx](35, 50) * scale.x;
			smoke.flags = SPF_ROLL|SPF_REPLACE|SPF_LOCAL_ANIM;
			smoke.lifetime = random[sfx](60, 100);
			smoke.sizestep = smoke.size * 0.03;
			smoke.startalpha = alpha;
			smoke.fadestep = -1;
			smoke.startroll = random[sfx](0, 359);
			smoke.rollvel = frandom[sfx](-4,4);
			Level.SpawnParticle(smoke);
		}
	}
}

mixin class ToM_PickupSound 
{
	//default PlayPickupSound EXCEPT the sounds 
	// can play over each other
	override void PlayPickupSound (Actor toucher)	
	{
		double atten;
		int chan;
		int flags = 0;

		if (bNoAttenPickupSound)
			atten = ATTN_NONE;
		else
			atten = ATTN_NORM;
		if (toucher != NULL && toucher.CheckLocalView()) 
		{
			chan = CHAN_ITEM;
			flags = CHANF_NOPAUSE | CHANF_MAYBE_LOCAL | CHANF_OVERLAP;
		}
		else 
		{
			chan = CHAN_ITEM;
			flags = CHANF_MAYBE_LOCAL;
		}
		
		toucher.A_StartSound(PickupSound, chan, flags, 1, atten);
	}
}

mixin class ToM_PickupFlashProperties
{
	color flashColor;
	int flashDuration;
	double flashAlpha;
	//protected int flashTimer;
	property flashColor : flashColor;
	property flashDuration : flashDuration;
	property flashAlpha : flashAlpha;

	override bool TryPickup (in out Actor toucher)
	{
		let ret = super.TryPickup(toucher);
		if (ret && toucher)
		{
			toucher.A_SetBlend(flashColor, flashAlpha, flashDuration);
		}
		return ret;
	}
}

mixin class ToM_ComplexPickupmessage
{
	string pickupNote;
	property pickupNote : pickupNote;

	override string PickupMessage()
	{
		string finalmsg = StringTable.Localize(pickupMsg);
		
		string note = GetPickupNote();
		if (note)
		{
			finalmsg = String.Format("%s %s", finalmsg, note);
		}
		
		return finalmsg;
	}
	
	virtual string GetPickupNote() 
	{
		return StringTable.Localize(pickupNote);
	}
}

class ToM_Inventory : Inventory
{
	mixin ToM_CheckParticles;
	mixin ToM_PickupFlashProperties;
	mixin ToM_PickupSound;
	mixin ToM_ComplexPickupmessage;
}