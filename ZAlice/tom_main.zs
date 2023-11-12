mixin class ToM_PlayerSightCheck 
{
	protected bool canSeePlayer;
	//a simple check that returns true if the actor is in any player's LOS:
	bool CheckPlayerSights() 
	{
		for ( int i=0; i<MAXPLAYERS; i++ ) 	
		{
			if ( playeringame[i] && players[i].mo && CheckSight(players[i].mo) )
				return true;
		}
		return false;
	}
}

mixin class ToM_CheckParticles
{
	protected transient CVar s_particles;
	
	int GetParticlesQuality()
	{
		if (!s_particles)
			s_particles = CVar.GetCVar('tom_particles', players[consoleplayer]);
		
		return s_particles.GetInt();
	}
}

class ToM_NullActor : Actor 
{
	Default 
	{
		+NOINTERACTION
		+NOBLOCKMAP
		+SYNCHRONIZED
		+DONTBLAST
		radius 0;
		height 0;
		FloatBobPhase 0;
	}
	override void PostBeginPlay() 
	{
		Destroy();
	}
}

//A class that returns the name of a key bound to a specific action (thanks to 3saster):
class ToM_Keybinds 
{
	static string getKeyboard(string keybind) 
	{
		Array<int> keyInts;
		Bindings.GetAllKeysForCommand(keyInts, keybind);
		if (keyInts.Size() == 0)
			return Stringtable.Localize("$PKC_NOTBOUND");
		return Bindings.NameAllKeys(keyInts);
	}
}

Class ToM_BaseActor : Actor abstract 
{
	protected double pi;
	protected name bcolor;
	protected int age;
	mixin ToM_PlayerSightCheck;
	mixin ToM_CheckParticles;

	static const name whiteSmokeTextures[] = 
	{
		"SMO2A0",
		"SMO2B0",
		"SMO2C0",
		"SMO2D0",
		"SMO2E0",
		"SMO2F0"
	};

	static const name blackSmokeTextures[] =
	{
		"SMOKC0",
		"SMOKE0",
		"SMOKG0",
		"SMOKI0",
		"SMOKK0",
		"SMOKM0",
		"SMOKO0",
		"SMOKQ0"
	};

	static string GetRandomWhiteSmoke() 
	{
		return ToM_BaseActor.whiteSmokeTextures[random[smksfx](0, ToM_BaseActor.whiteSmokeTextures.Size() -1)];
	}

	static string GetRandomBlackSmoke()
	{
		return ToM_BaseActor.blackSmokeTextures[random[smksfx](0, ToM_BaseActor.BlackSmokeTextures.Size() -1)];
	}

	bool CheckLandingSize (double cradius = 0, bool checkceiling = false) 
	{
		if (checkceiling) 
		{
			double ceilingHeight = GetZAt (flags: GZF_CEILING);
			for (int i = 0; i < 360; i += 45) 
			{
				double curHeight = GetZAt (cradius, 0, i, GZF_ABSOLUTEANG | GZF_CEILING);
				if (curHeight > ceilingz)
					return true;
			}
		}
		else 
		{
			double floorHeight = GetZAt ();
			for (int i = 0; i < 360; i += 45) 
			{
				double curHeight = GetZAt (cradius, 0, i, GZF_ABSOLUTEANG);
				if (curHeight < floorz)
					return true;
			}
		}
		return false;
	}
	
	bool CheckClippingLines(double size)
	{
		BlockLinesIterator it = BlockLinesIterator.Create(self, size);
		double tbox[4];
		// top, bottom, left, right
		tbox[0] = pos.y+size;
		tbox[1] = pos.y-size;
		tbox[2] = pos.x-size;
		tbox[3] = pos.x+size;
		while (it.Next()) 
		{
			let l = it.CurLine;
			if ( !l ) continue;
			if ( tbox[2] > l.bbox[3] ) continue;
			if ( tbox[3] < l.bbox[2] ) continue;
			if ( tbox[0] < l.bbox[1] ) continue;
			if ( tbox[1] > l.bbox[0] ) continue;
			if (ToM_UtilsP.BoxOnLineSide(tbox[0],tbox[1],tbox[2],tbox[3],l) == -1 ) 
				return true;
		}
		return false;
	}
	
	static const string ToM_LiquidFlats[] = 
	{ 
		"BLOOD", "LAVA", "NUKAGE", "SLIME01", "SLIME02", "SLIME03", "SLIME04", "SLIME05", "SLIME06", "SLIME07", "SLIME08", "BDT_"
	};
	
	bool CheckLiquidFlat() 
	{
		if (!self)
			return false;

		if (GetFloorTerrain().isLiquid == true)
			return true;
			
		string tex = TexMan.GetName(floorpic);
		for (int i = 0; i < ToM_LiquidFlats.Size(); i++) 
		{
			if (tex.IndexOf(ToM_LiquidFlats[i]) >= 0 )
				return true;
		}
		return false;
	}
	
	override void Tick() 
	{
		super.Tick();
		if (!isFrozen())
			age++;
	}
	
	States 
	{
	Loadsprites:
		LENR A 0;
		LENB A 0;
		LENG A 0;
		LENY A 0;
		LENC A 0;
		LENS AB 0;
		SPRK ABC 0;
		SMO2 ABCDEF 0;
		stop;
	}
}

