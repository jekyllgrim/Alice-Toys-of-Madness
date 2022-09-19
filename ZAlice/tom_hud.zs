class ToM_AliceHUD : BaseStatusBar
{
	const noYStretch = 0.833333;
	
	protected transient CVar aspectScale;
	HUDFont mIndexFont;

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
		
		FaceAnimationsInit();
	}
	
	override void Tick()
	{
		UpdateFaceAnimation();
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
		
	
	const BLINK_MIN = 35;
	const BLINK_MAX = 35 * 5;
	int face_duration;
	int face_curframe;
	ToM_FaceSprite face_curSprite;
	array <ToM_FaceSprite> FSprites_curSeq;
	
	/*enum FSprites_states
	{
		FS_front_calm,
		FS_front_angry,
		FS_front_demon,
		FS_front_ouch,
		FS_front_smile,
		FS_angry_left,
		FS_angry_right,
		FS_return_angry_left,
		FS_return_angry_right,
		FS_return_calm_left,
		FS_return_calm_right,
	}*/
	
	array <ToM_FaceSprite> FSprites_front_calm;
	array <ToM_FaceSprite> FSprites_front_angry;
	array <ToM_FaceSprite> FSprites_front_demon;
	array <ToM_FaceSprite> FSprites_front_ouch;
	array <ToM_FaceSprite> FSprites_front_smile;
	array <ToM_FaceSprite> FSprites_angry_left;
	array <ToM_FaceSprite> FSprites_angry_right;
	array <ToM_FaceSprite> FSprites_return_angry_left;
	array <ToM_FaceSprite> FSprites_return_angry_right;
	array <ToM_FaceSprite> FSprites_return_calm_left;
	array <ToM_FaceSprite> FSprites_return_calm_right;
	
	void DrawAliceFace()
	{
		if (!face_curSprite)
			return;
		
		let tex = face_curSprite.GetGraphic();
		ToM_DrawImage(tex, (80, -85), DI_SCREEN_LEFT_BOTTOM|DI_ITEM_CENTER);
	}

	void FaceAnimationsInit()
	{
		FSprites_front_calm.Clear();
		FSprites_front_angry.Clear();
		FSprites_front_demon.Clear();
		FSprites_front_ouch.Clear();
		FSprites_front_smile.Clear();
		FSprites_angry_left.Clear();
		FSprites_angry_right.Clear();
		FSprites_return_angry_left.Clear();
		FSprites_return_angry_right.Clear();
		FSprites_return_calm_left.Clear();
		FSprites_return_calm_right.Clear();
	
		for (int i = 0; i < FSprites.Size(); i++)
		{
			array <string> st;
			FSprites[i].Split(st, ":");
			if (st.Size() < 1)
				return;
			
			if (st[0] ~== "acf_front_calm")
			{
				ToM_FaceSprite fsprt = ToM_FaceSprite.Create(FSprites[i]);
				FSprites_front_calm.Push(fsprt);
			}
			if (st[0] ~== "acf_front_ouch")
			{
				ToM_FaceSprite fsprt = ToM_FaceSprite.Create(FSprites[i]);
				FSprites_front_ouch.Push(fsprt);
			}
			if (st[0] ~== "acf_front_smile")
			{
				ToM_FaceSprite fsprt = ToM_FaceSprite.Create(FSprites[i]);
				FSprites_front_smile.Push(fsprt);
			}
			if (st[0] ~== "acf_front_angry")
			{
				ToM_FaceSprite fsprt = ToM_FaceSprite.Create(FSprites[i]);
				FSprites_front_angry.Push(fsprt);
			}
			if (st[0] ~== "acf_front_demon")
			{
				ToM_FaceSprite fsprt = ToM_FaceSprite.Create(FSprites[i]);
				FSprites_front_demon.Push(fsprt);
			}
			if (st[0] ~== "acf_angry_left")
			{
				ToM_FaceSprite fsprt = ToM_FaceSprite.Create(FSprites[i]);
				FSprites_angry_left.Push(fsprt);
			}
			if (st[0] ~== "acf_angry_right")
			{
				ToM_FaceSprite fsprt = ToM_FaceSprite.Create(FSprites[i]);
				FSprites_angry_right.Push(fsprt);
			}
			if (st[0] ~== "acf_return_angry_left")
			{
				ToM_FaceSprite fsprt = ToM_FaceSprite.Create(FSprites[i]);
				FSprites_return_angry_left.Push(fsprt);
			}
			if (st[0] ~== "acf_return_angry_right")
			{
				ToM_FaceSprite fsprt = ToM_FaceSprite.Create(FSprites[i]);
				FSprites_return_angry_right.Push(fsprt);
			}
			if (st[0] ~== "acf_return_calm_left")
			{
				ToM_FaceSprite fsprt = ToM_FaceSprite.Create(FSprites[i]);
				FSprites_return_calm_left.Push(fsprt);
			}
			if (st[0] ~== "acf_return_calm_right")
			{
				ToM_FaceSprite fsprt = ToM_FaceSprite.Create(FSprites[i]);
				FSprites_return_calm_right.Push(fsprt);
			}
		}
		UpdateFaceSequence(FSprites_front_calm);
	}
	
	void UpdateFaceSequence(array<ToM_FaceSprite> newSequence)
	{
		//FSprites_curSeq.Clear();
		FSprites_curSeq.Copy(newSequence);
		
		/*
		switch (newstate)
		{
		case FS_front_calm:
			FSprites_curSeq = FSprites_front_calm;
			break;
		case FS_front_angry:
			FSprites_curSeq = FSprites_front_angry;
			break;
		case FS_front_demon:
			FSprites_curSeq = FSprites_front_demon;
			break;
		case FS_front_ouch:
			FSprites_curSeq = FSprites_front_ouch;
			break;
		case FS_front_smile:
			FSprites_curSeq = FSprites_front_smile;
			break;
		case FS_angry_left:
			FSprites_curSeq = FSprites_angry_left;
			break;
		case FS_angry_right:
			FSprites_curSeq = FSprites_angry_right;
			break;
		case FS_return_angry_left:
			FSprites_curSeq = FSprites_return_angry_left;
			break;
		case FS_return_angry_right:
			FSprites_curSeq = FSprites_return_angry_right;
			break;
		case FS_return_calm_left:
			FSprites_curSeq = FSprites_return_calm_left;
			break;
		case FS_return_calm_right:
			FSprites_curSeq = FSprites_return_calm_right;
			break;
		}*/
	}
	
	void UpdateFaceAnimation()
	{
		// Check if the the current sequence is empty.
		// If so, reinit:
		if (FSprites_curSeq.Size() < 1)
		{
			FaceAnimationsInit();
			return;
		}
		
		// Check if current face sprite is valid.
		// If not, set it to the default one:
		if (!face_curSprite)
		{
			face_curSprite = FSprites_front_calm[0];
		}
		
		// Decrement the duration if above 0:
		if (face_duration > 0)
		{
			face_duration--;
		}
		
		// Otherwise set next frame:
		else
		{
			int i = face_curframe;
			face_curframe++;
			if (face_curframe >= FSprites_curSeq.Size())
			{
				let sprt = FSprites_curSeq[i];
				name where = sprt.GetNextState();
				switch (where)
				{
				case '':
					UpdateFaceSequence(FSprites_front_calm);
					break;
				case 'acf_return_calm_right':
					UpdateFaceSequence(FSprites_return_calm_right);
					break;
				case 'acf_return_calm_left':
					UpdateFaceSequence(FSprites_return_calm_left);
					break;
				}
				face_curframe = 0;
			}
			face_curSprite = FSprites_curSeq[face_curframe];
			if (face_curSprite == FSprites_front_calm[0])
				face_duration = random[acf](BLINK_MIN, BLINK_MAX);
			else
				face_duration = face_curSprite.GetDuration();
		}
	}
	
	static const string FSprites[] =
	{	
		"acf_front_calm:0:0",
		"acf_front_calm:1:3",
		"acf_front_calm:2:3",
		
		"acf_front_ouch:1:3",
		"acf_front_ouch:2:3",
		"acf_front_ouch:3:24",
		
		"acf_front_smile:0:30",
		"acf_front_angry:0:30",

		"acf_front_demon:1:3",
		"acf_front_demon:2:3",
		"acf_front_demon:3:3",
		"acf_front_demon:4:3",
		"acf_front_demon:3:4",
		"acf_front_demon:2:4:loop",

		"acf_angry_left:1:3",
		"acf_angry_left:2:3",
		"acf_angry_left:3:3",
		"acf_angry_left:4:15",

		"acf_angry_right:1:3",
		"acf_angry_right:2:3",
		"acf_angry_right:3:3",
		"acf_angry_right:4:15:acf_return_calm_right"

		"acf_return_angry_left:1:3",
		"acf_return_angry_left:2:3",
		"acf_return_angry_left:3:3",
		"acf_return_angry_left:4:3:acf_return_calm_left",

		"acf_return_angry_right:1:3",
		"acf_return_angry_right:2:3",
		"acf_return_angry_right:3:3",
		"acf_return_angry_right:4:3",
	
		"acf_return_calm_left:1:3",
		"acf_return_calm_left:2:3",
		"acf_return_calm_left:3:3",
		"acf_return_calm_left:4:3",

		"acf_return_calm_right:1:3",
		"acf_return_calm_right:2:3",
		"acf_return_calm_right:3:3",
		"acf_return_calm_right:4:3"
	};
}



