class ToM_DebugSpot : Actor 
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
		Renderstyle 'Shaded';
		StencilColor "00FF00";
	}

	static ToM_DebugSpot Spawn(Vector3 location, int duration, double size = 1)
	{
		let t = ToM_DebugSpot(Actor.Spawn('ToM_DebugSpot', location));
		if (t)
		{
			t.A_SetHealth(duration);
			t.scale *= size;
		}
		return t;
	}
	
	override void Tick() 
	{
		if (vel != (0,0,0))
		{
			SetOrigin(Vec3Offset(vel.x, vel.y, vel.z), true);
		}
		if (GetAge() > TICRATE * health)
		{
			Destroy();
		}
	}
	
	states 
	{
	Spawn:
		AMRK A -1;
		stop;
	}
}

class ToM_TestPowerup1 : Powerup
{
	Default
	{
		Powerup.Duration -15;
		Inventory.Icon "PTESA0";
	}
}

class ToM_TestPowerup2 : Powerup
{
	Default
	{
		Powerup.Duration -20;
		Inventory.Icon "PTESB0";
	}
}

class ToM_TestPowerup3 : Powerup
{
	Default
	{
		Powerup.Duration -30;
		Inventory.Icon "PTESC0";
	}
}

class ToM_TestPowerupGiver : PowerupGiver
{
	Default
	{		
		+BRIGHT
		+INVENTORY.AUTOACTIVATE
		+INVENTORY.ALWAYSPICKUP
	}
}

class ToM_TestPowerupGiver1 : ToM_TestPowerupGiver
{
	Default
	{
		Powerup.Type 'ToM_TestPowerup1';
		Inventory.Pickupmessage "Giving test powerup #1";
	}

	States {
	Spawn:
		PTES A -1;
		stop;
	}
}

class ToM_TestPowerupGiver2 : ToM_TestPowerupGiver
{
	Default
	{
		Powerup.Type 'ToM_TestPowerup2';
		Inventory.Pickupmessage "Giving test powerup #2";
	}

	States {
	Spawn:
		PTES B -1;
		stop;
	}
}

class ToM_TestPowerupGiver3 : ToM_TestPowerupGiver
{
	Default
	{
		Powerup.Type 'ToM_TestPowerup3';
		Inventory.Pickupmessage "Giving test powerup #3";
	}

	States {
	Spawn:
		PTES C -1;
		stop;
	}
}

class Prop_Shootable : Actor
{
	Default
	{
		+SOLID
		height 56;
		radius 16;
		+SHOOTABLE
		+NOBLOOD
		+BUDDHA
		+DONTTHRUST
	}

	States {
	Spawn:
		COLU A -1;
		stop;
	}
}

class Prop_Monster : Prop_Shootable
{
	Default
	{
		+ISMONSTER
		Translation "0:255=#[255,128,128]";
		-NOBLOOD
	}

	States {
	Spawn:
		POSS A -1;
		stop;
	}
}