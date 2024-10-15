class ToM_Utils
{
	const PI = 3.141592653589793;

	static clearscope int Sign (double i) 
	{
		return (i >= 0) ? 1 : -1;
	}

	static clearscope double LoopRange(double val, double min, double max)
	{
		if (val > max)
			val = min;
		else if (val < min)
			val = max;
		return val;
	}

	static clearscope bool IsVoodooDoll(PlayerPawn mo) 
	{
		return !mo.player || !mo.player.mo || mo.player.mo != mo;
	}

	static clearscope bool IsInFirstPerson(Actor mo)
	{
		return mo && mo.player && 
			mo.player.mo && 
			mo.player.mo == mo && 
			mo.player == players[consoleplayer] && 
			mo.player.camera == mo && 
			!(mo.player.cheats & CF_CHASECAM);
	}

	//By default returns true if ANY of the players has the item.
	//If 'checkall' argument is true, the function returns true if ALL players have the item.
	static clearscope bool CheckPlayersHave(Class<Inventory> itm, bool checkall = false)
	{
		if(!itm)
			return false;
		
		// Check all: start with a TRUE; as soon as somebody is found
		// to NOT have the item, flip to false and break.
		// Otherwise: start with FALSE; as soon as somebody is found
		// to HAVE the item, flip to true and break.
		bool found = checkall;
		for (int pn = 0; pn < MAXPLAYERS; pn++) 
		{
			if (!playerInGame[pn])
				continue;
			
			PlayerInfo plr = players[pn];
			if (!plr || !plr.mo)
				continue;
				
			bool hasItem = plr.mo.CountInv(itm);
			
			// If we're checking anyone, as soon as somebody is found
			// to have the item, return true:
			if (!checkall) 
			{
				if (hasItem) {
					ToM_DebugMessage.Print(String.Format("Player %d has %s",plr.mo.PlayerNumber(),itm.GetClassName()), 2);
					found = true;
					break;
				}
			}
			
			// If we're checking everyone, as soon as somebody is found
			// to NOT have the item, return false:
			else if (!hasItem) 
			{
				ToM_DebugMessage.Print(String.Format("Player %d doesn't have %s.",plr.mo.PlayerNumber(),itm.GetClassName()), 2);
				found = false;
				break;
			}
		}
		return found;
	}
	
	static clearscope double LinearMap(double val, double source_min, double source_max, double out_min, double out_max, bool clampit = false) 
	{
		double sourceDiff = source_max - source_min;
		if (sourceDiff == 0)
		{
			return 0;
		}
		double d = (val - source_min) * (out_max - out_min) / sourceDiff + out_min;
		if (clampit)
		{
			double truemax = out_max > out_min ? out_max : out_min;
			double truemin = out_max > out_min ? out_min : out_max;
			d = Clamp(d, truemin, truemax);
		}
		return d;
	}

	static play double SinePulse(double frequency = TICRATE, int counter = -1)
	{
		double time = counter >= 0 ? counter : Level.mapTime;
		return 0.5 + 0.5 * sin(360.0 * time / frequency);
	}
		
	// Checks which side of a lindef the actor is on:
	// Unnecessary wrapper, since PointOnLineSide has since been
	// added to GZDoom
	static clearscope int PointOnLineSide( Vector2 p, Line l ) 
	{
		if ( !l ) return 0;
		//return (((p.y-l.v1.p.y)*l.delta.x+(l.v1.p.x-p.x)*l.delta.y) > double.epsilon);	
		return LevelLocals.PointOnLineSide(p, l);
	}
	
	//Returns -1 if the box (normally an actor's radius) intersects a linedef:
	static clearscope int BoxOnLineSide(double top, double bottom, double left, double right, Line l)
	{
		if (!l) 
			return 0;

		int p1, p2;
		if (l.delta.x == 0)
		{
			// ST_VERTICAL:
			p1 = (right < l.v1.p.x);
			p2 = (left < l.v1.p.x);
			if (l.delta.y < 0)
			{
				p1 ^= 1;
				p2 ^= 1;
			}
		}
		else if (l.delta.y == 0)
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
		else if ((l.delta.x*l.delta.y) >= 0)
		{
			// ST_POSITIVE:
			p1 = ToM_Utils.PointOnLineSide((left,top),l);
			p2 = ToM_Utils.PointOnLineSide((right,bottom),l);
		}
		else 
		{
			// ST_NEGATIVE:
			p1 = ToM_Utils.PointOnLineSide((right,top),l);
			p2 = ToM_Utils.PointOnLineSide((left,bottom),l);
		}
		return (p1 == p2) ? p1 : -1;
	}

	// Obtains a wall normal vector:
	static clearscope vector2 GetLineNormal(vector2 ppos, Line lline)
	{
		vector2 linenormal;
		linenormal = (-lline.delta.y, lline.delta.x).Unit();
		if (!ToM_Utils.PointOnLineSide(ppos, lline))
			linenormal *= -1;
		
		return linenormal;
	}

	// Obtains a normal vector from FLineTraceData
	// depending on what it hit:
	static play vector3 GetNormalFromTrace(FLineTraceData normcheck)
	{
		vector3 hitnormal = -normcheck.HitDir;
		if (normcheck.HitType == TRACE_HitFloor)
		{
			if (normcheck.Hit3DFloor) 
				hitnormal = -normcheck.Hit3DFloor.top.Normal;
			else 
				hitnormal = normcheck.HitSector.floorplane.Normal;
		}
		else if (normcheck.HitType == TRACE_HitCeiling)
		{
			if (normcheck.Hit3DFloor) 
				hitnormal = -normcheck.Hit3DFloor.bottom.Normal;
			else 
				hitnormal = normcheck.HitSector.ceilingplane.Normal;
		}
		else if (normcheck.HitType == TRACE_HitWall && normcheck.HitLine)
		{
			hitnormal.xy = (-normcheck.HitLine.delta.y, normcheck.HitLine.delta.x).Unit();
			if (normcheck.LineSide == Line.front)
			{
				hitnormal.xy *= -1;
			}
			hitnormal.z = 0;
		}
		return hitnormal;
	}

	// Obtains a normal for whatever surface is hit from the
	// given source actor, using given distance, angle and pitch.
	// Returns the normal and a bool telling if it was obtained successfully:
	static play vector3, bool GetNormalFromPos(Actor source, double dist, double angle, double pitch, out FLineTraceData normcheck)
	{
		if (!source)
		{
			return (0,0,0), false;
		}

		source.LineTrace(angle, dist, pitch, flags: TRF_NOSKY, offsetz: source.height*0.5, data:normcheck);
		let ht = normcheck.HitType;
		if (ht != TRACE_HitFloor && ht != TRACE_HitCeiling && ht != TRACE_HitWall)
		{
			return (0,0,0), false;
		}

		return GetNormalFromTrace(normcheck), true;
	}

	enum ETraceHitTypes
	{
		HT_None,
		HT_ShootableThing,
		HT_Solid,
	}

	// Wrapper that tells us if a given linetrace hit
	// something solid, something shootable, or nothing
	// and returns an actor pointer if one was obtained:
	static play ETraceHitTypes, Actor GetHitType(FLineTraceData tr)
	{
		if (tr.HitType == TRACE_HitNone)
		{
			return HT_None, null;
		}
		if (tr.HitType == TRACE_HitActor)
		{
			let victim = tr.HitActor;
			if (victim)
			{
				if(victim.bSHOOTABLE && victim.health > 0 && !victim.bDORMANT && !victim.bINVULNERABLE && !victim.bNODAMAGE)
				{
					return HT_ShootableThing, victim;
				}
				else if (victim.bSOLID)
				{
					return HT_Solid, victim;
				}
			}
		}
		else if (tr.HitType == TRACE_HitFloor || tr.HitType == TRACE_HitCeiling || tr.HitType == TRACE_HitWall)
		{
			return HT_Solid, null;
		}
		return HT_None, null;
	}
	
	// Gets a position at the end of a line-of-fire vector
	// of a given actor using given angle/pitch/distance/offsetz:
	static play vector3 GetEndOfLOF(Actor checker, double angle, double distance, double pitch, double offsetz)
	{
		FLineTraceData tr;
		let angle = checker.angle;
		let pitch = checker.pitch;
		let pos = checker.pos;
		checker.LineTrace(angle, distance, pitch, TRF_THRUACTORS, offsetz, 0, 0, data: tr);
		
		vector3 endpos;
		if (tr.HitType == Trace_HitNone)
		{
			let dir = (cos(angle)*cos(pitch), sin(angle)*cos(pitch), sin(-pitch));
			endpos = (pos + (0,0,offsetz)) + (dir * distance);
		}
		else
		{
			endpos = tr.HitLocation;
		}
		return endpos;
	}
	
	// Draws particles along a vector between two points in space:
	static void DrawParticlesFromTo(
		Vector3 from,
		Vector3 to,
		double density              = 8,
		double size                 = 10,
		double alpha                = 1.0,
		int lifetime                = 10,
		Vector3 vel                 = (0,0,0),
		double posOfs               = 0,
		String texture              = "",
		Color pcolor                = 0xFFCCCCFF,
		ERenderStyle renderstyle    = STYLE_Add,
		EParticleBeamStyle style    = PBS_Solid,
		double maxdistance          = PLAYERMISSILERANGE,
		PlayerInfo playerSource     = null)
	{
		density = Clamp(density, 0.025, 1024);
		let diff = Level.Vec3Diff(from, to); // difference between two points
		let dir = diff.Unit(); // direction from point 1 to point 2
		double dist = min(diff.Length(), maxdistance);
		int steps = int(ceil(dist / density)); // how many steps to take:

		// Generic particle properties:
		FSpawnParticleParams pp;
		if (!(style & PBS_Untextured) && texture)
		{
			TextureID tex = TexMan.CheckForTexture(texture);
			if (tex && tex.IsValid())
			{
				pp.texture = tex;
			}
		}
		pp.color1 = pcolor;
		pp.flags |= SPF_REPLACE;
		pp.lifetime = lifetime;
		pp.size = size;
		pp.style = renderstyle;
		pp.startalpha = alpha;
		if (style & PBS_Fade)
		{
			pp.fadestep = -1;
		}
		if (style & PBS_Shrink)
		{
			pp.sizestep = -(pp.size / pp.lifetime);
		}
		if (style & PBS_Fullbright)
		{
			pp.flags |= SPF_FULLBRIGHT;
		}
		pp.vel = vel;
		if (playerSource && playerSource.mo)
		{
			pp.vel = playerSource.mo.vel;
		}
		posOfs = abs(posOfs);
		Vector3 partPos = from; //initial position
		for (int i = 0; i <= steps; i++)
		{
			pp.pos = partPos;
			if (posOfs > 0)
			{
				pp.pos + (frandom[drawparts](-posOfs,posOfs), frandom[drawparts](-posOfs,posOfs), frandom[drawparts](-posOfs,posOfs));
			}
			// spawn the particle:
			Level.SpawnParticle(pp);
			// Move position from point 1 topwards point 2:
			partPos += dir*density;
		}
	}

	static play vector3 FindRandomPosAround(vector3 actorpos, double rad = 512, double mindist = 16, double fovlimit = 0, double viewangle = 0, double maxHeightDiff = 4096)
	{
		if (!level.IsPointInLevel(actorpos))
			return actorpos;
		
		vector3 finalpos = actorpos;
		double ofs = rad * 0.5;
		// 64 iterations should be enough...
		for (int i = 64; i > 0; i--)
		{
			// Pick a random position:
			vector3 ppos = level.Vec3Offset(actorpos, (frandom[frpa](-ofs, ofs), frandom[frpa](-ofs, ofs), 0));
			if (!Level.IsPointInLevel(ppos))
			{
				continue;
			}
			// Get the sector and distance to the point:
			let sec = Level.PointinSector(ppos.xy);
			double secfz = sec.NextLowestFloorAt(ppos.x, ppos.y, ppos.z);
			let diff = LevelLocals.Vec2Diff(actorpos.xy, ppos.xy);
			
			// Check FOV, if necessary:
			bool inFOV = true;
			if (fovlimit > 0)
			{
				double ang = atan2(diff.y, diff.x);
				inFOV = (Actor.AbsAngle(viewangle, ang) <= fovlimit);
			}
			
			// We found suitable position if it's in the map,
			// in view (optionally), on the same elevation
			// (optionally) and not closer than necessary
			// (optionally):
			if (inFOV && (abs(secfz - actorpos.z) <= maxHeightDiff) && (mindist <= 0 || diff.Length() >= mindist))
			{
				finalpos = (ppos.xy, secfz);
				//console.printf("Final pos: %.1f,%.1f,%.1f", finalpos.x,finalpos.y,finalpos.z);
				break;
			}
		}
		return finalpos;
	}

	static play double GetPlayerAtkHeight(PlayerPawn ppawn, bool absolute = false)
	{
		if (!ppawn)
			return 0;
		
		let player = ppawn.player;
		if (!player)
			return 0;
		
		double h = ppawn.height * 0.5 - ppawn.floorclip + ppawn.AttackZOffset*player.crouchFactor;
		if (absolute)
			h += ppawn.pos.z;
		
		return h;
	}
	
	// Converts offsets into relative offsets
	// mo: the actor to offset from
	// offset: desired relative offset as (forward/back, right/left, up/down)
	// isPosition: if TRUE, adds actor's position to the result. Set to FALSE when used for relative velocity.
	static clearscope Vector3 RelativeToGlobalCoords(actor mo, vector3 offset, bool isPosition = true)
	{
		if (!mo)
			return (0,0,0);
		
		return RelativeToGlobalOffset(mo.pos, (mo.angle, mo.pitch, mo.roll), offset, isPosition);
	}

	// Same as above, but doesn't take an actor pointer.
	// startPos: original position to operate around
	// viewAngles: (angle, pitch, roll) of the desired actor. viewAngle/viewPitch/viewRoll can be added or used instead.
	// isPosition: if TRUE, adds startpos to the final result.
	static clearscope Vector3 RelativeToGlobalOffset(Vector3 startpos, Vector3 viewAngles, Vector3 offset, bool isPosition = true)
	{
		Quat dir = Quat.FromAngles(viewAngles.x, viewAngles.y, viewAngles.z);
		vector3 ofs = dir * (offset.x, -offset.y, offset.z);
		if (isPosition)
		{
			return Level.Vec3offset(startpos, ofs);
		}
		return ofs;
	}

	// Converts world offsets to PSprite movement.
	// Used by PSprites that are meant to move in the same
	// direction as world vel.
	// Returns Vector2 to apply to PSprite's x and y,
	// and a Vector2 to apply to PSprite's scale
	// to imitate the movement.
	static clearscope Vector2, Vector2 WorldToPSpriteCoords(double forwardBack, double leftright, double updown, double pitch, double depthScale = 1.0)
	{
		double normPitch = ToM_Utils.LinearMap(pitch, -90, 90, -1.0, 1.0, true); //pscInv
		double invPitch = 1.0 - abs(normPitch); //psc
		Vector3 vec;
		vec.y = leftright; // horizontal movement - unchanged
		vec.z = forwardBack * normPitch + updown * invPitch; //vertical movement relative to pitch
		vec.x = forwardBack * invPitch + updown * normPitch; //depth (scale) movement relative to pitch
		if (vec.x != 0)
		{
			depthScale = abs(depthScale);
			vec.x = ToM_Utils.LinearMap(vec.x, -15, 15, -depthScale, depthScale);
		}

		return (vec.y, vec.z), (vec.x, vec.x);
	} 
	
	static play void AlignToPlane(Actor a, SecPlane sec = null, bool ceiling = false) 
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
			a.LineTrace(0, max(a.height, a.radius), ceiling ? 90 : -90, flags:TRF_THRUACTORS|TRF_NOSKY, data:hit);
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
		double ang = Actor.DeltaAngle(VectorAngle(norm.x, norm.y), a.angle);
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
	
	// Copies appearance of one actor to another in all 
	// the ways I could think of:
	static play void CopyAppearance(Actor to, Actor from, bool style = true, bool size = false) 
	{
		if (!to || !from)
			return;
		to.sprite = from.sprite;
		to.frame = from.frame;
		to.scale = from.scale;
		to.angle = from.angle;
		to.roll = from.roll;
		to.bROLLSPRITE = from.bROLLSPRITE;
		to.bROLLCENTER = from.bROLLCENTER;
		to.spriteoffset = from.spriteoffset;
		to.worldOffset = from.worldOffset;
		to.bSPRITEFLIP = from.bSPRITEFLIP;
		to.bXFLIP = from.bXFLIP;
		to.bYFLIP = from.bYFLIP;
		to.bFORCEYBILLBOARD = from.bFORCEYBILLBOARD;
		to.bFORCEXYBILLBOARD = from.bFORCEXYBILLBOARD;
		to.bFLOATBOB = from.bFLOATBOB;
		to.FloatBobPhase = from.FloatBobPhase;
		to.FloatBobStrength = from.FloatBobStrength;
		// these 4 are CRITICALLY important to make sure
		// the copy also has the same sprite clipping
		// as the original actor:
		to.bIsMonster = from.bIsMonster;
		to.bCorpse = from.bCorpse;
		to.bFloorclip = from.bFloorclip;
		to.bSpecialFloorclip = from.bSpecialFloorclip;

		if (size)
		{
			to.A_SetSize(from.height, from.radius);
		}
			
		if (style) 
		{
			to.A_SetRenderstyle(from.alpha, from.GetRenderstyle());
			to.translation = from.translation;
		}
	}
	
	// Make the given actor invisible, have it drop its items
	// and call A_BossDeath if necessary.
	// If 'remove' is true, also destroy it; otherwise it's implied
	// that it's queued for destruction to be destroyed later by
	// the caller.
	static play void KillActorSilent(actor victim, bool remove = true) 
	{
		if (!victim)
			return;
		//hide the corpse
		victim.A_SetRenderstyle(0, Style_None);
		//drop the items
		victim.A_NoBlocking();
		//call A_BossDeath if necessary
		if (victim.bBOSS || victim.bBOSSDEATH)
			victim.A_BossDeath();
		if (remove && !victim.player)
			victim.Destroy();
	}

	// Adds an actor to the specified array so they're ordered by their distance 
	// from the 'from' actor:
	static void AddByDistance(Actor toAdd, Actor from, out array<Actor> arr)
	{
		if (arr.Size() <= 0)
		{
			arr.Push(toAdd);
			return;
		}

		double dist = from.Distance3D(toAdd)**2;
		for (int i = 0; i < arr.Size(); i++)
		{
			let v = arr[i];
			if (!v) 
				continue;
			
			if (dist <= from.Distance3DSquared(v))
			{
				arr.Insert(i, toAdd);
				break;
			}
		}
	}

	static play Inventory SpawnInvPickup(Inventory sourceItem, vector3 spawnpos, Class<Inventory> itemToSpawn) 
	{
		let item = Inventory(Actor.Spawn(itemToSpawn,spawnpos));
		if (!item) return null;
		
		// Halve the amount if it's dropped by the enemy:
		if (sourceItem.bTOSSED) 
		{
			item.bTOSSED = true;
			item.amount = Clamp(item.amount / 2, 1, item.amount);
		}
		
		// this is important to make sure that the weapon 
		// that wasn't dropped doesn't get DROPPED flag 
		// (and thus can't be crushed by moving ceilings)
		else if (item is 'Weapon')
		{
			item.bDROPPED = false;
		}

		// transfer all relevant data similar to
		// how RandomSpawner does it:
		item.SpawnAngle = sourceItem.SpawnAngle;
		item.Angle		= sourceItem.Angle;
		item.SpawnPoint = sourceItem.SpawnPoint;
		item.special    = sourceItem.special;
		item.args[0]    = sourceItem.args[0];
		item.args[1]    = sourceItem.args[1];
		item.args[2]    = sourceItem.args[2];
		item.args[3]    = sourceItem.args[3];
		item.args[4]    = sourceItem.args[4];
		item.special1   = sourceItem.special1;
		item.special2   = sourceItem.special2;
		item.SpawnFlags = sourceItem.SpawnFlags & ~MTF_SECRET;
		item.HandleSpawnFlags();
		item.SpawnFlags = sourceItem.SpawnFlags;
		item.bCountSecret = sourceItem.SpawnFlags & MTF_SECRET;
		item.ChangeTid(sourceItem.tid);
		item.Vel	= sourceItem.Vel;
		item.master = sourceItem.master;
		item.target = sourceItem.target;
		item.tracer = sourceItem.tracer;

		return item;
	}
}