Class ToM_BaseDebris : ToM_BaseActor abstract 
{
	protected bool landed;			//true if object landed on the floor (or ceiling, if can stick to ceiling)
	protected bool moving; 		//marks actor as moving; sets to true automatically if actor spawns with non-zero vel
	Default 
	{
		+ROLLSPRITE
		+FORCEXYBILLBOARD
		+INTERPOLATEANGLES
		-ALLOWPARTICLES
		+SYNCHRONIZED
		+DONTBLAST
		FloatBobPhase 0;
		renderstyle 'Translucent';
		alpha 1.0;
		radius 1;
		height 1;
		mass 1;
	}
	// thanks Gutawer for explaning the math and helping this function come to life
	virtual void FlyBack() 
	{
		if (!target)
			return;
		SetZ(pos.z+5);
		moving = true;
		landed = false;
		bFLATSPRITE = false;
		bTHRUACTORS = true;
		bNOGRAVITY = false;
		gravity = 1.0;
		A_FaceTarget();
		
		double dist = Distance2D(target);							//horizontal distance to target
		double vdisp = target.pos.z - pos.z + frandom[sfx](8,32);		//height difference between gib and target + randomized height
		double ftime = 20;											//time of flight
		
		double vvel = (vdisp + 0.5 * ftime*ftime) / ftime;
		double hvel = dist / ftime;
		
		VelFromAngle(hvel,angle);
		vel.z = vvel;
	}
	override void PostBeginPlay() 
	{
		if (!level.IsPointInLevel(pos)) 
		{
			Destroy();
			return;
		}
		super.PostBeginPlay();
	}
}
	
