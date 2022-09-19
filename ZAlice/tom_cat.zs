class ToM_CheshireCat : ToM_BaseActor
{
	int talkduration;

	Default
	{
		+NOINTERACTION
		+NOBLOCKMAP
		scale 0.8;
		SeeSound "characters/cheshire/spawn";
	}
		
	
	virtual state A_ChangeTalkState(StateLabel state1, StateLabel state2)
	{
		if (talkduration == 0)
			return ResolveState("Despawn");
		return A_Jump(256, state1, state2);
	}
	
	void A_StartTalking()
	{
		talkduration = int(S_GetLength(activesound)) + 1;
		A_StartSound(ActiveSound, CHAN_VOICE);
	}
	
	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		A_StartSound(seesound);
		talkduration = -1;
	}
	
	override void Tick()
	{
		super.Tick();
		if (talkduration > 0 && GetAge() % 35 == 0)
		{
			talkduration--;
		}
		if (talkduration == 0)
		{
			A_StartSound("characters/cheshire/despawn", flags:CHANF_NOSTOP);
			A_SetRenderstyle(alpha, Style_Translucent);
			A_FadeOut(0.1);
		}
		A_FaceTarget();
	}
	
	States
	{
	Spawn:
	Sit:
		M000 ABCDEFGHIJKLMNOPQRSTUVWXY 3;
		loop;
	Talk1:
		M002 ABCDEFGHIJKLMNOPQRSTUVWXYZ 2;
		M003 ABCDEFGHIJ 2;
		TNT1 A 0 { return ResolveState("Sit"); }
	Talk2:
		M004 ABCDEFGHIJKLMNOPQRSTUVWXYZ 1;
		M005 ABCDEFGHIJKLMNOPQRSTUVWXY 2;
		TNT1 A 0 { return ResolveState("Sit"); }
	Talk3:
		M006 ABCDEFGHIJKLMNOPQRSTUVWXYZ 2;
		M007 ABCDEFGHIJKLMN 2;
		TNT1 A 0 { return ResolveState("Sit"); }
	Stand:
		M008 ABCDEFGHIJKLMNOPQRSTU 3;
		loop;
	See:
		M001 ABCDEFGHIJKLMNOPQRSTU 3;
		loop;
	Despawn:
		TNT1 A 0 A_SetRenderstyle(alpha, Style_Translucent);
		M000 ABCDEFGHIJKLMNOPQRSTUVWXY 3 A_FadeOut(0.1);
		stop;
	}
}

class ToM_CheshireCat_Talk : ToM_CheshireCat
{
	Default
	{
		Renderstyle 'Translucent';
		alpha 0;
		ActiveSound "characters/cheshire/pickup_cards";
	}
	
	States
	{
	Spawn:
		M000 ABCDEFGHIJKLMN 3 A_FadeIn(0.1);
		TNT1 A 0 
		{
			A_SetRenderstyle(1, Style_Normal);
			A_StartTalking();
			return A_Jump(256, "Talk1", "Talk2", "Talk3");
		}
	Sit:
		TNT1 A 0 A_Jump(256, random[waitframe](1,10));
		M000 ABCDEFGHIJKLMNOPQRSTUVWXY 3;
		TNT1 A 0 
		{
			if (talkduration > 2)
				return A_Jump(256, "Talk1", "Talk2", "Talk3");
			return ResolveState(null);
		}
		loop;
	}
}