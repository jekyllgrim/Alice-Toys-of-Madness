class ToM_AliceHUD : BaseStatusBar
{
	const noYStretch = 0.833333;
	InventoryBarState invbarstate;
	
	protected transient CVar aspectScale;
	HUDFont hfIndexfont;
	HUDFont hfAsrafel;
	protected ToM_HUDFaceController FaceController;
	protected int hudstate;
	
	protected int weakAmmoFrame;
	protected int mediumAmmoFrame;
	protected int strongAmmoFrame;
	
	protected transient CVar userHudScale;
	protected transient CVar userOldHudScale;

	const MAXWEAPICONOFS = 70;
	protected int curWeapIconOfs;
	
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
		
		return (aspectScale.GetBool());
	}

	// Versions of the draw functions that respect
	// UI scaling but ignore UI stretching.
	// These also incorporate automatic offsets
	// to account for minimal and full versions of the HUD.

	void ToM_DrawImage(String texture, Vector2 pos, int flags = 0, double alpha = 1., Vector2 box = (-1, -1), Vector2 scale = (1, 1), ERenderStyle style = STYLE_Translucent, Color col = 0xffffffff, int translation = 0, double clipwidth = -1)
	{
		if (IsAspectCorrected()) 
		{
			scale.y *= noYStretch;
			pos.y *= noYStretch;
		}
		DrawImage(texture, pos, flags, alpha, box, scale, style, col, translation, clipwidth);
	}
	
	void ToM_DrawTexture(TextureID texture, Vector2 pos, int flags = 0, double alpha = 1., Vector2 box = (-1, -1), Vector2 scale = (1, 1), ERenderStyle style = STYLE_Translucent, Color col = 0xffffffff, int translation = 0, double clipwidth = -1)
	{
		if (IsAspectCorrected()) 
		{
			scale.y *= noYStretch;
			pos.y *= noYStretch;
		}
		DrawTexture(texture, pos, flags, alpha, box, scale, style, col, translation, clipwidth);
	}

	void ToM_DrawImageRotated(String texid, Vector2 pos, int flags, double angle, double alpha = 1, Vector2 scale = (1, 1), ERenderStyle style = STYLE_Translucent, Color col = 0xffffffff, int translation = 0)
	{
		if (IsAspectCorrected()) 
		{
			scale.y /= noYStretch;
			pos.y *= noYStretch;
		}
		DrawImageRotated(texid, pos, flags, angle, alpha, scale, style, col, translation);
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

	void ToM_Fill(Color col, Vector2 pos, Vector2 size, int flags = 0)
	{
		if (IsAspectCorrected()) 
		{
			size.y *= noYStretch;
			pos.y *= noYStretch;
		}
		Fill(col, pos.x, pos.y, size.x, size.y, flags);
	}

	override void DrawPowerups ()
	{}
	
	void UpdateManaFrames()
	{
		if (level.time % 3 != 0)
			return;
	
		let am1 = GetCurrentAmmo();
		if (!am1)
			return;
		
		if (am1.GetClass() == "ToM_WeakMana")
		{
			if (++weakAmmoFrame >= WeakManaFrames.Size())
				weakAmmoFrame = 0;
		}
			
		else if (am1.GetClass() == "ToM_MediumMana")
		{
			if (++mediumAmmoFrame >= MediumManaFrames.Size())
				mediumAmmoFrame = 0;
		}
		else if (am1.GetClass() == "ToM_StrongMana")
		{
			if (++strongAmmoFrame >= StrongManaFrames.Size())
				strongAmmoFrame = 0;
		}
	}
		
	
	override void Init() 
	{
		super.Init();
		Font fnt = Font.FindFont('AsrafelComplete');
		//hfIndexfont = HUDFont.Create(fnt, fnt.GetCharWidth("0"), Mono_CellLeft, 1, 1);
		hfAsrafel = HUDFont.Create(fnt);
		hfIndexfont = HUDFont.Create(fnt, shadowx: 2, shadowy: 2);

		invbarstate = InventoryBarstate.Create();
	}
	
	override void Tick()
	{
		super.Tick();
		UpdateManaFrames();
	}
	
	override void Draw (int state, double TicFrac) 
	{
		Super.Draw (state, TicFrac);
			
		if (state == HUD_AltHUD || state == HUD_None) return;
		
		hudstate = state;
		vector2 hudres = (640, 400);
		
		// Workaround for fullscreen HUD scaling when the user
		// has 'hud_olscale' CVAR set to true. 
		// With oldscale, HUD scaling options are broken for huds
		// that aren't 320x200: the scale slider doesn't apply
		// the changes at every increment.
		// For some reason, drawing a forcescaled HUD and then
		// manually scaling it with a CVAR check seems to work.
		
		if (!userOldHudScale)
		{
			userOldHudScale = CVar.GetCVar('hud_oldscale', CPlayer);
		}
		
		// If 'hud_oldscale' is false, we'll rely on normal scaling.
		if (userOldHudScale.GetBool() == true)
		{
			if (!userHudScale)
				userHudScale = CVar.GetCVar('hud_scale', CPlayer);
			int userscale = int(Clamp(userHudScale.GetInt(), -1., 8.));
			// -1 = adapt to screen scale, 0 = use default scale
			// apply manual scaling only if it's over 0:
			if (userscale > 0.)
				hudres /= userscale;
		}

		BeginHUD(1., false /*userOldHudScale.GetBool()*/, int(hudres.x), int(hudres.y));

		UpdateWeaponIconOfs(TicFrac);
		DrawLeftCorner();
		DrawRightcorner();
		DrawKeys();
		DrawWeaponIcons();
		//DrawTeapotIcon(pos: (128, -69), DI_SCREEN_LEFT_BOTTOM|DI_ITEM_LEFT_TOP);
		DrawPowerupClock();

		if (isInventoryBarVisible())
		{
			DrawInventoryBar(invbarstate, (0, 0), 7, DI_SCREEN_CENTER_BOTTOM, HX_SHADOW);
		}
	}

	static const string clockhands[] =
	{
		"graphics/hud/timepiece/powerclock_hand1.png",
		"graphics/hud/timepiece/powerclock_hand2.png",
		"graphics/hud/timepiece/powerclock_hand3.png",
		"graphics/hud/timepiece/powerclock_hand4.png",
		"graphics/hud/timepiece/powerclock_hand5.png"
	};

	array < class<Weapon> > playerWeapons;
	const MAXWEAPONSLOTS = 10;

	void WeaponSlotsInit()
	{
		let wslots = CPlayer.weapons;
		for (int i = 1; i <= MAXWEAPONSLOTS; i++)
		{
			// Slot 0 is the 10th slot:
			int sn = i >= MAXWEAPONSLOTS ? 0 : i;
			int size = wslots.SlotSize(sn);
			if (size <= 0)
				continue;

			for (int s = 0; s < size; s++)
			{
				class<Weapon> weap = wslots.GetWeapon(sn, s);
				if (weap)
				{
					playerWeapons.Push(weap);
				}
			}
		}
	}

	Weapon curWeapon;
	Weapon prevWeapon;
	void UpdateWeaponIconOfs(double ticfrac)
	{
		curWeapIconOfs = int(Clamp(curWeapIconOfs - ticfrac, 0, MAXWEAPICONOFS));

		Weapon selected = Cplayer.readyweapon;
		if (!selected) return;
		Weapon pending = Cplayer.pendingweapon;
		if (pending == WP_NOCHANGE) pending = null;

		if (!curWeapon || !pending)
		{
			curWeapon = selected;
		}
		else if (pending && pending != WP_NOCHANGE && pending != curWeapon)
		{
			curWeapIconOfs = MAXWEAPICONOFS;
			prevWeapon = curWeapon;
			curWeapon = pending;
		}
	}

	void DrawWeaponIcons()
	{
		Vector2 pos = (144, 0);
		int flags = DI_SCREEN_LEFT_BOTTOM;
		if (playerWeapons.Size() <= 0)
		{
			WeaponSlotsInit();
		}
		ToM_DrawImage("graphics/hud/WeaponIcons/wslots_edgecurl.png", pos, flags|DI_ITEM_RIGHT_BOTTOM);
		TextureID edgeTex = TexMan.CheckForTexture("graphics/hud/WeaponIcons/wslots_edge.png");
		TextureID baseTex = TexMan.CheckForTexture("graphics/hud/WeaponIcons/wslots_base.png");
		Vector2 baseSize = Texman.GetScaledSize(baseTex);
		for (int i = 0; i < playerWeapons.Size(); i++)
		{
			Weapon weap = Weapon(CPlayer.mo.FindInventory(playerWeapons[i]));
			if (!weap) continue;
			Vector2 ppos = pos;
			if (prevWeapon && weap == prevWeapon)
			{
				ppos.y += (MAXWEAPICONOFS - curWeapIconOfs);
			}
			else if (curWeapon && weap == curWeapon)
			{
				ppos.y += curWeapIconOfs;
			}
			else
			{
				ppos.y += MAXWEAPICONOFS;
			}
			
			ToM_DrawTexture(baseTex, ppos, flags|DI_ITEM_LEFT_BOTTOM);
			TextureID icon = GetIcon(weap, 0);
			if (icon && icon.isValid())
			{
				Vector2 wpos = ppos + (baseSize.x * 0.5, baseSize.y * -0.5);
				ToM_DrawTexture(icon, wpos, flags|DI_ITEM_CENTER, box: baseSize - (2, 2));
				DrawSpecialIconRules(weap, wpos, flags|DI_ITEM_CENTER, box: baseSize - (2, 2));
			}
			ToM_DrawTexture(edgeTex, pos, flags|DI_ITEM_LEFT_BOTTOM);
			pos.x += 4;
		}
		ToM_DrawImage("graphics/hud/WeaponIcons/wslots_edgecurl_r.png", pos + (baseSize.x - 4, 0), flags|DI_ITEM_LEFT_BOTTOM);
	}

	void DrawSpecialIconRules(Weapon weap, Vector2 pos, int flags, Vector2 box = (-1, -1))
	{
		if (!(weap is 'ToM_BaseWeapon')) return;

		// Teapot heat indicator:
		let teapot = ToM_Teapot(weap);
		if (teapot && teapot.heat > 0)
		{
			// Get current heat level as a 0.0-1.0 range:
			double fac = Clamp(double(teapot.heat) / teapot.HEAT_MAX, 0.0, 1.0);
			// Align clip rectangle around the box, then 
			// move it down based on the amount of heat:
			SetClipRect(
				pos.x - box.x*0.5,
				pos.y - box.y*0.5 + box.y * (1.0 - fac),
				box.x,
				box.y,
				flags
			);
			ToM_DrawImage("AWICTPOR", pos, flags, box: box);
			ClearClipRect();
			if (teapot.overheated && level.maptime & 8)
			{
				ToM_DrawImage("AWICTPOS", pos, flags);
			}
		}

		// Vorpal knife combo indicator:
		let knife = ToM_Knife(weap);
		if (knife && ToM_RageBox.HasRageBox(CPlayer.mo))
		{
			ToM_DrawImage("AWICVKNR", pos, flags, style: STYLE_Add);
		}

		// Eyestaff charge indicator:
		let eyestaff = ToM_Eyestaff(weap);
		if (eyestaff && eyestaff.charge > 0)
		{
			double fac = Clamp(double(eyestaff.charge) / eyestaff.ES_FULLBEAMCHARGE, 0.0, 1.0);
			let psp = CPlayer.FindPSprite(PSP_WEAPON);
			if (psp && psp.curstate.InStateSequence(eyestaff.FindState("FireBeam")))
			{
				fac = 1.0;
			}
			ToM_DrawImage("AWICEYER", pos, flags, alpha: fac, style: STYLE_Add);
		}

		// Blunderbuss charge indicator:
		let bbus = ToM_Blunderbuss(weap);
		if (bbus && bbus.charge > 0)
		{
			double fac = Clamp(bbus.charge / 5.0, 0.0, 1.0);
			ToM_DrawImage("AWICBBUR", pos, flags, alpha: fac, style: STYLE_Add);
		}
	}

	array <Powerup> powerups;

	void DrawPowerupClock()
	{
		vector2 pos = (66, 71);
		int fflags = DI_SCREEN_LEFT_TOP|DI_ITEM_CENTER;

		bool found;
		for (let item = CPlayer.mo.inv; item != null; item = item.inv)
		{
			let pwr = Powerup(item);
			if (!pwr)
				continue;

			let icon = pwr.GetPowerupIcon();
			if (!icon || !icon.IsValid())
				continue;
			
			found = true;
			if (powerups.Find(pwr) == powerups.Size())
			{
				powerups.Push(pwr);
			}
		}

		if (!found)
		{
			powerups.Clear();
			return;
		}

		ToM_DrawImage("graphics/hud/timepiece/powerclock.png", pos, fflags);

		int texid;
		for (int i = 0; i < powerups.Size(); i++)
		{
			let pwr = powerups[i];
			if (!pwr)
				continue;

			int curSec = abs(pwr.EffectTics) / 35;
			int handAng = curSec * -6;
			ToM_DrawImageRotated(clockhands[texid], pos, fflags, handAng/*, style: STYLE_Shaded, col: pwr.blendColor*/); //hand
			ToM_DrawImageRotated(clockhands[texid], pos - (2, 2), fflags, handAng, alpha: 0.2); //shadow
			if (!pwr.IsBlinking())
			{
				let icon = pwr.GetPowerupIcon();
				if (icon && icon.IsValid()) 
				{
					vector2 targetsize = (16, 16);
					vector2 iconsize = TexMan.GetScaledSize(icon);
					targetsize.x /= iconsize.x;
					targetsize.y /= iconsize.y;
					//console.printf("%s icon: %s", pwr.GetTag(), TexMan.GetName(icon));
					ToM_DrawTexture(icon, pos + Actor.RotateVector((0, -32), -handAng), fflags, scale: targetsize);
				}
			}
			texid++;
			if (texid >= clockhands.Size())
				texid = 0;
		}

		ToM_DrawImage("graphics/hud/timepiece/powerclock_glass.png", pos, fflags);
	}
	
	// Red at 25% or less, white otherwise:
	int GetHealthColor()
	{
		int hmax = CPlayer.mo.GetMaxHealth(true);
		int health = CPlayer.health;
		if (health <= (hmax * 0.25))
			return Font.CR_Red;
		return Font.CR_White;
	}
	
	// White if the armor absorbs less than 50% damage,
	// gold otherwise:
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
		let barm = BasicArmor(CPlayer.mo.FindInventory("BasicArmor"));
		if (barm && barm.amount > 0)
		{
			String armimg;
			switch(barm.armortype)
			{
				case 'ToM_ArmorBonus':
					armimg = "graphics/HUD/armor_bronze.png";
					break;
				case 'ToM_SilverArmor':
					armimg = "graphics/HUD/armor_silver.png";
					break;
				default:
					armimg = "graphics/HUD/armor_gold.png";
					break;
			}
			ToM_DrawImage(armimg, ofs, DI_SCREEN_LEFT_BOTTOM|DI_ITEM_LEFT_BOTTOM);
			ToM_DrawString(hfIndexfont, String.Format("%d",GetArmorAmount()), (81, -152) + ofs, DI_SCREEN_LEFT_BOTTOM|DI_TEXT_ALIGN_CENTER, translation: GetArmorColor(barm), scale: (0.5, 0.35));
		}
		
		// mirror's background:
		ToM_DrawImage("graphics/HUD/mirror_back.png", ofs, DI_SCREEN_LEFT_BOTTOM|DI_ITEM_LEFT_BOTTOM);
		
		// Alice's face:
		DrawAliceFace(ofs, (80, -85));
		
		// mirror's glass:
		ToM_DrawImage("graphics/HUD/mirror_glass.png", ofs, DI_SCREEN_LEFT_BOTTOM|DI_ITEM_LEFT_BOTTOM);
		
		// cracks in glass (health indication):
		DrawMirrorCracks(ofs);
		
		// mirror's frame goes on top:
		ToM_DrawImage("graphics/HUD/mirror_frame.png", ofs, DI_SCREEN_LEFT_BOTTOM|DI_ITEM_LEFT_BOTTOM);
		
		// finally, health numbers:
		ToM_DrawString(hfIndexfont, String.Format("%d",CPlayer.health), (81, -43) + ofs, DI_SCREEN_LEFT_BOTTOM|DI_TEXT_ALIGN_CENTER, translation: GetHealthColor(), scale: (0.5, 0.35));
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
		amtFac = Clamp(amtfac, 0.0, 1.0);
		
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
		
		// The top of the liquid is a separate, fake-3D texture that
		// represents the top surface of the liquid.
		// We need to scale it dynamically, so that it matches the
		// width of the bubble. We'll utilize a bit of basic geometry:
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
					triHeight = ToM_Utils.LinearMap(amtFac, 0.5, 1.0, 0, rad);
				// From half ammo to zero ammo: the cathetus also goes from 
				// 0 to circle's radius:
				else
					triHeight = ToM_Utils.LinearMap(amtFac, 0.5, 0.0, 0, rad);
				// The Pythagorean theorem is: hypotenuse squared equals 
				// the sum of its squared catheti (c*c = a*a + b*b).
				// Since the chord (or rather, half of it) is a cathetus 
				// here, and the radius is the hypotenuse, restructure the 
				// formula:
				// cathetus squared = hypotenuse squared minus the 
				// other cathetus squared:
				double halfChordSquared = ((rad * rad) - (triHeight * triHeight));
				
				// To get the full chord, take a square root of the value
				// calculated above (that's half of the length of the chord)
				// and multiply the result by 2 (that's full length):
				double chord = sqrt(halfChordSquared) * 2;
				
				// Make it a bit smaller so that it doesn't stick out of
				// the bubble's sides (the bubble is pixelated, after all,
				// not a perfectly smooth circle, so it can happen):
				width = chord * 0.95;
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

	void DrawJackBomb(Vector2 pos, int flags, double scale =  1.0)
	{
		let jackbomb = ToM_JackBombPickup(CPlayer.mo.FindInventory('ToM_JackBombPickup'));
		if (!jackbomb || jackbomb.amount <= 0) return;

		TextureID back = TexMan.CheckForTexture("graphics/hud/jackbomb_icon_back.png");
		TextureID front = TexMan.CheckForTexture("graphics/hud/jackbomb_icon_front.png");
		Vector2 size = TexMan.GetScaledSize(back) * scale;

		ToM_DrawTexture(back, pos, flags, scale:(scale, scale));
		if (jackbomb.throwTimer > 0)
		{
			double fac = jackbomb.throwTimer / double(ToM_JackBombPickup.JACKBOMB_FIRERATE);
			ToM_Fill(0xaaa0a0a0, pos + (-size.x, -size.y*fac), (size.x, size.y*fac), flags);
		}
		ToM_DrawTexture(front, pos, flags, scale:(scale, scale));
		ToM_DrawString(hfAsrafel, ""..jackbomb.amount, pos - size + (15,10)*scale, flags|DI_TEXT_ALIGN_CENTER, scale: (0.4, 0.4) * scale);
	}
	
	void DrawRightcorner()
	{
		DrawJackBomb((0, -160), DI_SCREEN_RIGHT_BOTTOM|DI_ITEM_RIGHT_BOTTOM, 0.75);

		vector2 ofs = GetSbarOffsets(right: true);
	
		// weak mana:
		DrawManaVessel("ToM_WeakMana", WeakManaFrames[weakAmmoFrame], (-134, -75) + ofs, 43, toptexture: "amanaWtp");
		// medium mana:
		DrawManaVessel("ToM_MediumMana", MediumManaFrames[mediumAmmoFrame], (-106, -122) + ofs, 43, toptexture: "amanaMtp");
		// purple mana:
		DrawManaVessel("ToM_StrongMana", StrongManaFrames[strongAmmoFrame], (-78, -75) + ofs, 43, toptexture: "amanaStp");
	
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
		string amLightTex;
		if (am1)
		{
			if (am1.GetClass() == "ToM_WeakMana")
			{
				amtex = "vessel_runes_weak.png";
				amLightTex = "vessel_runes_weak_highlights.png";
			}
			else if (am1.GetClass() == "ToM_MediumMana")
			{
				amtex = "vessel_runes_medium.png";
				amLightTex = "vessel_runes_medium_highlights.png";
			}
			else if (am1.GetClass() == "ToM_StrongMana")
			{
				amtex = "vessel_runes_strong.png";
				amLightTex = "vessel_runes_strong_highlights.png";
			}
			double amtAlpha = ToM_Utils.LinearMap(amt1, 0, am1.maxamount, 0.5, 1);
			amtex = String.Format("graphics/HUD/%s", amtex);
			amLightTex = String.Format("graphics/HUD/%s", amLightTex);
			ToM_DrawImage(amtex, ofs, DI_SCREEN_RIGHT_BOTTOM|DI_ITEM_RIGHT_BOTTOM, alpha: amtAlpha);
			ToM_DrawImage(amLightTex, ofs, DI_SCREEN_RIGHT_BOTTOM|DI_ITEM_RIGHT_BOTTOM, alpha: amtAlpha);
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
	
	void DrawAliceFace(vector2 pos, vector2 ofs)
	{
		if (CPlayer.health <= 0 || !CPlayer.mo)
			return;
		
		Screen.EnableStencil(true);
		Screen.SetStencil(0, SOP_Increment, SF_ColorMaskOff);
		// use mirror's background as a mask:
		ToM_DrawImage("graphics/HUD/mirror_back.png", pos, DI_SCREEN_LEFT_BOTTOM|DI_ITEM_LEFT_BOTTOM);
		Screen.SetStencil(1, SOP_Keep, SF_AllOn);
		
		if (!FaceController)
		{
			FaceController = ToM_AlicePlayer(CPlayer.mo).GetHUDFace();
		}

		else
		{
			TextureID face = FaceController.GetFaceTexture();
			if (face.isValid())
			{
				Vector2 size = TexMan.GetScaledSize(face);
				double scaleFac = CPlayer.mo.scale.y / CPlayer.mo.default.scale.y;
				ToM_DrawTexture(face, pos + ofs + (0, size.y*0.5), DI_SCREEN_LEFT_BOTTOM|DI_ITEM_CENTER_BOTTOM, alpha:CPlayer.mo.alpha, scale: (scaleFac, scaleFac));
			}
		}

		Screen.EnableStencil(false);
		Screen.ClearStencil();
	}

	static const name mirrorCrackTex[] =
	{
		"mirror_cracks01.png",
		"mirror_cracks02.png",
		"mirror_cracks03.png",
		"mirror_cracks04.png",
		"mirror_cracks05.png",
		"mirror_cracks06.png",
		"mirror_cracks07.png",
		"mirror_cracks08.png",
		"mirror_cracks09.png",
		"mirror_cracks10.png",
		"mirror_cracks11.png",
		"mirror_cracks12.png",
		"mirror_cracks13.png",
		"mirror_cracks14.png",
		"mirror_cracks15.png"
	};

	void DrawMirrorCracks(vector2 pos)
	{
		int health = CPlayer.health;
		if (health > 70)
			return;
		
		String texpath;
		if (health <= 0)
		{
			texpath = String.Format("graphics/HUD/%s", mirrorCrackTex[mirrorCrackTex.Size()-1]);
		}
		else
		{
			double pick = ToM_Utils.LinearMap(health, 65, 0, 0, mirrorCrackTex.Size() - 1);
			int i = int(Clamp(round(pick), 0, mirrorCrackTex.Size() - 1));
			texpath = String.Format("graphics/HUD/%s", mirrorCrackTex[i]);
		}

		if (texpath)
		{
			ToM_DrawImage(texpath, pos, DI_SCREEN_LEFT_BOTTOM|DI_ITEM_LEFT_BOTTOM);
		}
	}
	
	static const name WeakManaFrames[] = 
	{
		"amanaW00",
		"amanaW01",
		"amanaW02",
		"amanaW03",
		"amanaW04",
		"amanaW05",
		"amanaW06",
		"amanaW07",
		"amanaW08",
		"amanaW09",
		"amanaW10",
		"amanaW11"
	};

	static const name MediumManaFrames[] = 
	{
		"amanaM00",
		"amanaM01",
		"amanaM02",
		"amanaM03",
		"amanaM04",
		"amanaM05",
		"amanaM06",
		"amanaM07",
		"amanaM08",
		"amanaM09",
		"amanaM10",
		"amanaM11"
	};
	
	static const name StrongManaFrames[] = 
	{
		"amanaS00",
		"amanaS01",
		"amanaS02",
		"amanaS03",
		"amanaS04",
		"amanaS05",
		"amanaS06",
		"amanaS07",
		"amanaS08",
		"amanaS09",
		"amanaS10",
		"amanaS11"
	};
}

// Since it's impossible to easily do multi-frame animations
// in the HUD, I'm using a simple actor attached to the player
// and use its state sequences to do the animation.
// The actor's current sprite is read by the HUD and drawn
// as a regular texture.

class ToM_HUDFaceController : Actor
{
	const DMGDELAY = 25;

	protected PlayerInfo HPlayer;
	protected PlayerPawn HPlayerPawn;
	
	protected int dmgwait;
	protected int damageAmount;
	protected double damageAngle;
	protected int attackdown;
	
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
	protected state s_ragebox;
	protected state s_ragebox_loop;
	
	Default
	{
		+NOINTERACTION
		+NOBLOCKMAP
		+NOSECTOR
		+SYNCHRONIZED
		+NOTIMEFREEZE
		FloatBobPhase 0;
		YScale 0.834;
	}

	static ToM_HUDFaceController Create(PlayerPawn ppawn)
	{
		if (!ppawn || !ppawn.player || !ppawn.player.mo || ppawn.player.mo != ppawn)
		{
			return null;
		}
		let fc = ToM_HUDFaceController(Actor.Spawn("ToM_HUDFaceController", ppawn.pos));
		if (fc)
		{
			fc.HPlayerPawn = ppawn;
			fc.HPlayer = ppawn.player;
		}
		return fc;
	}
	
	clearscope TextureID GetFaceTexture()
	{
		return curstate.GetSpriteTexture(0);
	}
	
	bool CheckFaceSequence(state checkstate)
	{
		return (checkstate && InStateSequence(curstate, checkstate));
	}
	
	void SetFaceState(state newstate, bool noOverride = false)
	{
		if (!noOverride || !CheckFaceSequence(newstate))
		{
			SetState(newstate);
		}
	}

	void PlayerDamaged(int damage, double angle)
	{
		damageAmount = damage;
		damageAngle = angle;
	}

	bool HasRageBox()
	{
		//Console.Printf("HPlayerPawn %d | has rage box: %d", HPlayerPawn != null, HPlayerPawn != null && (HPlayerPawn.CountInv("ToM_RageBoxSelector") || HPlayerPawn.CountInv("ToM_RageBoxEffect")));
		return HPlayerPawn && ToM_RageBox.HasRageBox(HPlayerPawn);
	}

	bool IsInvulnerable()
	{
		return HPlayerPawn && (/*HPlayerPawn.bINVULNERABLE || */HPlayer.cheats & CF_GODMODE || HPlayer.cheats & CF_GODMODE2);
	}

	void UpdateValues()
	{
		attackdown = HPlayer.attackdown? attackdown += 1 : 0;
		
		if (dmgwait > 0)
		{
			dmgwait--;
		}
	}
	
	override void BeginPlay()
	{
		super.BeginPlay();
		A_SpriteOffset(-32, -128);
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
		s_ragebox = FindState("RageBoxActivation");
		s_ragebox_loop = FindState("RageBoxLoop");
	}
	
	override void Tick()
	{
		if (!HPlayer || !HPlayerPawn)
			return;
		
		super.Tick();
		
		// Rage box face takes priority:
		if (HasRageBox())
		{
			SetFaceState(s_ragebox, true);
		}
		
		// Otherwise invulnerable face takes priority:
		else if (IsInvulnerable())
		{
			SetFaceState(s_front_demon, true);
		}
		
		// Otherwise, if we're damaged, display one of the
		// damaged faces:
		else if (damageAmount > 0 && dmgwait <= 0)
		{
			// Set this to DMGDELAY, so that if we're damaged
			// continuously, the state doesn't get activated
			// too frequently and has the chance to actually
			// show its animation:
			dmgwait = DMGDELAY;
			if (damageAmount >= 25)
			{
				SetFaceState(s_front_ouch, true);
			}
			else
			{
				// Attacked from the front:
				if (abs(damageAngle) < 40)
				{
					// If already looking left, return from left:
					if (CheckFaceSequence(s_left_angry))
					{
						SetFaceState(s_return_left_angry);
					}
					// If looking right, return from right:
					else if (CheckFaceSequence(s_right_angry))
					{
						SetFaceState(s_return_right_angry);
					}
					// Otherwise just show front damage face:
					else
					{
						SetFaceState(s_front_angry);
					}
				}
				// Attacked from the right:
				else if (damageAngle < 0)
				{
					SetFaceState(s_right_angry);
				}
				// Attacked from the left:
				else
				{
					SetFaceState(s_left_angry);
				}
			}
			// Don't forget to reset the stored amount of damage,
			// so that the state doesn't get triggered mutliple
			// times:
			damageAmount = 0;
		}

		// Otherwise go to rampage face if attackdown has been
		// true for 2 seconds:
		else if (attackdown >= TICRATE*2)
		{
			SetFaceState(s_front_angry, true);
		}

		UpdateValues();
	}
	
	States
	{
	Spawn:
	FrontCalm:
		AHF1 A 1 NoDelay A_SetTics(random[ahf](TICRATE, TICRATE * 4));
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
		AHF5 AAAABBBBCCCCDDDDCCCCCBBBBB 1
		{
			if (!IsInvulnerable())
			{
				return State(s_front_calm);
			}
			return State(null);
		}
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
	RageBoxActivation:
		AHF6 ABCDEFGHI 6;
	RageBoxLoop:
		AHF7 ABCDEFGHIJKLM 5 A_SetTics(random[ahf](3, 7));
		TNT1 A 0
		{
			if (!HasRageBox())
			{
				return ResolveState("RageBoxDeactivation");
			}
			return ResolveState(null);
		}
		loop;
	RageBoxDeactivation:
		AHF6 IHGFEDCBA 4;
		goto FrontCalm;
	}
}