class ToM_BaseWeapon : Weapon abstract
{
	mixin ToM_PlayerSightCheck;
	mixin ToM_CheckParticles;
	
	protected bool isSelected;
	protected vector2 targOfs; //used by DampedRandomOffset
	protected vector2 shiftOfs; //used by DampedRandomOffset
	protected int idleCounter; //used by idle animations 
	protected int particleLayer_bottom; //used by multi-layer particle effects
	protected int particleLayer_top; //used by multi-layer particle effects
	protected double atkzoom;
	protected int atkButtonState;
	protected int atkButtonStateAlt;
	protected Array<int> recentAtkButtons; //tracks the last presses
	const TRACKED_ATK_BUTTONS_MAX = 10;
	
	color pickupParticleColor;
	Property PickupParticleColor : pickupParticleColor;
	bool isTwoHanded;
	Property IsTwoHanded : isTwoHanded;
	protected bool canPlayCheshireSound;
	sound cheshireSound;
	Property CheshireSound : cheshireSound;
	sound loopedAttackSound;
	Property LoopedAttackSound : loopedAttackSound;
	
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
	
	enum EPABCheck
	{
		PAB_ANY,		//pressed now (doesn't matter if held)
		PAB_HELD,		//pressed AND held
		PAB_NOTHELD,	//pressed but NOT held
		PAB_HELDONLY	//NOT pressed but held
	}
	
	enum EPABbuttonCheck
	{
		PAB_AUTO,
		PAB_PRIMARY,
		PAB_SECONDARY
	}

	enum EAtkButtonStates
	{
		ABS_None,
		ABS_Held,
		ABS_Lifted,
		ABS_PressedAgain,
	}
	
	Default 
	{
		// Weapons just reuse tag for their pickupmessage
		// and add ! to it
		Inventory.PickupSound "pickups/weapon";
		weapon.BobStyle "InverseSmooth";
		weapon.BobRangeX 0.32;
		weapon.BobRangeY 0.17;
		weapon.BobSpeed 1.85;
		scale 0.5;
		+FLOATBOB
		+Inventory.AUTOACTIVATE
		FloatBobStrength 0.8;
		ToM_BaseWeapon.PickupParticleColor "7fa832";
	}

