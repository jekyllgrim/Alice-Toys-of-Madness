
class ToM_KickWeapon : CustomInventory
{
	protected bool wasKicking;
	protected ToM_AlicePlayer alice;
	protected State s_standing;
	protected State s_idlestates;
	protected State s_walking;
	protected State s_finishWalking;
	protected State s_kick;
	protected State s_jumping;
	protected State s_jumploop;
	protected State s_finishJumping;
	protected State s_prevstate;

	const PITCHTH0 = 90.0;
	const PITCHTH1 = 30.0;
	const PITCHTH2 = -20.0;
	const PITCHTH3 = -90.0;

	Default
	{
		+INVENTORY.UNDROPPABLE
		+INVENTORY.UNTOSSABLE
		Inventory.Maxamount 1;
	}
	
	double arcKickAngle;
	array <Actor> kickedActors;

	action void A_AliceKick(int steps, double endPitch = -30)
	{
		if (invoker.arcKickAngle < endPitch)
		{
			invoker.ResetKick();
		}
		FLineTraceData tr;
		double atkheight = ToM_Utils.GetPlayerAtkHeight(player.mo);
		LineTrace(angle, 70, invoker.arcKickAngle, TRF_NOSKY, atkheight, data: tr);
		int hitType;
		Actor hitactor;
		[hitType, hitactor] = ToM_Utils.GetHitType(tr);

		if (hitType == ToM_Utils.HT_ShootableThing && hitactor && invoker.kickedActors.Find(hitactor) == invoker.kickedActors.Size())
		{
			invoker.kickedActors.Push(hitactor);
			hitactor.DamageMobj(self, self, 40, 'Normal');
			hitactor.A_StartSound("weapons/kick/hitflesh", CHAN_BODY, CHANF_OVERLAP);
			if (hitactor.bISMONSTER && !hitactor.bDONTTHRUST && !hitactor.bBOSS && !hitactor.bNOGRAVITY && !hitactor.bFLOAT && hitactor.mass <= 400)
			{
				//initial push away speed is based on mosnter's mass:
				double pushspeed = ToM_Utils.LinearMap(hitactor.mass, 100, 400, 10, 5);
				pushspeed = Clamp(pushspeed,5,20) * frandom[sfx](0.85,1.2);
				//bonus Z velocity is based on the players view pitch (so that you can knock monsters further by looking up):
				double pushz = Clamp(ToM_Utils.LinearMap(self.pitch,0,-90,0,10), 0, 10);
				hitactor.Vel3DFromAngle(
					pushspeed,
					self.angle,
					Clamp(self.pitch - 5, -15, -45)
				);
				hitactor.vel.z += pushz;
			}
		}
		// could not hit an actor: try hitting a wall in front of us
		else if (invoker.arcKickAngle <= endPitch)
		{
			LineTrace(angle, 70, 0, TRF_NOSKY, atkheight, data: tr);
			[hitType, hitactor] = ToM_Utils.GetHitType(tr);
			if (hittype == ToM_Utils.HT_Solid)
			{
				Vector3 puffpos = tr.hitlocation;
				if (tr.HitLine)
				{
					let norm = ToM_Utils.GetLineNormal(pos.xy, tr.HitLine);
					puffpos.xy += norm * 8;
				}
				let spot = Spawn('ToM_DebugSpot', puffpos);
				if (spot)
				{
					spot.A_StartSound("weapons/kick/hitwall");
					spot.Destroy();
				}
				FSpawnParticleParams pp;
				pp.lifetime = 30;
				pp.flags = SPF_ROLL;
				pp.color1 = "";
				pp.startalpha = 0.6;
				pp.fadestep = -1;
				pp.pos = puffpos;
				double v = 0.5;
				for (int i = 4; i > 0; i--)
				{
					pp.texture = TexMan.CheckForTexture(ToM_BaseActor.GetRandomWhiteSmoke());
					pp.size = frandom(14, 20);
					pp.sizestep = pp.size*0.015;
					pp.vel = (frandom[kickpuff](-v,v), frandom[kickpuff](-v,v), frandom[kickpuff](-v,v));
					pp.accel = -(pp.vel / pp.lifetime);
					pp.startroll = frandom[kickpuff](0,360);
					pp.rollvel = frandom[kikcpuff](-15, 15);
					pp.rollacc = -(pp.rollvel / pp.lifetime);
					Level.SpawnParticle(pp);
				}
			}
		}
		invoker.arcKickAngle -= (90 - endPitch) / steps;
	}

