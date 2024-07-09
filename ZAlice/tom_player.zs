class ToM_AlicePlayer : DoomPlayer
{
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

	static const name leaftex[] = { 'AIRLEAF1', 'AIRLEAF2', 'AIRLEAF3', 'AIRLEAF4', 'AIRLEAF5', 'AIRLEAF6', 'AIRLEAF7', 'AIRLEAF8' };
	
	protected int curWeaponID;
	protected vector2 prevMoveDir;
	double modelDirection;

	protected state s_jump;
	protected state s_airjump;
	protected int airJumps;
	protected int airJumpTics;
	const MAXAIRJUMPTICS = 6;
	const MAXAIRJUMPS = 1;
	const AIRJUMPTICTHRESHOLD = -4;
	const AIRJUMPFACTOR = 0.8;

	Default
	{
		+INTERPOLATEANGLES
		+DECOUPLEDANIMATIONS
		+DONTTRANSLATE
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

	void UpdateMovementAnimation()
	{
		double hvel = vel.xy.Length();
		bool twohanded;
		let weap = ToM_BaseWeapon(player.readyweapon);
		twohanded = weap && weap.IsTwoHanded;

		// swimming
		double minFr = 15;
		double maxFr = 40;
		if (FindInventory('ToM_GrowthPotionEffect'))
		{
			minFr *= ToM_GrowthPotionEffect.SPEEDFACTOR;
			maxFr *= ToM_GrowthPotionEffect.SPEEDFACTOR;
		}
		if (waterLevel >= 2)
		{
			SetAnimation('swim_loop', interpolateTics: 10, flags:SAF_LOOP|SAF_NOOVERRIDE);
			SetAnimationFrameRate(ToM_Utils.LinearMap(hvel, 3, 18, minFr, maxFr));
		}
		// falling (not jumping)
		else if (!player.onground && !IsPlayerFlying())
		{
			if (!InStateSequence(curstate, s_jump))
			{
				SetAnimation('jump', startframe: 9, loopframe: 9, interpolateTics: 6, flags:SAF_LOOP|SAF_NOOVERRIDE);
				SetStateLabel("JumpLoop");
			}
		}
		// standing still
		else if (hvel <= 0.1)
		{
			SetAnimation('basepose', interpolateTics: 10, flags:SAF_LOOP|SAF_NOOVERRIDE);
		}
		// walking
		else if (hvel <= 7.5)
		{
			SetAnimation(twohanded? 'walk_bigweapon' : 'walk_smallweapon', interpolateTics: 5, flags:SAF_LOOP|SAF_NOOVERRIDE);
			SetAnimationFrameRate(ToM_Utils.LinearMap(hvel, 2, 7.5, minFr, maxFr));
		}
		// running
		else
		{
			SetAnimation(twohanded? 'run_bigweapon' : 'run_smallweapon', flags:SAF_LOOP|SAF_NOOVERRIDE);
			SetAnimationFrameRate(ToM_Utils.LinearMap(hvel, 7.5, 20, minFr, maxFr));
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
			A_ChangeModel("", 1, flags: CMDL_HIDEMODEL);
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
			A_ChangeModel("", 1, "models/alice/weapons", modelnames[newmodel]);
		}
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
		if (!player)
			return;
		
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
			airJumps = 0;

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

		int downlim = -4;
		int uplim = 6;
		double downfac = -1.85;
		double upfac = 1.2;
		int jumptics = player.jumptics;
		if (player && jumptics != 0)
		{
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
			
			return (bob.x, boby * (1. - ticfrac) + prevboby * ticfrac);
		}
		
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
		else if (level.IsJumpingAllowed() && player.onground && player.jumpTics == 0)
		{
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
			SetState(s_jump);
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

		SetState(s_airjump);

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
		let player = self.player;
		bool done = false;

		// [AA] No falling in water if the player is
		// moving:
		if (waterlevel > 1 && vel.x != 0 && vel.y != 0)
		{
			done = true;
		}

		else if (pos.z > floorz && waterlevel == 0 && !bNOGRAVITY)
		{
			// Handling for crossing ledges:
			if (vel.z == 0 && pos.z == oldfloorz && oldfloorz > floorz)
			{
				vel.z -= grav * 1.; //[AA] default was * 2
				done = true;
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
		
		// [AA] If the player just landed after a jump and
		// isn't trying to move, aggressively reduce velocity
		// to avoid uncontrollable after-jump sliding:
		bool doBrake;
		if (player.onground && !waterlevel && player.jumptics > 0)
		{
			// If the player isn't pressing movement keys
			// at all, let them brake:
			if (!(cmd.sidemove | cmd.forwardmove))
			{
				doBrake = true;
			}
			else 
			{
				// Compare velocity to controls. If the player is pressing
				// movement keys in the opposite direction of their
				// current movement, let them brake:
				let hvel = ToM_Utils.RelativeToGlobalCoords(self, vel, false);
				vector2 movevel;
				moveVel.x = ToM_Utils.LinearMap(cmd.forwardmove, -ToM_MaxMoveInput, ToM_MaxMoveInput, -hvel.x, hvel.x, true);
				moveVel.y = ToM_Utils.LinearMap(cmd.sidemove, -ToM_MaxMoveInput, ToM_MaxMoveInput, -hvel.y, hvel.y, true);
				if ( (movevel.x > 0 && hvel.x < 0 || movevel.x < 0 && hvel.x > 0) || (movevel.x > 0 && hvel.x < 0 || movevel.x < 0 && hvel.x > 0) )
				{
					//console.printf("forwardmove/sidemove: %.2f, %.2f | vel.xy: %.2f, %.2f", movevel.x, movevel.y, hvel.x, hvel.y);
					doBrake = true;
				}
			}
		}
		// Aggressive braking:
		if (doBrake)
		{
			vel.xy *= 0.72;
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
				// [AA] Aircontrol doesn't apply for a few tics after
				// an air jump (see airJumpTics), to let the player
				// reorient themselves when performing it:
				if (airJumpTics <= 0)
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
			
			// [AA] Slow down the player just after jump if they're not pressing movement keys

			if (!(player.cheats & CF_PREDICTING) && (forwardmove != 0 || sidemove != 0))
			{
				PlayRunning ();
			}

			if (player.cheats & CF_REVERTPLEASE)
			{
				player.cheats &= ~CF_REVERTPLEASE;
				player.camera = player.mo;
			}
		}
	}
	
	States {
	See:
	Spawn:
		M000 A 1 UpdateMovementAnimation();
		loop;

	Melee:
	Missile:
		M000 A 30;
		goto Spawn;
	
	Jump:
		JumpGround:
			M000 A 8 SetAnimation('jump', 30, loopframe: 9, flags: SAF_LOOP);
			M000 A 0
			{
				return ResolveState("JumpLoop");
			}
		JumpAir:
			M000 A 4 
			{
				SetAnimation('jump_air', 20, loopframe: 4, flags: SAF_LOOP);
				return ResolveState("JumpLoop");
			}
		JumpLoop:
			M000 A 1;
			M000 A 0
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
			M000 A 12 
			{
				SetAnimation('jump_end', 30);
			}
			goto Spawn;
	
	Pain:
		M000 A 12 SetAnimation('pain');
		Goto Spawn;
		
	Death:
		M000 A -1
		{
			A_PlayerScream();
			A_NoBlocking();
			SetAnimation('death_faint');
		}
		Stop;
	XDeath:
		M000 A -1
		{
			A_PlayerScream();
			A_NoBlocking();
			SetAnimation('death_fall');
		}
		Stop;
	}
}