class ToM_HobbyHorse : ToM_BaseWeapon
{
	int combo;	
	protected array < Actor > swingVictims;
	protected vector2 swingOfs;
	protected vector2 swingStep;
	protected int swingSndCounter;
	const SWINGSTAGGER = 8;
	
	Default
	{
		+WEAPON.MELEEWEAPON
		Weapon.slotnumber 1;
		Weapon.slotpriority 1;
		Tag "Hobby Horse";
	}
	
	
	action void A_PrepareSwing(double startX, double startY, double stepX, double stepY)
	{
		invoker.swingVictims.Clear();
		invoker.swingOfs = (startX, startY);
		invoker.swingStep = (stepX, stepY);
	}
	
	action void A_SwingAttack(int damage, double range = 64, class<Actor> pufftype = 'ToM_HorsePuff')
	{			
		FLineTraceData hit;
		LineTrace(
			angle + invoker.swingOfs.x, 
			radius + range, 
			pitch + invoker.swingOfs.y, 
			TRF_NOSKY|TRF_SOLIDACTORS, 
			ToM_BaseActor.GetPlayerAtkHeight(PlayerPawn(self)), 
			data: hit
		);
		
		let type = hit.HitType;
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
		
		else if (type == TRACE_HitActor)
		{
			let victim = hit.HitActor;
			if (victim && (victim.bSHOOTABLE || victim.bVULNERABLE || victim.bSOLID) && invoker.swingVictims.Find(victim) == invoker.swingVictims.Size())
			{
				invoker.swingVictims.Push(victim);
				if (!victim.bDORMANT && (victim.bSHOOTABLE || victim.bVULNERABLE))
				{
					victim.DamageMobj(self, self, damage, 'normal');
					A_StartSound("weapons/hhorse/hitflesh", CHAN_WEAPON);
					if (!victim.bNOBLOOD)
					{
						victim.TraceBleed(damage, self);
						victim.SpawnBlood(hit.HitLocation, AngleTo(victim), damage);
					}
				}
				else
					A_StartSound("weapons/hhorse/hitwall", CHAN_AUTO);
			}
		}
		//let spot = Spawn("ToM_DebugSpot", hit.hitlocation);
		//spot.A_SetHealth(1);
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
		HHRS AAAAABBBBB 1 
		{
			A_WeaponOffset(5, 0, WOF_ADD);
			A_RotatePSprite(OverlayID(), -1, WOF_ADD);
		}		
		HHRS CCCCC 1 
		{
			A_WeaponOffset(3, 0, WOF_ADD);
			A_RotatePSprite(OverlayID(), -0.5, WOF_ADD);
		}
		TNT1 A 0 
		{
			A_PrepareSwing(-25, -10, 10, 4);
			A_StartSound("weapons/hhorse/swing", CHAN_AUTO);
			A_CameraSway(4, 0, 6);
		}
		HHRS BB 1 
		{
			A_SwingAttack(30);
			A_WeaponOffset(-35, 12, WOF_ADD);
			A_RotatePSprite(OverlayID(), 3, WOF_ADD);
		}
		HHRS DD 1 
		{
			A_SwingAttack(30);
			A_WeaponOffset(-45, 18, WOF_ADD);
			A_RotatePSprite(OverlayID(), 3, WOF_ADD);
		}
		HHRS DDD 1 
		{
			A_SwingAttack(30);
			A_WeaponOffset(-45, 18, WOF_ADD);
			A_RotatePSprite(OverlayID(), 3, WOF_ADD);
		}
		goto AttackEnd;
	LeftSwing:			
		TNT1 A 0 A_OverlayPivot(OverlayID(), 0.6, 1);
		HHRS AAAAAEEEEE 1 
		{
			A_WeaponOffset(-5, 0, WOF_ADD);
			A_RotatePSprite(OverlayID(), 1, WOF_ADD);
		}
		HHRS GGGGG 1 
		{
			A_WeaponOffset(-3, 0, WOF_ADD);
			A_RotatePSprite(OverlayID(), 0.5, WOF_ADD);
		}
		TNT1 A 0 
		{
			A_PrepareSwing(25, -10, -10, 5);
			A_StartSound("weapons/hhorse/swing", CHAN_AUTO);
			A_CameraSway(-4, 0, 6);
		}
		HHRS FF 1 
		{
			A_SwingAttack(30);
			A_WeaponOffset(35, 12, WOF_ADD);
			A_RotatePSprite(OverlayID(), -3, WOF_ADD);
		}
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
	Overhead:				
		TNT1 A 0 A_OverlayPivot(OverlayID(), 0.2, 0.8);
		HHRS KKKKLLLL 1 
		{
			A_WeaponOffset(1.2, -3, WOF_ADD);
			A_RotatePSprite(OverlayID(), -0.3, WOF_ADD);
			A_ScalePSprite(OverlayID(), 0.0025, 0.0025,WOF_ADD);
		}
		HHRS MMMMMMMMMM 1 
		{
			A_WeaponOffset(0.5, -1, WOF_ADD);
			A_RotatePSprite(OverlayID(), -0.3, WOF_ADD);
			A_ScalePSprite(OverlayID(), 0.0025, 0.0025,WOF_ADD);
		}
		TNT1 A 0 
		{
			A_PrepareSwing(-5, -30, 1.5, 12);
			A_StartSound("weapons/hhorse/heavyswing", CHAN_AUTO);
			A_CameraSway(0, 5, 7);
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
	AttackEnd:
		TNT1 A 5
		{
			A_WeaponOffset(24, 90+WEAPONTOP);
			A_RotatePSprite(OverlayID(), -30);
		}
		HRS1 AAAAAA 1
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