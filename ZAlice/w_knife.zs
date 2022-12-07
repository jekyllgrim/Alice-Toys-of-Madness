class ToM_Knife : ToM_BaseWeapon
{	
	bool rightSlash; //right slash or left slash?
	int combo; //combo counter
	
	const MAXRECALLTIME = 35 * 7; //recall knife after this wait time
	ToM_KnifeProjectile knife; //pointer to thrown knife
	protected bool knifeWasThrown; //true if thrown
	protected int recallWait; //recall timer
	
	protected int clawResetWait;
	
	Default 
	{
		+WEAPON.MELEEWEAPON;
		+WEAPON.NOAUTOFIRE;
		//Obituary "";
		Tag "Vorpal Knife";
		weapon.slotnumber 1;
		//inventory.icon "";
		//weapon.upsound "weapons/knife/draw";
	}
	
	action void A_KnifeReady(int flags = 0)
	{
		if (!player)
			return;
		
		if (invoker.knifeWasThrown)
		{
			flags |= WRF_NOPRIMARY;
		}
		
		if (HasRageBox())
		{
			A_Overlay(APSP_LeftHand, "LeftHandClaw", true);
			flags |= WRF_NOSWITCH;
		}
		
		A_WeaponReady(flags);
	}
	
	action void A_SetKnifeSprite(name defsprite, name ragesprite = '')
	{
		if (!player)
			return;
		
		let psp = player.FindPSprite(OverlayID());
		if (!psp)
			return;
		
		if (ragesprite && HasRageBox())
			psp.sprite = GetSpriteIndex(ragesprite);
		
		else
			psp.sprite = GetSpriteIndex(defsprite);
	}
	
	action void A_KnifeSlash(double damage = 10)
	{
		A_CustomPunch(damage, true, CPF_NOTURN, "ToM_KnifePuff", range: 80);
	}
	
	// Throws the knife and saves a pointer to it:
	action void A_ThrowKnife()
	{
		A_StopSound(CHAN_WEAPON);
		Actor a, b;
		[a, b] = A_FireProjectile("ToM_KnifeProjectile");
		if (b)
		{
			invoker.knife = ToM_KnifeProjectile(b);
			invoker.knifeWasThrown = true;
			invoker.recallWait = MAXRECALLTIME;
		}
	}	
	
	// Calls the knife projectile to begin recalling
	// and activates the "recall particles" if not
	// yet active:
	action void A_RecallKnife()
	{
		if (invoker.knife && player)
		{
			invoker.knife.BeginRecall();
			
			if (player.readyweapon && player.readyweapon == invoker)
			{
				A_Overlay(APSP_Overlayer, "SpawnRecallParticles", true);
			}
		}
	}
	
	action void A_MoveLeftHandAside(vector2 step = (8, 8), vector2 limit = (40, 40))
	{
		/*if (!player)
			return;
		
		let psp = player.FindPSprite(APSP_LeftHand);
		if (!psp)
			return;
		
		A_StopPSpriteReset(APSP_LeftHand);
		//invoker.clawResetWait = 35 * 2;
		psp.x = Clamp(psp.x + step.x, step.x, limit.x);
		psp.y = Clamp(psp.y + step.y, step.y, limit.y);
		
		console.printf("Left hand ofs: %.1f, %.1f", psp.x, psp.y);*/
	}
		
	
	void CatchKnife()
	{
		if (!owner || !owner.player)
			return;
		
		knife = null;
		owner.A_StartSound("weapons/knife/restore", CHAN_AUTO);
		
		let weap = owner.player.readyweapon;
		if (weap && weap == self)
		{
			let psp = owner.player.FindPSprite(PSP_WEAPON);
			if (psp && !InStateSequence(psp.curstate, ResolveState("CatchKnife")))
				psp.SetState(ResolveState("CatchKnife"));
		}
		knifeWasThrown = false;
		
		console.printf("Knife successfully recalled");
	}
		
	
	override void DoEffect()
	{
		super.DoEffect();
		if (!owner || !owner.player || owner.health <= 0)
			return;
		
		// Safety-check: if the bool says the knife was 
		// thrown but we don't have a valid pointer 
		// to the knife, just restore it by setting
		// the bool to false:
		if (knifeWasThrown && !knife)
		{
			knifeWasThrown = false;
		}
		
		// Automatic recall handling:
		if (recallWait > 0)
		{
			// Decrement timer:
			recallWait--;
			
			// If we're out of time and knife was 
			// actually thrown:
			if (recallWait <= 0 && knifeWasThrown)
			{
				// If the knife pointer is still valid,
				// initate the recall:
				if (knife)
				{
					knife.BeginRecall();
				}
				// Otherwise do the recall anyway
				// and restore the knife in our hand:
				else
				{
					if (tom_debugmessages)
						console.printf("Lost pointer to thrown knife; restoring automatically");
					CatchKnife();
				}
			}
		}
	}
	
	States
	{
	Spawn:
		ALVB A -1;
		stop;
	SelectRage:
		TNT1 A 0 
		{
			A_WeaponOffset(0, WEAPONTOP);
			vector2 piv = (0.2, 0.3);
			A_OverlayPivot(OverlayID(), piv.x, piv.y);
			A_Overlay(APSP_LeftHand, "SelectRageLeftHand");
			A_OverlayPivot(APSP_LeftHand, piv.x, piv.y);
		}
		VRAG ABCDEF 2 { player.viewheight -= 2; }
		VRAG FFFGGGHHHIIIIIIIIIIIIIIIIIIIIIIIIII 5 A_OverlayOffset(OverlayID(), frandom[sfx](-1,1), frandom[sfx](-1,1), WOF_ADD);
		TNT1 A 0 A_OverlayPivot(OverlayID(), 0.6, 0.6);
		VRAG JKLMNO 2 A_RotatePSprite(OverlayID(), 3, WOF_ADD);
		TNT1 A 0 A_RotatePSPrite(OverlayID(), 0, WOF_ADD);
		VKRR BCDEFG 1 { player.viewheight += 2; }
		goto ready;
	SelectRageLeftHand:
		VRAG ABCDEF 2;
		VRAG FFFGGGHHHIIIIIIIIIIIIIIIIIIIIIIIIII 5 A_OverlayOffset(OverlayID(), frandom[sfx](-1,1), frandom[sfx](-1,1), WOF_ADD);
		TNT1 A 0 A_OverlayPivot(OverlayID(), 0.6, 0.6);
		VRAG JKL 2;
		VRAG M 5;
		VCLS AB 2;
		VCLS C 10;
		VCLS D 3;
		goto LeftHandClaw;
	LeftHandClaw:
		TNT1 A 0
		{
			A_OverlayPivot(OverlayID(), 0.2, 0.3);
			A_OverlayFlags(OverlayID(), PSPF_FLIP|PSPF_MIRROR, true);
			A_OverlayFlags(OverlayID(), PSPF_ADDWEAPON, false);
			A_OverlayOffset(OverlayID(), 0, WEAPONTOP);
		}
		VCLW A 1 
		{
			if (!HasRageBox())
				return ResolveState("Null");
			return ResolveState(null);
		}
		wait;
	Select:
		VKNF A 0 
		{
			if (HasRageBox())
			{
				return ResolveState("SelectRage");
			}
			
			if (invoker.knifeWasThrown)
				A_SetKnifeSprite("VKNR");
				
			A_WeaponOffset(-24, 86);
			A_OverlayPivot(OverlayID(), 0.6, 0.8);
			A_RotatePSprite(OverlayID(), 30);
			return ResolveState(null);
		}
		#### ###### 1
		{
			A_WeaponOffset(4, -9, WOF_ADD);
			A_RotatePSprite(OverlayID(), -5, WOF_ADD);
			A_KnifeReady(WRF_NOFIRE|WRF_NOBOB);
		}
		goto Ready;
	Deselect:
		VKNF A 0 
		{
			if (invoker.knifeWasThrown)
				A_SetKnifeSprite("VKNR");

			A_OverlayPivot(OverlayID(), 1, 1);	
			let psp = player.FindPSprite(PSP_Weapon);
		}
		#### ###### 1
		{
			A_WeaponOffset(-4, 9, WOF_ADD);
			A_RotatePSprite(OverlayID(), 5, WOF_ADD);
		}
		TNT1 A 0 A_Lower;
		wait;
	Ready:
		TNT1 A 0 
		{
			invoker.rightSlash = false;
			A_ResetPSprite(APSP_LeftHand, 20);
		}
		#### A 1 
		{
			if (invoker.knifeWasThrown) {
				A_SetKnifeSprite("VKNR", "VKRR");
				//if ((player.cmd.buttons & BT_ALTATTACK) && (player.oldbuttons & BT_ALTATTACK))
					//return ResolveState("AltFire");
			}
			else
				A_SetKnifeSprite("VKNF", "VKRF");
			
			if (invoker.combo > 0 && level.maptime % 5 == 0)
			{
				invoker.combo -= 1;
				if (tom_debugmessages > 1)
					console.printf("Knife combo counter: %d", invoker.combo);
			}
			A_KnifeReady();
			return ResolveState(null);
		}
		wait;
	Fire:
		TNT1 A 0 
		{
			A_StopPSpriteReset();
			invoker.combo++;
			if (invoker.combo % 5 == 0)
			{
				return ResolveState("DownSlash");
			}
			invoker.rightSlash = !invoker.rightSlash;
			return invoker.rightSlash ? ResolveState("RightSlash") : ResolveState("LeftSlash");
		}
	RightSlash:
		TNT1 A 0 
		{
			A_SetKnifeSprite("VKNF", "VKRF");
			A_OverlayPivot(OverlayID(), 0.5, 0.5);
			A_RotatePSprite(OverlayID(), frandom[psprot](-20,0), WOF_INTERPOLATE);
		}
		#### BBB 1
		{
			A_WeaponOffset(20, 0, WOF_ADD);
			A_RotatePSprite(OverlayID(), -5.5, WOF_ADD);
			A_MoveLeftHandAside();
		}
		#### A 0 A_StartSound("weapons/knife/swing", CHAN_AUTO);
		#### BBB 1
		{
			A_WeaponOffset(-60, 0, WOF_ADD);
			A_OverlayOffset(APSP_LeftHand, 8, 8, WOF_ADD);
			A_RotatePSprite(OverlayID(), 5, WOF_ADD);
		}
		TNT1 A 0 
		{
			A_KnifeSlash(25);
			A_SetKnifeSprite("VKNS", "VKRS");
		}
		#### CCC 1
		{
			A_WeaponOffset(-44, 0, WOF_ADD);
			A_OverlayOffset(APSP_LeftHand, 4, 4, WOF_ADD);
			A_RotatePSprite(OverlayID(), 3, WOF_ADD);
		}
		TNT1 A 0 
		{
			A_ResetPSprite(OverlayID(), 10);
			A_SetKnifeSprite("VKNF", "VKRF");
		}
		#### CCCHHHHAAA 1 A_KnifeReady(WRF_NOBOB);
		goto ready;
	LeftSlash:
		TNT1 A 0 
		{
			A_SetKnifeSprite("VKNF", "VKRF");
			A_OverlayPivot(OverlayID(), 0.9, 0.7);
			A_RotatePSprite(OverlayID(), frandom[psprot](0,20), WOF_INTERPOLATE);
		}
		#### EEE 1
		{
			A_WeaponOffset(-24, -4, WOF_ADD);
			A_RotatePSprite(OverlayID(), 3, WOF_ADD);
			A_MoveLeftHandAside();
		}
		#### A 0 A_StartSound("weapons/knife/swing", CHAN_AUTO);
		#### EEE 1
		{
			A_WeaponOffset(80, 4, WOF_ADD);
			A_OverlayOffset(APSP_LeftHand, 8, 10, WOF_ADD);
			A_RotatePSprite(OverlayID(), -5, WOF_ADD);
		}		
		#### E 0 
		{
			A_KnifeSlash(25);
			A_SetKnifeSprite("VKNS", "VKRS");
		}
		#### FFF 1
		{
			A_WeaponOffset(65, 4, WOF_ADD);
			A_OverlayOffset(APSP_LeftHand, 5, 7, WOF_ADD);
			A_RotatePSprite(OverlayID(), -3, WOF_ADD);
		}
		#### A 0 
		{
			A_ResetPSprite(OverlayID(), 10);
			A_SetKnifeSprite("VKNF", "VKRF");
		}
		#### FFFEEEDDAA 1 A_KnifeReady(WRF_NOBOB);
		goto ready;
	DownSlash:
		TNT1 A 0 
		{
			A_SetKnifeSprite("VKNF", "VKRF");
			A_OverlayPivot(OverlayID(), 0.5, 1);
			A_RotatePSprite(OverlayID(), frandom[wrot](-5,25), WOF_INTERPOLATE);
		}
		#### GG 1 A_WeaponOffset(6, -5, WOF_ADD);
		#### A 0 A_StartSound("weapons/knife/swing", CHAN_AUTO);		
		#### GGH 1 
		{
			A_WeaponOffset(-12, 35, WOF_ADD);
			A_MoveLeftHandAside((11, 8));
		}
		TNT1 A 0  
		{
			A_KnifeSlash(35);
			A_SetKnifeSprite("VKNS", "VKRS");
		}
		#### HHHH 1 
		{
			A_WeaponOffset(-18, 25, WOF_ADD);
			A_OverlayOffset(APSP_LeftHand, 8, 4, WOF_ADD);
		}
		TNT1 A 0 
		{
			A_ResetPSprite(OverlayID(), 9);
			A_SetKnifeSprite("VKNF", "VKRF");
		}
		#### HHHHZZZZZ 1 A_KnifeReady(WRF_NOBOB);
		goto ready;
	RecallKnife:
		#### # 1 A_RecallKnife();
		goto ready;
	AltFire:
		#### # 0 
		{
			if (invoker.knifeWasThrown)
			{
				return ResolveState("RecallKnife");
			}
			A_ResetPSprite(OverlayID());
			A_SetKnifeSprite("VKNF", "VKRF");
			return ResolveState(null);
		}
		#### HHH 1
		{
			A_WeaponOffset(4, -3, WOF_ADD);
			A_RotatePSprite(OverlayID(), -1.5, WOF_ADD);
		}
		#### A 0 A_StartSound("weapons/knife/throw", CHAN_WEAPON);
		#### IIII 1
		{
			A_WeaponOffset(3, -1.5, WOF_ADD);
			A_RotatePSprite(OverlayID(), -1, WOF_ADD);
		}
		#### JJJ 1 
		{
			A_WeaponOffset(-5, 15, WOF_ADD);
			A_RotatePSprite(OverlayID(), 4, WOF_ADD);
		}
		#### A 0 A_ThrowKnife();
		#### KKK 1 
		{
			A_WeaponOffset(-5, 8, WOF_ADD);
			A_RotatePSprite(OverlayID(), 3, WOF_ADD);
		}
		#### KKK 1 A_WeaponOffset(-1.6, 2, WOF_ADD);
		#### KK 1 A_WeaponOffset(-0.5, 1, WOF_ADD);
		TNT1 A 0 
		{
			A_SetKnifeSprite("VKNR", "VKRR");
			A_ResetPSprite(OverlayID(), 6);
			A_RotatePSprite(OverlayID(), 10, WOF_ADD);
		}
		#### AAAAAA 1 A_KnifeReady(WRF_NOBOB|WRF_NOFIRE);
		goto Ready;
	CatchKnife:
		TNT1 A 0 
		{
			A_SetKnifeSprite("VKNR", "VKRR");
			A_WeaponOffset(15, 20);
			A_OverlayRotate(OverlayID(), -10);
			invoker.knifeWasThrown = false;
			A_ResetPSprite(OverlayID(), 6);
		}
		#### BCDEFG 1;
		goto Ready;
	SpawnRecallParticles:
		TNT1 A 1
		{
			A_SpawnPSParticle("RecallKnifeParticle", density: 4, xofs: 80, yofs: 80);
			if (!invoker.knifeWasThrown)
				return ResolveState("Null");
			
			return ResolveState(null);
		}
		wait;
	RecallKnifeParticle:
		TNT1 A 0 
		{
			A_OverlayPivotAlign(OverlayID(),PSPA_CENTER,PSPA_CENTER);
			A_OverlayFlags(OverlayID(),PSPF_RENDERSTYLE|PSPF_FORCEALPHA,true);
			A_OverlayRenderstyle(OverlayID(),Style_Add);
			A_OverlayAlpha(OverlayID(),0);
			A_OverlayScale(OverlayID(),0.05,0.05);
		}
		VKNP AAAAAAAAAAAAAA 1 bright 
		{
			A_OverlayScale(OverlayID(),0.05,0.05,WOF_ADD);
			let psp = player.FindPSprite(OverlayID());
			if (psp) {
				psp.alpha = Clamp(psp.alpha + 0.05, 0, 0.5);
				A_OverlayOffset(OverlayID(),psp.x * 0.9, psp.y * 0.9, WOF_INTERPOLATE);
			}
		}
		stop;
	Cache:
		VKNF A 0;
		VKNS A 0;
		VKNR A 0;
		VKRF A 0;
		VKRS A 0;
		VKRR A 0;
	}
}


