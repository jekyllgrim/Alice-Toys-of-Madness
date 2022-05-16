Mixin class ToM_Math 
{		
	int Sign (double i) 
	{
		return (i >= 0) ? 1 : -1;
	}
	
	clearscope double LinearMap(double val, double o_min, double o_max, double n_min, double n_max) 
	{
		return (val - o_min) * (n_max - n_min) / (o_max - o_min) + n_min;
	}
	
	//Utility functions by Marisa Kirisame
	
	//Checks which side of a lindef the actor is on:
	clearscope int PointOnLineSide( Vector2 p, Line l ) 
	{
		if ( !l ) return 0;
		return (((p.y-l.v1.p.y)*l.delta.x+(l.v1.p.x-p.x)*l.delta.y) > double.epsilon);	
	}
	
	//Returns -1 if the box (normally an actor's radius) intersects a linedef:
    int BoxOnLineSide( double top, double bottom, double left, double right, Line l ) 
{
		if ( !l ) return 0;
		int p1, p2;
		if ( l.delta.x == 0 ) 
		{
			// ST_VERTICAL:
			p1 = (right < l.v1.p.x);
			p2 = (left < l.v1.p.x);
			if ( l.delta.y < 0 ) 
			{
				p1 ^= 1;
				p2 ^= 1;
			}
		}
		else if ( l.delta.y == 0 )	
		{
			// ST_HORIZONTAL:
			p1 = (top > l.v1.p.y);
			p2 = (bottom > l.v1.p.y);
			if ( l.delta.x < 0 )		
			{
				p1 ^= 1;
				p2 ^= 1;
			}
		}
		else if ( (l.delta.x*l.delta.y) >= 0 )	
		{
			// ST_POSITIVE:
			p1 = PointOnLineSide((left,top),l);
			p2 = PointOnLineSide((right,bottom),l);
		}
		else 
		{
			// ST_NEGATIVE:
			p1 = PointOnLineSide((right,top),l);
			p2 = PointOnLineSide((left,bottom),l);
		}
		return (p1==p2)?p1:-1;
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
		    if (BoxOnLineSide(tbox[0],tbox[1],tbox[2],tbox[3],l) == -1 ) 
				return true;
		}
		return false;
    }
	
	//Find a random position within the specified spot in a grid of the specified size:
	vector3 FindRandomPosAround(vector3 actorpos, double gridrad = 128, double step = 16) 
	{
		if (!level.IsPointInLevel(actorpos))
			return actorpos;
		//because zscript doesn't support vector3 arrays I have to do this
		//UGH
		array <double> tposX;
		array <double> tposY;
		array <double> tposZ;
		//establish grid corners (top left and bottom right)
		vector3 startpos = actorpos - (gridrad, gridrad, 0);
		vector3 endpos = actorpos + (gridrad, gridrad, 0);
		//get sector of the actorpos:
		Sector actorsector = Level.PointInSector(actorpos.xy);
		//start at top left:
		vector3 curpos = startpos;
		while (true) 
		{
			//save the coordinates if they're not in void and within this sector:
			if (Level.IsPointInLevel(curpos) && Level.PointInSector(curpos.xy) == actorsector) 
			{
				//let itr = BlockLinesIterator.Create(self,
				tposX.Push(curpos.x);
				tposY.Push(curpos.y);
				tposZ.Push(curpos.z);
			}
			//move one step horizontally:
			curpos.x += step;
			//if we're too far, reset horizontal and move one step down:
			if (curpos.x > endpos.x) 
			{
				curpos.x = startpos.x;
				curpos.y += step;
			}
			//if we're too far down too, stop iterating:
			if (curpos.y > endpos.y)
				break;
		}
		//in case array sizes are not equal for some reason:
		int foo = min(tposX.Size(), tposY.Size(), tposZ.Size()) - 1;
		//return a random position:
		int i = random[findpos](0,foo);
		vector3 finalpos = (tposX[i], tposY[i], tposZ[i]);
		return finalpos;
	}	
	
	void CopyAppearance(Actor to, Actor from, bool style = true, bool size = false) 
	{
		if (!to || !from)
			return;
		to.sprite = from.sprite;
		to.frame = from.frame;
		to.scale = from.scale;
		to.bSPRITEFLIP = from.bSPRITEFLIP;
		to.bXFLIP = from.bXFLIP;
		to.bYFLIP = from.bYFLIP;
		if (size)
			to.A_SetSize(from.height, from.radius);
		if (style) 
		{
			to.A_SetRenderstyle(from.alpha, from.GetRenderstyle());
			to.translation = from.translation;
		}
	}	
}

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

