Mixin class ToM_SmoothMoveTurnMixin
{
	//ChaseSmooth works by  storing the state ChaseSmooth was called from, and using that information along with
	//the actor's tics value to determine if the ChaseSmoth call each tic should have the chance to result in an attack, or just moving & turning.
	//The smooth turning functions work in a similar way.
	Actor smtActor;//the actor instance this mixin belongs to
	State smtChaseState;
	bool smtChasing;//controls wether to call A_Chase or A_Wander in ChaseSmooth
	int smtChaseFlags;//stores any A_Chase flags for use during Tick()
	
	State smtTurnState;
	double smtAngleTarget;
	double smtTurnSpeed;//the difference between starting angle and smtAngleTarget divided by smtTurnState.tics
	double smtTurnSpeedMax;//if > 0, if smtLimitTurnSpeed is true and when chasing or wandering, limit smtTurnSpeed to to this
	bool smtLimitTurnSpeed;//set to true when chasing or wandering
	
	void InitSmoothMoveTurnMixin(Actor other, double turnSpeedMax = 0)
	{
		smtActor = other;
		smtTurnSpeedMax = turnSpeedMax;
	}
	
	//To be called from the smtActor's Tick()
	void UpdateSmoothMoveTurnMixin()
	{
		if(smtActor == null)
		{
			return;
		}
		//this chase behavior is called when the monster is in a state that called A_ChaseSmooth, 
		//but is not the first tic in that state
		if(smtChaseState && smtActor.curState && smtActor.tics != smtActor.curState.tics)
		{
			if (smtActor.curState == smtChaseState)
			{
				ChaseSmooth(melee : null, missile : null, chaseFlags : smtChaseFlags, chase : smtChasing);
			}
			else
			{
				smtChaseState = null;
				smtChasing = false;
				smtChaseFlags = 0;
			}
		}
		//this is used for turning smoothly.
		if (smtTurnState && smtActor.curState && smtActor.tics != smtActor.curState.tics)
		{
			if(smtActor.curState == smtTurnState)
			{
				TurnTowards();
			}
			else
			{
				smtTurnState = null;
				smtLimitTurnSpeed = false;
			}
		}
	}
	
	//Smooth chasing code by Boondorl
	//Smooth turning code by phantombeta
	void ChaseSmooth(StateLabel melee = '_a_chase_default', StateLabel missile = '_a_chase_default', int chaseFlags = 0, bool chase = true)
	{
		smtChasing = chase;
		smtChaseState = smtActor.curState;
		smtChaseFlags = chaseFlags;

		Vector3 tempPos = smtActor.pos;
		double angleTemp = smtActor.angle;
		smtLimitTurnSpeed = true;
		
		if(chase)
		{
			if(smtActor.target == null)
			{
				return;
			}
			A_Chase(melee,missile,chaseFlags);
		}
		else
		{
			A_Wander(chaseFlags);
		}

		Vector3 diff = (smtActor.pos - tempPos);
		Vector3 dir = !(diff ~== (0, 0, 0)) ? diff.Unit() : (0, 0, 0);
		smtActor.SetOrigin(tempPos + dir * smtActor.speed,true);
		
		smtActor.A_SetAngle(angleTemp);
		//only rotate for the initial ChaseSmooth call, and not the automatic ones from Tick()
		if(smtActor.tics == smtActor.curState.tics)
		{
			FaceAngleSmooth(smtActor.moveDir * 45);
		}
	}

	//Shortcut for smooth wandering.  
	void WanderSmooth(int flags = 0)
	{
		ChaseSmooth(null,null,flags,false);
	}
	
	//Smooth variant of A_Face(). Pass target as a parameter to replicate A_FaceTarget.
	void FaceSmooth(Actor other = null,int flags = 0)
	{
		if(other == null)
		{
			return;
		}
		double angleTemp = smtActor.angle;
		smtActor.A_Face(other,0,0,0,0,flags);//for pitch setting
		smtActor.A_SetAngle(angleTemp);
		FacePosSmooth(other.pos + (0,0,flags == FAF_MIDDLE ? double(other.height) / 2 : 0));
	}
	//for facing a position
	void FacePosSmooth(Vector3 targetPos)
	{
		Vector3 sCoords = LevelLocals.SphericalCoords(smtActor.pos,targetPos,(smtActor.angle,smtActor.pitch));
		FaceAngleSmooth(smtActor.angle - sCoords.x);
	}
	
	void FaceAngleSmooth(double a)
	{
		smtTurnState = smtActor.curState;
		smtAngleTarget = a;
		double angDiff = DeltaAngle(smtActor.angle,smtAngleTarget);
		smtTurnSpeed = abs(angDiff / (smtTurnState.tics > 0 ? smtTurnState.tics : 1));
		if(smtLimitTurnSpeed && smtTurnSpeedMax > 0)
		{
			smtTurnSpeed = Clamp(smtTurnSpeed,0,smtTurnSpeedMax);
		}
		TurnTowards();
	}
	//the base smooth turning function, turns smoothly towards any angle. 
	//This is only  to be called from Tick(), ChaseSmooth, or the other smooth rotating functions.
	protected void TurnTowards()
	{
		double angDiff = DeltaAngle(smtActor.angle,smtAngleTarget);
		double angleChange = angDiff < 0 ? max(-smtTurnSpeed, angDiff) : min(smtTurnSpeed, angDiff);
		smtActor.A_SetAngle(smtActor.angle + angleChange);
		//console.printf("[SmoothMoveTurnMixin/TurnTowards] smtAngleTarget = %f, angDiff = %f, smtTurnSpeed = %f, angleChange = %f, angle = %f",smtAngleTarget,angDiff,smtTurnSpeed,angleChange,smtActor.angle);
	}
}

