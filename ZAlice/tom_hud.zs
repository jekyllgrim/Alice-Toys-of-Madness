class ToM_AliceHUD : BaseStatusBar
{
	const noYStretch = 0.833333;
	
	protected transient CVar aspectScale;
	HUDFont mIndexFont;
	ToM_HUDFaceController FaceController;
	TextureID HUDFace;

	// Versions of the draw functions that respect
	// UI scaling but ignore UI stretching:

	void ToM_DrawImage(String texture, Vector2 pos, int flags = 0, double Alpha = 1., Vector2 box = (-1, -1), Vector2 scale = (1, 1)) 
	{
		if (aspectScale.GetBool() == true) 
		{
			scale.y *= noYStretch;
			pos.y *= noYStretch;
		}
		DrawImage(texture, pos, flags, Alpha, box, scale);
	}
	
	void ToM_DrawTexture(TextureID texture, Vector2 pos, int flags = 0, double Alpha = 1., Vector2 box = (-1, -1), Vector2 scale = (1, 1))
	{
		if (aspectScale.GetBool() == true) 
		{
			scale.y *= noYStretch;
			pos.y *= noYStretch;
		}
		DrawTexture(texture, pos, flags, Alpha, box, scale);
	}
	
	void ToM_DrawString(HUDFont font, String string, Vector2 pos, int flags = 0, int translation = Font.CR_UNTRANSLATED, double Alpha = 1., int wrapwidth = -1, int linespacing = 4, Vector2 scale = (1, 1)) 
	{
		if (aspectScale.GetBool() == true) 
		{
			scale.y *= noYStretch;
			pos.y *= noYStretch;
		}
		DrawString(font, string, pos, flags, translation, Alpha, wrapwidth, linespacing, scale);
	}

	void ToM_DrawInventoryIcon(Inventory item, Vector2 pos, int flags = 0, double alpha = 1.0, Vector2 boxsize = (-1, -1), Vector2 scale = (1.,1.)) {
		if (aspectScale.GetBool() == true) 
		{
			scale.y *= noYStretch;
			pos.y *= noYStretch;
		}
		DrawInventoryIcon(item, pos, flags, alpha, boxsize, scale);
	}
	
	override void Init() 
	{
		super.Init();
		Font fnt = "INDEXFONT_DOOM";
		mIndexFont = HUDFont.Create(fnt, fnt.GetCharWidth("0"), Mono_CellLeft, 1, 1);
	}
	
	override void Tick()
	{
		if (!FaceController)
		{
			let handler = ToM_Mainhandler(Eventhandler.Find("ToM_Mainhandler"));
			if (handler)
			{
				FaceController = handler.HUDFaces[CPlayer.mo.PlayerNumber()];
			}
		}
		
		HUDFace = FaceController.GetFaceTexture();
	}
	
	override void Draw (int state, double TicFrac) 
	{
		Super.Draw (state, TicFrac);
		
		if (aspectScale == null)
			aspectScale = CVar.GetCvar('hud_aspectscale',CPlayer);
			
		if (state == HUD_AltHUD || state == HUD_None)
			return;
		
		BeginHUD(1., false, 640, 480);
		
		DrawBackgroundStuff();
		DrawLeftCorner();
		DrawRightcorner();
	}
	
	void DrawBackgroundStuff()
	{
		// left: decoration
		ToM_DrawImage("graphics/HUD/base_left.png", (0, 0), DI_SCREEN_LEFT_BOTTOM|DI_ITEM_LEFT_BOTTOM);
		
		// right: vessels and decoration
		ToM_DrawImage("graphics/HUD/base_right.png", (0, 0), DI_SCREEN_RIGHT_BOTTOM|DI_ITEM_RIGHT_BOTTOM);
	}
	
	// Red at 25% or less, white otherwise:
	int GetHealthColor()
	{
		int hmax = CPlayer.mo.maxhealth;
		int health = CPlayer.health;
		if (health <= (hmax * 0.25))
			return Font.CR_Red;
		return Font.CR_White;
	}	
	
	void DrawLeftCorner()
	{		
		// armor frame goes first
		let armor = BasicArmor(CPlayer.mo.FindInventory("BasicArmor"));
		if (armor && armor.amount > 0)
		{
			ToM_DrawInventoryIcon(armor, (0, 0),DI_SCREEN_LEFT_BOTTOM|DI_ITEM_CENTER);
		}
		
		// mirror's background in the middle:
		ToM_DrawImage("graphics/HUD/mirror_back.png", (0, 0), DI_SCREEN_LEFT_BOTTOM|DI_ITEM_LEFT_BOTTOM);
		
		DrawAliceFace();
		
		// mirror's glass:
		ToM_DrawImage("graphics/HUD/mirror_glass.png", (0, 0), DI_SCREEN_LEFT_BOTTOM|DI_ITEM_LEFT_BOTTOM);
		
		// cracks in glass (health indication):
		DrawMirrorCracks();
		
		// mirror's frame goes on top:
		ToM_DrawImage("graphics/HUD/mirror_frame.png", (0, 0), DI_SCREEN_LEFT_BOTTOM|DI_ITEM_LEFT_BOTTOM);
		
		// And finally, numbers:
		ToM_DrawString(mIndexFont, String.Format("%d",CPlayer.health), (81, -44), DI_SCREEN_LEFT_BOTTOM|DI_TEXT_ALIGN_CENTER, translation: GetHealthColor());
	}
	
	void DrawRightcorner()
	{
		// highlights go on top:
		ToM_DrawImage("graphics/HUD/vessel_highlights.png", (0, 0), DI_SCREEN_RIGHT_BOTTOM|DI_ITEM_RIGHT_BOTTOM);
	}
	
	void DrawAliceFace()
	{
		if (!HUDFace)
			return;
		
		ToM_DrawTexture(HUDFace, (80, -85), DI_SCREEN_LEFT_BOTTOM|DI_ITEM_CENTER);
	}
	
	void DrawMirrorCracks()
	{
		int health = CPlayer.health;
		if (health >= 75)
			return;
		
		name path = "graphics/HUD/";
		name tex;
		switch (health)
		{
		case 70: case 69: case 68: case 67: case 66: 
			tex = "mirror_cracks01.png"; break;
		case 65: case 64: case 63: case 62: case 61: 
			tex = "mirror_cracks02.png"; break;
		case 60: case 59: case 58: case 57: case 56: 
			tex = "mirror_cracks03.png"; break;
		case 55: case 54: case 53: case 52: case 51: 
			tex = "mirror_cracks04.png"; break;
		case 50: case 49: case 48: case 47: case 46: 
			tex = "mirror_cracks05.png"; break;
		case 45: case 44: case 43: case 42: case 41: 
			tex = "mirror_cracks06.png"; break;
		case 40: case 39: case 38: case 37: case 36: 
			tex = "mirror_cracks07.png"; break;
		case 35: case 34: case 33: case 32: case 31: 
			tex = "mirror_cracks08.png"; break;
		case 30: case 29: case 28: case 27: case 26: 
			tex = "mirror_cracks09.png"; break;
		case 25: case 24: case 23: case 22: case 21: 
			tex = "mirror_cracks10.png"; break;
		case 20: case 19: case 18: case 17: case 16: 
			tex = "mirror_cracks11.png"; break;
		case 15: case 14: case 13: case 12: case 11: 
			tex = "mirror_cracks12.png"; break;
		case 10: case 9: case 8: case 7: case 6:
			tex = "mirror_cracks13.png"; break;
		case 5: case 4: case 3: case 2: case 1:
			tex = "mirror_cracks14.png"; break;
		case 0:
			tex = "mirror_cracks15.png"; break;
		}
		if (tex)
			ToM_DrawImage(path..tex, (0, 0), DI_SCREEN_LEFT_BOTTOM|DI_ITEM_LEFT_BOTTOM);
	}
}

