class ToM_CheshireCat_Idle : ToM_BaseActor
{
	Default
	{
		+NOINTERACTION
		+NOBLOCKMAP
		scale 0.8;
	}
	
	/*override void Tick()
	{
		super.Tick();
		console.printf("frame: %d", frame);
	}*/
	
	States
	{
	Spawn:
	Sit:
		TNT1 A 0 { console.printf("Sit"); }
		M000 ABCDEFGHIJKLMNOPQRSTUVWXY 3;
		//loop;
	Talk1:
		TNT1 A 0 { console.printf("Talk1"); }
		M002 ABCDEFGHIJKLMNOPQRSTUVWXYZ 2;
		M003 ABCDEFGHIJ 2;
		//loop;
	Talk2:
		TNT1 A 0 { console.printf("Talk2"); }
		M004 ABCDEFGHIJKLMNOPQRSTUVWXYZ 1;
		M005 ABCDEFGHIJKLMNOPQRSTUVWXY 2;
		//loop;
	Talk3:
		TNT1 A 0 { console.printf("Talk3"); }
		M006 ABCDEFGHIJKLMNOPQRSTUVWXYZ 2;
		M007 ABCDEFGHIJKLMN 2;
		//loop;
		goto spawn;
	Stand:
		TNT1 A 0 { console.printf("Stand"); }
		M008 ABCDEFGHIJKLMNOPQRSTU 3;
		//loop;
	See:
		TNT1 A 0 { console.printf("See"); }
		M001 ABCDEFGHIJKLMNOPQRSTU 3;
		//loop;
	}
}