	action void A_AliceStomp()
	{
		ToM_GrowthPotionEffect.DoStepDamage(self, damage: 60, distance: 160);
	}

	bool IsPlayerMoving()
	{
		return alice && alice.IsPlayerMoving();
	}

	void ResetKick()
	{
		kickedActors.Clear();
		arcKickAngle = 90;
	}

	override void BeginPlay()
	{
		Super.BeginPlay();
		ResetKick();
		s_standing		= FindState("Standing");
		s_idlestates	= FindState("IdleStates");
		s_walking		= FindState("Walking");
		s_finishWalking = FindState("FinishWalking");
		s_kick			= FindState("Kick");
		s_jumping		= FindState("Jumping");
		s_jumploop		= FindState("JumpLoop");
		s_finishJumping = FindState("FinishJumping");
	}
	
	override void Tick() {}
	
	override void DoEffect()
	{
		super.DoEffect();
		if (!owner || !self) return;

		alice = ToM_AlicePlayer(owner);
		if (!alice || !alice.player || ToM_Utils.IsVoodooDoll(alice))
		{
			Destroy();
			return;
		}
		
		if (alice.health <= 0)
			return;
		
		let player = alice.player;
		PSprite plegs = player.FindPSprite(APSP_Legs);
		if (!plegs)
		{
			plegs = player.GetPSprite(APSP_Legs);
			if (!plegs) return; //would this ever happen?
			plegs.caller = self;
			plegs.pivot = (0.5, 0.86);
			plegs.bAddWeapon = false;
			plegs.bAddBob = false;
			plegs.SetState(s_standing);
		}

		plegs.bInterpolate = true;
		// Adjust y position relative to camera pitch:
		double ofsY;
		if (alice.pitch >= PITCHTH1)
		{
			ofsY = ToM_Utils.LinearMap(alice.pitch, PITCHTH0, PITCHTH1, 30, 217, true);
		}
		else if (alice.pitch >= PITCHTH2)
		{
			ofsY = ToM_Utils.LinearMap(alice.pitch, PITCHTH1, PITCHTH2, 217, 225, true);
		}
		else
		{
			ofsY = ToM_Utils.LinearMap(alice.pitch, PITCHTH2, PITCHTH3, 225, 320, true);
		}
		plegs.y = ofsY;
		// Adjust scale based on bobbing if moving on the ground:
		double bobfac = 0;
		if (player.onground)
		{
			bobfac = player.viewz - (alice.pos.z + alice.player.mo.ViewHeight + player.crouchviewdelta);
		}
		double sc = ToM_Utils.LinearMap(bobfac, -9, 9, 1.05, 0.95);
		// Slightly reduce scale with pitch as well:
		//double pitchFac =  ToM_Utils.LinearMap(plegs.y, yOfs.x, yOfs.y, 1, 0.8, true);
		plegs.scale = (sc, sc);// * pitchFac;
		
		// kicking/stomping (not affected by rotation)
		if (player.cmd.buttons & BT_USER4 && !InStateSequence(plegs.curstate, s_kick) && (!owner.FindInventory('ToM_GrowthPotionEffect') || player.onground))
		{
			plegs.SetState(s_kick);
		}
		// safeguard to make sure speed and other kick data gets
		// properly reset if the kicking state sequence got
		// interrupted for whatever reason:
		if (wasKicking && InStateSequence(s_prevstate, s_kick) && !InStateSequence(plegs.curstate, s_kick))
		{
			owner.speed /= 0.1;
			ResetKick();
			wasKicking = false;
		}
		// kicking has highest priority over everything:
		if (InStateSequence(plegs.curstate, s_kick))
		{
			s_prevstate = plegs.curstate;
			plegs.rotation = 0;
			return;
		}

		// Adjust angle and add a bit of offset based on movement direction:
		double faceDir = 0;
		double moveOfsY;
		double moveVel = alice.vel.xy.Length();
		if (moveVel > 5)
		{
			facedir = Normalize180(alice.modelDirection);
			moveOfsY = ToM_Utils.LinearMap(abs(faceDir), 180, 0, 0, 40);
			if (faceDir > 90)
			{
				faceDir -= 180;
			}
			else if (faceDir < -90)
			{
				faceDir += 180;
			}
		}
		double newAngle = Clamp(faceDir, -90, 90);
		plegs.rotation = newAngle;
		plegs.y += moveOfsY * ToM_Utils.LinearMap(moveVel, 0, 15, 0.0, 1.0, true);

		// jumping:
		if (player.jumptics < 0 && !InStateSequence(plegs.curstate, s_jumping))
		{
			plegs.SetState(s_jumping);
		}
		// falling:
		if (!player.onground && !player.jumptics && !InStateSequence(plegs.curstate, s_jumping))
		{
			plegs.SetState(s_jumploop);
		}
		// landing:
		if (player.onground && InStateSequence(plegs.curstate, s_jumping))
		{
			plegs.SetState(s_finishJumping);
		}

		// moving:
		if (InStateSequence(plegs.curstate, s_idlestates) && IsPlayerMoving())
		{
			plegs.SetState(s_walking);
		}

		// stopped moving:
		if (InStateSequence(plegs.curstate, s_walking) && !IsPlayerMoving())
		{
			plegs.SetState(s_finishWalking);
		}

		s_prevstate = plegs.curstate;
	}
	
