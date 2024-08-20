class ToM_Eyestaff : ToM_BaseWeapon
{
	const APSP_EyeChargeFlash = PSP_Flash -1;

	double charge;
	private ToM_EyestaffBeam beam1;	//outer beam (purple)
	private ToM_EyestaffBeam beam2; //inner beam (yellow)
	private ToM_EyestaffBeam outerBeam; //rendered for other players and mirrors
	
	const ES_FULLBEAMCHARGE = 12;
	const ES_FULLROCKETCHARGE = 70;
	const ES_FULLALTCHARGE = 42;
	const ES_PARTALTCHARGE = 8;
	const ES_MAXCIRCLES = 4;
	int altStartupFrame;
	
	int altCharge;
	vector2 altChargeOfs;
	ToM_ESAimingCircle aimCircle;
	ToM_ESAimingCircle aimCircles[ES_MAXCIRCLES]; //keep track of circles existing simultaneously
	int aimCircleID;
	vector3 aimCirclePos;
	ToM_OuterBeamPos outerBeamPos;
	
	Default
	{
		Tag "$TOM_WEAPON_EYESTAFF";
		ToM_BaseWeapon.CheshireSound "cheshire/vo/eyestaff";
		Inventory.Icon "AWICEYES";
		ToM_BaseWeapon.IsTwoHanded true;
		ToM_BaseWeapon.LoopedAttackSound "weapons/eyestaff/beam";
		Weapon.slotnumber 7;
		weapon.ammotype1 "ToM_StrongMana";
		weapon.ammouse1 1;
		weapon.ammogive1 100;
		weapon.ammotype2 "ToM_StrongMana";
		weapon.ammouse2 1;
	}

	override void OnDeselect(Actor dropper)
	{
		Super.OnDeselect(dropper);
		A_StopCharge();
		A_StopBeam();
		A_RemoveAimCircle();
		A_StopSound(CHAN_7);
	}
	
	action void A_StopCharge()
	{
		invoker.charge = 0;
		invoker.altCharge = 0;
		invoker.aimCircle = null;
	}

	void MakeBeams()
	{
		if (!owner) return;

		if (!beam1)
		{
			beam1 = ToM_EyestaffBeam(ToM_LaserBeam.Create(owner, 10, 4.2, -1.4, type: "ToM_EyestaffBeam"));
		}
		if (!beam2)
		{
			beam2 = ToM_EyestaffBeam(ToM_LaserBeam.Create(owner, 10, 4.2, -1.25, type: "ToM_EyestaffBeamInner"));
		}
		if (!outerBeamPos)
		{
			outerBeamPos = ToM_OuterBeamPos(Spawn('ToM_OuterBeamPos', pos));
			outerBeamPos.master = owner;
		}
		if (!outerBeam)
		{
			outerBeam = ToM_EyestaffBeam(ToM_LaserBeam.Create(outerBeamPos, 0, 0, 0, type: "ToM_EyestaffBeam"));
			outerBeam.master = owner;
			outerBeam.bMASTERNOSEE = true;
			outerBeam.source = outerBeamPos;
		}
	}
	
	action void A_FireBeam(int damage = 5)
	{
		if (!self || !self.player)
			return;
		
		if (player.refire % 3 == 0 && !invoker.DepleteAmmo(invoker.bAltFire))
		{
			return;
		}
			
		A_StartSound(invoker.loopedAttackSound, CHAN_WEAPON, CHANF_LOOPING);

		let puf = LineAttack(angle, PLAYERMISSILERANGE, pitch, damage, 'Eyestaff', 'ToM_EyestaffPuff', LAF_NORANDOMPUFFZ|LAF_OVERRIDEZ, offsetz: player.viewz - pos.z);
		if (puf)
		{
			invoker.MakeBeams();
			invoker.beam1.trackingpos = invoker.beam2.trackingpos = invoker.outerBeam.trackingpos = true;
			invoker.beam1.targetPos = invoker.beam2.targetPos = invoker.outerBeam.targetPos = puf.pos;
			invoker.beam1.SetEnabled(true);
			invoker.beam2.SetEnabled(true);
			invoker.outerBeam.SetEnabled(true);
		}
	}
	
	action void A_StopBeam()
	{
		if (invoker.beam1)
		{
			invoker.beam1.SetEnabled(false);
		}
		if (invoker.beam2)
		{
			invoker.beam2.SetEnabled(false);
		}
		if (invoker.outerBeam)
		{
			invoker.outerBeam.SetEnabled(false);
		}
		if (invoker.outerBeamPos)
		{
			invoker.outerBeamPos.Destroy();
		}
		A_StopSound(CHAN_WEAPON);
	}
	
	action void A_EyestaffFlash(StateLabel label, double alpha = 0)
	{
		let psp = Player.FindPSprite(PSP_Flash);
		if (!psp)
		{
			let st = ResolveState(label);
			if (!st)
				return;
			psp = player.GetPSprite(PSP_Flash);
			psp.SetState(st);
			A_OverlayFlags(PSP_Flash, PSPF_Renderstyle|PSPF_ForceAlpha, true);
			A_OverlayRenderstyle(PSP_Flash, Style_Add);
			let psw = player.FindPSprite(PSP_WEAPON);
			if (psw)
			{
				//psp.x = 0;
				//psp.y = 0;
				psp.pivot = psw.pivot;
				psp.scale = psw.scale;
			}
		}
		if (alpha <= 0)
		{
			alpha = ToM_Utils.LinearMap(invoker.charge, 0, ES_FULLBEAMCHARGE, 0.0, 1.0);
		}
		psp.alpha = alpha;
	}
	
	action void A_EyestaffRecoil()
	{
		//A_DampedRandomOffset(3,3, 2);
		A_OverlayPivot(OverlayID(),0, 0);
		A_OverlayPivot(PSP_Flash, 0, 0);
		A_OverlayPivot(APSP_EyeChargeFlash, 0, 0);
		double sc = frandom[eye](0, 0.025);
		A_OverlayScale(OverlayID(), 1 + sc, 1 + sc, WOF_INTERPOLATE);
		A_OverlayScale(PSP_Flash, 1 + sc, 1 + sc, WOF_INTERPOLATE);
		A_OverlayScale(APSP_EyeChargeFlash, 1 + sc, 1 + sc, WOF_INTERPOLATE);
		A_AttackZoom(0.001, 0.05, 0.002);
	}
	
	action state A_DoAltCharge()
	{
		invoker.charge++;
		if (tom_debugmessages)
		{
			console.printf("Eyestaff visualMode charge: \cd%d\c-/\cq%d\c-", invoker.charge, ES_FULLALTCHARGE);
		}

		bool enoughAmmo = invoker.DepleteAmmo(invoker.bAltFire, true);
		// consume 1 more ammo every 3 tics:
		if (invoker.charge % 3 == 0)
		{
			enoughAmmo = invoker.DepleteAmmo(invoker.bAltFire, true);
		}
		
		// Cancel charge if:
		// 1. we're out of ammo
		// 2. we reached maximum charge
		// 3. we reached at least partial charge and
		// the player is not holding the attack button
		if (!enoughAmmo || invoker.charge >= ES_FULLALTCHARGE || (!PressingAttackButton() && invoker.charge >= ES_PARTALTCHARGE))
		{
			return ResolveState("AltFireDo");
		}
		
		A_WeaponOffset(
			invoker.altChargeOfs.x + frandom[eye](-1,1), 
			invoker.altChargeOfs.y + frandom[eye](-1,1), 
			WOF_INTERPOLATE
		);
		return ResolveState(null);
	}
	
	action void A_AimCircle(double dist = 350)
	{
		double atkheight = ToM_Utils.GetPlayerAtkHeight(PlayerPawn(self));
		
		FLineTraceData tr;
		bool traced = LineTrace(angle, dist, pitch, TRF_THRUACTORS, atkheight, data: tr);
		
		vector3 ppos;
		if (tr.HitType == Trace_HitNone)
		{
			let dir = (cos(angle)*cos(pitch), sin(angle)*cos(pitch), sin(-pitch));
			ppos = (pos + (0,0,atkheight)) + (dir * dist);
		}
		else
		{
			ppos = tr.HitLocation;
		}
		ppos.z = level.PointInSector(ppos.xy).NextLowestFloorAt(ppos.x, ppos.y, ppos.z);

		if (!invoker.aimCircle)
		{
			invoker.aimCircle = ToM_ESAimingCircle.Create(ppos, ToM_Eyestaff(invoker), self.player.mo, invoker.aimCircleID);
			invoker.aimCircles[invoker.aimCircleID] = invoker.aimCircle;
			if (++invoker.aimCircleID >= ES_MAXCIRCLES)
			{
				invoker.aimCircleID = 0;
			}
		}
		invoker.aimCircle.SetOrigin(ppos, true);
	}
	
	action void A_RemoveAimCircle()
	{
		for (int i = 0; i < ES_MAXCIRCLES; i++)
		{
			if (invoker.aimCircles[i])
			{
				invoker.aimCircles[i].Destroy();
				invoker.aimCircles[i] = null;
			}
		}
		let player = self.player;
		if (!player) return;
		let psp = player.FindPSprite(APSP_LeftHand);
		if (psp && InStateSequence(psp.curstate, ResolveState("AimCircleControlLayer")))
		{
			psp.Destroy();
		}
	}
	
	action void A_LaunchSkyMissiles()
	{
		A_WeaponOffset(
			invoker.altChargeOfs.x + frandom[eye](-1.2,1.2), 
			invoker.altChargeOfs.y + frandom[eye](-1.2,1.2), 
			WOF_INTERPOLATE
		);
		
		double ofs = 80;
		let ppos = pos + (frandom[eyemis](-ofs,ofs), frandom[eyemis](-ofs,ofs), floorz);
		ppos.z = level.PointInSector(ppos.xy).NextLowestFloorAt(ppos.x, ppos.y, ppos.z) + 18;
		
		let proj = ToM_EyestaffProjectile(Spawn("ToM_EyestaffProjectile", ppos));
		if (proj)
		{
			proj.visualMode = true;
			proj.target = self;
			proj.A_StartSound("weapons/eyestaff/boom2");
			proj.vel.z = proj.speed;
			proj.vel.xy = (frandom[skyeye](-3,3), frandom[skyeye](-3,3));
		}
	}
	
	action void A_SpawnSkyMissiles(double height = 800)
	{
		if (!invoker.aimCircle)
		{
			Console.Printf("\cgAToM Error:\c- Eyestaff aiming circle missing: cannot fire sky missiles.");
			return;
		}
		
		double pz = Clamp(invoker.aimCircle.pos.z + height, invoker.aimCircle.pos.z, invoker.aimCircle.ceilingz);
		
		let ppos = (invoker.aimCircle.pos.x, invoker.aimCircle.pos.y, pz);
		
		let sms = ToM_SkyMissilesSpawner(Spawn("ToM_SkyMissilesSpawner", ppos));
		if (sms)
		{
			sms.charge = invoker.altCharge;
			sms.target = self;
			sms.tracer = invoker.aimCircle;
		}
	}
	
	// Receive reduced damage from eyestaff projectiles:
	override void ModifyDamage (int damage, Name damageType, out int newdamage, bool passive, Actor inflictor, Actor source, int flags)
	{
		if (passive && owner && inflictor && inflictor is 'ToM_EyestaffProjectile' && inflictor.target == owner)
		{
			newdamage = int(round(damage / 4.0));
		}
	}

	States
	{
	/*Spawn:
		ALJE A -1;
		stop;*/
	Select:
		JEYC A 0 
		{
			A_SetSelectPosition(-24, 90+WEAPONTOP);
			A_OverlayPivot(OverlayID(), 0.6, 0.8);
			A_OverlayRotate(OverlayID(), 30);
		}
		#### ###### 1
		{
			A_WeaponOffset(4, -15, WOF_ADD);
			A_OverlayRotate(OverlayID(), -5, WOF_ADD);
			A_WeaponReady(WRF_NOFIRE|WRF_NOBOB);
		}
		goto Ready;
	Deselect:
		JEYC A 0
		{
			A_OverlayPivot(OverlayID(), 0.6, 0.8);
			A_StopSound(CHAN_WEAPON);
		}
		#### ###### 1
		{
			A_ResetZoom();
			A_WeaponOffset(-4, 15, WOF_ADD);
			A_OverlayRotate(OverlayID(), 5, WOF_ADD);
		}
		TNT1 A 0 A_Lower;
		wait;
	Ready:
		JEYC A 1 
		{
			if (invoker.charge > 0)
			{
				invoker.charge = clamp(invoker.charge -= 0.2, 0, ES_FULLBEAMCHARGE);
			}
			A_ResetZoom();
			A_WeaponReady();
		}
		loop;
	Fire:
		JEYC A 1
		{
			A_EyestaffFlash("BeamFlash");
			A_PlayerAttackAnim(-1, 'attack_eyestaff', 30, endframe: 1, flags: SAF_LOOP|SAF_NOOVERRIDE);
		}
		#### A 0
		{
			A_StartSound("weapons/eyestaff/charge1", CHAN_7, CHANF_NOSTOP);
			if (invoker.charge >= ES_FULLBEAMCHARGE)
			{
				A_StopCharge();
				A_PlayerAttackAnim(-1, 'attack_eyestaff', 30, flags: SAF_LOOP);
				return ResolveState("FireBeam");
			}
			if (PressingAttackButton(holdCheck:PAB_HELD))
			{
				invoker.charge = clamp(invoker.charge + 1, 0, ES_FULLBEAMCHARGE);
				A_SpawnPSParticle("ChargeParticle", bottom: true, density: ToM_Utils.LinearMap(invoker.charge, 0, ES_FULLBEAMCHARGE, 1, 10), xofs: 120, yofs: 120);
				A_AttackZoom(0.001, 0.08, 0.002);
				return ResolveState("Fire");
			}
			return ResolveState("FireEndFast");
		}
		goto Ready;
	FireBeam:
		JEYC A 1
		{
			invoker.charge = clamp(invoker.charge + 1, 0, ES_FULLROCKETCHARGE);
			if (invoker.charge < ES_FULLROCKETCHARGE)
			{
				A_SoundVolume(CHAN_7, ToM_Utils.LinearMap(invoker.charge, 0, ES_FULLROCKETCHARGE, 1.0, 0.0));
			}
			if (player.refire % 2 == 0)
			{
				A_SpawnPSParticle("ChargeParticle", bottom: true, density: 10, xofs: 120, yofs: 120);
				A_PlayerAttackAnim(-1, 'attack_eyestaff', 30, flags: SAF_LOOP|SAF_NOOVERRIDE);
				A_EyestaffFlash("BeamFlash", frandom[eye](0.3, 1));
				A_EyestaffRecoil();
			}
			A_Overlay(APSP_EyeChargeFlash, "ProjReadyFlash", true);
			A_FireBeam();
		}
		#### A 0 A_ReFire("FireBeam");
		#### A 0 
		{
			if (invoker.charge >= ES_FULLROCKETCHARGE)
			{
				return ResolveState("FireEndProjectile");
			}
			return ResolveState("FireEndFast");
		}
		goto Ready;
	FireEndFast:
		#### A 0
		{
			A_Overlay(APSP_EyeChargeFlash, "FlashEnd");
			A_StopBeam();
			A_StopSound(CHAN_7);
			A_StartSound("weapons/eyestaff/chargeoff", CHAN_WEAPON, volume: 0.7, startTime: ToM_Utils.LinearMap(invoker.charge, 0, ES_FULLROCKETCHARGE, 0.7, 0.0, true));
			A_PlayerAttackAnim(1, 'attack_eyestaff');
		}
		goto Ready;
	BeamFlash:
		JEYC F 1 bright
		{
			let psp = player.FindPSprite(OverlayID());
			let psw = player.FindPSprite(PSP_WEAPON);
			if (psp && psw && InStateSequence(psw.curstate, invoker.GetReadyState()))
			{
				if (invoker.charge <= 0)
				{
					return ResolveState("Null");
				}
				psp.alpha = ToM_Utils.LinearMap(invoker.charge, 0, ES_FULLBEAMCHARGE, 0, 0.7, true);
			}
			return ResolveState(null);
		}
		loop;
	FlashEnd:
		#### # 1 bright A_PSPFadeOut(0.15);
		loop;
	ProjReadyFlash:
		TNT1 A 0 
		{
			A_OverlayFlags(OverlayID(), PSPF_Renderstyle|PSPF_ForceAlpha, true);
			A_OverlayRenderstyle(OverlayID(), STYLE_Add);
			A_OverlayAlpha(OverlayID(), 0);
			let psp = player.FindPSprite(OverlayID());
			let psw = player.FindPSprite(PSP_WEAPON);
			if (psp && psw)
			{
				psp.pivot = psw.pivot;
				psp.scale = psw.scale;
			}
		}
		JEYC H 1 bright
		{
			double alph;
			if (invoker.charge < ES_FULLROCKETCHARGE)
			{
				alph = ToM_Utils.LinearMap(invoker.charge, 0, ES_FULLROCKETCHARGE, 0, 0.35, true);
			}
			else
			{
				alph = frandom[sfx](0.6, 0.8);
			}
			A_OverlayAlpha(OverlayID(), alph);
		}
		wait;
	FireEndProjectile:
		TNT1 A 0 
		{
			invoker.charge = 0;
			A_PlayerAttackAnim(20, 'attack_eyestaff_alt_end', 30, interpolateTics:6);
			A_Overlay(PSP_Flash, "Null");
			A_Overlay(APSP_EyeChargeFlash, "Null");
			A_ClearPSParticles(bottom: true);
			A_StopSound(CHAN_7);
			A_StopBeam();
			let proj = A_FireProjectile("ToM_EyestaffProjectile", useammo: false);
			if (proj)
			{
				proj.A_StartSound("weapons/eyestaff/fireProjectile");
			}
		}
		JEYC ACE 1 A_AttackZoom(0.03, 0.1);
		JEYC EEEEEE 1 
		{
			A_ResetZoom();
			A_WeaponOffset(frandom[eye](-2, 2), frandom[eye](-2, 2), WOF_ADD);
		}
		JEYC EEEEEE 1
		{
			A_ResetZoom();
			A_WeaponOffset(frandom[eye](-1, 1), frandom[eye](-1, 1), WOF_ADD);
		}
		TNT1 A 0 A_CheckReload();
		TNT1 A 0 A_ResetPsprite(OverlayID(), 9);
		JEYC EEDDCCBBA 1;
		goto ready;
	AltFlash:
		JEYC G -1 bright;
		stop;
	AltFire:
		TNT1 A 0 
		{
			A_PlayerAttackAnim(-1, 'attack_eyestaff_alt_start');
			A_Overlay(PSP_Flash, "Null");
			A_Overlay(APSP_EyeChargeFlash, "Null");
			A_StopCharge();
			A_ClearPSParticles(bottom: true);
		}
		JEYC AAABBBCCCDDDEEE 1 
		{
			A_WeaponOffset(-5, 1.4, WOF_ADD);
			let psp = player.FindPSprite(OverlayID());
			if (psp)
				invoker.altStartupFrame = psp.frame;
			invoker.altChargeOfs = (psp.x, psp.y);
			//A_ScalePSprite(OverlayID(), -0.01, -0.01, WOF_ADD);
			if (!PressingAttackButton())
			{
				A_RemoveAimCircle();
				A_PlayerAttackAnim(8, 'attack_eyestaff_alt_end', 40);
				return ResolveState("AltFireEndFast");
			}
			return ResolveState(null);
		}
	AltCharge:
		JEYC E 1
		{
			A_PlayerAttackAnim(-1, 'attack_eyestaff_alt_start', startframe: 6);
			A_StartSound("weapons/eyestaff/charge2", CHAN_WEAPON, CHANF_LOOPING);
			A_Overlay(APSP_LeftHand, "AimCircleControlLayer", true);
			A_EyestaffFlash("AltFlash");
			A_SpawnPSParticle("ChargeParticle", bottom: true, density: 4, xofs: 120, yofs: 120);
		}			
		JEYC E 1 { return A_DoAltCharge(); }
		loop;
	AimCircleControlLayer:
		TNT1 A 1 A_AimCircle(400);
		loop;
	AltFireDo:
		JEYC E 6;
		TNT1 A 0 
		{
			A_StopSound(CHAN_WEAPON);
			A_ClearOverlays(APSP_LeftHand, APSP_LeftHand);
			if (invoker.aimCircle)
			{
				invoker.aimCircle.chargeFinished = true;
			}
		}
		JEYC E 1
		{
			A_PlayerAttackAnim(-1, 'attack_eyestaff_alt_start', startframe: 6);
			invoker.charge--;
			invoker.altCharge++;
			A_EyestaffFlash("AltFlash");
			if (invoker.charge <= 0)
				return ResolveState("AltFireEnd");
			
			A_LaunchSkyMissiles();
			return ResolveState(null);
		}
		wait;
	AltFireEnd:
		JEYC E 15
		{
			A_PlayerAttackAnim(17, 'attack_eyestaff_alt_end', 25);
			A_SpawnSkyMissiles();
			A_StopCharge();
			player.SetPsprite(PSP_Flash, ResolveState("Null"));
		}
	AltFireEndFast:
		JEYC # 0 
		{
			let psp = player.FindPSprite(OverlayID());
			psp.frame = invoker.altStartupFrame;
			A_ResetPsprite(OverlayID(), invoker.altStartupFrame * 2);
		}
		JEYC # 2
		{
			let psp = player.FindPSprite(OverlayID());
			if (psp.frame <= 0)
				return ResolveState("Ready");
			
			psp.frame--;
			return ResolveState(null);
		}
		wait;
	ChargeParticle:
		JEYC P 0 
		{
			A_OverlayPivotAlign(OverlayID(),PSPA_CENTER,PSPA_CENTER);
			A_OverlayFlags(OverlayID(),PSPF_RENDERSTYLE|PSPF_FORCEALPHA,true);
			A_OverlayRenderstyle(OverlayID(),Style_Add);
			A_OverlayAlpha(OverlayID(),0);
			A_OverlayScale(OverlayID(),0.5,0.5);
			let psp = player.FindPSprite(OverlayID());
			if (psp)
			{
				// If this is used by alt attack, use JEYCQ
				// sprite instead of JEYCP:
				if (invoker.bAltFire)
				{
					psp.frame++;
				}
				// If this is for primary and we've fired long enough
				// to charge an after-beam rocket, use JEYCR:
				else if (invoker.charge >= ES_FULLROCKETCHARGE && random[sfx](0,1) == 1)
				{
					psp.frame += 2;
				}
			}
		}
		#### ############## 1 bright 
		{
			let psp = player.FindPSprite(OverlayID());
			let psw = player.FindPSprite(PSP_WEAPON);
			if (psp && psw)
			{
				if (InStateSequence(psw.curstate, invoker.GetReadyState()))
				{
					A_SetTics(2);
				}
				double scalestep = invoker.bAltFire ? 0.1 : 0.05;
				A_OverlayScale(OverlayID(),scalestep,scalestep,WOF_ADD);
				double alpahstep = invoker.bAltFire ? 0.075 : 0.05;
				psp.alpha = Clamp(psp.alpha + alpahstep, 0, 0.85);
				A_OverlayOffset(OverlayID(),psp.x * 0.85, psp.y * 0.85, WOF_INTERPOLATE);
			}
		}
		stop;
	}
}

