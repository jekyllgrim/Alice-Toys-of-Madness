// used for testing position only:
class ToM_CheshireCatBase : ToM_BaseActor
{
	int talktime;
	Sound soundToPlay;

	Default
	{
		+SOLID
		+SYNCHRONIZED
		FloatBobphase 0;
		+DONTBLAST
		+DECOUPLEDANIMATIONS
		+NOTIMEFREEZE
		Radius 20;
		Height 56;
	}
}

// this one gets actually spawned (for each consoleplayer separately):
class ToM_CheshireCat : ToM_CheshireCatBase
{
	Default
	{
		+NOINTERACTION
		+NOBLOCKMAP
		+NOSAVEGAME
		RenderStyle 'Translucent';
		Alpha 0;
	}

	static void SpawnAndTalk(PlayerPawn pmo, Sound soundToPlay, int talktime = 0, double rad = 512, double mindist = 128, bool mapevent = false)
	{
		if (!pmo || ToM_Utils.IsVoodooDoll(pmo)) return;

		let c = CVar.GetCVar(mapevent? 'tom_cheshire_map' : 'tom_cheshire_items', pmo.player);
		if (!c || !c.GetBool()) return;

		int pnumber = pmo.PlayerNumber();
		talktime = talktime > 0? talktime : S_GetLength(soundToPlay) * TICRATE;
		let handler = ToM_MainHandler(EventHandler.Find('ToM_MainHandler'));
		if (!handler || handler.playerCheshireTimers[pnumber] > 0)
		{
			return;
		}

		Vector3 spawnpos = pmo.pos;
		bool spawngood;
		// Pick spawn position.
		// First, try spawning in front of the player (-45/45 + player's angle)
		// if not possible, try spawning behind (-45/315 + player's angle)
		double angstep = 5;
		double alim1 = 45; //inner range 
		double alim2 = alim1 + (360 - alim1*2);
		double anglimit = alim1;
		// Start with 0 and go right:
		for (int i = 0; abs(i) <= abs(anglimit); i += angstep)
		{
			ToM_DebugMessage.Print(String.Format("Iterating. i = %d, angstep = %d, anglimit = %d", i, angstep, anglimit));
			// reached right limit, start going left:
			if (anglimit == alim1 && i >= anglimit)
			{
				anglimit = -anglimit;
				angstep = -angstep;
				i = 0;
			}
			// reached left limit:
			else if (anglimit < 0 && i <= anglimit)
			{
				// If still using first range, extend to 315
				// and start going right from 50:
				if (abs(anglimit) == alim1)
				{
					anglimit = alim2;
					angstep = -angstep;
					i = alim1;
					ToM_DebugMessage.Print(String.Format("reached -45. Resetting. i = %d, angstep = %d, anglimit = %d", i, angstep, anglimit));
					continue;
				}
				// otherwise abort:
				else
				{
					ToM_DebugMessage.Print(String.Format("reached %d, aborting", anglimit));
					break;
				}
			}

			Vector3 ppos;
			ppos.xy = pmo.pos.xy + Actor.RotateVector((frandom[catspawn](mindist, rad), 0), pmo.angle + i);
			ppos.z = level.PointInSector(ppos.xy).NextLowestFloorAt(ppos.x, ppos.y, pmo.pos.z);
			if (tom_debugobjects)
				ToM_DebugSpot.Spawn(ppos, 5, 6);

			if (ppos.z > pmo.pos.z + 160 || ppos.z < pmo.pos.z - 64) continue;
			if (!level.IsPointInLevel(ppos)) continue;

			spawnpos = ppos;
			// test position with a test actor:
			let testcat = Spawn('ToM_CheshireCatBase', spawnpos);
			spawngood = testcat && testcat.TestMobjLocation() && testcat.CheckSight(pmo);
			// destroy test actor:
			if (testcat)
			{
				testcat.Destroy();
			}
			// stop looking if position is good:
			if (spawngood)
			{
				ToM_DebugMessage.Print(String.Format("Found good spawn position"));
				break;
			}
		}
		// Not a single valid position found:
		if (spawnpos == pmo.pos)
		{
			ToM_DebugMessage.Print(String.Format("Can't find any cat positions"));
			return;
		}

		handler.playerCheshireTimers[pnumber] = talktime;

		// the rest is ONLY executed for consoleplayer:
		if (pnumber == consoleplayer)
		{
			let cat = ToM_CheshireCatBase(Spawn('ToM_CheshireCat', spawnpos));
			if (cat)
			{
				cat.angle += cat.AngleTo(pmo);
				cat.soundToPlay = soundToPlay;
				cat.talktime = talktime;
			}
		}
	}

	State A_ProgressSpeech()
	{
		if (talktime <= 0)
		{
			return FindState("Despawn");
		}
		return FindState(null);
	}

	override void PostbeginPlay()
	{
		Super.PostBeginPlay();
		SetAnimation('idle', flags:SAF_LOOP|SAF_INSTANT);
	}

	override void Tick()
	{
		Super.Tick();
		if (!IsFrozen() && InStateSequence(curstate, FindState("Talk")))
		{
			talktime--;
		}
	}

	States {
	Spawn:
		TNT1 A 35;
		TNT1 A 0 A_StartSound("cheshire/spawn", CHAN_BODY);
		M000 A 1 
		{
			A_FadeIn(0.028);
			if (alpha >= 1)
			{
				A_SetRenderStyle(1.0, STYLE_Normal);
				return ResolveState("Idle");
			}
			return ResolveState(null);
		}
		wait;
	Despawn:
		M000 A 50 SetAnimation('idle', interpolateTics: 20, flags:SAF_LOOP);
		M000 A 0 A_StartSound("cheshire/despawn", CHAN_BODY);
		M000 A 1 A_FadeOut(0.028);
		wait;
	Idle:
		M000 A 35;
		M000 A 0 A_StartSound(soundToPlay, CHAN_VOICE, attenuation: ATTN_NONE);
		goto Talk;
	Talk:
		M000 A 51
		{
			SetAnimation('talk1');
			tics = min(talktime, tics);
		}
		M000 A 0 A_ProgressSpeech();
		M000 A 73 
		{
			SetAnimation('talk2');
			tics = min(talktime, tics);
		}
		M000 A 0 A_ProgressSpeech();
		M000 A 58 
		{
			SetAnimation('talk3');
			tics = min(talktime, tics);
		}
		M000 A 0 A_ProgressSpeech();
		loop;
	}
}