Class ToM_SmallDebris : ToM_BaseDebris abstract 
{
	protected bool onceiling;		//true if object is stuck on ceiling (must be combined with landed)
	protected bool onliquid;
	protected int bounces;
	protected double Voffset;		//small randomized plane offset to reduce z-fighting for blood pools and such
	double wrot; //gets added to roll to imitate rotation during flying
	double dbrake; //how quickly to reduce horizontal speed of "landed" particles to simulate sliding along the floor
	double dscale;
	property dbrake : dbrake;	
	protected bool removeonfall;	//if true, object is removed when reaching the floor
	property removeonfall : removeonfall;
	protected bool removeonliquid;
	property removeonliquid : removeonliquid;
	protected double liquidheight;
	property liquidheight : liquidheight;
	protected bool hitceiling;		//if true, react to reaching the ceiling (otherwise ignore)
	property hitceiling : hitceiling;
	
	protected vector2 wallnormal;
	protected vector3 wallpos;
	protected line wall;
	
	protected state d_spawn;
	protected state d_death;
	protected state d_ceiling;
	protected state d_wall;
	protected state d_liquid;
	
	protected sound liquidsound;
	property liquidsound : liquidsound;
	
	Default 
	{
		gravity 0.8;
		ToM_SmallDebris.liquidsound "";
		ToM_SmallDebris.removeonfall false;
		ToM_SmallDebris.removeonliquid true;
		ToM_SmallDebris.dbrake 0;
		ToM_SmallDebris.hitceiling false;
		bouncecount 8;
		+MOVEWITHSECTOR
		+NOBLOCKMAP
	}
	
	override void BeginPlay() 
	{
		super.BeginPlay();		
		ChangeStatnum(110);
	}
	//a cheaper version of SetOrigin that also doesn't update floorz/ceilingz (because they're updated manually in Tick) - thanks phantombeta
	void ToM_SetOrigin (Vector3 newPos) 
	{
		LinkContext ctx;
		UnlinkFromWorld (ctx);
		SetXYZ (newPos);
		LinkToWorld (ctx);
	}
	override void PostBeginPlay() 
	{
		super.PostBeginPlay();
		if (vel.length() != 0 || gravity != 0) //mark as movable if given any non-zero velocity or gravity
			moving = true;
		d_spawn = FindState("Spawn");
		d_death = FindState("Death");
		d_ceiling = FindState("HitCeiling");
		d_wall = FindState("HitWall");
		d_liquid = FindState("DeathLiquid");
	}
	//a chad tick override that skips Actor.Tick()
	override void Tick() 
	{		
		if (alpha < 0)
		{
			Destroy();
			return;
		}
		if (isFrozen())
			return;
		//animation:
		if (tics != -1) 
		{
			if (tics > 0) 
				tics--;
			while (!tics) 
			{
				if (!SetState (CurState.NextState)) // mobj was removed
					return;
			}
		}
		/*
		Perform collision for the objects that don't have NOINTERACTION and are older than 1 tic.
		The latter helps to avoid collision at the moment of spawning.
		*/
		if (!bNOINTERACTION && GetAge() > 1) 
		{
			UpdateWaterLevel(); //manually update waterlevel
			FindFloorCeiling(); //manually update floorz/ceilingz
			if (d_spawn && InStateSequence(curstate,d_spawn)) 
			{
				//check if hit ceiling: (if hitceiling is true)
				if (hitceiling && pos.z >= ceilingz - 10 && vel.z > 0) 
				{
					ToM_Hitceiling();
					if (!self)
						return;
				}
				//check if hit wall:
				else if (pos.z > floorz+Voffset) 
				{
					A_FaceMovementDirection(flags:FMDF_NOPITCH);
					FLineTraceData hit;
					LineTrace(angle,radius+16,1,flags:TRF_THRUACTORS|TRF_NOSKY,data:hit);
					if (hit.HitLine && hit.hittype == TRACE_HITWALL) 
					{
						wall = hit.HitLine;
						wallnormal = (-hit.HitLine.delta.y,hit.HitLine.delta.x).unit();
						wallpos = hit.HitLocation;
						if (!hit.LineSide)
							wallnormal *= -1;
						//if the actor can bounce off walls and isn't too close to the floor, it'll bounce:
						if (bBOUNCEONWALLS){		
							if (wallbouncesound)
								A_StartSound(wallbouncesound);
							else if (bouncesound)
								A_StartSound(bouncesound);								
							wrot *= -1;
							vel = vel - (wallnormal,0) * 2 * (vel dot (wallnormal,0));
							if (wallbouncefactor)
								vel *= wallbouncefactor;
							else
								vel *= bouncefactor;
							A_FaceMovementDirection();
						}
						//otherwise stop and call hitwall
						else if (vel.x != 0 || vel.y != 0) 
						{
							SetOrigin(wallpos + wallnormal * radius,true);
							A_Stop();
							//console.printf("%s sticking to wall at %d:%d:%d",GetClassName(),pos.x,pos.y,pos.z);
							ToM_HitWall();
						}
					}
					if (!self)
						return;
				}
			}
			//stick to surface if already landed:
			if (landed) 
			{
				//stick to ceiling if on ceiling
				if (onceiling)
					SetZ(ceilingz-Voffset);
				//otherwise stick to floor (and, if necessary, slide on it)
				else 
				{
					double i = floorz+Voffset;
					if (pos.z > i)
						landed = false;
					else 
					{
						SetZ(i);
						//do the slide if friction allows it (as defined by dbrake property)
						if (dbrake > 0) 
						{
							if (!(vel.x ~== 0) || !(vel.y ~== 0)) 
							{
								vel.xy *= dbrake;
								A_FaceMovementDirection(flags:FMDF_NOPITCH);
								FLineTraceData hit;
								LineTrace(angle,12,0,flags:TRF_THRUACTORS|TRF_NOSKY,offsetz:1,data:hit);
								if (hit.HitLine && hit.hittype == TRACE_HITWALL /*&& (!hit.HitLine || hit.HitLine.flags & hit.Hitline.ML_BLOCKING || hit.LinePart == Side.Bottom)*/) 
								{
									//console.printf("%s hit wall at %d:%d:%f | pitch: %f",GetClassName(),hit.HitLocation.x,hit.HitLocation.y,hit.HitLocation.z,pitch);
									wallnormal = (-hit.HitLine.delta.y,hit.HitLine.delta.x).unit();
									wallpos = hit.HitLocation;
									if (!hit.LineSide)
										wallnormal *= -1;
									vel = vel - (wallnormal,0) * 2 * (vel dot (wallnormal,0));
									vel *= bouncefactor * 0.5;
									A_FaceMovementDirection(flags:FMDF_NOPITCH);
								}
							}
						}
						else
							vel.xy = (0,0);
					}
				}
			}
			//simulate falling if not yet landed:
			else 
			{
				if (pos.z <= floorz+Voffset) 
				{
					bool liquid = CheckLiquidFlat();
					if (bounces >= bouncecount || !bBOUNCEONFLOORS || liquid || abs(vel.z) <= 2) 
					{
						if (liquid)
							onliquid = true;
						ToM_HitFloor();	
					}
					else 
					{
						SetZ(floorz+Voffset);
						vel.z *= -bouncefactor;
						bounces++;
						if (bouncesound)
							A_StartSound(bouncesound);
					}
					if (!self)
						return;
				}
				else if (!bNOGRAVITY) 
					vel.z -= gravity;
			}
		}
		//finally, manually move the object:
		if (moving) 
		{
			//this cheaper version won't automatically update floorz/ceilingz, which is good for objects like smoke that don't interact with geometry
			ToM_SetOrigin(level.vec3offset(pos, vel));
		}
	}
	virtual void ToM_HitFloor() {			//hit floor if close enough
		if (removeonfall) 
		{
			Destroy();
			return;
		}
		if (floorpic == skyflatnum) { 
			Destroy();
			return;
		}
		landed = true;
		vel.z = 0;
		if (Voffset < 0)
			Voffset = 0;
		//landed on liquid:
		if (onliquid) 
		{
			A_Stop();
			A_StartSound(liquidsound,slot:CHAN_AUTO,flags:CHANF_DEFAULT,1.0,attenuation:3);
			if (removeonliquid) 
			{
				Destroy();
				return;
			}
			
			// If it's a flat (non-3d-floor) liquid, we'll visually
			// sink the object into it a bit either by 50% of its 
			// height or by the value of its liquidheight property:
			floorclip = (liquidheight == 0) ? (height * 0.5) : liquidheight;
			
			// Enter "DeathLiquid" state if present, otherwise enter "Death":
			if (d_liquid)
				SetState(d_liquid);
			else if (d_death)
				SetState(d_death);
		}
		//otherwise enter "Death" state if present
		else if (d_death)
			SetState(d_death);
		SetZ(floorz+Voffset);
	}
	//stick to ceiling and enter "HitCeiling" state if present:
	virtual void ToM_Hitceiling() 
	{
		if (ceilingpic == skyflatnum) 
		{
			Destroy();
			return;
		}
		SetZ(ceilingz-Voffset);
		if (d_ceiling)
			SetState(d_ceiling);
	}
	//enter "HitWall" state if present:
	virtual void ToM_HitWall() 
	{
		if (d_wall)
			SetState(d_wall);	
	}
	states 
	{
	Spawn:
		#### # -1;
		stop;
	}
}

