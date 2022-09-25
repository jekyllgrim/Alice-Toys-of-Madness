class ToM_AliceHUD : BaseStatusBar
{
	const noYStretch = 0.833333;
	
	protected transient CVar aspectScale;
	HUDFont mIndexFont;
	protected ToM_HUDFaceController FaceController;
	protected TextureID HUDFace;
	protected int hudstate;
	const eShiftX = 32;	
	const eShiftY = 24;
	
	vector2 GetElementOffset(int flags = 0)
	{
		vector2 ofs = (0, 0);
	
		if (hudstate == HUD_StatusBar)
		{
			ofs = (-eShiftX, eShiftY);
			if (flags & DI_SCREEN_RIGHT)
			{
				ofs.x *= -1;
			}
		}
		
		return ofs;
	}

	// Versions of the draw functions that respect
	// UI scaling but ignore UI stretching.
	// These also incorporate automatic offsets
	// to account for minimal and full versions of the HUD.

	void ToM_DrawImage(String texture, Vector2 pos, int flags = 0, double Alpha = 1., Vector2 box = (-1, -1), Vector2 scale = (1, 1), bool sbarofs = true)
	{
		if (sbarofs)
		{
			pos += GetElementOffset(flags);
		}
		if (aspectScale.GetBool() == true) 
		{
			scale.y *= noYStretch;
			pos.y *= noYStretch;
		}
		DrawImage(texture, pos, flags, Alpha, box, scale);
	}
	
	void ToM_DrawTexture(TextureID texture, Vector2 pos, int flags = 0, double Alpha = 1., Vector2 box = (-1, -1), Vector2 scale = (1, 1), bool sbarofs = true)
	{
		if (sbarofs)
		{
			pos += GetElementOffset(flags);
		}
		if (aspectScale.GetBool() == true) 
		{
			scale.y *= noYStretch;
			pos.y *= noYStretch;
		}
		DrawTexture(texture, pos, flags, Alpha, box, scale);
	}
	
	void ToM_DrawString(HUDFont font, String string, Vector2 pos, int flags = 0, int translation = Font.CR_UNTRANSLATED, double Alpha = 1., int wrapwidth = -1, int linespacing = 4, Vector2 scale = (1, 1), bool sbarofs = true) 
	{
		if (sbarofs)
		{
			pos += GetElementOffset(flags);
		}
		if (aspectScale.GetBool() == true) 
		{
			scale.y *= noYStretch;
			pos.y *= noYStretch;
		}
		DrawString(font, string, pos, flags, translation, Alpha, wrapwidth, linespacing, scale);
	}

	void ToM_DrawInventoryIcon(Inventory item, Vector2 pos, int flags = 0, double alpha = 1.0, Vector2 boxsize = (-1, -1), Vector2 scale = (1.,1.), bool sbarofs = true) 
	{
		if (sbarofs)
		{
			pos += GetElementOffset(flags);
		}
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
		
		hudstate = state;
		
		BeginHUD(1., false, 320, 200);
		
		DrawBackgroundStuff();
		DrawLeftCorner();
		DrawRightcorner();
	}
	
	void DrawBackgroundStuff()
	{
		if (hudstate == HUD_StatusBar)
			return;
	
		// left decoration
		ToM_DrawImage("graphics/HUD/base_left.png", (0, 0), DI_SCREEN_LEFT_BOTTOM|DI_ITEM_LEFT_BOTTOM);
		
		// right decoration
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
		
		// mirror's background:
		ToM_DrawImage("graphics/HUD/mirror_back.png", (0, 0), DI_SCREEN_LEFT_BOTTOM|DI_ITEM_LEFT_BOTTOM);
		
		// Alice's face:
		DrawAliceFace();
		
		// mirror's glass:
		ToM_DrawImage("graphics/HUD/mirror_glass.png", (0, 0), DI_SCREEN_LEFT_BOTTOM|DI_ITEM_LEFT_BOTTOM);
		
		// cracks in glass (health indication):
		DrawMirrorCracks();
		
		// mirror's frame goes on top:
		ToM_DrawImage("graphics/HUD/mirror_frame.png", (0, 0), DI_SCREEN_LEFT_BOTTOM|DI_ITEM_LEFT_BOTTOM);
		
		// finally, health numbers:
		ToM_DrawString(mIndexFont, String.Format("%d",CPlayer.health), (81, -44), DI_SCREEN_LEFT_BOTTOM|DI_TEXT_ALIGN_CENTER, translation: GetHealthColor());
	}
	
	void DrawManaVessel(name ammotype, string texture, vector2 pos, double diameter, int flags = 0, string toptexture = "")
	{
		Class<Ammo> ammocls = ammotype;
		if (!ammotype)
			return;
		let am = Ammo(CPlayer.mo.FindInventory(ammocls));
		if (!am)
			return;
		
		bool isSelected;
		let weap = CPlayer.readyweapon;
		isSelected = (weap && weap.ammotype1 == ammocls);
		
		double amount = am.amount;
		double maxamount = am.maxamount;
		if (maxamount <= 0)
			return;
		
		//console.printf("%s: %d / %d", ammotype, amount, maxamount);
		
		double amtFac = amount / double(maxamount);
		double gclip = diameter - diameter * amtFac;
		//gclip = int(gclip);
		
		SetClipRect(
			pos.x,
			pos.y + gclip,
			diameter,
			diameter - gclip,
			DI_SCREEN_RIGHT_BOTTOM
		);
		ToM_DrawImage(texture, pos, DI_SCREEN_RIGHT_BOTTOM|DI_ITEM_LEFT_TOP);
		if (!isSelected)
		{
			ToM_DrawImage("graphics/HUD/vessel_black_liquid.png", pos, DI_SCREEN_RIGHT_BOTTOM|DI_ITEM_LEFT_TOP, alpha: 0.45);
		}
		ClearClipRect();
		
		// The top of the liquid is a separate, fake-3D texture.
		// We need to scale it dynamically, so that it matches the
		// width of the bubble. Here we need a bit of geometry:
		// the bubble is a circle with a diameter of 43, and the top
		// line of the mana texture is that circle's chord.
		// Using Pythagorean theorem, knowing the vertical pos of that chord
		// we can calculate its exact width. We start with the circle's
		// diameter and with amtFac, which corresponds to the height
		// of the mana level in the bubble:
		// (https://www.cuemath.com/geometry/Chords-of-a-circle/)
		if (toptexture && amtFac < 0.99 && amtFac > 0.01)
		{
			double rad = diameter / 2;
			double width;
			
			// If we're exactly at half ammo, the chord equals
			// the circle's diameter:
			if (amtFac == 0.5)
				width = diameter;
			else
			{
				// Otherwise the Pythagorean theorem comes into play.
				// We imagine a triangle, whose top is at the middle of the
				// circle, its sides are equal to the circle's radius,
				// and the widest side is the chord itself.
				// Now split it into 2 equal triangles. We're only using
				// one of those smaller triangles. One of its catheti is
				// equal to the distance from the circle's center
				// to the height of the chord. The other catheti is
				// the chord itself, and its hypotenuse is equal to the
				// circle's radius. We know the radius and the distance 
				// from center to the chord, now we need to find the
				// cathetus of that triangle, multiply it by 2, and we got
				// the length of the chord.
				
				// First, get the first cathetus, i.e. distance from the center
				// of the bubble to the chord. Note that the chord can be
				// below the center, but the length of the cathetus is
				// always positive. We need to map it using amtFac.
				double triHeight;
				
				// From half ammo to full ammo: the cathetus goes from 0 to
				// circle's radius:
				if (amtFac > 0.5)
					triHeight = ToM_BaseActor.LinearMap(amtFac, 0.5, 1.0, 0, rad);
				// From half ammo to zero ammo: the cathetus also goes from 0 to
				// circle's radius:
				else
					triHeight = ToM_BaseActor.LinearMap(amtFac, 0.5, 0.0, 0, rad);
				// The Pythagorean theorem is: hypotenuse squared equals the sum
				// of its squared catheti (c2 = a2 + b2).
				// Since the chord (or rather, half of it) is a cathetus here,
				// and radius is the hypotenuse, restructure the formula:
				// cathetus squared equals hypotenuse squared minus the other
				// cathetus squared:
				double halfChordSquared = ((rad * rad) - (triHeight * triHeight));
				
				// To get the full chord, take a square root of the value
				// calculated above (that's half of the length of the chord)
				// and multiply it by 2 (that's full length);
				double chord = sqrt(halfChordSquared) * 2;
				
				// Make it a bit smaller so that it doesn't stick out of
				// the bubble's sides (the bubble is pixelated, after all,
				// so it can happen):
				width = chord * 0.98;
			}
			
			// The top texture is aligned to its center (middle of the
			// bubble's width), and its horizontal position is equal
			// to the position of the clip rectangle (which is the top
			// end of the mana texture):
			vector2 tpos = ( pos.x + rad, pos.y + gclip );
			ToM_DrawImage(toptexture, tpos, flags: DI_SCREEN_RIGHT_BOTTOM|DI_ITEM_CENTER, box: (width, -1));
			if (!isSelected)
			{
				ToM_DrawImage("graphics/HUD/vessel_black_liquidtop.png", tpos, flags: DI_SCREEN_RIGHT_BOTTOM|DI_ITEM_CENTER, alpha: 0.45, box: (width, -1));
			}
		}
	}
	
	void DrawRightcorner()
	{
		// red mana:
		DrawManaVessel("ToM_RedMana", "graphics/HUD/vessel_red_liquid.png", (-134, -75), 43, toptexture: "graphics/HUD/vessel_red_liquidtop.png");// red mana:
		// yellow mana:
		DrawManaVessel("ToM_YellowMana", "graphics/HUD/vessel_Yellow_liquid.png", (-106, -122), 43, toptexture: "graphics/HUD/vessel_Yellow_liquidtop.png");
		// purple mana:
		DrawManaVessel("ToM_PurpleMana", "graphics/HUD/vessel_Purple_liquid.png", (-78, -75), 43, toptexture: "graphics/HUD/vessel_Purple_liquidtop.png");
	
		// vessels:
		ToM_DrawImage("graphics/HUD/vessels.png", (0, 0), DI_SCREEN_RIGHT_BOTTOM|DI_ITEM_RIGHT_BOTTOM);
		
		// runes on the vessels:
		ToM_DrawImage("graphics/HUD/vessel_runes.png", (0, 0), DI_SCREEN_RIGHT_BOTTOM|DI_ITEM_RIGHT_BOTTOM);
		
		// highlights go on top:
		ToM_DrawImage("graphics/HUD/vessel_highlights.png", (0, 0), DI_SCREEN_RIGHT_BOTTOM|DI_ITEM_RIGHT_BOTTOM);
	}
	
	void DrawAliceFace()
	{
		if (!HUDFace || CPlayer.health <= 0)
			return;
		
		ToM_DrawTexture(HUDFace, (80, -85), DI_SCREEN_LEFT_BOTTOM|DI_ITEM_CENTER);
	}
	
	void DrawMirrorCracks()
	{
		int health = CPlayer.health;
		if (health > 70)
			return;
		
		name path = "graphics/HUD/";
		name tex;
		
		if (health > 65)
			tex = "mirror_cracks01.png";
		else if (health > 60)
			tex = "mirror_cracks02.png";
		else if (health > 55)
			tex = "mirror_cracks03.png";
		else if (health > 50)
			tex = "mirror_cracks04.png";
		else if (health > 45)
			tex = "mirror_cracks05.png";
		else if (health > 40)
			tex = "mirror_cracks06.png";
		else if (health > 35)
			tex = "mirror_cracks07.png";
		else if (health > 30)
			tex = "mirror_cracks08.png";
		else if (health > 25)
			tex = "mirror_cracks09.png";
		else if (health > 20)
			tex = "mirror_cracks10.png";
		else if (health > 15)
			tex = "mirror_cracks11.png";
		else if (health > 10)
			tex = "mirror_cracks12.png";
		else if (health > 5)
			tex = "mirror_cracks13.png";
		else if (health > 0)
			tex = "mirror_cracks14.png";
		else
			tex = "mirror_cracks15.png";

		if (tex)
		{
			ToM_DrawImage(path..tex, (0, 0), DI_SCREEN_LEFT_BOTTOM|DI_ITEM_LEFT_BOTTOM);
		}
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
			if (HPlayer.damagecount >= 25)
			{
				SetFaceState(s_front_ouch, true);
			}
			else
			{
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
		AHF1 H 60;
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