class ToM_KnifePuff : ToM_BasePuff
{
	Default
	{
		+NOINTERACTION
		+PUFFONACTORS
		seesound "weapons/knife/hitflesh";
		attacksound "weapons/knife/hitwall";
	}
	
	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		if (target && target.player)
		{
			let weap = ToM_Knife(target.player.readyweapon);
			if (weap)
			{
				int forcePainChance = ToM_UtilsP.LinearMap(weap.combo, 0, 5, 15, 80);
				bFORCEPAIN = (random[knifepain](0, 100) <= forcePainChance);
			}
		}
	}
}

// The actual knife projectile with all the logic
// and behavior. The 3D model is NOT attached to
// it; see ToM_KnifeProjectileModel for that.
class ToM_KnifeProjectile : ToM_StakeProjectile
{
	Actor knifemodel; //the actor that the 3d model is attached to
	int bleedDelay;
	int deathDelay;
	
	enum EKnifeValues
	{
		KV_RECALLSPEED = 34,
		KV_BLEEDELAYMIN = 15,
		KV_BLEEDELAYMAX = 40,
		KV_BLEEDDAMAGE = 5,
		KV_DEATHRECALLTIME = 35 * 2,
	}		
	
	static const color RecallColors[] =
	{
		"c6c3ff",
		"b5a7ff",
		"9275ff",
		"4d42ff"
	};
	