// This creates a visual colored layer on top of
// an actor by spawning a non-intereactive actor
// that copies the origina actor's appearance
// and position. With default sprite snorting
// this actor will be placed on top of the
// original one, and with renderstyles, color
// and alpha applied, it creates a "layer."
class ToM_ActorLayer : ToM_SmallDebris abstract
{
	double fade;
	property fade : fade;

	Default
	{
		+NOINTERACTION
		+NOSPRITESHADOW
		ToM_ActorLayer.fade 0.1;
		Renderstyle 'Translucent';
		Alpha 1.0;
	}
	
	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		if (!master)
		{
			Destroy();
		}
	}
	
	override void Tick()
	{
		if (!master)
		{
			Destroy();
			return;
		}
		if (!master.isFrozen())
		{
			SetOrigin(master.pos, true);
			ToM_UtilsP.CopyAppearance(self, master, style: false, size: true);
			//console.printf("%s layer alpha: %.2f", master.GetTag(), alpha);
			if (fade > 0)
			{
				alpha -= fade;
				if (alpha <= 0.0)
					Destroy();
			}
		}
	}
}

Class ToM_RicochetSpark : ToM_SmallDebris 
{
	Default 
	{
		ToM_SmallDebris.dbrake 0.8;
		alpha 1.5;
		radius 3;
		height 3;
		scale 0.035;
		+BRIGHT
	}
	override Void PostBeginPlay() 
	{
		if (waterlevel > 1) 
		{
			Destroy();
			return;
		}
		super.PostbeginPlay();
	}
	states 
	{
	Spawn:
		SPRK # 1 
		{
			A_FadeOut(0.03);
			scale *= 0.95;
		}
		loop;
	}
}

