class ToM_Knife : ToM_BaseWeapon
{	
	bool LeftSlash; //right slash or left slash?
	int combo; //combo counter
	int clawCombo; //claw combo counter
	
	const MAXRECALLTIME = 35 * 7; //recall knife after this wait time
	ToM_KnifeProjectile knife; //pointer to thrown knife
	protected int recallWait; //recall timer
	protected int otherHandWait;

	/*static const String pickupLines[] =
	{
		"$TOM_WEAPONMSG_KNIFE1",
		"$TOM_WEAPONMSG_KNIFE2",
		"$TOM_WEAPONMSG_KNIFE3"
	};*/
	
	Default 
	{
		Tag "$TOM_WEAPON_KNIFE";
		Inventory.Icon "AWICVKNF";
		ToM_BaseWeapon.CheshireSound "cheshire/vo/yourknife";
		+WEAPON.MELEEWEAPON;
		+WEAPON.NOAUTOFIRE;
		//Obituary "";
		weapon.slotnumber 1;
		//weapon.upsound "weapons/knife/draw";
	}

	/*override String PickupMessage()
	{
		String weapname = StringTable.Localize(GetTag());
		String comment = StringTable.Localize(pickupLines[random[msg](0, pickupLines.Size()-1)]);
		return String.Format("%s %s", weapname, comment);
	}*/
	
	action void A_KnifeReady(int flags = 0)
	{
		if (!player)
			return;
		
		if (invoker.wasThrown)
		{
			flags |= WRF_NOPRIMARY;
		}
		
		if (HasRageBox())
		{
			flags |= WRF_NOSWITCH;
		}
		
		// Don't bob the weapon if the main layer is currently
		// in the process of being reset (offsets aren't equal default):
		let pss = player.FindPSprite(PSP_WEAPON);
		if ( pss && (pss.x != 0 || pss.y != WEAPONTOP) )
		{
			flags |= WRF_NOBOB;
		}
		
		A_WeaponReady(flags);
	}
	
	action void A_ClawReady()
	{
		if (!player)
			return;
		
		if (!invoker.wasThrown)
			return;
		
		if (!HasRageBox())
			return;
		
		if (player.cmd.buttons & BT_ATTACK && !(player.oldbuttons & BT_ATTACK))
		{
			let psp = player.FindPSprite(APSP_LeftHand);
			if (psp)
				player.SetPSprite(APSP_LeftHand, ResolveState("ClawLeftSlash"));
		}
	}	
	
	action void A_SetKnifeSprite(name defsprite, name ragesprite = '')
	{
		if (!player)
			return;
		
		let psp = player.FindPSprite(OverlayID());
		if (!psp)
			return;
		
		if (ragesprite && HasRageBox())
			psp.sprite = GetSpriteIndex(ragesprite);
		
		else
			psp.sprite = GetSpriteIndex(defsprite);
	}

	const KNIFE_ParticleTrails = 20;

	action void A_PrepareKnifeSwing(Vector2 eye1start)
	{
		A_PrepareSwing(eye1start.x, eye1start.y, 0);
	}

	action void A_PrepareClawSwing(Vector2 eye1start, Vector2 eye2start, Vector2 eye3start, Vector2 eye4start)
	{
		A_PrepareSwing(eye1start.x, eye1start.y, 0);
		A_PrepareSwing(eye2start.x, eye2start.y, 1);
		A_PrepareSwing(eye3start.x, eye3start.y, 2);
		A_PrepareSwing(eye4start.x, eye4start.y, 3);
	}

	action void A_KnifeSwing(int damage, double stepX, double stepY)
	{
		let psp = player.FindPSprite(PSP_WEAPON);
		if (!psp) return;
		name decaltype;
		if (InStateSequence(psp.curstate, ResolveState("LeftSlash")))
		{
			decaltype = 'VKnifeLeft';
		}
		else if (InStateSequence(psp.curstate, ResolveState("RightSlash")))
		{
			decaltype = 'VKnifeLeft'; //'VKnifeRight';
		}
		else
		{
			decaltype = 'VKnifeDown';
		}
		Actor victim, puff;
		bool damaged;
		[victim, puff, damaged] = A_SwingAttack(
			damage, 
			stepX, stepY,
			range: 60,
			pufftype: 'ToM_KnifePuff',
			trailcolor: HasRageBox() ? 0xFFCC0000 : 0xFFFFFFFF,
			trailalpha: 0.65,
			trailsize: 1.5,
			trailtics: 15,
			style: PBS_Fade|PBS_Fullbright|PBS_Untextured,
			decaltype: decaltype,
			id: 0);
		if (victim && victim.health > 0 && damaged && random[knifepain](0, 100) <= ToM_Utils.LinearMap(invoker.combo, 0, 5, 15, 80))
		{
			let st = victim.FindState("Pain");
			if (st)
			{
				victim.SetState(st);
			}
		}
	}

