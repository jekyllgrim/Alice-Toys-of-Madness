class ToM_AlicePlayer : DoomPlayer
{
	const MAXAIRJUMPTICS = 6;
	const MAXAIRJUMPS = 1;
	const AIRJUMPTICTHRESHOLD = -4;
	const AIRJUMPFACTOR = 0.8;
	const BASEMODELPATH = "models/alice";
	const MAXCOYOTETIME = 10;
	const SHOULDERSWAPTIME = 4;

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
		MI_Character,
		MI_Weapon,
		MI_LeftArm,
		MI_RageParts,
		MI_MockShell,
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
	protected ToM_PlayerShadow aliceShadow;
	
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
	bool isCamShoulderSwapped;
	uint camShoulderSwapTics;
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
		ToM_SetAnimation('basepose', flags:SAF_LOOP|SAF_INSTANT);
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

	void ToM_SetAnimation(Name animName, double framerate = -1, int startFrame = -1, int loopFrame= -1, int endFrame= -1, int interpolateTics = -1, int flags = 0)
	{
		if (aliceShadow && aliceShadow.shadowmode == ToM_PlayerShadow.SMODE_3D)
		{
			aliceShadow.SetAnimation(animName, framerate, startFrame, loopFrame, endFrame, interpolateTics, flags);
		}
		SetAnimation(animName, framerate, startFrame, loopFrame, endFrame, interpolateTics, flags);
	}

	void ToM_SetAnimationFrameRate(double framerate)
	{
		if (aliceShadow && aliceShadow.shadowmode == ToM_PlayerShadow.SMODE_3D)
		{
			aliceShadow.SetAnimationFrameRate(framerate);
		}
		SetAnimationFrameRate(framerate);
	}

	action void ToM_ChangeModel(name modeldef, int modelindex = 0, string modelpath = "", name model = "", int skinindex = 0, string skinpath = "", name skin = "", int flags = 0, int generatorindex = -1, int animationindex = 0, string animationpath = "", name animation = "")
	{
		if (invoker.aliceShadow && invoker.aliceShadow.shadowmode == ToM_PlayerShadow.SMODE_3D)
		{
			invoker.aliceShadow.A_ChangeModel(modeldef, modelindex, modelpath, model, skinindex, skinpath, skin, flags, generatorindex, animationindex, animationpath, animation);
		}
		A_ChangeModel(modeldef, modelindex, modelpath, model, skinindex, skinpath, skin, flags, generatorindex, animationindex, animationpath, animation);
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
			ToM_SetAnimation('swim_loop', interpolateTics: 5, flags:SAF_LOOP|SAF_NOOVERRIDE);
			ToM_SetAnimationFrameRate(ToM_Utils.LinearMap(hvel, 3, 18, minFr, maxFr));
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
					ToM_SetAnimation('jump', startframe: 9, loopframe: 9, interpolateTics: 10, flags:SAF_LOOP|SAF_NOOVERRIDE);
					SetState(s_jumpLoop);
				}
			}
			// otherwise slow down current walk/run animation without switching to jumping:
			else
			{
				ToM_SetAnimationFrameRate(3);
			}
		}
		// moving or standing still:
		else
		{
			fallingTics = 0;
			// standing still
			if (hvel <= 0.1)
			{
				ToM_SetAnimation('basepose', interpolateTics: 10, flags:SAF_LOOP|SAF_NOOVERRIDE);
			}
			// walking
			else if (hvel <= 7.5)
			{
				ToM_SetAnimation(twohanded? 'walk_bigweapon' : 'walk_smallweapon', interpolateTics: 5, flags:SAF_LOOP|SAF_NOOVERRIDE|SAF_INSTANT);
				ToM_SetAnimationFrameRate(ToM_Utils.LinearMap(hvel, 2, 7.5, minFr, maxFr));
			}
			// running
			else
			{
				ToM_SetAnimation(twohanded? 'run_bigweapon' : 'run_smallweapon', flags:SAF_LOOP|SAF_NOOVERRIDE|SAF_INSTANT);
				ToM_SetAnimationFrameRate(ToM_Utils.LinearMap(hvel, 7.5, 20, minFr, maxFr));
			}
			// spawn dust devils:
			if (hvel > 0.1)
			{
				int frec = int(round(ToM_Utils.LinearMap(hvel, 0.1, 18, 12, 4, true)));
				if (GetAge() % frec == 0)
				{
					FSpawnParticleParams p;
					p.startalpha = 1.0;
					p.fadestep = -1;
					p.size = frandom[dust](15, 20);
					p.lifetime = random[dust](18, 25);
					p.texture = TexMan.CheckForTexture(ToM_BaseActor.GetRandomWhiteSmoke());
					p.color1 = 0xeec0a1;
					p.pos = Vec3Offset(frandom[dust](-10, 10), frandom[dust](-10, 10), p.size*0.5);
					double v = 0.2;
					p.vel = (frandom(-v, v), frandom(-v, v), frandom(0, v));
					p.flags = SPF_ROLL;
					p.startroll = frandom[dust](0, 360);
					p.rollvel = frandom[dust](-3, 3);
					p.flags = SPF_NOTIMEFREEZE;
					Level.SpawnParticle(p);
				}
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
			ToM_ChangeModel("", MI_Weapon, flags: CMDL_HIDEMODEL);
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
			ToM_ChangeModel("", MI_Weapon, "models/alice/weapons", modelnames[newmodel]);
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

		if (!aliceShadow)
		{
			aliceShadow = ToM_PlayerShadow(Spawn('ToM_PlayerShadow', pos));
			aliceShadow.master = self;
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
		doingPlungingAttack = weap && psp && weap is 'ToM_HobbyHorse' && InStateSequence(psp.curstate, weap.FindState("AltFire"));
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

		// 3rd-person crosshair spot:
		if (!crosshairSpot)
		{
			crosshairSpot = ToM_CrosshairSpot.Create(self);
		}
		else if (player.readyweapon)
		{
			player.readyweapon.crosshair = crosshairSpot.renderRequired >= 0? -1 : 0;
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
			if (tppDist && tppVertOfs && tppHorOfs)
			{
				if (player.cheats & CF_CHASECAM)
				{
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
					if (camShoulderSwapTics)
					{
						camOfs.y = ToM_Utils.LinearMap(camShoulderSwapTics, 
							SHOULDERSWAPTIME, 
							0, 
							isCamShoulderSwapped? camOfs.y : -camOfs.y,
							isCamShoulderSwapped? -camOfs.y : camOfs.y,
							true);
						camShoulderSwapTics--;
					}
					else if (isCamShoulderSwapped)
					{
						camOfs.y = -camOfs.y;
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
		if (dmg > 0 && health > 0)
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
			if (hudface)
			{
				hudface.PlayerDamaged(dmg, dmgAngle);
			}
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
		// If firing, face the angle (no direction):
		if (InStateSequence(curstate, missilestate))
		{
			prevMoveDir = (0,0);
		}
		// Otherwise calculate direction to turn the model in
		// from movement direction:
		else if (vel.xy.Length() > 0 && IsPlayerMoving())
		{
			prevMoveDir = Level.Vec2Diff(pos.xy, Level.Vec2Offset(pos.xy, vel.xy));
		}
		modelDirection = (prevMoveDir == (0,0)) ? 0 : atan2(prevMoveDir.y, prevMoveDir.x) - Normalize180(angle);

		// Make the model face the direction of movement, if the player
		// is in third person or seen from outside:
		if (PlayerNumber() != consoleplayer || ((player.cheats & CF_CHASECAM) && (player.camera == self || player.camera == specialCamera)))
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

	override void CrouchMove(int direction)
	{
		Super.CrouchMove(direction);
		if (direction < 0)
		{
			scale *= 0.9;
		}
		else
		{
			scale /= 0.9;
		}
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
			if (coyoteTime)
			{
				vel.z = max(vel.z, 0);
				coyoteTime = 0;
			}

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

			vel.z += jumpvelz;
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
				// Coyote time:
				if (player.jumptics == 0 && coyoteTime == 0 && level.IsJumpingAllowed())
				{
					coyoteTime = MAXCOYOTETIME;
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
		APLR A 12 ToM_SetAnimation('pain');
		Goto Spawn;
	
	Jump:
		JumpGround:
			APLR A 8 ToM_SetAnimation('jump', 30, loopframe: 9, flags: SAF_LOOP|SAF_INSTANT);
			APLR A 0
			{
				return ResolveState("JumpLoop");
			}
		JumpAir:
			APLR A 4 
			{
				ToM_SetAnimation('jump_air', 20, loopframe: 4, flags: SAF_LOOP);
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
				ToM_SetAnimation('jump_end', 30);
			}
			goto Spawn;
		
	Death:
		APLR A -1
		{
			A_PlayerScream();
			A_NoBlocking();
			ToM_SetAnimation('death_faint');
		}
		Stop;
	XDeath:
		APLR A -1
		{
			A_PlayerScream();
			A_NoBlocking();
			ToM_SetAnimation('death_fall');
		}
		Stop;
	}
}

// Dummy class def just so that I can define a MODELDEF
// with this name:
class ToM_PlayerShadowBlob : Actor abstract
{
	States {
	Spawn:
		APLR A -1;
		stop;
	}
}

class ToM_PlayerShadow : ToM_BaseActor
{
	enum EShadowModes
	{
		SMODE_Hidden,
		SMODE_Blob,
		SMODE_3D,
	}

	int shadowMode;

	Default
	{
		+NOINTERACTION
		+NOBLOCKMAP
		+DECOUPLEDANIMATIONS
		+SYNCHRONIZED
		+DONTBLAST
		FloatBobPhase 0;
		Height 1;
		Radius 1;
		Renderstyle 'Stencil';
		StencilColor '000000';
		Alpha 1;
	}

	override void Tick()
	{
		if (!master)
		{
			Destroy();
			return;
		}
		UpdateMode();

		SetOrigin((pos.xy, min(master.pos.z, master.floorz)), false);
		SetOrigin((master.pos.xy, pos.z), true);
		A_SetAngle(master.angle, SPF_INTERPOLATE);
		spriteRotation = master.spriteRotation;
		double scf = ToM_Utils.LinearMap(abs(pos.z - master.pos.z), 0, 320, 1.2, 3.5, true);
		scale = master.scale * scf;
	}

	void UpdateMode()
	{
		// this is not synced, so check for consoleplayer!
		int mode = CVar.GetCVar('tom_playershadow', players[consoleplayer]).GetInt();
		if (shadowMode == mode) return;
	
		switch (mode)
		{
			default:
				renderRequired = -1;
				break;
			case 1:
				renderRequired = 0;
				bDECOUPLEDANIMATIONS = false;
				for (int i = 1; i <= 10; i++)
				{
					A_ChangeModel("", modelindex: i, flags: CMDL_HIDEMODEL);
				}
				alpha = 0.8;
				A_ChangeModel("ToM_PlayerShadowBlob");
				break;
			case 2:
				renderRequired = 0;
				bDECOUPLEDANIMATIONS = true;
				alpha = default.alpha;
				A_ChangeModel("");
				break;
		}
		shadowMode = mode;
	}

	States {
	Spawn:
		APLR A -1;
		stop;
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

class ToM_CrosshairSpot : ToM_BaseActor
{
	ToM_AlicePlayer alice;
	protected Vector3 crosshairTargetPos;
	protected bool isManualPos;
	protected double crosshairRadius;
	protected double crosshairRotAngle;
	protected Actor crosshairAimActor;
	protected TextureID crosshairTexture;
	protected Vector3 crosshairDir;
	private Vector3 prevParticlePos;
	private TextureID defGraphic;
	ECRosshairModes crosshairMode;

	enum ECRosshairModes
	{
		CMODE_Normal, //regular spot
		CMODE_Circular,
		CMODE_AoE, //circular around a specific point
		CMODE_Seeker, //circular around a target
		CMODE_Hidden,
	}
	
	enum ECrosshairSetting
	{
		CS_None,
		CS_TPP,
		CS_Always,
	}

	Default
	{
		+NOINTERACTION
		+NOBLOCKMAP
		+BRIGHT
		+FORCEXYBILLBOARD
		+INVISIBLEINMIRRORS
		Scale 0.24;
		Renderstyle 'Add';
		+NOTIMEFREEZE
		radius 4;
		height 4;
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

	override void BeginPlay()
	{
		Super.BeginPlay();
		crosshairDir = (0,0,1);
		scale.y = scale.x / level.pixelstretch;
	}

	void Update(int newMode = -1, double newRadius = -1, Actor newTarget = null, Vector3 newPos = (0,0,0), Vector3 newDir = (0, 0, 1), String specialsprite = "")
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
		if (specialsprite != "")
		{
			TextureID tex = TexMan.CheckForTexture(specialsprite);
			if (tex.isValid())
			{
				crosshairTexture = tex;
			}
		}
		crosshairDir = newDir;

		if (tom_debugmessages >= 3 && 
			(newMode  > -1 || 
			newRadius > -1 ||
			newTarget ||
			newPos != (0,0,0) ||
			specialSprite != ""))
		{
			String dstr = "TPP crosshair updated:";
			if (newMode > -1)
				dstr.AppendFormat("\nMode: \cd%d\c-", crosshairMode);
			if (newRadius > -1)
				dstr.AppendFormat("\nRadius: \cd%.1f\c-", crosshairRadius);
			if (newTarget)
				dstr.AppendFormat("\nTarget: \cd%p\c-", crosshairAimActor);
			if (newPos != (0,0,0))
				dstr.AppendFormat("\nPos: \cd%.1f, %.1f, %.1f\c-", crosshairTargetPos.x, crosshairTargetPos.y, crosshairTargetPos.z);
			if (specialsprite != "")
				dstr.AppendFormat("\nSpecial sprite: \cd%s\c-", TexMan.GetName(crosshairTexture));
			ToM_DebugMessage.Print(dstr, 3);
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

		if (alice.player != players[consoleplayer])
		{
			renderRequired = -1;
		}
		else
		{
			CVar crossMode = CVar.GetCvar('tom_tppCrosshair', alice.player);
			switch (crossMode.GetInt())
			{
				default:
					renderRequired = -1;
					break;
				case CS_TPP:
					renderRequired = (alice.player.cheats & CF_CHASECAM)? 0 : -1;
					break;
				case CS_ALWAYS:
					renderRequired = 0;
					break;
			}
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
				newpos = level.Vec3Offset(tr.HitLocation, norm * 4);
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

		if (!defGraphic.IsValid())
		{
			defGraphic = spawnstate.GetSpriteTexture(0);
		}

		if (crosshairTexture.IsValid())
		{
			picnum = crosshairTexture;
			crosshairTexture.SetInvalid();
		}
		else
		{
			picnum = defGraphic;
		}

		alice.player.cheats |= CF_INTERPVIEW;

		// scale size inversely relative to distance from player:
		scale.x = scale.y = ToM_Utils.LinearMap(Distance3D(alice), 320, PLAYERMISSILERANGE, default.scale.x, default.scale.x * 16.0, true);

		TextureID tex = picnum; //curstate.GetSpriteTexture(0);
		FSpawnParticleParams p;
		p.color1 = "";
		p.texture = tex;
		p.flags = SPF_FULLBRIGHT|SPF_NOTIMEFREEZE;
		p.startalpha = 1;
		p.size = TexMan.GetSize(tex) * scale.x;
		p.style = STYLE_Add;

		if (crosshairMode == CMODE_Normal)
		{
			alpha = 1;
			p.fadestep = -1;
			p.pos = prev;
			p.lifetime = 10;
			Level.SpawnParticle(p);
		}
		else
		{
			alpha = 0;
			p.fadestep = 0;
			p.lifetime = 2;
			Vector3 targetpos;
			double angSec;
			double angStep = 4;
			double rad;

			if (crosshairMode == CMODE_AoE || !crosshairAimActor)
			{
				targetpos = pos;
				crosshairRadius = max(crosshairRadius, 32);
				angSec = 90;
			}
			else
			{
				targetpos = crosshairAimActor.Vec3Offset(0, 0, crosshairAimActor.height*0.5);
				crosshairRadius = crosshairAimActor.radius * 1.5;
				angSec = 45;
			}

			if (prevParticlePos == (0,0,0))
			{
				prevParticlePos = targetpos;
			}

			p.size *= ToM_Utils.LinearMap(crosshairRadius, 16, 128, 0.3, 1.0, true);
			// set velocity from prev to current position
			// to force faux interpolation:
			p.vel = level.Vec3Diff(prevParticlePos, targetpos);
			p.pos.z = prevParticlePos.z;
			Vector3 forward = (1,0,0);
			Vector3 up = (0,0,1);
			Quat base;
			if (abs(crosshairDir.z) ~== 1)
			{
				base = Quat.AxisAngle(up, 0);
			}
			else
			{
				crosshairDir = crosshairDir cross (crosshairDir.y,-crosshairDir.x,0).Unit();
				base = Quat.FromAngles(atan2(crosshairDir.y,crosshairDir.x), -asin(crosshairDir.z), 0);
			}
			for (double i = 0; i < angSec; i += angStep)
			{
				Quat rot = Quat.AxisAngle(up, crosshairRotAngle + i);
				p.pos = level.Vec3Offset(prevParticlePos, (base*rot*forward) * crosshairRadius);
				level.SpawnParticle(p);
				rot = Quat.AxisAngle(up, crosshairRotAngle + i + 180);
				p.pos = level.Vec3Offset(prevParticlePos, (base*rot*forward) * crosshairRadius);
				level.SpawnParticle(p);
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
		crosshairDir = (0,0,1);
	}
	
	States
	{
	Spawn:
		AMCR X -1;
		stop;
	}
}

class ToM_PlayerDollBackground : ToM_BaseActor
{
	Default
	{
		+NOINTERACTION
		+NOBLOCKMAP
		+BRIGHT
		+SYNCHRONIZED
		+DONTBLAST
		FloatBobPhase 0;
	}

	States {
	Spawn:
		M000 A -1;
		stop;
	}
}
	

class ToM_PlayerDoll : ToM_BaseActor
{
	private double dollSpawnangle;
	bool dollSpawnValid;

	Default
	{
		+NOINTERACTION
		+NOBLOCKMAP
		+BRIGHT
		+SYNCHRONIZED
		+DONTBLAST
		FloatBobPhase 0;
	}

	static ToM_PlayerDoll SpawnDoll(Vector3 pos, double angle)
	{
		let doll = ToM_PlayerDoll(Actor.Spawn('ToM_PlayerDoll', pos));
		if (doll)
		{
			doll.dollSpawnValid = true;
			doll.SetZ(doll.cursector.NextLowestFloorAt(doll.pos.x, doll.pos.y, doll.pos.z));
			doll.angle = angle;
			doll.dollSpawnangle = doll.angle;
			doll.spawnPoint = doll.pos;

			Vector2 cameraOfs = Actor.RotateVector((50, 0), doll.angle);
			let cam = SecurityCamera(Actor.Spawn('SecurityCamera', level.Vec3Offset(doll.pos, (cameraOfs, 40))));
			cam.angle = doll.angle + 180 + 28;
			cam.pitch = 15;
			TexMan.SetCameraToTexture(cam, "AlicePlayer.menuMirror", 80);

			Vector2 bgOfs = Actor.RotateVector((128, 0), doll.angle + 180);
			let dollbg = Actor.Spawn('ToM_PlayerDollBackground', level.Vec3Offset(doll.pos, (bgOfs, -32)));
			dollbg.angle += 28;
			dollbg.A_ChangeModel("", skin: "AlicePlayer.menuMirrorReflection");
		}
		return doll;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		if (!dollSpawnValid)
		{
			Destroy();
			return;
		}

		String pcTex = ToM_PCANTEX_BODY..consoleplayer;
		A_ChangeModel("", skinindex: ToM_AlicePlayer.SI_TorsoLegs, skin: pcTex, flags: CMDL_USESURFACESKIN);

		pcTex = ToM_PCANTEX_BODY2..consoleplayer;
		A_ChangeModel("", skinindex: ToM_AlicePlayer.SI_Skirt, skin: pcTex, flags: CMDL_USESURFACESKIN);

		pcTex = ToM_PCANTEX_ARM..consoleplayer;
		A_ChangeModel("", skinindex: ToM_AlicePlayer.SI_Arms, skin: pcTex, flags: CMDL_USESURFACESKIN);
	}

	override void Tick()
	{
		if (tics != -1) 
		{
			if (tics > 0)
			{
				tics--;
			}
			while (!tics) 
			{
				SetState (CurState.NextState);
			}
		}
	}

	States {
	Spawn:
		#### # 0
		{
			SetZ(spawnPoint.z);
			angle = dollSpawnAngle;
			pitch = 0;
		}
		Idle1:
			M100 ABCDEFGHIJKLMNOPQRSTUVWXYZ 2;
			M101 ABC 2;
			M100 ABCDEFGHIJKLMNOPQRSTUVWXYZ 2;
			M101 ABC 2;
			#### # 0 A_Jump(120, "Idle1_dirtkick", "Idle1_heelkick", "Idle1_nails", "Idle1_to2");
			#### # 0 { return FindState("Idle1"); }
		Idle1_dirtkick:
			M102 ABCDEFGHIJKLMNOPQRSTUVWXYZ 2;
			M103 ABCDEFGHIJKLMNOPQRSTUVWXYZ 2;
			M104 ABCDEFGHIJ 2;
			#### # 0 { return FindState("Idle1"); }
		Idle1_heelkick:
			M105 ABCDEFGHIJKLMNOPQRSTUVWXYZ 2;
			M106 ABCDEFGHIJKLMNOPQRSTUVWXYZ 2;
			M107 ABCDEFGHIJKLMN 2;
			#### # 0 { return FindState("Idle1"); }
		Idle1_nails:
			M108 ABCDEFGHIJKLMNOPQRSTUVWXYZ 2;
			M109 ABCDEFGHIJKLMNOPQRSTUVWXYZ 2;
			M110 ABCDEFGHIJKLMNOPQRSTUVWXY 2;
			#### # 0 { return FindState("Idle1"); }
		Idle1_to2:
			M111 ABCDEFGHIJKLMNOPQRSTU 2;
		Idle2:
			M112 ABCDEFGHIJKLMNOPQRSTUVWXYZ 2;
			M113 ABC 2;
			M112 ABCDEFGHIJKLMNOPQRSTUVWXYZ 2;
			M113 ABC 2;
			#### # 0 A_Jump(120, "Idle2_armsbehind", "Idle_foldarms", "Idle2_to3");
			#### # 0 { return FindState("Idle2"); }
		Idle2_armsbehind:
			M114 ABCDEFGHIJKLM 2;
		Idle2_armsbehind_stand:
			M117 ABCDEFGHIJKLMNOPQRSTUVWXYZ 2;
			M118 ABC 2;
			M117 ABCDEFGHIJKLMNOPQRSTUVWXYZ 2;
			M118 ABC 2;
			#### # 0 A_Jump(120, "Idle2_armsbehind_rocktoes", "Idle2_armsbehind_back");
			#### # 0 { return FindState("Idle2_armsbehind_stand"); }
		Idle2_armsbehind_back:
			M114 MLKJIHGFEDCBA 2;
			#### # 0 { return FindState("Idle2"); }
		Idle2_armsbehind_rocktoes:
			M115 ABCDEFGHIJKLMNOPQRSTUVWXYZ 2;
			M116 ABCDEFGHIJKLMNOPQRSTUVWXY 2;
			#### # 0 { return FindState("Idle2_armsbehind_stand"); }
		Idle2_foldarms:
			M119 ABCDEFGHIJKLMNOPQ 2;
		Idle2_foldarms_stand:
			M120 ABCDEFGHIJKLMNOPQRSTUVWXYZ 2;
			M121 ABCDEFG 2;
			M120 ABCDEFGHIJKLMNOPQRSTUVWXYZ 2;
			M121 ABCDEFG 2;
			#### # 0 A_Jump(120, "Idle2_foldarms_back");
			#### # 0 { return FindState("Idle2_armsbehind_stand"); }
		Idle2_foldarms_back:
			M119 QPONMLKJIHGFEDCBA 2;
			#### # 0 { return FindState("Idle2"); }
		Idle2_to3:
			M122 ABCDEFGHIJKLMNOPQRSTU 2;
		Idle3:
			M123 ABCDEFGHIJKLMNOPQRSTUVWXYZ 2;
			M124 ABC 2;
			M123 ABCDEFGHIJKLMNOPQRSTUVWXYZ 2;
			M124 ABC 2;
			#### # 0 A_Jump(120, "Idle3_to1");
			#### # 0 { return FindState("Idle3"); }
		Idle3_to1:
			M125 ABCDEFGHIJKLMNOPQRST 2;
			goto Idle1;

	Anim_basepose:
		M000 AB 35;
		loop;

	Anim_attack:
		#### # 0
		{
			SetZ(spawnPoint.z);
			angle = dollSpawnAngle;
			pitch = 0;
		}
		M002 ABCDEFGHIJKLMNOPQRST 2;
		#### # 20;
		loop;
	Anim_altattack:
		#### # 0
		{
			SetZ(spawnPoint.z);
			angle = dollSpawnAngle;
			pitch = 0;
		}
		M003 ABCDEFGHIJKLMNOPQRSTUV 2;
		#### # 20;
		loop;
	Anim_moveleft:
		#### # 0 A_SetAngle(dollSpawnAngle - 90);
		goto Anim_move;
	Anim_moveright:
		#### # 0 A_SetAngle(dollSpawnAngle + 90);
		goto Anim_move;
	Anim_back:
		#### # 0 A_SetAngle(dollSpawnAngle + 180);
		goto Anim_move;
	Anim_forward:
		#### # 0 A_SetAngle(dollSpawnAngle);
		goto Anim_move;
	Anim_move:
		#### # 0
		{
			pitch = 0;
			SetZ(spawnPoint.z);
		}
		M004 ABCDEFGHIJKL 2;
		loop;
	Anim_jump:
		#### # 0
		{
			SetZ(spawnPoint.z);
			angle = dollSpawnAngle;
			pitch = 0;
		}
		M005 ABCDEFGHIJKLMN 2;
		M005 KLMN 2;
		M006 ABCDEFGHIJKLM 2;
		#### # 35;
		loop;
	Anim_ThrowJackbomb:
		#### # 0
		{
			SetZ(spawnPoint.z);
			angle = dollSpawnAngle;
			pitch = 0;
		}
		M007 ABCDEFGHIJKLMN 2;
		M007 A 20;
		loop;
	Anim_right:
		#### # 0
		{
			SetZ(spawnPoint.z);
			pitch = 0;
		}
		M008 AABBCCDDEEFFGGHHIIJJKKLLMMNNOOPPQQRRSS 1
		{
			angle = Normalize180(angle + 1);
		}
		loop;
	Anim_left:
		#### # 0
		{
			SetZ(spawnPoint.z);
			pitch = 0;
		}
		M008 AABBCCDDEEFFGGHHIIJJKKLLMMNNOOPPQQRRSS 1
		{
			angle = Normalize180(angle - 1);
		}
		loop;
	Anim_moveup:
		#### # 0
		{
			SetZ(spawnPoint.z + 20);
			angle = dollSpawnAngle;
			pitch = -45;
		}
		M009 ABCDEFGHIJKLMNOPQRS 2;
		loop;
	Anim_movedown:
		#### # 0
		{
			SetZ(spawnPoint.z + 20);
			angle = dollSpawnAngle;
			pitch = 45;
		}
		M009 ABCDEFGHIJKLMNOPQRS 2;
		loop;
	Anim_User4: //kick
		#### # 0
		{
			SetZ(spawnPoint.z);
			angle = dollSpawnAngle;
			pitch = 0;
		}
		M126 ABCDEFGHIJKLMNOPQRSTUVWXYZ 2;
		M127 ABCD 2;
		loop;
	}
}