class ToM_FaceSprite : Object ui
{	
	private string graphicName;
	private int frame;
	private int duration;
	private string nextState;
	
	static ToM_FaceSprite Create(string graphic, string path = "graphics/hud/face/", string extension = ".png")
	{
		array<String> graphicData;
		graphic.Split(graphicData, ":");
		if (graphicData.Size() < 3)
		{
			console.printf("ToM_FaceSprite.Create() couldn't parse \"%s\": improper format", graphic);
			return null;
		}
		
		ToM_FaceSprite fs = New("ToM_FaceSprite");
		
		if (fs)
		{
			fs.graphicName = String.Format("%s%s%s%s", path, graphicData[0], graphicData[1], extension);		
			//fs.frame = graphicData[1].ToInt();
			fs.duration = graphicData[2].toInt();
			console.printf("ToM_FaceSprite.Create() resolved graphic as \"%s\"", fs.graphicName);
			
			if (graphicData.Size() > 3)
			{
				fs.nextState = String.Format("%s%s%s", path, graphicData[3], extension);
				console.printf("ToM_FaceSprite.Create() resolved NEXT graphic as \"%s\"", fs.nextState);
			}
		}
		
		return fs;
	}
	
	string GetGraphic()
	{
		return graphicName;
	}
	
	string GetNextState()
	{
		return nextState;
	}
	
	int GetDuration()
	{
		return duration;
	}
}