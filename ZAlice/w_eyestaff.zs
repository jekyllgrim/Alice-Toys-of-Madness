class ToM_Eyestaff : ToM_BaseWeapon
{
	int charge;
	private double atkzoom;
	
	const ES_FULLCHARGE = 70;
	
	Default
	{
		Weapon.slotnumber 6;
		Tag "Jabbberwock's Eye Staff";
	}
	
	action void A_StopCharge()
	{
		invoker.charge = 0;
		invoker.atkzoom = 0;
		A_StopSound(CHAN_WEAPON);
		A_ResetPsprite();
	}
	
	/*override void DoEffect()
	{
		super.DoEffect();
		if (!owner || !owner.player || !owner.player.readyweapon)
			return;
		
		let psp = owner.player.FindPSprite(PSP_Weapon);
		if (!psp)
			return;
		
		console.printf("PSprite offset: %.1f:%.1f | PSprite scale: %.1f:%.1f", psp.x, psp.y, psp.scale.x, psp.scale.y);
	}*/

	States
	{
	Select:
		TNT1 A 0 
		{
			A_WeaponOffset(0, WEAPONTOP + 102);
		}
		JEYC AABBCC 1
		{
			A_WeaponOffset(0, -17, WOF_ADD);
			A_WeaponReady(WRF_NOFIRE|WRF_NOBOB);
		}
		goto Ready;
	Deselect:
		TNT1 A 0
		{
			invoker.atkzoom = 0;
			A_ZoomFactor(1,ZOOM_NOSCALETURNING);
			A_StopSound(CHAN_WEAPON);
		}
		JEYC CCBBAA 1
		{
			A_WeaponOffset(0, 17, WOF_ADD);
		}
		TNT1 A 0 A_Lower;
		wait;
	Ready:
		TNT1 A 0 A_ResetPsprite;
		JEYC C 1 A_WeaponReady;
		wait;
	Fire:
		JEYC C 1;
		TNT1 A 0
		{
			A_StartSound("weapons/eyestaff/charge1", CHAN_WEAPON, CHANF_LOOPING);
			if (invoker.charge >= ES_FULLCHARGE)
			{
				A_StopCharge();
				return ResolveState("FireBeam");
			}
			if (PressingAttackButton(holdCheck:PAB_HELD))
			{
				invoker.charge++;
				A_DampedRandomOffset(2, 2, 1.2);
				invoker.atkzoom = Clamp(invoker.atkzoom - 0.006,0,0.1);
				A_ZoomFactor(1 - invoker.atkzoom,ZOOM_NOSCALETURNING);
				return ResolveState("Fire");
			}
			A_StopCharge();
			A_StartSound("weapons/eyestaff/chargeoff", CHAN_WEAPON);
			return ResolveState("Ready");
		}
		goto Ready;
	FireBeam:
		JEYC C 2
		{
			A_Overlay(PSP_Flash, "BeamFlash");
			A_OverlayFlags(PSP_Flash, PSPF_Renderstyle|PSPF_ForceAlpha, true);
			A_OverlayRenderstyle(PSP_Flash, Style_Add);
			A_OverlayAlpha(PSP_Flash, frandom[eye](0.3, 1));
			A_OverlayPivot(OverlayID(),0.2, 0.2);
			A_OverlayPivot(PSP_Flash,0.2, 0.2);
			A_StartSound("weapons/eyestaff/beam", CHAN_WEAPON, CHANF_LOOPING);
			A_DampedRandomOffset(3,3, 2);
			double sc = frandom[eye](-0.02, 0.02);
			A_OverlayScale(OverlayID(), 1 + sc, 1 + sc, WOF_INTERPOLATE);
			A_OverlayScale(PSP_Flash, 1 + sc, 1 + sc, WOF_INTERPOLATE);
			A_RailAttack(1, 5, color1: "", color2: "CC00FF", flags: RGF_SILENT|RGF_NOPIERCING);
		}
		TNT1 A 0 A_ReFire("FireBeam");
		goto FireEnd;
	BeamFlash:
		JEYC F 2 bright;
		stop;
	FireEnd:
		TNT1 A 0 
		{
			A_StopSound(CHAN_WEAPON);
			let proj = A_FireProjectile("Rocket");
			if (proj)
				proj.A_StartSound("weapons/eyestaff/fireProjectile");
		}
		JEYC CDE 1 
		{
			A_WeaponOffset(6, -6, WOF_ADD);
			A_OverlayScale(OverlayID(), 0.06, 0.06, WOF_ADD);
		}
		JEYC EEEEEE 2 A_WeaponOffset(frandom[eye](-1, 1), frandom[eye](-1, 1), WOF_ADD);
		JEYC DDDDCCCCC 1 
		{
			A_OverlayScale(OverlayID(), -0.02, -0.02, WOF_ADD);
			A_WeaponOffset(-2, 2, WOF_ADD);
		}
		goto ready;
	}
}