	action void A_ClawSwing(int damage, double stepX, double stepY)
	{
		let psp = player.FindPSprite(APSP_LeftHand);
		if (!psp) return;
		name decaltype;
		if (InStateSequence(psp.curstate, ResolveState("ClawLeftSlash")))
		{
			decaltype = 'VClawRight';
		}
		else
		{
			decaltype = 'VClawDown';
		}
		for (int i = 0; i < 4; i++)
		{
			let victim = A_SwingAttack(
				(i == 0)? damage : 0,
				stepX, stepY,
				range: 60,
				pufftype: (i == 0)? 'ToM_ClawPuff' : '',
				trailcolor: 0xFFCC0000,
				trailalpha: 0.65,
				trailsize: 1.5,
				trailtics: 15,
				style: PBS_Fade|PBS_Fullbright|PBS_Untextured,
				decaltype: (i == 0)? decaltype : 'none',
				id: i);
		}
	}
	
	// Throws the knife and saves a pointer to it:
	action void A_ThrowKnife()
	{
		A_StopSound(CHAN_WEAPON);
		Actor a, b;
		[a, b] = A_FireProjectile("ToM_KnifeProjectile");
		if (b)
		{
			invoker.knife = ToM_KnifeProjectile(b);
			invoker.wasThrown = true;
			invoker.recallWait = MAXRECALLTIME;
		}
	}	
	
	// Calls the knife projectile to begin recalling
	// and activates the "recall particles" if not
	// yet active:
	action void A_RecallKnife()
	{
		if (invoker.knife && player)
		{
			invoker.knife.BeginRecall();
			
			if (player.readyweapon && player.readyweapon == invoker)
			{
				A_Overlay(APSP_Overlayer, "SpawnRecallParticles", true);
			}
		}
	}
	
	// Moves the calling layer away if the other layer is attacking
	// (moves the knife hand away while the claw is attacking
	// or vice versa):
	action void A_MoveHandAway( double scaleStep = 0.04, 
								double scaleLimit = 1.18, 
								vector2 offsetStep = (-10, 20),
								vector2 offsetLimit = (-50, 140),
								int resetTime = 35 )
	{
		if (!player)
			return;
		
		invoker.otherHandWait = resetTime;
		A_StopPSpriteReset(OverlayID(), droprightthere: true);
		
		let psp = player.FindPSprite(OverlayID());
		if (!psp)
			return;
		
		A_OverlayPivot(OverlayID(), 1, 0);
		double tscale = Clamp(psp.scale.x + scaleStep, 1, scaleLimit);
		psp.scale = (tscale, tscale);
		
		psp.x = Clamp(psp.x + offsetStep.x, psp.x, offsetLimit.x);
		psp.y = Clamp(psp.y + offsetStep.y, psp.y, offsetLimit.y);
	}
		
	
	void CatchKnife()
	{
		if (!owner || !owner.player)
			return;
		
		knife = null;
		wasThrown = false;
		owner.A_StartSound("weapons/knife/restore", CHAN_AUTO);
		
		let weap = owner.player.readyweapon;
		if (weap && weap == self)
		{
			let psp = owner.player.FindPSprite(PSP_WEAPON);
			if (psp && !InStateSequence(psp.curstate, ResolveState("CatchKnife")))
				psp.SetState(ResolveState("CatchKnife"));
		}
		
		if (tom_debugmessages)
			console.printf("Knife successfully recalled");
	}
		
	
	override void DoEffect()
	{
		super.DoEffect();
		if (!owner || !owner.player || owner.health <= 0)
			return;
		
		// Safety-check: if the bool says the knife was 
		// thrown but we don't have a valid pointer 
		// to the knife, just restore it by setting
		// the bool to false:
		if (wasThrown && !knife)
		{
			if (tom_debugmessages)
				console.printf("Lost pointer to thrown knife; restoring automatically");
			wasThrown = false;
		}
		
		// Automatic recall handling:
		if (recallWait > 0)
		{
			// Decrement timer:
			recallWait--;
			
			// If we're out of time and knife was 
			// actually thrown:
			if (recallWait <= 0 && wasThrown)
			{
				// If the knife pointer is still valid,
				// initate the recall:
				if (knife)
				{
					knife.BeginRecall();
				}
				// Otherwise do the recall anyway
				// and restore the knife in our hand:
				else
				{
					if (tom_debugmessages)
						console.printf("Lost pointer to thrown knife; restoring automatically");
					CatchKnife();
				}
			}
		}
	}
	
