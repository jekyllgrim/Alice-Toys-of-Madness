class ToM_AlicePlayer : DoomPlayer
{
	const MAXAIRJUMPTICS = 6;
	const MAXAIRJUMPS = 1;
	const AIRJUMPTICTHRESHOLD = -4;
	const AIRJUMPFACTOR = 0.8;
	const BASEMODELPATH = "models/alice";
	const MAXCOYOTETIME = 10;

	static const name leaftex[] =
	{ 
		'AIRLEAF1', 'AIRLEAF2', 'AIRLEAF3', 'AIRLEAF4', 'AIRLEAF5', 'AIRLEAF6', 'AIRLEAF7', 'AIRLEAF8' 
	};

	static const name modelnames[] =
	{
		"aliceweap_knife.iqm",
		"aliceweap_horse.iqm",
		"aliceweap_cards.iqm",
		"aliceweap_jacks.iqm",
		"aliceweap_pgrinder.iqm",
		"aliceweap_teapot.iqm",
		"aliceweap_icewand.iqm",
		"aliceweap_eyestaff.iqm",
		"aliceweap_blunderbuss.iqm"
	};

	enum EWModels
	{
		AW_Knife,
		AW_Horse,
		AW_Cards,
		AW_Jacks,
		AW_PGrinder,
		AW_Teapot,
		AW_IceWand,
		AW_Eyestaff,
		AW_Blunderbuss,
		AW_NoWeapon = -1000,
	}

	enum EModelIndexes
	{
		MI_Character   = 0,
		MI_Weapon      = 1,
		MI_LeftArm     = 2,
		MI_RageParts   = 3,
	}

	enum ESurfaceIndexes
	{
		SI_TorsoLegs,
		SI_Head,
		SI_Skirt,
		SI_Arms,
		SI_BowStraps,
		SI_BowSkull,
		SI_Hair,
	}

	protected ToM_HUDFaceController hudFace;
	
	protected int curWeaponID;
	protected vector2 prevMoveDir;
	double modelDirection;

	protected State s_jump;
	protected State s_airjump;
	protected State s_jumpLoop;
	protected State s_pain;
	protected uint airJumps;
	protected uint airJumpTics;
	array <ToM_PspResetController> pspcontrols;

	array <Actor> collideFilter;
	bool doingPlungingAttack;

	protected uint fallingTics;
	protected uint coyoteTime;
	protected double coyoteZ;

	protected ToM_PlayerCamera specialCamera;
	protected ToM_CrosshairSpot crosshairSpot;

	clearscope ToM_HUDFaceController GetHUDFace()
	{
		return hudface;
	}

	Default
	{
		+INTERPOLATEANGLES
		+DECOUPLEDANIMATIONS
		+DONTTRANSLATE
		+NOPAIN
		player.StartItem "ToM_Knife", 1;
		player.Viewheight 51;
		player.AttackZOffset 18;
		player.DisplayName "Alice";
		MeleeRange 80;
	}

	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		SetAnimation('basepose', flags:SAF_LOOP|SAF_INSTANT);
		curWeaponID = AW_NoWeapon;

		s_jump = ResolveState("Jump");
		s_airjump = ResolveState("JumpAir");
		s_jumpLoop = ResolveState("JumpLoop");
		s_pain = ResolveState("Pain");

		String pcTex = ToM_PCANTEX_BODY..PlayerNumber();
		A_ChangeModel("", skinindex: SI_TorsoLegs, skin: pcTex, flags: CMDL_USESURFACESKIN);

		pcTex = ToM_PCANTEX_BODY2..PlayerNumber();
		A_ChangeModel("", skinindex: SI_Skirt, skin: pcTex, flags: CMDL_USESURFACESKIN);

		pcTex = ToM_PCANTEX_ARM..PlayerNumber();
		A_ChangeModel("", skinindex: SI_Arms, skin: pcTex, flags: CMDL_USESURFACESKIN);
	}

	ToM_CrosshairSpot GetCrosshairSpot()
	{
		return crosshairSpot;
	}
	
	bool IsPlayerMoving()
	{
		let player = self.player;
		return (player.cmd.forwardmove != 0 || player.cmd.sidemove != 0);
	}

	bool IsPlayerRunning()
	{
		return IsPlayerMoving() && (player.cmd.buttons & BT_RUN);
	}

	bool IsPlayerFlying()
	{
		return bFLYCHEAT || (player.cheats & CF_FLY) || (player.cheats & CF_NOCLIP2);
	}

	void ResetAirJump()
	{
		airJumps = 0;
	}

	void UpdateMovementAnimation()
	{
		if (ToM_Utils.IsVoodooDoll(self))
		{
			return;
		}

		double hvel = vel.xy.Length();
		bool twohanded;
		let weap = ToM_BaseWeapon(player.readyweapon);
		twohanded = weap && weap.IsTwoHanded;

		// slow animations down when using Growth cake:
		double minFr = 15;
		double maxFr = 40;
		if (FindInventory('ToM_GrowthPotionEffect'))
		{
			minFr *= ToM_GrowthPotionEffect.SPEEDFACTOR;
			maxFr *= ToM_GrowthPotionEffect.SPEEDFACTOR;
		}

		// swimming
		if (waterLevel >= 2)
		{
			SetAnimation('swim_loop', interpolateTics: 5, flags:SAF_LOOP|SAF_NOOVERRIDE);
			SetAnimationFrameRate(ToM_Utils.LinearMap(hvel, 3, 18, minFr, maxFr));
		}
		// falling (not jumping)
		else if (!player.onground && !coyoteTime && !IsPlayerFlying())
		{
			fallingTics++;
			// after a few tics, switch to jump animation:
			if (fallingTics > 14)
			{
				if (!InStateSequence(curstate, s_jump))
				{
					SetAnimation('jump', startframe: 9, loopframe: 9, interpolateTics: 10, flags:SAF_LOOP|SAF_NOOVERRIDE);
					SetState(s_jumpLoop);
				}
			}
			// otherwise slow down current falling animation:
			else
			{
				SetAnimationFrameRate(3);
			}
		}
		else
		{
			fallingTics = 0;
			// standing still
			if (hvel <= 0.1)
			{
				SetAnimation('basepose', interpolateTics: 10, flags:SAF_LOOP|SAF_NOOVERRIDE);
			}
			// walking
			else if (hvel <= 7.5)
			{
				SetAnimation(twohanded? 'walk_bigweapon' : 'walk_smallweapon', interpolateTics: 5, flags:SAF_LOOP|SAF_NOOVERRIDE|SAF_INSTANT);
				SetAnimationFrameRate(ToM_Utils.LinearMap(hvel, 2, 7.5, minFr, maxFr));
			}
			// running
			else
			{
				SetAnimation(twohanded? 'run_bigweapon' : 'run_smallweapon', flags:SAF_LOOP|SAF_NOOVERRIDE|SAF_INSTANT);
				SetAnimationFrameRate(ToM_Utils.LinearMap(hvel, 7.5, 20, minFr, maxFr));
			}
		}
	}

	void UpdateWeaponModel()
	{
		if (!player)
			return;

		let weap = ToM_BaseWeapon(player.readyweapon);
		if (!weap || weap.wasThrown)
		{
			curWeaponID = AW_NoWeapon;
			A_ChangeModel("", MI_Weapon, flags: CMDL_HIDEMODEL);
			return;
		}

		int newmodel = curWeaponID;
		if (weap)
		{
			switch (weap.GetClassName()) {
			case 'ToM_Knife':
				newmodel = AW_Knife;
				break;
			case 'ToM_HobbyHorse':
				newmodel = AW_Horse;
				break;
			case 'ToM_Cards':
				newmodel = AW_Cards;
				break;
			case 'ToM_Jacks':
				newmodel = AW_Jacks;
				break;
			case 'ToM_PepperGrinder':
				newmodel = AW_PGrinder;
				break;
			case 'ToM_Teapot':
				newmodel = AW_Teapot;
				break;
			case 'ToM_IceWand':
				newmodel = AW_IceWand;
				break;
			case 'ToM_Eyestaff':
				newmodel = AW_Eyestaff;
				break;
			case 'ToM_Blunderbuss':
				newmodel = AW_Blunderbuss;
				break;
			}
		}

		if (newmodel != curWeaponID)
		{
			curWeaponID = newmodel;
			A_ChangeModel("", MI_Weapon, "models/alice/weapons", modelnames[newmodel]);
		}
	}

	override void Tick()
	{
		Super.Tick();
		if (!player || !player.mo || player.mo != self) return;

		if (coyoteTime)
		{
			coyoteTime--;
		}

		if (!hudface)
		{
			hudface = ToM_HUDFaceController.Create(self);
		}

		// Make sure these are always there:
		if (!FindInventory('ToM_InvReplacementControl'))
		{
			GiveInventory('ToM_InvReplacementControl', 1);
		}
		if (!FindInventory('ToM_KickWeapon'))
		{
			GiveInventory('ToM_KickWeapon', 1);
		}

		// Prevent Mad Vision shader from being active
		// if you don't have it (e.g. after loading
		// a save):
		if (!FindInventory('ToM_MadVisionEffect') && player == players[consoleplayer])
		{
			PPShader.SetEnabled("Alice_ScreenWarp", false);
		}

		// Update collision during and after Hobby Horse's
		// alt jump attack:
		let weap = player.readyweapon;
		let psp = player.FindPSprite(PSP_WEAPON);
		doingPlungingAttack = weap && psp && weap is 'ToM_HobbyHorse' && InStateSequence(psp.curstate, weap.FindState("AltFireDo"));
		if (!doingPlungingAttack)
		{
			for (int i = collideFilter.Size() - 1; i >= 0; i--)
			{
				let act = collideFilter[i];
				if (!act || !act.bSolid)
				{
					collideFilter.Delete(i);
					continue;
				}
				Vector2 pdiff = level.Vec2Diff(pos.xy, act.pos.xy);
				if (abs(pdiff.x) > radius + act.radius || abs(pdiff.y) > radius + act.radius)
				{
					collideFilter.Delete(i);
				}
			}
		}

		// 3rd-person camera:
		if (!specialCamera)
		{
			specialCamera = ToM_PlayerCamera.Create(self);
		}
		else
		{
			CVar tppMode, tppDist, tppVertOfs, tppHorOfs, tppSwap;
			tppMode = CVar.GetCVar('tom_tppCamMode', player);
			// custom 3rd person camera disabled:
			if (tppMode && tppMode.GetInt() <= 0)
			{
				if (player.camera == specialCamera)
				{
					specialCamera.Update(false);
				}
				return;
			}
			// custom 3rd-person camera enabled:
			tppDist = CVar.GetCVar('tom_tppCamDist', player);
			tppVertOfs = CVar.GetCVar('tom_tppCamVertOfs', player);
			tppHorOfs = CVar.GetCVar('tom_tppCamHorOfs', player);
			tppSwap = CVar.GetCVar('tom_tppSwapShoulder', player);
			if (tppDist && tppVertOfs && tppHorOfs && tppSwap)
			{
				if (player.cheats & CF_CHASECAM)
				{
					// 3rd-person crosshair spot:
					if (!crosshairSpot)
					{
						crosshairSpot = ToM_CrosshairSpot.Create(self);
					}
					Vector3 camOfs;
					switch (tppMode.GetInt())
					{
						case 1:
							camOfs = (86, 0, 24);
							break;
						case 2:
							camOfs = (70, -28, 12);
							break;
						case 3:
							camOfs.x = Clamp(abs(tppDist.GetFloat()), 32, 256);
							camOfs.y = Clamp(tppHorOfs.GetFloat(), -128, 128);
							camOfs.z = Clamp(abs(tppVertOfs.GetFloat()), 0, 84);
							break;
					}
					camOfs.x *= -1;
					if (tppSwap.GetBool())
					{
						camOfs.y *= -1;
					}
					// Only apply it if player's camera is set to player pawn (in order to not mess with
					// camera-related scripts like ACS), OR if camera offsets got updated:
					if (player.camera == player.mo || (player.camera == specialCamera && camOfs != specialCamera.cameraOfs))
					{
						specialCamera.Update(true, camOfs, crosshairSpot);
					}
				}
				else if (player.camera == specialCamera)
				{
					specialCamera.Update(false);
				}
			}
		}
	}

	// Safety for cases when you finish the level while frozen
	// with some effect (like mid-firing Bluderbuss)
	override void Travelled()
	{
		player.cheats &= ~(CF_FROZEN | CF_TOTALLYFROZEN);
	}

	override int DamageMobj (Actor inflictor, Actor source, int damage, Name mod, int flags, double angle)
	{
		int dmg = super.DamageMobj(inflictor, source, damage, mod, flags, angle);
		if (dmg > 0)
		{
			A_Pain();
			if (InStateSequence(curstate, spawnstate))
			{
				SetState(s_pain);
			}
			double dmgAngle = 0;
			if (flags & DMG_USEANGLE)
			{
				dmgAngle = angle;
			}
			else
			{
				Actor who = inflictor ? inflictor : source;
				if (who)
				{
					dmgAngle = self.DeltaAngle(self.angle, self.AngleTo(who));
				}
			}
			hudface.PlayerDamaged(dmg, dmgAngle);
		}
		return dmg;
	}
	
	// Animations are handled manually. Do nothing here
	override void PlayRunning()
	{}
	override void PlayIdle()
	{}
	// Weapon animations are handled from weapons. Do nothing here
	override void PlayAttacking ()
	{}
	override void PlayAttacking2 ()
	{}

	override void PlayerThink()
	{
		super.PlayerThink();

		let player = self.player;
		if (!player || ToM_Utils.IsVoodooDoll(self))
		{
			return;
		}
		
		UpdateWeaponModel();
		// If firing, face the angle (no direction);
		if (InStateSequence(curstate, missilestate))
		{
			prevMoveDir = (0,0);
		}
		else if (vel.xy.Length() > 0 && IsPlayerMoving())
		{
			prevMoveDir = Level.Vec2Diff(pos.xy, Level.Vec2Offset(pos.xy, vel.xy));
		}
		modelDirection = (prevMoveDir == (0,0)) ? 0 : atan2(prevMoveDir.y, prevMoveDir.x) - Normalize180(angle);

		// Make the model face the direction of movement, if the player
		// is in third person or seen from outside:
		if (PlayerNumber() != consoleplayer || (player.cheats & CF_CHASECAM) || player.camera != self)
		{
			spriteRotation = modelDirection;
		}
		else
		{
			spriteRotation = 0;
		}

		if (airJumpTics > 0)
			airJumpTics--;

		if (player.onground || waterlevel > 0)
		{
			ResetAirJump();
			coyoteTime = 0;
		}

		double downlim = -6;
		double downfac = 2.6;
		double uplim = 6;
		double upfac = -1.2;

		int jumptics = player.jumptics;
		if (jumptics != 0)
		{
			if (jumptics >= downlim && jumptics < 0)
				player.viewz += jumptics * downfac;
			
			if (jumptics <= uplim && jumptics > 0)
				player.viewz += jumptics * upfac;
			
			//else if (jumptics > 0)
			//	player.viewz += ToM_Utils.LinearMap(jumptics, downlim, lim, downlim * downfac, 0, true);

			//double vz = player.viewz - pos.z;
		}
	}

	override vector2 BobWeapon(double ticfrac)
	{
		let player = self.player;
		if (!player) return (0, 0);
		
		let weapon = player.readyweapon;
		if (!weapon || weapon.bDONTBOB)
			return (0,0);

		let bob = super.BobWeapon(ticfrac);

		int jumptics = player.jumptics;
		if (player && jumptics != 0)
		{
			int downlim = -4;
			int uplim = 6;
			double downfac = -1.85;
			double upfac = 1.2;
			double prevboby;
			double boby;
			
			if (jumptics >= downlim && jumptics < 0)
			{
				prevboby = (player.jumptics - 1) * downfac;
				boby = player.jumptics * downfac;
			}
			
			if (jumptics <= uplim && jumptics > 0)
			{
				prevboby = (player.jumptics - 1) * upfac;
				boby = player.jumptics * upfac;
			}
			
			bob = (bob.x, boby * (1. - ticfrac) + prevboby * ticfrac);
		}

		double wScaleF = weapon.WeaponScaleY - weapon.default.WeaponScaleY;
		if (wScaleF != 0)
		{
			bob.y += 64. * wScaleF;
			bob.x -= 32 * wScaleF;
		}

		//Console.Printf("WeaponScale: \cd%.3f\c-, \cd%.3f\c-", weapon.WeaponScaleX, weapon.WeaponScaleY);
		
		return bob;
	}

	override void CheckJump()
	{
		let player = self.player;
		if (!(player.cmd.buttons & BT_JUMP))
			return;

		if (pos.z > floorz && !player.onGround && waterlevel == 0 && !bNOGRAVITY)
		{
			CheckAirJump();
		}

		if (player.crouchoffset != 0)
		{
			// Jumping while crouching will force an un-crouch but not jump
			player.crouching = 1;
		}
		else if (waterlevel >= 2)
		{
			Vel.Z = 4 * Speed;
		}
		else if (bNoGravity)
		{
			Vel.Z = 3.;
		}
		else if (level.IsJumpingAllowed() && (player.onground || coyoteTime) && player.jumpTics == 0)
		{
			coyoteTime = 0;

			double jumpvelz = JumpZ * 35 / TICRATE;
			double jumpfac = 0;

			// [BC] If the player has the high jump power, double his jump velocity.
			// (actually, pick the best factors from all active items.)
			for (let p = Inv; p != null; p = p.Inv)
			{
				let pp = PowerHighJump(p);
				if (pp)
				{
					double f = pp.Strength;
					if (f > jumpfac) jumpfac = f;
				}
			}
			if (jumpfac > 0) jumpvelz *= jumpfac;

			Vel.Z += jumpvelz;
			bOnMobj = false;
			player.jumpTics = -1;
			if (!(player.cheats & CF_PREDICTING)) 
			{
				A_StartSound("*jump", CHAN_BODY);
			}
			if (InStateSequence(curstate, spawnstate))
			{
				SetState(s_jump);
			}
		}
	}

	void CheckAirJump()
	{
		//console.printf("Jump button: %s, %s", 
		//	player.cmd.buttons & BT_JUMP ? "pressed" : "not pressed",
		//	player.oldbuttons & BT_JUMP ? "held" : "not held"
		//);

		if (FindInventory('ToM_GrowthPotionEffect'))
		{
			return;
		}

		if (!(player.jumptics < AIRJUMPTICTHRESHOLD && airJumps < MAXAIRJUMPS && player.cmd.buttons & BT_JUMP && !(player.oldbuttons & BT_JUMP)))
		{
			return;
		}

		coyoteTime = 0;

		A_StartSound("alice/jumpair", CHAN_BODY);
		airJumps++;
		airJumpTics = MAXAIRJUMPTICS;
		player.jumpTics = -1;
		bOnMobj = false;

		A_Stop();
		vel.z = jumpz * AIRJUMPFACTOR * 35 / TICRATE * GetGravity();
		let player = self.player;
		UserCmd cmd = player.cmd;
		double fm = cmd.forwardmove;
		double sm = cmd.sidemove;
		[fm, sm] = TweakSpeeds (fm, sm);
		fm *= Speed / 256;
		sm *= Speed / 256;

		double friction, movefactor;
		[friction, movefactor] = GetFriction();
		double forwardmove = fm * movefactor * (35 / TICRATE) * AIRJUMPFACTOR;
		double sidemove = sm * movefactor * (35 / TICRATE) * AIRJUMPFACTOR;

		if (forwardmove)
		{
			ForwardThrust(forwardmove, Angle);
		}
		if (sidemove)
		{
			let a = Angle - 90;
			Thrust(sidemove, a);
		}

		if (InStateSequence(curstate, spawnstate) || InStateSequence(curstate, s_jump))
		{
			SetState(s_airjump);
		}

		//console.printf("doing jump %d", airJumps);

		FSpawnParticleParams leaf;
		leaf.flags = SPF_REPLACE|SPF_NOTIMEFREEZE|SPF_ROLL|SPF_FULLBRIGHT;
		leaf.fadestep = -1;
		leaf.color1 = "";
		leaf.style = STYLE_Add;
		for (int i = 40; i > 0; i--)
		{
			leaf.startalpha = frandom[sfx](0.35, 1);
			double ang = frandom[sfx](0, 360);
			leaf.pos.xy = Vec2Angle(radius * 2, ang);
			leaf.pos.z = pos.z;
			leaf.texture = TexMan.CheckForTexture(leaftex[random[sfx](0, leaftex.Size() - 1)]);
			leaf.lifetime = random[sfx](20, 40);
			leaf.size = frandom[sfx](16, 32);
			leaf.sizestep = leaf.size / -leaf.lifetime;
			double v = frandom[sfx](2, 5);
			leaf.vel.xy = (v * cos(ang), v * sin(ang));
			leaf.vel.z = frandom[sfx](-2, 2);
			leaf.accel = leaf.vel / leaf.lifetime * -0.6;
			leaf.startroll = frandom[sfx](0, 360);
			leaf.rollvel = frandom[sfx](-15, 15);
			Level.SpawnParticle(leaf);
		}

		FSpawnParticleParams smoke;
		smoke.flags = SPF_REPLACE|SPF_NOTIMEFREEZE|SPF_ROLL;
		smoke.fadestep = -1;
		smoke.color1 = "";
		smoke.style = Style_Add;
		for (int ang = 0; ang < 360; ang += 15)
		{
			smoke.startalpha = frandom[sfx](0.4, 0.7);
			smoke.pos.xy = Vec2Angle(radius * 2, ang);
			smoke.pos.z = pos.z;
			smoke.texture = TexMan.CheckForTexture(ToM_BaseActor.GetRandomWhiteSmoke());
			smoke.lifetime = 26;
			smoke.size = frandom[sfx](30, 40);
			smoke.sizestep = 3;
			double v = 1;
			smoke.vel.xy = (v * cos(ang), v * sin(ang));
			smoke.vel.z = 0;
			smoke.accel = smoke.vel / -smoke.lifetime;
			smoke.startroll = frandom[sfx](0, 360);
			smoke.rollvel = frandom[sfx](-5, 5);
			Level.SpawnParticle(smoke);
		}
	}

	override void FallAndSink(double grav, double oldfloorz)
	{
		if (coyoteTime)
		{
			return;
		}

		// [AA] No falling in water if the player is
		// moving:
		if (waterlevel > 1 && vel.x != 0 && vel.y != 0)
		{
			return;
		}

		let player = self.player;
		bool done = false;

		if (pos.z > floorz && waterlevel == 0 && !bNOGRAVITY)
		{
			// Handling for crossing ledges:
			if (vel.z == 0 && pos.z == oldfloorz && oldfloorz > floorz)
			{
				if (player.jumptics == 0)
				{
					coyoteTime = MAXCOYOTETIME;
					done = true;
				}
				else
				{
					vel.z -= grav * 1.; //[AA] default was * 2
					done = true;
				}
			}
			// reduced gravity effect when jumping:
			else if (player.jumptics != 0)
			{
				vel.z -= grav * 0.5; //[AA] default was 1.0
				done = true;
			}
		}

		if (!done)
		{
			super.FallAndSink(grav, oldfloorz);
		}

		if (pos.z <= floorz && vel.z <= -8.0 && FindInventory('ToM_GrowthPotionEffect'))
		{
			ToM_GrowthPotionEffect.DoStepDamage(self, damage: 108, distance: 320);
		}
	}

	override bool CanCollideWith(Actor other, bool passive)
	{
		if (collideFilter.Find(other) != collideFilter.Size())
		{
			return false;
		}

		if (doingPlungingAttack && other.bShootable && (other.bIsMonster || other.player))
		{
			collideFilter.Push(other);
			return false;
		}

		return Super.CanCollideWith(other, passive);
	}

	override void MovePlayer ()
	{
		let player = self.player;
		UserCmd cmd = player.cmd;

		// [RH] 180-degree turn overrides all other yaws
		if (player.turnticks)
		{
			player.turnticks--;
			Angle += (180. / TURN180_TICKS);
		}
		else
		{
			Angle += cmd.yaw * (360./65536.);
		}

		player.onground = (pos.z <= floorz) || bOnMobj || bMBFBouncer || (player.cheats & CF_NOCLIP2);
		// [AA] Counter friction if the player is not moving, or
		// moving in the opposite direction of their current momentum.
		// Do this after a jump, or, if in 3rd person, always
		// (because sliding in 3rd person feels awful).
		if (player.onground && !waterlevel && (player.jumptics > 0 || player.cheats & CF_CHASECAM))
		{
			double brakefac = 0.72;
			// If the player isn't pressing movement keys
			// at all, let them brake:
			if (!(cmd.sidemove | cmd.forwardmove))
			{
				vel.xy *= brakefac;
			}
			else 
			{
				// Compare velocity to controls. If the player is pressing
				// movement keys in the opposite direction of their
				// current movement, let them brake:
				Vector2 moveVel = vel.xy;
				moveVel.y *= -1;
				Vector2 moveInput = Actor.RotateVector((cmd.forwardmove, cmd.sidemove).Unit(), -angle) * vel.Length();

				// In 3rd person movement-based braking means your velocity is inverted, letting you
				// instantly change directions.
				// In 1st person movement-based braking simply slows your speed down.
				if (abs(moveVel.x + moveInput.x) < abs(moveVel.x))
				{
					if (player.cheats & CF_CHASECAM)
					{
						vel.x = moveInput.x;
					}
					else
					{
						vel.x *= brakefac;
					}
				}
				if (abs(moveVel.y + moveInput.y) < abs(moveVel.y))
				{
					if (player.cheats & CF_CHASECAM)
					{
						vel.y = -moveInput.y;
					}
					else
					{
						vel.y *= brakefac;
					}
				}
			}
		}

		if (cmd.forwardmove | cmd.sidemove)
		{
			double forwardmove, sidemove;
			double friction, movefactor;
			double bobfactor;
			double fm, sm;
		
			[friction, movefactor] = GetFriction();

			bobfactor = friction < ORIG_FRICTION ? movefactor : ORIG_FRICTION_FACTOR;
			// [AA] Changes to aircontrol application:
			if (!player.onground && !bNoGravity && !waterlevel)
			{
				double aircontrol = level.aircontrol;
				// [AA] increased aircontrol during jumping:
				if (player.jumptics < 0)
				{
					aircontrol *= 50;
				}
				// [AA] Don't apply air control for a few tics after
				// an air jump (see airJumpTics), to let the player
				// reorient themselves when performing it.
				// Also don't apply aircontrol if we're NOT jumping
				// but in coyote time:
				if (airJumpTics <= 0 || (!coyoteTime  && player.jumptics == 0))
				{
					movefactor *= aircontrol;
					bobfactor*= aircontrol;
				}
				//console.printf("jumptics: %d | movefactor: %.2f | aircontrol: %.8f | level.aircontrol: %.8f", player.jumptics, aircontrol, level.aircontrol, movefactor);
			}

			fm = cmd.forwardmove;
			sm = cmd.sidemove;
			[fm, sm] = TweakSpeeds (fm, sm);
			fm *= Speed / 256;
			sm *= Speed / 256;

			// When crouching, speed and bobbing have to be reduced
			if (CanCrouch() && player.crouchfactor != 1)
			{
				fm *= player.crouchfactor;
				sm *= player.crouchfactor;
				bobfactor *= player.crouchfactor;
			}

			forwardmove = fm * movefactor * (35 / TICRATE);
			sidemove = sm * movefactor * (35 / TICRATE);
			
			if (forwardmove)
			{
				Bob(Angle, cmd.forwardmove * bobfactor / 256., true);
				ForwardThrust(forwardmove, Angle);
			}
			if (sidemove)
			{
				let a = Angle - 90;
				Bob(a, cmd.sidemove * bobfactor / 256., false);
				Thrust(sidemove, a);
			}

			if (player.cheats & CF_REVERTPLEASE)
			{
				player.cheats &= ~CF_REVERTPLEASE;
				if (!ToM_Utils.IsVoodooDoll(self))
				{
					player.camera = player.mo;
				}
			}
		}
	}
	
	States {
	See:
	Spawn:
		APLR A 1 UpdateMovementAnimation();
		loop;

	Melee:
	Missile:
		APLR A 30;
		goto Spawn;
	
	Pain:
		APLR A 12 SetAnimation('pain');
		Goto Spawn;
	
	Jump:
		JumpGround:
			APLR A 8 SetAnimation('jump', 30, loopframe: 9, flags: SAF_LOOP);
			APLR A 0
			{
				return ResolveState("JumpLoop");
			}
		JumpAir:
			APLR A 4 
			{
				SetAnimation('jump_air', 20, loopframe: 4, flags: SAF_LOOP);
				return ResolveState("JumpLoop");
			}
		JumpLoop:
			APLR A 1;
			APLR A 0
			{
				if (waterlevel >= 2)
				{
					return ResolveState("Spawn");
				}
				else if (player.onGround)
				{
					return ResolveState("JumpEnd");
				}
				return ResolveState("JumpLoop");
			}
		JumpEnd:
			APLR A 12 
			{
				SetAnimation('jump_end', 30);
			}
			goto Spawn;
		
	Death:
		APLR A -1
		{
			A_PlayerScream();
			A_NoBlocking();
			SetAnimation('death_faint');
		}
		Stop;
	XDeath:
		APLR A -1
		{
			A_PlayerScream();
			A_NoBlocking();
			SetAnimation('death_fall');
		}
		Stop;
	}
}