	Default
	{
		seesound ""; //Called from the weapon, not here
		deathsound "";
		renderstyle "Translucent";
		speed 25;
		damage (20);
		-NOGRAVITY
		+HITTRACER
		gravity 0.2;
		radius 4;
		height 20;
		ToM_Projectile.ShouldActivateLines true;
	}
	
	// Called from the weapon to start recalling the knife:
	void BeginRecall()
	{
		// If NOCLIP is true, the knife is already
		// being recalled; do nothing:
		if (bNOCLIP)
		{
			if (tom_debugmessages)
				console.printf("Knife is already being recalled");
			return;
		}

		if (tom_debugmessages)
			console.printf("Recalling knife");		
		
		if (tracer && tracer.bISMONSTER && tracer.health <= 0 && !tracer.bNOBLOOD)
		{
			for (int i = 4; i > 0; i--)
			{
				tracer.SpawnBlood(pos, tracer.AngleTo(self) + frandom[knifebleed](-15,15), 40);
			}
		}
		
		A_Stop();
		tracer = null;
		// Disable sticking-to-wall behavior - see StickToWall()
		// Without this the knife's pos.z would be forcefully
		// attached to a plane if it hit a 2-sided wall.
		// That behavior checks for bTHRUACTORS, so by disabling
		// it we disable the sticking behavior.
		// See ToM_StakeProjectile for details.
		bTHRUACTORS = false;
		bNOCLIP = true;
		SetStateLabel("Recall");
	}	
	