class ToM_MonsterBase : ToM_BaseActor abstract
{
    mixin ToM_SmoothMoveTurnMixin;
	sound XDeathsound;
	property XDeathsound : XDeathsound;
	bool wasgibbed;

	double hitboxRadius;
	double hitboxheight;
	property hitboxRadius : hitboxRadius;
	property hitboxheight : hitboxheight;

	Default
	{
		Monster;
	}
	
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		InitSmoothMoveTurnMixin(self,turnSpeedMax : 10.0);
		if (hitboxRadius > 0. || hitboxheight > 0.)
		{
			let hb = Spawn("ToM_MonsterHitbox", pos);
			if (hb)
			{
				hb.master = self;
				hb.A_SetSize(hitboxRadius, hitboxheight);
			}
		}
	}

	override void Tick()
	{
		Super.Tick();
		UpdateSmoothMoveTurnMixin();
	}
}

class ToM_MonsterHitbox : ToM_BaseActor
{
	vector2 masterSizeDiff;

	Default
	{
		+NOGRAVITY
		+NOBLOOD
	}

	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		if (master)
		{
			masterSizeDiff = (radius - master.radius, height - master.height);
		}
	}

	override void Tick()
	{
		if (!master)
		{
			Destroy();
			return;
		}
		//RadiusDebug.Enable(self);
		//super.Tick();
		A_SetSize(master.radius + masterSizeDiff.x, master.height + masterSizeDiff.y);
		bSHOOTABLE = master.bSHOOTABLE;
		console.printf("hitbox for %s | size %1.f x %.1f", master.GetTag(), radius, height);
		SetOrigin(master.pos, true);
		A_SetAngle(master.angle, SPF_INTERPOLATE);
		A_SetPitch(master.angle, SPF_INTERPOLATE);
	}
	override int DamageMobj (Actor inflictor, Actor source, int damage, Name mod, int flags, double angle)
	{
		if (master)
		{
			master.DamageMobj(inflictor, source, damage, mod, flags, angle);
		}
		return 0;
	}

	/*override bool CanCollideWith(Actor other, bool passive)
	{
		if (!master || !master.bSOLID || !master.bSHOOTABLE)
			return false;

		bool ret = super.CanCollideWith(other, passive);
		// allow collision with real missiles:
		if (ret && passive && other && other.bMISSILE && other.bACTIVATEIMPACT)
		{
			return true;
		}
		return false;
	}*/

	override bool CanCrossLine(Line crossing, Vector3 next)
	{
		return true;
	}
}