class ToM_BeamPosController : LineTracer
{
	override ETraceStatus TraceCallback()
	{
		int res = TRACE_Continue;

		switch (results.HitType)
		{
		case TRACE_HitActor:
			if (results.HitActor && (results.HitActor.bShootable || results.HitActor.bSolid))
			{
				res = TRACE_Stop;
			}
			break;
		case TRACE_HitWall:
		case TRACE_HasHitSky:
		case TRACE_HitFloor:
		case TRACE_HitCeiling:
			res = TRACE_Stop;
			break;
		}

		if (res == TRACE_Stop && results.Distance < 128)
		{
			results.HitPos = results.SrcFromTarget + results.HitVector * 128;
		}

		return res;
	}
}

class ToM_EyestaffPuff : ToM_BasePuff
{
	Default
	{
		+NODAMAGETHRUST
		+PUFFONACTORS
		DamageType 'Eyestaff';
		ToM_BasePuff.ParticleAmount 15;
		//ToM_BasePuff.ParticleColor 0xf44dde;
		ToM_BasePuff.ParticleSize 7;
		ToM_BasePuff.ParticleSpeed 6;
		ToM_BasePuff.ParticleTexture 'JEYCP0';
	}

	States {
	XDeath:
		TNT1 A 1;
		stop;
	Crash:
		TNT1 A 1
		{
			if (target)
			{
				FLineTraceData tr;
				SpawnPuffEffects(ToM_Utils.GetNormalFromPos(self, 32, target.angle, target.pitch, tr));
			}
		}
		stop;
	}
}

