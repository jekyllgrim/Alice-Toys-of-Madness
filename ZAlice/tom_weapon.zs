class ToM_BaseWeapon : Weapon abstract
{
	mixin ToM_PlayerSightCheck;
	mixin ToM_CheckParticles;
	
	array <ToM_PspResetController> pspcontrols;
	
	protected vector2 targOfs; //used by DampedRandomOffset
	protected vector2 shiftOfs; //used by DampedRandomOffset
	protected int idleCounter; //used by idle animations 
	protected int particleLayer_bottom; //used by multi-layer particle effects
	protected int particleLayer_top; //used by multi-layer particle effects
	protected double atkzoom;
	
	protected state kickstate;
	protected double prekickspeed;
	
	color PickupParticleColor;
	property PickupParticleColor : PickupParticleColor;
	bool IsTwoHanded;
	property IsTwoHanded : IsTwoHanded;
	
	// used by vorpal knife and jacks, to tell the player pawn
	// that it shouldn't be rendering any weapon model:
	bool wasThrown;
	
	protected int swayTics;
	protected double maxSwayTics; // starting point for the timer
	protected double SwayAngle; // the target angle for the camera sway
	protected double SwayPitch;
	protected double currentAngleSway; // how much has the camera already been swayed
	protected double currentPitchSway;
	protected transient CVar c_freelook;
	
	protected state s_fire;
	protected state s_hold;
	protected state s_altfire;
	protected state s_althold;
	protected state s_idle;
	
	enum PABCheck
	{
		PAB_ANY,		//pressed now (doesn't matter if held)
		PAB_HELD,		//pressed AND held
		PAB_NOTHELD,	//pressed but NOT held
		PAB_HELDONLY	//NOT pressed but held
	}
	
	enum PABbuttonCheck
	{
		PAB_AUTO,
		PAB_PRIMARY,
		PAB_SECONDARY
	}
	
	Default 
	{
		Inventory.Pickupmessage "";
		Inventory.PickupSound "pickups/weapon";
		weapon.BobStyle "InverseSmooth";
		weapon.BobRangeX 0.32;
		weapon.BobRangeY 0.17;
		weapon.BobSpeed 1.85;
		scale 0.5;
		+FLOATBOB
		FloatBobStrength 0.8;
		ToM_BaseWeapon.PickupParticleColor "7fa832";
	}
	
	action bool HasRageBox()
	{
		return ToM_RageBox.HasRageBox(self);
	}
	
	/*	Function by Lewisk3 using Gutamatics to fire 3D projectiles
		with proper 3D offsets and optional crosshair converging.
		(Adapted from a static version to an action function by me.)
	*/
	action Actor A_Fire3DProjectile(class<Actor> proj, bool useammo = true, double forward = 0, double leftright = 0, double updown = 0, bool crosshairConverge = false, double angleoffs = 0, double pitchoffs = 0)
	{
		if (!player || !player.mo)
			return null;
			
		let weapon = player.ReadyWeapon;
		if (useammo && weapon && stateinfo && stateinfo.mStateType == STATE_Psprite)
		{
			if (!weapon.DepleteAmmo(weapon.bAltFire, true))
				return null;
		}		
		double a = angle + angleoffs;
		double p = Clamp(pitch + pitchoffs, -90, 90);
		double r = roll;
		let mat = ToM_GM_Matrix.fromEulerAngles(a, p, r);
		mat = mat.multiplyVector3((forward, -leftright, updown));
		vector3 offsetPos = mat.asVector3(false);
		
		vector3 shooterPos = (pos.xy, ToM_Utils.GetPlayerAtkHeight(player.mo, absolute:true));
		offsetPos = level.vec3offset(offsetPos, shooterPos);
		
		// Get velocity
		vector3 aimpos;
		if(crosshairConverge)
		{
			FLineTraceData lt;
			LineTrace(a, PLAYERMISSILERANGE, p, 0, ToM_Utils.GetPlayerAtkHeight(player.mo), 0, data:lt);
			double projrad = GetDefaultByType(proj).radius;			
			aimPos = (lt.HitLocation.xy - lt.HitDir.xy*projrad, lt.HitLocation.z);
			
			//Spawn("ToM_DebugSpot", aimPos);
		
			vector3 aimAngles = level.SphericalCoords(offsetPos, aimPos, (a, p));
			
			a -= aimAngles.x;
			p -= aimAngles.y;
		}
		
		mat = ToM_GM_Matrix.fromEulerAngles(a, p, r);
		mat = mat.multiplyVector3((1.0,0,0));
		
		vector3 projVel = mat.asVector3(false) * GetDefaultByType(proj).Speed;
		
		// Spawn projectile
		let proj = Spawn(proj, offsetPos);
		if(proj)
		{
			proj.angle = a;
			proj.pitch = p;
			proj.roll = r;
			proj.vel = projVel;
			proj.target = self;
			if (proj.seesound && Level.IsPointInLevel(proj.pos) && proj.pos == proj.pos)
			{
				proj.A_StartSound(proj.seesound);
			}
		}
		return proj;
	}
	
	double GetBaseZoom()
	{
		return owner.CountInv("ToM_GrowthPotionEffect") ? ToM_GrowthPotionEffect.GROWZOOM : 1;
	}

	const SWING_MaxIDs = 50;
	const SWING_SoundStagger = 15;
	protected ToM_SwingController swingdata[SWING_MaxIDs];
	protected array <Actor> swingVictims; //actors hit by the attack
	protected int swingSndCounter; //delay the attack sound

	// Set up the swing: initial coords and the step:
	action void A_PrepareSwing(double startX, double startY, int id = 0)
	{
		id = Clamp(id, 0, SWING_MaxIDs);
		invoker.swingVictims.Clear();
		invoker.swingdata[id] = ToM_SwingController.Create((startX, startY));
		invoker.swingSndCounter = 0;
	}
	
	// Do the attack and move the offset one step as defined above:
	action Actor, Actor A_SwingAttack(int damage,
							double stepX, double stepY,
							double range = 0,
							class<Actor> pufftype = null,
							color trailcolor = 0xFFFFFFFF,
							double trailalpha = 1.0,
							double trailsize = 12,
							int trailtics = 6,
							EParticleBeamStyle style = PBS_Solid,
							ERenderStyle rstyle = STYLE_Shaded,
							String texture = "LEGYA0",
							name decaltype = 'none',
							int id = 0)
	{
		id = Clamp(id, 0, SWING_MaxIDs);
		if (range == 0) range = self.MeleeRange;
		if (CountInv('ToM_GrowthPotionEffect'))
		{
			range *= 1.2;
		}
		ToM_SwingController data = invoker.swingdata[id];
		if (!data)
		{
			Console.Printf("\cgSwing data:\c- Controller \cd%d\c- does not exist. Aborting.", id);
			return null, null;
		}
		Vector2 flatOfs = data.ofs;
		Quat view = Quat.FromAngles(angle, pitch, roll);
		Quat ofs = Quat.FromAngles(flatOfs.x, flatOfs.y, 0);
		Quat res = view * ofs;
		Vector3 dir = res * (1,0,0);
		double aimYaw = atan2(dir.y, dir.x);
		double aimPitch = -asin(dir.z);
	
		FLineTraceData hit;
		LineTrace(
			aimYaw, 
			range, 
			aimPitch, 
			TRF_NOSKY|TRF_SOLIDACTORS, 
			ToM_Utils.GetPlayerAtkHeight(PlayerPawn(self)), 
			data: hit
		);

		// Debug spot:
		if (tom_debugmessages)
		{
			let spot = Spawn("ToM_DebugSpot", hit.hitlocation);
			spot.A_SetHealth(1);
			spot.scale *= 0.4;
			if (damage > 0)
			{
				spot.SetShade(0xFFFF0000);
				spot.scale *= 1.5;
			}
		}

		Actor victim;
		Actor puff;
		Vector3 hitnormal = ToM_Utils.GetNormalFromTrace(hit);
		Vector3 puffpos = hit.hitlocation;
		if (damage > 0)
		{
			int type;
			[type, victim] = ToM_Utils.GetHitType(hit);

			if (pufftype && type != ToM_Utils.HT_None)
			{
				puff = Spawn(pufftype, puffpos, ALLOW_REPLACE);
				if (puff)
				{
					if (hit.hittype == TRACE_HitWall)
					{
						puffpos += hitnormal * puff.radius;
					}
					else if (hit.hittype == TRACE_HitCeiling)
					{
						puffpos += hitnormal * puff.height;
					}
					else if (hit.hittype == TRACE_HitFloor)
					{
						puffpos.z += 1;
					}
					puff.SetOrigin(puffpos, false);
					
					puff.target = self;
					puff.A_Face(self, 0, 0);
					puff.tracer = victim;
					if (type == ToM_Utils.HT_ShootableThing)
					{
						puff.A_StartSound(puff.seesound);
					}
				}
			}
			
			// Do this if we hit geometry:
			if (puff && type == ToM_Utils.HT_Solid && invoker.swingSndCounter <= 0)
			{
				invoker.swingSndCounter = SWING_SoundStagger;
				puff.A_StartSound(puff.attacksound, CHAN_AUTO);
				if (decaltype != 'none')
				{
					puff.A_SprayDecal(decaltype, 8, direction: -hitnormal);
				}
				let tompuff = ToM_BasePuff(puff);
				if (tompuff)
				{
					tompuff.SpawnPuffEffects(hitnormal, puffpos);
				}
			}
			
			// Do this if we hit an actor:
			else if (type == ToM_Utils.HT_ShootableThing && victim && invoker.swingVictims.Find(victim) == invoker.swingVictims.Size())
			{
				invoker.swingVictims.Push(victim);
				victim.DamageMobj(puff? puff : self, self, damage, 'normal');
				/*if (fleshsound)
				{
					A_StartSound(fleshsound, CHAN_WEAPON);
				}*/
				// Bleed:
				if (!victim.bNOBLOOD)
				{
					victim.TraceBleed(damage, self);
					victim.SpawnBlood(hit.HitLocation, AngleTo(victim), damage);
				}
			}
		}
		
		// Add a step:
		data.Update(flatofs + (stepX, stepY), hit.HitLocation);

		Vector3 from = data.prevPos;
		Vector3 to = data.pos;
		if (from != (0,0,0))
		{
			ToM_Utils.DrawParticlesFromTo(
				from, to, 
				density:	trailsize * 0.1,
				size:		trailsize,
				alpha:		trailalpha,
				lifetime:	trailtics,
				texture:	texture,
				pcolor:		trailcolor,
				renderstyle: rstyle,
				style:		style);
		}

		return victim, puff;
	}

	action void A_PlayerAttackAnim(int animTics, Name animName, double framerate = -1, int startFrame = -1, int loopFrame= -1, int endFrame = -1, int interpolateTics = -1, int flags = 0)
	{
		let player = self.player;
		let alice = ToM_AlicePlayer(player.mo);
		if (alice)
		{
			alice.SetState(alice.MissileState);
			alice.A_SetTics(animTics);
			alice.SetAnimation(animName, framerate, startFrame, loopFrame, endFrame, interpolateTics, flags);
		}
	}
	
	action void A_AttackZoom(double step = 0.001, double limit = 0.03, double jitter = 0.002)
	{
		if (!player)
			return;
		
		let weap = player.readyweapon;
		if (!weap)
			return;

		invoker.atkzoom = Clamp(invoker.atkzoom + step, 0, limit);
		double targetZoom = invoker.atkzoom;
		if (targetZoom >= limit)
			targetZoom += frandom[atkzoom](-jitter, jitter);
		
		weap.FOVScale = 1 + targetZoom;
	}
	
	action void A_ResetZoom(double step = 0.005)
	{
		if (!player)
			return;
		
		let weap = player.readyweapon;
		if (!weap)
			return;
		
		invoker.atkzoom = Clamp(invoker.atkzoom - step, 0, 1);
		weap.FOVScale = Clamp(1 + invoker.atkzoom, 1, weap.FOVScale);
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

	//A variation on GetPlayerInput with a more convenient syntax
	action bool PressingAttackButton(int btnCheck = PAB_AUTO, int holdCheck = PAB_ANY) 
	{
		if (!player)
			return false;
		//get the button:
		int button;
		switch (btnCheck) 
		{
		case PAB_AUTO:
			button = invoker.bAltFire ? BT_ALTATTACK : BT_ATTACK;
			break;
		case PAB_PRIMARY:
			button = BT_ATTACK;
			break;
		case PAB_SECONDARY:
			button = BT_ALTATTACK;
			break;
		}
		
		//check if pressed now:
		bool pressed = (player.cmd.buttons & button);
		//check if it was pressed during previous tic:
		bool held = (player.oldbuttons & button); 
		
		switch (holdCheck) 
		{
		case PAB_HELDONLY: //true if held and not pressed
			return held;
			break;
		case PAB_NOTHELD: //true if not held, only pressed
			return !held && pressed;
			break;
		case PAB_HELD: //true if held and pressed
			return held && pressed;
			break;
		}
		return pressed; //true if pressed, ignore held check
	}
	
	action bool A_CheckAmmo(bool secondary = false, int amount = -1) {
		if (A_CheckInfiniteAmmo())
			return true;
		
		let tAmmo = secondary ? invoker.ammo2 : invoker.ammo1;
		if (!tAmmo)
			return true; //this weapon doesn't use ammo at all
		
		//check for default ammouse value if -1, otherwise check for specified:
		if (amount <= -1) 
		{
			amount = secondary ? invoker.ammouse2 : invoker.ammouse1;
		}
		
		if (tAmmo.amount < amount)
		{
			return false;
		}
		
		return true;
	}
	
	action bool A_CheckInfiniteAmmo() 
	{
		return (sv_infiniteammo || FindInventory("PowerInfiniteAmmo", true) );
	}
	
	/*	This function staggers randomizes offsets of a PSprite
		staggering the randomization over a few tics, so that it
		can be used for randomized shaking, but smoother than if it
		were called every tic.
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
	// to default values.
	// In conjuction with ToM_PspResetController allows to
	// stagger this process over multiple tics
	// (see pspcontrol array and Tick())
	action void A_ResetPSprite(int layer = 0, int staggertics = 0)
	{
		// If using default value, interpret as calling layer
		int tlayer = layer == 0 ? OverlayID() : layer;
		
		let psp = player.FindPSprite(tlayer);
		if (!psp)
		{
			if (ToM_debugmessages > 1)
				console.printf("PSprite %d doesn't exist", tlayer);
			return;
		}
		
		// If this is main layer (PSP_WEAPON), or an
		// overlay that doesn't have bADDWEAPON,
		// the target offsets are (0, 32).
		// Otherwise they're (0,0):
		vector2 tofs = (0, 0);
		if (tlayer == PSP_WEAPON || psp.bAddWeapon == false)
			tofs.y = WEAPONTOP;
		
		// If stagger tics is 1 or fewer, simply reset everything:
		if (staggertics <= 1)
		{
			A_StopPSpriteReset(tlayer);
			A_OverlayOffset(tlayer, tofs.x, tofs.y);
			A_OverlayRotate(tlayer, 0);
			A_OverlayScale(tlayer, 1, 1);
			return;
		}
		
		// Otherwise create a ToM_PspResetController and pass
		// the current PSPrite and target values to it:
		
		let cont = ToM_PspResetController(ToM_PspResetController.Create(psp, staggertics, tofs));
		if (!cont)
		{
			if (ToM_debugmessages)
				console.printf("Error: Couldn't create ToM_PspResetController", tlayer);
			return;
		}
		
		if (invoker.pspcontrols.Find(cont) == invoker.pspcontrols.Size())
		{
			if (tom_debugmessages > 1)
			{
				console.printf("Pushing layer %d into pspcontrols array. Tics: %d, target offsets: (%d, %d)", tlayer, staggertics, tofs.x, tofs.y);
			}
			invoker.pspcontrols.Push(cont);
		}
	}
	
	// This stops the process of the calling layer
	// being reset, so that new offsets could be easily
	// applied on top.
	action void A_StopPSpriteReset(int layer = 0, bool dropRightThere = false)
	{
		int tlayer = layer == 0 ? OverlayID() : layer;
		let psp = player.FindPSprite(tlayer);
		
		if (!psp)
		{
			if (ToM_debugmessages > 1)
				console.printf("PSprite %d doesn't exist", tlayer);
			return;
		}
		
		for (int i = invoker.pspcontrols.Size() - 1; i >= 0; i--)
		{
			if (invoker.pspcontrols[i] && invoker.pspcontrols[i].GetPSprite() == psp)
			{
				if (ToM_debugmessages > 1)
					console.printf("Removing psp controller for PSprite %d", tlayer);
				if (dropRightThere)
					invoker.pspcontrols[i].StopReset();
				else
					invoker.pspcontrols[i].Destroy();
				invoker.pspcontrols.Delete(i);
				return;
			}
		}
	}	
	
	/*
		A version of A_OverlayRotate that allows additive rotation
		without intepolation. Necessary because interpolation breaks 
		when combined with animation of differently-sized frames.
	*/
	action void A_RotatePSprite(int layer = 0, double degrees = 0, int flags = 0) 
	{
		int tlayer = layer == 0 ? OverlayID() : layer;
		
		let psp = player.FindPSprite(tlayer);
		if (!psp)
			return;
		double targetAngle = degrees;
		if (flags & WOF_ADD)
			targetAngle += psp.rotation;
		A_OverlayRotate(tlayer, targetAngle);
	}
	
	// Same but for scale:
	action void A_ScalePSprite(int layer = 0, double wx = 1, double wy = 1, int flags = 0) 
	{
		int tlayer = layer == 0 ? OverlayID() : layer;
		
		let psp = player.FindPSprite(tlayer);
		if (!psp)
			return;
		vector2 targetScale = (wx,wy);
		if (flags & WOF_ADD)
			targetScale += psp.scale;
		A_OverlayScale(tlayer, targetScale.x, targetScale.y);
	}
	
	action void A_CopyPSprite(int layer)
	{
		if (!player) return;
		let from = player.FindPSprite(OverlayID());
		if (!from) 
			return;
		
		let to = player.GetPSprite(layer);
		to.translation = from.translation;
		to.x = from.x;
		to.y = from.y;
		to.Coord0 = from.Coord0;
		to.Coord1 = from.Coord1;
		to.Coord2 = from.Coord2;
		to.Coord3 = from.Coord3;
		to.pivot = from.pivot;
		to.bPivotPercent = from.bPivotPercent;
		to.bInterpolate = from.bInterpolate;
		to.scale = from.scale;
		to.rotation = from.rotation;
		//A_OverlayRenderstyle(layer, from.GetRenderstyle());
		to.alpha = from.alpha;
		to.bAddWeapon = from.bAddWeapon;
		to.bMirror = from.bMirror;
		to.bFlip = from.bFlip;
		to.bAddBob = from.bAddBob;
		to.sprite = from.sprite;
		to.frame = from.frame;
	}
	
	action void A_SpawnPSParticle(stateLabel statename, bool bottom = false, int density = 1, double xofs = 0, double yofs = 0, int chance = 100, int maxlayers = 50)
	{
		if (chance < 100 && random[pspart](0, 100) > chance)
			return;
		state tstate = ResolveState(statename);
		if (!tstate)
			return;
		int startlayer = bottom ? APSP_BottomParticle : APSP_TopParticle;
		for (int i = 0; i < density; i++) 
		{
			int layer = startlayer + (bottom ? invoker.particleLayer_bottom : invoker.particleLayer_top);
			player.SetPSprite(layer, tstate);
			A_OverlayOffset(layer,frandom[pspart](-xofs,xofs),frandom[pspart](-yofs, yofs));
			if (bottom)
			{
				invoker.particleLayer_bottom++;
				if (invoker.particleLayer_bottom >= maxlayers)
				{
					invoker.particleLayer_bottom = 0;
				}
			}
			else
			{
				invoker.particleLayer_top++;
				if (invoker.particleLayer_top >= maxlayers)
				{
					invoker.particleLayer_top = 0;
				}
			}
			//Console.Printf("Creating layer %d", layer);
		}
	}
	
	action void A_ClearPSParticles(bool bottom = false, int maxlayers = 50)
	{
		int startlayer = bottom ? APSP_BottomParticle : APSP_TopParticle;
		A_ClearOverlays(startlayer, startlayer + maxlayers);
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
			{
				psp.Destroy();
			}
		}
	}
	
	action void A_PSPMakeTranslucent(int layer = 0, double alpha = 1.0)
	{
		if (!player)
			return;
		int tlayer = layer == 0 ? OverlayID() : layer;
		A_OverlayFlags(layer, PSPF_Renderstyle|PSPF_ForceAlpha, true);
		A_OverlayRenderstyle(layer, Style_Translucent);
		A_OverlayAlpha(layer, alpha);
	}
	
	action actor A_FireArchingProjectile(class<Actor> missiletype, double angle = 0, bool useammo = true, double spawnofs_xy = 0, double spawnheight = 0, int flags = 0, double pitch = 0) 
	{
		if (!self || !self.player) 
			return null;
		double pitchOfs = pitch;
		if (pitch != 0 && self.pitch < 0)
			pitchOfs = ToM_Utils.LinearMap(self.pitch, 0, -90, pitchOfs, 0);
		return A_FireProjectile(missiletype, angle, useammo, spawnofs_xy, spawnheight, flags, pitchOfs);
	}
	
	override void BeginPlay()
	{
		super.BeginPlay();
		swayTics = -1;
		s_fire = FindState("Fire");
		s_hold = FindState("Hold");
		s_altfire = FindState("AltFire");
		s_althold = FindState("AltHold");
		s_idle = FindState("IdleAnim");
	}
	
	// I don't want weapon pickups to be too common due to their
	// somewhat dramatic appearance. If all players already have 
	// this weapon, and this weapon uses ammo, we'll destroy it 
	// and spawn ammo for it instead.
	// If it doesn't use ammo, we'll just destroy it directly,
	// since there's no need to spawn duplicates of weapons 
	// that don't consume ammo.
	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		if (bTOSSED && ToM_Utils.CheckPlayersHave(self.GetClass(), checkAll: true))
		{
			if (ammotype1)
			{
				let am = Ammo(Spawn(ammotype1, pos));
				if (am)
				{
					am.bTOSSED = true;
					am.vel = vel;
				}
				Destroy();
				return;
			}
		}
		let handler = ToM_MainHandler(EventHandler.Find("ToM_MainHandler"));
		if (handler && handler.mapweapons.Find(GetClass()) == handler.mapweapons.Size())
		{
			handler.mapweapons.Push(GetClass());
		}
	}
	
	override void DoEffect()
	{
		super.DoEffect();
		
		if (!owner || !owner.player)
			return;
		
		if (swingSndCounter)
		{
			swingSndCounter--;
		}
			
		let weap = owner.player.readyweapon;
		
		if (!weap || weap != self)
			return;
		
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
	
		/*for (int i = pspcontrols.Size() - 1; i >= 0; i--)
		{
			if (pspcontrols[i])
			{
				pspcontrols[i].DoResetStep();
			}
			else
			{
				pspcontrols.Delete(i);
			}	
		}*/
	}
	
	override void Tick()
	{
		super.Tick();
		if (owner || isFrozen() || bTossed)
			return;
		
		if (GetAge() % 10 == 0)
			canSeePlayer = CheckPlayerSights(true);
		if (!canSeePlayer)
			return;
			
		if (players[consoleplayer].mo /*&& players[consoleplayer].mo.CountInv(self.GetClass()) <= 0 */)
		{
			TextureID tex = TexMan.CheckForTexture("ACWEZ0");
			double size = TexMan.GetSize(tex);
			for (int i = 0; i < 2; i++)
			{
				FSpawnParticleParams pp;
				pp.texture = tex;
				pp.color1 = "";
				pp.lifetime = 20;
				pp.size = size*0.25;
				pp.sizestep = -(pp.size / pp.lifetime);
				pp.startalpha = 1;
				pp.fadestep = -1;
				pp.startroll = frandom[pickupPartvis](0,360);
				pp.rollvel = 5 * randompick[pickupPartvis](-1,1);
				pp.flags = SPF_FULLBRIGHT|SPF_ROLL;
				pp.style = Style_Add;
				pp.pos.x = pos.x + frandom[pickupPartvis](-radius, radius);
				pp.pos.y = pos.y + frandom[pickupPartvis](-radius, radius);
				pp.pos.z = pos.z + frandom[pickupPartvis](1, 4);
				pp.vel.z = frandom[pickupPartvis](0.4, 4);
				Level.SpawnParticle(pp);
			}
		}
	}

	States {
	Spawn:
		M000 A 1
		{
			/*roll = model_roll;
			pitch = model_pitch;
			angle = model_angle;*/
		}
		loop;
	}
}

