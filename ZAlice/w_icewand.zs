class ToM_Icewand : ToM_BaseWeapon
{
	ToM_ReflectionCamera cam;

	Default
	{
		Tag "$TOM_WEAPON_ICEWAND";
		ToM_BaseWeapon.IsTwoHanded true;
		Weapon.SlotNumber 6;
		weapon.ammotype1 "ToM_MediumMana";
		weapon.ammouse1 1;
		weapon.ammogive1 80;
		weapon.ammotype2 "ToM_MediumMana";
		weapon.ammouse2 20;
	}

	override void DoEffect()
	{
		super.DoEffect();
		if (!owner || !owner.player)
		{
			if (cam) cam.Destroy();
			return;
		}
		
		let weap = owner.player.readyweapon;
		if (weap == self)
		{
			if (!cam)
			{
				cam = ToM_ReflectionCamera(Spawn("ToM_IcewwandCamera", owner.pos));
				cam.ppawn = PlayerPawn(owner);
				TexMan.SetCameraToTexture(cam, "AliceWeapon.camtex", owner.player.fov);
			}
			/*let psp = owner.player.FindPSprite(APSP_Overlayer);
			let psw = owner.player.FindPSprite(PSP_WEAPON);
			if (!psp)
			{
				psp = owner.player.GetPSprite(APSP_Overlayer);
				psp.SetState(ResolveState("WandHandle"));
				psp.bAddWeapon = true;
				psp.bAddBob = true;
			}*/
		}
		else
		{
			if (cam)
			{
				cam.Destroy();
			}
		}
	}

	States {
	Select:
		AICW A 0 
		{
			A_WeaponOffset(-24, 90+WEAPONTOP);
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
		AICW A 0
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
		AICW A 1 bright A_WeaponReady();
		loop;
	WandHandle:
		TNT1 A 0 A_Overlay(OverlayID() + 1, "CrystalGraphic");
		AICW B 1
		{
			let psw = player.FindPSprite(PSP_WEAPON);
			for (int i = 0; i < 2; i++)
			{
				let psp = player.FindPSprite(OverlayID() + i);
				if (!psp) continue;
				psp.bInterpolate = psw.bInterpolate;
				psp.bPivotPercent = psw.bPivotPercent;
				psp.pivot = psw.pivot;
				psp.scale = psw.scale;
				psp.rotation = psw.rotation;
			}
		}
		wait;
	CrystalGraphic:
		AICW C -1 bright
		{
			A_OverlayFlags(OverlayID(), PSPF_RenderStyle|PSPF_ForceAlpha, true);
			A_OverlayRenderstyle(OverlayID(), STYLE_Add);
			A_OverlayAlpha(OverlayID(), 0.7);
		}
		stop;
	Fire:
		AICW A 1
		{
			double sc = frandom[icewand](1.0, 1.05);
			A_OverlayScale(OverlayID(), sc, sc, WOF_INTERPOLATE);
		}
		#### # 0 A_Refire;
		#### # 0 A_OverlayScale(OverlayID(), 1, 1, WOF_INTERPOLATE);
		goto ready;
	}
}

class ToM_IcewwandCamera : ToM_ReflectionCamera
{
	override void Tick() 
	{
		if (!ppawn) 
		{
			Destroy();
			return;
		}
		
		Warp(
			ppawn, 
			xofs: ppawn.radius * 0.5, 
			yofs: -12,
			zofs: 40
		);
		
		A_SetRoll(ppawn.roll, SPF_INTERPOLATE);
		A_SetAngle(ppawn.angle -20, SPF_INTERPOLATE);
		A_SetPitch(Clamp(ppawn.pitch + 15, -90, 90), SPF_INTERPOLATE);
	}
}