Class ToM_RandomDebris : ToM_SmallDebris 
{
	name spritename;
	double rotstep;
	property rotation : wrot;
	property spritename : spritename;
	bool randomroll;
	property randomroll : randomroll;
	Default 
	{
		ToM_RandomDebris.spritename 'PDEB';
		ToM_SmallDebris.removeonliquid true;
		ToM_SmallDebris.dbrake 0.8;
		ToM_RandomDebris.rotation 17;
		ToM_RandomDebris.randomroll true;
		+BOUNCEONWALLS
		+ROLLCENTER
		wallbouncefactor 0.5;
		height 8;
		stencilcolor "101010";
		scale 0.2;
	}
	override void PostBeginPlay() 
	{
		super.PostBeginPlay();		
		if (randomroll)
			roll = random[sfx](0,359);
		wrot = (wrot * frandom[sfx](0.8,1.2))*randompick[sfx](-1,1);
		scale *= frandom[sfx](0.75,1.2);
		bSPRITEFLIP = randompick[sfx](0,1);
		sprite = GetSpriteIndex(spritename);
		if (spritename == 'PDEB')
			frame = random[sfx](0,5);
	}
	states 
	{
	spawn:
		#### # 1 {			
			roll+=wrot;
			wrot *= 0.99;
		}
		loop;
	Death:
		#### # 0 { 
			roll = 180 * randompick[sfx](-1,1) + frandom[sfx](-3,3);
		}
		#### # 1 
		{
			A_FadeOut(0.03);
			scale *= 0.95;
		}
		wait;
	cache:
		PDEB ABCDEF 0;
		PFLD ABCDEF 0;
	}
}

//Debris that spawn white smoke:
Class ToM_SmokingDebris : ToM_RandomDebris 
{	
	Default 
	{
		scale 0.5;
		gravity 0.25;
	}
	override void Tick () 
	{
		super.Tick();	
		if (isFrozen())
			return;
		TextureID smoketex = TexMan.CheckForTexture(ToM_BaseActor.GetRandomWhiteSmoke());
		FSpawnParticleParams smoke;
		smoke.texture = smoketex;
		smoke.color1 = "";
		smoke.flags = SPF_ROLL|SPF_REPLACE;
		smoke.lifetime = 34;
		smoke.size = TexMan.GetSize(smoketex) * 0.11;
		smoke.sizestep = smoke.size * 0.03;
		smoke.startalpha = alpha * 0.4;
		smoke.fadestep = 0.01;
		smoke.vel = (frandom[smk](-1,1),frandom[smk](-1,1),frandom[smk](-1,1));
		smoke.pos = pos+(frandom[smk](-4,4),frandom[smk](-4,4),frandom[smk](-4,4));
		smoke.startroll = random[sfx](0, 359);
		smoke.rollvel = frandom[sfx](0.5,1) * randompick[sfx](-1,1);
		Level.SpawnParticle(smoke);
		A_FadeOut(0.03);
	}
}

//Flame spawned by burning debris:
Class ToM_DebrisFlame : ToM_BaseFlare 
{
	Default 
	{
		scale 0.05;
		renderstyle 'translucent';
		alpha 1;
	}
	override void PostBeginPlay() 
	{
		super.PostBeginPlay();
		roll = random[sfx](0,359);
		wrot = frandom[sfx](5,10)+randompick[sfx](-1,1);
	}
	states 
	{
	Spawn:
		TNT1 A 0 NoDelay A_Jump(256,1,3); //randomize appearance a bit:
		BOM4 IJKLMNOPQ 1 {
			A_FadeOut(0.05);
			roll += wrot;
			scale *= 1.1;
		}
		wait;
	}
}

