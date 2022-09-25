class ToM_Knife : ToM_BaseWeapon
{
	bool rightSlash;
	int combo;
	int trailFrame;
	int knifeReload;
	
	enum knifeconsts
	{
		KNIFE_RELOAD_TIME = 88,
		KNIFE_PARTIAL_RELOAD_TIME = 6,
		KNIFE_RELOAD_FRAME = 11,
		KNIFE_READY_FRAME = 0,
	}
	
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
		SetKnifeFrame();
		if (invoker.knifeReload > 0)
		{
			flags |= WRF_NOFIRE;
		}
		/*else
		{
			player.SetPSprite(APSP_TopFX, ResolveState("Null"));
			player.SetPSprite(APSP_Overlayer, ResolveState("Null"));
			//A_DoIdleAnimation(4, 60);
		}*/
		A_WeaponReady(flags);
	}
	
	action void SetKnifeFrame()
	{
		//let psp = player.FindPSprite(PSP_Weapon);
		//if (!psp) return;
		//psp.frame = (invoker.knifeReload > 0) ? KNIFE_RELOAD_FRAME :  KNIFE_READY_FRAME;
		//psp.sprite = GetSpriteIndex( (invoker.knifeReload > 0) ? KNIFE_RELOAD_SPRITE : KNIFE_READY_SPRITE );
		if (invoker.knifeReload > 0)
		{
			A_OverlayFlags(OverlayID(), PSPF_FORCEALPHA, true);
			A_OverlayAlpha(OverlayID(), 0);
		}
		else 
		{
			A_OverlayFlags(OverlayID(), PSPF_FORCEALPHA, false);
			A_OverlayAlpha(OverlayID(), 1.0);
		}
	}
	
	override void DoEffect()
	{
		super.DoEffect();
		if (!owner || !owner.player || owner.health <= 0 || owner.isFrozen())
			return;
		if (knifeReload > 0)
		{
			knifeReload--;
			if (knifeReload <= 0)
				owner.A_StartSound("weapons/knife/restore", CHAN_AUTO);
			else
			{
				let weap = owner.player.readyweapon;
				let plr = owner.player;
				if (plr && weap && weap == self)
				{
					let psp = plr.FindPSprite(APSP_Overlayer);
					if (!psp)
						plr.SetPSprite(APSP_Overlayer, ResolveState("RestoreKnife"));
				}
			}
		}
	}
	
	States
	{
	Spawn:
		ALVB A -1;
		stop;
	Select:
		TNT1 A 0 
		{
			A_WeaponOffset(-24, 86);
			A_OverlayPivot(OverlayID(), 0.6, 0.8);
			A_RotatePSprite(OverlayID(), 30);		
			SetKnifeFrame();
		}
		VKNF ###### 1
		{
			A_WeaponOffset(4, -9, WOF_ADD);
			A_RotatePSprite(OverlayID(), -5, WOF_ADD);
			A_WeaponReady(WRF_NOFIRE|WRF_NOBOB);
		}
		goto Ready;
	Deselect:
		TNT1 A 0 
		{
			A_OverlayPivot(OverlayID(), 1, 1);	
			let psp = player.FindPSprite(PSP_Weapon);
			SetKnifeFrame();
		}
		VKNF ###### 1
		{
			A_WeaponOffset(-4, 9, WOF_ADD);
			A_RotatePSprite(OverlayID(), 5, WOF_ADD);
		}
		TNT1 A 0 A_Lower;
		wait;
	Ready:
		TNT1 A 0 
		{
			//A_ResetPSprite(OverlayID());
			invoker.rightSlash = false;
			invoker.combo = 0;
		}
		VKNF A 1 
		{
			A_KnifeReady();
		}
		wait;
	IdleAnim:
		VKNI AABC 2 A_WeaponReady(WRF_NOBOB);
		VKNI DDEEFFGGHHIIJJKK 1 
		{
			A_RotatePSprite(OverlayID(), 2);
			A_WeaponReady(WRF_NOBOB);
		}
		VKNI LLMMNNOO 1 
		{
			A_RotatePSprite(OverlayID(), -4);
			A_WeaponReady(WRF_NOBOB);
		}
		VKNI BAA 2 A_WeaponReady(WRF_NOBOB);
		goto Ready;
	Fire:
		TNT1 A 0 
		{
			invoker.trailFrame = 0;
			invoker.combo++;
			if (invoker.combo >= 5)
			{
				invoker.combo = 0;
				return ResolveState("DownSlash");
			}
			invoker.rightSlash = !invoker.rightSlash;
			let st = invoker.rightSlash ? ResolveState("RightSlash") : ResolveState("LeftSlash");			
			return st;
		}
	RightSlash:
		TNT1 A 0 
		{
			A_ResetPSprite(OverlayID());
			A_OverlayPivot(OverlayID(), 0.5, 0.5);
			A_RotatePSprite(OverlayID(), frandom[wrot](-15,0), WOF_INTERPOLATE);
		}
		VKNF AAABB 1
		{
			A_WeaponOffset(16, 0, WOF_ADD);
			A_RotatePSprite(OverlayID(), -5.5, WOF_ADD);
		}
		TNT1 A 0 A_StartSound("weapons/knife/swing", CHAN_AUTO);
		VKNF BBB 1
		{
			A_WeaponOffset(-55, 0, WOF_ADD);
			A_RotatePSprite(OverlayID(), 5, WOF_ADD);
		}
		TNT1 C 0
		{
			A_CustomPunch(15, true, CPF_NOTURN, "ToM_KnifePuff");
		}
		VKNS CCC 1
		{
			A_WeaponOffset(-55, 0, WOF_ADD);
			A_RotatePSprite(OverlayID(), 3, WOF_ADD);
		}
		VKNF CCCHHHHAAA 1
		{
			A_ResetPSprite(OverlayID(), 10);
			//A_WeaponReady(WRF_NOBOB);
		}
		goto ready;
	LeftSlash:
		TNT1 A 0 
		{
			A_ResetPSprite(OverlayID());
			A_OverlayPivot(OverlayID(), 0.9, 0.7);
			A_RotatePSprite(OverlayID(), frandom[wrot](0,15), WOF_INTERPOLATE);
		}
		VKNF ADDEE 1
		{
			A_WeaponOffset(-32, -4, WOF_ADD);
			A_RotatePSprite(OverlayID(), 3, WOF_ADD);
		}
		TNT1 A 0 A_StartSound("weapons/knife/swing", CHAN_AUTO);
		VKNF EEE 1
		{
			A_WeaponOffset(44, 4, WOF_ADD);
			A_RotatePSprite(OverlayID(), -5, WOF_ADD);
		}		
		TNT1 E 0 
		{
			A_CustomPunch(15, true, CPF_NOTURN, "ToM_KnifePuff");
		}
		VKNS FFF 1
		{
			A_WeaponOffset(44, 4, WOF_ADD);
			A_RotatePSprite(OverlayID(), -3, WOF_ADD);
		}
		VKNF FFFEEEDDAA 1
		{
			A_ResetPSprite(OverlayID(), 10);
			A_WeaponReady(WRF_NOBOB);
		}
		goto ready;
	DownSlash:
		TNT1 A 0 
		{
			A_ResetPSprite(OverlayID());
			A_OverlayPivot(OverlayID(), 0.5, 1);
			A_RotatePSprite(OverlayID(), frandom[wrot](-5,15), WOF_INTERPOLATE);
		}
		VKNF GGGG 1
		{
			A_WeaponOffset(5, -4, WOF_ADD);
		}
		TNT1 A 0 A_StartSound("weapons/knife/swing", CHAN_AUTO);		
		VKNF GGH 1
		{
			A_WeaponOffset(-12, 24, WOF_ADD);
		}		
		TNT1 H 0 
		{
			A_CustomPunch(25, true, CPF_NOTURN, "ToM_KnifePuff");
		}
		VKNS HHHH 1
		{
			A_WeaponOffset(-18, 24, WOF_ADD);
		}
		VKNF HHHHZZZZZ 1
		{
			A_ResetPSprite(OverlayID(), 9);
			A_WeaponReady(WRF_NOBOB);
		}
		goto ready;
	AltFire:
		TNT1 A 0 A_ResetPSprite(OverlayID());
		VKNF HHH 1
		{
			A_WeaponOffset(4, -3, WOF_ADD);
			A_RotatePSprite(OverlayID(), -1.5, WOF_ADD);
		}
		TNT1 A 0 A_StartSound("weapons/knife/throw", CHAN_WEAPON);
		VKNF IIII 1
		{
			A_WeaponOffset(3, -1.5, WOF_ADD);
			A_RotatePSprite(OverlayID(), -1, WOF_ADD);
		}
		VKNF JJJ 1 
		{
			A_WeaponOffset(-5, 15, WOF_ADD);
			A_RotatePSprite(OverlayID(), 4, WOF_ADD);
		}
		TNT1 A 0 
		{
			A_StopSound(CHAN_WEAPON);
			A_FireProjectile("ToM_KnifeProjectile");
		}
		VKNF KKK 1 
		{
			A_WeaponOffset(-5, 8, WOF_ADD);
			A_RotatePSprite(OverlayID(), 3, WOF_ADD);
		}
		VKNF KKK 1 A_WeaponOffset(-1.6, 2, WOF_ADD);
		VKNF KK 1 A_WeaponOffset(-0.5, 1, WOF_ADD);
		TNT1 A 0
		{
			invoker.knifeReload = KNIFE_RELOAD_TIME;
		}
		TNT1 AAAAAAAA 1 
		{
			A_ResetPSprite(OverlayID(), 8);
			A_WeaponReady(WRF_NOBOB|WRF_NOFIRE);
		}
		goto Ready;
	RestoreKnife:
		VKNR A 1
		{
			A_SpawnPSParticle("RestoreKnifeParticle", density: 4, xofs: 80, yofs: 80);
			
			if (invoker.knifeReload <= KNIFE_PARTIAL_RELOAD_TIME)
			{
				return ResolveState("RestoreKnifeEnd");
			}
			return ResolveState(null);
		}
		loop;
	RestoreKnifeEnd:
		VKNR BCDEFG 1;
		stop;
	RestoreKnifeParticle:
		TNT1 A 0 {
			A_OverlayPivotAlign(OverlayID(),PSPA_CENTER,PSPA_CENTER);
			A_OverlayFlags(OverlayID(),PSPF_RENDERSTYLE|PSPF_FORCEALPHA,true);
			A_OverlayRenderstyle(OverlayID(),Style_Add);
			A_OverlayAlpha(OverlayID(),0);
			A_OverlayScale(OverlayID(),0.05,0.05);
		}
		VKNP AAAAAAAAAAAAAA 1 bright {
			A_OverlayScale(OverlayID(),0.05,0.05,WOF_ADD);
			let psp = player.FindPSprite(OverlayID());
			if (psp) {
				psp.alpha = Clamp(psp.alpha + 0.05, 0, 0.5);
				A_OverlayOffset(OverlayID(),psp.x * 0.9, psp.y * 0.9, WOF_INTERPOLATE);
			}
		}
		stop;
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
}

