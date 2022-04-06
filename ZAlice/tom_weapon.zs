class ToM_BaseWeapon : Weapon abstract
{
	Default
	{
		weapon.BobStyle "InverseSmooth";
		weapon.BobRangeX 0.32;
		weapon.BobRangeY 0.17;
		weapon.BobSpeed 1.85;
	}
	
	action void ResetPSprite(int layer)
	{
		if (!player)
			return;
		let psp = player.FindPSprite(layer);
		if (!psp)
			return;
		A_OverlayOffset(layer, 0, layer == PSP_WEAPON ? 32 : 0, WOF_INTERPOLATE);
		A_OverlayRotate(layer, 0, WOF_INTERPOLATE);
		A_OverlayScale(layer, 1, 1, WOF_INTERPOLATE);
	}
}

class ToM_BasePuff : Actor
{
	Default
	{
		+NOINTERACTION
		+PUFFONACTORS
		+PUFFGETSOWNER
	}
}