	States
	{
	/*Spawn:
		ALVB A -1;
		stop;*/
	ClawHandSelect:
		VCLW A 1
		{
			A_OverlayFlags(OverlayID(), PSPF_ADDWEAPON|PSPF_ADDBOB, false);
			A_OverlayOffset(OverlayID(), -24, WEAPONTOP+30);
			A_OverlayPivot(OverlayID(), 0.2, 0.8);
			A_RotatePSprite(OverlayID(), -30);
		}
		#### ###### 1
		{
			A_OverlayOffset(OverlayID(), 4, -5, WOF_ADD);
			A_RotatePSprite(OverlayID(), 5, WOF_ADD);
		}
		goto ClawHandReady;
	ClawHandReady:
		TNT1 A 0
		{
			A_OverlayPivot(OverlayID(), 0.2, 0.75);
			A_OverlayFlags(OverlayID(), PSPF_ADDWEAPON, false);
			A_OverlayFlags(OverlayID(), PSPF_ADDBOB, true);
			A_OverlayOffset(OverlayID(), 0, WEAPONTOP);
		}
		VCLW A 1 
		{
			if (!HasRageBox())
			{
				return ResolveState("ClawHandReadyLower");
			}
			
			let psw = player.FindPSprite(PSP_WEAPON);
			let psp = player.FindPSprite(OverlayID());
			if (psp && psw)
			{
				if (psw && InStateSequence(psw.curstate, ResolveState("Fire")))
				{
					A_MoveHandAway();
				}
				else if (invoker.otherHandWait > 0)
				{
					invoker.otherHandWait--;
					if (invoker.otherHandWait <= 0)
					{
						A_ResetPSprite(OverlayID(), 10);
					}
				}
			}
			
			if (invoker.clawCombo > 0 && level.maptime % 5 == 0)
			{
				invoker.clawCombo -= 1;
			}
			
			A_ClawReady();
			return ResolveState(null);
		}
		wait;
	ClawHandReadyLower:
		TNT1 A 0 
		{
			A_StopPSpriteReset();
			A_OverlayFlags(OverlayID(), PSPF_ADDBOB, false);
			if (tom_debugmessages)
				console.printf("Rage Mode over: deselecting claw");
		}
		VCLW AAAAA 1 
		{
			// For some reason A_OverlayOffset isn't working out
			// for me in this state sequence:
			//A_OverlayOffset(OverlayID(), -5, 20);
			let psp = player.FindPSprite(OverlayID());
			if (psp)
			{
				psp.x -= 5;
				psp.y += 20;
			}
		}
		stop;
	ClawLeftSlash:
		VCLW A 0 
		{
			A_StopPSpriteReset();
			invoker.clawCombo++;
			if (invoker.LeftSlash)
			{
				invoker.LeftSlash = false;
				return ResolveState("ClawDownSlash");
			}
			invoker.LeftSlash = true;
			
			A_OverlayPivot(OverlayID(), 0.5, 0.5);
			return ResolveState(null);
		}
		VCLW BBB 1
		{
			A_OverlayOffset(OverlayID(), -20, 0, WOF_ADD);
			A_RotatePSprite(OverlayID(), 5.5, WOF_ADD);
		}
		VCLW CCCC 1
		{
			A_OverlayOffset(OverlayID(), -8, 0, WOF_ADD);
			A_RotatePSprite(OverlayID(), 2.5, WOF_ADD);
		}
		TNT1 A 0 
		{
			A_StartSound("weapons/knife/swingold", CHAN_AUTO, pitch: 0.9);
			A_PrepareClawSwing((65, -10), (66, -7), (67, -4), (68, -1));
		}
		VCLW DDD 1
		{
			A_OverlayOffset(OverlayID(), 35, 0, WOF_ADD);
			A_RotatePSprite(OverlayID(), -5, WOF_ADD);
			A_ClawSwing(25, -18, 6);
		}
		VCLW EEEE 1
		{
			A_OverlayOffset(OverlayID(), 20, 0, WOF_ADD);
			A_RotatePSprite(OverlayID(), -3, WOF_ADD);
			A_ClawSwing(25, -18, 2);
		}
		TNT1 A 0 A_ResetPSprite(OverlayID(), 8);
		VCLW FFFF 1;
		VCLW AAAA 1 A_ClawReady();
		goto ClawHandReady;
	ClawDownSlash:
		VCLW A 0 
		{
			A_StopPSpriteReset();
			A_OverlayPivot(OverlayID(), 0.5, 0.5);
			A_RotatePSprite(OverlayID(), frandom[psprot](-20,0), WOF_INTERPOLATE);
		}
		VCLW GGH 1
		{
			A_OverlayOffset(OverlayID(), -5, -10, WOF_ADD);
			A_RotatePSprite(OverlayID(), 5.5, WOF_ADD);
		}
		VCLW HIII 1
		{
			A_OverlayOffset(OverlayID(), -3, -3.5, WOF_ADD);
			A_RotatePSprite(OverlayID(), 2.5, WOF_ADD);
		}
		TNT1 A 0 
		{
			A_StartSound("weapons/claw/swing", CHAN_AUTO, pitch: 0.9);
			A_PrepareClawSwing((20, -40), (23, -39), (26, -38), (29, -37));
		}
		VCLW JJK 1
		{
			A_OverlayOffset(OverlayID(), 30, 20, WOF_ADD);
			A_ClawSwing(30, -4, 15);
		}
		VCLW KKKK 1
		{
			A_OverlayOffset(OverlayID(), 30, 30, WOF_ADD);
			A_ClawSwing(30, -4, 15);
		}
		TNT1 A 0 A_ResetPSprite(OverlayID(), 8);
		VCLW LLLL 1;
		VCLW AAAA 1 A_ClawReady();
		goto ClawHandReady;
	Select:
		VKNF A 0 
		{
			if (HasRageBox())
			{
				A_SetSelectPosition(0, WEAPONTOP);
				return ResolveState("Ready");
				//A_Overlay(APSP_LeftHand, "ClawHandSelect");
			}

			if (invoker.wasThrown) 
			{
				A_SetKnifeSprite("VKNR", "VKRR");
			}
			else
			{
				A_SetKnifeSprite("VKNF", "VKRF");
			}
				
			A_SetSelectPosition(-24, 86);
			A_OverlayPivot(OverlayID(), 0.6, 0.8);
			A_RotatePSprite(OverlayID(), 30);
			return ResolveState(null);
		}
		#### ###### 1
		{
			A_WeaponOffset(4, -9, WOF_ADD);
			A_RotatePSprite(OverlayID(), -5, WOF_ADD);
			A_KnifeReady(WRF_NOFIRE|WRF_NOBOB);
		}
		goto Ready;
	Deselect:
		VKNF A 0 
		{
			if (invoker.wasThrown)
				A_SetKnifeSprite("VKNR");

			A_OverlayPivot(OverlayID(), 1, 1);
			let psp = player.FindPSprite(PSP_Weapon);
		}
		#### ###### 1
		{
			A_WeaponOffset(-4, 9, WOF_ADD);
			A_RotatePSprite(OverlayID(), 5, WOF_ADD);
		}
		TNT1 A 0 A_Lower;
		wait;
	Ready:
		TNT1 A 0 
		{
			invoker.LeftSlash = false;
		}
		#### A 1 
		{
			if (HasRageBox())
			{
				A_Overlay(APSP_LeftHand, "ClawHandReady", true);
			}

			if (invoker.wasThrown) 
			{
				A_SetKnifeSprite("VKNR", "VKRR");
			}
			else
				A_SetKnifeSprite("VKNF", "VKRF");
			
			if (invoker.combo > 0 && level.maptime % 5 == 0)
			{
				invoker.combo -= 1;
				if (tom_debugmessages > 1)
					console.printf("Knife combo counter: %d", invoker.combo);
			}
			
			// Move this hand away if the claw is currently attacking:
			if (HasRageBox() && invoker.wasThrown)
			{
				let psl = player.FindPSprite(APSP_LeftHand);
				if ( psl && 
					(InStateSequence(psl.curstate, ResolveState("ClawLeftSlash")) ||
					InStateSequence(psl.curstate, ResolveState("ClawDownSlash")) ) )
				{
					A_MoveHandAway(offsetStep: (10, 20), offsetLimit: (50, 140), resetTime: 20);
				}
				else if (invoker.otherHandWait > 0)
				{
					invoker.otherHandWait--;
					if (invoker.otherHandWait <= 0)
					{
						A_ResetPSprite(OverlayID(), 8);
					}
				}
			}
			else
				A_ResetPSprite(OverlayID());
			
			A_KnifeReady();
			return ResolveState(null);
		}
		wait;
	Fire:
		TNT1 A 0 
		{
			A_StopPSpriteReset();
			A_PlayerAttackAnim(15, 'attack_knife', 40);
			invoker.combo++;
			if (invoker.combo % 5 == 0)
			{
				return ResolveState("DownSlash");
			}
			invoker.LeftSlash = !invoker.LeftSlash;
			return invoker.LeftSlash ? ResolveState("LeftSlash") : ResolveState("RightSlash");
		}
	LeftSlash:
		TNT1 A 0 
		{
			A_SetKnifeSprite("VKNF", "VKRF");
			A_OverlayPivot(OverlayID(), 0.5, 0.5);
			A_RotatePSprite(OverlayID(), frandom[psprot](-20,0), WOF_INTERPOLATE);
		}
		#### BBB 1
		{
			A_WeaponOffset(20, 0, WOF_ADD);
			A_RotatePSprite(OverlayID(), -5.5, WOF_ADD);
		}
		#### A 0 
		{
			A_StartSound("weapons/knife/swing", CHAN_AUTO);
			A_PrepareKnifeSwing((-55, 0));
		}
		#### BBB 1
		{
			A_WeaponOffset(-60, 8, WOF_ADD);
			A_RotatePSprite(OverlayID(), 10, WOF_ADD);
			A_KnifeSwing(25, 20, 2);
		}
		/*TNT1 A 0 
		{
			A_KnifeSlash(25);
			A_SetKnifeSprite("VKNS", "VKRS");
		}*/
		#### CCC 1
		{
			A_WeaponOffset(-44, 5, WOF_ADD);
			A_RotatePSprite(OverlayID(), 5, WOF_ADD);
			A_KnifeSwing(25, 20, 2);
		}
		TNT1 A 0 
		{
			A_ResetPSprite(OverlayID(), 10);
			A_SetKnifeSprite("VKNF", "VKRF");
		}
		#### CCCHHHHAAA 1 A_KnifeReady(WRF_NOBOB);
		goto ready;
	RightSlash:
		TNT1 A 0 
		{
			A_SetKnifeSprite("VKNF", "VKRF");
			A_OverlayPivot(OverlayID(), 0.9, 0.7);
			A_RotatePSprite(OverlayID(), frandom[psprot](0,20), WOF_INTERPOLATE);
		}
		#### EEE 1
		{
			A_WeaponOffset(-24, -4, WOF_ADD);
			A_RotatePSprite(OverlayID(), 3, WOF_ADD);
		}
		#### A 0 
		{
			A_StartSound("weapons/knife/swing", CHAN_AUTO);
			A_PrepareKnifeSwing((45, 10));
		}
		#### EEE 1
		{
			A_WeaponOffset(80, 4, WOF_ADD);
			A_RotatePSprite(OverlayID(), -5, WOF_ADD);
			A_KnifeSwing(25, -25, -3);
		}		
		/*#### E 0 
		{
			A_KnifeSlash(25);
			A_SetKnifeSprite("VKNS", "VKRS");
		}*/
		#### FFF 1
		{
			A_WeaponOffset(65, 4, WOF_ADD);
			A_RotatePSprite(OverlayID(), -3, WOF_ADD);
			A_KnifeSwing(25, -20, -4);
		}
		#### A 0 
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
			A_RotatePSprite(OverlayID(), frandom[wrot](-5,25), WOF_INTERPOLATE);
		}
		#### GG 1 A_WeaponOffset(6, -5, WOF_ADD);
		#### A 0 
		{
			A_StartSound("weapons/knife/swing", CHAN_AUTO);
			A_PrepareKnifeSwing((-17, -40));
		}
		#### GGH 1 
		{
			A_WeaponOffset(-12, 35, WOF_ADD);
			A_KnifeSwing(30, 4, 15);
		}
		#### HHHH 1 
		{
			A_WeaponOffset(-18, 25, WOF_ADD);
			A_KnifeSwing(30, 4, 10);
		}
		TNT1 A 0 
		{
			A_ResetPSprite(OverlayID(), 9);
			A_SetKnifeSprite("VKNF", "VKRF");
		}
		#### HHHHZZZZZ 1 A_KnifeReady(WRF_NOBOB);
		goto ready;
	RecallKnife:
		#### # 1 A_RecallKnife();
		goto ready;
	AltFire:
		#### # 0 
		{
			if (invoker.wasThrown)
			{
				return ResolveState("RecallKnife");
			}
			A_ResetPSprite(OverlayID());
			A_SetKnifeSprite("VKNF", "VKRF");
			A_OverlayPivot(OverlayID(), 0.9, 0.9);
			A_PlayerAttackAnim(20, 'attack_knife_alt', 40);
			return ResolveState(null);
		}
		#### HHH 1
		{
			A_WeaponOffset(4, -3, WOF_ADD);
			A_RotatePSprite(OverlayID(), -1.5, WOF_ADD);
		}
		#### A 0 A_StartSound("weapons/knife/throw", CHAN_WEAPON);
		#### IIII 1
		{
			A_OverlayScale(OverlayID(), 0.15, 0.15, WOF_ADD);
			A_WeaponOffset(3, -1.5, WOF_ADD);
			A_RotatePSprite(OverlayID(), -1, WOF_ADD);
		}
		#### JJJ 1 
		{
			A_OverlayScale(OverlayID(), -0.1, -0.1, WOF_ADD);
			A_WeaponOffset(-5, 15, WOF_ADD);
			A_RotatePSprite(OverlayID(), 4, WOF_ADD);
		}
		#### A 0 A_ThrowKnife();
		#### KKK 1 
		{
			A_OverlayScale(OverlayID(), -0.015, -0.015, WOF_ADD);
			A_WeaponOffset(-5, 8, WOF_ADD);
			A_RotatePSprite(OverlayID(), 3, WOF_ADD);
		}
		#### KKK 1 A_WeaponOffset(-1.6, 2, WOF_ADD);
		#### KK 1 A_WeaponOffset(-0.5, 1, WOF_ADD);
		TNT1 A 0 
		{
			A_SetKnifeSprite("VKNR", "VKRR");
			A_ResetPSprite(OverlayID(), 6);
			A_RotatePSprite(OverlayID(), 10, WOF_ADD);
		}
		#### AAAAAA 1 A_KnifeReady(WRF_NOBOB|WRF_NOFIRE);
		goto Ready;
	CatchKnife:
		TNT1 A 0 
		{
			A_SetKnifeSprite("VKNR", "VKRR");
			A_WeaponOffset(15, 20);
			A_OverlayRotate(OverlayID(), -10);
			invoker.wasThrown = false;
			A_ResetPSprite(OverlayID(), 6);
		}
		#### BCDEFG 1;
		goto Ready;
	SpawnRecallParticles:
		TNT1 A 1
		{
			A_SpawnPSParticle("RecallKnifeParticle", density: 4, xofs: 80, yofs: 80);
			if (!invoker.wasThrown)
				return ResolveState("Null");
			
			return ResolveState(null);
		}
		wait;
	RecallKnifeParticle:
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
		VKNS A 0;
		VKNR A 0;
		VKRF A 0;
		VKRS A 0;
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
		ToM_BasePuff.ParticleAmount 20;
		ToM_BasePuff.ParticleColor 0xd4b856;
		ToM_BasePuff.ParticleSize 10;
	}
}

