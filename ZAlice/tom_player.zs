class ToM_AlicePlayer : DoomPlayer
{
	state RunState;
	ToM_PlayerLegs legs;

	Default
	{
		player.StartItem "ToM_Knife", 1;
		//scale 1.2;
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

		// Regular movement bobbing
		// (needs to be calculated for gun swing even if not on ground)

		// killough 10/98: Make bobbing depend only on player-applied motion.
		//
		// Note: don't reduce bobbing here if on ice: if you reduce bobbing here,
		// it causes bobbing jerkiness when the player moves from ice to non-ice,
		// and vice-versa.

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
		/*double forwardmove, sidemove;
		double friction, movefactor;

		[friction, movefactor] = GetFriction();
		if (!player.onground && !bNoGravity && !waterlevel)
		{
			movefactor *= level.aircontrol;
		}

		forwardmove = fm * movefactor * (35 / TICRATE);
		sidemove = sm * movefactor * (35 / TICRATE);

		return (!(player.cheats & CF_PREDICTING) && (forwardmove != 0 || sidemove != 0));*/
		
		let buttons = player.cmd.buttons;
		
		return player.OnGround && (buttons & BT_FORWARD || buttons & BT_BACK || buttons & BT_MOVELEFT || buttons & BT_MOVERIGHT);
	}
	
	state ShouldStopMovingLegs()
	{
		if (!IsPlayerMoving())
			return SpawnState;
		
		return ResolveState(null);
	}
	
	/*override void PlayRunning()
	{
		if (SeeState && InStateSequence(CurState, SpawnState))
		{
			let sstate = SeeState;
			
			if (player.cmd.buttons & BT_RUN)
			{
				if (!RunState)
					RunState = ResolveState("SeeRun");
				sstate = RunState;
			}
			
			SetState (sstate);
		}
	}*/
	
	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		
		if (!legs)
		{
			legs = ToM_PlayerLegs(Spawn("ToM_PlayerLegs", pos));
			if (legs)
			{
				legs.ppawn = ToM_AlicePlayer(self);
			}
		}
	}
	
	States {
	Spawn:
		F120 A 1;
		Loop;
		
	See:
		F120 A 1;
		loop;
	SeeWalk:
		F121 ABCDEFGHIJKLMNOPQRST 1
		{
			return ShouldStopMovingLegs();
		}
		Loop;
	SeeRun:
		F122 ABCDEFGHIJKL 2
		{
			return ShouldStopMovingLegs();
		}
		Loop;
	
	Melee:
	Missile:
	Missile.VorpalBlade:
		F123 ABCDEFGHIJKLMNOPQRSTU 1;
		Goto Spawn;
	
	Pain:
		F126 ABCDEFGHIJKLM 1;
		Goto Spawn;
		
	Death:
		F007 A 3
		{
			if (legs)
			{
				legs.SetState(legs.FindState("Death"));
			}
			A_PlayerScream();
			A_NoBlocking();
		}
		F007 BCDEFGHI 3;
		F007 J -1;
		Stop;
	}
}

class ToM_PlayerLegs : ToM_SmallDebris
{
	ToM_AlicePlayer ppawn;
	
	protected state s_walk;
	protected state s_run;
	protected int curMoveState;
	protected bool isConsole;
	
	enum ELegsState
	{
		PL_STANDING,
		PL_WALKING,
		PL_RUNNING,
		PL_DEAD
	}
	
	Default
	{
		+NOINTERACTION
		+NOTIMEFREEZE
		renderstyle 'Normal';
	}
	
	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		bONLYVISIBLEINMIRRORS = (ppawn && ppawn.player && ppawn.player == players[consoleplayer] && !ToM_Mainhandler.IsVoodooDoll(ppawn));
		isConsole = bONLYVISIBLEINMIRRORS;
		
		s_walk = FindState("SeeWalk");
		s_run = FindState("SeeRun");
	}
	
	int CheckPPawnmovement()
	{
		if (!ppawn || !ppawn.player)
			return PL_STANDING;
	
		let player = ppawn.player;
		
		if (!player.OnGround)
			return PL_STANDING;
		
		let buttons = player.cmd.buttons;
		
		if (!(buttons & BT_FORWARD || buttons & BT_BACK || buttons & BT_MOVELEFT || buttons & BT_MOVERIGHT))
			return PL_STANDING;
		
		if (buttons & BT_RUN)
			return PL_RUNNING;
		
		return PL_WALKING;
	}
	
	override void Tick()
	{
		Super.Tick();
		
		if (!ppawn)
		{
			return;
		}
		
		SetOrigin(ppawn.pos, true);
		angle = ppawn.angle;
		
		if (isConsole)
		{
			bONLYVISIBLEINMIRRORS = !(ppawn.player.cheats & CF_CHASECAM);
		}
		
		if (curMoveState == PL_DEAD)
			return;
		
		switch (CheckPPawnmovement())
		{
		case PL_STANDING:
			if (curMoveState != PL_STANDING)
			{
				curMoveState = PL_STANDING;
				SetState(SpawnState);
			}
			break;
		case PL_WALKING:
			if (curMoveState != PL_WALKING)
			{
				curMoveState = PL_WALKING;
				SetState(s_walk);
			}
			break;
		case PL_RUNNING:
			if (curMoveState != PL_RUNNING)
			{
				curMoveState = PL_RUNNING;
				SetState(s_run);
			}
			break;
		}
	}
	
	States {
	Spawn:
		F120 A 1;
		Loop;
		
	SeeWalk:
		F121 ABCDEFGHIJKLMNOPQRST 1;
		Loop;
		
	SeeRun:
		F122 ABCDEFGHIJKL 2;
		Loop;
		
	Death:
		TNT1 A 0 { curMoveState = PL_DEAD; }
		F007 ABCDEFGHI 3;
		F007 J -1;
		Stop;
	}
}