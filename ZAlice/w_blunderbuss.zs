class ToM_Blunderbuss : ToM_BaseWeapon
{
	double charge;
	protected double smokescale;
	protected double smokeofs;
	protected double smokeroll;
	
	Default
	{
		Tag "Blunderbuss";
		ToM_BaseWeapon.CheshireSound "cheshire/vo/blunderbuss";
		Inventory.Icon "AWICBBUS";
		ToM_BaseWeapon.IsTwoHanded true;
		+WEAPON.NOAUTOFIRE
		+WEAPON.BFG
		Weapon.slotnumber 8;
		weapon.ammotype1 "ToM_StrongMana";
		weapon.ammouse1 50;
		weapon.ammogive1 100;
	}

	override void UpdateCrosshairSpot()
	{
		crosshairSpot.Update(specialsprite: "AMCRY0");
	}
	
	action void A_FireBlunderbuss()
	{
		A_ClearPSParticles(bottom:false);
		//A_Overlay(APSP_UnderLayer, "MuzzleSmoke");
		//A_Overlay(APSP_TopFX, "Flash");
		for (int i = 3; i > 0; i--)
		{
			A_FireProjectile("ToM_MuzzleSmoke", frandom[muzsm](-5,5), useammo:false, spawnheight: -8, flags:FPF_NOAUTOAIM, pitch: frandom[muzsm](-5,5));
		}
		A_FireProjectile("ToM_Cannonball");
		invoker.charge = 0;
		A_Recoil(14);
		if (pos.z <= floorz)
			vel.z += 6;
		A_QuakeEX(2,2,1,10,0,1,sfx:"", flags:QF_SCALEDOWN);
	}
	
	States
	{
	/*Spawn:
		ALBB A -1;
		stop;*/
	Select:
		BBUS A 0 
		{
			A_SetSelectPosition(-24, 90+WEAPONTOP);
			A_OverlayPivot(OverlayID(), 0.6, 0.8);
			A_OverlayRotate(OverlayID(), 30);
		}
		#### ###### 1
		{
			A_WeaponOffset(4, -15, WOF_ADD);
			A_OverlayRotate(OverlayID(), -5, WOF_ADD);
			A_WeaponReady(WRF_NOFIRE|WRF_NOBOB);
		}
		goto Ready;
	Deselect:
		BBUS A 0
		{
			A_OverlayPivot(OverlayID(), 0.6, 0.8);
			A_StopSound(CHAN_WEAPON);
		}
		#### ###### 1
		{
			A_ResetZoom();
			A_WeaponOffset(-4, 15, WOF_ADD);
			A_OverlayRotate(OverlayID(), 5, WOF_ADD);
		}
		TNT1 A 0 A_Lower;
		wait;
	Ready:
		BBUS A 1 
		{
			A_ResetZoom();
			A_WeaponReady();
		}
		wait;
	Fire:
		TNT1 A 0 
		{
			A_StartSound("weapons/blunderbuss/fire", CHAN_AUTO);
			A_StartSound("weapons/blunderbuss/pull", CHAN_AUTO);
			A_PlayerAttackAnim(80, 'attack_blunderbuss', 30);
		}
		BBUS BBBBBBBBBBBBBBBBBBBBBBBBB 1
		{
			A_WeaponOffset(frandom[bbus](-invoker.charge, invoker.charge), WEAPONTOP + frandom[bbus](0, invoker.charge), WOF_INTERPOLATE);
			invoker.charge += 0.2;
			A_Overlay(APSP_Overlayer, "Flint");
			A_AttackZoom(0.001, 0.08, 0.002);
			A_SpawnPSParticle("FireParticle", bottom: false, density: 3, xofs: 1.4, yofs: 1);
		}
		BBUS B 1 A_FireBlunderbuss();
		TNT1 A 0 
		{
			A_CameraSway(0, -12, 10);
			player.cheats |= CF_FROZEN;
		}
		BBUS DF 1;
		BBUS FFFFFFFFFF 1 
		{
			A_WeaponOffset(30, 20, WOF_ADD);
			A_OverlayScale(OverlayID(), 0.08, 0.08, WOF_ADD);
			A_ResetZoom();
		}
		TNT1 A 0
		{
			player.cheats &= ~CF_FROZEN;
		}
		TNT1 A 25 A_CheckReload();
		BBUS B 0 
		{
			A_WeaponOffset(-16, 90+WEAPONTOP);
			A_OverlayPivot(OverlayID(), 0.6, 0.8);
			A_OverlayRotate(OverlayID(), 45);
			A_OverlayScale(OverlayID(), 1, 1);
		}
		#### ########## 1
		{
			A_WeaponOffset(1.6, -9, WOF_ADD);
			A_OverlayRotate(OverlayID(), -4.5, WOF_ADD);
			A_WeaponReady(WRF_NOFIRE|WRF_NOBOB);
		}
		BBUS B 5 A_WeaponReady(WRF_NOFIRE);
		BBUR AB 2 A_WeaponReady(WRF_NOFIRE);
		TNT1 A 0 A_StartSound("weapons/blunderbuss/cock");
		BBUR CDE 4 A_WeaponReady(WRF_NOFIRE);
		goto Ready;
	Flint:
		BBUS X 2 bright
		{
			A_OverlayFlags(OverlayID(), PSPF_RENDERSTYLE|PSPF_FORCEALPHA, true);
			A_OverlayRenderstyle(OverlayID(), Style_Add);
			A_OverlayAlpha(OverlayID(), frandom[bbus](0.2, 1));
		}
		stop;
	/*Flash:
		BBUS Y 2 bright;
		stop;*/
	MuzzleSmoke:
		BBUS S 0
		{
			A_OverlayFlags(OverlayID(), PSPF_AddWeapon|PSPF_AddBob, false);
			A_OverlayFlags(OverlayID(), PSPF_ForceAlpha, true);
			A_OverlayOffset(OverlayID(), 0, WEAPONTOP);
			A_OverlayPivotAlign(OverlayID(),PSPA_CENTER,PSPA_CENTER);
			invoker.smokescale = frandom[bbus](0.12, 0.19);
			invoker.smokeofs = frandom[bbus](-1, -2);
			invoker.smokeroll = frandom[bbus](-5,5);
			A_OverlayRotate(OverlayID(), frandom[bbus](0, 359));
		}
		#### # 1
		{
			A_OverlayScale(OverlayID(), invoker.smokescale, invoker.smokescale, WOF_ADD);
			invoker.smokescale *= 0.93;
			A_OverlayRotate(OverlayID(), invoker.smokeroll, WOF_ADD);
			invoker.smokeroll *= 0.93;
			A_OverlayOffset(OverlayID(), invoker.smokeofs, invoker.smokeofs, WOF_ADD);
			invoker.smokeofs *= 0.96;
			A_PSPFadeOut(0.015);
		}
		wait;
	FireParticle:
		BBUS P 1 bright 
		{
			A_OverlayPivotAlign(OverlayID(),PSPA_CENTER,PSPA_CENTER);
			A_OverlayFlags(OverlayID(),PSPF_RENDERSTYLE|PSPF_FORCEALPHA,true);
			A_OverlayRenderstyle(OverlayID(),Style_Add);
			double sc = frandom[bbus](0.8, 1.5);
			A_OverlayScale(OverlayID(),sc, sc);
		}
		#### ########## 1 bright 
		{
			double mod = 0.1;
			A_OverlayScale(OverlayID(),-mod,-mod,WOF_ADD);
			let psp = player.FindPSprite(OverlayID());
			if (psp) 
			{
				psp.alpha = Clamp(psp.alpha - mod, 0, 1);
				A_OverlayOffset(OverlayID(),psp.x += frandom[bbus](-0.75, 0.75), psp.y -= frandom[bbus](1.2, 2.4), WOF_INTERPOLATE);
			}
		}
		stop;
	}
}