class ToM_SwingController play
{
	Vector2 ofs;
	Vector3 pos;
	Vector3 prevPos;

	static ToM_SwingController Create(Vector2 ofs)
	{
		ToM_SwingController ctrl = New('ToM_SwingController');
		ctrl.ofs = ofs;
		return ctrl;
	}

	void Update(Vector2 ofs, Vector3 pos = (0,0,0))
	{
		self.ofs = ofs;
		self.prevPos = self.pos;
		self.pos = pos;
	}
}

class ToM_BasePuff : ToM_BaseActor
{
	int puff_particles;
	double puff_partvel;
	double puff_gravity;
	double puff_partsize;
	color puff_partcolor;
	name puff_texture;

	property ParticleAmount : puff_particles;
	property ParticleSpeed : puff_partvel;
	property ParticleGravity : puff_gravity;
	property ParticleSize : puff_partsize;
	property ParticleColor : puff_partcolor;
	property ParticleTexture : puff_texture;

	Default
	{
		+NOBLOCKMAP
		+NOGRAVITY
		+FORCEXYBILLBOARD
		+PUFFGETSOWNER
		+DONTSPLASH
		radius 1;
		height 1;
		ToM_BasePuff.ParticleAmount 0;
		ToM_BasePuff.ParticleSpeed 3;
		ToM_BasePuff.ParticleSize 12;
		ToM_BasePuff.ParticleColor 0;
		ToM_BasePuff.ParticleGravity 0.5;
	}