class ToM_KnifeProjectile : ToM_StakeProjectile
{
	actor knifemodel;
	
	Default
	{
		seesound "";
		//deathsound "weapons/knife/throwwall";
		renderstyle "Translucent";
		speed 25;
		damage (40);
		-NOGRAVITY
		gravity 0.2;
		radius 10;
		height 6;
		ToM_Projectile.ShouldActivateLines true;
	}
	
	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		A_StartSound("weapons/knife/throw", CHAN_AUTO, startTime: 0.25);
		knifemodel = Spawn("ToM_KnifeProjectileModel", pos);
		knifemodel.angle = angle;
		knifemodel.pitch = pitch;			
	}
	
	override void Tick()
	{
		super.Tick();
		if (knifemodel)
			knifemodel.SetOrigin(pos, true);
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
		TNT1 A 1
		{
			A_StartSound("weapons/knife/throwflesh");
			if (knifemodel)
				knifemodel.Destroy();
		}
		stop;
	Death:
		TNT1 A 50
		{
			FireLineActivator();
			A_StopSound(CHAN_BODY);
			A_StartSound("weapons/knife/throwwall");
			if (knifemodel)
				knifemodel.A_SetPitch(pitch);
			StickToWall();
		}
		TNT1 A 0
		{
			if (knifemodel)
				knifemodel.A_SetRenderstyle(alpha, Style_Translucent);
		}
		TNT1 A 1 
		{
			if (knifemodel)
				knifemodel.A_FadeOut(0.1);
			A_FadeOut(0.1);
		}
		wait;
	}
}

class ToM_KnifeProjectileModel : Actor
{
	Default
	{
		+NOINTERACTION
	}
	States
	{
	Spawn:
		TNT1 A 0;
		MODL A -1;
		stop;
	}
}