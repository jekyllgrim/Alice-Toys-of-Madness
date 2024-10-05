extend class ToM_UiHandler
{
	const DEBUGAREA_X = 1920;
	const DEBUGAREA_Y = 1080;
	const DEBUGLEVELS = 4;
	ui ToM_DebugMessage debugmessages[DEBUGLEVELS];
	ui HUDFont dfont;

	override void InterfaceProcess (ConsoleEvent e)
	{
		if (e.name.IndexOf("ToM_DebugMessage") >= 0)
		{
			//Console.MidPrint(smallfont, String.Format("Processing interface event: %s", e.name));
			array<String> cmd;
			e.name.Split(cmd, "::::");
			if (cmd.Size() != 2) return;
			int stringID = Clamp(e.args[0] - 1, 0, DEBUGLEVELS-1);
			String debugstring = String.Format("\cm%d\c- %s", gametic, cmd[1]);

			if (!debugmessages[stringID])
			{
				debugmessages[stringID] =  ToM_DebugMessage.Create(debugstring, stringID, e.args[1]);
			}
			else
			{
				debugmessages[stringID].Update(debugstring);
			}
		}
	}

	ui void PrintDebugBlock(array<String> strings, Vector2 pos, Vector2 size, HUDfont hfnt, double fntscale = 1.0, int screenflags = 0, double alpha = 1.0, color fillcolor = 0x30000000)
	{
		statusbar.Fill(fillcolor, pos.x, pos.y, size.x, size.y, screenflags);

		int indent = 1;
		Font fnt = hfnt.mFont;
		double stringHeight = fnt.GetHeight() * fntscale;
		int maxlines = (size.y - stringHeight*2) / (stringHeight + indent);
		double maxLineWidth = (size.x - stringHeight*2);
		
		for (int i = 0; i < strings.Size(); i++)
		{
			String str = strings[i];
			if (!str) continue;

			if (fnt.StringWidth(str) <= maxLineWidth) continue;

			int skip;
			strings.Delete(i);
			let brlines = fnt.BreakLines(str, maxLineWidth);
			for (int bi = 0; bi < brlines.Count(); bi++)
			{
				strings.Insert(i + bi, brlines.StringAt(bi));
				skip++;
			}

			i += skip;
		}

		Vector2 strpos = (pos.x + stringHeight, pos.y + size.y - stringHeight);
		int totalLines;
		double stralpha = alpha;

		for (int i = strings.Size() - 1; i >= 0; i--)
		{
			String str = strings[i];
			if (!str) continue;

			statusbar.DrawString(hfnt,
				str,
				(strpos.x, strpos.y - (stringHeight + 1)),
				screenflags,
				alpha: stralpha,
				linespacing: indent,
				scale: (fntscale, fntscale));

			totalLines += 1;
			if (totalLines > maxlines)
			{
				break;
			}

			strpos.y -= (stringHeight + 1);
			stralpha = alpha - alpha*0.5*(double(totalLines) / maxlines);
		}
	}

	ui void PrintDebugMessages()
	{
		if (tom_debugmessages <= 0 || tom_debugMsgMode < 2) return;

		statusbar.BeginHUD(1.0, true, DEBUGAREA_X, DEBUGAREA_Y);
		if (!dfont)
		{
			Font fnt = Font.FindFont('NewConsoleFont');
			dfont = HUDFont.Create(fnt, fnt.GetCharWidth("0"), Mono_CellCenter, 0, 1);
		}

		double realHUDWidth = DEBUGAREA_Y * Screen.GetAspectRatio();

		Vector2 areaSize = (DEBUGAREA_X * tom_debugMsgSizeX, DEBUGAREA_Y * tom_debugMsgSizeY);
		Vector2 pos = (-areaSize.x, 0);
		Color fillcolor = color(int(round(255 * tom_debugmsgBackAlpha * 0.2)), 0, 0, 0);
		for (int i = min(tom_debugmessages, debugmessages.Size()) - 1; i >= 0; i--)
		{
			let data = debugmessages[i];
			if (!data) continue;

			statusbar.DrawString(dfont,
				"Level "..i+1,
				pos,
				flags: StatusBarCore.DI_SCREEN_RIGHT_TOP|StatusBarCore.DI_TEXT_ALIGN_LEFT,
				translation: Font.CR_White);

			PrintDebugBlock(data.debugstrings,
				pos,
				areaSize,
				dfont,
				fntscale: tom_debugMsgFontScale,
				screenflags: StatusBarCore.DI_SCREEN_RIGHT_TOP,
				alpha: tom_debugmsgTextAlpha,
				fillcolor: fillcolor);

			pos.x -= areaSize.x + 2;
			if (pos.x < -realHUDWidth)
			{
				pos.x = DEBUGAREA_X - areaSize.x;
				pos.y += areaSize.y + 2;
			}
		}
	}
}