class ToM_ClawPuff : ToM_KnifePuff
{
	Default
	{
		attacksound "weapons/claw/scrape";
	}
}

// The actual knife projectile with all the logic
// and behavior. The 3D model is NOT attached to
// it; see ToM_KnifeProjectileModel for that.
class ToM_KnifeProjectile : ToM_StakeProjectile
{
	Actor knifemodel; //the actor that the 3d model is attached to
	int bleedDelay;
	int deathDelay;
	
	enum EKnifeValues
	{
		KV_RECALLSPEED = 34,
		KV_BLEEDELAYMIN = 15,
		KV_BLEEDELAYMAX = 40,
		KV_BLEEDDAMAGE = 5,
		KV_DEATHRECALLTIME = 35 * 2,
	}		
	
	static const color RecallColors[] =
	{
		"c6c3ff",
		"b5a7ff",
		"9275ff",
		"4d42ff"
	};
	
	bool ShooterHasRageBox()
	{
		return target && ToM_RageBox.HasRageBox(target);
	}
	
	Default
	{
		seesound ""; //Called from the weapon, not here
		deathsound "";
		renderstyle "Translucent";
		decal 'VKnifeThrown';
		speed 25;
		DamageFunction (random[knifedamage](60, 80));
		-NOGRAVITY
		+HITTRACER
		+BLOODSPLATTER
		gravity 0.2;
		radius 4;
		height 20;
		ToM_Projectile.ShouldActivateLines true;
	}
	
