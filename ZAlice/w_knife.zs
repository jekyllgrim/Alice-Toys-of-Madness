class ToM_Knife : ToM_BaseWeapon
{
	bool rightSlash;
	int combo;
	int trailFrame;
	int knifeReload;
	
	enum knifeconsts
	{
		KNIFE_RELOAD_TIME = 75,
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
		if (invoker.knifeReload > 0)
		{
			flags |= WRF_NOFIRE;
		}
		
		if (CountInv("ToM_RageBoxInitEffect"))
		{
			A_Overlay(APSP_UnderLayer, "LeftHandClaw", true);
			flags |= WRF_NOSWITCH;
		}
		
		A_WeaponReady(flags);
	}
	
	action void A_KnifeReloadVisuals()
	{
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
	
	action void A_SetKnifeSprite(name defsprite, name ragesprite)
	{
		let psp = player.FindPSprite(OverlayID());
		if (HasRageBox())
			psp.sprite = GetSpriteIndex(ragesprite);
		else
			psp.sprite = GetSpriteIndex(defsprite);
	}
	
	action void A_KnifeSlash(double distance = 10)
	{
		A_CustomPunch(distance, true, CPF_NOTURN, "ToM_KnifePuff");
	}
	
	override void DoEffect()
	{
		super.DoEffect();
		if (!owner || !owner.player || owner.health <= 0)
			return;
			
		if (knifeReload > 0)
		{
			knifeReload--;
			if (knifeReload <= 0)
				owner.A_StartSound("weapons/knife/restore", CHAN_AUTO);
			else
			{
				let plr = owner.player;
				let weap = owner.player.readyweapon;
				if (plr && weap && weap == self)
				{
					let psp = plr.FindPSprite(APSP_Overlayer);
					if (!psp)
						plr.SetPSprite(APSP_Overlayer, ResolveState("RestoreKnife"));
				}
			}
		}
		
		/*let weap = owner.player.readyweapon;
		if (weap && weap == self)
		{
			let psp = owner.player.FindPSprite(PSP_WEAPON);
			if (psp)
				console.printf("Current frame: %d", psp.frame);
		}*/
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
			A_Overlay(APSP_Underlayer, "SelectRageLeftHand");
			A_OverlayFlags(APSP_Underlayer, PSPF_FLIP|PSPF_MIRROR, true);
			A_OverlayFlags(APSP_Underlayer, PSPF_ADDWEAPON, false);
			A_OverlayPivot(APSP_Underlayer, piv.x, piv.y);
			A_OverlayOffset(APSP_Underlayer, 10, WEAPONTOP + 10);
		}
		VRAG ABCDEF 2 { player.viewheight -= 2; }
		VRAG FFFGGGHHHIIIIIIIIIIIIIIIIIIIIIIIIII 5 A_OverlayOffset(OverlayID(), frandom[sfx](-1,1), frandom[sfx](-1,1), WOF_ADD);
		TNT1 A 0 A_OverlayPivot(OverlayID(), 0.6, 0.6);
		VRAG JKLMNO 2 A_RotatePSprite(OverlayID(), 3, WOF_ADD);
		TNT1 A 0 A_RotatePSPrite(OverlayID(), 0, WOF_ADD);
		VKRR BCDEFG 1 { player.viewheight += 2; }
		stop;
		goto ready;
	SelectRageLeftHand:
		VRAG ABCDEF 2;
		VRAG FFFGGGHHHIIIIIIIIIIIIIIIIIIIIIIIIII 5 A_OverlayOffset(OverlayID(), frandom[sfx](-1,1), frandom[sfx](-1,1), WOF_ADD);
		TNT1 A 0 A_OverlayPivot(OverlayID(), 0.6, 0.6);
		VRAG JKL 2;
		VRAG M 5;
		VCLW Z 10 A_OverlayScale(OverlayID(), 1.2, 1.2);
		VCLW A 7 A_ResetPSprite(OverlayID(), 7);
		goto LeftHandClaw;
	LeftHandClaw:
		VCLW A 1 
		{
			if (!HasRageBox())
				return ResolveState("Null");
			return ResolveState(null);
		}
		loop;
		/*VCLW AAAAAAAAAAAAAAAAAAAAAAAA 1 
		{
			A_OverlayOffset(OverlayID(), 0.1, 0.1, WOF_ADD);
			A_OverlayRotate(OverlayID(), -0.03, WOF_ADD);
		}
		VCLW A 40 A_ResetPSprite(OverlayID(), 40);*/
		loop;
	Select:
		TNT1 A 0 
		{
			if (CountInv("ToM_RageBoxInitEffect"))
			{
				return ResolveState("SelectRage");
			}
			A_WeaponOffset(-24, 86);
			A_OverlayPivot(OverlayID(), 0.6, 0.8);
			A_RotatePSprite(OverlayID(), 30);		
			A_KnifeReloadVisuals();
			return ResolveState(null);
		}
		VKNF ###### 1
		{
			A_WeaponOffset(4, -9, WOF_ADD);
			A_RotatePSprite(OverlayID(), -5, WOF_ADD);
			A_KnifeReady(WRF_NOFIRE|WRF_NOBOB);
		}
		goto Ready;
	Deselect:
		TNT1 A 0 
		{
			A_SetKnifeSprite("VKNF", "VKRF");
			A_OverlayPivot(OverlayID(), 1, 1);	
			let psp = player.FindPSprite(PSP_Weapon);
			A_KnifeReloadVisuals();
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
			invoker.rightSlash = false;
			invoker.combo = 0;
		}
		#### A 1 
		{
			A_SetKnifeSprite("VKNF", "VKRF");
			A_KnifeReloadVisuals();
			A_KnifeReady();
		}
		wait;
	/*IdleAnim:
		VKNI AABC 2 A_KnifeReady(WRF_NOBOB);
		VKNI DDEEFFGGHHIIJJKK 1 
		{
			A_RotatePSprite(OverlayID(), 2);
			A_KnifeReady(WRF_NOBOB);
		}
		VKNI LLMMNNOO 1 
		{
			A_RotatePSprite(OverlayID(), -4);
			A_KnifeReady(WRF_NOBOB);
		}
		VKNI BAA 2 A_KnifeReady(WRF_NOBOB);
		goto Ready;*/
	Fire:
		TNT1 A 0 
		{
			A_StopPSpriteReset();
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
			A_SetKnifeSprite("VKNF", "VKRF");
			A_OverlayPivot(OverlayID(), 0.5, 0.5);
			A_RotatePSprite(OverlayID(), frandom[wrot](-15,0), WOF_INTERPOLATE);
		}
		#### AABB 1
		{
			A_WeaponOffset(16, 0, WOF_ADD);
			A_RotatePSprite(OverlayID(), -5.5, WOF_ADD);
		}
		#### A 0 A_StartSound("weapons/knife/swing", CHAN_AUTO);
		#### BBB 1
		{
			A_WeaponOffset(-60, 0, WOF_ADD);
			A_RotatePSprite(OverlayID(), 5, WOF_ADD);
		}
		#### A 0 
		{
			A_KnifeSlash(25);
			A_SetKnifeSprite("VKNS", "VKRS");
		}
		VKNS CCC 1
		{
			A_WeaponOffset(-44, 0, WOF_ADD);
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
			A_RotatePSprite(OverlayID(), frandom[wrot](0,15), WOF_INTERPOLATE);
		}
		#### DDEE 1
		{
			A_WeaponOffset(-20, -4, WOF_ADD);
			A_RotatePSprite(OverlayID(), 3, WOF_ADD);
		}
		#### A 0 A_StartSound("weapons/knife/swing", CHAN_AUTO);
		#### EEE 1
		{
			A_WeaponOffset(80, 4, WOF_ADD);
			A_RotatePSprite(OverlayID(), -5, WOF_ADD);
		}		
		TNT1 E 0 
		{
			A_KnifeSlash(25);
			A_SetKnifeSprite("VKNS", "VKRS");
		}
		#### FFF 1
		{
			A_WeaponOffset(65, 4, WOF_ADD);
			A_RotatePSprite(OverlayID(), -3, WOF_ADD);
		}
		TNT1 A 0 
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
			A_RotatePSprite(OverlayID(), frandom[wrot](-5,15), WOF_INTERPOLATE);
		}
		#### GGG 1 A_WeaponOffset(5, -4, WOF_ADD);
		#### A 0 A_StartSound("weapons/knife/swing", CHAN_AUTO);		
		#### GGH 1 A_WeaponOffset(-12, 35, WOF_ADD);
		TNT1 A 0  
		{
			A_KnifeSlash(35);
			A_SetKnifeSprite("VKNS", "VKRS");
		}
		#### HHHH 1 A_WeaponOffset(-18, 25, WOF_ADD);
		TNT1 A 0 
		{
			A_ResetPSprite(OverlayID(), 9);
			A_SetKnifeSprite("VKNF", "VKRF");
		}
		#### HHHHZZZZZ 1 A_KnifeReady(WRF_NOBOB);
		goto ready;
	AltFire:
		TNT1 A 0 
		{
			A_ResetPSprite(OverlayID());
			A_SetKnifeSprite("VKNF", "VKRF");
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
		#### A 0 
		{
			A_StopSound(CHAN_WEAPON);
			A_FireProjectile("ToM_KnifeProjectile");
		}
		#### KKK 1 
		{
			A_WeaponOffset(-5, 8, WOF_ADD);
			A_RotatePSprite(OverlayID(), 3, WOF_ADD);
		}
		#### KKK 1 A_WeaponOffset(-1.6, 2, WOF_ADD);
		#### KK 1 A_WeaponOffset(-0.5, 1, WOF_ADD);
		TNT1 A 0
		{
			invoker.knifeReload = KNIFE_RELOAD_TIME;
		}
		TNT1 A 0 A_ResetPSprite(OverlayID(), 8);
		TNT1 AAAAAAAA 1 A_KnifeReady(WRF_NOBOB|WRF_NOFIRE);
		goto Ready;
	RestoreKnife:
		TNT1 A 0 A_SetKnifeSprite("VKNR", "VKRR");
		#### A 1
		{
			A_SpawnPSParticle("RestoreKnifeParticle", density: 4, xofs: 80, yofs: 80);
			
			if (invoker.knifeReload <= KNIFE_PARTIAL_RELOAD_TIME)
			{
				return ResolveState("RestoreKnifeEnd");
			}
			return ResolveState(null);
		}
		wait;
	RestoreKnifeEnd:
		TNT1 A 0 A_SetKnifeSprite("VKNR", "VKRR");
		#### BCDEFG 1;
		stop;
	RestoreKnifeParticle:
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
		VKNR A 0;
		VKRF A 0;
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
		+HITTRACER
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
		knifemodel.master = self;
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
		+NOBLOCKMAP
	}
	
	override void Tick()
	{
		super.Tick();
		if (!master)
			Destroy();
	}
	
	States
	{
	Spawn:
		TNT1 A 0;
		MODL A -1;
		stop;
	}
}