class ToM_EyestaffBeam : ToM_LaserBeam
{
	const PULSEFREQ = 25;

	Default
	{
		ToM_LaserBeam.LaserColor "c334eb";
		XScale 3.4;
	}
	
	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		if (!bMASTERNOSEE && source && source.player)
		{
			if (source.player == players[consoleplayer])
				bINVISIBLEINMIRRORS = true;
			else
				A_SetRenderstyle(alpha, Style_None);
		}
	}
	
	override void BeamTick()
	{
		alpha = 1.0 - 0.5 * ToM_Utils.SinePulse(PULSEFREQ, GetAge());
	}

	override vector3 GetSourcePos()
	{
		vector3 srcPos = (source.pos.xy, source.pos.z + (source.height * 0.5));
		// bob only first-person views:
		if(!bMASTERNOSEE && source.player && source.player.camera == source && !(source.player.cheats & CF_CHASECAM)) 
		{
			srcPos.z = source.player.viewz;
		}
		
		return srcPos;
	}
}

class ToM_EyestaffBeamInner : ToM_EyestaffBeam
{
	Default
	{
		ToM_LaserBeam.LaserColor "ffee00";
		XScale 1.6;
	}
	
	override void BeamTick()
	{
		alpha = 0.25 + 0.5 * ToM_Utils.SinePulse(PULSEFREQ, GetAge());
	}
}

