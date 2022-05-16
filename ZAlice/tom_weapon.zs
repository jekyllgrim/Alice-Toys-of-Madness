class ToM_BaseWeapon : Weapon abstract
{
	mixin ToM_Math;
	
	double PSpriteStartX[200];
	double PSpriteStartY[200];
	protected vector2 targOfs; //used by DampedRandomOffset
	protected vector2 shiftOfs; //used by DampedRandomOffset
	protected int idleCounter; //used by idle animations 
	protected int particleLayer; //used by multi-layer particle effects
	protected double atkzoom;
	
	protected int swayTics;
	protected double maxSwayTics; // starting point for the timer
	protected double SwayAngle; // the target angle for the camera sway
	protected double SwayPitch;
	protected double currentAngleSway; // how much has the camera already been Sway?
	protected double currentPitchSway;
	protected transient CVar c_freelook;
	
	protected state s_fire;
	protected state s_hold;
	protected state s_altfire;
	protected state s_althold;
	protected state s_idle;
	

	enum ToM_PSprite_Layers
	{
		APSP_BottomParticle = -300,
		APSP_UnderLayer = -10,
		APSP_Overlayer = 5,
		APSP_Card = 2,
		APSP_Thumb = 3,
		APSP_TopFX = 10,
		APSP_TopParticle = 300,
	}
	
	enum PABCheck
	{
		PAB_ANY,		//don't check if the button is held down
		PAB_HELD,		//check if the button is held down
		PAB_NOTHELD,	//check if the button is NOT held down
		PAB_HELDONLY	//check ONLY if the button is held down and ignore if it's pressed now
	}
	
	Default 
	{
		weapon.BobStyle "InverseSmooth";
		weapon.BobRangeX 0.32;
		weapon.BobRangeY 0.17;
		weapon.BobSpeed 1.85;
	}
	
	override void BeginPlay()
	{
		super.BeginPlay();
		swayTics = -1;
	}
	
	action void A_AttackZoom(double step = 0.001, double limit = 0.03, double jitter = 0.002)
	{
		if (invoker.atkzoom < limit)
		{
			invoker.atkzoom += step;
			A_ZoomFactor(1 - invoker.atkzoom,ZOOM_NOSCALETURNING);
		}
		else
			A_ZoomFactor(1 - invoker.atkzoom + frandom[atkzoom](-jitter, jitter),ZOOM_NOSCALETURNING);
	}
	
	action void A_ResetZoom(double step = 0.005)
	{
		if (invoker.atkzoom > 0)
		{
			invoker.atkzoom = Clamp(invoker.atkzoom - step, 0, 1);
			A_ZoomFactor(1 - invoker.atkzoom,ZOOM_NOSCALETURNING);
		}
	}
	
	// Camera sway function by josh771
	action void A_CameraSway(double aSway, double pSway, int tics) 
	{
		invoker.SwayTics = tics;
		invoker.maxSwayTics = tics;
		
		invoker.SwayAngle = aSway;
		//pitch Sway is ignored if freelook isn't in use:
		invoker.SwayPitch = CheckFreeLook() ? pSway : 0;

		invoker.currentAngleSway = 0.0;
		invoker.currentPitchSway = 0.0;
	}
	
	//check if freelook is in use
	action bool CheckFreeLook() 
	{
		//double-check 'freelook' cvar was cached correctly
		if (!invoker.c_freelook) 
		{
			invoker.c_freelook = CVar.GetCvar('freelook', player);
		}
		if (!invoker.c_freelook.GetBool())
			return false;
		//if singleplayer: return false if freelook is *disabled* OR if the player isn't *using* it
		//if multiplayer: ignore player settings, since everyone should be on equal terms
		if (!Level.IsFreelookAllowed() || (!multiplayer && !invoker.c_freelook)) 
		{
			//Console.Printf("Freelook allowed: %d | multiplayer: %d | Freelook in use: %d",Level.IsFreelookAllowed(),multiplayer,invoker.c_freelook);
			return false;
		}
		return true;
	}

	//A variation on GetPlayerInput that incorporates the switching primary/secondary attack feature:
	action bool PressingAttackButton(bool secondary = false, int holdCheck = PAB_ANY) 
	{
		if (!player)
			return false;
		//get the button:
		int button = secondary ? BT_ALTATTACK : BT_ATTACK;
		
		bool pressed = (player.cmd.buttons & button); //check if pressed now 
		bool held = (player.oldbuttons & button); //check if it was held from previous tic
		
		switch (holdCheck) 
		{
		case PAB_HELDONLY:			//true if held and not pressed
			return held;
			break;
		case PAB_NOTHELD:				//true if not held, only pressed
			return !held && pressed;
			break;
		case PAB_HELD:					//true if held and pressed
			return held && pressed;
			break;
		}
		return pressed;				//true if pressed, ignore held check
	}
	
	/*	This function staggers an overlay offset change over a few tics, so that
		I can randomize layer offsets but make it smoother than if it were called
		every tic.
	*/
	action void A_DampedRandomOffset(double rangeX, double rangeY, double rate = 1) 
	{
		if (!player)
			return;
		let psp = Player.FindPSprite(PSP_WEAPON);
		if (!psp)
			return;
		if (abs(psp.x) >= abs(invoker.targOfs.x) || abs(psp.y) >= abs(invoker.targOfs.y)) 
		{
			invoker.targOfs = (frandom[sfx](0,rangeX),frandom[sfx](0,rangeY)+WEAPONTOP);
			vector2 shift = (rangeX * rate, rangeY * rate);
			shift = (shift.x == 0 ? 1 : shift.x, shift.y == 0 ? 1 : shift.y);
			invoker.shiftOfs = ((invoker.targOfs.x - psp.x) / shift.x, (invoker.targOfs.y - psp.y) / shift.y);
		}
		A_WeaponOffset(invoker.shiftOfs.x, invoker.shiftOfs.y, WOF_ADD);
	}
	
	action void A_DoIdleAnimation(int frequency = 1, int chance = 0)
	{
		if (chance <= 0)
			return;
		if (!player)
			return;
		if (!invoker.s_idle)
			return;			
		chance = Clamp(chance, 0, 100);
		if (level.maptime % 35 != 0)
			return;
		invoker.idleCounter++;
		if (invoker.idleCounter % frequency == 0 && chance >= random[idleanim](1, 100))
		{
			invoker.idleCounter = 0;
			player.SetPSprite(OverlayID(), invoker.s_idle);
		}
	}
	
	// Reset the specified PSprite's offset, scale and angle
	// to default values. If staggertics is above 1, performs
	// only a partial reset. This argument is meant to be used
	// for a gradual reset, to be called over the matching number
	// of frames.
	action void A_ResetPSprite(int layer = 0, int staggertics = 1)
	{
		if (!player)
		{
			if (ToM_debugmessages)
				console.printf("Error: Tried calling A_ResetPSprite on invalid player");
			return;
		}
		int tlayer = layer == 0 ? OverlayID() : layer;
		let psp = player.FindPSprite(tlayer);
		if (!psp)
		{
			if (ToM_debugmessages)
				console.printf("Error: PSprite %d doesn't exist", layer);
			return;
		}
		vector2 targetofs = (0, tlayer == PSP_WEAPON ? WEAPONTOP : 0);
		if (staggertics > 1)
		{
			int id = layer + 100;
			if (id < 0 || id >= invoker.PSpriteStartX.Size() || id >= invoker.PSpriteStartX.Size())
			{
				if (ToM_debugmessages)
					console.printf("Error: PSprite index %d is out of PSpriteStart offset bounds", id);
				return;
			}
			vector2 ofs = ( invoker.PSpriteStartX[id] == 0 ? psp.x : invoker.PSpriteStartX[id], invoker.PSpriteStartY[id] == 0 ? psp.y : invoker.PSpriteStartY[id]);
			//vector2 sc = psp.scale;
			//double ang = psp.rotation;
			vector2 ofsStep = (-(ofs.x - targetOfs.x) / staggertics, -(ofs.y - targetOfs.y) / staggertics);
			/*console.printf("target ofs: (%1.f, %1.f) \ncurrent ofs: (%1.f, %1.f) \ncurrent step: target ofs: (%1.f, %1.f)",
				targetofs.x, targetOfs.y, 
				ofs.x, ofs.y, 
				ofsStep.x, ofsStep.y
			);*/
			
			A_OverlayOffset(layer, ofsStep.x, ofsStep.y, WOF_ADD);
			if (psp.x == targetOfs.x) invoker.PSpriteStartX[id] = 0;
			if (psp.y == targetOfs.y) invoker.PSpriteStartY[id] = 0;
			//A_OverlayRotate(layer, -ang / staggertics, WOF_ADD);
			//A_OverlayScale(layer, -(sc.x - 1) / staggertics, -(sc.y - 1) / staggertics, WOF_ADD);
			return;
		}
		A_OverlayOffset(layer, targetOfs.x, targetOfs.y/*, WOF_INTERPOLATE*/);
		A_OverlayRotate(layer, 0/*, WOF_INTERPOLATE*/);
		A_OverlayScale(layer, 1, 1/*, WOF_INTERPOLATE*/);
		if (ToM_debugmessages)
		{
			console.printf("PSprite offset: %.1f:%.1f | PSprite scale: %.1f:%.1f", psp.x, psp.y, psp.scale.x, psp.scale.y);
		}
	}
	
	/*
		A version of A_OverlayRotate that allows additive rotation
		without intepolation. Necessary because interpolation breaks 
		when combined with animation. 
		See stakegun primary fire for an example of use.
	*/
	action void A_RotatePSprite(int layer = 0, double degrees = 0, int flags = 0) 
	{
		let psp = player.FindPSprite(layer);
		if (!psp)
			return;
		double targetAngle = degrees;
		if (flags & WOF_ADD)
			targetAngle += psp.rotation;
		A_OverlayRotate(OverlayID(), targetAngle);
	}
	
	// Same but for scale:
	action void A_ScalePSprite(int layer = 0, double wx = 1, double wy = 1, int flags = 0) 
	{
		let psp = player.FindPsprite(OverlayID());
		if (!psp)
			return;
		vector2 targetScale = (wx,wy);
		if (flags & WOF_ADD)
			targetScale += psp.scale;
		A_OverlayScale(OverlayID(), targetScale.x, targetScale.y);
	}
	
	action void A_SpawnPSParticle(stateLabel statename, bool bottom = false, int density = 1, double xofs = 0, double yofs = 0, int chance = 100)
	{
		if (random[pspart](0, 100) > chance)
			return;
		state tstate = ResolveState(statename);
		if (!tstate)
			return;
		int startlayer = bottom ? APSP_BottomParticle : APSP_TopParticle;
		for (int i = 0; i < density; i++) 
		{
			int layer = startlayer+invoker.particleLayer;
			player.SetPSprite(layer, tstate);
			A_OverlayOffset(layer,frandom[pspart](-xofs,xofs),frandom[pspart](-yofs, yofs), WOF_ADD);
			invoker.particleLayer++;
			if (invoker.particleLayer >= 50)
				invoker.particleLayer = 0;
		}
	}
	
	action void A_PSPFadeOut(double factor)
	{
		if (!player)
			return;
		let psp = player.FindPSprite(OverlayID());
		if (psp)
		{
			psp.alpha -= factor;
			if (psp.alpha <= 0)
				player.SetPSprite(OverlayID(), ResolveState("Null"));
		}
	}
	
	action actor A_FireArchingProjectile(class<Actor> missiletype, double angle = 0, bool useammo = true, double spawnofs_xy = 0, double spawnheight = 0, int flags = 0, double pitch = 0) 
	{
		if (!self || !self.player) 
			return null;
		double pitchOfs = pitch;
		if (pitch != 0 && self.pitch < 0)
			pitchOfs = invoker.LinearMap(self.pitch, 0, -90, pitchOfs, 0);
		return A_FireProjectile(missiletype, angle, useammo, spawnofs_xy, spawnheight, flags, pitchOfs);
	}

	override void PostBeginPlay() 
	{
		super.PostBeginPlay();
		s_fire = FindState("Fire");
		s_hold = FindState("Hold");
		s_altfire = FindState("AltFire");
		s_althold = FindState("AltHold");
		s_idle = FindState("IdleAnim");
	}
	
	override void DoEffect()
	{
		super.DoEffect();
		if (SwayTics >= 0) 
		{
			double phase = (SwayTics / maxSwayTics) * 90.0;
			double newAngleSway = (cos(phase) * SwayAngle);
			double newPitchSway = (cos(phase) * SwayPitch);
			double finalAngle = (owner.angle - currentAngleSway) + newAngleSway;
			double finalPitch = (owner.pitch - currentPitchSway) + newPitchSway;
			currentAngleSway = newAngleSway;
			currentPitchSway = newPitchSway;
			owner.A_SetAngle(finalAngle, SPF_INTERPOLATE);
			owner.A_SetPitch(finalPitch, SPF_INTERPOLATE);
			SwayTics--;
		}
	}
}

