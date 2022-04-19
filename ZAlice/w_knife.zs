class ToM_Knife : ToM_BaseWeapon
{
	bool rightSlash;
	int combo;
	int trailFrame;
	int knifeReload;
	int particleLayer;
	const KNIFE_RELOAD_TIME = 88;
	const KNIFE_PARTIAL_RELOAD_TIME = 20;
	const KNIFE_RELOAD_FRAME = 11;
	
	action void A_KnifeReady(int flags = 0)
	{
		SetKnifeFrame();
		if (invoker.knifeReload > 0)
		{
			flags |= WRF_NOFIRE;
			if (invoker.knifeReload <= KNIFE_PARTIAL_RELOAD_TIME)
			{
				A_Overlay(APSP_TopFX, "KnifeFadeIn", true);
				A_OverlayFlags(APSP_TopFX, PSPF_ForceAlpha, true);
				let psp = player.FindPSprite(APSP_TopFX);
				if (psp)
					psp.alpha = invoker.LinearMap(invoker.knifeReload, KNIFE_PARTIAL_RELOAD_TIME, 0, 0.0, 0.8);
			}
		}
		else
		{
			player.SetPSprite(APSP_TopFX, ResolveState("Null"));
		}
		A_WeaponReady(flags);
	}
	
	action void SetKnifeFrame()
	{
		let psp = player.FindPSprite(PSP_Weapon);
		if (!psp) return;
		if (invoker.knifeReload > 0)
		{
			psp.frame = KNIFE_RELOAD_FRAME;
		}
		else
		{
			psp.frame = 0;
		}
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
	
	override void DoEffect()
	{
		super.DoEffect();
		if (!owner || !owner.player || owner.health <= 0 || owner.isFrozen())
			return;
		if (knifeReload > 0)
		{
			knifeReload--;
			if (knifeReload == 0)
				owner.A_StartSound("weapons/knife/restore", CHAN_AUTO);
		}
		let weap = owner.player.readyweapon;
		let plr = owner.player;
		if (plr && weap && weap == self)
		{
			if (knifeReload > 0)
			{
				let psp = plr.FindPSprite(APSP_TopFX);
				if (!psp)
					plr.SetPSprite(APSP_TopFX, ResolveState("RestoreKnife"));
			}
			/*else
			{
				plr.SetPSprite(APSP_TopFX, ResolveState("Null"));
				plr.SetPSprite(APSP_Overlayer, ResolveState("Null"));
			}*/
		}
	}
	
	States
	{
	Select:
		TNT1 A 0 
		{
			A_WeaponOffset(-24, 86);
			A_OverlayPivot(OverlayID(), 0.6, 0.8);
			A_OverlayRotate(OverlayID(), 30);		
			SetKnifeFrame();
		}
		VKNF ###### 1
		{
			A_WeaponOffset(4, -9, WOF_ADD);
			A_OverlayRotate(OverlayID(), -5, WOF_ADD);
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
			A_OverlayRotate(OverlayID(), 5, WOF_ADD);
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
			if (invoker.knifeReload <= 0 && level.time % (35 * 3) == 0)
				return ResolveState("IdleAnim");
			return ResolveState(null);
		}
		wait;
	IdleAnim:
		VKNI ABC 2 A_WeaponReady(WRF_NOBOB);
		VKNI DDEEFFGGHHIIJJKK 1 
		{
			A_OverlayRotate(OverlayID(), 2);
			A_WeaponReady(WRF_NOBOB);
		}
		VKNI LLMMNNOO 1 
		{
			A_OverlayRotate(OverlayID(), -4);
			A_WeaponReady(WRF_NOBOB);
		}
		VKNI BA 2 A_WeaponReady(WRF_NOBOB);
		goto Ready;
	KnifeFadeIn:
		VKNF A -1;
		stop;
	Fire:
		VKNF A 0 
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
			//A_OverlayRotate(OverlayID(), frandom[wrot](-30,0), WOF_INTERPOLATE);
		}
		VKNF AAABB 1
		{
			A_WeaponOffset(16, 0, WOF_ADD);
			//A_OverlayRotate(OverlayID(), -5, WOF_ADD);
		}
		TNT1 A 0 A_StartSound("weapons/knife/swing", CHAN_AUTO);
		VKNF BBB 1
		{
			A_WeaponOffset(-42, 0, WOF_ADD);
			//A_OverlayRotate(OverlayID(), 5, WOF_ADD);
		}
		TNT1 C 0
		{
			A_CustomPunch(15, true, CPF_NOTURN, "ToM_KnifePuff");
		}
		VKNS CCC 1
		{
			A_WeaponOffset(-42, 0, WOF_ADD);
			//A_OverlayRotate(OverlayID(), 3, WOF_ADD);
		}
		VKNF CCCHHHHAAA 1
		{
			A_WeaponOffset(17.2, 0, WOF_ADD);
			//A_OverlayRotate(OverlayID(), -0.1, WOF_ADD);
			A_WeaponReady(WRF_NOBOB);
		}
		goto ready;
	LeftSlash:
		TNT1 A 0 
		{
			A_ResetPSprite(OverlayID());
			A_OverlayPivot(OverlayID(), 0.9, 0.7);
			//A_OverlayRotate(OverlayID(), frandom[wrot](0,30), WOF_INTERPOLATE);
		}
		VKNF ADDEE 1
		{
			A_WeaponOffset(-32, -4, WOF_ADD);
			//A_OverlayRotate(OverlayID(), 5, WOF_ADD);
		}
		TNT1 A 0 A_StartSound("weapons/knife/swing", CHAN_AUTO);
		VKNF EEE 1
		{
			A_WeaponOffset(44, 4, WOF_ADD);
			//A_OverlayRotate(OverlayID(), -5, WOF_ADD);
		}		
		TNT1 E 0 
		{
			A_CustomPunch(15, true, CPF_NOTURN, "ToM_KnifePuff");
		}
		VKNS FFF 1
		{
			A_WeaponOffset(44, 4, WOF_ADD);
			//A_OverlayRotate(OverlayID(), -3, WOF_ADD);
		}
		VKNF FFFEEEDDAA 1
		{
			A_WeaponOffset(-10.4, -0.4, WOF_ADD);
			//A_OverlayRotate(OverlayID(), 0.1, WOF_ADD);
			A_WeaponReady(WRF_NOBOB);
		}
		goto ready;
	DownSlash:
		TNT1 A 0 
		{
			A_ResetPSprite(OverlayID());
			A_OverlayPivot(OverlayID(), 0.5, 1);
			//A_OverlayRotate(OverlayID(), frandom[wrot](-10,10), WOF_INTERPOLATE);
		}
		VKNF GGGG 1
		{
			A_WeaponOffset(5, -4, WOF_ADD);
		}
		TNT1 A 0 A_StartSound("weapons/knife/swing", CHAN_AUTO);		
		VKNF GGH 1
		{
			A_WeaponOffset(-12, 18, WOF_ADD);
		}		
		TNT1 H 0 
		{
			A_CustomPunch(25, true, CPF_NOTURN, "ToM_KnifePuff");
		}
		VKNS HHHH 1
		{
			A_WeaponOffset(-18, 18, WOF_ADD);
		}
		VKNF HHHHAAAAA 1
		{
			A_WeaponOffset(8.75, -7.5, WOF_ADD);
			A_WeaponReady(WRF_NOBOB);
		}
		goto ready;
	AltFire:
		TNT1 A 0 A_ResetPSprite(OverlayID());
		VKNF HHH 1
		{
			A_WeaponOffset(4, -4, WOF_ADD);
			A_OverlayRotate(OverlayID(), -2, WOF_ADD);
		}
		TNT1 A 0 A_StartSound("weapons/knife/throw", CHAN_WEAPON);
		VKNF IIII 1
		{
			A_WeaponOffset(3, -2, WOF_ADD);
			A_OverlayRotate(OverlayID(), -1, WOF_ADD);
		}
		VKNF JJJ 1 
		{
			A_WeaponOffset(-5, 15, WOF_ADD);
			A_OverlayRotate(OverlayID(), 4, WOF_ADD);
		}
		TNT1 A 0 
		{
			A_StopSound(CHAN_WEAPON);
			A_FireProjectile("ToM_KnifeProjectile");
			invoker.knifeReload = KNIFE_RELOAD_TIME;
		}
		VKNF KKK 1 
		{
			A_WeaponOffset(-5, 8, WOF_ADD);
			A_OverlayRotate(OverlayID(), 3, WOF_ADD);
		}
		VKNF KKK 1 A_WeaponOffset(-1.6, 2, WOF_ADD);
		VKNF KK 1 A_WeaponOffset(-0.5, 1, WOF_ADD);
		VKNF LLLLLLLL 1 
		{
			A_WeaponOffset(1.475, -8.125, WOF_ADD);
			A_WeaponReady(WRF_NOBOB|WRF_NOFIRE);
			A_OverlayRotate(OverlayID(), -1.375, WOF_ADD);
		}
		goto Ready;
	RestoreKnife:
		TNT1 A 1 {
			for (int i = 0; i < 4; i++) {
				int layer = 300+invoker.particleLayer;
				A_Overlay(layer,"RestoreKnifeParticle");
				A_OverlayOffset(layer,frandom[sfx](-80,80),frandom[sfx](-80,80));
				invoker.particleLayer++;
				if (invoker.particleLayer >= 50)
					invoker.particleLayer = 0;
			}
		}
		loop;
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
/*	RestoreKnife:
		TNT1 A 0
		{
			A_ResetPSprite(OverlayID());
			A_OverlayFlags(OverlayID(), PSPF_ForceAlpha, true);
			A_OverlayAlpha(OverlayID(), 0);
			A_Overlay(APSP_UnderLayer, "RestoreKnifeUnderlay");
		}
		VKNF A 1
		{
			let psp = player.FindPSprite(OverlayID());
			if (psp && psp.alpha < 1)
			{
				psp.alpha += 0.1;
				return ResolveState(null);
			}
			A_OverlayAlpha(OverlayID(), 1.0);
			player.SetPSprite(APSP_UnderLayer, ResolveState("Null"));
			return ResolveState("Ready");
		}
		wait;
	RestoreKnifeUnderlay:
		VKNF L -1;
		stop;*/
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