Class ToM_ExplosiveDebris : ToM_RandomDebris 
{
	static const name flameTextures[] = { "BOM4I0", "BOM4J0", "BOM4K0", "BOM4L0" };

	Default 
	{
		scale 0.5;
		gravity 0.3;
	}

	override void Tick ()
	{
		if (isFrozen())
			return;

		Vector3 oldPos = self.pos;
		Super.Tick();
		
		TextureID smoketex = TexMan.CheckForTexture(ToM_BaseActor.GetRandomBlackSmoke());
		FSpawnParticleParams smoke;
		smoke.texture = smoketex;
		smoke.color1 = "";
		smoke.flags = SPF_ROLL|SPF_REPLACE;
		smoke.lifetime = 34;
		smoke.size = TexMan.GetSize(smoketex) * 0.25;
		smoke.sizestep = -1.4;
		smoke.startalpha = alpha * 0.3;
		smoke.fadestep = -1;
		smoke.vel = (frandom[smk](-1,1),frandom[smk](-1,1),frandom[smk](-1,1));
		smoke.pos = pos+(frandom[smk](-9,9),frandom[smk](-9,9),frandom[smk](-9,9));
		smoke.startroll = frandom[sfx](-40,40);
		smoke.rollvel = frandom[sfx](0.5,1) * randompick[sfx](-1,1);
		Level.SpawnParticle(smoke);

		Vector3 path = level.vec3Diff(self.pos, oldPos);
		double distance = path.length() / 4;
		Vector3 direction = path / distance;
		int steps = int( distance );
		for(int i = 0; i < steps; i++)
		{
			TextureID flametex = TexMan.CheckForTexture(flameTextures[random[sfx](0, flameTextures.Size() - 1)]);
			FSpawnParticleParams flame;
			flame.texture = flametex;
			flame.color1 = "";
			flame.style - STYLE_Add;
			flame.flags = SPF_ROLL|SPF_REPLACE|SPF_FULLBRIGHT;
			flame.lifetime = 40;
			flame.pos = oldpos;
			flame.size = TexMan.GetSize(flametex) * 0.1;
			flame.sizestep = flame.size * 0.05;
			flame.startalpha = alpha * 0.3;
			flame.fadestep = -1;
			flame.startroll = frandom[sfx](0,360);
			flame.rollvel = frandom[sfx](5,10)+randompick[sfx](-1,1);
			Level.SpawnParticle(flame);

			oldPos = level.vec3Offset( oldPos, direction );
		}
		A_FadeOut(0.022);
	}
}

class ToM_SphereFX : ToM_SmallDebris
{
	double grow;
	protected int growsteps;
	protected double size;
	double fade;

	Default
	{
		+NOINTERACTION
		Renderstyle 'Stencil';
		scale 64;
	}
	
	static ToM_SphereFX SpawnExplosion(vector3 pos, double size = 48, double alpha = 0.6, double grow = 1.15, double fade = 0.05, color col1 = color("FFFF00"), color col2 = color("fcb126"), double boomfactor = 3.)
	{
		let sphere1 = ToM_SphereFX(ToM_SphereFX.Spawn(pos, size, alpha, grow, fade, col1));
		if (sphere1)
			sphere1.bBRIGHT = true;
		
		let sphere2 = ToM_SphereFX(ToM_SphereFX.Spawn(pos, size / boomfactor, alpha, grow, fade, col2));
		if (sphere2)
			sphere2.bBRIGHT = true;
		
		return sphere1;
	}
	
	static ToM_SphereFX Spawn(vector3 pos, double size = 1, double alpha = 1, double grow = 0, double fade = 0, color col = 0)
	{
		let sphere = ToM_SphereFX(Actor.Spawn("ToM_SphereFX", pos));
		if (!sphere)
			return null;
		
		sphere.size = size;
		sphere.A_SetScale(size);
		sphere.alpha = alpha;
		sphere.grow = grow;
		sphere.fade = fade;
		if (col)
			sphere.SetShade(col);
		return sphere;
	}
	
	override void Tick()
	{
		super.Tick();
		if (isFrozen())
			return;
		
		if (grow > 0)
		{
			scale *= grow;
		}
		if (fade > 0)
			A_FadeOut(fade);
	}
	
	States 
	{
	Spawn:
		M000 A -1;
		stop;
	}
}

