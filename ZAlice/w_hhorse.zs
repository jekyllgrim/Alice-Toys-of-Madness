class ToM_HobbyHorse : ToM_BaseWeapon
{
	int combo;
	int totalcombo;
	int fallAttackForce;
	double curPSProtation;
	Vector2 curPSPscale;
	int swingHoldTime; //incremented if the player presses and holds the attack button, adding extra damage
	const MAXHOLDTIME = 18;
	
	Default
	{
		Tag "$TOM_WEAPON_HORSE";
		Inventory.Icon "AWICHHRS";
		ToM_BaseWeapon.CheshireSound "cheshire/vo/billyclub";
		ToM_BaseWeapon.IsTwoHanded true;
		+WEAPON.MELEEWEAPON
		+WEAPON.NOAUTOFIRE
		Weapon.slotnumber 1;
		Weapon.slotpriority 1;
	}

	action void A_PrepareHorseSwing(Vector2 eye1start, Vector2 eye2start)
	{
		A_PrepareSwing(eye1start.x, eye1start.y, 0);
		A_PrepareSwing(eye2start.x, eye2start.y, 1);
	}

	action void A_PrepareHorseHold()
	{
		let psp = player.FindPSprite(OverlayID());
		invoker.curPSProtation = psp.rotation;
		invoker.curPSPscale = psp.scale;
		invoker.swingHoldTime = 0;
	}

	action State A_HoldHorseSwing(StateLabel nextSlashState)
	{
		State st = ResolveState(nextSlashState);
		if (!st)
		{
			return ResolveState("Ready");
		}
		if (invoker.atkButtonState == ABS_Held)
		{
			invoker.swingHoldTime = invoker.swingHoldTime < MAXHOLDTIME? invoker.swingHoldTime + 1 : MAXHOLDTIME;
			double rot = ToM_Utils.LinearMap(invoker.swingHoldTime, 0, MAXHOLDTIME, 0, 0.25, true);
			A_OverlayRotate(OverlayID(), invoker.curPSProtation + frandom(-rot, rot), WOF_INTERPOLATE);
			double sc = ToM_Utils.LinearMap(invoker.swingHoldTime, 0, MAXHOLDTIME, 0, 0.05);
			A_OverlayScale(OverlayID(), invoker.curPSPscale.x + sc, invoker.curPSPscale.y + sc, WOF_INTERPOLATE);
			return ResolveState(null);
		}
		return st;
	}

	action State A_HorseRefire()
	{
		return A_CheckNextSlash("Fire", "AltFire", true);
	}
	
	// Do the attack and move the offset one step as defined above:
	action void A_HorseSwing(int damage, double stepX, double stepY)
	{
		let psp = player.FindPSprite(PSP_WEAPON);
		if (!psp) return;
		name decaltype;
		switch (invoker.combo)
		{
			case 0:
			case 1:
				decaltype = 'HorseDecalLeft';
				break;
			case 2:
				decaltype = 'HorseDecalRight';
				break;
			default:
				decaltype = 'HorseDecalDown';
				break;
		}

		if (invoker.swingHoldTime > 0)
		{
			damage += int(round(ToM_Utils.LinearMap(invoker.swingHoldTime, 0, MAXHOLDTIME, 0, 20, true)));
		}

		Actor victim, puff;
		bool wasHit;
		for (int i = 0; i < 2; i++)
		{
			[victim, puff, wasHit] = A_SwingAttack(
				(i == 0)? damage : 0, 
				stepX, stepY,
				range: 80, 
				pufftype: (i == 0)? 'ToM_HorsePuff' : '',
				trailcolor: 0xff00BB,
				trailsize: 8,
				style: PBS_Fade|PBS_Fullbright,
				rstyle: Style_Add,
				decaltype: (i == 0)? decaltype : 'none',
				id: i);
			
			if (i != 0 || !victim || !wasHit || !(victim.bIsMonster || victim.player))
			{
				continue;
			}

			double stunchance = ToM_Utils.LinearMap(victim.health, 300, 2000, 100, 25, true);
			if (stunchance < random(0, 100))
			{
				continue;
			}
			
			if (!victim.bNogravity && !victim.bDontThrust)
			{
				double pushspeed = ToM_Utils.LinearMap(victim.mass, 100, 800, 5, 0, true);
				if (victim.health < 0)
				{
					pushspeed *= 2;
				}

				Vector3 pushdir;
				double ang;
				switch (invoker.combo)
				{
					case 0:
					case 1:
						ang = self.angle + 90;
						break;
					case 2:
						ang = self.angle - 90;
						break;
					default:
						ang = self.angle;
						pushdir.z = pushspeed;
						break;
				}
				pushdir.xy = Actor.RotateVector((pushspeed, 0), ang);
				victim.vel = pushdir;
			}

			if (victim.health <= 0)
			{
				victim.freezeTics = 0;
			}
			else
			{
				int freezebonus = int(round(ToM_Utils.LinearMap(invoker.swingHoldTime, 0, MAXHOLDTIME, 0, 13, true)));
				victim.freezeTics = max(victim.freezeTics, int(ToM_Utils.LinearMap(invoker.totalcombo, 1, 8, 12 + freezebonus, 35 + freezebonus, true)));
				if (victim.freezeTics > 0)
				{
					let stunflash = ToM_ActorLayer.Create(victim, STYLE_TranslucentStencil, alpha: 0.7, fade: 0.7 / victim.freezeTics, fullbright: true);
					if (stunflash)
					{
						stunflash.SetShade(0xffffff);
					}
				}
				State pst = victim.FindState("Pain");
				if (victim.freezeTics > 12 && pst && !InStateSequence(victim.curstate, pst))
				{
					victim.SetState(pst);
				}
			}
		}
	}

	const MAXEYEFIRE = 20;
	/*uint curFirePos;
	Vector3 eyeFirePos[MAXEYEFIRE];*/
	protected Vector3 prevViewAngles[MAXEYEFIRE];
	protected Vector3 prevRelMove[MAXEYEFIRE];
	protected Vector3 curRelMove;

	action void A_SpawnHorseEyeFire()
	{
		invoker.curRelMove = (RotateVector(vel.xy, -angle), vel.z);
		A_SpawnPSParticle("HorseReadyParticle", xofs: frandom[hrp](-2,2), yofs: frandom[hrp](-2,2), maxlayers: MAXEYEFIRE);
		A_SpawnPSParticle("HorseReadyParticle", bottom: true, xofs: frandom[hrp](-2,2), yofs: frandom[hrp](-2,2), maxlayers: MAXEYEFIRE);
		A_Overlay(APSP_TopParticle-1, "HorseReadyParticleBase", true);
	}

	action void A_AnimateHorseEyeFire()
	{
		int ovid = OverlayID();
		let psp = player.FindPSprite(ovid);
		if (!psp) return;
		let psw = player.FindPSprite(PSP_WEAPON);
		if (!psw || !InStateSequence(psw.curstate, ResolveState("Ready")))
		{
			psp.Destroy();
			return;
		}

		// first-time setup (alpha check is used to determine
		// if this has been done yet):
		if (psp.alpha >= 1.0)
		{
			A_OverlayFlags(ovid,PSPF_RENDERSTYLE|PSPF_FORCESTYLE|PSPF_FORCEALPHA,true);
			A_OverlayPivotAlign(ovid,PSPA_CENTER,PSPA_CENTER);
			A_OverlayRenderstyle(ovid,Style_Add);
			psp.scale = (1.5,1.5);
			psp.alpha = 0.3;
			psp.bInterpolate = false;
			if (ovid > 0)
			{
				int i = Clamp(ovid - APSP_TopParticle, 0, MAXEYEFIRE-1);
				invoker.prevViewAngles[i] = (angle, pitch, roll);
				invoker.prevRelMove[i] = invoker.curRelMove;
			}
		}

		// Update values only on the top layer:
		if (ovid > 0)
		{
			int i = Clamp(ovid - APSP_TopParticle, 0, MAXEYEFIRE-1);
			Vector3 hm = invoker.prevRelMove[i] * 0.5; //X - relative forward, Y - relative sideways
			Vector3 vm = invoker.prevViewAngles[i];

			Vector3 baseMove = (0, 0, -2); //scale/depth (forward/backward), horizontal, vertical
			baseMove.x += hm.x; //forward/back
			baseMove.y += hm.y - (vm.x - angle); //horizontal
			baseMove.z += vm.y - pitch + hm.z*0.5; //vertical

			Vector2 ofs, sc;
			[ofs, sc] = ToM_Utils.WorldToPSpriteCoords(baseMove.x, baseMove.y, baseMove.z, self.pitch, 0.2);

			psp.x += ofs.x; //horizontal
			psp.y += ofs.y; //vertical
			psp.scale += sc;
			
			// update cached values:
			invoker.prevViewAngles[i] = (angle, pitch, roll);
			invoker.prevRelMove[i] = invoker.curRelMove;

			psp.alpha -= 0.015;
		}
		// Copy values on bottom layer from top layer:
		else
		{
			let pspTop = player.FindPSprite(ovid + APSP_TopParticle - APSP_BottomParticle);
			if (pspTop)
			{
				psp.x = pspTop.x + 15;
				psp.y = pspTop.y + 5;
				psp.scale = pspTop.scale;
				psp.alpha = pspTop.alpha;
			}
		}

		if (psp.scale.x <= 0 || psp.scale.y <= 0 || psp.alpha <= 0)
		{
			psp.Destroy();
		}
	}

	/*void DrawEyeFireParticles(Vector3 newpos)
	{
		for (int i = 0; i < MAXEYEFIRE-1; i++)
		{
			eyeFirePos[i] = eyeFirePos[i+1];
		}
		eyeFirePos[MAXEYEFIRE-1] = newPos;
		for (int i = 0; i < MAXEYEFIRE-1; i++)
		{
			Vector3 from = eyeFirePos[i];
			Vector3 to = eyeFirePos[i+1];
			if (from != (0,0,0) && to != (0,0,0))
			{
				ToM_Utils.DrawParticlesFromTo(from, to, 
					density: 0.5, 
					size: 4,
					lifetime: 12,
					vel: (0,0,0.1),
					texture: "LEGYA0",
					pcolor: 0xffff0066,
					renderstyle: STYLE_Shaded,
					style: PBS_Fullbright|PBS_Fade);
			}
		}
	}*/

	action void A_StartJumpAttack()
	{
		invoker.combo = 0;
		A_ResetPSprite();
		A_OverlayPivot(OverlayID(), 0.2, 0.8);
		A_StartSound("weapons/hhorse/jumpattack", CHAN_BODY);
		vector3 forwarddir = (cos(angle), sin(angle), 0);
		double fwdvel = vel dot forwarddir;
		VelFromAngle(fwdvel + 7);
		// jump has to be reset to not mess with jumping/falling-after-jump gravity:
		player.jumptics = 0;
		if (player.onGround)
		{
			vel.z += 12;
		}
	}

	action void A_LandAttack()
	{
		A_StopSound(CHAN_BODY);
		A_StartSound("*land", CHAN_BODY);
		A_CameraSway(0, 30, 4);

		int fallAttackForce = invoker.fallAttackForce;
		//int fallAttackForce = (abs(vel.x) + abs(vel.y)) * 0.5 + abs(vel.z);
		
		int rad = 128 + fallAttackForce;
		vector3 ipos = ToM_Utils.RelativeToGlobalCoords(self, (radius + 8, 0, 0));
		ipos.z = floorz;
		let hi = Spawn("ToM_HorseImpactSpot", ipos);
		if (hi)
		{
			hi.target = self;
			hi.A_Explode(80 + fallAttackForce, rad, 0);
			hi.A_StartSound("weapons/hhorse/hitfloor", CHAN_7);
			double qints = ToM_Utils.LinearMap(fallAttackForce, 4, 32, 1, 4, true);
			int qdur = int(ToM_Utils.LinearMap(fallAttackForce, 4, 32, 10, 30, true));
			hi.A_Quake(qints, qdur, 0, rad, sfx: "");
			for (int i = random[sfx](12,16); i > 0; i--)
			{
				double randomDebrisVel = 5;
				let debris = Spawn("ToM_RandomDebris", hi.pos + (frandom[sfx](-rad, rad),frandom[sfx](-rad, rad), 0));
				if (debris) 
				{
					double zvel = (pos.z > floorz) ? frandom[sfx](-randomDebrisVel,randomDebrisVel) : frandom[sfx](randomDebrisVel * 0.5, randomDebrisVel);
					debris.vel = (frandom[sfx](-randomDebrisVel,randomDebrisVel),frandom[sfx](-randomDebrisVel,randomDebrisVel),zvel);
					debris.A_SetScale(frandom[sfx](0.5, 1.5));
					debris.gravity *= 0.5;
				}
			}

			FSpawnParticleParams pp;
			pp.texture = TexMan.CheckForTexture("SPRKA0");
			pp.flags = SPF_FULLBRIGHT|SPF_ROLL;
			pp.style = STYLE_Add;
			pp.color1 = "";
			pp.startalpha = 1;
			pp.fadestep = -1;
			for (int i = random[sfx](30,40); i > 0; i--)
			{
				pp.pos = pos + (random[psfx](-rad, rad), random[psfx](-rad, rad), 0);
				pp.lifetime = random[psfx](40, 50);
				Vector2 hvel = (frandom[psfx](0.5, 3), frandom[psfx](-0.5, 0.5));
				double hangle = frandom[psfx](0, 360);
				pp.vel.z = frandom[psfx](0.5, 2);
				pp.vel.xy = Actor.RotateVector(hvel, hangle);
				pp.accel.xy = Actor.RotateVector((hvel.x / pp.lifetime * 0.5, hvel.y * -0.5), hangle);
				pp.size = random[psfx](10, 18);
				pp.sizestep = (pp.size / pp.lifetime) * -0.5;
				Level.SpawnParticle(pp);
			}
		}

		int reps = int(ToM_Utils.LinearMap(fallAttackForce, 40, 1, 5, 1, true));
		for (int i = 0; i <= reps; i++)
		{
			let iring = ToM_HorseImpact(Spawn("ToM_HorseImpact", ipos));
			iring.scale.x = rad * ToM_Utils.LinearMap(i, 0, reps, 0.3, 1.0);
			iring.scale.y = iring.scale.x;
		}

		if (fallAttackForce >= 29 && pos.z <= floorz)
		{
			let hid = Spawn("ToM_HorseImpactDebris", ipos);
		}

		vel.z = 5;
	}

	override void OnDeselect(Actor dropper)
	{
		Super.OnDeselect(dropper);
		if (dropper)
		{
			if (dropper.IsActorPlayingSound(CHAN_BODY, "weapons/hhorse/freefall"))
			{
				dropper.A_StopSound(CHAN_BODY);
			}
			combo = totalcombo = 0;
			swingHoldTime = 0;
		}
	}
	
	override void DoEffect()
	{
		super.DoEffect();
		if (!owner || !owner.player)
			return;
		
		if (!owner.player.onGround)
		{
			let weap = owner.player.readyweapon;
			if (weap && weap == self)
			{
				let psp = owner.player.FindPSprite(PSP_WEAPON);
				if (!psp)
					return;
				
				if (InStateSequence(psp.curstate, ResolveState("AltFire")))
				{
					fallAttackForce = int(ceil( (abs(owner.vel.x) + abs(owner.vel.y)) * 0.15 + abs(owner.vel.z) ));
				}
			}
		}
	}
	
	States
	{
	/*Spawn:
		ALHH A -1;
		stop;*/
	Select:
		HHRS A 0 
		{
			A_SetSelectPosition(-24, 90+WEAPONTOP);
			A_OverlayPivot(OverlayID(), 0.6, 0.8);
			A_OverlayRotate(OverlayID(), -18);
		}
		#### ###### 1
		{
			A_WeaponOffset(4, -15, WOF_ADD);
			A_OverlayRotate(OverlayID(), 3, WOF_ADD);
			A_WeaponReady(WRF_NOFIRE|WRF_NOBOB);
		}
		goto Ready;
	Deselect:
		HHRS A 0
		{
			A_OverlayPivot(OverlayID(), 0.6, 0.8);
			invoker.combo = invoker.totalcombo = 0;
		}
		#### ###### 1
		{
			A_ResetZoom();
			A_WeaponOffset(-4, 15, WOF_ADD);
			A_OverlayRotate(OverlayID(), -3, WOF_ADD);
		}
		TNT1 A 0 A_Lower;
		wait;
	Ready:
		HHRS A 1 
		{
			A_WeaponReady();
			invoker.swingHoldTime = 0;
			if (invoker.totalcombo > 0 && level.maptime % 3 == 0)
			{
				invoker.totalcombo--;
			}
			A_SpawnHorseEyeFire();
		}
		wait;
	HorseReadyParticleBase:
		TNT1 A 0 
		{
			A_OverlayFlags(OverlayID(),PSPF_RENDERSTYLE|PSPF_FORCEALPHA,true);
			A_OverlayPivotAlign(OverlayID(),PSPA_CENTER,PSPA_CENTER);
			A_OverlayRenderstyle(OverlayID(),Style_Add);
			A_OverlayScale(OverlayID(), 2.2, 2.2);
		}
		HHRP A 1 bright
		{
			let psp = player.FindPSprite(OverlayID());
			if (psp)
			{
				psp.bInterpolate = false;
				psp.scale.x = psp.scale.y = 1.9 + 0.3 * ToM_Utils.SinePulse();
				psp.alpha = 0.4 + 0.2 * ToM_Utils.SinePulse();
			}
			//Vector2 hmove = RotateVector(vel.xy, -angle);
			//Console.Printf("Forward/back: %.1f | Left/Right: %.1f", hmove.x, hmove.y);
			psp = player.FindPSprite(PSP_WEAPON);
			if (!psp || !InStateSequence(psp.curstate, ResolveState("Ready")))
			{
				return ResolveState("Null");
			}
			return ResolveState(null);
		}
		wait;
	HorseReadyParticle:
		HHRP A 1 bright A_AnimateHorseEyeFire();
		wait;
	Fire:
		TNT1 A 0 
		{
			A_ResetPSprite();
			invoker.combo++;
			invoker.totalcombo++;
			if (invoker.combo <= 1) {
				A_PlayerAttackAnim(30, 'attack_horse', 15);
				return ResolveState("RightSwing");
			}
			if (invoker.combo == 2) {
				A_PlayerAttackAnim(30, 'attack_horse', 15);
				return ResolveState("LeftSwing");
			}
			A_PlayerAttackAnim(40, 'attack_horse', 10);
			return ResolveState("Overhead");
		}
	RightSwing:
		TNT1 A 0 A_OverlayPivot(OverlayID(), 0.1, 0.6);
		HHRS AAABBBB 1 
		{
			A_WeaponOffset(6, -13, WOF_ADD);
			A_RotatePSprite(OverlayID(), -1.2, WOF_ADD);
		}		
		HHRS CCC 1 
		{
			A_WeaponOffset(3, 0, WOF_ADD);
			A_RotatePSprite(OverlayID(), -0.5, WOF_ADD);
		}
		#### # 0 A_PrepareHorseHold();
		#### # 1 A_HoldHorseSwing("RightSwingDo");
		wait;
	RightSwingDo:
		TNT1 A 0 
		{
			A_PrepareHorseSwing((-25, -10), (-20, -20));
			A_StartSound("weapons/hhorse/swing", CHAN_AUTO);
			A_CameraSway(4, 0, 6);
		}
		HHRS BB 1 
		{
			A_HorseSwing(40, 14, 4);
			A_WeaponOffset(-35, 12, WOF_ADD);
			A_RotatePSprite(OverlayID(), 3, WOF_ADD);
		}
		HHRS DD 1 
		{
			A_HorseSwing(40, 14, 4);
			A_WeaponOffset(-50, 22, WOF_ADD);
			A_RotatePSprite(OverlayID(), 3, WOF_ADD);
		}
		HHRS DDD 1 
		{
			A_HorseSwing(40, 14, 4);
			A_WeaponOffset(-50, 22, WOF_ADD);
			A_RotatePSprite(OverlayID(), 4, WOF_ADD);
		}
		goto AttackEnd;
	LeftSwing:
		TNT1 A 0 A_OverlayPivot(OverlayID(), 0.6, 1);
		HHRS AAAEEEE 1 
		{
			A_WeaponOffset(-6, -9, WOF_ADD);
			A_RotatePSprite(OverlayID(), 1.2, WOF_ADD);
		}
		HHRS GGGG 1 
		{
			A_WeaponOffset(-3, 0, WOF_ADD);
			A_RotatePSprite(OverlayID(), 0.5, WOF_ADD);
		}
		#### # 0 A_PrepareHorseHold();
		#### # 1 A_HoldHorseSwing("LeftSwingDo");
		wait;
	LeftSwingDo:
		TNT1 A 0 
		{
			A_PrepareHorseSwing((25, -10), (20, -20));
			A_StartSound("weapons/hhorse/swing", CHAN_AUTO);
			A_CameraSway(-4, 0, 6);
		}
		HHRS FF 1 
		{
			A_HorseSwing(40, -15, 5);
			A_WeaponOffset(35, 12, WOF_ADD);
			A_RotatePSprite(OverlayID(), -3, WOF_ADD);
		}
		HHRS HH 1 
		{
			A_HorseSwing(40, -15, 5);
			A_WeaponOffset(45, 18, WOF_ADD);
			A_RotatePSprite(OverlayID(), -3, WOF_ADD);
		}
		HHRS HHH 1 
		{
			A_HorseSwing(40, -15, 5);
			A_WeaponOffset(45, 18, WOF_ADD);
			A_RotatePSprite(OverlayID(), -3, WOF_ADD);
		}
		goto AttackEnd;
	Overhead:
		TNT1 A 0 A_OverlayPivot(OverlayID(), 0.2, 0.8);
		HHRS KKKKLLLL 1 
		{
			A_WeaponOffset(1.2, -3, WOF_ADD);
			A_RotatePSprite(OverlayID(), -0.3, WOF_ADD);
			A_ScalePSprite(OverlayID(), 0.0025, 0.0025,WOF_ADD);
		}
		HHRS MMMMMMMM 1 
		{
			A_WeaponOffset(0.6, -1.2, WOF_ADD);
			A_RotatePSprite(OverlayID(), -0.3, WOF_ADD);
			A_ScalePSprite(OverlayID(), 0.0025, 0.0025,WOF_ADD);
		}
		#### # 0 A_PrepareHorseHold();
		#### # 1 A_HoldHorseSwing("OverheadDo");
		wait;
	OverheadDo:
		TNT1 A 0 
		{
			A_PrepareHorseSwing((-2, -30), (-18, -30));
			A_StartSound("weapons/hhorse/heavyswing", CHAN_AUTO);
			A_CameraSway(0, 5, 7);
		}
		HHRS NOO 1 
		{
			A_HorseSwing(60, 1.5, 16);
			A_WeaponOffset(-24, 35, WOF_ADD);
			A_RotatePSprite(OverlayID(), 0.1, WOF_ADD);
			A_ScalePSprite(OverlayID(), -0.003, -0.003, WOF_ADD);
		}
		HHRS OO 1 
		{
			A_HorseSwing(60, 1.5, 16);
			A_WeaponOffset(-24, 35, WOF_ADD);
			A_RotatePSprite(OverlayID(), 0.1, WOF_ADD);
			A_ScalePSprite(OverlayID(), -0.003, -0.003, WOF_ADD);
		}
		TNT1 A 0 { invoker.combo = 0; }
		goto AttackEnd;
	AttackEnd:
		TNT1 A 5
		{
			A_WeaponOffset(24, 90+WEAPONTOP);
			A_RotatePSprite(OverlayID(), -30);
			return A_HorseRefire();
		}
		HHRS AAAAAA 1
		{
			A_WeaponOffset(-4, -15, WOF_ADD);
			A_RotatePSprite(OverlayID(), 5, WOF_ADD);
			return A_HorseRefire();
		}
		TNT1 A 0 
		{ 
			A_ResetPSprite();
			invoker.combo = 0;
		}
		goto Ready;
	Altfire:
		TNT1 A 0 
		{
			A_StartJumpAttack();
			A_PlayerAttackAnim(-1, 'attack_horse_alt', 30);//, loopframe: 9, flags: SAF_LOOP);
		}
		HHRS KKKKLLLL 1 
		{
			A_WeaponOffset(1.2, -4, WOF_ADD);
			A_RotatePSprite(OverlayID(), -0.3, WOF_ADD);
			A_ScalePSprite(OverlayID(), 0.0025, 0.0025,WOF_ADD);
		}
		HHRS MMMMMMMM 1 
		{
			A_WeaponOffset(0.6, -1.5, WOF_ADD);
			A_RotatePSprite(OverlayID(), -0.3, WOF_ADD);
			A_ScalePSprite(OverlayID(), 0.0025, 0.0025,WOF_ADD);
		}
		TNT1 A 0 
		{
			A_PrepareHorseSwing((-2, -30), (-18, -30));
			A_StartSound("weapons/hhorse/altswing", CHAN_AUTO);
			A_CameraSway(0, 5, 7);
			//A_Overlay(APSP_Overlayer, "OverheadTrail");
		}
		HHRS NNNOOOOOOO 1 
		{
			A_HorseSwing(0, 0.5, 8);
			A_WeaponOffset(-4, 4, WOF_ADD);
			A_RotatePSprite(OverlayID(), 0.03, WOF_ADD);
			A_ScalePSprite(OverlayID(), -0.001, -0.001, WOF_ADD);
		}
		goto FallLoop;
	FallLoop:
		HHRS O 1
		{
			let psp = player.FindPSprite(OverlayID());
			if (psp)
			{
				A_WeaponOffset(Clamp(psp.x-2, -68, 0), Clamp(psp.y+2, 32, 68), WOF_INTERPOLATE);
			}
			A_HorseSwing(0, 0.05, 0.5);
			if (tom_debugmessages)
				console.printf("fall attack force: %d", invoker.fallAttackForce);
			if (invoker.fallAttackForce > 25)
				A_StartSound("weapons/hhorse/freefall", CHAN_BODY, CHANF_LOOPING);
		}
		TNT1 A 0 
		{
			if (waterlevel >= 2)
			{
				A_StopSound(CHAN_BODY);
				self.tics = 1;
				return ResolveState("AltAttackEnd");
			}
			if (!player.onGround)
			{
				return ResolveState("FallLoop");
			}
			return ResolveState(null);
		}
		TNT1 A 0 
		{
			A_LandAttack();
			A_PlayerAttackAnim(45, 'attack_horse_jump_end', 15);
		}
		HHRS OOOO 1 A_WeaponOffset(3, -6, WOF_ADD);
		goto AltAttackEnd;
	AltAttackEnd:
		HHRS OOOOOOOOO 1 
		{
			A_WeaponOffset(-6, 20, WOF_ADD);
			A_RotatePSprite(OverlayID(), 2, WOF_ADD);
		}
		goto AttackEnd;
	}
}