	override String PickupMessage()
	{
		return String.Format("%s!", StringTable.Localize(GetTag()));
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
	
	// Do the attack and move the offset one step as defined above
	// Return values:
	// 1. Actor - the actor that was hit
	// 2. Actor - the puff
	// 3. bool - true if the hit actor was dealt damage
	action Actor, Actor, bool A_SwingAttack(int damage,
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
			if (tom_debugmessages)
			{
				Console.Printf("\cgSwing data:\c- Controller \cd%d\c- does not exist. Aborting.", id);
			}
			return null, null, false;
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
		if (tom_debugmessages > 1)
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
		bool damaged = false;
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
					puffpos = level.Vec3Offset(puffpos, hitnormal * max(puff.radius, puff.height));
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
				if (hit.hitLine)
				{
					hit.HitLine.RemoteActivate(self, hit.LineSide, SPAC_Impact, self.pos);
				}
			}
			
			// Do this if we hit an actor:
			else if (damage > 0 && type == ToM_Utils.HT_ShootableThing && victim && invoker.swingVictims.Find(victim) == invoker.swingVictims.Size())
			{
				if (pos.z > floorz && invoker.swingVictims.Size() == 0 && (victim.bFloat || victim.bNoGravity) && !self.bNoGravity && !self.bFloat && !self.bFLYCHEAT && !(player.cheats & CF_FLY) && !(player.cheats & CF_NOCLIP2))
				{
					if (vel.z < 0) vel.z = 0;
					vel.z += 5;
					ToM_AlicePlayer(self).ResetAirJump();
				}

				invoker.swingVictims.Push(victim);
				victim.DamageMobj(puff? puff : self, self, damage, 'normal');
				damaged = true;
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

		return victim, puff, damaged;
	}

	action void A_PlayerAttackAnim(int animTics, Name animName, double framerate = -1, int startFrame = -1, int loopFrame= -1, int endFrame = -1, int interpolateTics = -1, int flags = 0)
	{
		let player = self.player;
		let alice = ToM_AlicePlayer(player.mo);
		if (alice && !ToM_Utils.IsVoodooDoll(alice))
		{
			//Console.Printf("Applying player animation \cd%s\c-", animName);
			alice.SetState(alice.MissileState);
			alice.A_SetTics(animTics);
			if (interpolateTics <= 0)
			{
				flags |= SAF_INSTANT;
			}
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
	action void A_ResetPSprite(int layer = 0, int staggertics = 0, bool interpolate = false)
	{
		// If using default value, interpret as calling layer
		int tlayer = layer == 0 ? OverlayID() : layer;
		
		let psp = player.FindPSprite(tlayer);
		if (!psp)
		{
			if (ToM_debugmessages > 1)
				console.printf("\cYPSPRC:\c- PSprite %d doesn't exist", tlayer);
			return;
		}
		let alice = ToM_AlicePlayer(self);
		if (!alice) return;
		
		// If this is main layer (PSP_WEAPON), or an
		// overlay that doesn't have bADDWEAPON,
		// the target offsets are (0, 32).
		// Otherwise they're (0,0):
		vector2 tofs = (0, 0);
		if (tlayer == PSP_WEAPON || psp.bAddWeapon == false)
		{
			tofs.y = WEAPONTOP;
		}
		
		// If stagger tics is 1 or fewer, simply reset everything:
		if (staggertics <= 1)
		{
			psp.bInterpolate = false;
			A_StopPSpriteReset(tlayer);
			psp.x = tofs.x;
			psp.y = tofs.y;
			psp.rotation = 0;
			psp.scale = (1, 1);
			psp.pivot = (0,0);
			psp.Coord0 = (0,0);
			psp.Coord1 = (0,0);
			psp.Coord2 = (0,0);
			psp.Coord3 = (0,0);
			psp.ResetInterpolation();
			return;
		}
		
		// Otherwise create a ToM_PspResetController and pass
		// the current PSPrite and target values to it:
		
		let cont = ToM_PspResetController(ToM_PspResetController.Create(psp, staggertics, tofs, interpolate: interpolate));
		if (!cont)
		{
			if (ToM_debugmessages)
				console.printf("\cYPSPRC:\c- Error: Couldn't create ToM_PspResetController", tlayer);
			return;
		}
		
		if (alice.pspcontrols.Find(cont) == alice.pspcontrols.Size())
		{
			if (tom_debugmessages > 1)
			{
				console.printf("\cYPSPRC:\c- Pushing layer \cd%d\c- into pspcontrols array. Tics: \cd%d\c-, target offsets: \cd(%d, %d)\c-", tlayer, staggertics, tofs.x, tofs.y);
			}
			alice.pspcontrols.Push(cont);
		}
		else if (tom_debugmessages > 1)
		{
			Console.Printf("\cyPSPRC:\c- Controller for layer \cd%d\c- already exists, not pushing.", tlayer);
		}
	}
	
	action void A_SetSelectPosition(double wx, double wy)
	{
		A_StopPSpriteReset(OverlayID(), dropRightThere: true);
		let psp = player.FindPSprite(PSP_WEAPON);
		if (psp)
		{
			A_ResetPSprite(PSP_WEAPON);
			psp.x = wx;
			psp.y = wy;
			psp.ResetInterpolation();
			if (tom_debugmessages > 1)
			{
				Console.Printf("\cYPSPRC:\c- Layer %d reset. Pos: %.1f,%.1f | Scale: %.1f, %.1f", PSP_WEAPON, psp.x, psp.y, psp.scale.x, psp.scale.y);
			}
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
				console.printf("\cYPSPRC:\c- PSprite %d doesn't exist", tlayer);
			return;
		}
		
		let alice = ToM_AlicePlayer(self);
	
		for (int i = alice.pspcontrols.Size() - 1; i >= 0; i--)
		{
			let cntrl = alice.pspcontrols[i];
			//Console.Printf("\cgIterating over PSprites.\c- Target id: \cg%d\c- | current id: \cg%d\c-", tlayer, cntrl? cntrl.GetPSprite().id : 000);
			if (cntrl && cntrl.GetPSprite() == psp)
			{
				if (ToM_debugmessages > 1)
					console.printf("\cYPSPRC:\c- Removing psp controller for PSprite %d", tlayer);
				if (dropRightThere)
					cntrl.StopReset();
				else
				{
					cntrl.ResetPsprite();
					cntrl.Destroy();
				}
				alice.pspcontrols.Delete(i);
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

	// Dedicated refire for melee weapons that utilizes
	// input buffering to jump states:
	action State A_CheckNextSlash(StateLabel nextPrimary = "Fire", StateLabel nextSecondary = null, bool allowSwitch = true)
	{
		State sNext1 = ResolveState(nextPrimary);
		State sNext2 = ResolveState(nextSecondary);
		State togo = null;

		// If nextPrimary state is valid and primary button
		// is pressed again, jump to it:
		if (sNext1 && invoker.atkButtonState == ABS_PressedAgain)
		{
			invoker.atkButtonState = ABS_Held;
			togo = sNext1;
		}
		// Otherwise check if it should jump to secondary:
		else if (sNext2 && invoker.atkButtonStateAlt == ABS_PressedAgain)
		{
			togo = sNext2;
			invoker.atkButtonStateAlt = ABS_Held;
		}

		// If we're supposed to jump OR if we can't jump
		// but allowSwitch is false, disable the ability
		// to switch weapons (like WRF_DISABLESWITCH):
		if (togo || !allowSwitch)
		{
			player.WeaponState &= ~WF_WEAPONSWITCHOK;
			player.pendingweapon = WP_NOCHANGE;
		}
		// Otherwise (we're not supposed to jump and
		// we are allowed to switch), allow switching:
		else
		{
			player.WeaponState |= WF_WEAPONSWITCHOK;
		}

		return togo;
	}

	virtual void OnRemoval(Actor dropper)
	{
		if (dropper)
		{
			OnDeselect(dropper);
		}
	}

	virtual void OnDeselect(Actor dropper)
	{
		if (dropper)
		{
			dropper.A_StopSound(CHAN_WEAPON);
		}
		FOVScale = 1.0;
		atkButtonState = atkButtonStateAlt = ABS_None;
	}

	virtual void HandleInputBuffering()
	{
		let player = owner.player;
		let psp = player.FindPSprite(PSP_WEAPON);
		// If no PSprite, reset button states:
		if (!psp)
		{
			atkButtonState = atkButtonStateAlt = ABS_None;
			if (recentAtkButtons.Size() > 0)
			{
				recentAtkButtons.Clear();
			}
			return;
		}

		// If ready, both button states are none:
		if (InStateSequence(psp.curstate, GetReadyState()))
		{
			atkButtonState = atkButtonStateAlt = ABS_None;
			if (recentAtkButtons.Size() > 0)
			{
				recentAtkButtons.Clear();
			}
		}
		// Otherwise do buffering:
		else
		{
			// Primary attack button held:
			if (atkButtonState == ABS_None && InStateSequence(psp.curstate, GetAtkState(false)))
			{
				atkButtonState = ABS_Held;
				recentAtkButtons.Push(BT_ATTACK);
			}
			// Secondary attack button held:
			if (atkButtonStateAlt == ABS_None && InStateSequence(psp.curstate, GetAltAtkState(false)))
			{
				atkButtonStateAlt = ABS_Held;
				recentAtkButtons.Push(BT_ALTATTACK);
			}
			
			// If primary was held but player is not pressing
			// the attack button, store it as Lifted:
			if (atkButtonState == ABS_Held && !(player.cmd.buttons & BT_ATTACK))
			{
				atkButtonState = ABS_Lifted;
			}
			// If primary is NOT held (and it's also not None
			// because the state is not Ready) and the player IS
			// pressing the button, record it as Pressed Again.
			// This is what will allow the weapon to go to the next
			// slash:
			if (atkButtonState != ABS_Held && (player.cmd.buttons & BT_ATTACK))
			{
				// If primary is pressed again for the first time,
				// track it:
				if (atkButtonState != ABS_PressedAgain)
				{
					// If secondary was pressed before (during the same
					// buffering window), overwrite it with primary:
					if (atkButtonStateAlt == ABS_PressedAgain && recentAtkButtons.Size() > 0 && recentAtkButtons[recentAtkButtons.Size()-1] == BT_ALTATTACK)
					{
						recentAtkButtons.Pop();
					}
					// Otherwise add primary to the array:
					recentAtkButtons.Push(BT_ATTACK);
				}
				// Pressing primary button records the
				// alt button as lifted, so they can override
				// each other:
				atkButtonState = ABS_PressedAgain;
				atkButtonStateAlt = ABS_Lifted;
			}

			// Do the same for secondary attack:
			if (atkButtonStateAlt == ABS_Held && !(player.cmd.buttons & BT_ALTATTACK))
			{
				atkButtonStateAlt = ABS_Lifted;
			}
			if (atkButtonStateAlt != ABS_Held && (player.cmd.buttons & BT_ALTATTACK))
			{
				if (atkButtonStateAlt != ABS_PressedAgain)
				{
					if (atkButtonState == ABS_PressedAgain && recentAtkButtons.Size() > 0 && recentAtkButtons[recentAtkButtons.Size()-1] == BT_ATTACK)
					{
						recentAtkButtons.Pop();
					}
					recentAtkButtons.Push(BT_ALTATTACK);
				}
				atkButtonStateAlt = ABS_PressedAgain;
				atkButtonState = ABS_Lifted;
			}

			while (recentAtkButtons.Size() > TRACKED_ATK_BUTTONS_MAX)
			{
				recentAtkButtons.Delete(0);
			}
		}

		if (tom_debugmessages > 2)
		{
			String absString, absStringAlt, statestr;

			if (InStateSequence(psp.curstate, GetReadyState()))
				statestr = "Ready";
			else if (InStateSequence(psp.curstate, GetAtkState(false)))
				statestr = "Attack";
			else if (InStateSequence(psp.curstate, GetAltAtkState(false)))
				statestr = "Alt Attack";

			switch (atkButtonState)
			{
				default:               absString = "\cg None"; break;
				case ABS_Held:         absString = "\cq Held"; break;
				case ABS_Lifted:       absString = "\cd Lifted"; break;
				case ABS_PressedAgain: absString = "\cv Pressed again"; break;
			}

			switch (atkButtonStateAlt)
			{
				default:               absStringAlt = "\cg None"; break;
				case ABS_Held:         absStringAlt = "\cq Held"; break;
				case ABS_Lifted:       absStringAlt = "\cd Lifted"; break;
				case ABS_PressedAgain: absStringAlt = "\cv Pressed again"; break;
			}

			String btnstr;
			for (int i = 0; i < recentAtkButtons.Size(); i++)
			{
				String str;
				switch (recentAtkButtons[i])
				{
					default: str = " \cg(x)"; break;
					case BT_ATTACK: str = " \cd(1)"; break;
					case BT_ALTATTACK: str = " \cy(2)"; break;
				}
				btnstr.AppendFormat(str);
			}

			Console.MidPrint(NewConsoleFont, 
				String.Format(
					"\cfPrimary button state:\c- %s"
					"\n\cfSecondary button state:\c- %s"
					"\n\cfWeapon state:\c- \cd%s\c-"
					"\n\cfRecent btns:%s", 
					absString, absStringAlt, statestr, btnstr
				)
			);
		}
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
	
	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		canPlayCheshireSound = !bNoSector;
	}

	override void DetachFromOwner()
	{
		OnRemoval(owner);
		Super.DetachFromOwner();
	}

	override void OnDrop (Actor dropper)
	{
		OnRemoval(dropper);
		Super.OnDrop(dropper);
	}

	override bool Use(bool pickup)
	{
		if (pickup)
		{
			if (CheshireSound && canPlayCheshireSound && !bTOSSED && owner && owner.player)
			{
				canPlayCheshireSound = false;
				ToM_CheshireCat.SpawnAndTalk(owner.player.mo, CheshireSound);
			}
			return false;
		}
		return Super.Use(pickup);
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
		
		let player = owner.player;
		if (!player) return;

		let weap = owner.player.readyweapon;

		if (weap && weap == self &&  owner.health > 0)
		{
			isSelected = true;
		}
		else
		{
			if (isSelected)
			{
				OnDeselect(owner);
				isSelected = false;
			}
			return;
		}

		if (bMELEEWEAPON)
		{
			HandleInputBuffering();
		}
		
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

	Property ParticleAmount : puff_particles;
	Property ParticleSpeed : puff_partvel;
	Property ParticleGravity : puff_gravity;
	Property ParticleSize : puff_partsize;
	Property ParticleColor : puff_partcolor;
	Property ParticleTexture : puff_texture;

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
		for (int i = int(round(puff_particles * frandom[puffvis](0.8, 1.2))); i > 0; i--)
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
	Property ShouldActivateLines : ShouldActivateLines;
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
	String trailTexture;
	double trailscale;
	double trailalpha;
	double trailfade;
	double trailvel;
	double trailz;
	double trailshrink;
	int trailstyle;
	
	double wrot;
	
	Property trailactor : trailactor;
	Property flareactor : flareactor;
	Property flarecolor : flarecolor;
	Property flarescale : flarescale;
	Property flarealpha : flarealpha;
	Property trailcolor : trailcolor;
	Property trailTexture : trailTexture;
	Property trailalpha : trailalpha;
	Property trailscale : trailscale;
	Property trailfade : trailfade;
	Property trailshrink : trailshrink;
	Property trailvel : trailvel;
	Property trailz : trailz;
	Property trailstyle : trailstyle;
	
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
		trail.lifetime = int(ceil(trailalpha / trailfade));
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
		for(int i = 0; i <= steps; i++)
		{
			SpawnTrail(oldpos);
			oldPos = level.vec3Offset(oldPos, direction);
		}
	}
}

class ToM_PiercingProjectile : ToM_Projectile
{
	array <Actor> hitvictims;

	Default
	{
		+BLOODSPLATTER
	}

	virtual int GetProjectileDamage()
	{
		return damage * random(1,8);
	}
	
	virtual int HitVictim(Actor victim)
	{
		int dmg = GetProjectileDamage();
		if (dmg > 0)
		{
			int dmg = victim.DamageMobj(self, target? target : Actor(self), dmg, damagetype);
			if (dmg && bBLOODSPLATTER && !victim.bNoBlood)
			{
				victim.TraceBleed(damage, self);
				victim.SpawnBlood(pos, AngleTo(victim), damage);
			}
			return dmg;
		}
		return 0;
	}
	
	virtual bool CheckValid(Actor victim)
	{
		return (!target || victim != target) && victim.bSHOOTABLE && !victim.bNonShootable && victim.health > 0 && !victim.bNoDamage && !victim.bInvulnerable;
	}
	
	override int SpecialMissileHit(actor victim)
	{
		if (victim)
		{
			if (CheckValid(victim) && hitvictims.Find(victim) == hitvictims.Size())
			{
				hitvictims.Push(victim);
				HitVictim(victim);
			}
			return (victim.bDontRip && !bRipper)? MHIT_DEFAULT : MHIT_PASS;
		}
		
		return MHIT_PASS;
	}
}
	

// A base projectile class that can stick into walls and planes.
// It'll move with the sector if it hit a moving one (e.g. door/platform).
// Ported from Painslayer, used by thrown Vorpal Knife and Playing Cards.
Class ToM_StakeProjectile : ToM_Projectile 
{
	enum EStuckTypes
	{
		STUCK_NONE		= 0,
		STUCK_GEOMETRY	= 1 << 1,
		STUCK_ACTOR		= 1 << 2, // This is set only in SpecialMissileHit()
		STUCK_SECPLANE	= 1 << 3, // Parented to a SecPlane (see ToM_StatucStuffHandler)
		STUCK_FLOOR		= STUCK_GEOMETRY | 1 << 4,
		STUCK_CEILING	= STUCK_GEOMETRY | 1 << 5,
		STUCK_WALL		= STUCK_GEOMETRY | 1 << 6,
		STUCK_3DFLOOR	= STUCK_GEOMETRY | 1 << 7,
	}
	// records the type of sticking:
	protected EStuckTypes stucktype;
	// Pos where the flight ended:
	protected vector3 endspot;
	// 3D floor to stick into, if any:
	protected transient F3DFloor hit_3dfloor;
	// Line to stick into, if any:
	protected Line hit_line;
	// Non-monster object to stick into, if any:
	protected actor stickobject; 
	protected double stickAngleOfs;
	protected double stickDeadPitch;
	// Plane to stick  into, if any. Has to be transient becase
	// SecPlane is not serializable. ToM_StaticStuffHandler
	// takes care of reacquiring this in case a save is made and
	// loaded *while* a stake was stuck:
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
	
	Default 
	{
		+MOVEWITHSECTOR
		+NOEXTREMEDEATH
	}

	EStuckTypes GetStuckType()
	{
		return stucktype;
	}
	
	void SetEndSpot(vector3 spot) 
	{
		endspot = spot;
	}
	
	// This function is called when the projectile 
	// dies and checks if it hit something:
	virtual void StickToWall() 
	{	
		String myclass = GetClassName();
		
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
		
		// Stuck in an actor:
		if (stickobject) 
		{
			if (bBLOODSPLATTER && stickobject.bSHOOTABLE && !stickobject.bNOBLOOD && !stickobject.bDORMANT)
			{
				stickobject.TraceBleed(damage, self);
				stickobject.SpawnBlood(self.pos, AngleTo(stickobject), damage);
			}
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
			stucktype = STUCK_CEILING;
			if (tom_debugmessages)
				console.printf("\cy%s\c- hit ceiling at at \cd%d\c-,\cd%d\c-,\cd%d\c-",myclass,pos.x,pos.y,pos.z);
		}
		else if (trac.HitLocation.z <= botz) 
		{
			stucktype = STUCK_FLOOR;
			if (tom_debugmessages)
				console.printf("\cy%s\c- hit floor at at \cd%d\c-,\cd%d\c-,\cd%d\c-",myclass,pos.x,pos.y,pos.z);
		}
		// If stuck in floor or ceiling, stop here:
		if (stucktype == STUCK_FLOOR || stucktype == STUCK_CEILING)
		{
			return;
		}
			
		// 3D floor is easiest, so we start with it:
		if (hit_3dfloor) 
		{
			stucktype = STUCK_3DFLOOR|STUCK_SECPLANE;
			// we simply attach the stake to the 3D floor's
			// top plane, nothing else:
			F3DFloor flr = trac.Hit3DFloor;
			stickplane = flr.top;
			stickoffset = stickplane.ZAtPoint(sticklocation) - pos.z;
			if (tom_debugmessages)
				console.printf("\cy%s\c- hit a 3D floor at \cd%d\c-,\cd%d\c-,\cd%d\c-",myclass,pos.x,pos.y,pos.z);
			return;
		}
		//otherwise see if we hit a line:
		else if (hit_Line) 
		{
			stucktype = STUCK_WALL;
			//check if the line is two-sided first:
			let tline = hit_Line;
			// if it's one-sided, it can't be a door/lift,
			// so don't do anything else:
			if (!tline.backsector) 
			{
				if (tom_debugmessages)
					console.printf("\cy%s\c- hit one-sided line, not doing anything else",myclass);
				return;
			}
			stucktype |= STUCK_SECPLANE;
			//if it's two-sided:
			//check which side we're on:
			int lside = ToM_Utils.PointOnLineSide(pos.xy,tline);
			String sside = (lside == 0) ? "front" : "back";
			//we'll attach the stake to the sector on the other side:
			let targetsector = (lside == 0 && tline.backsector) ? tline.backsector : tline.frontsector;
			let floorHitZ = targetsector.floorplane.ZatPoint (sticklocation);
			let ceilHitZ = targetsector.ceilingplane.ZatPoint (sticklocation);
			String secpart = "middle";
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
				console.printf("\cy%s\c- hit the %s %s part of the line at \cd%d\c-,\cd%d\c-,\cd%d\c-",myclass,secpart,sside,pos.x,pos.y,pos.z);
		}
	}
	
	// Virtual for breaking apart; child actors
	// override it to add debris or change the 
	// behavior:
	virtual void StakeBreak() 
	{
		stucktype = STUCK_NONE;
		if (tom_debugmessages)
			console.printf("\cy%s\c- destroyed at \cd%d\c-,\cd%d\c-,\cd%d\c-",GetClassName(), pos.x, pos.y, pos.z);
		if (self)
			Destroy();
	}
	
	// Record a non-monster solid object the stake
	// runs into if there is one:
	override int SpecialMissileHit (Actor victim) 
	{
		if (victim != target && (victim.bSOLID || victim.bSHOOTABLE))
		{
			stickobject = victim;
			stucktype = STUCK_ACTOR;
			stickoffset = pos.z - stickobject.pos.z;
			stickAngleOfs = DeltaAngle(stickobject.angle, angle);
			stickDeadPitch = random[sticksfx](60,80);
			if (tom_debugmessages)
			{
				console.printf("\cy%s\c- hit \cy%s\c- at at \cd%d\c-,\cd%d\c-,\cd%d\c-", GetClassName(), stickobject.GetClassName(), pos.x,pos.y,pos.z);
			}
		}
		return -1;
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
		
		if (stucktype == STUCK_NONE) 
		{
			return;
		}

		// Otherwise stake is dead, so we'll move it
		// alongside the object/plane it's supposed
		// to be attached to:

		// Attached to an actor:
		if (stucktype == STUCK_ACTOR)
		{
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
			// WAS attached to an actor at some point,
			// but that actor no longer exists, so just
			// let the stake fall down:
			else
			{
				stucktype = STUCK_NONE;
				bNOGRAVITY = false;
			}
		}
		
		// Attached to ceiling:
		else if (stucktype == STUCK_CEILING)
		{
			SetZ(ceilingz);
		}
		
		// Attached to floor:
		else if (stucktype == STUCK_FLOOR)
		{
			SetZ(floorz);
		}
		
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



class ToM_PspResetController : Thinker
{
	protected PSprite psp;
	protected int tics;
	protected bool interpolate;
	
	protected vector2 sourceofs;
	protected vector2 sourcescale;
	protected double sourcerotation;
	
	protected vector2 ofs;
	protected vector2 scale;
	protected double rotation;
	
	protected vector2 targetofs;
	protected vector2 targetscale;
	protected double targetrotation;
	
	protected vector2 ofs_step;
	protected vector2 scale_step;
	protected double rotation_step;
	
	static ToM_PspResetController Create (PSprite psp, int tics, vector2 tofs = (0,0), vector2 tscale = (1, 1), int trotation = 0, bool interpolate = true)
	{
		if (!psp || tics <= 0)
			return null;
		
		let ppRC = ToM_PspResetController(New("ToM_PspResetController"));
		if (ppRC)
		{
			ppRC.psp = psp;
			ppRC.tics = tics;
			ppRC.interpolate = interpolate && tics > 0;
			
			ppRC.ofs = ppRC.sourceofs = (psp.x, psp.y);
			ppRC.scale = ppRC.sourcescale = psp.scale;
			ppRC.rotation = ppRC.sourcerotation = psp.rotation;
			
			ppRC.targetofs = tofs;
			ppRC.targetscale = tscale;
			ppRC.targetrotation = trotation;
			
			ppRC.ofs_step = (tofs - ppRC.ofs) / tics;
			ppRC.scale_step = (tscale - ppRC.scale ) / tics;
			ppRC.rotation_step = (trotation - ppRC.rotation) / tics;
			if (tom_debugmessages > 1)
			{
				console.printf(
					"\cYPSPRC:\c- Controller created:\n"
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
				console.printf("\cYPSPRC:\c- No PSprite, destroying controller");
			}
			Destroy();
			return;
		}
		psp.bInterpolate = interpolate;
		psp.x = clamp(psp.x + ofs_step.x, min(sourceofs.x, targetofs.x), max(sourceofs.x, targetofs.x));
		psp.y = clamp(psp.y + ofs_step.y, min(sourceofs.y, targetofs.y), max(sourceofs.y, targetofs.y));

		psp.scale.x = clamp(psp.scale.x + scale_step.x, min(sourcescale.x, targetscale.x), max(sourcescale.x, targetscale.x));
		psp.scale.y = clamp(psp.scale.y + scale_step.y, min(sourcescale.y, targetscale.y), max(sourcescale.y, targetscale.y));

		psp.rotation = clamp(psp.rotation + rotation_step, min(sourcerotation, targetrotation), max(sourcerotation, targetrotation));
		
		if (tom_debugmessages > 1)
		{
			console.printf("\cYPSPRC:\c- Updating PSprite | Pos \cd%.1f, %.1f | Rot \cd%.1f\c- | Scale \cd%.1f,%.1f\c-| Tics left: \cd%d\c-", psp.x, psp.y, psp.rotation, psp.scale.x, psp.scale.y, tics);
		}
		
		tics--;
		if (tics < 0)
		{
			if (tom_debugmessages > 1)
			{
				console.printf("\cYPSPRC:\c- PSP reset controller destroyed");
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
		{
			psp = null;
		}
	
		Destroy();
	}
	
	void ResetPsprite()
	{
		if (psp)
		{
			// Double-check we didn't overshoot with the values:
			psp.x = targetofs.x;
			psp.y = targetofs.y;
			psp.scale = targetscale;
			psp.rotation = targetrotation;
			psp.ResetInterpolation();
		}
	}
	
	override void OnDestroy()
	{
		if (tom_debugmessages > 1)
		{
			Console.Printf("\cyPSPRC:\c- Controller for layer \cd%s\c- \cgdestroyed\c-", psp? ""..psp.id : "'unknown'");
		}
		Super.OnDestroy();
	}
}