class ToM_BasePuff : Actor
{
	mixin ToM_Math;
	Default 
	{
		+NOBLOCKMAP
		+NOGRAVITY
		+FORCEXYBILLBOARD
		+PUFFGETSOWNER
		-ALLOWPARTICLES
		+DONTSPLASH
		-FLOORCLIP
	}
}

//Base projectile class that can produce relatively solid trails:
Class ToM_Projectile : ToM_BaseActor abstract 
{
	//protected bool mod; //affteced by Weapon Modifier
	mixin ToM_Math;
	protected vector3 spawnpos;
	protected bool farenough;	
	color flarecolor;
	double flarescale;
	double flarealpha;
	color trailcolor;
	double trailscale;
	double trailalpha;
	double trailfade;
	double trailvel;
	double trailz;
	double trailshrink;
	
	class<Actor> trailactor;
	property trailactor : trailactor;
	class<ToM_ProjFlare> flareactor;	
	property flareactor : flareactor;
	property flarecolor : flarecolor;
	property flarescale : flarescale;
	property flarealpha : flarealpha;
	property trailcolor : trailcolor;
	property trailalpha : trailalpha;
	property trailscale : trailscale;
	property trailfade : trailfade;
	property trailshrink : trailshrink;
	property trailvel : trailvel;
	property trailz : trailz;
	
	Default 
	{
		projectile;
		height 6;
		radius 6;
		ToM_Projectile.flarescale 0.065;
		ToM_Projectile.flarealpha 0.7;
		ToM_Projectile.trailscale 0.04;
		ToM_Projectile.trailalpha 0.4;
		ToM_Projectile.trailfade 0.1;
		ToM_Projectile.flareactor "ToM_ProjFlare";
		ToM_Projectile.trailactor "ToM_BaseFlare";
	}
	
	/*
		For whatever reason the fancy pitch offset calculation used in arching projectiles 
		like grenades (see ToM_FireArchingProjectile) screws up the projectiles' collision, 
		so that it'll collide with the player if it fell down on them after being fired 
		directly upwards.
		I had to add this override to circumvent that.
	*/
	override bool CanCollideWith(Actor other, bool passive) 
	{
		if (!other)
			return false;
		if (!passive && target && other == target)
			return false;
		return super.CanCollideWith(other, passive);
	}
	
	//This is just to make sure the projectile doesn't collide with certain
	//non-collidable actors. Used by stuff like stakes.
	static bool CheckVulnerable(actor victim, actor missile = null) 
	{
		if (!victim)
			return false;
		/*if (missile) 
		{
			if (missile.bMTHRUSPECIES && missile.target && missile.target.species == victim.species)
				return true;
			if (victim.bSPECTRAL && !missile.bSPECTRAL)
				return true;
		}*/
		return (victim.bSHOOTABLE && !victim.bNONSHOOTABLE && !victim.bNOCLIP && !victim.bNOINTERACTION && !victim.bINVULNERABLE && !victim.bDORMANT && !victim.bNODAMAGE  && !victim.bSPECTRAL);
	}
	
	override void PostBeginPlay() 
	{
		super.PostBeginPlay();		
		//tom_main = target && PKWeapon.CheckWmod(target);
		if (trailcolor)
			spawnpos = pos;
		if (!flarecolor || !flareactor)
			return;
		let fl = ToM_ProjFlare( Spawn(flareactor,pos) );
		if (fl) 
		{
			fl.master = self;
			fl.fcolor = flarecolor;
			fl.fscale = flarescale;
			fl.falpha = flarealpha;
		}
	}
	
	//An override initially by Arctangent that spawns trails like FastProjectile does it:
	override void Tick () 
	{
		Vector3 oldPos = self.pos;		
		Super.Tick();
		if (!trailcolor || !trailactor)
			return;		
		if (!s_particles)
			s_particles = CVar.GetCVar('tom_particles', players[consoleplayer]);
		if (s_particles.GetInt() < 1)
			return;	
		if (!farenough) 
		{
			if (level.Vec3Diff(pos,spawnpos).length() < 80)
				return;
			farenough = true;
		}
		Vector3 path = level.vec3Diff( self.pos, oldPos );
		double distance = path.length() / clamp(int(trailscale * 50),1,8); //this determines how far apart the particles are
		Vector3 direction = path / distance;
		int steps = int( distance );
		
		for( int i = 0; i < steps; i++ )  
		{
		
			let trl = Spawn(trailactor,oldPos+(0,0,trailz));
			if (trl) 
			{
				trl.master = self;
				let trlflr = ToM_BaseFlare(trl);
				if (trlflr) 
				{
					trlflr.fcolor = trailcolor;
					trlflr.fscale = trailscale;
					trlflr.falpha = trailalpha;
					if (trailactor.GetClassName() == "ToM_BaseFlare")
						trlflr.A_SetRenderstyle(alpha,Style_Shaded);
					if (trailfade != 0)
						trlflr.fade = trailfade;
					if (trailshrink != 0)
						trlflr.shrink = trailshrink;
				}
				if (trailvel != 0)
					trl.vel = (frandom(-trailvel,trailvel),frandom(-trailvel,trailvel),frandom(-trailvel,trailvel));
			}
			oldPos = level.vec3Offset( oldPos, direction );
		}
	}
}