	// When run into a floor/ceiling by a moving wall,
	// recall it instead of destroying.
	// See ToM_StakeProjectile for details.
	override void StakeBreak()
	{
		BeginRecall();
	}
	
	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		A_StartSound("weapons/knife/throw", CHAN_AUTO, startTime: 0.25);
		knifemodel = Spawn("ToM_KnifeProjectileModel", pos);
		knifemodel.angle = angle;
		knifemodel.pitch = pitch;
		knifemodel.master = self;
		bleedDelay = random[knifebleed](KV_BLEEDELAYMIN, KV_BLEEDELAYMAX);
	}
	
	override void Tick()
	{
		super.Tick();
		if (isFrozen())
			return;
		
		if (knifemodel)
		{
			knifemodel.SetOrigin(pos, true);
			
			// If the knife is already stuck but not recalling,
			// adjust the model's angle and pitch to match it:
			if (bTHRUACTORS && !bNOCLIP)
			{
				knifemodel.angle = angle;
				knifemodel.pitch = pitch;
			}
			
			// Spawn the trail:
			if (!bTHRUACTORS)
			{
				let tr = Spawn("ToM_KnifeProjectileModel", pos);
				if (tr)
				{
					tr.angle = knifemodel.angle;
					tr.pitch = knifemodel.pitch;
				}
			}
		}
		
		// Auto-recall the knife after a delay if the victim
		// has already died:
		if (!bNOCLIP && tracer && tracer.bSHOOTABLE && tracer.health <= 0)
		{
			deathDelay++;
			if (deathDelay >= KV_DEATHRECALLTIME)
			{
				if (tom_debugmessages)
					console.printf("Victim has been dead for %d tics, recalling knife", deathDelay);
				BeginRecall();
			}
		}
		
		if (!target || !tracer || !tracer.bSHOOTABLE || tracer.health <= 0 || tracer.bNOBLOOD)
			return;
			
		// Do the bleed damage to the enemy the knife is stuck into.
		// Rather than employing a control item, I do it from the 
		// knife itself. It keeps things simpler and makes sure
		// the effect persists as long as the knife is stuck in
		// the victim:
		if (bleedDelay > 0)
		{
			bleedDelay--;
			if (bleedDelay <= 0)
			{
				bleedDelay = random[knifebleed](KV_BLEEDELAYMIN,KV_BLEEDELAYMAX);
				// 66% chance to not cause pain:
				int fflags = DMG_THRUSTLESS;
				if (random[knifebleed](1,3) != 1)
				{
					fflags |= DMG_NO_PAIN;
				}
				
				// do the damage:
				let dmg = tracer.DamageMobj(self,target,KV_BLEEDDAMAGE,"Bleed",flags:fflags);
				
				// If damage is > 0, spawn blood and the visuals:
				if (dmg > 0)
				{
					let al = Spawn("ToM_BleedLayer", tracer.pos);
					if (al)
						al.master = tracer;
					tracer.SpawnBlood(pos, tracer.AngleTo(self), dmg);
				}
			}
		}
	}			
	
	States
	{
	Spawn:
		TNT1 A 0 NoDelay 
		{
			A_StartSound("weapons/knife/fly", CHAN_BODY, CHANF_LOOPING, attenuation: 8);
		}
		TNT1 A 1
		{
			if (knifemodel)
				knifemodel.A_SetPitch(knifemodel.pitch + 25);
		}
		wait;
	XDeath:
		TNT1 A -1
		{
			StickToWall();
			A_StartSound("weapons/knife/throwflesh");
		}
		stop;
	Death:
		TNT1 A -1
		{
			A_StopSound(CHAN_BODY);
			A_StartSound("weapons/knife/throwwall");
			if (knifemodel)
				knifemodel.A_SetPitch(pitch);
			StickToWall();
		}
		stop;
	Recall:
		TNT1 A 1
		{
			if (target) 
			{
				vector3 vec = Vec3To(target) + (0,0,target.height * 0.75);
				vel = vec.Unit() * KV_RECALLSPEED;
				
				if (knifemodel)
				{
					A_FaceTarget(flags:FAF_MIDDLE);
					knifemodel.angle = angle + 180;
					knifemodel.pitch -= 10;
					for (int i = 8; i > 0; i--)
					{
						int c = random[eyec](0, RecallColors.Size() - 1);
						let col = RecallColors[c];
						A_SpawnParticle(
							col,
							SPF_FULLBRIGHT,
							lifetime: 20,
							size: 6,
							xoff: frandom[knifepart](-16,16),
							yoff: frandom[knifepart](-16,16),
							zoff: frandom[knifepart](-16,16),
							sizestep: -0.1
						);
					}
				}
				
				if (Distance3D(target) <= 64) 
				{
					let kn = ToM_Knife(target.FindInventory("ToM_Knife"));
					if (kn)
					{
						kn.CatchKnife();
					}
					
					if (knifemodel)
					{
						knifemodel.Destroy();
					}
					
					Destroy();
				}
			}
		}
		loop;
	}
}

class ToM_BleedLayer : ToM_ActorLayer
{
	Default
	{
		Renderstyle 'Stencil';
		stencilcolor "EE0000";
		alpha 0.8;
		ToM_ActorLayer.Fade 0.05;
	}
}

// The visual actor that the 3D model of the knife
// is attached to.
// If it has no master, it's used as a trail.
class ToM_KnifeProjectileModel : ToM_SmallDebris
{
	Default
	{
		+NOINTERACTION
		+NOBLOCKMAP
	}
	
	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		// If it has no master, apply trail visuals:
		if (!master)
		{
			A_SetRenderstyle(0.85, STYLE_Stencil);
			SetShade("BBBBBB");
		}
	}
	
	override void Tick()
	{
		super.Tick();
		// If it's a trail, fade it out:
		if (!master && !isFrozen())
		{
			A_FadeOut(0.045);
		}
	}
	
	States
	{
	Spawn:
		M000 A -1;
		stop;
	}
}