class ToM_EyestaffProjectile : ToM_Projectile
{
	bool visualMode;
	bool altMode;
	int eyeProjDamage;
	
	static const color SmokeColors[] =
	{
		"850464",
		"d923aa",
		"f74fcc"
	};

	Default
	{
		ToM_Projectile.flarecolor "ff38f5";
		ToM_Projectile.trailtexture "LENGA0";
		ToM_Projectile.trailcolor "c334eb";
		ToM_Projectile.trailfade 0.05;
		ToM_Projectile.trailalpha 1;
		ToM_Projectile.trailscale 0.08;
		ToM_Projectile.trailstyle STYLE_AddShaded;
		DamageType 'Eyestaff';
		+FORCEXYBILLBOARD
		+NOGRAVITY
		+FORCERADIUSDMG
		+BRIGHT
		+ROLLCENTER
		deathsound "weapons/eyestaff/boom1";
		height 13;
		radius 10;
		speed 22;
		DamageFunction GetEyeProjDamage();
		Renderstyle 'Add';
		alpha 0.5;
		xscale 5;
		yscale 6;
		Decal "EyestaffProjectileDecal";
	}

	int GetEyeProjDamage()
	{
		if (eyeProjDamage)
		{
			return eyeProjDamage;
		}
		return altMode? 15 : 100;
	}
	
	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		A_FaceMovementDirection();
		if (visualMode)
		{
			bNOINTERACTION = true;
			double vx = 3.5;
			int life = 25;
			TextureID ptex = TexMan.CheckForTexture("JEYCP0");
			for (double pangle = 0; pangle < 360; pangle += (360.0 / 12))
			{
				A_SpawnParticleEx(
					"",//col,
					ptex,
					STYLE_Add,
					SPF_FULLBRIGHT|SPF_RELATIVE,
					lifetime: life,
					size: 7,
					angle: pangle,
					velx: vx,
					accelx: -(vx / life),
					accelz: -0.1,
					sizestep: -(7. / life)
				);
			}
		}
	}
	
	override void Tick()
	{
		super.Tick();
		if (isFrozen())
			return;
		if (visualMode)
		{
			if (pos.z > ceilingz)
			{
				Destroy();
				return;
			}
			A_FadeOut(0.04);
			trailalpha = alpha * 3;
		}
		A_SetRoll(roll + 16, SPF_INTERPOLATE);
		/*if (tracer && InStateSequence(curstate, spawnstate))
		{
			A_SeekerMissile(0, 0.3, SMF_PRECISE|SMF_CURSPEED);
		}*/
	}

	override void SpawnTrail(vector3 ppos)
	{
		FSpawnParticleParams trail;

		double trailofs = radius * 0.6;
		vector3 projpos = ToM_Utils.RelativeToGlobalCoords(self, (-trailofs, -trailofs, 0), isPosition: false);
		CreateParticleTrail(trail, ppos + projpos, trailvel);
		Level.SpawnParticle(trail);
		
		projpos = ToM_Utils.RelativeToGlobalCoords(self, (-trailofs, trailofs, 0), isPosition: false);
		CreateParticleTrail(trail, ppos + projpos, trailvel);
		Level.SpawnParticle(trail);
	}
	
	States
	{
	Spawn:
		M000 A 4
		{
			double svel = 0.5;
			ToM_WhiteSmoke.Spawn(
				pos,
				ofs: 4,
				vel: (
					frandom[essmk](-svel,svel),
					frandom[essmk](-svel,svel),
					frandom[essmk](-svel,svel)
				),
				scale: 0.3,
				alpha: 0.4,
				fade: 0.15,
				dbrake: 0.6,
				style: STYLE_AddShaded,
				shade: SmokeColors[random[essmk](0, SmokeColors.Size() - 1)],
				flags: SPF_FULLBRIGHT
			);
		}
		loop;
	Death:
		TNT1 A 1 
		{
			if (altMode)
			{
				A_Explode(30, 128);
			}
			else
			{
				A_Explode(128, 160, 0);
			}
			ToM_SphereFX.SpawnExplosion(pos, col1: flarecolor, col2: "fcb126");
			double svel = 2;
			for (int i = 10; i > 0; i--)
			{
				ToM_WhiteSmoke.Spawn(
					pos,
					ofs: 16,
					vel: (
						frandom[essmk](-svel,svel),
						frandom[essmk](-svel,svel),
						frandom[essmk](-svel,svel)
					),
					scale: 0.6,
					rotation: 2,
					alpha: 0.6,
					fade: 0.02,
					dbrake: 0.7,
					dscale: 1.015,
					style: STYLE_AddShaded,
					shade: SmokeColors[random[essmk](0, SmokeColors.Size() - 1)],
					flags: SPF_FULLBRIGHT
				);
			}
		}
		//BAL2 CDE 5;
		stop;
	}
}