class ToM_MuzzleSmoke : ToM_SmallDebris
{
	TextureID trailtex;
	Default
	{
		+NOINTERACTION
		+MISSILE
		Speed 15;
		Scale 1.0;
		Renderstyle 'Shaded';
		StencilColor '800080';
		Alpha 0.6;
	}
	override void PostBeginPlay() 
	{
		super.PostBeginPlay();
		frame = random[sfx](0,5);
		dscale = frandom[sfx](0.002, 0.003);
		wrot = frandom[sfx](-10, 10);
	}
	States
	{
	Spawn:
		SMO2 # 1
		{
			vel *= 0.8;
			scale *= (1 + dscale);
			dscale *= 0.99;
			roll += wrot;
			wrot *= 0.9;
			A_FadeOut(default.alpha * 0.01);
		}
		loop;
	}
}


class ToM_Cannonball : ToM_Projectile
{
	Default
	{
		radius 16;
		height 24;
		DamageFunction (300);
		xscale 0.25;
		yscale 0.25 / 1.2;
		speed 50;
		+FORCERADIUSDMG
		//ToM_Projectile.trailactor "ToM_CannonballFireTrail";
		//ToM_Projectile.trailz 16;
		//ToM_Projectile.trailvel 2;
	}
	States
	{
	Spawn:
		BCAN A 1 NoDelay 
		{
			A_StartSound("weapons/blunderbuss/flyloop", CHAN_BODY, CHANF_LOOPING);
			if (GetAge() > 3)
			{
				let trl = Spawn("ToM_CannonballFireTrail", pos + (0,0,16));
				if (trl)
				{
					trl.vel = (frandom[bbus](-2, 2),frandom[bbus](-2, 2),frandom[bbus](-2, 2));
				}
			}
		}
		loop;
	Death:
		TNT1 A 0
		{
			A_StartSound("weapons/blunderbuss/explode", CHAN_BODY, attenuation: 1);
			
			ToM_SphereFX.SpawnExplosion(pos, size: 128, alpha: 0.5, col1: "4f026e", col2: "d10841", boomfactor: 2);
			A_Explode(1200, 512, XF_THRUSTZ, fulldamagedistance: 320);
			let exp = ToM_GenericExplosion.Create(
				pos, scale: 1.5, tics: 2,
				randomdebris: 24,
				randomDebrisVel: 18,
				randomdebrisScale: 2,
				smokingdebris: 0,
				explosivedebris: 0,
				//explosivedebrisVel: 10,
				//explosivedebrisScale: 2,
				quakeIntensity: 4,
				quakeDuration: 20,
				quakeradius: 512
			);
			if (exp)
			{
				exp.A_SetRenderstyle(2, Style_AddShaded);
				exp.SetShade("ff0161");
			}
		}
		TNT1 AAAAAAAA 1
		{
			//int dist = 128;
			//Spawn("ToM_CannonballExplosion", pos + (frandom[cbex](-dist, dist), frandom[cbex](-dist, dist), frandom[cbex](-dist, dist)));
			double mom = frandom[cbex](8, 14);
			let ex = Spawn("ToM_CannonballExplosion", pos);
			if (ex)
			{
				ex.vel = (frandom[cbex](-mom, mom), frandom[cbex](-mom, mom), frandom[cbex](-mom, mom));
			}
		}
		stop;
	}
}