Class ToM_BaseFlare : ToM_SmallDebris 
{
	protected state mdeath;
	protected state mxdeath;
	protected state mcrash;
	color fcolor;
	property fcolor : fcolor;
	bool style;
	property style : style;
	double fscale;		//scale; used when it's set externally from the spawner
	double falpha;		//alpha; used when it's set externally from the spawner
	double fade;
	property fadefactor : fade;
	double shrink;
	property shrinkfactor : shrink;
	
	Default 
	{
		+BRIGHT
		+NOINTERACTION
		renderstyle 'AddShaded';
		alpha 0.4;
		scale 0.4;
		gravity 0;
	}
	
	static ToM_BaseFlare Spawn(vector3 pos, double scale = 0.4, double alpha = 0.5, double fade = 0, double shrink = 0, color col = color("FF0000"))
	{
		let flare = ToM_BaseFlare(Actor.Spawn("ToM_BaseFlare", pos));
		if (flare)
		{
			flare.falpha = alpha;
			flare.fscale = scale;
			flare.fade = fade;
			flare.shrink = shrink;
			flare.fcolor = col;
		}
		return flare;
	}
	
	override void PostBeginPlay() 
	{
		super.PostBeginPlay();
		if (master) 
		{
			mdeath = master.FindState("Death");
			mxdeath = master.FindState("XDeath");
			mcrash = master.FindState("Crash");
		}
		SetColor();
	}
	
	virtual void SetColor()
	{ //fcolor is meant to be set by the actor that spawns the flare
		if (GetRenderstyle() == Style_AddShaded || GetRenderstyle() == Style_Shaded) 
		{
			if (!fcolor) 
			{
				Destroy();
				return;
			}				
			else 
			{
				SetShade(fcolor);
			}
		}
		if (fscale != 0)
			A_SetScale(fscale);
		if (falpha != 0)
			alpha = falpha;
	}
	
	states 
	{
	Spawn:
		LENG A 1 
		{
			if (fade != 0)
				A_FadeOut(fade);
			if (shrink != 0) 
			{
				scale *= shrink;
			}
		}
		loop;
	}
}

Class ToM_ProjFlare : ToM_BaseFlare 
{
	double xoffset;
	double scaleDiff;

	Default 
	{
		ToM_BaseFlare.fcolor "FF0000";
		alpha 0.8;
		scale 0.11;		
	}

	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		if (!master)
		{
			Destroy();
			return;
		}
		scalediff = scale.x / max(master.scale.x, master.scale.y);
	}

	override void Tick() 
	{
		super.Tick();
		if (!master) 
		{
			Destroy();
			return;
		}	

		if (isFrozen())
			return;

		// sprite clipping:
		bMissile = master.bMissile; 		
		bCorpse = master.bCorpse;
		bSpecialFloorclip = master.bSpecialFloorclip;

		scale = master.scale * scalediff;

		Warp(master,xoffset,0,0,flags:WARPF_INTERPOLATE);
		
		if (master.InstateSequence(master.curstate, mdeath) || master.InstateSequence(master.curstate, mxdeath) || master.InstateSequence(master.curstate, mcrash)) 
		{
			Destroy();
			return;
		}
	}
}

Class ToM_BaseSmoke : ToM_SmallDebris abstract 
{
	double fade;
	Default 
	{
		+NOINTERACTION
		+ROLLCENTER
		gravity 0;
		renderstyle 'Translucent';
		alpha 0.3;
		scale 0.1;
	}
	
	override void PostBeginPlay() 
	{
		super.PostBeginPlay();
		if (waterlevel > 1) 
		{
			self.Destroy();
			return;
		}
		scale.x *= frandom[sfx](0.8,1.2);
		scale.y *= frandom[sfx](0.8,1.2);
		bSPRITEFLIP = randompick[sfx](0,1);
		roll = random[sfx](0,359);
	}
	
	states	
	{
	Spawn:
		#### # 1 
		{
			A_Fadeout(0.01);
		}
		loop;
	}
}

//medium-sized dark smoke that raises over burnt bodies
class ToM_BlackSmoke : ToM_BaseSmoke 
{
	Default 
	{
		alpha 0.3;
		scale 0.3;
	}
	override void Tick() 
	{
		if (isFrozen())
			return;
		vel *= 0.99;
		super.Tick();
	}
	override void PostBeginPlay() 
	{
		super.PostBeginPlay();
		roll += frandom[sfx](-40,40);
	}
	states	
	{
	Spawn:
		SMOK ABCDEFGHIJKLMNOPQ 2 NoDelay 
		{
			A_FadeOut(0.01);
		}
		SMOK R 2 
		{
			A_FadeOut(0.005);
			scale *= 0.99;
		}
		wait;
	}
}

