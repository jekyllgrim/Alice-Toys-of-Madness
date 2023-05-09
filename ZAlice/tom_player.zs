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
