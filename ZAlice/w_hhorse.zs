class ToM_HobbyHorse : ToM_BaseWeapon
{
	int combo;	
	protected array < Actor > swingVictims; //actors hit by the attack
	protected vector2 swingOfs;
	protected vector2 swingStep;
	protected int swingSndCounter; //delay the attack sound
	const SWINGSTAGGER = 8; // by this much
	
	Default
	{
		Tag "Hobby Horse";
		ToM_BaseWeapon.IsTwoHanded true;
		+WEAPON.MELEEWEAPON
		+WEAPON.NOAUTOFIRE
		Weapon.slotnumber 1;
		Weapon.slotpriority 1;
	}
	
	// Set up the swing: initial coords and the step:
	action void A_PrepareSwing(double startX, double startY, double stepX, double stepY)
	{
		invoker.swingVictims.Clear();
		invoker.swingOfs = (startX, startY);
		invoker.swingStep = (stepX, stepY);
	}
	
	// Do the attack and move the offset one step as defined above:
	action void A_SwingAttack(int damage, double range = 64, class<Actor> pufftype = 'ToM_HorsePuff')
	{
		// Get the screen-relative angle/pitch using Gutamatics:
		ToM_GM_Quaternion view = ToM_GM_Quaternion.createFromAngles(angle, pitch, roll);
		ToM_GM_Quaternion ofs = ToM_GM_Quaternion.createFromAngles(invoker.swingOfs.x, invoker.swingOfs.y, 0);
		ToM_GM_Quaternion res = view.multiplyQuat(ofs);		
		double aimAng, aimPch;
		[aimAng, aimPch] = res.toAngles();
		
		FLineTraceData hit;
		LineTrace(
			aimAng, 
			range, 
			aimPch, 
			TRF_NOSKY|TRF_SOLIDACTORS, 
			ToM_UtilsP.GetPlayerAtkHeight(PlayerPawn(self)), 
			data: hit
		);
		
		let type = hit.HitType;
		// Do this if we hit geometry:
		if (type == TRACE_HitFloor || type == TRACE_HitCeiling || type == TRACE_HitWall)
		{
			if (invoker.swingSndCounter <= 0)
			{
				invoker.swingSndCounter = SWINGSTAGGER;
				A_StartSound("weapons/hhorse/hitwall", CHAN_AUTO);
				int val = 1 * invoker.combo;
				A_QuakeEx(val, val, val, 6, 0, 32, "");				
			}
		}
		
		// Do this if we hit an actor:
		else if (type == TRACE_HitActor)
		{
			let victim = hit.HitActor;
			// Check the victim is valid and not yet in the array:
			if (victim && (victim.bSHOOTABLE || victim.bVULNERABLE || victim.bSOLID) && invoker.swingVictims.Find(victim) == invoker.swingVictims.Size())
			{
				invoker.swingVictims.Push(victim);
				// Can be damaged:
				if (!victim.bDORMANT && (victim.bSHOOTABLE || victim.bVULNERABLE))
				{
					victim.DamageMobj(self, self, damage, 'normal');
					A_StartSound("weapons/hhorse/hitflesh", CHAN_WEAPON);
					// Bleed:
					if (!victim.bNOBLOOD)
					{
						victim.TraceBleed(damage, self);
						victim.SpawnBlood(hit.HitLocation, AngleTo(victim), damage);
					}
				}
				// Can't be damaged:
				else
					A_StartSound("weapons/hhorse/hitwall", CHAN_AUTO);
			}
		}
		// Debug spot:
		// let spot = Spawn("ToM_DebugSpot", hit.hitlocation);
		// spot.A_SetHealth(1);
		
		// Add a step:
		invoker.swingOfs += invoker.swingStep;
	}
	
	override void DoEffect()
	{
		super.DoEffect();
		if (swingSndCounter > 0)
			swingSndCounter--;
	}
	
	States
	{
	Spawn:
		ALHH A -1;
		stop;
	Select:
		HHRS A 0 
		{
			A_WeaponOffset(-24, 90+WEAPONTOP);
			A_OverlayPivot(OverlayID(), 0.6, 0.8);
			A_OverlayRotate(OverlayID(), -18);
		}
		#### ###### 1
		{
			A_WeaponOffset(4, -15, WOF_ADD);
			A_OverlayRotate(OverlayID(), 3, WOF_ADD);
			A_WeaponReady(WRF_NOFIRE|WRF_NOBOB);
		}
		goto Ready;
	Deselect:
		HHRS A 0
		{
			A_OverlayPivot(OverlayID(), 0.6, 0.8);
		}
		#### ###### 1
		{
			A_ResetZoom();
			A_WeaponOffset(-4, 15, WOF_ADD);
			A_OverlayRotate(OverlayID(), -3, WOF_ADD);
		}
		TNT1 A 0 A_Lower;
		wait;		
	Ready:
		HHRS A 1 A_WeaponReady();
		wait;
	Fire:
		TNT1 A 0 
		{
			A_ResetPSprite();
			invoker.combo++;
			if (invoker.combo <= 1)
				return ResolveState("RightSwing");
			if (invoker.combo == 2)
				return ResolveState("LeftSwing");
			return ResolveState("Overhead");			
		}
	RightSwing:
		TNT1 A 0 A_OverlayPivot(OverlayID(), 0.1, 0.6);
		HHRS AAABBBB 1 
		{
			A_WeaponOffset(6, 0, WOF_ADD);
			A_RotatePSprite(OverlayID(), -1.2, WOF_ADD);
		}		
		HHRS CCCC 1 
		{
			A_WeaponOffset(3, 0, WOF_ADD);
			A_RotatePSprite(OverlayID(), -0.5, WOF_ADD);
		}
		TNT1 A 0 
		{
			A_PrepareSwing(-25, -10, 14, 4);
			A_StartSound("weapons/hhorse/swing", CHAN_AUTO);
			A_CameraSway(4, 0, 6);
		}
		HHRS BB 1 
		{
			A_SwingAttack(30);
			A_WeaponOffset(-35, 12, WOF_ADD);
			A_RotatePSprite(OverlayID(), 3, WOF_ADD);
		}
		TNT1 A 0 A_Overlay(APSP_Overlayer, "RightSwingTrail");
		HHRS DD 1 
		{
			A_SwingAttack(30);
			A_WeaponOffset(-50, 22, WOF_ADD);
			A_RotatePSprite(OverlayID(), 3, WOF_ADD);
		}
		HHRS DDD 1 
		{
			A_SwingAttack(30);
			A_WeaponOffset(-50, 22, WOF_ADD);
			A_RotatePSprite(OverlayID(), 4, WOF_ADD);
		}
		goto AttackEnd;
	RightSwingTrail:
		HHRR ABCDA 1 bright
		{
			let from = player.FindPSprite(PSP_WEAPON);
			let to = player.FindPSprite(OverlayID());
			if (from && to)
			{
				to.pivot = from.pivot;
				to.rotation = from.rotation;
			}
		}
		stop;
	LeftSwing:			
		TNT1 A 0 A_OverlayPivot(OverlayID(), 0.6, 1);
		HHRS AAAEEEE 1 
		{
			A_WeaponOffset(-6, 0, WOF_ADD);
			A_RotatePSprite(OverlayID(), 1.2, WOF_ADD);
		}
		HHRS GGGG 1 
		{
			A_WeaponOffset(-3, 0, WOF_ADD);
			A_RotatePSprite(OverlayID(), 0.5, WOF_ADD);
		}
		TNT1 A 0 
		{
			A_PrepareSwing(25, -10, -15, 5);
			A_StartSound("weapons/hhorse/swing", CHAN_AUTO);
			A_CameraSway(-4, 0, 6);
		}
		HHRS FF 1 
		{
			A_SwingAttack(30);
			A_WeaponOffset(35, 12, WOF_ADD);
			A_RotatePSprite(OverlayID(), -3, WOF_ADD);
		}
		TNT1 A 0 A_Overlay(APSP_Overlayer, "LeftSwingTrail");
		HHRS HH 1 
		{
			A_SwingAttack(30);
			A_WeaponOffset(45, 18, WOF_ADD);
			A_RotatePSprite(OverlayID(), -3, WOF_ADD);
		}
		HHRS HHH 1 
		{
			A_SwingAttack(30);
			A_WeaponOffset(45, 18, WOF_ADD);
			A_RotatePSprite(OverlayID(), -3, WOF_ADD);
		}
		goto AttackEnd;
	LeftSwingTrail:
		HHRL ABCDA 1 bright
		{
			let from = player.FindPSprite(PSP_WEAPON);
			let to = player.FindPSprite(OverlayID());
			if (from && to)
			{
				to.pivot = from.pivot;
				to.rotation = from.rotation;
			}
		}
		stop;
	Overhead:				
		TNT1 A 0 A_OverlayPivot(OverlayID(), 0.2, 0.8);
		HHRS KKKKLLLL 1 
		{
			A_WeaponOffset(1.2, -3, WOF_ADD);
			A_RotatePSprite(OverlayID(), -0.3, WOF_ADD);
			A_ScalePSprite(OverlayID(), 0.0025, 0.0025,WOF_ADD);
		}
		HHRS MMMMMMMM 1 
		{
			A_WeaponOffset(0.6, -1.2, WOF_ADD);
			A_RotatePSprite(OverlayID(), -0.3, WOF_ADD);
			A_ScalePSprite(OverlayID(), 0.0025, 0.0025,WOF_ADD);
		}
		TNT1 A 0 
		{
			A_PrepareSwing(-5, -30, 1.5, 16);
			A_StartSound("weapons/hhorse/heavyswing", CHAN_AUTO);
			A_CameraSway(0, 5, 7);
			A_Overlay(APSP_Overlayer, "OverheadTrail");
		}
		HHRS NOO 1 
		{
			A_SwingAttack(60);
			A_WeaponOffset(-24, 35, WOF_ADD);
			A_RotatePSprite(OverlayID(), 0.1, WOF_ADD);
			A_ScalePSprite(OverlayID(), -0.003, -0.003, WOF_ADD);
		}
		HHRS OO 1 
		{
			A_SwingAttack(60);
			A_WeaponOffset(-24, 35, WOF_ADD);
			A_RotatePSprite(OverlayID(), 0.1, WOF_ADD);
			A_ScalePSprite(OverlayID(), -0.003, -0.003, WOF_ADD);
		}
		TNT1 A 0 { invoker.combo = 0; }
		goto AttackEnd;
	OverheadTrail:
		TNT1 A 1;
		HHRO ABCD 1 bright
		{
			let from = player.FindPSprite(PSP_WEAPON);
			let to = player.FindPSprite(OverlayID());
			if (from && to)
			{
				to.pivot = from.pivot;
				to.rotation = from.rotation;
			}
		}
		stop;
	AttackEnd:
		TNT1 A 5
		{
			A_WeaponOffset(24, 90+WEAPONTOP);
			A_RotatePSprite(OverlayID(), -30);
			A_WeaponReady(WRF_NOBOB);
		}
		HHRS AAAAAA 1
		{
			A_WeaponOffset(-4, -15, WOF_ADD);
			A_RotatePSprite(OverlayID(), 5, WOF_ADD);
			A_WeaponReady(WRF_NOBOB);
		}
		TNT1 A 0 
		{ 
			A_ResetPSprite();
			invoker.combo = 0;
		}
		goto Ready;
	}
}

class ToM_HorsePuff : ToM_BasePuff
{
	Default
	{
		+NOINTERACTION
		+PUFFONACTORS
		seesound "weapons/hhorse/hitflesh";
		attacksound "weapons/hhorse/hitwall";
	}
	
	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		int val = 1;
		if (target && target.player)
		{
			let wpn = ToM_HobbyHorse(target.player.readyweapon);
			if (wpn)
				val *= wpn.combo;
			target.A_QuakeEx(val, val, val, 6, 0, 32, "");
		}
	}
	
	States
	{
	Spawn:
		TNT1 A 10;
		stop;
	}
}