	// Called from the weapon to start recalling the knife:
	void BeginRecall()
	{
		// If NOCLIP is true, the knife is already
		// being recalled; do nothing:
		if (bNOCLIP)
		{
			if (tom_debugmessages)
				console.printf("Knife is already being recalled");
			return;
		}

		if (tom_debugmessages)
			console.printf("Recalling knife");
		
		if (tracer && tracer.bISMONSTER && tracer.health <= 0 && !tracer.bNOBLOOD)
		{
			for (int i = 4; i > 0; i--)
			{
				tracer.SpawnBlood(pos, tracer.AngleTo(self) + frandom[knifebleed](-15,15), 40);
			}
		}
		
		A_Stop();
		tracer = null;
		// Disable sticking-to-wall behavior - see StickToWall()
		// Without this the knife's pos.z would be forcefully
		// attached to a plane if it hit a 2-sided wall.
		// That behavior checks for bTHRUACTORS, so by disabling
		// it we disable the sticking behavior.
		// See ToM_StakeProjectile for details.
		bTHRUACTORS = false;
		bNOCLIP = true;
		SetStateLabel("Recall");
	}	
	
	// When run into a floor/ceiling by a moving wall,
	// recall it instead of destroying.
	// See ToM_StakeProjectile for details.
	override void StakeBreak()
	{
		BeginRecall();
	}

