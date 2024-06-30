// used for testing position only:
class ToM_CheshireCatBase : ToM_BaseActor
{
	int talktime;
	Sound soundToPlay;

	Default
	{
		+SOLID
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
		+NOBLOCKMAP
		+NOINTERACTION
		+SYNCHRONIZED
		+NOSAVEGAME
		FloatBobphase 0;
		+DONTBLAST
		RenderStyle 'Translucent';
		Alpha 0;
	}

	static void SpawnAndTalk(PlayerPawn pmo, Sound soundToPlay, int talktime = 0, double rad = 512, double mindist = 128)
	{
		if (!pmo || ToM_Utils.IsVoodooDoll(pmo)) return;

		let c = CVar.GetCVar('tom_cheshire', pmo.player);
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
		for (int i = 32; i > 0; i--)
		{
			spawnpos = ToM_Utils.FindRandomPosAround(pmo.pos, rad, mindist, 60, pmo.angle);
			// not a single remotely valid position - abort:
			if (spawnpos == pmo.pos)
			{
				return;
				break;
			}
			// test position with a test actor:
			let testcat = Spawn('ToM_CheshireCatBase', spawnpos);
			spawngood = testcat && testcat.TestMobjLocation() && testcat.CheckSight(pmo);
			if (spawngood)
			{
				Vector3 view = Level.SphericalCoords((pmo.pos.xy, pmo.player.viewz), spawnpos, (pmo.angle, pmo.pitch));
				spawngood = abs(view.y) <= 40;
			}
			// destroy test actor:
			if (testcat)
			{
				testcat.Destroy();
			}
			// stop looking if position is good:
			if (spawngood)
			{
				break;
			}
		}

		handler.playerCheshireTimers[pnumber] = talktime;

		// the rest is ONLY executed for consoleplayer:
		if (pnumber == consoleplayer)
		{
			let cat = ToM_CheshireCatBase(Spawn('ToM_CheshireCat', spawnpos));
			if (cat)
			{
				cat.A_Face(pmo);
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