/*	A base projectile class that can stick into walls and planes.
	It'll move with the sector if it hit a moving one (e.g. door/platform).
	Base for stakes, bolts and shurikens.
*/
Class ToM_StakeProjectile : ToM_Projectile 
{
	protected vector3 endspot;
	protected transient F3DFloor hit_3dfloor;
	protected Line hit_line;
	protected int hitplane; //0: none, 1: floor, 2: ceiling
	protected actor stickobject; //a non-monster object that was hit
	protected transient SecPlane stickplane; //a plane to stick to (has to be transient, can't be recorded into savegames)
	protected vector2 sticklocation; //the point at the line the stake collided with
	protected double stickoffset; //how far the stake is from the nearest ceiling or floor (depending on whether it hit top or bottom part of the line)
	protected double topz; //ZAtPoint below stake
	protected double botz; //ZAtPoint above stake
	actor pinvictim; //The fake corpse that will be pinned to a wall
	protected double victimofz; //the offset from the center of the stake to the victim's corpse center
	protected state sspawn; //pointer to Spawn label
	bool stuckToSecPlane; //a non-transient way to record whether it stuck to a wall. Used by ToM_StakeStickHandler
	
	Default 
	{
		+MOVEWITHSECTOR
		+NOEXTREMEDEATH
	}
	
	void SetEndSpot(vector3 spot) 
	{
		endspot = spot;
	}
	
	//this function is called when the projectile dies and checks if it hit something
	virtual void StickToWall() 
	{
		string myclass = GetClassName();
		bTHRUACTORS = true;
		bNOGRAVITY = true;
		A_Stop();
		if (endspot != (0,0,0))
			SetOrigin(endspot, false);
			
		if (target && (angle == 0 || pitch == 0))
		{
			angle = target.angle;
			pitch = target.pitch;
		}
		
		if (stickobject) 
		{
			stickoffset = pos.z - stickobject.pos.z;
			if (tom_debugmessages > 2)
				console.printf("%s hit %s at at %d,%d,%d",myclass,stickobject.GetClassName(),pos.x,pos.y,pos.z);
			return;
		}
		
		//use linetrace to get information about what we hit
		FLineTraceData trac;
		LineTrace(angle,64,pitch,TRF_NOSKY|TRF_THRUACTORS|TRF_BLOCKSELF,data:trac);
		//if (!hit_3dfloor)
			hit_3dfloor = trac.Hit3DFloor;
		//if (!hit_Line)
			hit_Line = trac.HitLine;		
		//if (endspot != (0,0,0))
			//sticklocation = endspot.xy;
		//else
			sticklocation = trac.HitLocation.xy;
		topz = CurSector.ceilingplane.ZatPoint(sticklocation);
		botz = CurSector.floorplane.ZatPoint(sticklocation);
		
		//if hit floor/ceiling, we'll attach to them:
		if (trac.HitLocation.z >= topz) 
		{
			hitplane = 2;
			if (tom_debugmessages > 2)
				console.printf("%s hit ceiling at at %d,%d,%d",myclass,pos.x,pos.y,pos.z);
		}
		else if (trac.HitLocation.z <= botz) 
		{
			hitplane = 1;
			if (tom_debugmessages > 2)
				console.printf("%s hit floor at at %d,%d,%d",myclass,pos.x,pos.y,pos.z);
		}
		if (hitplane > 0)
			return;
			
		//3D floor is easiest, so we start with it:
		if (hit_3dfloor) 
		{
			stuckToSecPlane = true;
			//we simply attach the stake to the 3D floor's top plane, nothing else
			F3DFloor flr = trac.Hit3DFloor;
			stickplane = flr.top;
			stickoffset = stickplane.ZAtPoint(sticklocation) - pos.z;
			if (tom_debugmessages > 2)
				console.printf("%s hit a 3D floor at %d,%d,%d",myclass,pos.x,pos.y,pos.z);
			return;
		}
		//otherwise see if we hit a line:
		if (hit_Line) 
		{
			//check if the line is two-sided first:
			let tline = hit_Line;
			//if it's one-sided, it can't be a door/lift, so don't do anything else:
			if (!tline.backsector) 
			{
				if (tom_debugmessages > 2)
					console.printf("%s hit one-sided line, not doing anything else",myclass);
				return;
			}
			stuckToSecPlane = true;
			//if it's two-sided:
			//check which side we're on:
			int lside = PointOnLineSide(pos.xy,tline);
			string sside = (lside == 0) ? "front" : "back";
			//we'll attach the stake to the sector on the other side:
			let targetsector = (lside == 0 && tline.backsector) ? tline.backsector : tline.frontsector;
			let floorHitZ = targetsector.floorplane.ZatPoint (sticklocation);
			let ceilHitZ = targetsector.ceilingplane.ZatPoint (sticklocation);
			string secpart = "middle";
			//check if we hit top or bottom floor (i.e. door or lift):
			if (pos.z <= floorHitZ) 
			{
				secpart = "lower";
				stickplane = targetsector.floorplane;
				stickoffset = floorHitZ - pos.z;
			}
			else if (pos.z >= ceilHitZ) 
			{
				secpart = "top";
				stickplane = targetsector.ceilingplane;
				stickoffset = ceilHitZ - pos.z;
			}
			if (tom_debugmessages > 2)
				console.printf("%s hit the %s %s part of the line at %d,%d,%d",myclass,secpart,sside,pos.x,pos.y,pos.z);
		}
	}
	
	//record a non-monster solid object the stake runs into if there is one:
	override int SpecialMissileHit (Actor victim) 
	{
		if (!victim.bISMONSTER && victim.bSOLID) 
		{
			stickobject = victim;
		}
		return -1;
	}
	
	//virtual for breaking apart; child actors override it to add debris spawning and such:
	virtual void StakeBreak() 
	{
		if (tom_debugmessages > 2)
			console.printf("%s Destroyed",GetClassName());
		if (self)
			Destroy();
	}
	
	override void PostBeginPlay() 
	{
		super.PostBeginPlay();
		sspawn = FindState("Spawn");
	}
	
	override void Tick () 
	{
		super.Tick();
		//all stake-like projectiles need to face their movement direction while in Spawn sequence:
		if (!isFrozen() && sspawn && InStateSequence(curstate,sspawn)) 
		{
			A_FaceMovementDirection(flags:FMDF_INTERPOLATE );
			/*FLineTraceData hit;
			LineTrace(angle, radius + vel.length(), pitch, TRF_NOSKY|TRF_BLOCKSELF, data: hit);
			if (hit.Hitline)
				hit_line = hit.HitLine;
			if (hit.Hit3DFloor)
				hit_3dfloor = hit.Hit3DFloor;
			if (hit.HitType == TRACE_HitFloor || hit.HitType == TRACE_HitCeiling || hit.HitType == TRACE_HitWall)
				endspot = hit.Hitlocation;*/
		}
		//otherwise stake is dead, so we'll move it alongside the object/plane it's supposed to be attached to:
		if (bTHRUACTORS) 
		{
			topz = CurSector.ceilingplane.ZAtPoint(pos.xy);
			botz = CurSector.floorplane.ZAtPoint(pos.xy);
			/*	Destroy the stake if it's run into ceiling/floor by a moving sector 
				(e.g. a door opened, pulled the stake up and pushed it into the ceiling). 
				Only do this if the stake didn't actually hit a plane before that:
			*/
			if (!hitplane && (pos.z >= topz-height || pos.z <= botz)) 
			{
				StakeBreak();
				return;
			}
			//attached to floor/ceiling:
			if (hitplane > 0) 
			{
				if (hitplane > 1)
					SetZ(ceilingz);
				else
					SetZ(floorz);
			}
			//attached to a plane (hit a door/lift earlier)
			else if (stickplane) 
			{
				SetZ(stickplane.ZAtPoint(sticklocation) - stickoffset);
			}
			//otherwise attach it to the solid object it hit earlier:
			else if (stickobject)
				SetZ(stickobject.pos.z + stickoffset);
			//and if there's a decorative corpse on the stake, move it as well:
			if (pinvictim)
				pinvictim.SetZ(pos.z + victimofz);
		}
	}
}


