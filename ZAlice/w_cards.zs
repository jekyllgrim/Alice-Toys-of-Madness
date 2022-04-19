class ToM_Cards : ToM_BaseWeapon
{
	int cardDamage;
	int cardSuit;
	name cardName;
	
	Default
	{
		weapon.slotnumber 2;
		Tag "Playing cards";
	}
	
	action void CreateCardLayers()
	{
		if (!player || health <= 0)
			return;
		A_Overlay(APSP_Card, "Card", true);
		A_Overlay(APSP_Thumb, "Thumb", true);
	}
	
	action void PickFrame()
	{
		let pspw = player.FindPSprite(PSP_Weapon);
		let psp = player.FindPSprite(OverlayID());
		if (pspw && psp)
		{
			psp.frame = pspw.frame;
		}
	}
	
	action Actor A_FireCard(double xspread = 0, double yspread = 0)
	{
		let proj = ToM_CardProjectile(A_FireProjectile("ToM_CardProjectile", angle: frandom[firecard](-xspread, xspread), pitch:frandom[firecard](-yspread, yspread)));
		if (proj)
		{
			proj.A_StartSound("weapons/cards/fire", pitch:frandom[sfx](0.95, 1.05));
			proj.sprite = GetSpriteIndex(invoker.cardName);
			proj.SetDamage(invoker.cardDamage);
			proj.broll = frandom[card](4,6);
			return proj;
		}
		return null;
	}
	
	action void A_FireCardsMultiple(int amount = 7, double xspread = 12, double yspread = 6, double curve = 0)
	{
		A_StartSound("weapons/cards/altfire", CHAN_AUTO);
		for (int i = amount; i > 0; i--)
		{
			let proj = ToM_CardProjectile(A_FireProjectile("ToM_CardProjectile", angle: frandom[firecard](-xspread, xspread), pitch:frandom[firecard](-yspread, yspread)));
			if (proj)
			{
				proj.sprite = GetSpriteIndex(invoker.cardName);
				proj.SetDamage(invoker.cardDamage);
				proj.angleCurve = frandom[firecard](-curve, curve);
				proj.pitchCurve = frandom[firecard](-curve, curve);
				proj.broll = frandom[card](-5,5);
			}
			PickACard();
		}
	}
	
	static const name CardSuits[] = { "C", "S", "H", "D" };
	static const name CardValues[] = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "T", "J", "Q", "K" };
	
	// Picks the next card:
	action void PickACard()
	{
		if (!player || health <= 0)
			return;
		if (tom_debugmessages)
			console.printf("Attemping to pick a card");
		let psp = player.FindPSprite(APSP_Card);
		if (!psp)
			return;
		// pick a suit that isn't the same as previous:
		int cs = invoker.cardSuit;
		while (cs == invoker.cardSuit)
		{
			cs = random[pickcard](0, invoker.CardSuits.Size() - 1);
		}
		// pick a value that isn't the same as previous:
		int cv = invoker.cardDamage;
		while (cv == invoker.cardDamage)
		{
			cv = random[pickcard](0, invoker.CardValues.Size() - 1);
		}
		// construct card sprite name:
		name csuit = invoker.CardSuits[cs];
		name cval = invoker.CardValues[cv];
		invoker.cardName = String.Format("AC%s%s", csuit, cval);
		if (tom_debugmessages)
			console.printf("picked sprite %s", invoker.cardName);
		// set damage, value and sprite:
		invoker.cardSuit = cs;
		invoker.cardDamage = cv;
		psp.sprite = GetSpriteIndex(invoker.cardName);
	}
	
	override void BeginPlay()
	{
		super.BeginPlay();
		cardDamage = -1;
		cardSuit = -1;
	}
	
	States
	{
	Select:
		TNT1 A 0 
		{
			A_WeaponOffset(-24, 86);
			A_OverlayPivot(OverlayID(), 0.6, 0.8);
			A_OverlayRotate(OverlayID(), 30);		
			CreateCardLayers();
			PickACard();
		}
		PDEK AAAAAA 1
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
		}
		PDEK AAAAAA 1
		{
			A_WeaponOffset(-4, 9, WOF_ADD);
			A_OverlayRotate(OverlayID(), 5, WOF_ADD);
		}
		TNT1 A 0 A_Lower;
		wait;
	Ready:
		TNT1 A 0
		{
			A_ResetPSprite(OverlayID());
			CreateCardLayers();
			if (invoker.cardDamage < 0 || invoker.cardSuit < 0)
				PickACard();
		}
		PDEK A 1 A_WeaponReady();
		wait;
	Thumb:
		PDET A 1 PickFrame();
		loop;
	Card:
		#### # 1 PickFrame();
		loop;
	Fire:
		TNT1 A 0 A_ResetPSprite(OverlayID());
		PDEK ABC 1 A_WeaponOffset(6, -2, WOF_ADD);
		TNT1 A 0 A_FireCard(4, 3.2);
		PDEK EEEEE 1 A_WeaponOffset(3, -1, WOF_ADD);
		TNT1 A 0 PickACard();
		PDEK FFGGDBB 1 A_WeaponOffset(-3.83, 1, WOF_ADD);
		PDEK BBAAA 1 
		{
			A_ReFire();
			A_WeaponOffset(-2.6, 1, WOF_ADD);
		}
		goto ready;
	AltFire:
		TNT1 A 0 
		{
			A_ResetPSprite(OverlayID());
			A_Overlay(APSP_Overlayer, "LeftArm");
		}
		PDEK AABBC 1 A_WeaponOffset(2, -1.4, WOF_ADD);
	AltFireEnd:
		TNT1 A 0 A_FireCardsMultiple(curve: 1.8);
		PDEK EEEEE 1 
		{
			A_WeaponOffset(1, 2, WOF_ADD);
			A_OverlayRotate(OverlayID(), -2, WOF_ADD);
		}
		PDEK EEEEEEEEEEEEEEEEEE 1 
		{
			A_WeaponOffset(-1, -0.5, WOF_ADD);
			A_OverlayRotate(OverlayID(), 0.714, WOF_ADD);
		}
		PDEK FFGGDDBBAAA 1 
		{
			A_ReFire();
			A_overlayRotate(OverlayID(), 0);
			A_ResetPSprite(OverlayID(), 5);
		}
		goto ready;
	AltHold:
		TNT1 A 0 
		{
			A_WeaponOffset(5, WEAPONTOP + 7, WOF_INTERPOLATE);
			A_Overlay(APSP_Overlayer, "LeftArm");
		}
		PDEK EEEEE 1 A_WeaponOffset(1, -2, WOF_ADD);
		goto AltFireEnd;
	LeftArm:
		TNT1 A 0 
		{
			A_ResetPSprite(OverlayID());
			A_OverlayFlags(OverlayID(), PSPF_AddWeapon|PSPF_AddBob, false);
		}
		PDEK HIIJJ 1 A_OverlayOffset(OverlayID(), 2, -2, WOF_ADD);
		PDEK KKK 1 A_OverlayOffset(OverlayID(), -3, -1, WOF_ADD);
		PDEK LLL 1 A_OverlayOffset(OverlayID(), -5, 0, WOF_ADD);
		PDEK LLL 1 A_OverlayOffset(OverlayID(), 1, 2, WOF_ADD);
		PDEK MMMM 1 A_OverlayOffset(OverlayID(), 2, 3, WOF_ADD);
		PDEK NNNIIIIIIIIHHH 1 A_OverlayOffset(OverlayID(), 2, 5, WOF_ADD);
		stop;
	Cache:
		PDEK A 0;
		PDET A 0;
		ACH1 A 0;
		ACH2 A 0;
		ACH3 A 0;
		ACH4 A 0;
		ACH5 A 0;
		ACH6 A 0;
		ACH7 A 0;
		ACH8 A 0;
		ACH9 A 0;
		ACHT A 0;
		ACHJ A 0;
		ACHQ A 0;
		ACHK A 0;
		ACD1 A 0;
		ACD2 A 0;
		ACD3 A 0;
		ACD4 A 0;
		ACD5 A 0;
		ACD6 A 0;
		ACD7 A 0;
		ACD8 A 0;
		ACD9 A 0;
		ACDT A 0;
		ACDJ A 0;
		ACDQ A 0;
		ACDK A 0;
		ACS1 A 0;
		ACS2 A 0;
		ACS3 A 0;
		ACS4 A 0;
		ACS5 A 0;
		ACS6 A 0;
		ACS7 A 0;
		ACS8 A 0;
		ACS9 A 0;
		ACST A 0;
		ACSJ A 0;
		ACSQ A 0;
		ACSK A 0;
		ACC1 A 0;
		ACC2 A 0;
		ACC3 A 0;
		ACC4 A 0;
		ACC5 A 0;
		ACC6 A 0;
		ACC7 A 0;
		ACC8 A 0;
		ACC9 A 0;
		ACCT A 0;
		ACCJ A 0;
		ACCQ A 0;
		ACCK A 0;
	}
}