class ToM_HorsePuff : ToM_BasePuff
{
	Default
	{
		+NOINTERACTION
		+PUFFONACTORS
		seesound "weapons/hhorse/hitflesh";
		attacksound "weapons/hhorse/hitwall";
		ToM_BasePuff.ParticleAmount 4;
		ToM_BasePuff.ParticleSpeed 3;
	}
	
	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		int val = 1;
		if (target && target.player)
		{
			let wpn = ToM_HobbyHorse(target.player.readyweapon);
			if (wpn)
				val *= wpn.combo;
			target.A_QuakeEx(val, val, val, 6, 0, 32, "");
		}
	}

	override void SpawnPuffEffects(Vector3 dir, Vector3 origin)
	{
		if (puff_particles <= 0 || waterlevel > 0) return;

		FSpawnParticleParams p;
		if (origin == (0,0,0))
		{
			origin = pos + (0,0,height*0.5);
		}
		double yaw = atan2(dir.y, dir.x);
		double pch = -atan2(dir.z, dir.xy.Length());
		Quat orientation = Quat.FromAngles(yaw, pch, 0.0);
		for (int i = int(round(puff_particles * frandom[puffvis](0.8, 1.2))); i > 0; i--)
		{
			double v = 30;
			Quat offset = Quat.FromAngles(frandom[puffvis](-v, v), frandom[puffvis](-v, v), 0.0);
			ToM_WhiteSmoke.Spawn(
				origin,
				vel: orientation * offset * (puff_partvel * frandom[puffvis](0.8, 1.2), 0.0, 0.0),
				scale: 0.18,
				alpha: 0.8,
				fade: 0.03
			);
		}
	}

	States
	{
	Spawn:
		TNT1 A 10;
		stop;
	}
}