class ToM_NullActor : Actor 
{
	Default 
	{
		+NOINTERACTION
		+SYNCHRONIZED
		+DONTBLAST
		radius 1;
		height 1;
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
	protected transient CVar s_particles;
	mixin ToM_Math;
	mixin ToM_PlayerSightCheck;
	
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
	
	static const string ToM_LiquidFlats[] = 
	{ 
		"BLOOD", "LAVA", "NUKAGE", "SLIME01", "SLIME02", "SLIME03", "SLIME04", "SLIME05", "SLIME06", "SLIME07", "SLIME08", "BDT_"
	};
	
	//water check by Boondorl
	double GetWaterTop()	
	{
		if (CurSector.MoreFlags & Sector.SECMF_UNDERWATER)
			return CurSector.ceilingPlane.ZAtPoint(pos.xy);
		else
		
		{
			let hsec = CurSector.GetHeightSec();
			if (hsec)
			
			{
				double top = hsec.floorPlane.ZAtPoint(pos.xy);
				if ((hsec.MoreFlags & Sector.SECMF_UNDERWATERMASK)
					&& (pos.z < top
					|| (!(hsec.MoreFlags & Sector.SECMF_FAKEFLOORONLY) && pos.z > hsec.ceilingPlane.ZAtPoint(pos.xy))))
				
				{
					return top;
				}
			}
			else
			
			{
				for (uint i = 0; i < CurSector.Get3DFloorCount(); ++i)
				
				{
					let ffloor = CurSector.Get3DFloor(i);
					if (!(ffloor.flags & F3DFloor.FF_EXISTS)
						|| (ffloor.flags & F3DFloor.FF_SOLID)
						|| !(ffloor.flags & F3DFloor.FF_SWIMMABLE))
					
					{
						continue;
					}
						
					double top = ffloor.top.ZAtPoint(pos.xy);
					if (top > pos.z && ffloor.bottom.ZAtPoint(pos.xy) <= pos.z)
						return top;
				}
			}
		}			
		return 0;
	}	
	
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
	
	static void AlignToPlane(Actor a, SecPlane sec = null, bool ceiling = false) 
	{
		if (!a)
			return;
		Vector3 norm;
		a.pitch = 0;
		a.roll = 0;
		if (sec)
			norm = sec.normal;
		else 
		{
			FLineTraceData hit;
			a.LineTrace(0,a.height+16,ceiling ? 90 : -90,flags:TRF_THRUACTORS|TRF_NOSKY,data:hit);
			if (hit.Hit3DFloor) 
			{
				F3DFloor ff = hit.Hit3DFloor;
				norm = ceiling ? ff.bottom.normal : -ff.top.normal;
			}
			else 
				norm = ceiling ? a.CurSector.ceilingplane.normal : a.CurSector.floorplane.normal;
		}
		if (abs(norm.z) ~== 1) 
		{
			if (ceiling) 
			{
				a.pitch += 180;
			}
			return;		
		}
		a.angle = 0;
		double ang = DeltaAngle(VectorAngle(norm.x, norm.y), a.angle);
		double pch = 90 - asin(norm.z);
		if (pch > 90)
			pch -= 180;			
		a.pitch = pch * cos(ang);
		a.roll = pch * sin(ang);	
		if (ceiling) 
		{
			a.pitch += 180;
			a.roll *= -1;
		}
	}
	
	static clearscope double GetPlayerAtkHeight(PlayerPawn ppawn)
	{
		let player = ppawn.player;
		if (!ppawn)
			return 0;
		return ppawn.height * 0.5 - ppawn.floorclip + ppawn.AttackZOffset*player.crouchFactor;
	}
	
	static vector3 GetRelativePosition(actor mo, vector3 offset)
	{
		if (!mo)
			return (0,0,0);
		let cosang     = cos(mo.angle);
		let cosvang    = cos(mo.pitch);
		let cosrang    = cos(mo.roll);
		let sinang     = sin(mo.angle);
		let sinvang    = sin(-mo.pitch);
		let sinrang    = sin(-mo.roll);

		let up_no_roll = (
		-   sinvang * cosang,
		-   sinvang * sinang,
			cosvang);
		let left_no_roll = (
		-   sinang,
			cosang,
			0);

		// Now use these three:
		let forw = (
			cosvang * cosang,
			cosvang * sinang,
			sinvang);
		let left    = cosrang * left_no_roll - sinrang * up_no_roll;
		let up      = cosrang * up_no_roll + sinrang * left_no_roll;

		return(mo.pos + forw * offset.x + left * offset.y + up * offset.z);
	}
	
	override void BeginPlay() 
	{
		super.BeginPlay();
		pi = 3.141592653589793;
	}	
	
	override void Tick() 
	{
		super.Tick();
		if (!isFrozen())
			age++;
	}
	
	/*	Make the given actor invisible, have it drop its items
		and call A_BossDeath if necessary.
		If 'remove' is true, also destroy it; otherwise it's implied
		that it's queued for destruction to be destroyed later by
		the caller.
	*/	
	static void KillActorSilent(actor victim, bool remove = true) 
	{
		if (!victim)
			return;
		//hide the corpse
		victim.bINVISIBLE = true;
		//drop the items
		victim.A_NoBlocking();
		//call A_BossDeath if necessary
		if (victim.bBOSS || victim.bBOSSDEATH)
			victim.A_BossDeath();
		if (remove && !victim.player)
			victim.Destroy();
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
			destroy();
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
	double wrot;					//gets added to roll to imitate rotation during flying
	double dbrake; 				//how quickly to reduce horizontal speed of "landed" particles to simulate sliding along the floor
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
		-NOBLOCKMAP
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
	//a chad tick override that skips Actor's super.tick!
	override void Tick() 
	{
		if (alpha < 0)
		{
			destroy();
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
			destroy();
			return;
		}
		if (floorpic == skyflatnum) { 
			destroy();
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
				destroy();
				return;
			}
			/*
			if it's a flat (non-3d-floor) liquid, we'll visually sink the object into it a bit
			either by 50% of its height or by the value of its liquidheight property
			*/
			floorclip = (liquidheight == 0) ? (height * 0.5) : liquidheight;
			//enter "DeathLiquid" state if present, otherwise enter "Death"
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
			destroy();
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
			destroy();
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
		

Class ToM_Tracer : FastProjectile 
{
	Default 
	{
		-ACTIVATEIMPACT;
		-ACTIVATEPCROSS;
		+NOTELEPORT;
		+BLOODLESSIMPACT;
		alpha 0.75;
		renderstyle "add";
		speed 64;
		radius 4;
		height 4;
		seesound "null";
		deathsound "null";
	}    
	//whizz sound snippet by phantombeta
	override void Tick () 
	{
		Super.Tick ();
		if (level.isFrozen())
			return;
		if (!playeringame [consolePlayer])
			return;		
		let curCamera = players [consolePlayer].camera;
		if (!curCamera) // If the player's "camera" variable is null, set it to their PlayerPawn
			curCamera = players [consolePlayer].mo;
		if (!curCamera) // If the player's PlayerPawn is null too, just stop trying
			return;
		if (CheckIfCloser (curCamera, 192))
			A_StartSound("weapons/tracerwhizz",CHAN_AUTO,attenuation:8);
	}
	states 
	{
		Spawn:
			TNT1 A 2 NoDelay 
			{
				vel = vel.unit() * 256;
			}
			MODL A 1 bright;
			wait;
		Xdeath:
			TNT1 A 1;
			stop;
		Death:
			TNT1 A 1 
			{
				//if (frandom(0.0,1.0) > 0.8)
				//	A_SpawnProjectile("RicochetBullet",0,0,random(0,360),2,random(-40,40));
			}
			stop;
	}
}
	
Class ToM_BaseFlare : ToM_SmallDebris 
{
	protected state mdeath;
	protected state mxdeath;
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
	override void PostBeginPlay() 
	{
		super.PostBeginPlay();
		if (master) 
		{
			mdeath = master.FindState("Death");
			mxdeath = master.FindState("XDeath");
		}
		SetColor();
	}
	virtual void SetColor() { //fcolor is meant to be set by the actor that spawns the flare
		if (GetRenderstyle() == Style_AddShaded || GetRenderstyle() == Style_Shaded) 
		{
			if (!fcolor) 
			{
				destroy();
				return;
			}				
			else 
			{
				SetShade(fcolor);
			}
		}
		//frame = style;
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
	Default 
	{
		ToM_BaseFlare.fcolor "FF0000";
		alpha 0.8;
		scale 0.11;
	}
	override void Tick() 
	{
		super.Tick();
		if (!master /*|| !bdoom_debris*/) 
		{
			destroy();
			return;
		}
		if (isFrozen())
			return;
		Warp(master,xoffset,0,0,flags:WARPF_INTERPOLATE);
		/*if (master.InstateSequence(master.curstate,mdeath) || master.InstateSequence(master.curstate,mxdeath)) 
		{
			Destroy();
			return;
		}*/
	}
}

Class ToM_BaseSmoke : ToM_SmallDebris abstract 
{
	Default 
	{
		+NOINTERACTION
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
			self.destroy();
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
	double fade;
	Default 
	{
		+ROLLCENTER
		scale 0.1;
		renderstyle 'Translucent';
		alpha 0.5;
	}
	
	static ToM_WhiteSmoke SpawnWhiteSmoke(Actor self, vector3 ofs = (0,0,0), vector3 vel = (0,0,0), double scale = (0.1), double rotation = 4, double alpha = 0.5, double fade = 0)
	{
		if (!self)
			return null;
		let smk = ToM_WhiteSmoke(Actor.Spawn("ToM_WhiteSmoke", self.pos + ofs));
		if (smk)
		{
			smk.vel = vel;
			smk.scale = (scale, scale);
			smk.wrot = rotation;
			smk.alpha = alpha;
			smk.fade = fade;
		}
		return smk;
	}
	
	override void PostBeginPlay() 
	{
		super.PostBeginPlay();
		scale *= frandom[sfx](0.9,1.1);
		wrot *= (frandom[sfx](0.8, 1.2) * randompick[sfx](-1,1));
		frame = random[sfx](0,5);
		if (fade == 0)
			fade = 0.01;
	}	
	
	states 
	{
	Spawn:
		SMO2 # 1 
		{
			if (GetAge() < 26) 
			{
				wrot *= 0.98;
				scale *= 1.03;
				vel*=0.98;
				roll+=wrot;
				A_FadeOut(fade);
			}
			else 
			{
				wrot *= 0.92;
				scale *= 1.01;
				vel*=0.93;
				roll+=wrot;
				A_FadeOut(fade);
			}
		}
		loop;
	}
}

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
}

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