class ToM_ESAimingCircle_AfterImage : ToM_ESAimingCircle
{
	Default
	{
		alpha 0.4;
	}

	override void PostbeginPlay()
	{
		ToM_BaseActor.PostBeginPlay();
	}

	override void Tick()
	{
		ToM_BaseActor.Tick();
		A_FadeOut(0.012);
	}
}

class ToM_EyestaffBurnControl : ToM_BurnController
{
	Default
	{
		ToM_ControlToken.duration 200;
		ToM_ControlToken.EffectFrequency 3;
	}

	override color GetFlameColor()
	{
		return ToM_EyestaffProjectile.SmokeColors[random[sfx](0, ToM_EyestaffProjectile.SmokeColors.Size() - 1)];
	}

	override TextureID GetFlameTexture()
	{
		return TexMan.CheckForTexture(ToM_BaseActor.GetRandomWhiteSmoke());
	}

	override void DoControlEffect()
	{
		alpha = ToM_Utils.LinearMap(timer, 0, duration, 1, 0.15);
		Super.DoControlEffect();
	}
}

class ToM_ESAimingCircle : ToM_BaseActor
{
	protected PlayerPawn shooter;
	protected ToM_Eyestaff eyestaff;
	protected int circleID;
	protected int charge;
	protected Canvas circleCanvas;
	protected String canvasTexName;
	protected TextureID circleOut;
	protected TextureID circleIn;
	protected Shape2DTransform circleTransform;
	protected Shape2D outerShape;
	protected Shape2D innerShape;
	protected Shape2D innerEdgeShape;
	protected double circleOutAngle;
	bool chargeFinished;