class ToM_CrosshairSpawner : ToM_InventoryToken
{
	protected vector3 aimPos;
	protected PlayerPawn ppawn;
	
	vector3 GetAimPos()
	{
		return aimPos;
	}
	
	override void DoEffect()
	{
		super.DoEffect();
		if (!owner || !owner.player || owner.player != players[consoleplayer] || !owner.player.readyweapon || owner.health <= 0)
			return;
				
		if (!ppawn) ppawn = PlayerPawn(owner);
		
		let weap = owner.player.readyweapon;
		if (weap && weap.bMELEEWEAPON)
			return;
		
		FLineTracedata tr;
		owner.LineTrace(owner.angle, 2048, owner.pitch, TRF_SOLIDACTORS, owner.height * 0.5 - owner.floorclip + ppawn.AttackZOffset*ppawn.player.crouchFactor, data: tr);
		aimPos = tr.hitLocation;
		SpawnCrosshair();
	}
	
	void SpawnCrosshair()
	{
		Spawn("ToM_CrosshairSpot", aimPos);
	}
}


class ToM_CrosshairSpot : ToM_BaseDebris
{
	Default
	{
		+NOINTERACTION
		+NOBLOCKMAP
		+BRIGHT
		+FORCEXYBILLBOARD
		scale 0.24;
		+NOTIMEFREEZE
		radius 2;
		height 2;
		renderstyle "Add";
	}
	
	States
	{
	Spawn:
		AMCR X 1 A_FadeOut(0.1);
		loop;
	}
}