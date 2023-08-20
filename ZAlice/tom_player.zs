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
	}
	
	double GetCameraBobSpeed()
	{
		if (CountInv("ToM_GrowControl"))
			return 40;
		
		return 20;
	}
	
	override void CalcHeight()
	{
		let player = self.player;
		double angle;
		double bob;
		bool still = false;

		if (player.cheats & CF_NOCLIP2)
		{
			player.bob = 0;
		}
		else if (bNoGravity && !player.onground)
		{
			player.bob = 0.5;
		}
		else
		{
			player.bob = player.Vel dot player.Vel;
			if (player.bob == 0)
			{
				still = true;
			}
			else
			{
				player.bob *= player.GetMoveBob();

				if (player.bob > MAXBOB)
					player.bob = MAXBOB;
			}
		}

		double defaultviewheight = ViewHeight + player.crouchviewdelta;

		if (player.cheats & CF_NOVELOCITY)
		{
			player.viewz = pos.Z + defaultviewheight;

			if (player.viewz > ceilingz-4)
				player.viewz = ceilingz-4;

			return;
		}

		if (still)
		{
			if (player.health > 0)
			{
				angle = Level.maptime / (120 * TICRATE / 35.) * 360.;
				bob = player.GetStillBob() * sin(angle);
			}
			else
			{
				bob = 0;
			}
		}
		else
		{
			angle = Level.maptime / (GetCameraBobSpeed() * TICRATE / 35.) * 360.;
			bob = player.bob * sin(angle) * (waterlevel > 1 ? 0.25f : 0.5f);
		}

		// move viewheight
		if (player.playerstate == PST_LIVE)
		{
			player.viewheight += player.deltaviewheight;

			if (player.viewheight > defaultviewheight)
			{
				player.viewheight = defaultviewheight;
				player.deltaviewheight = 0;
			}
			else if (player.viewheight < (defaultviewheight/2))
			{
				player.viewheight = defaultviewheight/2;
				if (player.deltaviewheight <= 0)
					player.deltaviewheight = 1 / 65536.;
			}
			
			if (player.deltaviewheight)	
			{
				player.deltaviewheight += 0.25;
				if (!player.deltaviewheight)
					player.deltaviewheight = 1/65536.;
			}
		}

		if (player.morphTics)
		{
			bob = 0;
		}
		player.viewz = pos.Z + player.viewheight + (bob * clamp(ViewBob, 0. , 1.5)); // [SP] Allow DECORATE changes to view bobbing speed.
		if (Floorclip && player.playerstate != PST_DEAD
			&& pos.Z <= floorz)
		{
			player.viewz -= Floorclip;
		}
		if (player.viewz > ceilingz - 4)
		{
			player.viewz = ceilingz - 4;
		}
		if (player.viewz < floorz + 4)
		{
			player.viewz = floorz + 4;
		}
	}
	
	bool IsPlayerMoving()
	{	
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

	void UpdateMovementSpeed()
	{
		//int targetTics = int(ToM_UtilsP.LinearMap(vel.length(), 0, 10, 5, 1, true));
		//A_SetTics(targetTics);
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
			A_ChangeModel("", 1, "", "");
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
		if (player.playerstate == PST_DEAD)
			return;

		if (player.cmd.buttons & BT_ATTACK || player.cmd.buttons & BT_ALTATTACK)
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

		bool pressingAttack = (player.cmd.buttons & BT_ATTACK) || (player.cmd.buttons & BT_ALTATTACK);
		// only play the attack animation if it's either not yet playing,
		// or the player keeps pressing fire (for autofire weapons):
		if (targetstate && (pressingAttack || !InStateSequence(curstate, targetState)))
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
	
	override void Tick()
	{
		super.Tick();
		UpdateWeaponModel();
	}

	override void PlayerThink()
	{
		super.PlayerThink();

		if (airJumpTics > 0)
			airJumpTics--;

		if (pos.z <= floorz || waterlevel > 0)
			airJumps = 0;

		if (pos.z > floorz && waterlevel == 0 && !bNOGRAVITY)
		{
			CheckAirJump();
		}

		double lim = -12;
		double downlim = -4;
		double downfac = 6;

		int jumptics = player.jumptics;
		if (jumptics < 0 && jumptics >= lim)
		{
			if (jumptics >= downlim)
				player.viewz += jumptics * downfac;
			
			else
				player.viewz += ToM_UtilsP.LinearMap(jumptics, downlim, lim, downlim * downfac, 0, true);

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

		int lim = -12;
		int downlim = -4;
		double downfac = -1.85;
		if (player && player.jumptics < 0 && player.jumptics >= lim)
		{
			double prevboby;
			double boby;
			if (player.jumptics >= downlim)
			{
				prevboby = (player.jumptics - 1) * downfac;
				boby = player.jumptics * downfac;
			}
			else
			{
				prevboby = ToM_UtilsP.LinearMap(player.jumptics - 1, downlim, lim, downlim * downfac, 0, true);
				boby = ToM_UtilsP.LinearMap(player.jumptics, downlim, lim, downlim * downfac, 0, true);
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
		if (pos.z > floorz && waterlevel == 0 && !bNOGRAVITY)
		{
			// Default handling for crossing ledges:
			if (vel.z == 0 && pos.z == oldfloorz && oldfloorz > floorz)
				vel.z -= grav * 2;
			// slowed-down falling:
			else
				vel.z -= grav * 0.5;
			
			return;
		}
		
		// No falling in water (I've always hated it):
		else if (waterlevel > 0)
			return;

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

		if (cmd.forwardmove | cmd.sidemove)
		{
			double forwardmove, sidemove;
			double bobfactor;
			double friction, movefactor;
			double fm, sm;

			[friction, movefactor] = GetFriction();
			bobfactor = friction < ORIG_FRICTION ? movefactor : ORIG_FRICTION_FACTOR;
			// [JGP] Only had to override this to add this feature:
			if (!player.onground && !bNoGravity && !waterlevel && airJumpTics <= 0)
			{
				// [RH] allow very limited movement if not on ground.
				movefactor *= level.aircontrol;
				bobfactor*= level.aircontrol;
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
	Spawn:
		M100 A 320;
	//	M100 A 30;
	//Idle:
	//	M000 ABCDEFGHIJKLMLKJIHGFEDCB 2;
		Loop;
	WalkSmall:
		M001 ABCDEFGHIJKLMNOPQRST 1 UpdateMovementSpeed();
		Loop;
	RunSmall:
		M002 ABCDEFGHIJKL 2 UpdateMovementSpeed();
		Loop;
	WalkBig:
		M003 ABCDEFGHIJKLMNOPQRST 1  UpdateMovementSpeed();
		Loop;
	RunBig:
		M004 ABCDEFGHIJKL 2 UpdateMovementSpeed();
		Loop;
	Swim:
		M009 ABCDEFGHIJKLMNOPQRSTU 1 UpdateMovementSpeed();
		loop;

	Melee:
		stop;
	Missile:
		stop;
	
	Attack_Knife:
		M011 ABCDEFGHIJKLMNOPQRSTU 1;
		Goto Spawn;
	Attack_Horse:
		M012 ABCDEFGHIJKLMNOP 2;
		Goto Spawn;
	Attack_Cards:
		M014 ABCDEFGHIJKLMN 2;
		Goto Spawn;
	Attack_PGrinder:
		M013 A 10;
		M013 A 10;
		Goto Spawn;
	Attack_Teapot:
		M015 ABCDEFGH 1;
		M015 HGFEDCB 2;
		M015 A 10;
		Goto Spawn;
	Attack_Eyestaff:
		M016 A 10;
		M016 A 10;
		Goto Spawn;
	Attack_Blunderbuss:
		M017 ABCDEFGHIJKLMNOPQRSTUVWXYZ 2;
		M018 ABCDEFGHIJKLMNOPQRSTUVWXYZ 1;
		M019 ABCDEFGHIJKLMNOPQRSTU 1;
		goto Spawn;
	
	Pain:
		M005 ABCDEFGHIJKLM 1;
		Goto Spawn;
		
	Death:
		TNT1 A 0
		{
			A_PlayerScream();
			A_NoBlocking();
		}
		M006 ABCDEFGHIJKLMNOPQRSTUVWXYZ 1;
		M007 ABCDEFGHIJ 1;
		#### # -1;
		Stop;
	XDeath:
		TNT1 A 0
		{
			A_PlayerScream();
			A_NoBlocking();
		}
		M008 ABCDEFGHIJKLMNOPQRSTUV 1;
		#### # -1;
		Stop;
	
	Jump:
		M010 ABCDEFGH 1;
		M010 I 1
		{
			if (player.onGround)
				return ResolveState("JumpEnd");
			return ResolveState(null);
		}
		wait;
	JumpEnd:
		M010 HGFEDCBA 1;
		goto Spawn;
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
