class ToM_AlicePlayer : DoomPlayer
{
	state RunState;

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
		let buttons = player.cmd.buttons;

		return player.OnGround && (buttons & BT_FORWARD || buttons & BT_BACK || buttons & BT_MOVELEFT || buttons & BT_MOVERIGHT);
	}
	
	state ProgressMovement()
	{
		if (!IsPlayerMoving())
			return SpawnState;
		
		state targetState = player.cmd.buttons & BT_RUN ? ResolveState("SeeRun") : ResolveState("See");
		if (!InStateSequence(curstate, targetState))
			return targetState;
		
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

	/*override void Tick()
	{
		super.Tick();
		if (player && player.readyweapon)
		{
			if (player.readyweapon is "ToM_Knife")
			{
				A_ChangeModel("", "1", "models/alice/knife", "aliceplayer_knife.iqm");
			}
		}
	}*/
	
	States {
	Spawn:
		M100 A 320;
		M100 A 30;
	Idle:
		M000 ABCDEFGHIJKLMLKJIHGFEDCB 2;
		Loop;
	See:
		M001 ABCDEFGHIJKLMNOPQRST 1
		{
			return ProgressMovement();
		}
		Loop;
	SeeRun:
		M002 ABCDEFGHIJKL 2
		{
			return ProgressMovement();
		}
		Loop;
	
	Melee:
	Missile:
	Missile.VorpalBlade:
		M009 ABCDEFGHIJKLMNOPQRSTU 1;
		Goto Spawn;
	
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
		TNT1 A 0 A_PlayerScream();
		M008 ABCDEFGHIJKLMNOPQRSTUV 1;
		#### # -1;
		Stop;
	Melee.Horse:
		M010 ABCDEFGHIJKLMNOP 1;
		goto Spawn;
	Missile.PGrinder:
		M011 A 5;
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
		M015 ABCDEFGH 2;
		M015 HGFEDCBA 4;
		M015 ABCDEFGH 2;
		M015 HGFEDCBA 4;
		M015 ABCDEFGH 2;
		M015 HGFEDCBA 4;
		// eyestaff
		TNT1 A 0 A_ChangeModel("", "1", "models/alice/eyestaff", "eyestaff.iqm", 1, "models/alice/eyestaff", "eyestafftex.png");
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
		A_ChangeModel("", "1", "models/alice/HobbyHorse", "aliceplayer_horse.iqm", skinindex: 1, skin: "FIREBLU");
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