	override void StickToWall()
	{
		Super.StickToWall();
		// don't spawn on bleeding monsters:
		if (stickobject && stickobject.bShootable && !stickobject.bNOBLOOD && !stickobject.bINVULNERABLE)
		{
			return;
		}

		FLineTraceData tr;
		Vector3 dir; bool success;
		[dir, success] = ToM_Utils.GetNormalFromPos(self, 64, angle, pitch, tr);
		let puff = ToM_BasePuff(Spawn('ToM_KnifePuff', pos));
		if (puff)
		{
			// hit a plane:
			if (success)
			{
				puff.SpawnPuffEffects(dir, self.pos);
			}
			// hit a solid object:
			else
			{
				puff.SpawnPuffEffects(tr.hitDir * -1, self.pos);
			}
		}
	}
	
	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		A_StartSound("weapons/knife/throw", CHAN_AUTO, startTime: 0.25);
		knifemodel = Spawn("ToM_KnifeProjectileModel", pos);
		knifemodel.angle = angle;
		knifemodel.pitch = pitch;
		knifemodel.master = self;
		bleedDelay = random[knifebleed](KV_BLEEDELAYMIN, KV_BLEEDELAYMAX);
	}
	
	override void Tick()
	{
		super.Tick();
		if (isFrozen())
			return;
		
		if (knifemodel)
		{
			knifemodel.SetOrigin(pos, true);
			
			// If the knife is already stuck but not recalling,
			// adjust the model's angle and pitch to match it:
			if (bTHRUACTORS && !bNOCLIP)
			{
				knifemodel.angle = angle;
				knifemodel.pitch = pitch;
			}
			
			// Spawn the trail:
			if (!bTHRUACTORS)
			{
				let tr = Spawn("ToM_KnifeProjectileModel", pos);
				if (tr)
				{
					tr.angle = knifemodel.angle;
					tr.pitch = knifemodel.pitch;
					tr.A_SetRenderstyle(0.85, STYLE_Stencil);
					tr.SetShade(ShooterHasRageBox() ? "FF0000" : "BBBBBB");
				}
			}
		}
		
		// Auto-recall the knife after a delay if the victim
		// has already died:
		if (!bNOCLIP && tracer && tracer.bSHOOTABLE && tracer.health <= 0)
		{
			deathDelay++;
			if (deathDelay >= KV_DEATHRECALLTIME)
			{
				if (tom_debugmessages)
					console.printf("Victim has been dead for %d tics, recalling knife", deathDelay);
				BeginRecall();
			}
		}
		
		if (!target || !tracer || !tracer.bSHOOTABLE || tracer.health <= 0 || tracer.bNOBLOOD)
			return;
			
		// Do the bleed damage to the enemy the knife is stuck into.
		// Rather than employing a control item, I do it from the 
		// knife itself. It keeps things simpler and makes sure
		// the effect persists as long as the knife is stuck in
		// the victim:
		if (bleedDelay > 0)
		{
			bleedDelay--;
			if (bleedDelay <= 0)
			{
				bleedDelay = random[knifebleed](KV_BLEEDELAYMIN,KV_BLEEDELAYMAX);
				int fflags = DMG_THRUSTLESS;
				// 66% chance to not cause pain:
				if (random[knifebleed](1,3) != 1)
				{
					fflags |= DMG_NO_PAIN;
				}
				
				// do the damage:
				let dmg = tracer.DamageMobj(self,target,KV_BLEEDDAMAGE,"Bleed",flags:fflags);
				
				// If damage is > 0, spawn blood and the visuals:
				if (dmg > 0)
				{
					let al = Spawn("ToM_BleedLayer", tracer.pos);
					if (al)
						al.master = tracer;
					if (!tracer.bNoBlood && !tracer.bDormant)
					{
						tracer.SpawnBlood(pos, tracer.AngleTo(self), dmg);
					}
				}
			}
		}
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
		TNT1 A -1
		{
			StickToWall();
			A_StartSound("weapons/knife/throwflesh");
		}
		stop;
	Death:
		TNT1 A -1
		{
			A_StopSound(CHAN_BODY);
			A_StartSound("weapons/knife/throwwall");
			if (knifemodel)
				knifemodel.A_SetPitch(pitch);
			StickToWall();
		}
		stop;
	Recall:
		TNT1 A 1
		{
			if (target && target.player)
			{
				vector3 vec = Vec3To(target) + (0, 0, target.player.viewz - 10 - target.pos.z);
				vel = vec.Unit() * min(Distance3D(target), KV_RECALLSPEED);
				
				if (knifemodel)
				{
					A_FaceTarget(flags:FAF_MIDDLE);
					knifemodel.angle = angle + 180;
					knifemodel.pitch -= 10;
					FSpawnParticleParams pp;
					pp.color1 = "";
					pp.texture = TexMan.CheckForTexture("SPRKC0", TexMan.Type_Any);
					pp.size = 8;
					// make particle larger for consoleplayer if it's their knife
					// and it's far away:
					if (target.player && target.player == players[consoleplayer])
					{
						double size = ToM_Utils.LinearMap(Distance3D(target), target.radius, 1024, 10, 40);
						pp.size = Clamp(size, 8, 40);
					}
					pp.sizestep = pp.size * -0.05;
					pp.lifetime = 64;
					pp.flags = SPF_FULLBRIGHT;
					pp.style = STYLE_Add;
					pp.startalpha = 0.5;
					pp.fadestep = -1;
					double ho = 16;
					double v = 1.5;
					for (int i = 3; i > 0; i--)
					{
						pp.vel = (frandom[knifepart](-v,v),frandom[knifepart](-v,v),frandom[knifepart](-v,v));
						pp.accel = pp.vel * -0.05;
						pp.pos = pos + (frandom[knifepart](-ho,ho), frandom[knifepart](-ho,ho), frandom[knifepart](-ho,ho));
						Level.SpawnParticle(pp);
					}
				}
				
				if (Distance2D(target) <= 64 && abs(pos.z - target.player.viewz) <= 64 )
				{
					let kn = ToM_Knife(target.FindInventory("ToM_Knife"));
					if (kn)
					{
						kn.CatchKnife();
					}
					
					if (knifemodel)
					{
						knifemodel.Destroy();
					}
					
					Destroy();
				}
			}
		}
		loop;
	}
}

class ToM_BleedLayer : ToM_ActorLayer
{
	Default
	{
		Renderstyle 'Stencil';
		stencilcolor "EE0000";
		alpha 0.8;
		ToM_ActorLayer.Fade 0.05;
	}
}

// The visual actor that the 3D model of the knife
// is attached to.
// If it has no master, it's used as a trail.
class ToM_KnifeProjectileModel : ToM_SmallDebris
{
	Default
	{
		+NOINTERACTION
		+NOBLOCKMAP
	}
	
	override void Tick()
	{
		super.Tick();
		// If it has no master, it's being used as 
		// a trail, not the actual knife model,
		// so we'll fade it out:
		if (!master && !isFrozen())
		{
			A_FadeOut(0.045);
		}
	}
	
	States
	{
	Spawn:
		M000 A -1;
		stop;
	}
}