	Default
	{
		+NOBLOCKMAP
		+NOINTERACTION
		+BRIGHT
		renderstyle 'Add';
		alpha 0.7;
		radius 256;
		scale 8;
		height 1;
	}

	static ToM_ESAimingCircle Create(Vector3 pos, ToM_Eyestaff eyestaff, PlayerPawn shooter, int circleID)
	{
		let c = ToM_ESAimingCircle(Actor.Spawn('ToM_ESAimingCircle', pos));
		if (c)
		{
			c.eyestaff = eyestaff;
			c.shooter = shooter;
			c.circleID = circleID;
		}
		return c;
	}

	override void PostbeginPlay()
	{
		Super.PostBeginPlay();
		canvasTexName = String.Format("EyestaffAimCircle%d%d", shooter? shooter.PlayerNumber() : 0, circleID);
		if (tom_debugmessages)
		{
			Console.Printf("Created canvas texture \cd%s\c- for \cy%s\c-", canvasTexName, GetClassName());
		}
		circleCanvas = TexMan.GetCanvas(canvasTexName);
		if (!circleCanvas)
		{
			Console.Printf("\cgAToM Error:\c- \cg%s\c- is not a valid texture; couldn't obtain Canvas. Destroying \cy%s\c-...", canvasTexName, GetClassName());
			Destroy();
			return;
		}
		A_ChangeModel("", skin: canvasTexName);
		circleOut = TexMan.CheckForTexture("Models/Eyestaff/eyestaff_circle_out.png");
		circleIn = TexMan.CheckForTexture("Models/Eyestaff/eyestaff_circle_in.png");
		if (!circleOut.IsValid() || !circleIn.IsValid())
		{
			Console.Printf("\cgAToM Error:\c- Couldn't obtain textures. Destroying \cy%s\c-...", GetClassName());
			Destroy();
			return;
		}
	}

