class ToM_AliceHUD : BaseStatusBar
{
	const noYStretch = 0.833333;
	
	protected transient CVar aspectScale;
	HUDFont mIndexFont;
	protected ToM_HUDFaceController FaceController;
	protected TextureID HUDFace;
	protected int hudstate;
	
	protected int redAmmoFrame;
	protected int YellowAmmoFrame;
	protected int BlueAmmoFrame;
	
	vector2 GetSbarOffsets(bool right = false, int shiftX = 32, int shiftY = 24)
	{
		vector2 ofs = (0, 0);
	
		if (hudstate == HUD_StatusBar)
		{
			ofs = (-shiftX, shiftY);
			if (right)
			{
				ofs.x *= -1;
			}
		}
		
		return ofs;
	}
	
	bool IsAspectCorrected()
	{
		if (!aspectScale)
			aspectScale = CVar.GetCvar('hud_aspectscale',CPlayer);
		
		return (aspectScale && aspectScale.GetBool());
	}

	// Versions of the draw functions that respect
	// UI scaling but ignore UI stretching.
	// These also incorporate automatic offsets
	// to account for minimal and full versions of the HUD.

	void ToM_DrawImage(String texture, Vector2 pos, int flags = 0, double Alpha = 1., Vector2 box = (-1, -1), Vector2 scale = (1, 1))
	{
		if (IsAspectCorrected()) 
		{
			scale.y *= noYStretch;
			pos.y *= noYStretch;
		}
		DrawImage(texture, pos, flags, Alpha, box, scale);
	}
	
	void ToM_DrawTexture(TextureID texture, Vector2 pos, int flags = 0, double Alpha = 1., Vector2 box = (-1, -1), Vector2 scale = (1, 1))
	{
		if (IsAspectCorrected()) 
		{
			scale.y *= noYStretch;
			pos.y *= noYStretch;
		}
		DrawTexture(texture, pos, flags, Alpha, box, scale);
	}
	
	void ToM_DrawString(HUDFont font, String string, Vector2 pos, int flags = 0, int translation = Font.CR_UNTRANSLATED, double Alpha = 1., int wrapwidth = -1, int linespacing = 4, Vector2 scale = (1, 1)) 
	{
		if (IsAspectCorrected()) 
		{
			scale.y *= noYStretch;
			pos.y *= noYStretch;
		}
		DrawString(font, string, pos, flags, translation, Alpha, wrapwidth, linespacing, scale);
	}

	void ToM_DrawInventoryIcon(Inventory item, Vector2 pos, int flags = 0, double alpha = 1.0, Vector2 boxsize = (-1, -1), Vector2 scale = (1.,1.)) 
	{
		if (IsAspectCorrected()) 
		{
			scale.y *= noYStretch;
			pos.y *= noYStretch;
		}
		DrawInventoryIcon(item, pos, flags, alpha, boxsize, scale);
	}
	
	void UpdateManaFrames()
	{
		if (level.time % 3 != 0)
			return;
	
		let am1 = GetCurrentAmmo();
		if (!am1)
			return;
		
		if (am1.GetClass() == "ToM_RedMana")
		{
			if (++redAmmoFrame >= RedManaFrames.Size())
				redAmmoFrame = 0;
		}
			
		else if (am1.GetClass() == "ToM_YellowMana")
		{
			if (++yellowAmmoFrame >= yellowManaFrames.Size())
				yellowAmmoFrame = 0;
		}
		else if (am1.GetClass() == "ToM_PurpleMana")
		{
			if (++blueAmmoFrame >= blueManaFrames.Size())
				blueAmmoFrame = 0;
		}
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
		UpdateManaFrames();
	}
	