class ToM_CannonballExplosion : ToM_SmallDebris
{
	Default
	{
		+NOINTERACTION
		+NOBLOCKMAP
		renderstyle 'add';
		+BRIGHT;
		scale 0.5;
		alpha 0.6;
	}
	
	override void PostBeginPlay() 
	{
		super.PostBeginPlay();
		A_SetScale(scale.x * frandom[sfx](0.5,1.5));
		bSPRITEFLIP = randompick[sfx](0,1);
		roll = frandom[sfx](0, 359);
	}
	States
	{
	Spawn:
		BOM1 ABCDEFGHIJKLMNOPQRSTUVWX 1 
		{
			vel *= 0.86;
		}
		stop;
	}
}

class ToM_CannonballFireTrail : ToM_BaseFlare
{
	double wscale;
	
	Default
	{
		renderstyle 'Translucent';
		alpha 0.6;
	}
	
	override void PostBeginPlay() 
	{
		super.PostBeginPlay();
		wrot = frandom[ftrail](-10,10);
		wscale = 1.15;
	}
	
	override void Tick()
	{
		super.Tick();
		if (!isFrozen())
		{
			scale *= wscale;
			roll += wrot;
			wscale = Clamp(wscale * 0.95, 1, 10);
			wrot * 0.95;			
		}
	}
		
	States
	{
	Spawn:
		BOM4 NOPQ 1;
		BOM5 ABCDEFGHIJKLMN 1 A_FadeOut(0.02);
		wait;
	}
}
		