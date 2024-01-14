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
		translation "1:255=%[0.00,1.01,0.00]:[1.02,2.00,0.00]";
	}
	
	override void Tick() 
	{
		if (GetAge() > 35 * health)
			Destroy();
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