class ToM_DebugMessage ui
{
	const STRINGUPDATETIME = 4;
	const MAXSTRINGS = 512;
	int stringID;
	array<String> debugstrings;

	static clearscope void Print(String debugstring, int stringID = 1, bool singular = false)
	{
		if (stringID > tom_debugmessages) return;
		switch (tom_debugMsgMode)
		{
			default:
				Console.PrintfEx(PRINT_LOG, debugstring);
				break;
			case 1:
				Console.Printf(debugstring);
				break;
			case 2:
				Console.PrintfEx(PRINT_LOG, debugstring);
			case 3:
				EventHandler.SendInterfaceEvent(consoleplayer, "ToM_DebugMessage::::"..debugstring, stringID, singular);
				break;
		}
	}

	static ToM_DebugMessage Create(String debugstring, int stringID = 1, bool singular = false)
	{
		if (stringID > tom_debugmessages) return null;
		let data = new('ToM_DebugMessage');
		data.stringID = stringID;
		data.Update(debugstring);
		return data;
	}

	void Update(String debugstring, bool singular = false)
	{
		if (singular)
		{
			debugstrings.Clear();
		}
		array<String> strings;
		debugstring.Split(strings, "\n");
		for (int i = 0; i < strings.Size(); i++)
		{
			String str = strings[i];
			debugstrings.Push(str);
		}
		if (debugstrings.Size() > MAXSTRINGS)
		{
			debugstrings.Delete(0, debugstrings.Size() - MAXSTRINGS);
		}
	}
}

class ToM_DebugSpot : Actor 
{	
	Default 
	{
		+NOINTERACTION
		+NOBLOCKMAP
		+SYNCHRONIZED
		+DONTBLAST
		+BRIGHT
		+FORCEXYBILLBOARD
		xscale 0.35;
		yscale 0.292;
		FloatBobPhase 0;
		alpha 2;
		health 3;
		Renderstyle 'Shaded';
		StencilColor "00FF00";
	}

	static ToM_DebugSpot Spawn(Vector3 location, int duration, double size = 1)
	{
		let t = ToM_DebugSpot(Actor.Spawn('ToM_DebugSpot', location));
		if (t)
		{
			t.A_SetHealth(duration);
			t.scale *= size;
		}
		return t;
	}
	
	override void Tick() 
	{
		if (vel != (0,0,0))
		{
			SetOrigin(Vec3Offset(vel.x, vel.y, vel.z), true);
		}
		if (GetAge() > TICRATE * health)
		{
			Destroy();
		}
	}
	
	states 
	{
	Spawn:
		AMRK A -1;
		stop;
	}
}

class ToM_TestPowerup1 : Powerup
{
	Default
	{
		Powerup.Duration -15;
		Inventory.Icon "PTESA0";
	}
}

class ToM_TestPowerup2 : Powerup
{
	Default
	{
		Powerup.Duration -20;
		Inventory.Icon "PTESB0";
	}
}

class ToM_TestPowerup3 : Powerup
{
	Default
	{
		Powerup.Duration -30;
		Inventory.Icon "PTESC0";
	}
}

class ToM_TestPowerupGiver : PowerupGiver
{
	Default
	{		
		+BRIGHT
		+INVENTORY.AUTOACTIVATE
		+INVENTORY.ALWAYSPICKUP
	}
}

class ToM_TestPowerupGiver1 : ToM_TestPowerupGiver
{
	Default
	{
		Powerup.Type 'ToM_TestPowerup1';
		Inventory.Pickupmessage "Giving test powerup #1";
	}

	States {
	Spawn:
		PTES A -1;
		stop;
	}
}

class ToM_TestPowerupGiver2 : ToM_TestPowerupGiver
{
	Default
	{
		Powerup.Type 'ToM_TestPowerup2';
		Inventory.Pickupmessage "Giving test powerup #2";
	}

	States {
	Spawn:
		PTES B -1;
		stop;
	}
}

class ToM_TestPowerupGiver3 : ToM_TestPowerupGiver
{
	Default
	{
		Powerup.Type 'ToM_TestPowerup3';
		Inventory.Pickupmessage "Giving test powerup #3";
	}

