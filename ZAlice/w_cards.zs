class ToM_Cards : ToM_BaseWeapon
{
	protected int cardDamage[3];
	protected name cardSpriteName[3];
	protected double cardFanAngle;
	protected double cardXpos;
	
	protected int cardVertStep[3];
	protected int handVertStep;
	const CARDSTEPS = 32;
	const HANDSTEPS = CARDSTEPS;
	const ANGLESTEP = 360. / CARDSTEPS;
	const CARDANGLEDIFF = ANGLESTEP * 1.5;
	const CARDRAD = 4.;
	
	const FANSTARTANGLE = 9;
	const FANANGLESTEP = 3;
	
	static const int cardLayerNum[] = { APSP_Card1, APSP_Card3, APSP_Card2 };
	protected int curCardLayer;
	protected int cardLayerID;
	
	Default
	{
		Tag "Playing cards";
		weapon.slotnumber 2;
		weapon.ammotype1 "ToM_RedMana";
		weapon.ammouse1 2;
		weapon.ammogive1 100;
		weapon.ammotype2 "ToM_RedMana";
		weapon.ammouse2 1;
	}
	
	action void A_CreateCardLayers()
	{
		if (!player || health <= 0)
			return;
		A_Overlay(APSP_Card1, "PrepareCard");
		A_Overlay(APSP_Card2, "PrepareCard");
		A_Overlay(APSP_Card3, "PrepareCard");
		int l = random[acard](0, invoker.cardLayerNum.Size() - 1);
		invoker.curCardLayer = invoker.cardLayerNum[l];
	}	
	
	action void A_FireCardLayer()
	{
		invoker.curCardLayer = invoker.cardLayernum[invoker.cardLayerID];
		player.SetPSPrite(invoker.curCardLayer, ResolveState("FireCard"));
		invoker.cardLayerID++;
		if (invoker.cardLayerID >= invoker.cardLayerNum.Size())
			invoker.cardLayerID = 0;
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
			double ang = ANGLESTEP * Clamp(invoker.cardVertStep[layer], 1, CARDSTEPS) + (CARDANGLEDIFF * 10 * layer);
			ang += (CARDANGLEDIFF * i);
			vector2 coords = (cos(ang) * CARDRAD, sin(ang) * CARDRAD);
			A_OverlayVertexOffset(OverlayID(), i, coords.x, coords.y);
		}
	}
	
	action void A_RotateHand()
	{
		invoker.handVertStep--;
		if (invoker.handVertStep < 0)
			invoker.handVertStep = HANDSTEPS;
		double ang = ANGLESTEP * Clamp(invoker.handVertStep, 1, CARDSTEPS);
		vector2 coords = (cos(ang) * CARDRAD, sin(ang) * CARDRAD);
		A_WeaponOffset(coords.x, WEAPONTOP + coords.y);
		double sc = ToM_UtilsP.LinearMap(coords.y, -CARDRAD, CARDRAD, 1, 1.06);
		A_OverlayScale(OverlayID(), sc, sc, WOF_INTERPOLATE);
	}
	
	action void A_OffsetCardLayer(int layer)
	{
		vector2 ofs;
		switch (layer)
		{
		case APSP_Card1: 
			ofs = (-2.5, 2); 
			break;
		case APSP_Card2: 
			ofs = (1.4, 1.5); 
			break;
		case APSP_Card3: 
			ofs = (7, -1); 
			break;
		}
		A_OverlayOffset(layer, ofs.x, ofs.y, WOF_ADD);
	}
	
	action void A_RemoveCardLayers()
	{
		player.SetPSPrite(APSP_Card1, ResolveState("RemoveCard"));
		player.SetPSPrite(APSP_Card2, ResolveState("RemoveCard"));
		player.SetPSPrite(APSP_Card3, ResolveState("RemoveCard"));
	}
	
	action Actor A_FireCard(double xspread = 0, double yspread = 0, double xofs = 0, double yofs = 0, bool explicitangle = false)
	{
		double horspread = explicitangle ? xspread : frandom[firecard](-xspread, xspread);
		double vertspread = explicitangle ? yspread : frandom[firecard](-yspread, yspread);
		//console.printf("firing a card at an angle of %1.f", horspread);
		let proj = ToM_CardProjectile(A_Fire3DProjectile(
			"ToM_CardProjectile",
			leftright: xofs,
			updown: yofs,
			crosshairConverge: true,
			angleoffs: horspread, 
			pitchoffs: vertspread
		));
		int cardId = 0;
		switch (invoker.curCardLayer)
		{
		//case APSP_Card1: cardId = 0; break;
		case APSP_Card2: cardId = 1; break;
		case APSP_Card3: cardId = 2; break;
		}
		if (proj)
		{
			proj.A_StartSound("weapons/cards/fire", pitch:frandom[sfx](0.95, 1.05));
			let spritename = invoker.cardSpriteName[cardId];
			let sprt = GetSpriteIndex(spritename);
			if (sprt)
			{
				proj.sprite = sprt;
				if (tom_debugmessages)
					console.printf("setting projectile sprite to %s", spritename);
			}
			else if (tom_debugmessages)
				console.printf("Couldn't set proj sprite; %s is an invalid sprite", spritename);
			proj.SetDamage(Clamp(invoker.cardDamage[cardId], 1, 10));
			proj.broll = frandom[card](-2,2);
			return proj;
		}
		return null;
	}
	
	protected array <ToM_CardData> Cards;
	static const name CardSuits[] = { "C", "S", "H", "D" };
	static const name CardValues[] = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "T", "J", "Q", "K" };
	
	void FillCardsArray()
	{
		string prefix = "AC";
		for (int suit = 0; suit < CardSuits.Size(); suit++)
		{
			for (int val = 0; val < CardValues.Size(); val++)
			{
				string spritename = String.Format("%s%s%s", prefix, CardSuits[suit], CardValues[val]);
				SpriteID csprite = GetSpriteIndex(spritename);
				if (csprite && csprite > 0)
				{
					let ct = ToM_CardData.Create(name(spritename), val);
					if (ct)
						Cards.Push(ct);
				}
			}
		}
	}
	
	// Picks the next card:
	action SpriteID A_PickCard()
	{
		let nullsprite = GetSpriteIndex("TNT1A0");
		if (!player || health <= 0)
			return nullsprite;
		if (tom_debugmessages)
			console.printf("Attemping to pick a card");
		
		if (invoker.Cards.Size() <= 0)
		{
			if (tom_debugmessages)
				console.printf("Cards array empty: filling");
			invoker.FillCardsArray();
		}
		
		int cardId = 0;
		switch (invoker.curCardLayer)
		{
		//case APSP_Card1: cardId = 0; break;
		case APSP_Card2: cardId = 1; break;
		case APSP_Card3: cardId = 2; break;
		}
		if (tom_debugmessages)
			console.printf("Current layer is %d", invoker.curCardLayer);
		
		int id = random[pickcard](0, invoker.Cards.Size() - 1);
		let ct = invoker.Cards[id];
		if (ct)
		{
			invoker.cardDamage[cardId] = ct.cardValue;
			invoker.cardSpriteName[cardId] = ct.cardSpriteName;
			invoker.Cards.Delete(id);
			if (tom_debugmessages)
				console.printf("Selected card sprite: %s",invoker.cardSpriteName[cardID]);
		}
		let s = GetSpriteIndex(invoker.cardSpriteName[cardId]);
		return s;
	}
	
	/*override bool TryPickup(in out Actor toucher)
	{
		bool ret = super.TryPickup(toucher);
		if (ret)
		{
			vector3 catpos = ToM_UtilsP.FindRandomPosAround(toucher.pos, gridrad: 512, mindist: 80, fovlimit: 45, viewangle: toucher.angle);
			if (Level.IsPointInLevel(catpos))
			{
				let cat = Spawn("ToM_CheshireCat_Talk", catpos);
				if (cat)
				{
					cat.target = toucher;
				}
			}
		}
		return ret;
	}*/
	
	States
	{
	Spawn:
		ALCA A -1;
		stop;
	Select:
		APCR A 0 
		{
			A_WeaponOffset(24, WEAPONTOP + 54);
			A_CreateCardLayers();
			//PickACard();
		}
		#### ###### 1
		{
			A_WeaponOffset(-4, -9, WOF_ADD);
			A_WeaponReady(WRF_NOFIRE|WRF_NOBOB);
		}
		goto Ready;
	Deselect:
		APCR A 0 
		{
			A_RemoveCardLayers();
		}
		#### ###### 1
		{
			A_WeaponOffset(4, 9, WOF_ADD);
		}
		TNT1 A 0 A_Lower;
		wait;
	PrepareCard:
		TNT1 A 0
		{
			let p = player.FindPSprite(OverlayID());
			p.bInterpolate = false;
			A_OverlayFlags(OverlayID(), PSPF_ADDBOB|PSPF_ADDWEAPON, false);
			A_OverlayOffset(OverlayID(), 0, WEAPONTOP);
			A_OverlayPivot(OverlayID(), 0, 0.5);
			let psp = player.FindPSprite(OverlayID());
			switch (OverlayID())
			{
			case APSP_Card1: 
				psp.scale = (0.84, 0.84);
				break;
			case APSP_Card2: 
				psp.scale = (1.15, 1.15);
				break;
			case APSP_Card3: 
				psp.scale = (0.8, 0.8);
				break;
			}
		}
		TNT1 A 1;
		APCR BCD 1 
		{
			A_OffsetCardLayer(OverlayID());
			//if (OverlayID() == APSP_Card2)
				//A_OverlayScale(OverlayID(), 0.035, 0.035, WOF_ADD);
		}
		APCR EFG 2 
		{
			A_OffsetCardLayer(OverlayID());
			//if (OverlayID() == APSP_Card2)
				//A_OverlayScale(OverlayID(), 0.08, 0.08, WOF_ADD);
		}
	ReadyCardIdle:
		TNT1 A 0 
		{
			let s = A_PickCard();
			let psp = player.FindPSprite(OverlayID());
			if (psp && s)
			{
				psp.sprite = s;
				return ResolveState(null);
			}
			return ResolveState("Null");
		}			
		#### A 1 A_RotateIdleCard();		
		wait;
	FireCard:
		#### ### 1 
		{
			A_OverlayScale(OverlayID(), -0.3, -0.3, WOF_ADD);
			A_OverlayOffset(OverlayID(), -8, 3.2, WOF_ADD);
		}
		TNT1 A 0
		{
			A_OverlayOffset(OverlayID(), 0, WEAPONTOP);
			A_OverlayScale(OverlayID(), 1, 1);
		}
		TNT1 A 1;
		goto PrepareCard;
	RemoveCard:
		TNT1 A 0 A_OverlayFlags(OverlayID(), PSPF_ADDBOB, false);
		APCR GFEDCB 1
		{
			let psp = player.FindPSprite(OverlayID());
			if (psp)
			{
				psp.x *= 0.8;
				psp.y *= 0.8;
				psp.scale.x = Clamp(psp.scale.x * 0.8, 1, 10);
				psp.scale.y = Clamp(psp.scale.y * 0.8, 1, 10);
				// If this happens during altfire, also move
				// the cards to the right and down, to match
				// the movement of the arm:
				if (invoker.bAltFire)
				{
					psp.x -= 22;
					psp.y += 7;
				}
			}
		}
		stop;
	Ready:
		APCR A 1 
		{
			A_CheckReload();
			A_WeaponReady();
		}
		loop;
	Fire:
		TNT1 A 0 A_StopPSpriteReset();
	Hold:
		TNT1 A 0 
		{
			A_FireCardLayer();
			A_OverlayPivot(OverlayID(), 0, 0);
			vector2 ofs;
			switch (invoker.curCardLayer)
			{
			case APSP_Card1: ofs = (9, 0); break;
			case APSP_Card2: ofs = (12, 2); break;
			case APSP_Card3: ofs = (15, 1); break;
			}
			//console.printf("ofs: %1.f, %1.f", ofs.x, ofs.y);
			A_FireCard(1, 1, xofs: ofs.x, yofs: ofs.y);
		}
		APCR AAAAAAAAA 1 A_RotateHand();
		TNT1 A 0 
		{
			A_CheckReload();
			A_Refire();
		}
		TNT1 A 0 A_ResetPSprite(OverlayID(), 4);
		APCR A 4 A_WeaponReady(WRF_NOBOB); 
		goto Ready;
	AltFire:
		APCR A 1 A_RemoveCardLayers();
	AltHold:
		APCR AIIJJKK 1;
		APCR LLLL 1
		{
			invoker.cardFanAngle = FANSTARTANGLE;
			invoker.cardXpos = -2;
			A_OverlayOffset(OverlayID(), -2, 0, WOF_ADD);
		}
		APCR MMNNOOO 1 
		{
			A_OverlayOffset(OverlayID(), 2, 0, WOF_ADD);
			//let s = A_PickCard();
			double Yspread = 2;
			let proj = A_FireCard(
				invoker.cardFanAngle, 
				frandom[firecard](-Yspread, Yspread), 
				xofs: invoker.cardXpos, 
				yofs: -14, 
				explicitangle: true
			);
			invoker.cardFanAngle -= FANANGLESTEP;
			invoker.cardXpos += 1;
		}
		APCR OOOOO 1 A_OverlayOffset(OverlayID(), 2, 0, WOF_ADD);
		TNT1 A 0 A_ResetPSprite(OverlayID(), 5);
		APCR PPQAA 1;
		TNT1 A 0 A_ReFire();
		APCR A 6 A_CreateCardLayers();
		goto ready;
	Cache:
		ACC1 A 0; ACC2 A 0; ACC3 A 0; ACC4 A 0; ACC5 A 0; ACC6 A 0; ACC7 A 0; ACC8 A 0; ACC9 A 0; ACCT A 0; ACCJ A 0; ACCQ A 0; ACCK A 0; ACD1 A 0; ACD2 A 0; ACD3 A 0; ACD4 A 0; ACD5 A 0; ACD6 A 0; ACD7 A 0; ACD8 A 0; ACD9 A 0; ACDT A 0; ACDJ A 0; ACDQ A 0; ACDK A 0; ACH1 A 0; ACH2 A 0; ACH3 A 0; ACH4 A 0; ACH5 A 0; ACH6 A 0; ACH7 A 0; ACH8 A 0; ACH9 A 0; ACHT A 0; ACHJ A 0; ACHQ A 0; ACHK A 0; ACS1 A 0; ACS2 A 0; ACS3 A 0; ACS4 A 0; ACS5 A 0; ACS6 A 0; ACS7 A 0; ACS8 A 0; ACS9 A 0; ACST A 0; ACSJ A 0; ACSQ A 0; ACSK A 0;
	}
}

class ToM_CardData play
{
	name cardSpriteName;
	int cardValue;
	
	static ToM_CardData Create(name cardSpriteName, int value)
	{
		let ct = New("ToM_CardData");
		if (ct)
		{
			ct.cardSpriteName = cardSpriteName;
			ct.cardValue = value;
		}
		return ct;
	}
}

class ToM_CardProjectile : ToM_StakeProjectile
{	
	double broll;
	double angleCurve;
	double pitchCurve;
	//name spriteName;
	
	Default
	{
		ToM_Projectile.ShouldActivateLines true;
		ToM_Projectile.trailcolor "f4f4f4";
		ToM_Projectile.trailscale 0.013;
		ToM_Projectile.trailfade 0.024;
		ToM_Projectile.trailalpha 0.2;
		ToM_Projectile.DelayTraceDist 24;
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