class ToM_HUDFaceController : Actor
{
	const BLINK_MIN = 35;
	const BLINK_MAX = 35 * 5;
	
	const DMGDELAY = 20;
	int dmgwait;
	
	state s_front_calm;
	state s_front_angry;
	state s_front_smile;
	state s_front_demon;
	state s_front_ouch;
	state s_return_left_calm;
	state s_return_right_calm;
	state s_return_left_angry;
	state s_return_right_angry;
	state s_right_angry;
	state s_left_angry;
	
	PlayerInfo HPlayer;
	PlayerPawn HPlayerPawn;
	
	Default
	{
		+NOINTERACTION
		+NOBLOCKMAP
		+NOSECTOR
		+SYNCHRONIZED
		Renderstyle 'None';
		FloatBobPhase 0;
	}
	
	clearscope TextureID GetFaceTexture()
	{
		return curstate.GetSpriteTexture(0);
	}
	
	bool CheckFaceSequence(state checkstate)
	{
		return ( checkstate && InStateSequence(curstate, checkstate) );
	}
	
	void SetFaceState(state newstate, bool noOverride = false)
	{
		if (!noOverride || !CheckFaceSequence(newstate))
			SetState(newstate);
	}
	
	override void BeginPlay()
	{
		super.BeginPlay();
		s_front_calm = FindState("FrontCalm");
		s_front_angry = FindState("FrontAngry");
		s_front_smile = FindState("FrontSmile");
		s_front_demon = FindState("FrontDemon");
		s_front_ouch = FindState("FrontOuch");
		s_return_left_calm = FindState("ReturnLeftCalm");
		s_return_right_calm = FindState("ReturnRightCalm");
		s_return_left_angry = FindState("ReturnLeftAngry");
		s_return_right_angry = FindState("ReturnRightAngry");
		s_right_angry = FindState("RightAngry");
		s_left_angry = FindState("LeftAngry");
	}
	
