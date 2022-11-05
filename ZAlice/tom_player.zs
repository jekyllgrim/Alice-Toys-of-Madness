class ToM_AlicePlayer : DoomPlayer
{
	state RunState;
	ToM_PlayerLegs legs;

	Default
	{
		player.StartItem "ToM_Knife", 1;
		//scale 1.2;
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