	virtual void SpawnPuffEffects(Vector3 dir, Vector3 origin = (0,0,0))
	{
		if (puff_particles <= 0 || waterlevel > 0) return;

		FSpawnParticleParams p;
		if (puff_texture)
		{
			TextureID tex = TexMan.CheckForTexture(puff_texture);
			if (tex && tex.IsValid())
			{
				p.texture = tex;
				p.style = STYLE_Add;
			}
			// neither texture nor color are valid:
			else if (puff_partcolor == 0)
			{
				return;
			}
		}
		if (puff_partcolor == 0)
		{
			p.color1 = "";
		}
		p.flags = SPF_FULLBRIGHT;
		p.startalpha = 1.0;
		if (origin == (0,0,0))
		{
			origin = pos + (0,0,height*0.5);
		}
		p.pos = origin;
		double yaw = atan2(dir.y, dir.x);
		double pch = -atan2(dir.z, dir.xy.Length());
		Quat orientation = Quat.FromAngles(yaw, pch, 0.0);
		for (int i = round(puff_particles * frandom[puffvis](0.8, 1.2)); i > 0; i--)
		{
			if (puff_partcolor != 0)
			{
				p.color1 = color(
					Clamp(int(puff_partcolor.r * frandom[puffvis](0.7, 1.1)), 0, 255),
					Clamp(int(puff_partcolor.g * frandom[puffvis](0.7, 1.1)), 0, 255),
					Clamp(int(puff_partcolor.b * frandom[puffvis](0.7, 1.1)), 0, 255)
				);
			}
			p.lifetime = random[puffvis](20, 30);
			p.size = puff_partsize * frandom[puffvis](0.8, 1.2);
			p.sizestep = -(p.size / p.lifetime);
			double v = 20;
			Quat offset = Quat.FromAngles(frandom[puffvis](-v, v), frandom[puffvis](-v, v), 0.0);
			p.vel = orientation * offset * (puff_partvel * frandom[puffvis](0.8, 1.2), 0.0, 0.0);
			p.accel.xy = (p.vel.xy / -p.lifetime) * 0.5;
			p.accel.z = gravity * -puff_gravity;
			Level.SpawnParticle(p);
		}
	}