	override void Draw (int state, double TicFrac) 
	{
		Super.Draw (state, TicFrac);
			
		if (state == HUD_AltHUD || state == HUD_None)
			return;
		
		hudstate = state;
		
		BeginHUD(1., false, 320, 200);
		
		DrawLeftCorner();
		DrawRightcorner();
		DrawKeys();
		DrawTeapotIcon(pos: (128, -69), DI_SCREEN_LEFT_BOTTOM|DI_ITEM_LEFT_TOP);
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
	
	int GetArmorColor(BasicArmor armor)
	{
		if (!armor)
			return Font.CR_UNTRANSLATED;
		
		if (armor.savepercent < 0.5)
			return Font.CR_White;
		
		else
			return Font.CR_Gold;
	}
	
	void DrawLeftCorner()
	{
		// left decoration - goes below everything
		if (hudstate == HUD_Fullscreen)
		{
			ToM_DrawImage("graphics/HUD/base_left.png", (0, 0), DI_SCREEN_LEFT_BOTTOM|DI_ITEM_LEFT_BOTTOM);
		}
		
		vector2 ofs = GetSbarOffsets();
	
		// armor frame goes first
		let armor = BasicArmor(CPlayer.mo.FindInventory("BasicArmor"));
		if (armor && armor.amount > 0)
		{
			ToM_DrawInventoryIcon(armor, ofs, DI_SCREEN_LEFT_BOTTOM|DI_ITEM_LEFT_BOTTOM);
			ToM_DrawString(mIndexFont, String.Format("%d",GetArmorAmount()), (81, -144) + ofs, DI_SCREEN_LEFT_BOTTOM|DI_TEXT_ALIGN_CENTER, translation: GetArmorColor(armor));
		}
		
		// mirror's background:
		ToM_DrawImage("graphics/HUD/mirror_back.png", ofs, DI_SCREEN_LEFT_BOTTOM|DI_ITEM_LEFT_BOTTOM);
		
		// Alice's face:
		DrawAliceFace((80, -85) + ofs);
		
		// mirror's glass:
		ToM_DrawImage("graphics/HUD/mirror_glass.png", ofs, DI_SCREEN_LEFT_BOTTOM|DI_ITEM_LEFT_BOTTOM);
		
		// cracks in glass (health indication):
		DrawMirrorCracks(ofs);
		
		// mirror's frame goes on top:
		ToM_DrawImage("graphics/HUD/mirror_frame.png", ofs, DI_SCREEN_LEFT_BOTTOM|DI_ITEM_LEFT_BOTTOM);
		
		// finally, health numbers:
		ToM_DrawString(mIndexFont, String.Format("%d",CPlayer.health), (81, -44) + ofs, DI_SCREEN_LEFT_BOTTOM|DI_TEXT_ALIGN_CENTER, translation: GetHealthColor());
	}
	
	// Draws a single mana vessel (3 of them used in right corner)
	void DrawManaVessel(name ammotype, string texture, vector2 pos, double diameter, int flags = 0, string toptexture = "")
	{
		// Since SetClipRect is also subjected to aspect ratio
		// correction, I can't use ToM_Draw* functions here,
		// and instead modify pos and scale and use the regular
		// Draw functions to avoid pixel stretching.
		
		if (IsAspectCorrected()) 
		{
			pos.y *= noYStretch;
		}
	
		// Get ammo type:
		Class<Ammo> ammocls = ammotype;
		if (!ammocls)
			return;
			
		let am = Ammo(CPlayer.mo.FindInventory(ammocls));
		if (!am)
			return;
		
		// Check if current weapon is using this
		// ammo type (if not, we'll dim it)
		bool isSelected;
		let weap = CPlayer.readyweapon;
		isSelected = (weap && weap.ammotype1 == ammocls);
		
		// Get amount and maxamount:
		double amount = am.amount;
		double maxamount = am.maxamount;
		if (maxamount <= 0)
			return;
		
		// Get current ammo/max ammo as a 0.0-1.0 range:
		double amtFac = amount / double(maxamount);
		
		// Calculate the distance of how far to clip the
		// mana texture from the top of the bubble. This
		// distance equals the bubble's diameter multiplied
		// by the factor calculated above:
		double gclip = diameter - diameter * amtFac;
		if (IsAspectCorrected()) 
		{
			gclip *= noYStretch;
		}
		
		// Clipping rectangle allows only things within that
		// rectangle to be rendered. It's also always anchored
		// at its top left corner (they ignore DI_ITEM* flags),
		// so we need to move the clipping rectangle down AND
		// change its vertical height so it only covers a part
		// of the bubble from the top:
		SetClipRect(
			pos.x,
			pos.y + gclip,
			diameter,
			diameter - gclip,
			DI_SCREEN_RIGHT_BOTTOM
		);
		
		vector2 tscale = (1, (IsAspectCorrected() ? noYStretch : 1));
		// Draw the mana texture (properly clipped)
		DrawImage(texture, pos, DI_SCREEN_RIGHT_BOTTOM|DI_ITEM_LEFT_TOP, scale: tscale);
		
		// Dim if current weapon isn't using this mana type:
		if (!isSelected)
		{
			DrawImage("graphics/HUD/vessel_black_liquid.png", pos, DI_SCREEN_RIGHT_BOTTOM|DI_ITEM_LEFT_TOP, alpha: 0.7, scale: tscale);
		}
		// The rest shoudln't be clipped, don't forget to
		// clear the rectangle:
		ClearClipRect();
		
		// The top of the liquid is a separate, fake-3D texture.
		// We need to scale it dynamically, so that it matches the
		// width of the bubble. Here we need a bit of geometry:
		// the bubble is a circle with a diameter of 43, and the top
		// line of the mana texture is that circle's chord.
		// (https://www.cuemath.com/geometry/Chords-of-a-circle/)
		// Using Pythagorean theorem, knowing the vertical pos of that chord
		// we can calculate its exact width. We start with the circle's
		// diameter and with amtFac, which corresponds to the height
		// of the mana level in the bubble:
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
					triHeight = ToM_UtilsP.LinearMap(amtFac, 0.5, 1.0, 0, rad);
				// From half ammo to zero ammo: the cathetus also goes from 
				// 0 to circle's radius:
				else
					triHeight = ToM_UtilsP.LinearMap(amtFac, 0.5, 0.0, 0, rad);
				// The Pythagorean theorem is: hypotenuse squared equals 
				// the sum of its squared catheti (c2 = a2 + b2).
				// Since the chord (or rather, half of it) is a cathetus 
				// here,and radius is the hypotenuse, restructure the 
				// formula:
				// cathetus squared = hypotenuse squared minus the 
				// other cathetus squared:
				double halfChordSquared = ((rad * rad) - (triHeight * triHeight));
				
				// To get the full chord, take a square root of the value
				// calculated above (that's half of the length of the chord)
				// and multiply the result by 2 (that's full length);
				double chord = sqrt(halfChordSquared) * 2;
				
				// Make it a bit smaller so that it doesn't stick out of
				// the bubble's sides (the bubble is pixelated, after all,
				// not a perfectly smooth circle, so it can happen):
				width = chord * 0.96;
			}
			
			// The top texture is aligned to its center (middle of the
			// bubble's width), and its horizontal position is equal
			// to the position of the clip rectangle (which is the top
			// end of the mana texture):
			vector2 tpos = ( pos.x + rad, pos.y + gclip );
			DrawImage(toptexture, tpos, flags: DI_SCREEN_RIGHT_BOTTOM|DI_ITEM_CENTER, box: (width, -1), scale: tscale);
			
			// Dim if current weapon isn't using this mana type:
			if (!isSelected)
			{
				DrawImage("graphics/HUD/vessel_black_liquidtop.png", tpos, flags: DI_SCREEN_RIGHT_BOTTOM|DI_ITEM_CENTER, alpha: 0.7, box: (width, -1), scale: tscale);
			}
		}
	}
	
	void DrawRightcorner()
	{
		vector2 ofs = GetSbarOffsets(right: true);
	
		// red mana:
		DrawManaVessel("ToM_RedMana", RedManaFrames[redAmmoFrame], (-134, -75) + ofs, 43, toptexture: "amanaRtp");
		// yellow mana:
		DrawManaVessel("ToM_YellowMana", yellowManaFrames[yellowAmmoFrame], (-106, -122) + ofs, 43, toptexture: "amanaYtp");
		// purple mana:
		DrawManaVessel("ToM_PurpleMana", blueManaFrames[blueAmmoFrame], (-78, -75) + ofs, 43, toptexture: "amanaBtp");
	
		// vessels:
		ToM_DrawImage("graphics/HUD/vessels.png", ofs, DI_SCREEN_RIGHT_BOTTOM|DI_ITEM_RIGHT_BOTTOM);
		
		if (hudstate == HUD_Fullscreen)
		{
			// right decoration - in contrast to left one,
			// this is drawn on top of the vessels, because
			// some of its elements wrap around them
			ToM_DrawImage("graphics/HUD/base_right.png", (0, 0), DI_SCREEN_RIGHT_BOTTOM|DI_ITEM_RIGHT_BOTTOM);
		}
		
		// runes on the vessels:
		ToM_DrawImage("graphics/HUD/vessel_runes.png", ofs, DI_SCREEN_RIGHT_BOTTOM|DI_ITEM_RIGHT_BOTTOM);
		Ammo am1; Ammo am2; int amt1; int amt2;
		[am1, am2, amt1, amt2] = GetCurrentAmmo();
		string amtex;
		if (am1)
		{
			if (am1.GetClass() == "ToM_RedMana")
				amtex = "vessel_runes_red.png";
			else if (am1.GetClass() == "ToM_YellowMana")
				amtex = "vessel_runes_yellow.png";
			else if (am1.GetClass() == "ToM_PurpleMana")
				amtex = "vessel_runes_blue.png";
			double amtAlpha = ToM_UtilsP.LinearMap(amt1, 0, am1.maxamount, 0.5, 1);
			amtex = String.Format("graphics/HUD/%s", amtex);
			ToM_DrawImage(amtex, ofs, DI_SCREEN_RIGHT_BOTTOM|DI_ITEM_RIGHT_BOTTOM, alpha: amtAlpha);
		}
		
		// highlights go on top:
		ToM_DrawImage("graphics/HUD/vessel_highlights.png", ofs, DI_SCREEN_RIGHT_BOTTOM|DI_ITEM_RIGHT_BOTTOM);
	}

	//Roughly copied from AltHUD but returns the texture, not a bool:
	protected TextureID GetKeyTexture(Key inv) 
	{		
		TextureID icon;	
		if (!inv) 
			return icon;
			
		TextureID AltIcon = inv.AltHUDIcon;
		if (!AltIcon.Exists()) 
			return icon;	// Setting a non-existent AltIcon hides this key.

		if (AltIcon.isValid()) 
			icon = AltIcon;
		else if (inv.SpawnState && inv.SpawnState.sprite) 
		{
			let state = inv.SpawnState;
			if (state) 
				icon = state.GetSpriteTexture(0);
			else 
				icon.SetNull();
		}
		// missing sprites map to TNT1A0. So if that gets encountered, use the default icon instead.
		if (icon.isNull() || TexMan.GetName(icon) == 'tnt1a0') 
			icon = inv.Icon; 

		return icon;
	}
	
	// Draws keys in a horizontal bar, similarly to how AltHUD
	// does it, but does NOT ignore HUD scale:
	void DrawKeys() 
	{
		if (deathmatch)
			return;		
		int hofs = 1;
		vector2 iconpos = (-2, 2);
		double iscale = 1;
		
		int count = Key.GetKeyTypeCount();			
		for(int i = 0; i < count; i++)
		{
			Key inv = Key(CPlayer.mo.FindInventory(Key.GetKeyType(i)));
			TextureID icon = GetKeyTexture(inv);
			if (icon.IsNull()) 
				continue;
			vector2 iconsize = TexMan.GetScaledSize(icon) * iscale;
			ToM_DrawTexture(icon, iconpos, flags: DI_SCREEN_RIGHT_TOP|DI_ITEM_RIGHT_TOP, scale: (iscale, iscale));
			iconpos.x -= (iconsize.x + hofs);
		}
	}
	
	void DrawTeapotIcon(double height = 68, vector2 pos = (0,0), int fflags = DI_SCREEN_LEFT_TOP|DI_ITEM_LEFT_TOP)
	{
		if (!CPlayer.readyweapon)
			return;
		
		let teapot = ToM_Teapot(CPlayer.readyweapon);
		if (!teapot)
			return;
		
		pos += GetSbarOffsets();
		//if (IsAspectCorrected()) pos.y *= noYStretch;
		
		ToM_DrawImage("graphics/hud/teapot_base.png", pos, fflags);
		
		if (teapot.heat <= 0)
			return;
		
		// Get current heat level as a 0.0-1.0 range:
		double amtFac = teapot.heat / teapot.HEAT_MAX;
		// clip distance:
		double cclip = height - height * amtFac;
		
		vector2 cpos = pos;
		if (IsAspectCorrected())
		{
			cpos.y *= noYStretch;
			//cclip *= noYStretch;
		}
		SetClipRect(
			pos.x,
			pos.y + cclip,
			height,
			height - cclip,
			fflags
		);
		
		string tex = "teapot_yellow.png";
		if (teapot.overheated)
			tex = "teapot_red.png";
		else if (teapot.heat >= teapot.HEAT_MED)
			tex = "teapot_orange.png";
		string ftex = String.Format("graphics/hud/%s",tex);
		
		ToM_DrawImage(ftex, pos, fflags);
		ClearClipRect();
		
		if (teapot.overheated)
		{
			ToM_DrawImage("ACTPPUFF", pos, fflags);
		}
	}
		
		
	
	void DrawAliceFace(vector2 pos)
	{
		if (!HUDFace || CPlayer.health <= 0)
			return;
		
		ToM_DrawTexture(HUDFace, pos, DI_SCREEN_LEFT_BOTTOM|DI_ITEM_CENTER);
	}
	
	void DrawMirrorCracks(vector2 pos)
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
			ToM_DrawImage(path..tex, pos, DI_SCREEN_LEFT_BOTTOM|DI_ITEM_LEFT_BOTTOM);
		}
	}
	
	static const name RedManaFrames[] = 
	{
		"amanaR01",
		"amanaR02",
		"amanaR03",
		"amanaR04",
		"amanaR05",
		"amanaR06",
		"amanaR07",
		"amanaR08",
		"amanaR09",
		"amanaR10",
		"amanaR11",
		"amanaR12"
	};

	static const name YellowManaFrames[] = 
	{
		"amanaY01",
		"amanaY02",
		"amanaY03",
		"amanaY04",
		"amanaY05",
		"amanaY06",
		"amanaY07",
		"amanaY08",
		"amanaY09",
		"amanaY10",
		"amanaY11",
		"amanaY12"
	};
	
	static const name BlueManaFrames[] = 
	{
		"amanaB01",
		"amanaB02",
		"amanaB03",
		"amanaB04",
		"amanaB05",
		"amanaB06",
		"amanaB07",
		"amanaB08",
		"amanaB09",
		"amanaB10",
		"amanaB11",
		"amanaB12"
	};
}

// Since it's impossible to easily do multi-frame animations
// in the HUD, I'm using a simple actor attached to the player
// and use its state sequences to do the animation.
// The actor's current sprite is read by the HUD and drawn
// as a regular texture.

class ToM_HUDFaceController : Actor
{
	PlayerInfo HPlayer;
	PlayerPawn HPlayerPawn;
	
	const BLINK_MIN = 35;
	const BLINK_MAX = 35 * 5;
	
	const DMGDELAY = 20;
	protected int dmgwait;
	
	protected state s_front_calm;
	protected state s_front_angry;
	protected state s_front_smile;
	protected state s_front_demon;
	protected state s_front_ouch;
	protected state s_return_left_calm;
	protected state s_return_right_calm;
	protected state s_return_left_angry;
	protected state s_return_right_angry;
	protected state s_right_angry;
	protected state s_left_angry;
	
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