class ToM_Cardguard_Club : ToM_MonsterBase
{
	Default
	{	
		Scale 0.75;
		Height 56;
		Radius 20;
		ToM_MonsterBase.hitboxRadius 26;
		ToM_MonsterBase.hitboxheight 64;
		Health 60;
		Painchance 200;
		Speed 4.5;
		MeleeRange 72;
		Dropitem "Clip";
		Species "Cardguard";
		SeeSound "characters/cardguard/club/see";
		ActiveSound "characters/cardguard/club/see";
		AttackSound "characters/cardguard/attack";
		PainSound "characters/cardguard/pain";
		DeathSound "characters/cardguard/death";
		ToM_MonsterBase.XDeathsound "characters/cardguard/gibs";
	}

	override int DamageMobj (Actor inflictor, Actor source, int damage, Name mod, int flags, double angle)
	{
		int ret = super.DamageMobj(inflictor, source, damage, mod, flags, angle);
		if (health <= 0 && inflictor && (!source || inflictor != source) && inflictor.pos.z >= pos.z + default.height * 0.85)		
		{
			state xd = ResolveState("XDeath");
			if (xd  && !InStateSequence(curstate, xd ))
			{
				SetState(xd);
			}
		}
		return ret;
	}

	override void PostBeginPlay()
	{
		super.PostBeginPlay();
		A_ChangeModel("", 1, "models/characters/cardguard", "cardguard_club_staff.iqm");
	}

	static const color guardBloodColors[] = { "810505", "b82323", "93136a", "931388" };

	void A_SpawnBloodSpurt(vector3 ofs = (0,0,0), vector3 pvel = (0,0,0))
	{
		FSpawnParticleParams pblood;
		pblood.flags = SPF_REPLACE;
		pblood.size = frandom[sfx](4, 8);
		pblood.lifetime = 50;
		pblood.sizestep = pblood.size / pblood.lifetime * -0.5;
		for (int i = 5; i > 0; i--)
		{
			pblood.color1 = guardBloodColors[random[sfx](0, guardBloodColors.Size() - 1)];
			
			ofs += (
				frandom[sfx](-2, 2),
				frandom[sfx](-2, 2),
				frandom[sfx](-2, 2)
			);
			pblood.pos = ToM_UtilsP.RelativeToGlobalCoords(self, ofs);
			
			pvel += (
				frandom[sfx](-1, 1),
				frandom[sfx](-1, 1),
				frandom[sfx](-1, 1)
			);
			pblood.vel = ToM_UtilsP.RelativeToGlobalCoords(self, pvel, false);
			
			pblood.accel.xy = pblood.vel.xy / -pblood.lifetime;
			pblood.accel.z = GetGravity() * -0.3;
			pblood.startalpha = 1;
			pblood.fadestep = -1;
			Level.SpawnParticle(pblood);
		}		
	}

	void A_XDeathScream()
	{
		A_StartSound(XDeathsound, CHAN_VOICE);
	}