	void UpdateTransform(double ang = 0)
	{
		if (!circleTransform)
		{
			circleTransform = new('Shape2DTransform');
		}
		
		circleTransform.Clear();
		circleTransform.Scale((radius*2, radius*2));
		circleTransform.Rotate(ang);
		circleTransform.Translate((radius, radius));
	}

	void UpdateOuterShape(double ang)
	{
		if (!outerShape)
		{
			outerShape = New('Shape2D');
			// Create vertices:
			Vector2 p = (-0.5, -0.5); //start at top left corner
			outerShape.PushVertex(p);
			outerShape.PushVertex((p.x, -p.y));
			outerShape.PushVertex((-p.x, p.y));
			outerShape.PushVertex((-p.x, -p.y));
			// Create texture coordinates:
			outerShape.PushCoord((0,0));
			outerShape.PushCoord((0,1));
			outerShape.PushCoord((1,0));
			outerShape.PushCoord((1,1));
			// Create triangles:
			outerShape.PushTriangle(0,1,2);
			outerShape.PushTriangle(1,2,3);
		}

		UpdateTransform(ang);
		outerShape.SetTransform(circleTransform);
	}

	void UpdateInnerShape()
	{
		if (chargeFinished) return;

		if (!innerShape)
		{
			innerShape = new('Shape2D');
		}
		else
		{
			innerShape.Clear(Shape2D.C_Verts);
			innerShape.Clear(Shape2D.C_Coords);
			innerShape.Clear(Shape2D.C_Indices);
		}
		if (!eyestaff) return;

		// Create center vertex:
		innerShape.PushVertex((0, 0));
		// Texture offsets relative to vertex positions, 
		// since textures use 0.0-1.0 range:
		Vector2 texOfs = (0.5, 0.5);
		innerShape.PushCoord(texOfs);
		// Calculate how far to move along the circle based
		// on highest latest charge (we're not reducing this
		// since eyestaff will decrement it when firing,
		// which we don't want to reflect):
		charge = max(charge, eyestaff.charge);
		double angstep = 360.0 / ToM_Eyestaff.ES_FULLALTCHARGE;
		double finalAng = 360.0 * (double(charge) / ToM_Eyestaff.ES_FULLALTCHARGE);
		int steps = charge;

		Vector2 p = (0, -1); //first edge vertex (top)
		for (int i = 0; i < steps; i++)
		{
			p = Actor.RotateVector(p, angStep);
			innerShape.PushVertex(p);
			innerShape.PushCoord(p + texOfs);
		}
		// Create triangles. Each triangle must connect
		// the center vertex with two edge vertices. We begin at 1,
		// because 0 is the coordinate of the center:
		for (int i = 1; i <= steps; i++)
		{
			int next = i+1;
			// looped around:
			if (next > steps)
			{
				if (finalAng >= 360)
				{
					next = 1;
				}
				else
				{
					break;
				}
			}
			// Create a triangle between center,
			// edge vertex and the next edge vertex:
			innerShape.PushTriangle(0, i, next);
		}

		UpdateTransform();
		innerShape.SetTransform(circleTransform);

		if (!innerEdgeShape)
		{
			innerEdgeShape = new('Shape2D');
			p = (0, 0);
			innerEdgeShape.PushVertex(p);
			innerEdgeShape.PushCoord((0,0));
			Vector2 s = (0, -0.38);
			p = Actor.RotateVector(s, finalAng - 2);
			innerEdgeShape.PushVertex(p);
			innerEdgeShape.PushCoord((0,0));
			p = Actor.RotateVector(s, finalAng);
			innerEdgeShape.PushVertex(p);
			innerEdgeShape.PushCoord((0,0));

			innerEdgeShape.PushTriangle(0, 1, 2);
		}
		UpdateTransform(finalAng);
		innerEdgeShape.SetTransform(circleTransform);
	}

	override void Tick()
	{
		Super.Tick();
		SetZ(floorz+1);
		
		double width = radius*2;
		circleCanvas.Clear(0, 0, width, width, 0xff000000);
		
		UpdateOuterShape(circleOutAngle);
		circleCanvas.DrawShape(circleOut, false, outerShape);
		circleOutAngle += 0.5;

		UpdateInnerShape();
		circleCanvas.DrawShape(circleIn, false, innerShape);
		if (charge < ToM_Eyestaff.ES_FULLALTCHARGE)
		{
			circleCanvas.DrawShapeFill(0xf170ff, 1.0, innerEdgeShape);
		}

		if (charge >= ToM_Eyestaff.ES_FULLALTCHARGE && !chargeFinished)
		{
			let ai = Spawn('ToM_ESAimingCircle_AfterImage', pos);
			if (ai)
			{
				ai.vel.z = 1;
				ai.A_ChangeModel("", skin: canvasTexName);
			}
		}
	}
	