class ToM_WhiteSmoke : ToM_BaseSmoke 
{
	int fadedelay;

	Default 
	{
		scale 0.1;
		renderstyle 'Translucent';
		alpha 0.5;
	}
	
	static Actor Spawn(vector3 pos, double ofs = 0, vector3 vel = (0,0,0), double scale = 0.1, double rotation = 4, double alpha = 0.5, double fade = 0.01, double dbrake = 0.98, double dscale = 1.04, int fadedelay = 25, int style = STYLE_Translucent, color shade = -1, bool bright = false, bool particle = true)
	{
		if (particle)
		{
			TextureID smoketex = TexMan.CheckForTexture(ToM_BaseActor.GetRandomWhiteSmoke());
			FSpawnParticleParams smoke;
			smoke.texture = smoketex;
			smoke.color1 = "";
			smoke.style = style;
			if (style == STYLE_Shaded || style == STYLE_AddShaded)
			{
				smoke.color1 = shade;
			}
			else
			{
				smoke.color1 = "";
			}
			smoke.lifetime = ceil(alpha / fade) + fadedelay;
			smoke.flags = SPF_ROLL|SPF_REPLACE;
			if (bright)
				smoke.flags |= SPF_FULLBRIGHT;
			smoke.size = TexMan.GetSize(smoketex) * scale * frandom[sfx](0.9,1.1);
			smoke.sizestep = smoke.size * (dscale - 1.0) * 0.75;
			smoke.startalpha = alpha;
			smoke.fadestep = -1;
			smoke.pos = pos+(frandom[smk](-ofs,ofs), frandom[wsmk](-ofs,ofs), frandom[wsmk](-ofs,ofs));
			smoke.vel = vel;
			smoke.accel = -(vel / smoke.lifetime);
			smoke.startroll = random[sfx](0, 359);
			smoke.rollvel = rotation * frandom[sfx](-1,1);
			smoke.rollacc = -(smoke.rollvel / smoke.lifetime);
			Level.SpawnParticle(smoke);
			return null;
		}

		let smk = ToM_WhiteSmoke(
			Actor.Spawn(
				'ToM_WhiteSmoke', 
				pos + (frandom[wsmk](-ofs,ofs), frandom[wsmk](-ofs,ofs), frandom[wsmk](-ofs,ofs))
			)
		);
		if (smk)
		{
			smk.vel = vel;
			smk.A_SetScale(scale);
			smk.wrot = rotation;
			smk.alpha = alpha;
			smk.fade = fade;
			smk.dbrake = dbrake;
			smk.dscale = dscale;
			smk.fadedelay = fadedelay;
		}
		return smk;
	}
	
	override void PostBeginPlay() 
	{
		super.PostBeginPlay();
		scale *= frandom[sfx](0.9,1.1);
		wrot *= (frandom[sfx](0.8, 1.2) * randompick[sfx](-1,1));
		if (fade <= 0)
			fade = 0.01;
		if (fadedelay <= 0)
			fadedelay = 25;
	}	
	
	override void Tick()
	{
		super.Tick();
		if (isFrozen())
			return;
		
		if (abs(wrot) > 0.12)
		{
			wrot *= 0.96;
		}
		roll += wrot;
		scale *= dscale;
		vel *= dbrake;
		
		if (GetAge() >= fadedelay)
		{
			dbrake *= 0.96;
			dscale = Clamp(dscale *= 0.98, 1, 100);
			A_FadeOut(fade);
		}
	}
	
	states 
	{
	Spawn:
		SMO2 # -1 NoDelay 
		{
			frame = random[sfx](0,5);
		}
		stop;
	}
}

/*
class ToM_WhiteDeathSmoke : ToM_BaseSmoke 
{
	Default 
	{
		alpha 0.5;
		scale 0.1;
		renderstyle 'add';
	}
	states	
	{
	Spawn:		
		SMOK ABCDEFGHIJKLMNOPQR 1 
		{
			A_FadeOut(0.05);
			scale *= 1.05;
		}
		stop;
	}
}*/

Class ToM_DebugSpot : Actor 
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
		translation "1:255=%[0.00,1.01,0.00]:[1.02,2.00,0.00]";
	}
	
	override void Tick() 
	{
		if (GetAge() > 35 * health)
			Destroy();
	}
	
	states 
	{
	Spawn:
		AMRK A -1;
		stop;
	}
}