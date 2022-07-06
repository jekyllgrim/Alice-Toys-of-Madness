class ToM_Cards : ToM_BaseWeapon
{
	int cardDamage;
	int cardSuit;
	name cardName;
	double cardXpos;
	protected double fanangle;
	
	protected int cardVertStep[3];
	protected int curCardLayer;
	protected int prevCardLayer;
	const CARDSTEPS = 32;
	const ANGLESTEP = 360. / CARDSTEPS;
	const ANGLEDIFF = ANGLESTEP * 1.5;
	const CARDRAD = 4.;
	
	Default
	{
		weapon.slotnumber 3;
		Tag "Playing cards";
	}
	
	action void A_CreateCardLayers()
	{
		if (!player || health <= 0)
			return;
		A_Overlay(APSP_Card1, "PrepareCard");
		A_Overlay(APSP_Card2, "PrepareCard");
		A_Overlay(APSP_Card3, "PrepareCard");
		invoker.curCardLayer = randompick[acard](APSP_Card1, APSP_Card2, APSP_Card3);
	}
	
	action void A_FireCardLayer()
	{
		int layer = invoker.curCardLayer;
		player.SetPSPrite(layer, ResolveState("FireCard"));
		invoker.prevCardLayer = invoker.curCardLayer;
		while (invoker.curCardLayer == invoker.prevCardLayer)
		{
			invoker.curCardLayer = randompick[acard](APSP_Card1, APSP_Card2, APSP_Card3);
		}
	}

	action 	void A_RotateIdleCard()
	{
		int layer;
		switch (OverlayID())
		{
		case APSP_Card1: layer = 0; break;
		case APSP_Card2: layer = 1; break;
		case APSP_Card3: layer = 2; break;
		}
		invoker.cardVertStep[layer]++;
		if (invoker.cardVertStep[layer] > CARDSTEPS)
			invoker.cardVertStep[layer] = 1;
		for (int i = 0; i < 4; i++)
		{
			double ang = ANGLESTEP * Clamp(invoker.cardVertStep[layer], 1, CARDSTEPS) + (ANGLEDIFF * 10 * layer);
			ang += (ANGLEDIFF * i);
			vector2 coords = (cos(ang) * CARDRAD, sin(ang) * CARDRAD);
			A_OverlayVertexOffset(OverlayID(), i, coords.x, coords.y);
		}
	}
	
	action void A_OffsetCardLayer(int layer)
	{
		vector2 ofs;
		switch (layer)
		{
		case APSP_Card1: 
			ofs = (-4, 0); 
			break;
		case APSP_Card2: 
			ofs = (0, -1.5); 
			break;
		case APSP_Card3: 
			ofs = (5, -0.4); 
			break;
		}
		A_OverlayOffset(layer, ofs.x, ofs.y, WOF_ADD);
	}
	
	action void A_RemoveCardLayers()
	{
		A_Overlay(APSP_Card1, "RemoveCard");
		A_Overlay(APSP_Card2, "RemoveCard");
		A_Overlay(APSP_Card3, "RemoveCard");
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
	
	action Actor A_FireCard(double xspread = 0, double yspread = 0, double xofs = 0, double yofs = 0, bool explicitangle = false)
	{
		double horspread = explicitangle ? xspread : frandom[firecard](-xspread, xspread);
		double vertspread = explicitangle ? yspread : frandom[firecard](-yspread, yspread);
		//console.printf("firing a card at an angle of %1.f", horspread);
		let proj = ToM_CardProjectile(A_FireProjectile(
			"ToM_CardProjectile", 
			angle: horspread, 
			spawnofs_xy: xofs,
			spawnheight: yofs,
			flags: FPF_AIMATANGLE,
			pitch: vertspread
		));
		if (proj)
		{
			proj.A_StartSound("weapons/cards/fire", pitch:frandom[sfx](0.95, 1.05));
			//proj.sprite = GetSpriteIndex(invoker.cardName);
			proj.SetDamage(invoker.cardDamage);
			proj.broll = frandom[card](-2,2);
			return proj;
		}
		return null;
	}
	
	static const name CardSuits[] = { "C", "S", "H", "D" };
	static const name CardValues[] = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "T", "J", "Q", "K" };
	
	// Picks the next card:
	/*action void PickACard()
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
	}*/
	
	override void BeginPlay()
	{
		super.BeginPlay();
		cardDamage = -1;
		cardSuit = -1;
	}
	
	States
	{
	Spawn:
		ALCA A -1;
		stop;
	Select:
		TNT1 A 0 
		{
			A_WeaponOffset(-24, 86);
			A_OverlayPivot(OverlayID(), 0.6, 0.8);
			A_OverlayRotate(OverlayID(), 18);
			A_CreateCardLayers();
			//PickACard();
		}
		APCR AABBCC 1
		{
			A_WeaponOffset(4, -9, WOF_ADD);
			A_RotatePSPrite(OverlayID(), -3, WOF_ADD);
			A_WeaponReady(WRF_NOFIRE|WRF_NOBOB);
		}
		goto Ready;
	Deselect:
		TNT1 A 0 
		{
			A_OverlayPivot(OverlayID(), 1, 1);
			A_RemoveCardLayers();
		}
		APCR CCBBAA 1
		{
			A_WeaponOffset(-4, 9, WOF_ADD);
			A_OverlayRotate(OverlayID(), 3, WOF_ADD);
		}
		TNT1 A 0 A_Lower;
		wait;
	PrepareCard:
		TNT1 A 0 
		{
			A_OverlayFlags(OverlayID(), PSPF_ADDBOB|PSPF_ADDWEAPON, false);
			A_OverlayOffset(OverlayID(), 0, WEAPONTOP);
			A_OverlayPivot(OverlayID(), 0, 0.5);
			switch (OverlayID())
			{
			case APSP_Card1: 
				A_OverlayScale(OverlayID(), 0.88, 0.88);
				break;
			case APSP_Card2: 
				A_OverlayScale(OverlayID(), 1, 1);
				break;
			case APSP_Card3: 
				A_OverlayScale(OverlayID(), 0.8, 0.8);
				break;
			}
		}
		APCR HHGGFFEE 1 
		{
			A_OffsetCardLayer(OverlayID());
			if (OverlayID() == APSP_Card2)
				A_OverlayScale(OverlayID(), 0.07, 0.07, WOF_ADD);
		}
		APCR D 1 A_RotateIdleCard();		
		wait;
	FireCard:
		APCR DDD 1 
		{
			A_OverlayScale(OverlayID(), -0.3, -0.3, WOF_ADD);
			A_OverlayOffset(OverlayID(), -8, 3.2, WOF_ADD);
		}
		goto PrepareCard;
	RemoveCard:
		TNT1 A 0 A_OverlayFlags(OverlayID(), PSPF_ADDBOB, false);
		APCR DEFGH 1
		{
			let psp = player.FindPSprite(OverlayID());
			if (psp)
			{
				psp.x *= 0.8;
				psp.y *= 0.8;
			}
		}
		stop;
	Ready:
		APCR C 1 A_WeaponReady;
		loop;
	Fire:
		APCR C 1
		{
			A_FireCardLayer();
			A_OverlayPivot(OverlayID(), 0, 0);
		}
		TNT1 A 0 
		{
			vector2 ofs;
			switch (invoker.curCardLayer)
			{
			case APSP_Card1: ofs = (9, 6); break;
			case APSP_Card2: ofs = (12, 8); break;
			case APSP_Card3: ofs = (15, 6); break;
			}
			console.printf("ofs: %1.f, %1.f", ofs.x, ofs.y);
			A_FireCard(1, 1, xofs: ofs.x, yofs: ofs.y);
		}
		APCR CCC 1 A_OverlayScale(OverlayID(), 0.03, 0.03, WOF_ADD);
		APCR CCCCCC 1 A_OverlayScale(OverlayID(), -0.015, -0.015, WOF_ADD);
		goto Ready;
	AltFire:
		TNT1 A 0 A_RemoveCardLayers();
		APCR CB 2;
	AltHold:
		APCR AJKL 2;
		APCR M 6
		{
			invoker.cardXpos = -15; 
			//invoker.fanangle = - 
		}
		APCR NNOOPP 1 
		{
			A_FireCard(invoker.cardXpos, frandom[firecard](-1.5, 1.5), xofs: invoker.cardXpos, explicitangle: true);
			invoker.cardXpos += 5;
		}
		APCR PPPP 1 A_OverlayOffset(OverlayID(), 1, 0, WOF_ADD);
		APCR PPQ 1 A_ResetPSprite(OverlayID(), 5);
		TNT1 A 0 A_ReFire();
	AltFireEnd:
		TNT1 A 0 A_CreateCardLayers();
		APCR ABC 3;
		goto ready;
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
		damage (12);
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
		if (target && (angleCurve > 0 || pitchCurve > 0))
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
			if (angleCurve > 0 || pitchCurve > 0)
			{
				A_SetAngle(angle + angleCurve);
				A_SetPitch(pitch + pitchCurve);
				Vel3DFromAngle(speed, angle, pitch);
			}
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