class ToM_HorseImpactSpot : ToM_BaseActor
{
	Default
	{
		+NOBLOCKMAP
		+NOINTERACTION
	}

	States {
	Spawn:
		TNT1 A 70;
		stop;
	}
}

class ToM_HorseImpact : ToM_SmallDebris
{
	int delay;
	Default
	{
		+NOINTERACTION
		+BRIGHT
		renderstyle 'Add';
	}

	States {
	Spawn:
		TNT1 A 0 A_SetTics(delay);
		M000 A 1
		{
			scale *= 1.05;
			A_FadeOut(0.05);
		}
		wait;
	}
}

class ToM_HorseImpactDebris : ToM_BaseActor
{
	Default
	{
		+NOINTERACTION
		+NOBLOCKMAP
		+MOVEWITHSECTOR
	}

	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		A_StartSound("weapons/hhorse/hitfloor_heavy");
		if (waterlevel > 0 || CheckLiquidFlat() || ToM_StaticStuffHandler.IsAnimatedTexture(floorpic))
		{
			Destroy();
			return;
		}
		name texname = TexMan.GetName(floorpic);
		A_ChangeModel("", skinindex: 0, skin: texname, flags: CMDL_USESURFACESKIN);
	}

	override void Tick()
	{
		super.Tick();
		SetZ(floorz);
		if (target)
			target.SetZ(floorz + 0.5);
	}

	States {
	Spawn:
		M000 A 100;
		TNT1 A 0 
		{
			if (target)
				target.Destroy();
		}
		M000 A 1 A_FadeOut(0.05);
		wait;
	}
}