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
		Tag "$TOM_WEAPON_CARDS";
		ToM_BaseWeapon.CheshireSound "cheshire/vo/52pickup";
		Inventory.Icon "AWICCARD";
		weapon.slotnumber 2;
		weapon.ammotype1 "ToM_WeakMana";
		weapon.ammouse1 2;
		weapon.ammogive1 100;
		weapon.ammotype2 "ToM_WeakMana";
		weapon.ammouse2 1;
	}
	
	action void A_CreateCardLayers()
	{
		if (!player || health <= 0)
			return;
		A_Overlay(APSP_Card1, "PrepareCard");
		A_Overlay(APSP_Card2, "PrepareCard");
		A_Overlay(APSP_Card3, "PrepareCard");
	}	
	
	action void A_FireCardLayer()
	{
		invoker.curCardLayer = invoker.cardLayernum[invoker.cardLayerID];
		let psp = player.FindPSprite(invoker.curCardLayer);
		if (psp)
		{
			player.SetPSPrite(invoker.curCardLayer, ResolveState("FireCard"));
			if (tom_debugmessages)
			{
				Console.Printf("\cyCARDS\c- Playing card attack animation on layer \cd%d\c-", invoker.curCardLayer);
			}
		}
		invoker.cardLayerID++;
		if (invoker.cardLayerID >= invoker.cardLayerNum.Size())
			invoker.cardLayerID = 0;
	}

	action void A_RotateIdleCard()
	{
		int layer;
		switch (OverlayID())
		{
		case APSP_Card1:
			layer = 0;
			break;
		case APSP_Card2:
			layer = 1;
			break;
		case APSP_Card3:
			layer = 2;
			break;
		}
		for (int i = 0; i < 4; i++)
		{
			double ang = ANGLESTEP * Clamp(invoker.cardVertStep[layer], 1, CARDSTEPS) + (CARDANGLEDIFF * 10);
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
		double sc = ToM_Utils.LinearMap(coords.y, -CARDRAD, CARDRAD, 1, 1.06);
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

	action Actor A_FindCardTarget(double dist = 2048, double aimAngle = 15)
	{
		let it = BlockThingsIterator.Create(self, dist);
		Actor closest;
		double closestDist = dist;
		double atkheight = ToM_Utils.GetPlayerAtkHeight(player.mo);
		vector3 eyes = pos + (0,0,atkheight);
		while (it.Next())
		{
			let t = it.thing;
			if (!t)
				continue;
			
			if (t.health <= 0 || !t.bSHOOTABLE || t.bNONSHOOTABLE || !(t.bIsMonster || t.player))
				continue;
			
			vector3 coords = Level.SphericalCoords(eyes, t.pos + (0,0,t.height*0.5), (angle, pitch));
			if (coords.z > closestDist)
				continue;
			
			double angFac = ToM_Utils.LinearMap(coords.z + radius + t.radius, 0, dist, 1.0, 0.1);
			if (abs(coords.x) > aimAngle*angFac || abs(coords.y) > aimAngle*angFac)
				continue;
			
			if (CheckSight(t,SF_IGNOREWATERBOUNDARY))
			{
				//Console.Printf("Found %s. Coords: %.1f, %.1f, %1.f", t.GetClassName(), coords.x, coords.y, coords.z);
				closestDist = coords.z;
				closest = t;
			}
		}
		return closest;
	}
	
	action Actor A_FireCard(double xspread = 0, double yspread = 0, double xofs = 0, double yofs = 0, bool altmode = false)
	{
		double horspread = altmode ? xspread : frandom[firecard](-xspread, xspread);
		double vertspread = altmode ? yspread : frandom[firecard](-yspread, yspread);
		
		//console.printf("firing a card at an angle of %1.f", horspread);
		let proj = ToM_CardProjectile(A_Fire3DProjectile(
			"ToM_CardProjectile",
			forward: radius,
			leftright: xofs,
			updown: yofs,
			crosshairConverge: true,
			angleoffs: horspread, 
			pitchoffs: vertspread
		));
		
		if (proj)
		{
			proj.A_StartSound("weapons/cards/fire", pitch:frandom[sfx](0.95, 1.05));
			proj.tracer = A_FindCardTarget();
			//proj.altmode = altmode;
			
			int dmg;
			name spritename;
			
			if (altmode)
			{
				[dmg, spritename] = invoker.PickRandomCard();
				proj.vel *= 0.35;
				proj.seekDelay = 14;
				proj.seekAngle = 6;
			}
			
			else 
			{
				int cardId = 0;
				switch (invoker.curCardLayer)
				{
				default:		 cardId = 0; break;
				case APSP_Card2: cardId = 1; break;
				case APSP_Card3: cardId = 2; break;
				}
				
				dmg = Clamp(invoker.cardDamage[cardId], 1, 10);
				spritename = invoker.cardSpriteName[cardId];
				if (tom_debugmessages)
				{
					console.printf("\cyCARDS\c- Card layer \cd%d\c-: sprite \cd%s\c- | damage \cd%d\c-", invoker.curCardLayer, spritename, dmg);
				}
			}
			
			//let sprt = GetSpriteIndex(spritename);
			//if (sprt > 0)
			//{
			//	proj.sprite = sprt;
			//}
			String newskin = String.Format("models/cards/tx%s.png", spritename);
			if (tom_debugmessages)
			{
				console.printf("\cyCARDS\c- Changing card model's skin to \cd\"%s\"\c- for layer \cd%d\c-", newskin, invoker.curCardLayer);
			}
			proj.A_ChangeModel("", skin: newskin);
			proj.cardSpecialDamage = dmg * 3;
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
				if (csprite > 0)
				{
					let ct = ToM_CardData.Create(name(spritename), val);
					if (ct)
						Cards.Push(ct);
				}
			}
		}
	}
	
	int, name PickRandomCard()
	{
		int cardValue = 0;
		name cardSpriteName = '';
	
		if (Cards.Size() <= 0)
		{
			if (tom_debugmessages)
				console.printf("\cyCARDS\c- \cdCards\c- array empty: filling");
			FillCardsArray();
		}
		
		int id = random[pickcard](0, Cards.Size() - 1);
		let ct = Cards[id];
		if (ct)
		{
			cardValue = ct.cardValue;
			cardSpriteName = ct.cardSpriteName;
			Cards.Delete(id);
		}
		
		if (tom_debugmessages)
			console.printf("\cyCARDS\c- Selected card sprite: \cd%s\c- | value: \cd%d\c-", cardSpriteName, cardValue);
		
		return cardValue, cardSpriteName;
	}
	
	// Picks the next card:
	action SpriteID A_SetLayerCard()
	{
		//let nullsprite = GetSpriteIndex("TNT1A0");
		if (!player || health <= 0)
			return -1;
		
		int cardId = 0;
		int layerID = OverlayID();
		switch (layerID)
		{
		default: 		 cardId = 0; break;
		case APSP_Card2: cardId = 1; break;
		case APSP_Card3: cardId = 2; break;
		}
		if (tom_debugmessages)
			console.printf("\cyCARDS\c- Attempting to set card for layer \cd%d\c-", layerID);
			
		int dmg; name spriteName;
		[dmg, spriteName] = invoker.PickRandomCard();
		
		invoker.cardDamage[cardId] = dmg;
		invoker.cardSpriteName[cardId] = spriteName;
				
		let s = GetSpriteIndex(invoker.cardSpriteName[cardId]);
		if (s > 0)
		{
			if (tom_debugmessages)
				console.printf("\cyCARDS\c- Selected sprite \cd%s\c- for layer \cd%d\c-", invoker.cardSpriteName[cardID], layerID);
			return s;
		}
		
		if (tom_debugmessages)
		{
			console.printf("\cyCARDS\c- \cd%s\c- couldn't resolve a valid sprite index, returning -1 (layer \cd%d\c-", invoker.cardSpriteName[cardID], layerID);
		}
		
		return -1;
	}

	override void DoEffect()
	{
		super.DoEffect();
		if (!owner || !owner.player)
			return;
		
		let weap = owner.player.readyweapon;
		if (!weap || weap != self)
			return;

		int d = cardVertStep[0] + 1;
		
		cardVertStep[0] = d;
		cardVertStep[1] = d + 7;
		cardVertStep[2] = d + 15;

		for (int i = 0; i < 3; i++)
		{
			if (cardVertStep[i] > CARDSTEPS)
			{
				cardVertStep[i] -= CARDSTEPS;
			}
		}
	}
	
	/*override bool TryPickup(in out Actor toucher)
	{
		bool ret = super.TryPickup(toucher);
		if (ret)
		{
			vector3 catpos = ToM_Utils.FindRandomPosAround(toucher.pos, gridrad: 512, mindist: 80, fovlimit: 45, viewangle: toucher.angle);
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
	/*Spawn:
		ALCA A -1;
		stop;*/
	Select:
		APCR A 0 
		{
			A_SetSelectPosition(24, WEAPONTOP + 54);
			A_CreateCardLayers();
		}
		#### ###### 1
		{
			A_WeaponOffset(-4, -9, WOF_ADD);
			A_WeaponReady(WRF_NOFIRE|WRF_NOBOB);
		}
		goto Ready;
	Deselect:
		APCR A 0 A_RemoveCardLayers();
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
		APCR BCD 1 A_OffsetCardLayer(OverlayID());
		APCR EFG 2 A_OffsetCardLayer(OverlayID());
	ReadyCardIdle:
		TNT1 A 0 
		{
			let s = A_SetLayerCard();
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
		#### # 0 
		{
			Vector2 pivot;
			switch (OverlayID())
			{
			case APSP_Card1:
			case APSP_Card2: 
				pivot = (0,0);
				break;
			case APSP_Card3: 
				pivot = (0,0.6);
				break;
			}
			A_OverlayPivot(OverlayID(), pivot.x, pivot.y);
		}
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
				psp.y += 12;
				psp.scale.x = Clamp(psp.scale.x * 0.8, 1, 10);
				psp.scale.y = Clamp(psp.scale.y * 0.8, 1, 10);
				// If this happens during altfire, also move
				// the cards to the left and down, to match
				// the movement of the arm:
				let psw = player.FindPSprite(PSP_WEAPON);
				if (psw && InStateSequence(psw.curstate, ResolveState("AltFire")))
				{
					psp.x -= 22;
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
		TNT1 A 0 
		{
			A_StopPSpriteReset();
		}
	Hold:
		TNT1 A 0 
		{
			A_PlayerAttackAnim(-1, 'attack_cards', 30, endframe: 2, interpolateTics: 6);
			A_FireCardLayer();
			A_OverlayPivot(OverlayID(), 0, 0);
			vector2 ofs;
			switch (invoker.curCardLayer)
			{
			case APSP_Card1: ofs = (3, 0); break;
			case APSP_Card2: ofs = (4, 2); break;
			case APSP_Card3: ofs = (5, 1); break;
			}
			//console.printf("ofs: %1.f, %1.f", ofs.x, ofs.y);
			A_FireCard(1, 1, xofs: ofs.x, yofs: ofs.y);
		}
		APCR AAAAAAAA 1 A_RotateHand();
		TNT1 A 0 
		{
			A_CheckReload();
			A_Refire();
		}
		TNT1 A 0 
		{
			A_ResetPSprite(OverlayID(), 4);
			A_PlayerAttackAnim(1, 'attack_cards', 30, endframe: 2);
		}
		APCR A 4 A_WeaponReady(WRF_NOBOB); 
		goto Ready;
	AltFire:
		APCR A 1 A_RemoveCardLayers();
	AltHold:
		TNT1 A 0 A_PlayerAttackAnim(34, 'attack_cards', 24);
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
			//let s = A_SetLayerCard();
			double Yspread = 2;
			let proj = A_FireCard(
				invoker.cardFanAngle, 
				frandom[firecard](-Yspread, Yspread), 
				xofs: invoker.cardXpos, 
				yofs: -14, 
				altmode: true
			);
			invoker.cardFanAngle -= FANANGLESTEP;
			invoker.cardXpos += 1;
		}
		APCR OOOOO 1 A_OverlayOffset(OverlayID(), 2, 0, WOF_ADD);
		TNT1 A 0 A_ResetPSprite(OverlayID(), 6);
		APCR PPQQAA 1;
		TNT1 A 0 A_ReFire();
		APCR A 5 A_CreateCardLayers();
		goto ready;
	Cache:
		ACC1 A 0; ACC2 A 0; ACC3 A 0; ACC4 A 0; ACC5 A 0; ACC6 A 0; ACC7 A 0; ACC8 A 0; ACC9 A 0; ACCT A 0; ACCJ A 0; ACCQ A 0; ACCK A 0; 
		ACD1 A 0; ACD2 A 0; ACD3 A 0; ACD4 A 0; ACD5 A 0; ACD6 A 0; ACD7 A 0; ACD8 A 0; ACD9 A 0; ACDT A 0; ACDJ A 0; ACDQ A 0; ACDK A 0; 
		ACH1 A 0; ACH2 A 0; ACH3 A 0; ACH4 A 0; ACH5 A 0; ACH6 A 0; ACH7 A 0; ACH8 A 0; ACH9 A 0; ACHT A 0; ACHJ A 0; ACHQ A 0; ACHK A 0; 
		ACS1 A 0; ACS2 A 0; ACS3 A 0; ACS4 A 0; ACS5 A 0; ACS6 A 0; ACS7 A 0; ACS8 A 0; ACS9 A 0; ACST A 0; ACSJ A 0; ACSQ A 0; ACSK A 0;
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
	const TRAILOFS = 4;
	double broll;
	double angleCurve;
	double pitchCurve;
	int cardSpecialDamage;
	int seekDelay;
	int seekAngle;
	//bool altmode;
	
	Default
	{
		ToM_Projectile.ShouldActivateLines true;
		ToM_Projectile.trailcolor "f4f4f4";
		ToM_Projectile.trailscale 0.013;
		ToM_Projectile.trailfade 0.005;
		ToM_Projectile.trailalpha 0.1;
		+ROLLSPRITE
		+SCREENSEEKER
		+BLOODSPLATTER
		renderstyle "Translucent";
		speed 55;
		DamageFunction SetCardDamage();
		gravity 0.6;
		radius 4;
		height 0.5;
		scale 0.75;
	}

	int SetCardDamage()
	{
		int dmg = cardSpecialDamage > 0 ? cardSpecialDamage : 20;
		if (tom_debugmessages > 1)
			console.printf("\cyCARDS\c- card damage: %d", dmg);
		return dmg;
	}

	// Spawn two trails at card eges relative to its roll:
	override void SpawnTrail(vector3 ppos)
	{
		FSpawnParticleParams trail;

		vector3 projpos = ToM_Utils.RelativeToGlobalCoords(self, (-TRAILOFS, -TRAILOFS, 0), isPosition: false);
		CreateParticleTrail(trail, ppos + projpos, trailvel);
		Level.SpawnParticle(trail);
		
		projpos = ToM_Utils.RelativeToGlobalCoords(self, (-TRAILOFS, TRAILOFS, 0), isPosition: false);
		CreateParticleTrail(trail, ppos + projpos, trailvel);
		Level.SpawnParticle(trail);
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

		seekAngle = Clamp(seekAngle, 1, 90);
	}

	void A_CardSeek(double ang)
	{
		if (age <= seekDelay || seekAngle <= 0) return;
		
		if (tracer)
		{
			double angTo = DeltaAngle(angle, AngleTo(tracer));
			if (abs(angTo) > 90 || abs(PitchTo(tracer)) > 45)
			{
				tracer = null;
			}
			else
			{
				A_SetRoll(roll - Clamp(angTo, -20, 20), SPF_INTERPOLATE);
			}
			A_SeekerMissile(0, seekAngle, SMF_PRECISE|SMF_CURSPEED, 256);
		}
		
//		if (!tracer)
//		{
//			if (GetAge() % 10 == 0)
//			{
//				tracer = RoughMonsterSearch(1080, true);
//			}
//		}
//		else
//		{
//			double angTo = DeltaAngle(angle, AngleTo(tracer));
//			if (abs(angTo) > 90 || abs(PitchTo(tracer)) > 45)
//			{
//				tracer = null;
//				return;
//			}
//			A_SetRoll(roll - Clamp(angTo, -20, 20), SPF_INTERPOLATE);
//			Vector3 endpos, dir;
//			double theight = max(tracer.height, tracer.projectilePassHeight);
//			double ofsz = theight*0.5;
//			double aimOfsZ = ofsz;
//			ToM_CardSeekTracer cardtracer;
//			for (int i = 0; i < 2; i++)
//			{
//				switch(i)
//				{
//					default: ofsz = theight*0.95; break; //try top
//					case 1: ofsz = theight*0.05; break; //try bottom
//					case 2: ofsz = theight*0.5; break; //try middle
//				}
//				endpos = (tracer.pos.xy, tracer.pos.z + ofsz);
//				dir = Level.Vec3Diff(self.pos, endpos).Unit();
//				cardtracer = new('ToM_CardSeekTracer');
//				cardtracer.Trace(self.pos, cursector, dir, PLAYERMISSILERANGE, TRACE_HitSky);
//				/*if (cardtracer.HitActor)
//				{
//					Console.Printf("Attempt \cd%d\c-: Tracer hit \cd%s\c- at \cd%.2f\c- offset", i, cardtracer.HitActor.GetClassName(),  ofsz / theight);
//				}*/
//				//ToM_DebugSpot.Spawn(cardtracer.results.hitPos, 1);
//				if (cardtracer.hitActor == tracer)
//				{
//					aimOfsZ = ofsz;
//					break;
//				}
//			}
//			A_Face(tracer, seekAngle, seekAngle, flags: FAF_BOTTOM, z_ofs: aimOfsZ);
//			Vel3DFromAngle(speed, angle, pitch);
//		}
	}
	
	States
	{
	Spawn:
		M000 A 1 A_CardSeek(seekangle);
		loop;
	XDeath:
		TNT1 A 1 A_StartSound("weapons/cards/hitflesh", CHAN_AUTO, attenuation: 8);
		stop;
	Death:
		M000 A 60
		{
			A_SetRenderstyle(alpha, Style_Translucent);
			A_StartSound("weapons/cards/hitwall", CHAN_AUTO, attenuation: 8);
			StickToWall();
		}
		M000 A 1 
		{
			A_FadeOut(0.15);
		}
		wait;
	}
}

class ToM_CardSeekTracer : LineTracer
{
	Actor hitActor;

	override ETraceStatus TraceCallBack()
	{
		let ht = results.hitType;
		if (ht == TRACE_HitFloor || ht == TRACE_HitCeiling || ht == TRACE_HitWall || ht == TRACE_HasHitSky)
		{
			return TRACE_Stop;
		}

		if (ht == TRACE_HitActor)
		{
			let ha = results.HitActor;
			if (ha && (ha.bSolid || ha.bSHOOTABLE))
			{
				self.HitActor = ha;
				return TRACE_Stop;
			}
		}

		return TRACE_Skip;
	}
}