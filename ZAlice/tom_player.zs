class ToM_AlicePlayer : DoomPlayer
{
	static const name modelpaths[] =
	{
		"models/alice/knife",
		"models/alice/HobbyHorse",
		"models/alice/cards",
		"models/alice/jacks",
		"models/alice/pgrinder",
		"models/alice/teapot",
		"models/alice/eyestaff",
		"models/alice/blunderbuss"
	};

	static const name modelnames[] =
	{
		"aliceplayer_knife.iqm",
		"aliceplayer_horse.iqm",
		"aliceplayer_cards.iqm",
		"jacks.iqm",
		"pgrinder.iqm",
		"teapot.iqm",
		"eyestaff.iqm",
		"blunderbuss.iqm"
	};

	enum EWModels
	{
		AW_Knife,
		AW_Horse,
		AW_Cards,
		AW_Jacks,
		AW_PGrinder,
		AW_Teapot,
		AW_Eyestaff,
		AW_Blunderbuss,
	}

	state s_idle;
	state s_walk_smallweapon;
	state s_run_smallweapon;
	state s_walk_bigweapon;
	state s_run_bigweapon;
	state s_atk_knife;
	state s_atk_horse;
	state s_atk_cards;
	state s_atk_jacks; //same as cards
	state s_atk_pgrinder;
	state s_atk_teapot;
	state s_atk_eyestaff;
	state s_atk_blunderbuss;
	state s_swim;
	state s_jump;

	private int curWeaponID;
	private vector2 prevMoveDir;

	private int airJumps;
	private int airJumpTics;
	const MAXAIRJUMPTICS = 6;
	const MAXAIRJUMPS = 1;
	const AIRJUMPTICTHRESHOLD = -4;
	const AIRJUMPFACTOR = 0.8;

	Default
	{
		+INTERPOLATEANGLES
		player.StartItem "ToM_Knife", 1;
		player.Viewheight 51;
		player.AttackZOffset 18;
		MeleeRange 80;
	}
	
	bool IsPlayerMoving()
	{
		let player = self.player;
		return player.cmd.forwardmove != 0 || player.cmd.sidemove != 0;

		let buttons = player.cmd.buttons;

		/*console.printf(
			"maptime: %d | "
			"FW %d | "
			"BK %d | "
			"LL %d | "
			"RR %d | "
			"sidemove: %d | "
			"forwardmove: %d",
			level.maptime,
			buttons & BT_FORWARD,
			buttons & BT_BACK,
			buttons & BT_MOVELEFT,
			buttons & BT_MOVERIGHT,
			player.cmd.sidemove,
			player.cmd.forwardmove
		);*/
		return (player.OnGround || waterlevel >= 2) && (buttons & BT_FORWARD || buttons & BT_BACK || buttons & BT_MOVELEFT || buttons & BT_MOVERIGHT);
	}

	bool IsPlayerRunning()
	{	
		let buttons = player.cmd.buttons;

		return IsPlayerMoving() && (buttons & BT_RUN);
	}

	state PickMovementState()
	{
		if (!IsPlayerMoving())
		{
			return spawnState;
		}
		
		state targetstate;
		if (waterlevel >= 2)
			targetState = s_swim;
		
		else 
		{
			bool isRunning = IsPlayerRunning();
			targetState = isRunning ? s_run_smallweapon : s_walk_smallweapon;
			let weap = ToM_BaseWeapon(player.readyweapon);
			if (weap && weap.IsTwoHanded)
			{
				targetState = isRunning ? s_run_bigweapon : s_walk_bigweapon;
			}
		}

		return targetState;
	}

	void UpdateMovementSpeed(int mintics = 1, int maxtics = 4)
	{
//		int targetTics = int(ToM_UtilsP.LinearMap(vel.length(), 0, 10, 8, 1));
//		targetTics = Clamp(targetTics, mintics, maxtics);
//		A_SetTics(targetTics);

//		if (lastframe > 0)
//		{
//			if (player.cmd.forwardmove != 0)
//			{
//				if (player.cmd.forwardmove > 0)
//				{
//					frame = ToM_UtilsP.LoopRange(frame + 1, 0, lastframe);
//				}
//				else
//				{
//					frame = ToM_UtilsP.LoopRange(frame - 1, 0, lastframe);
//				}
//			}
//			else if (player.cmd.sidemove != 0)
//			{
//				frame = ToM_UtilsP.LoopRange(frame + 1, 0, lastframe);
//			}
//		}

		PlayRunning();
	}

	void UpdateWeaponModel()
	{
		if (!player)
			return;

		let weap = ToM_BaseWeapon(player.readyweapon);
		if (!weap || weap.wasThrown)
		{
			curWeaponID = -1;
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
			A_ChangeModel("", 1, modelpaths[newmodel], modelnames[newmodel]);
		}
	}
	
	override void PlayRunning()
	{
		let player = self.player;

		if (player.playerstate == PST_DEAD)
			return;
		
		if (player.cmd.buttons & BT_ATTACK || player.cmd.buttons & BT_ALTATTACK)
			return;
		
		if (InStateSequence(curstate, s_jump))
			return;

		state targetstate = PickMovementState();

		if (!InStateSequence(curstate, targetState))
		{
			SetState(targetState);
		}
	}

	override void PlayIdle()
	{
		if (player.playerstate == PST_DEAD)
			return;

		if (!InStateSequence(curstate, SpawnState))
		{
			SetState(SpawnState);
		}
	}

	override void PlayAttacking()
	{
		if (player.playerstate == PST_DEAD)
			return;

		if (curWeaponID < 0)
			return;
		
		state targetstate;
		switch (curWeaponID) {
		case AW_Knife:
			targetstate = s_atk_knife;
			break;
		case AW_Horse:
			targetstate = s_atk_horse;
			break;
		case AW_Cards:
			targetstate = s_atk_cards;
			break;
		case AW_Jacks:
			targetstate = s_atk_jacks;
			break;
		case AW_PGrinder:
			targetstate = s_atk_pgrinder;
			break;
		case AW_Teapot:
			targetstate = s_atk_teapot;
			break;
		case AW_Eyestaff:
			targetstate = s_atk_eyestaff;
			break;
		case AW_Blunderbuss:
			targetstate = s_atk_blunderbuss;
			break;
		}

		//bool pressingAttack = (player.cmd.buttons & BT_ATTACK) || (player.cmd.buttons & BT_ALTATTACK);

		// only play the attack animation if it's either not yet playing,
		// or the player keeps pressing fire (for autofire weapons):
		if (targetstate && (player.attackdown || !InStateSequence(curstate, targetState)))
		{
			SetState(targetstate);
		}
	}

	override void PlayAttacking2 ()
	{
		PlayAttacking();
	}

	override void BeginPlay()
	{
		super.BeginPlay();

		curWeaponID = -1;

		s_idle = ResolveState("Idle");
		s_walk_smallweapon = ResolveState("WalkSmall");
		s_run_smallweapon = ResolveState("RunSmall");
		s_walk_bigweapon = ResolveState("WalkBig");
		s_run_bigweapon = ResolveState("RunBig");
		s_atk_knife = ResolveState("Attack_Knife");
		s_atk_horse = ResolveState("Attack_Horse");
		s_atk_cards = ResolveState("Attack_Cards");
		s_atk_jacks = ResolveState("Attack_Cards");
		s_atk_pgrinder = ResolveState("Attack_PGrinder");
		s_atk_teapot = ResolveState("Attack_Teapot");
		s_atk_eyestaff = ResolveState("Attack_Eyestaff");
		s_atk_blunderbuss = ResolveState("Attack_Blunderbuss");
		s_swim = ResolveState("Swim");
		s_jump = ResolveState("Jump");
	}

	override void PlayerThink()
	{
		super.PlayerThink();

		let player = self.player;
		if (!player)
			return;
		
		UpdateWeaponModel();

		// Make the model face the direction of movement, if the player
		// is in third person or seen from outside:
		if (PlayerNumber() != consoleplayer || (player.cheats & CF_CHASECAM) || player.camera != self)
		{
			// If firing, face the angle (no direction);
			if (InStateSequence(curstate, missilestate))
			{
				prevMoveDir = (0,0);
			}
			else if (vel.xy.Length() > 0)
			{
				prevMoveDir = Level.Vec2Diff(pos.xy, pos.xy + vel.xy);
			}
			spriteRotation = (prevMoveDir == (0,0)) ? 0 : atan2(prevMoveDir.y, prevMoveDir.x) - angle;
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
			//	player.viewz += ToM_UtilsP.LinearMap(jumptics, downlim, lim, downlim * downfac, 0, true);

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

	static const name leaftex[] = { 'AIRLEAF1', 'AIRLEAF2', 'AIRLEAF3', 'AIRLEAF4', 'AIRLEAF5', 'AIRLEAF6', 'AIRLEAF7', 'AIRLEAF8' };

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

		if (player.jumptics < AIRJUMPTICTHRESHOLD && airJumps < MAXAIRJUMPS && player.cmd.buttons & BT_JUMP && !(player.oldbuttons & BT_JUMP))
		{
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

			SetStateLabel("JumpAir");

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
	}

	override void FallAndSink(double grav, double oldfloorz)
	{
		let player = self.player;
		if (player)
		{			
			// [AA] No falling in water if the player is
			// moving:
			if (waterlevel > 1 && vel.x != 0 && vel.y != 0)
			{
				return;
			}

			else if (pos.z > floorz && waterlevel == 0 && !bNOGRAVITY)
			{
				// Handling for crossing ledges:
				if (vel.z == 0 && pos.z == oldfloorz && oldfloorz > floorz)
				{
					vel.z -= grav * 1.5; //[AA] default was * 2
					return;
				}
				// reduced gravity effect when jumping:
				else if (player.jumptics != 0)
				{
					vel.z -= grav * 0.5; //[AA] default was 1.0
					return;
				}
			}
		}

		super.FallAndSink(grav, oldfloorz);
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
				let hvel = ToM_UtilsP.RelativeToGlobalCoords(self, vel, false);
				vector2 movevel;
				moveVel.x = ToM_UtilsP.LinearMap(cmd.forwardmove, -12800, 12800, -hvel.x, hvel.x, true);
				moveVel.y = ToM_UtilsP.LinearMap(cmd.sidemove, -12800, 12800, -hvel.y, hvel.y, true);
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

	override void CheckJump()
	{
		let player = self.player;
		// [RH] check for jump
		if (player.cmd.buttons & BT_JUMP)
		{
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
				if (!(player.cheats & CF_PREDICTING)) A_StartSound("*jump", CHAN_BODY);

				if (!InStateSequence(curstate, s_jump))
				{
					SetState(s_jump);
				}
			}
		}
	}
	
	States {
	Move:
	Spawn:
		M100 A 320;
	//	M100 A 30;
	//Idle:
	//	M000 ABCDEFGHIJKLMLKJIHGFEDCB 2;
		loop;
	WalkSmall:
		M000 LMNOPQRSTUVWXYZ 1 UpdateMovementSpeed();
		M001 ABCDE 1 UpdateMovementSpeed();
		loop;
	RunSmall:
		M001 FGHIJKLMNOPQ 2 UpdateMovementSpeed(2);
		loop;
	WalkBig:
		M001 RSTUVWXYZ 1 UpdateMovementSpeed();
		M002 ABCDEFGHIJK 1 UpdateMovementSpeed();
		loop;
	RunBig:
		M002 LMNOPQRSTUVW 2 UpdateMovementSpeed(2);
		loop;
	Swim:
		M005 QRSTUVWXYZ 1 UpdateMovementSpeed();
		M006 ABCDEFGHIJK 1 UpdateMovementSpeed();
		loop;

	Melee:
		stop;
	Missile:	
	Attack_Knife:
		M006 UVWXYZ 1;
		M007 ABCDEFGHIJKLMNO 1;
		#### # 0 { return spawnstate; }
	Attack_Horse:
		M007 PQRSTUVWXYZ 2;
		M008 ABCDE 2;
		#### # 0 { return spawnstate; }
	Attack_Cards:
		M008 HIJKLMNOPQRSTU 2;
		#### # 0 { return spawnstate; }
	Attack_PGrinder:
		M008 F 20;
		#### # 0 { return spawnstate; }
	Attack_Teapot:
		M008 VWXYZ 1;
		M009 ABC 1;
		M009 BA 2;
		M008 ZYXW 2;
		M008 V 10;
		#### # 0 { return spawnstate; }
	Attack_Eyestaff:
		M009 D 20;
		#### # 0 { return spawnstate; }
	Attack_Blunderbuss:
		M009 FGHIJKLMNOPQRSTUVWXYZ 2;
		M010 ABCDE 2;
		M010 FGHIJKLMNOPQRSTUVWXYZ 1;
		M011 ABCDEFGHIJKLMNOPQRSTUVWXYZ 1;
		#### # 0 { return spawnstate; }
		stop;
	
	Jump:
		M006 LMNO 1;
		M006 OPQRST 1
		{
			if (player.onGround)
				return ResolveState("JumpEnd");
			return ResolveState(null);
		}
	JumpLoop:
		M012 ABCDE 2 
		{
			if (player.onGround)
				return ResolveState("JumpEnd");
			return ResolveState(null);
		}
		#### # 0 { return ResolveState("JumpLoop"); }
	JumpAir:
		M012 FGH 2
		{
			if (player.onGround)
				return ResolveState("JumpEnd");
			return ResolveState(null);
		}
	JumpAirLoop:
		M012 IJKL 2
		{
			if (player.onGround)
				return ResolveState("JumpEnd");
			return ResolveState(null);
		}
		loop;
	JumpEnd:
		M012 MNOPQRSTUV 1;
		goto Spawn;
	
	Pain:
		M002 XYZ 1;
		M003 ABCDEFGHIJ 1;
		Goto Spawn;
		
	Death:
		TNT1 A 0
		{
			A_PlayerScream();
			A_NoBlocking();
		}
		M003 KLMNOPQRSTUVWXYZ 1;
		M004 ABCDEFGHIJKLMNOPQRST 1;
		#### # -1;
		Stop;
	XDeath:
		TNT1 A 0
		{
			A_PlayerScream();
			A_NoBlocking();
		}
		M004 UVWXYZ 1;
		M005 ABCDEFGHIJKLMNOP 1;
		#### # -1;
		Stop;
	}
}

class ToM_PlayerModelTest : Actor
{
	States
	{
	Spawn:
 		//idle   
		TNT1 A 0 NoDelay A_ChangeModel("", "1", "models/alice/knife", "aliceplayer_knife.iqm");
 		M000 ABCDEFGHIJKLM 1;
 		M000 ABCDEFGHIJKLM 1;
 		// walk small weapon   
 		M001 ABCDEFGHIJKLMNOPQRST 1;
 		M001 ABCDEFGHIJKLMNOPQRST 1;
 		// run small weapon   
		TNT1 A 0 A_ChangeModel("", "1", "models/alice/teapot", "teapot.iqm");
 		M002 ABCDEFGHIJKL 1;
 		M002 ABCDEFGHIJKL 1;
 		// walk big weapon   
		TNT1 A 0 A_ChangeModel("", "1", "models/alice/HobbyHorse", "aliceplayer_horse.iqm");
 		M003 ABCDEFGHIJKLMNOPQRST 1;
 		M003 ABCDEFGHIJKLMNOPQRST 1;
 		// run big weapon   
		TNT1 A 0 A_ChangeModel("", "1", "models/alice/eyestaff", "eyestaff.iqm", 1, "models/alice/eyestaff", "eyestafftex.png");
 		M004 ABCDEFGHIJKL 1;
 		// pain   
 		M005 ABCDEFGHIJKLM 1;
 		// death faint   
 		M006 ABCDEFGHIJKLMNOPQRSTUVWXYZ 1;
 		M007 ABCDEFGHIJ 1;
 		#### # 10;
 		// death extreme   
 		M008 ABCDEFGHIJKLMNOPQRSTUV 1;
 		#### # 10;
		// swim
		M009 ABCDEFGHIJKLMNOPQRSTU 1;
		M009 ABCDEFGHIJKLMNOPQRSTU 1;
		// jump
		M010 ABCDEFGHI 1;
		#### # 20;
		M010 HGFEDCBA 1;
		#### # 15;
		M010 ABCDEFGHI 1;
		#### # 20;
		M010 HGFEDCBA 1;
		#### # 15;
		// knife
		TNT1 A 0 A_ChangeModel("", "1", "models/alice/knife", "aliceplayer_knife.iqm");
		M011 ABCDEFGHIJKLMNOPQRSTU 1;
		M011 ABCDEFGHIJKLMNOPQRSTU 1;
		M011 ABCDEFGHIJKLMNOPQRSTU 1;
		// cards 
		TNT1 A 0 A_ChangeModel("", "1", "models/alice/cards", "aliceplayer_cards.iqm");
		M014 A 20;
		M014 ABCDEFGHIJKLMN 1;
		M014 ABCDEFGHIJKLMN 1;
		M014 ABCDEFGHIJKLMN 1;
		// horse
		TNT1 A 0 A_ChangeModel("", "1", "models/alice/HobbyHorse", "aliceplayer_horse.iqm");
		M012 ABCDEFGHIJKLMNOP 1;
		M012 ABCDEFGHIJKLMNOP 1;
		M012 ABCDEFGHIJKLMNOP 1;
		// pepper grinder
		TNT1 A 0 A_ChangeModel("", "1", "models/alice/pgrinder", "pgrinder.iqm");
		M013 AB 10;
		// teapot
		TNT1 A 0 A_ChangeModel("", "1", "models/alice/teapot", "teapot.iqm");
		M015 ABCDEFGH 1;
		M015 GFEDCB 2;
		M015 ABCDEFGH 1;
		M015 GFEDCB 2;
		M015 ABCDEFGH 1;
		M015 GFEDCB 2;
		// eyestaff
		TNT1 A 0 A_ChangeModel("", "1", "models/alice/eyestaff", "eyestaff.iqm");
		M016 AB 10;
		// blunderbuss
		TNT1 A 0 A_ChangeModel("", "1", "models/alice/blunderbuss", "blunderbuss.iqm");
		M017 ABCDEFGHIJKLMNOPQRSTUVWXYZ 1;
		M018 ABCDEFGHIJKLMNOPQRSTUVWXYZ 1;
		M019 ABCDEFGHIJKLMNOPQRSTU 1;
		loop;
	}
}

class ToM_PlayerModelTestWalkLarge : Actor
{
	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		A_ChangeModel("", "1", "models/alice/jacks", "jacks.iqm");
	}

	States {
	Spawn:
 		M003 ABCDEFGHIJKLMNOPQRST 1;
		loop;
	}
}

class ToM_WeaponModelTest : Actor
{
	Default
	{
		+NOINTERACTION
		+NOBLOCKMAP
	}
	
	States {
	Spawn:
		M000 A -1 NoDelay 
		{
			Spawn("ToM_DebugSpot", pos);
		}
		stop;
	}
}