	States {
	Spawn:
		PTES C -1;
		stop;
	}
}

class ToM_Prop_Shootable : Actor
{
	Default
	{
		+SOLID
		height 56;
		radius 16;
		+SHOOTABLE
		+NOBLOOD
		+BUDDHA
		+DONTTHRUST
	}

	States {
	Spawn:
		COLU A -1;
		stop;
	}
}

class ToM_Prop_Monster : ToM_Prop_Shootable
{
	Default
	{
		+ISMONSTER
		Translation "0:255=#[255,128,128]";
		-NOBLOOD
	}

	States {
	Spawn:
		POSS A -1;
		stop;
	}
}

class ToM_Prop_RocketTurret : ToM_Prop_Monster
{
	override void Tick()
	{
		Super.Tick();
		if (target)
		{
			A_FaceTarget();
		}
	}

	States {
	Spawn:
		POSS A 35 A_LookEx(LOF_NoSeeSound, label:"Missile");
		loop;
	Missile:
		POSS F 10 A_SpawnProjectile('Rocket');
		POSS E 60;
		TNT1 A 0 A_JumpIf(target == null, "Spawn");
		loop;
	}
}

class ToM_Prop_Rocket : Rocket
{
	Default
	{
		Translation "64:79=123:127", "128:151=112:123";
		DamageFunction (1);
	}

	States {
	Death:
		MISL B 8 Bright A_Explode(1, 128, 0, fulldamagedistance: 128);
		MISL C 6 Bright;
		MISL D 4 Bright;
		Stop;
	}
}

// The main utils class:
class ToM_VisualTrace play abstract
{

	// This fires a tracer and draws particles along its distance.
	// partDist - distance between particles
	// partTics - lifetime of particles
	static void FireVisualTracer(Actor originator, double dist, int flags = 0, double partDist = 1, int partTics = 1, color partColor = color("00FF00"))
	{
		if (!originator || dist <= 0)
			return;
		
		// By default the trace will originate
		// from the actor's center:
		double atkheight = originator.height * 0.5;
		
		// If the actor is a PlayerPawn, originate
		// the tracer from their attack height instead:
		let ppawn = PlayerPawn(originator);
		if (ppawn)
		{
			atkheight = ToM_VisualTrace.GetPlayerAtkHeight(ppawn);
		}
		
		// Do the trace:
		FLineTracedata tr;
		originator.LineTrace(originator.angle, dist, originator.pitch, flags, atkheight, data: tr);
		
		// Get start and end positions:
		vector3 startpos = level.Vec3Offset(originator.pos, (0,0, atkheight));
		vector3 endpos = tr.HitLocation;

		ToM_VisualTrace.DrawParticlesBetweenPoints(startpos, endpos, partDist, partTics, partColor);
	}

	// This draws a particle trail between two points.
	// partDist - distance between particles
	// partTics - lifetime of particles
	static void DrawParticlesBetweenPoints(vector3 startpos, vector3 endpos, double partDist = 1, int partTics = 1, color partColor = color("00FF00"), int flags = SPF_FULLBRIGHT|SPF_NOTIMEFREEZE)
	{
		// Get the vector between them and normalize it:
		let diff = Level.Vec3Diff(startpos, endpos);
		let dir = diff.Unit();
		let dist = diff.Length();
		
		// Make sure distance between particles is no less
		// than 1. From that, get how many particles
		// we'll need to spawn:
		partDist = Clamp(partDist, 1., dist);
		int partSteps = int(dist / partDist);
		
		// Spawn the particles:
		vector3 nextPos = startpos;
		FSpawnParticleParams traceParticle;
		traceParticle.color1 = partColor;
		traceParticle.lifetime = partTics;
		traceParticle.size = 2;
		traceParticle.StartAlpha = 1;
		traceParticle.fadeStep = -1;
		traceParticle.flags = flags;
		for (int i = 1; i <= partSteps; i++)
		{
			traceParticle.pos = nextPos;
			Level.Spawnparticle(traceParticle);
			nextPos += dir * partDist;
		}
	}
	
	// This gets the exact attack height of the given PlayerPawn:
	static double GetPlayerAtkHeight(PlayerPawn ppawn)
	{
		if (!ppawn)
			return 0;
		let player = ppawn.player;
		if (!player)
			return 0;
		return ppawn.height * 0.5 - ppawn.floorclip + ppawn.AttackZOffset*player.crouchFactor;
	}
}