	States
	{
	Spawn:
		TNT1 A 1; //BAl1 A 10 bright NoDelay A_SetScale(1.0 / TexMan.GetSize(curstate.GetSpriteTexture(0)));
		stop;
	}
}

class ToM_NullPuff : ToM_NullActor
{
	Default
	{
		+PUFFGETSOWNER
		+BLOODLESSIMPACT
		+DONTSPLASH
		+NODECAL
	}
}
	

//Base projectile class that can produce relatively solid trails:
Class ToM_Projectile : ToM_BaseActor abstract 
{
	protected bool ShouldActivateLines;
	property ShouldActivateLines : ShouldActivateLines;
	protected bool dead;
	protected state s_spawn; //pointer to Spawn label
	protected state s_death;
	protected state s_crash;
	
	class<Actor> trailactor;
	class<ToM_ProjFlare> flareactor;
	ToM_ProjFlare flare;

	//protected bool mod; //affteced by Weapon Modifier
	protected vector3 spawnpos;
	protected bool farenough;	
	TextureID trailtex;
	vector3 prevvel;
	color flarecolor;
	double flarescale;
	double flarealpha;
	color trailcolor;
	string trailTexture;
	double trailscale;
	double trailalpha;
	double trailfade;
	double trailvel;
	double trailz;
	double trailshrink;
	int trailstyle;
	
	double wrot;
	
	property trailactor : trailactor;
	property flareactor : flareactor;
	property flarecolor : flarecolor;
	property flarescale : flarescale;
	property flarealpha : flarealpha;
	property trailcolor : trailcolor;
	property trailTexture : trailTexture;
	property trailalpha : trailalpha;
	property trailscale : trailscale;
	property trailfade : trailfade;
	property trailshrink : trailshrink;
	property trailvel : trailvel;
	property trailz : trailz;
	property trailstyle : trailstyle;
	
	Default 
	{
		projectile;
		height 6;
		radius 6;
		+ROLLSPRITE
		ToM_Projectile.flareactor "ToM_ProjFlare";
		ToM_Projectile.flarescale 0.065;
		ToM_Projectile.flarealpha 0.7;
		ToM_Projectile.trailscale 0.04;
		ToM_Projectile.trailalpha 0.4;
		ToM_Projectile.trailfade 0.1;
		ToM_Projectile.trailactor "";
		ToM_Projectile.trailstyle STYLE_Translucent;
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

	// Prevent gravity changes underwater:
	override void FallAndSink(double grav, double oldfloorz) 
	{
		if (pos.z > floorz && !bNOGRAVITY)
		{
			vel.z -= grav;
		}
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
		return (victim.bSHOOTABLE && !victim.bNONSHOOTABLE && !victim.bNOCLIP && !victim.bNOINTERACTION && !victim.bINVULNERABLE && !victim.bDORMANT && !victim.bNODAMAGE && !victim.bSPECTRAL);
	}
	
	bool FireLineActivator()
	{
		if (!target)
			return false;
					
		LineAttack(angle, PLAYERMISSILERANGE, pitch, 0, 'Normal', tom_debugmessages > 1 ? "ToM_DebugSpot" : "ToM_NullPuff", LAF_TARGETISSOURCE, offsetforward: radius);
		
		return true;
	}
	
	override void PostBeginPlay() 
	{
		super.PostBeginPlay();
		s_spawn = FindState("Spawn");
		s_death = FindState("Death");
		s_crash = FindState("Crash");
		//tom_main = target && PKWeapon.CheckWmod(target);
		spawnpos = pos;
		if (!flarecolor || !flareactor)
			return;
		flare = ToM_ProjFlare( Spawn(flareactor,pos) );
		if (flare) 
		{
			flare.master = self;
			flare.fcolor = flarecolor;
			flare.fscale = flarescale;
			flare.falpha = flarealpha;
		}
	}

	// Spawns a particle or actor-based trail:
	virtual void SpawnTrail(vector3 ppos)
	{
		// Actor based:
		if (trailactor) {
			vector3 tvel;
			if (trailvel != 0)
			{
				tvel = (
					frandom[trailfx](-trailvel,trailvel),
					frandom[trailfx](-trailvel,trailvel),
					frandom[trailfx](-trailvel,trailvel)
				);
			}
			let trl = Spawn(trailactor,ppos+(0,0,trailz));
			if (trl)
			{
				trl.master = self;
				let trlflr = ToM_BaseFlare(trl);
				if (trlflr)
				{
					trlflr.fcolor = trailcolor;
					trlflr.fscale = trailscale;
					trlflr.falpha = trailalpha;
					if (trailactor == 'ToM_BaseFlare')
						trlflr.A_SetRenderstyle(alpha,Style_Shaded);
					if (trailfade != 0)
						trlflr.fade = trailfade;
					if (trailshrink != 0)
						trlflr.shrink = trailshrink;
				}
				trl.vel = tvel;
			}
		}
		// Particle based:
		else
		{
			FSpawnParticleParams trail;
			CreateParticleTrail(trail, ppos, trailvel);
			Level.SpawnParticle(trail);
		}
	}

	// Spawns a particle-based trail. This uses the same
	// projectile values as actor-based trails but adapts
	// them so that they match the appearance of actor-based
	// ones in terms of size and such:
	virtual void CreateParticleTrail(out FSpawnParticleParams trail, vector3 ppos, double pvel, double velstep = 0) {
		trail.flags = SPF_ROLL|SPF_REPLACE;

		// determine if this is a textured particle
		// update the texture if the trailTexture value changes
		// (for projectiles that randomize the particle texture dynamically)
		if (!trailtex || (trailTexture && trailTexture != default.trailTexture))
			trailtex = TexMan.CheckForTexture(trailTexture);
			
		bool isTextured = trailtex.IsValid();

		// if textured, apply the texture:
		if (isTextured)
		{
			trail.texture = trailtex;
		}

		// apply color if provided:
		if (trailcolor)
		{
			// MUST BE SHADED if we're using textured particles,
			// otherwise the colors get weird for some reason:
			trail.style = (trailstyle == STYLE_Translucent) ? STYLE_Shaded : trailstyle;
			trail.color1 = color(trailcolor);
		}

		if (trail.style == STYLE_Shaded || trail.style == STYLE_AddShaded)
		{
			trail.flags |= SPF_FULLBRIGHT;
		}

		// add vertical offset to position:
		trail.pos = (ppos.x, ppos.y, ppos.z + trailz);
		// lifetime is calculated based on alpha and fadefactor:
		trail.lifetime = ceil(trailalpha / trailfade);
		// apply random velocity if pvel is not 0:
		if (pvel != 0)
		{
			trail.vel = (
				frandom[trailfx](-pvel,pvel),
				frandom[trailfx](-pvel,pvel),
				frandom[trailfx](-pvel,pvel)
			);
		}
		// apply acceleration if provided:
		if (velstep > 0)
			trail.accel = trail.vel * velstep;

		// apply trailalpha
		trail.startalpha = trailalpha;
		trail.fadestep = -1;

		// scale the particle. Since particle size = pixel size,
		// scale the texture accordingly:
		if (isTextured)
			trail.size = TexMan.GetSize(trailtex) * trailscale;
		// if not textured, 256 is used as a base value for scaling,
		// because the previously used default trail texture is 
		// 256x256, so trailscale was historically defined in 
		// projectiles with that in mind:
		else
			trail.size = 256. * trailscale;

		// Add size step if trailshrink is defined:
		if (trailshrink != 0)
		{
			trail.sizestep = trail.size * (trailshrink - 1);
		}
	}

	//An override initially by Arctangent that spawns trails like FastProjectile does it:
	override void Tick () 
	{
		Vector3 oldPos = self.pos;
		Super.Tick();
		if (isFrozen())
			return;
			
		/*if (ShouldActivateLines && !dead && ( InStateSequence(curstate, s_death) || InStateSequence(curstate, s_crash)))
		{
			dead = true;
			FireLineActivator();
		}*/
		
		// Continue only if either a color is specified
		// ir the trailactor is a custom actor:
		if (!trailcolor && !trailactor)
			return;
		
		if (GetParticlesQuality() <= TOMPART_MIN)
			return;
			
		if (oldPos == self.pos || vel.length() == 0)
			return;

		if (!farenough && target)
		{
			if (level.Vec3Diff(pos, spawnpos).length() < vel.length() + target.radius)
				return;
			farenough = true;
		}

		// Get difference between current position and position from
		// previous tick, split it into chunks and spawn a particle
		// at every inbetween positiong:
		Vector3 path = level.vec3Diff( self.pos, oldPos );
		// This determines how far apart the particles areL
		double distance = path.length() / clamp(int(trailscale * 50),1,8); 
		Vector3 direction = path / distance;
		int steps = int( distance );
		for(int i = 0; i < steps; i++)
		{
			SpawnTrail(oldpos);
			oldPos = level.vec3Offset(oldPos, direction);
		}
	}
}

class ToM_PiercingProjectile : ToM_Projectile
{
	array <Actor> hitvictims;
	
	virtual void HitVictim(Actor victim)
	{}
	
	virtual bool CheckValid(Actor victim)
	{
		return (!target || victim != target) && victim.bSHOOTABLE && victim.health > 0;
	}
	
	override int SpecialMissileHit(actor victim)
	{
		if (victim)
		{
			if (!CheckValid(victim))
				return 1;
			
			if (hitvictims.Find(victim) == hitvictims.Size())
			{
				hitvictims.Push(victim);
				HitVictim(victim);
			}
			return 1;
		}
		
		return 1;
	}
}
	

// A base projectile class that can stick into walls and planes.
// It'll move with the sector if it hit a moving one (e.g. door/platform).
// Ported from Painslayer, used by thrown Vorpal Knife and Playing Cards.
Class ToM_StakeProjectile : ToM_Projectile 
{
	// Pos where the flight ended:
	protected vector3 endspot;
	// Records if a plane was hit (see EHitplanes):
	protected int hitplane;
	// 3D floor to stick into, if any:
	protected transient F3DFloor hit_3dfloor;
	// Line to stick into, if any:
	protected Line hit_line;
	// Non-monster object to stick into, if any:
	protected actor stickobject; 
	protected double stickAngleOfs;
	protected double stickDeadPitch;
	// Plane to stick  into, if any
	// (has to be transient, since SecPlane 
	// can't be recorded into save games):
	protected transient SecPlane stickplane;
	// The point at the line the stake collided with:
	protected vector2 sticklocation; 
	// How far the stake is from the nearest ceiling
	// or floor (depending on whether it hit top or 
	// bottom part of the line):
	protected double stickoffset;
	// ZAtPoint below stake:
	protected double topz;
	// ZAtPoint above stake:
	protected double botz; 
	// The fake corpse that will be pinned to a wall:
	actor pinvictim;
	// The offset from the center of the stake to 
	// the victim's corpse center:
	protected double victimofz; 
	// A non-transient bool that is set to true if
	// the stake hit a plane. Upon save load it's
	// checked by a static event handler that calls
	// StickToWall() on all stakes that have this set
	// to true, to reattach them to planes:
	bool stuckToSecPlane;
	
	enum EHitplanes
	{
		PLANE_NONE,
		PLANE_FLOOR,
		PLANE_CEILING,
	}
	
	Default 
	{
		+MOVEWITHSECTOR
		+NOEXTREMEDEATH
	}
	
	void SetEndSpot(vector3 spot) 
	{
		endspot = spot;
	}
	
	// This function is called when the projectile 
	// dies and checks if it hit something:
	virtual void StickToWall() 
	{	
		string myclass = GetClassName();
		
		if (ShouldActivateLines)
		{
			FireLineActivator();
			if (tom_debugmessages)
				console.printf("%s is firing a line activator", myclass);
		}
		
		// Disable actor collision upon sticking into a wall.
		// Checking for this flag is this actor's primary
		// way to check if it has hit a wall yet or not:
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
			return;
		}
		
		//use linetrace to get information about what we hit
		FLineTraceData trac;
		LineTrace(angle,64,pitch,TRF_NOSKY|TRF_THRUACTORS|TRF_BLOCKSELF,data:trac);
		hit_3dfloor = trac.Hit3DFloor;
		hit_Line = trac.HitLine;		
		sticklocation = trac.HitLocation.xy;
		topz = CurSector.ceilingplane.ZatPoint(sticklocation);
		botz = CurSector.floorplane.ZatPoint(sticklocation);
		
		//if hit floor/ceiling, we'll attach to them:
		if (trac.HitLocation.z >= topz) 
		{
			hitplane = PLANE_CEILING;
			if (tom_debugmessages)
				console.printf("%s hit ceiling at at %d,%d,%d",myclass,pos.x,pos.y,pos.z);
		}
		else if (trac.HitLocation.z <= botz) 
		{
			hitplane = PLANE_FLOOR;
			if (tom_debugmessages)
				console.printf("%s hit floor at at %d,%d,%d",myclass,pos.x,pos.y,pos.z);
		}
		
		// If stuck in floor or ceiling, stop here:
		if (hitplane != PLANE_NONE)
			return;
			
		// 3D floor is easiest, so we start with it:
		if (hit_3dfloor) 
		{
			stuckToSecPlane = true;
			// we simply attach the stake to the 3D floor's
			// top plane, nothing else:
			F3DFloor flr = trac.Hit3DFloor;
			stickplane = flr.top;
			stickoffset = stickplane.ZAtPoint(sticklocation) - pos.z;
			if (tom_debugmessages)
				console.printf("%s hit a 3D floor at %d,%d,%d",myclass,pos.x,pos.y,pos.z);
			return;
		}
		//otherwise see if we hit a line:
		if (hit_Line) 
		{
			//check if the line is two-sided first:
			let tline = hit_Line;
			// if it's one-sided, it can't be a door/lift,
			// so don't do anything else:
			if (!tline.backsector) 
			{
				if (tom_debugmessages)
					console.printf("%s hit one-sided line, not doing anything else",myclass);
				return;
			}
			stuckToSecPlane = true;
			//if it's two-sided:
			//check which side we're on:
			int lside = ToM_Utils.PointOnLineSide(pos.xy,tline);
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
			if (tom_debugmessages)
				console.printf("%s hit the %s %s part of the line at %.1f,%1f,%1f",myclass,secpart,sside,pos.x,pos.y,pos.z);
		}
	}
	
	// Record a non-monster solid object the stake
	// runs into if there is one:
	override int SpecialMissileHit (Actor victim) 
	{
		if (victim != target && (victim.bSOLID || victim.bSHOOTABLE))
		{
			stickobject = victim;
			stickoffset = pos.z - stickobject.pos.z;
			stickAngleOfs = DeltaAngle(stickobject.angle, angle);
			stickDeadPitch = random[sticksfx](60,80);
			if (tom_debugmessages)
			{
				console.printf("%s hit %s at at %.1f, %.1f, %.1f", GetClassName(), stickobject.GetClassName(), pos.x,pos.y,pos.z);
			}
		}
		return -1;
	}
	
	// Virtual for breaking apart; child actors
	// override it to add debris or change the 
	// behavior:
	virtual void StakeBreak() 
	{
		if (tom_debugmessages)
			console.printf("%s destroyed at %.1f,%.1f,%.1f",GetClassName(), pos.x, pos.y, pos.z);
		if (self)
			Destroy();
	}
	
	override void Tick () 
	{
		super.Tick();
		// All stake-like projectiles need to face
		// their movement direction while in Spawn sequence:
		if (!isFrozen() && s_spawn && InStateSequence(curstate,s_spawn)) 
		{
			A_FaceMovementDirection(flags:FMDF_INTERPOLATE);
		}
		// Otherwise stake is dead, so we'll move it
		// alongside the object/plane it's supposed
		// to be attached to:
		if (bTHRUACTORS) 
		{
			// Attached to an actor:
			if (stickobject)
			{
				bool victimDead = (stickobject.bISMONSTER && stickobject.health <= 0);
				double vz = victimDead ? stickobject.height * 0.9 : stickoffset;
				SetOrigin(stickobject.pos + (0,0, vz), true);
				angle = stickobject.angle + stickAngleOfs;
				if (victimDead)
				{
					pitch = stickDeadPitch;
				}
			}
			
			// Attached to ceiling:
			else if (hitplane == PLANE_CEILING)
				SetZ(ceilingz);
			
			// Attached to floor:
			else if (hitplane == PLANE_FLOOR)
				SetZ(floorz);
			
			// Attached to a wall:
			else
			{		
				topz = CurSector.ceilingplane.ZAtPoint(pos.xy);
				botz = CurSector.floorplane.ZAtPoint(pos.xy);
				// Destroy the stake if it's run into ceiling/floor 
				// by a moving sector (e.g. a door opened, pulled 
				// the stake up and pushed it into the ceiling). 
				// Only do this if the stake didn't actually hit
				// a plane before that:
				if (pos.z >= topz-height || pos.z <= botz)
				{
					StakeBreak();
					return;
				}
				
				// Attached to a plane (hit a door/lift earlier):
				else if (stickplane) 
				{
					SetZ(stickplane.ZAtPoint(sticklocation) - stickoffset);
				}
			}
			
			/* (Painslayer feature)
			// and if there's a decorative corpse on the stake, 
			// move it as well:
			if (pinvictim)
				pinvictim.SetZ(pos.z + victimofz);
			*/
		}
	}
}