	States 
	{
	Spawn:
		M000 A -1;
		stop;
	}
}

class ToM_SkyMissilesSpawner : ToM_BaseActor
{
	int charge;
	double zShift;
	double circleRad;
	array<Actor> projTargets;
	int targetID;
	
	static const color EyeColor[] = 
	{
		"c334eb",
		"ff00f7",
		"70006b"
	};
	
	Default
	{
		+NOINTERACTION
		+NOBLOCKMAP
		radius 160;
		height 1;
	}
	
	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		let proj = GetDefaultByType("ToM_EyestaffProjectile");
		if (proj)
		{
			zShift = proj.height;
		}
		let circle = GetDefaultByType("ToM_ESAimingCircle");
		if (circle)
		{
			circleRad = circle.radius;
		}
	}
	
	override void Tick()
	{
		if (!target)
		{
			Destroy();
			return;
		}
		super.Tick();
		
		if (isFrozen())
			return;
		
		FSpawnParticleParams pp;
		pp.texture = TexMan.CheckForTexture(ToM_BaseActor.GetRandomWhiteSmoke());
		pp.style = STYLE_AddShaded;
		pp.color1 = EyeColor[random[eyec](0, EyeColor.Size()-1)];
		pp.lifetime = random[eyec](30, 50);
		pp.size = frandom[eyec](100, 140);
		pp.startalpha = 1.0;
		pp.fadestep = -1;
		pp.startroll = frandom[eyec](0, 360);
		double hv = 0.6;
		pp.vel.x = frandom[eyec](-hv,hv);
		pp.vel.y = frandom[eyec](-hv,hv);
		pp.vel.z = frandom[eyec](-hv,0);
		for (int i = int(ToM_Utils.LinearMap(charge, 0, ToM_Eyestaff.ES_FULLBEAMCHARGE, 1, 7)); i > 0; i--)
		{		
			vector3 ppos = pos;
			ppos.xy = Vec2Angle(frandom[eye](0, circleRad), random[eye](0, 359));

			double toplimit = Level.PointInSector(ppos.xy).NextHighestCeilingAt(ppos.x, ppos.y, ppos.z, ppos.z);
			ppos.z = Clamp(ppos.z, floorz, toplimit);

			pp.pos = ppos;
			Level.SpawnParticle(pp);
		}
	}
	
	States 
	{
	Spawn:
		TNT1 A 30 NoDelay
		{
			if (tracer)
			{
				let bt = BlockThingsIterator.Create(tracer, circleRad);
				while (bt.Next())
				{
					let t = bt.thing;
					if (target && t != target && t.bShootable && (t.bIsMonster || t.player) && t.health > 0 && tracer.Distance2D(t) <= circleRad && t.isHostile(target))
					{
						projTargets.Push(t);
					}
				}
			}
		}
		TNT1 A 3 
		{
			if (charge > 0)
			{
				vector3 ppos = pos;
				for (int i = 10; i > 0; i--)
				{
					ppos = (
						pos.x + frandom(-radius, radius), 
						pos.y + frandom(-radius, radius), 
						pos.z - zShift
					);
					double botlimit = level.PointInSector(ppos.xy).NextLowestFloorAt(ppos.x, ppos.y, ppos.z);
					double toplimit = level.PointInSector(ppos.xy).NextHighestCeilingAt(ppos.x, ppos.y, ppos.z, ppos.z, ppos.z + 1);
					ppos.z = Clamp(ppos.z, botlimit, toplimit - zShift);
					if (Level.IsPointInLevel(ppos))
						break;
				}
				for (int i = projTargets.Size() - 1; i >= 0; i--)
				{
					let mo = projTargets[i];
					if (!mo || mo.health <= 0)
					{
						projTargets.Delete(i);
					}
				}
				let proj = ToM_EyestaffProjectile(Spawn("ToM_EyestaffProjectile", ppos));
				if (proj)
				{
					proj.target = target;
					proj.altMode = true;
					if (projTargets.Size() > 0)
					{
						if (++targetID >= projTargets.Size())
						{
							targetID = 0;
						}
						proj.tracer = projTargets[targetID];
						if (proj.tracer)
						{
							Vector3 dir = level.Vec3Diff(proj.pos, proj.tracer.pos).Unit();
							proj.vel = dir * proj.speed;
						}
					}
					if (!proj.tracer)
					{
						proj.vel.z = -proj.speed;
						double hvel = 2.8;
						proj.vel.xy = (frandom(-hvel,hvel), frandom(-hvel,hvel));
					}
					proj.A_FaceMovementDirection();
				}
				charge--;
			}
			else if (tracer)
			{
				tracer.A_FadeOut(0.05);
			}
			else
			{
				return ResolveState("Null");
			}
			return ResolveState(null);
		}
		wait;
	}
}

class ToM_OuterBeamPos : ToM_BaseActor
{
	Default
	{
		+NOBLOCKMAP
	}

	override void Tick()
	{
		if (!master)
		{
			Destroy();
			return;
		}

		Vector3 ofs;
		ofs.xy = Actor.RotateVector((master.radius+14, -9.5), master.angle);
		ofs.z = master.height*0.46;
		SetOrigin(master.pos + ofs + master.vel, true);
	}
}