	override void Tick()
	{
		if (!HPlayer)
			return;
		super.Tick();
		
		if (HPlayerPawn.FindInventory("PowerStrength", true))
		{
			SetFaceState(s_front_demon, true);
		}
		
		else if (HPlayer.damagecount > 0 && dmgwait <= 0)
		{
			dmgwait = DMGDELAY;
			double atkangle = 0;
			// angle to attacker:
			if (HPlayer.attacker)
			{
				atkangle = HPlayerPawn.DeltaAngle(HPlayerPawn.angle, HPlayerPawn.AngleTo(HPlayer.attacker));
			}
			// Attacked from the front:
			if (abs(atkangle) < 40)
			{
				// If already looking left, return from left:
				if (CheckFaceSequence(s_left_angry))
					SetFaceState(s_return_left_angry);
				// If looking right, return from right:
				else if (CheckFaceSequence(s_right_angry))
					SetFaceState(s_return_right_angry);
				// Otherwise just show front damage face:
				else
					SetFaceState(s_front_angry);
			}
			// Attacked from the right:
			else if (atkangle < 0)
				SetFaceState(s_right_angry);
			// Attacked from the left:
			else
				SetFaceState(s_left_angry);
		}
		
		if (dmgwait > 0)
			dmgwait--;
	}
	
	States
	{
	Spawn:
	FrontCalm:
		AHF1 A 1 NoDelay A_SetTics(random[ahf](BLINK_MIN, BLINK_MAX));
		AHF1 BC 3;
		loop;
	FrontAngry:
		AHF1 D 25;
		goto FrontCalm;
	FrontSmile:
		AHF1 E 35;
		goto FrontCalm;
	FrontOuch:
		AHF1 FG 3;
		AHF1 H 30;
		goto FrontCalm;
	FrontDemon:
		AHF5 ABCD 4;
		AHF5 CB 5;
		loop;
	LeftAngry:
		AHF2 ABC 3;
		AHF2 D 21;
		goto ReturnLeftCalm;
	RightAngry:
		AHF2 EFG 3;
		AHF2 H 21;
		goto ReturnRightCalm;
	ReturnLeftAngry:
		AHF3 ABCD 3;
		goto FrontAngry;
	ReturnRightAngry:
		AHF3 EFGH 3;
		goto FrontAngry;
	ReturnLeftCalm:
		AHF4 BCD 4;
		goto FrontCalm;
	ReturnRightCalm:
		AHF4 FGH 4;
		goto FrontCalm;
	}
}