//Decorative explosion actor that spawns debris and stuff:
Class ToM_GenericExplosion : ToM_SmallDebris 
{
	int tics;
	int randomDebris;
	double randomDebrisVel;
	double randomDebrisScale;
	int explosiveDebris;
	double explosiveDebrisVel;
	double explosiveDebrisScale;
	int smokingDebris;
	double smokingDebrisVel;
	double smokingDebrisScale;
	int quakeIntensity;
	int quakeDuration;
	int quakeRadius;
	
	static ToM_GenericExplosion Create(
		vector3 pos, double scale = 0.5, int tics = 1,
		int randomdebris = 16, 
		double randomDebrisVel = 7, 
		double randomDebrisScale = 1,
		int smokingdebris = 12, 
		double smokingDebrisVel = 8, 
		double smokingDebrisScale = 1, 
		int explosivedebris = 0, 
		double explosiveDebrisVel = 10, 
		double explosiveDebrisScale = 1, 
		int quakeintensity = 3, 
		int quakeduration = 12, 
		int quakeradius = 220
	)
	{
		let exp = ToM_GenericExplosion(Spawn("ToM_GenericExplosion", pos));
		if (exp)
		{
			exp.scale = (scale, scale);
			exp.tics = abs(tics);
			exp.randomdebris = randomdebris ;
			exp.randomDebrisVel = randomDebrisVel ;
			exp.randomDebrisScale = randomDebrisScale ;
			exp.smokingdebris = smokingdebris ;
			exp.smokingDebrisVel = smokingDebrisVel ;
			exp.smokingDebrisScale = smokingDebrisScale ;
			exp.explosivedebris = explosivedebris ;
			exp.explosiveDebrisVel = explosiveDebrisVel ;
			exp.explosiveDebrisScale = explosiveDebrisScale ;
			exp.quakeintensity = quakeintensity ;
			exp.quakeduration = quakeduration ;
			exp.quakeradius = quakeradius;
		}
		return exp;
	}
	
	Default 
	{
		+NOINTERACTION
		+NOBLOCKMAP
		renderstyle 'add';
		+BRIGHT;
		alpha 1;
		scale 0.5;
	}
	
	override void PostBeginPlay() 
	{
		super.PostBeginPlay();
		double rs = scale.x * frandom[sfx](0.8,1.1)*randompick[sfx](-1,1);
		A_SetScale(rs);
		roll = random[sfx](0,359);
		A_Quake(quakeintensity,quakeduration,0,quakeradius,"");
		if (!CheckPlayerSights())
			return;
			
		if (GetParticlesQuality() <= TOMPART_MIN)
			return;
		
		if (randomdebris > 0) 
		{
			for (int i = int(randomdebris*frandom[sfx](0.7,1.3)); i > 0; i--) 
			{
				let debris = Spawn("ToM_RandomDebris",pos + (frandom[sfx](-8,8),frandom[sfx](-8,8),frandom[sfx](-8,8)));
				if (debris) 
				{
					double zvel = (pos.z > floorz) ? frandom[sfx](-randomDebrisVel,randomDebrisVel) : frandom[sfx](randomDebrisVel,randomDebrisVel*2);
					debris.vel = (frandom[sfx](-randomDebrisVel,randomDebrisVel),frandom[sfx](-randomDebrisVel,randomDebrisVel),zvel);
					debris.A_SetScale(0.5 * randomDebrisScale);
				}
			}
		}
		
		if (GetParticlesQuality() <= TOMPART_MED)
			return;
			
		if (smokingdebris > 0) 
		{
			for (int i = int(smokingdebris*frandom[sfx](0.7,1.3)); i > 0; i--) 
			{
				let debris = Spawn("ToM_SmokingDebris",pos + (frandom[sfx](-12,12),frandom[sfx](-12,12),frandom[sfx](-12,12)));
				if (debris) 
				{
					double zvel = (pos.z > floorz) ? frandom[sfx](-smokingDebrisVel / 2,smokingDebrisVel) : frandom[sfx](smokingDebrisVel / 2,smokingDebrisVel * 1.5);
					debris.vel = (frandom[sfx](-smokingDebrisVel,smokingDebrisVel),frandom[sfx](-smokingDebrisVel,smokingDebrisVel),zvel);
					debris.A_SetScale(smokingDebrisScale);
				}
			}
		}
		if (explosivedebris > 0) 
		{
			for (int i = int(explosivedebris*frandom[sfx](0.7,1.3)); i > 0; i--) 
			{
				let debris = Spawn("ToM_ExplosiveDebris",pos + (frandom[sfx](-12,12),frandom[sfx](-12,12),frandom[sfx](-12,12)));
				if (debris) 
				{
					double zvel = (pos.z > floorz) ? frandom[sfx](-explosiveDebrisVel / 2,explosiveDebrisVel) : frandom[sfx](explosiveDebrisVel / 2,explosiveDebrisVel * 1.5);
					debris.vel = (frandom[sfx](-explosiveDebrisVel,explosiveDebrisVel),frandom[sfx](-explosiveDebrisVel,explosiveDebrisVel),zvel);
					debris.A_SetScale(explosiveDebrisScale);
				}
			}
		}
	}
	States 
	{
	Spawn:
		BOM6 ABCDEFGHIJKLMNOPQRST 1 A_SetTics(tics);
		stop;
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
		return;
		////////////////		
		super.DoEffect();
		if (!owner || !owner.player || owner.player != players[consoleplayer] || !owner.player.readyweapon || owner.health <= 0)
			return;
				
		if (!ppawn) ppawn = PlayerPawn(owner);
		
		let weap = owner.player.readyweapon;
		if (!weap || weap.bMELEEWEAPON)
			return;
		
		FLineTracedata tr;
		double atkheight = ToM_Utils.GetPlayerAtkHeight(ppawn);
		//owner.LineTrace(owner.angle, 2048, owner.pitch, TRF_SOLIDACTORS, atkheight, data: tr);
		owner.LineTrace(owner.angle, 320, owner.pitch, TRF_THRUACTORS, atkheight, data: tr);
		console.printf("trace distance: %1.f", tr.Distance);
		
		/*let hitnormal = -tr.HitDir;
		if ( tr.HitType == TRACE_HitFloor ) {
			if ( tr.Hit3DFloor ) 
				hitnormal = -tr.Hit3DFloor.top.Normal;
			else 
				hitnormal = tr.HitSector.floorplane.Normal;
		}
		else if ( tr.HitType == TRACE_HitCeiling )    {
			if ( tr.Hit3DFloor ) 
				hitnormal = -tr.Hit3DFloor.bottom.Normal;
			else 
				hitnormal = tr.HitSector.ceilingplane.Normal;
		}
		else if ( tr.HitType == TRACE_HitWall ) {
			hitnormal = (-tr.HitLine.delta.y,tr.HitLine.delta.x,0).unit();
			if ( !tr.LineSide ) 
				hitnormal *= -1;
		}*/
		
		aimPos = tr.hitLocation;// + (hitnormal * 8);
		SpawnCrosshair(weap.GetClass());
	}
	
	void SpawnCrosshair(class<Weapon> weapclass = null)
	{
		let spot = Spawn("ToM_CrosshairSpot", aimPos);
		if (weapclass && weapclass == 'ToM_Blunderbuss')
		{
			spot.A_SetRenderstyle(spot.alpha, Style_AddShaded);
			spot.SetShade("c00003");
		}
	}
}