class ToM_PlayerCamera : Actor
{
	Actor targetpoint;
	ToM_AlicePlayer alice;
	protected bool enabled;
	Vector3 cameraOfs;

	Default
	{
		+NOINTERACTION
		+NOBLOCKMAP
		+CAMFOLLOWSPLAYER
	}
	
	static ToM_PlayerCamera Create(Actor who)
	{
		if (!who) return null;

		let alice = ToM_AlicePlayer(who);
		if (!alice) return null;

		let cam = ToM_PlayerCamera(Actor.Spawn('ToM_PlayerCamera', alice.pos));
		if (cam)
		{
			cam.alice = alice;
		}
		return cam;
	}

	void Update(bool on = true, Vector3 ofs = (0,0,0), Actor targetpoint = null)
	{
		if (!alice) return;

		enabled = on;
		if (enabled)
		{
			alice.player.camera = self;
			if (ofs != (0,0,0))
			{
				cameraOfs = ofs;
			}
			alice.viewbob = 0;
			self.targetPoint = targetpoint;
		}
		else
		{
			alice.player.camera = alice.player.mo;
			alice.viewbob = alice.default.viewbob;
		}
	}

	override void Tick()
	{
		if (!enabled)
		{
			return;
		}

		if (!alice)
		{
			Destroy();
			return;
		}

		SetViewPos(cameraOfs);
		SetOrigin(alice.pos, true);
	}
}