	States
	{
	Use:
		TNT1 A 0;
		fail;
	IdleStates:
		FinishJumping:
			FJE1 ABCDEFGHIJKLMNOPQRSTUVWXYZ 1;
		FinishWalking:
			FEX1 ABCDEFGHIJKLMNOPQRSTUVWXYZ 1;
			FEX2 ABCDEFGHIJ 1;
			TNT1 A 0 { return ResolveState("Standing"); }
		FinishStomp:
			FET1 ABCDEFGHIJKLMNOPQRSTUV 1;
			TNT1 A 0 { return ResolveState("Standing"); }
		FinishKick:
			FEL1 ABCDEFGHIJKLMNOPQRSTUVWXYZ 1;
			FEL2 ABCD 1;
			TNT1 A 0 { return ResolveState("Standing"); }
		Standing:
			FEA1 A -1;
			stop;

	Walking:
		FEW1 # 1
		{
			let psp = player.FindPSprite(OverlayID());
			if (psp)
			{

				int curFrame = psp.frame;
				curFrame += (player.cmd.forwardmove > 0)? 1 : -1;
				if (curFrame > 19)	curframe = 0;
				if (curFrame < 0)	curframe = 19;
				psp.frame = curframe;

				psp.tics = ToM_Utils.LinearMap(vel.xy.Length(), 3, 17, 4, 1, true);
			}
			return ResolveState(null);
		}
		loop;

	Jumping:
		JumpStart:
			FJS1 ABCDEFGHIJKLM 1;
		JumpLoop:
			FJL1 ABCDEFGHIJKLMNOPQRSTUVWXYZ 1;
			FJL2 ABCDEFGHIJKLM 1;
			loop;
	
	Kick:
		Kick_Regular:
			TNT1 A 0
			{
				invoker.wasKicking = true;
				speed *= 0.1;
				if (FindInventory('ToM_GrowthPotionEffect'))
				{
					return ResolveState("Stomp");
				}
				return ResolveState(null);
			}
			FEK1 A 1;
			TNT1 A 0 A_StartSound("weapons/kick/whip", CHAN_AUTO);
			FEK1 BCDEE 1 A_AliceKick(5);
			FEK1 FGHIJLKM 1;
			TNT1 A 0 
			{
				speed /= 0.1;
				invoker.wasKicking = false;
			}
			FEK1 NOPQR 1;
			TNT1 A 0 { return ResolveState("FinishKick"); }
		Stomp:
			FES1 ABCDEFGHIJKLMNO 1;
			FES1 P 2 A_AliceStomp();
			FES1 QRSTUVWXYZ 1;
			FES2 ABCD 1;
			TNT1 A 0 
			{
				speed /= 0.1;
				invoker.wasKicking = false;
			}
			FES2 EFGH 1;
			goto FinishStomp;
	}
}