class ToM_PspResetController : Thinker
{
	protected PSprite psp;
	protected int tics;
	
	protected vector2 ofs;
	protected vector2 scale;
	protected double rotation;
	
	protected vector2 targetofs;
	protected vector2 targetscale;
	protected double targetrotation;
	
	protected vector2 ofs_step;
	protected vector2 scale_step;
	protected double rotation_step;
	
	static ToM_PspResetController Create (PSprite psp, int tics, vector2 tofs = (0,0), vector2 tscale = (1, 1), int trotation = 0)
	{
		if (!psp || tics <= 0)
			return null;
		
		let ppRC = ToM_PspResetController(New("ToM_PspResetController"));
		if (ppRC)
		{
			ppRC.psp = psp;
			ppRC.tics = tics;
			
			ppRC.ofs = (psp.x, psp.y);
			ppRC.scale = psp.scale;
			ppRC.rotation = psp.rotation;
			
			ppRC.targetofs = tofs;
			ppRC.targetscale = tscale;
			ppRC.targetrotation = trotation;
			
			ppRC.ofs_step = (tofs - ppRC.ofs) / tics;
			ppRC.scale_step = (tscale - ppRC.scale ) / tics;
			ppRC.rotation_step = (trotation - ppRC.rotation) / tics;
			if (tom_debugmessages > 1)
			{
				console.printf(
					"PSP reset controller created:\n"
					"ofs: %d, %d | target ofs: %d, %d | step: %d, %d\n"
					"scale: %.1f, %.1f | target scale: %.1f, %.1f | step: %.1f\n"
					"rotation: %.1f | target rotation: %.1f | step: %.1f",
					psp.x, psp.y, ppRC.targetofs.x, ppRC.targetofs.y, ppRC.ofs_step.x, ppRC.ofs_step.y,
					psp.scale.x, psp.scale.y, ppRC.targetscale.x, ppRC.targetscale.y, ppRC.scale_step.x, ppRC.scale_step.y,
					psp.rotation, ppRC.targetrotation, ppRC.rotation_step
				);
			}
		}
		return ppRC;
	}
	
	override void Tick()
	{
		Super.Tick();
		if (!psp)
		{
			if (tom_debugmessages > 1)
			{
				console.printf("No PSprite, destroying controller");
			}
			Destroy();
			return;
		}
		psp.x += ofs_step.x;
		psp.y += ofs_step.y;
		psp.scale += scale_step;
		psp.rotation += rotation_step;
		if (tom_debugmessages > 1)
		{
			console.printf("Updating psprite values. Tics left: %d", tics);
		}
		
		tics--;
		if (tics < 0)
		{
			if (tom_debugmessages > 1)
			{
				console.printf("PSP reset controller destroyed");
			}
			Destroy();
			return;
		}
	}
	
	PSprite GetPSprite()
	{
		return psp;
	}
	
	void StopReset()
	{
		if (psp)
			psp = null;
	
		Destroy();
	}
	
	override void OnDestroy()
	{
		if (psp)
		{
			// Double-check we didn't overshoot with the values:
			psp.x = targetofs.x;
			psp.y = targetofs.y;
			psp.scale = targetscale;
			psp.rotation = targetrotation;
		}
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