class ToM_CrosshairSpot : ToM_BaseDebris
{
	ToM_AlicePlayer alice;
	protected Vector3 crosshairTargetPos;
	protected bool isManualPos;
	protected double crosshairRadius;
	protected double crosshairRotAngle;
	protected Actor crosshairAimActor;
	private Vector3 prevParticlePos;
	ECRosshairModes crosshairMode;

	enum ECRosshairModes
	{
		CMODE_Normal, //regular spot
		CMODE_AoE, //circular around a specific point
		CMODE_Seeker, //circular around a target
		CMODE_Hidden,
	}

	Default
	{
		+NOINTERACTION
		+NOBLOCKMAP
		+BRIGHT
		+FORCEXYBILLBOARD
		+INVISIBLEINMIRRORS
		scale 0.24;
		+NOTIMEFREEZE
		radius 4;
		height 4;
		renderstyle "Add";
		+DONTBLAST
		+SYNCHRONIZED
		FloatBobphase 0;
	}

	static ToM_CrosshairSpot Create(Actor who)
	{
		if (!who) return null;

		let alice = ToM_AlicePlayer(who);
		if (!alice) return null;

		let spot = ToM_CrosshairSpot(Spawn("ToM_CrosshairSpot", who.pos));
		if (spot)
		{
			spot.alice = alice;
		}
		return spot;
	}