    States {
    Spawn:
        #### # 1 nodelay
        {
            state togo;
            switch (random[pickanim](0, 10))
            {
            default:
                togo = ResolveState("Idle");
                break;
            case 10:
            case 9:
                togo = ResolveState("IdleScratch");
                break;
            case 8:
            case 7:
                togo = ResolveState("IdleTwirl");
                break;
            }
			return togo;
        }
        loop;
    Idle:
        M000 BCDEFGHIJKLMNO 3 A_Look;
        M000 BCDEFGHIJKLMNO 3 A_Look;
        #### # 0 { return spawnstate; }
        wait;
    Idle2:
        M000 PQRSTUVWXYZ 2 A_Look;
        M001 ABCDEFGHIJKLMNOPQRST 2 A_Look;
        #### # 0 { return spawnstate; }
        wait;
    IdleScratch:
        M007 PQRSTUVWXYZ 2 A_Look;
        M008 ABCDEFGHIJKLMNOPQRSTUVWXYZ 2 A_Look;
        M009 ABCDEFG 2 A_Look;
        #### # 0 { return spawnstate; }
        wait;
    IdleTwirl:
        M009 HIJKLMNOPQRSTUV 3 A_Look;
        #### # 0 { return spawnstate; }
        wait;

    Wander:
        #### # 0 { speed = default.speed * 0.5; }
        M001 UVWXYZ 2 
        {
            WanderSmooth();
            A_Look();
        }
        M002 ABCDEFGHIJKLM 2
        {
            WanderSmooth();
            A_Look();
        }
        loop;
    
    See:
        #### # 0 { speed = default.speed; }
        M002 OPQRSTUVWXYZ 2 
		{
			if (!target)
				return ResolveState("Wander");
			if (frame == 15 || frame == 22)
			{
				A_StartSound("characters/cardguard/step");
			}
			ChaseSmooth();
			return ResolveState(null);
		}
        loop;
    
    Melee:
        #### # 0 A_Jump(256, "Melee1", "Melee2");
	Melee1:
		M003 ABCDEF 2;
		#### # 0 A_CustomMeleeAttack(Random(8,16));
		M003 GHIJKLMNOPQ 2;
        #### # 0 { return SeeState; }
        wait;
	Melee2:
		M003 RSTUVX 2;
		#### # 0 A_CustomMeleeAttack(Random(8,16));
		M003 YZ 2;
		M004 ABCD 2;
        #### # 0 { return SeeState; }
        wait;

    Pain:
        #### # 0 A_Jump(256, "Pain1", "Pain2");
	Pain1:
		#### # 0 A_Pain;
		M004 EFGHIJKL 2;
        #### # 0 { return SeeState; }
        wait;
	Pain2:
		#### # 0 A_Pain;
		M004 MNOPQRSTU 2;
        #### # 0 { return SeeState; }
        wait;
	
	Raise:
		#### # 0 A_Jumpif(wasgibbed, "XRaise");
		M005 RQPONMLKJIHGFEDCDBA 2;
		M004 ZYXWV 2;
        #### # 0 { return SpawnState; }
        wait;
	
	XRaise:
		M007 NMLKJIHGFEDCBA 1;
		M006 ZYXWVUTSRQPONMLKJIHGFEDCBA 1;
		M005 ZYXWVUT 1;	
        #### # 0 { return SpawnState; }
        wait;
	
	Death:
		#### # 0 
		{
			A_Scream();
			A_FaceTarget();
			return ResolveState(null);
		}
		M004 VWXYZ 2;
		#### # 0 A_NoBlocking;
		M005 ABDCDEFGHIJKLMNOPQR 2;
		M005 S -1;
		stop;
	XDeath:
		#### # 0 
		{
			A_XDeathScream();
			wasgibbed = true;
		}
		M005 TUVWX 2 A_SpawnBloodSpurt((0,0,default.height + 12), (1, 1, 2));
		#### # 0 A_NoBlocking;
		M005 YZ 2;
		M006 ABCDEFGHIJKLMNOPQRSTYV 2 A_SpawnBloodSpurt((0,0,default.height + 8), (1, 1, 2));
		M006 WXYZ 1 A_SpawnBloodSpurt((0,0,default.height + 8), (1, 1, 2));
		M007 ABCDEFGH 1
		{
			pitch -= 6;
			A_SpawnBloodSpurt((-4,0,default.height + 8), (1, 1, 2));
		}
		M007 IJKLMN 1
		{
			pitch -= 6;
			A_SpawnBloodSpurt((0,0,default.height + 8), (1, 1, 2));
		}
		#### # 0 { pitch = -90; }
		M007 OOOOOOOOOOOOOOOOOO 1
		{
			A_SpawnBloodSpurt((5,0,default.height * 0.9), (1, 1, 2));
		}
		M007 OOOOOOOO 1
		{
			A_SetTics(random[sfx](20, 40));
			A_SpawnBloodSpurt((5,0,default.height * 0.9), (1, 1, 2));
		}
		M007 O -1;
		stop;
    }
}

    