class ToM_CardProjectile : ToM_StakeProjectile
{	
	double broll;
	double angleCurve;
	double pitchCurve;
	
	Default
	{
		ToM_Projectile.trailcolor "f4f4f4";
		ToM_Projectile.trailscale 0.013;
		ToM_Projectile.trailfade 0.024;
		ToM_Projectile.trailalpha 0.2;
		+ROLLSPRITE
		renderstyle "Translucent";
		speed 40;
		damage (10);
		gravity 0.6;
		radius 8;
		height 6;
		scale 0.75;
	}
	
	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		//A_StartSound("weapons/cards/fire", pitch:frandom[sfx](0.95, 1.05));
		//console.printf("card damage: %d", damage);
		if (target)
		{
			angle = target.angle + angleCurve;
			pitch = target.pitch + pitchCurve;
			Vel3DFromAngle(speed, angle, pitch);
		}
	}
	
	States
	{
	Spawn:
		#### A 1
		{			
			if (GetAge() > 5)
				roll += broll;
			A_SetAngle(angle + angleCurve);
			A_SetPitch(pitch + pitchCurve);
			Vel3DFromAngle(speed, angle, pitch);
		}
		loop;
	XDeath:
		TNT1 A 1 A_StartSound("weapons/cards/hitflesh", CHAN_AUTO, attenuation: 8);
		stop;
	Death:
		#### A 60
		{
			A_SetRenderstyle(alpha, Style_Translucent);
			A_StartSound("weapons/cards/hitwall", CHAN_AUTO, attenuation: 8);
			StickToWall();
		}
		#### A 1 
		{
			A_FadeOut(0.15);
		}
		wait;
	}
}