	void Update(int newMode = -1, double newRadius = -1, Actor newTarget = null, Vector3 newPos = (0,0,0))
	{
		if (newMode > -1)
			crosshairMode = newMode;
		if (newRadius > -1)
			crosshairRadius = newRadius;
		if (newTarget)
			crosshairAimActor = newtarget;
		if (newPos != (0,0,0))
		{
			crosshairTargetPos = newPos;
			isManualPos = true;
		}
	}

	override void Tick()
	{
		if (!alice)
		{
			Destroy();
			return;
		}

		if (crosshairMode == CMODE_Hidden)
		{
			renderRequired = -1;
			crosshairMode = CMODE_Normal;
			return;
		}

		if (!(alice.player.cheats & CF_CHASECAM))
		{
			renderRequired = -1;
			return;
		}

		if (alice.player == players[consoleplayer])
		{
			renderRequired = 1;
		}
		else
		{
			renderRequired = -1;
		}

		Vector3 newpos;
		// pos is being set by weapon:
		if (isManualPos)
		{
			newpos = crosshairTargetPos;
			// reset this (to utilize crosshairTargetPos this flag
			// has to be set every tic manually - see UpdateCrosshairSpot()
			// in ToM_BaseWeapon):
			isManualPos = false;
		}
		else
		{
			FLineTracedata tr;
			double atkheight = ToM_Utils.GetPlayerAtkHeight(alice);
			alice.LineTrace(alice.angle, PLAYERMISSILERANGE, alice.pitch, TRF_SOLIDACTORS, atkheight, data: tr);
			newpos = tr.HitLocation;
			if (tr.HitType != TRACE_HitNone)
			{
				let norm = ToM_Utils.GetNormalFromTrace(tr);
				newpos = level.Vec3Offset(tr.HitLocation, norm * 12);
			}
		}

		SetOrigin(newpos, true);
		if (pos.z < floorz)
		{
			SetZ(floorz);
		}

		// The rest is visuals - skip if not rendered:
		if (renderRequired < 0)
		{
			return;
		}

		// scale size inversely relative to distance from player:
		scale.x = scale.y = ToM_Utils.LinearMap(Distance3D(alice), 320, PLAYERMISSILERANGE, default.scale.x, default.scale.x * 16.0, true);

		TextureID tex = curstate.GetSpriteTexture(0);
		FSpawnParticleParams p;
		p.color1 = "";
		p.texture = tex;
		p.flags = SPF_FULLBRIGHT|SPF_NOTIMEFREEZE;
		p.startalpha = 1;
		p.size = TexMan.GetSize(tex) * scale.x;
		p.style = STYLE_Add;

		switch (crosshairMode)
		{
			default:
				alpha = 1;
				p.fadestep = -1;
				p.pos = prev;
				p.lifetime = 10;
				Level.SpawnParticle(p);
				break;
			case CMODE_AoE:
			case CMODE_Seeker:
				alpha = 0;
				p.fadestep = 0;
				p.lifetime = 2;
				double angSec;
				double angStep = 4;
				double rad;
				Vector3 targetpos;
				if (crosshairMode == CMODE_Seeker && crosshairAimActor)
				{
					targetpos = crosshairAimActor.Vec3Offset(0, 0, crosshairAimActor.height*0.5);
					crosshairRadius = crosshairAimActor.radius * 1.5;
					angSec = 45;
				}
				else
				{
					targetpos = pos;
					crosshairRadius = crosshairRadius > 0? crosshairRadius : 32;
					angSec = 90;
				}
				if (prevParticlePos == (0,0,0))
				{
					prevParticlePos = targetpos;
				}
				p.size *= ToM_Utils.LinearMap(crosshairRadius, 16, 128, 0.3, 1.0, true);
				// set position to prev, then give vel towards current
				// to force interpolation:
				p.vel = level.Vec3Diff(prevParticlePos, targetpos);
				p.pos.z = prevParticlePos.z;
				for (double i = 0; i < angSec; i += angStep)
				{
					Vector2 ofs = Actor.RotateVector((crosshairRadius, 0), crosshairRotAngle + i);
					p.pos.xy = Level.Vec2Offset(prevParticlePos.xy, ofs);
					Level.SpawnParticle(p);
					p.pos.xy = Level.Vec2Offset(prevParticlePos.xy, -ofs);
					Level.SpawnParticle(p);
					p.startalpha -= 1.0 / (angSec / angStep);
				}
				crosshairRotAngle -= 8;
				prevParticlePos = targetpos;
		}
		// reset everything
		// weapons need to call UpdateCrosshairSpot() every tic
		// in order to override this and apply custom mode:
		crosshairMode = CMODE_Normal;
		crosshairAimActor = Actor(null);
	}
	
	States
	{
	Spawn:
		AMCR X -1;
		stop;
	}
}