// Skill/episode menu. Uses a simple black background with text-only elements:

class ToM_SkillMenu : ListMenu 
{
	mixin ToM_DeltaTime;
	double textElementScale;
	array<ToM_TextItemHighlight> itemHighlights;

	override void Init(Menu parent, ListMenuDescriptor desc)
	{
		Super.Init(parent, desc);
		// Workaround to manually scale down the list of elements
		// if it becomes too long. This is mainly intended for
		// Wadsmooth users with a gigantic list of episodes:
		textElementScale = 1.0;
		if (mDesc)
		{
			int totalElements = mDesc.mItems.Size();
			double resFactor = mDesc.mVirtHeight / double(Screen.GetHeight());
			double totalHeightElements = (mDesc.mFont.GetHeight() + mDesc.mLinespacing) * resFactor * totalElements;
			double totalHeightMenu = mDesc.mVirtHeight * 0.75; //elements begin drawing 1/4th down from the top
			if (totalHeightElements > mDesc.mVirtHeight)
			{
				textElementScale = totalHeightElements / totalHeightMenu;
			}
			//Console.Printf("Total elements: %d | total height of elements: %.1f | total height of menu: %.1f | font scale factor: %.2f",totalElements, totalHeightElements, totalHeightMenu, textElementScale);
		}
	}

	override void Ticker()
	{
		Super.Ticker();
		if (mDesc && mDesc.mSelectedItem >= 0 && Menu.MenuTime() % 4 == 0)
		{
			Vector2 pos = (0, 0);
			Vector2 scale = (1, frandom[menusfx](1,1.5));
			pos.y -= mDesc.mLinespacing * (scale.y - 1) * 0.5;
			double alpha = frandom[menusfx](0.15, 0.25);
			itemHighlights.Push(ToM_TextItemHighlight.Create(pos, scale, alpha));
		}
	}

	override void Drawer()
	{
		Screen.Dim(0x000000, 1.0, 0, 0, Screen.GetWidth(), Screen.GetHeight());
		UpdateDeltaTime();

		double vHeight = mDesc.mVirtHeight * textElementScale;
		double vWidth = (mDesc.mVirtWidth * textElementScale) / 2; //center of the menu
		int y = vHeight / 4; //elements (except the title) begin drawing 1/4th down from the top
		let mFont = mDesc.mFont;

		for (int i = 0; i < mDesc.mItems.Size(); ++i)
		{
			let mItem = mDesc.mItems[i];
			if (!mItem)
				continue;
	
			// Draw the title:
			let title = ListMenuItemStaticTextCentered(mItem);
			if (title)
			{
				string text = StringTable.Localize(title.mText);
				// we'll use the title's own position, but forcibly centered
				// (if we pass title.GetX(), it won't be properly centered,
				// since that's the raw position).
				// Note, title is never scaled like other elements, since it
				// always has enough position due to occupying the top 1/4th
				// of the menu screen:
				vector2 textpos = ( (mDesc.mVirtWidth / 2) - (mFont.StringWidth(text) / 2), title.GetY());
				// draw the actual text:
				Screen.DrawText(
					mFont, 
					Font.CR_Untranslated,
					textpos.x, textpos.y,
					text, 
					DTA_VirtualWidth, mDesc.mVirtWidth,
					DTA_VirtualHeight, mDesc.mVirtHeight,
					DTA_FullscreenScale, FSMode_ScaleToFit43
				);
			}
			
			// Draw the skills:
			let item = ListMenuItemTextItem(mItem);
			if (item)
			{
				// Set vertical collision for mouse selection:
				item.SetY(y);
				item.mHeight = mDesc.mLinespacing;

				string text = StringTable.Localize(item.mText);
				text.StripRight("."); //full stops at the end of titles are just WRONG!
				double textwidth = mFont.StringWidth(text);
				vector2 textpos = ( (vWidth / 2) - (mFont.StringWidth(text) / 2), y);

				if (item.Selectable() && mDesc.mItems.Find(item) == mDesc.mSelectedItem)
				{
					for (int i = itemHighlights.Size() - 1; i >= 0; i--)
					{
						let hlight = itemHighlights[i];
						if (!hlight) continue;

						Screen.DrawText(
							mFont, 
							mDesc.mFontColor,
							textpos.x + hlight.pos.x, textpos.y + hlight.pos.y, 
							text,
							DTA_ScaleX, hlight.scale.x, DTA_ScaleY, hlight.scale.y,
							DTA_Alpha, hlight.alpha,
							DTA_LegacyRenderstyle, STYLE_TranslucentStencil,
							DTA_FillColor, 0xffffff,
							DTA_VirtualWidthF, vWidth,
							DTA_VirtualHeightF, vHeight,
							DTA_FullscreenScale, FSMode_ScaleToFit43
						);
		
						hlight.alpha -= 0.006 * deltaTime;
						if (hlight.alpha <= 0.0)
						{
							hlight.Destroy();
						}
					}
				}
				
				// Draw the skill text:
				Screen.DrawText(
					mFont, 
					mDesc.mSelectedItem == i ? item.mColorSelected : mDesc.mFontColor,
					textpos.x, textpos.y, 
					text,
					DTA_VirtualWidthF, vWidth,
					DTA_VirtualHeightF, vHeight,
					DTA_FullscreenScale, FSMode_ScaleToFit43
				);

				y += mDesc.mLinespacing;
			}
		}
	}
}

mixin class ToM_DeltaTime
{
	private transient double prevMSTime;
	private transient double deltaTime;

	void UpdateDeltaTime()
	{
		if (!prevMSTime)
			prevMSTime = MSTimeF();

		double ftime = MSTimeF() - prevMSTime;
		prevMSTime = MSTimeF();
		double dtime = 1000.0 / TICRATE;
		deltaTime = (ftime / dtime);
	}
}

class ListMenuItemToM_TextItem : ListMenuItemTextItem
{
	mixin ToM_DeltaTime;
	array<ToM_TextItemHighlight> itemHighlights;
	ListMenuDescriptor mDesc; // why don't elements already have a pointer to their menu or its descriptor??

	// Basically, extended DrawText() from ListMenu, that accepts scale,
	// alpha and color:
	void DrawTextHighlight(ListMenuDescriptor desc, Font fnt, int color, double x, double y, String text, bool ontop = false, Vector2 scale = (1,1), double alpha = 1.0, Color fillcolor = 0)
	{
		int w = desc ? desc.DisplayWidth() : ListMenuDescriptor.CleanScale;
		int h = desc ? desc.DisplayHeight() : -1;
		if (w == ListMenuDescriptor.CleanScale)
		{
			screen.DrawText(fnt, color, x, y, text, ontop? DTA_CleanTop : DTA_Clean, true,
				DTA_ScaleX, scale.x, DTA_ScaleY, scale.y,
				DTA_Alpha, alpha,
				DTA_LegacyRenderstyle, STYLE_TranslucentStencil,
				DTA_FillColor, fillcolor);
		}
		else
		{
			screen.DrawText(fnt, color, x, y, text,
				DTA_VirtualWidth, w, DTA_VirtualHeight, h,
				DTA_FullscreenScale, FSMode_ScaleToFit43,
				DTA_ScaleX, scale.x, DTA_ScaleY, scale.y,
				DTA_Alpha, alpha,
				DTA_FillColor, fillcolor);
		}
	}

	override void Ticker()
	{
		Super.Ticker();
		if (mDesc)
		{
			if (mDesc.mSelectedItem < 0)
			{
				itemHighlights.Clear();
			}
			else if (Menu.MenuTime() % 4 == 0)
			{
				Vector2 pos = (0, 0);
				Vector2 scale = (1, frandom[menusfx](1,1.5));
				pos.y -= mDesc.mLinespacing * (scale.y - 1) * 0.5;
				double alpha = frandom[menusfx](0.15, 0.25);
				itemHighlights.Push(ToM_TextItemHighlight.Create(pos, scale, alpha));
			}
		}
	}

	override void Draw(bool selected, ListMenuDescriptor desc)
	{
		UpdateDeltaTime();
		self.mDesc = desc;
		let font = menuDelegate.PickFont(mFont);
		if (selected)
		{
			for (int i = itemHighlights.Size() - 1; i >= 0; i--)
			{
				let hlight = itemHighlights[i];
				if (!hlight) continue;

				DrawTextHighlight(desc, font, mColor, mXpos + hlight.pos.x, mYpos + hlight.pos.y, mText, scale: hlight.scale, alpha: hlight.alpha, fillcolor: 0xffffff);

				hlight.alpha -= 0.006 * deltaTime;
				if (hlight.alpha <= 0.0)
				{
					hlight.Destroy();
				}
			}
		}
		DrawText(desc, font, selected ? mColorSelected : mColor, mXpos, mYpos, mText);
	}
}

class ToM_TextItemHighlight ui
{
	Vector2 pos;
	Vector2 scale;
	double alpha;

	static ToM_TextItemHighlight Create(Vector2 pos, Vector2 scale, double alpha)
	{
		let item = new('ToM_TextItemHighlight');
		item.pos = pos;
		item.scale = scale;
		item.alpha = alpha;
		return item;
	}
}

// A mixin that is included into the background menu element
// and into TITLEMAP-specific event handler:
extend class ToM_UiHandler
{
	ui bool tom_menuInitalized;

	ui int tom_currentMenustate;
	ui name prevSelectedControl;
	ui Menu prevSelectedMenu;
	enum EMenuStates
	{
		MS_None,
		MS_MainMenu,
		MS_Options,
		MS_QuitMenu,
		MS_LoadSave,
	}

	ui TextureID tex_bg;
	ui TextureID tex_lightning;
	ui TextureID candleSmokeTex;
	ui TextureID candleWickTex;
	ui TextureID quitMenu_bg;
	ui Vector2 quitMenu_bg_size;
	ui TextureID optMenu_bg;
	ui Vector2 optMenu_bg_size;
	ui TextureID optMenu_mirrortex;
	ui TextureID optMenu_refTex;
	ui TextureID optMenu_refTex_lit;
	ui Vector2 optMenu_refSize;
	ui Canvas optMenu_refCanvas;

	ui int lightningDelay;
	ui int lightningPhase;
	ui double lightningAlpha;
	const LIGHT_FREQUENCY = 5;
	const LIGHT_MAXALPHA = 1.0;
	const LIGHT_FADETIME = TICRATE / 2;
	const LIGHT_FADESTEP = LIGHT_MAXALPHA / LIGHT_FADETIME;

	ui double lampFlickerAlpha;
	ui double lampFlickerAlphaTics;
	ui LinearValueInterpolator lampFlickerInterpolator;
	ui TextureID lampFlickerTex;

	ui double candleLightAlpha;
	ui double candleLightAlphaStep;
	ui double candleLightAlphaDir;
	ui double candleLightAlphaTarget;

	ui array < ToM_MenuCandleSmokeController > smokeElements;
	ui int smokeJitterTics;
	ui int smokeJitterDuration;

	ui Actor alicePlayerDoll;
	transient String buildinfo;

	override void OnRegister()
	{
		let lump = Wads.FindLump("atombuild.txt");
		if (lump >= 0)
		{
			buildinfo = String.Format("Alice: Toys of Madness build %s", Wads.ReadLump(lump));
		}
	}

	ui void MMD_Init()
	{
		if (tom_menuInitalized) return;

		// quit menu background:
		quitMenu_bg = TexMan.CheckForTexture("graphics/menu/quitmenu_background.png");
		[quitMenu_bg_size.x, quitMenu_bg_size.y] = TexMan.GetSize(quitMenu_bg);
		// option menu background:
		optMenu_bg = TexMan.CheckForTexture("graphics/menu/optionmenu_background.png");
		[optMenu_bg_size.x, optMenu_bg_size.y] = TexMan.GetSize(optMenu_bg);
		// option menu mirror textures and cavas:
		optMenu_mirrortex = TexMan.CheckForTexture("AlicePlayer.menuMirror");
		optMenu_refTex = TexMan.CheckForTexture("Graphics/Menu/optionmenu_reflection.png");
		[optMenu_refSize.x, optMenu_refSize.y] = TexMan.GetSize(optMenu_refTex);
		optMenu_refTex_lit = TexMan.CheckForTexture("Graphics/Menu/optionmenu_reflection_lightning.png");
		optMenu_refCanvas = TexMan.GetCanvas("AlicePlayer.menuMirrorReflection");
		// option menu lamp flickering
		lampFlickerTex = TexMan.CheckForTexture("graphics/menu/optionmenu_background_light.png");
		// main menu backgrounds - regular background and another version of it,
		// lit up by lighting:
		tex_bg = TexMan.CheckForTexture("graphics/menu/menu_background.png");
		tex_lightning = TexMan.CheckForTexture("graphics/menu/menu_background_lit.png");
		// main menu - candle smoke elements' texture:
		candleSmokeTex = TexMan.CheckForTexture("SMO2C0");
		candleWickTex = TexMan.CheckForTexture("graphics/menu/menu_background_candlelight.png");
		// main menu - values:
		lightningDelay = TICRATE*4;
		candleLightAlphaTarget = frandom[tomMenu](0.4, 0.6);
		candleLightAlphaDir = -1;
		candleLightAlpha = 1.0;

		tom_menuInitalized = true;
	}

	ui void MMD_Draw()
	{
		MMD_Init();

		// First, determine which menu we're in.
		Menu mnu = Menu.GetCurrentMenu();
		MessageBoxMenu quitmnu = MessageBoxMenu(mnu);
		if (!mnu)
		{
			if (gamestate == GS_TITLELEVEL)
			{
				tom_currentMenustate = MS_MainMenu;
				// If we just opened the game and are in the title level,
				// open the main menu (because it doesn't open automatically):
				if (!mainMenuOpened)
				{
					Menu.SetMenu("MainMenu");
					mainMenuOpened = true;
				}
			}
			else
			{
				tom_currentMenustate = MS_None;
			}
		}
		// Quit menu:
		// (yes, the only way to determine it's a quit menu
		// is to check its mMessage, since aside from that
		// it's just a generic MessageBoxMenu):
		else if (quitmnu && quitmnu.mMessage && quitmnu.mMessage.StringAt(0) == StringTable.Localize("$TOM_MENU_QUITMESSAGE"))
		{
			tom_currentMenustate = MS_QuitMenu;
		}
		// Options - which is either OptionMenu (the main options menu), or
		// EnterKey (a control key rebind interface), or MesageBoxMenu
		// (one of the many confirmation message boxes):
		else if (mnu is 'OptionMenu' || mnu is 'EnterKey' || mnu is 'MessageBoxMenu')
		{
			tom_currentMenustate = MS_Options;
		}
		else if (mnu is 'ListMenu')
		{
			tom_currentMenustate = MS_MainMenu;
		}

		// Show player doll in options menu, otherwise hide it:
		if (tom_currentMenustate == MS_Options)
		{
			if (alicePlayerDoll && alicePlayerDoll.renderRequired < 0)
			{
				EventHandler.SendNetworkEvent("ShowPlayerDoll");
			}
		}
		else
		{
			if (alicePlayerDoll && alicePlayerDoll.renderRequired >= 0)
			{
				EventHandler.SendNetworkEvent("HidePlayerDoll");
			}
			// Do nothing else if no menu conditions are met:
			if (tom_currentMenustate == MS_None)
			{
				return;
			}
		}
		
		// debug notification when we open a new menu:
		if (mnu != prevSelectedMenu && tom_debugmessages > 0)
		{
			prevSelectedMenu = mnu;
			String title;
			let omnu = OptionMenu(mnu);
			if (omnu && omnu.mDesc)
			{
				title = " - \cy"..omnu.mDesc.mTitle;
			}
			ToM_DebugMessage.Print(String.Format("Entered menu: \cd%s\c-%s", mnu.GetClassName(), title));
		}

		vector2 screenRes = (Screen.GetWidth(), screen.GetHeight());
		// Quit menu:
		if (tom_currentMenustate == MS_QuitMenu)
		{
			Screen.Dim(0x000000, 1, 0, 0, int(screenRes.x), int(screenRes.y));
			// I want to delete the "press Y to quit" line, because
			// it doesn't look nice and everyone knows anyway.
			// Since that line is a second line in the message, I
			// check for the current number of lines. If more than one,
			// do some initial setup:
			if (quitmnu.mMessage.Count() > 1)
			{
				// I have to redefine the BrokenLines pointer in order to
				// make sure it only contains one string (my quit message):
				quitmnu.mMessage = quitmnu.textfont.BreakLines(StringTable.Localize("$TOM_MENU_QUITMESSAGE"), 600);
				// redefine selector (because it forcibly uses smallfont
				// by default):
				quitmnu.arrowfont = smallfont;
				quitmnu.selector = "{"; //Baldur Nuveau uses a pointing hand for this character
				quitmnu.destheight /= 2;
				quitmnu.destwidth /= 2;
			}
			Screen.DrawTexture(quitMenu_bg,
				false,
				0, 0,
				DTA_VirtualWidthF, quitMenu_bg_size.X,
				DTA_VirtualHeightF, quitMenu_bg_size.Y,
				DTA_FullScreenScale, FSMode_ScaleToFit43);
		}

		// Options menu:
		else if (tom_currentMenustate == MS_Options)
		{
			Screen.Dim(0x000000, 1, 0, 0, int(screenRes.x), int(screenRes.y));
			// We're in Customize Controls menu and currently hovering over a control bind element:
			OptionMenuItemControlBase controlItem;
			if (mnu is 'OptionMenu')
			{
				let desc = OptionMenu(mnu).mDesc;
				if (desc && desc.mSelectedItem >= 0)
				{
					controlItem = OptionMenuItemControlBase(desc.mItems[desc.mSelectedItem]);
				}
			}
			// We've just clicked on a control element to change its bind
			// (yes, it's a different menu, despite being drawn on top
			// of the previous one):
			else if (mnu is 'EnterKey')
			{
				controlItem = EnterKey(mnu).mOwner;
			}
			// This is a newly-hovered control item:
			if (controlitem)
			{
				if (controlItem.GetAction() != prevSelectedControl)
				{
					prevSelectedControl = controlItem.GetAction();
					EventHandler.SendNetworkEvent(String.Format("StartAliceDollAnimation|%s", prevSelectedControl));
					ToM_DebugMessage.Print(String.Format("Hovered control: \cd%s\c-", prevSelectedControl));
				}
			}
			else
			{
				prevSelectedControl = 'none';
				EventHandler.SendNetworkEvent("ResetAliceDollAnimation");
			}

			// The camera texture showing Alice:
			Screen.DrawTexture(optMenu_mirrortex,
				false,
				// Virtual resolution same as the background.
				// Other values are fixed, hand-picked to match
				// so the camera texture is exactly behind the
				// mirror in the background:
				optMenu_bg_size.X / 2 + 45, 74,
				DTA_VirtualWidthF, optMenu_bg_size.X,
				DTA_VirtualHeightF, optMenu_bg_size.Y,
				DTA_DestWidth, 230,
				DTA_DestHeightF, 378,
				DTA_FullScreenScale, FSMode_ScaleToFit43);

			// Now the foreground with a mirror (the mirror area is translucent):
			Screen.DrawTexture(optMenu_bg,
				false,
				0, 0,
				DTA_VirtualWidthF, optMenu_bg_size.X,
				DTA_VirtualHeightF, optMenu_bg_size.Y,
				DTA_FullScreenScale, FSMode_ScaleToFit43);

			// Now the flickering of the light bulb:
			if (lampFlickerInterpolator)
			{
				Screen.DrawTexture(lampFlickerTex,
					false,
					0, 0,
					DTA_VirtualWidthF, optMenu_bg_size.X,
					DTA_VirtualHeightF, optMenu_bg_size.Y,
					DTA_Alpha, lampFlickerInterpolator.GetValue() * 0.01,
					DTA_FullScreenScale, FSMode_ScaleToFit43);
			}
			
			// Now process the canvas for the background plane behind Alice
			// (the background itself is an actor with a flat plane model
			// placed behind her):
			optMenu_refCanvas.Clear(0, 0, optMenu_refSize.x, optMenu_refSize.y, 0xff000000);
			optMenu_refCanvas.DrawTexture(optMenu_refTex, false,
				0, 0,
				DTA_FlipY, true,
				DTA_DestWidthF, optMenu_refSize.x,
				DTA_DestHeightF, optMenu_refSize.y);
			// lit up by lightning, just like the main menu:
			optMenu_refCanvas.DrawTexture(optMenu_refTex_lit,false,
				0, 0,
				DTA_FlipY, true,
				DTA_DestWidthF, optMenu_refSize.x,
				DTA_DestHeightF, optMenu_refSize.y,
				DTA_Alpha, lightningAlpha);
			
			PrintBuildInfo();
		}

		// Otherwise, if it's a list menu, OR we're in a title level,
		// draw the main menu background:
		else if (tom_currentMenustate == MS_MainMenu)
		{
			Screen.Dim(0x000000, 1, 0, 0, int(screenRes.x), int(screenRes.y));
			vector2 size;
			[size.x, size.y] = TexMan.GetSize(tex_bg);

			// The base background is always drawn:
			Screen.DrawTexture(tex_bg, false,
				0, 0,
				DTA_VirtualWidthF, size.X,
				DTA_VirtualHeightF, size.Y,
				DTA_FullscreenScale, FSMode_ScaleToFit43
			);

			// The lit background is drawn on top whenever
			// lightning triggers, and gradually fades out:
			Screen.DrawTexture(tex_lightning, false,
				0, 0,
				DTA_VirtualWidthF, size.X,
				DTA_VirtualHeightF, size.Y,
				DTA_Alpha, lightningAlpha,
				DTA_FullscreenScale, FSMode_ScaleToFit43
			);

			// Draw smoke elements rising above the candle:
			vector2 smokePos = (-60, 46);
			for (int i = 0; i < smokeElements.Size(); i++)
			{
				let csc = smokeElements[i];
				if (!csc)
					continue;
				Screen.DrawTexture(candleSmokeTex, false,
					size.X / 2 + (smokePos.x + csc.pos.x),
					size.Y / 2 + (smokePos.y + csc.pos.y),
					DTA_VirtualWidthF, size.X,
					DTA_VirtualHeightF, size.Y,
					DTA_ScaleX, csc.scale,
					DTA_ScaleY, csc.scale,
					DTA_Alpha, csc.alpha,
					DTA_FullscreenScale, FSMode_ScaleToFit43
				);
			}

			// Draw flickering light spot on top of
			// the candle's wick:
			Screen.DrawTexture(candleWickTex, false,
				0, 0,
				DTA_VirtualWidthF, size.X,
				DTA_VirtualHeightF, size.Y,
				DTA_Alpha, candleLightAlpha,
				DTA_FullscreenScale, FSMode_ScaleToFit43
			);
		}

		/*if (mnu is 'LoadSaveMenu')
		{
			let savemnu = LoadSaveMenu(mnu);
			TextureID tex = TexMan.CheckForTexture("graphics/menu/menu_loadsave.png");
			Screen.DrawTexture(tex, false,
				savemnu.savePicLeft - 45, savemnu.savePicTop - 35,
				DTA_DestWidth, savemnu.savePicWidth + 45 + 45,
				DTA_Destheight, savemnu.savePicHeight + 35 + 48);
			Screen.DrawTexture(tex, false,
				savemnu.commentLeft - 45, savemnu.commentTop - 35,
				DTA_DestWidth, savemnu.commentWidth + 45 + 45,
				DTA_Destheight, savemnu.commentHeight + 35 + 48);
			Screen.DrawTexture(tex, false,
				savemnu.listboxLeft - 45, savemnu.listboxTop - 35,
				DTA_DestWidth, savemnu.listboxWidth + 45 + 45,
				DTA_Destheight, savemnu.listboxHeight + 35 + 48);
		}*/

		if (tom_currentMenustate == MS_MainMenu || tom_currentMenustate == MS_Options)
		{
			PrintBuildInfo();
		}
	}

	ui void PrintBuildInfo()
	{
		Screen.DrawText(newConsoleFont, Font.CR_White,
			Screen.GetWidth() - newConsoleFont.StringWidth(buildinfo), Screen.GetHeight() - newConsoleFont.GetHeight() - 2,
			buildinfo,
			DTA_Alpha, 0.6
		);
	}

	ui void MMD_Tick()
	{
		MMD_Init();

		if (!alicePlayerDoll)
		{
			let handler = ToM_Mainhandler(EventHandler.Find('ToM_Mainhandler'));
			if (handler)
			{
				alicePlayerDoll = handler.alicePlayerDoll;
			}
		}

		// Animate the player doll:
		if (tom_currentMenustate == MS_Options)
		{
			// This will cause the doll to call Tick() if the menu pauses
			// the game. In addition it'll also change its lightlevel even
			// if the menu is non-pausing, to reflect the lightning in the
			// background:
			EventHandler.SendNetworkEvent("AnimatePlayerDoll", int(round(55 * lightningAlpha)), menuactive != Menu.OnNoPause && gamestate != GS_TITLELEVEL);

			// option menu light bulb flickering:
			if (--lampFlickerAlphaTics <= 0)
			{
				lampFlickerAlpha = random[tomMenu](0,255) <= 250? frandom[tomMenu](0.6, 0.9) : frandom[tomMenu](0.1, 0.3);
				lampFlickerAlphaTics = random[tomMenu](10, 60);
			}
			if (!lampFlickerInterpolator)
			{
				lampFlickerInterpolator = LinearValueInterpolator.Create(50, 1);
			}
			lampFlickerInterpolator.Update(lampFlickerAlpha * 100);
		}

		if (tom_currentMenustate == MS_MainMenu)
		{
			// create a new smoke element:
			if (smokeJitterTics <= 0 && random[smokeJitter](0, 255) >= 253)
			{
				smokeJitterDuration = random[smokeJitter](30, 60);
				smokeJitterTics = smokeJitterDuration;
			}
			int smokeSineTime = !smokeJitterTics? (TICRATE * 10) : (20);
			double smokeHorOfs = !smokeJitterTics? (0.85) : (3.0 * sin(180.0 * (smokeJitterTics / double(smokeJitterDuration)))); //weaker fluctuations closer to the beginning and end of flicker sequence
			let csc = ToM_MenuCandleSmokeController.Create(
				//pos X and Y:
				(frandom[tomMenu](-0.5,0.5), frandom[tomMenu](-0.5,0.5)), 
				//pos step X and Y:
				(smokeHorOfs * sin(360.0 * Menu.MenuTime() / smokeSineTime), -0.5),
				// scale
				frandom[tomMenu](0.03, 0.06), -0.003,
				// alpha
				frandom[tomMenu](0.025, 0.05), -0.003,
				//rotation
				frandom[tomMenu](0, 360), frandom[tomMenu](-1, -4)
			);
			if (csc)
			{
				smokeElements.Push(csc);
				//smoketime += 1;
			}
			if (smokeJitterTics) smokeJitterTics--;

			// Tick smoke elements:
			for (int i = smokeElements.Size() -1; i >= 0; i--)
			{
				let csc = smokeElements[i];
				if (!csc)
				{
					smokeElements.Delete(i);
					continue;
				}
				csc.Ticker();
			}

			// candle light flickering:
			candleLightAlpha += candleLightAlphaStep * candleLightAlphaDir;
			if (candleLightAlpha <= candleLightAlphaTarget || candleLightAlpha >= 1.0)
			{
				candleLightAlphaDir *= -1;
				if (candleLightAlpha >= 1.0)
				{
					candleLightAlphaTarget = frandom[tomMenu](0.3, 0.8);
					candleLightAlphaStep = frandom[tomMenu](0.01, 0.005);
				}
			}
		}

		// lightning is handled in all menus, since its effects can be seen
		// both in main an in options menu:
		if (tom_currentMenustate != MS_None)
		{
			// count down lightning delay:
			if (lightningDelay > 0)
			{
				// after lightning countdown has ended, start
				// the lightning phase:
				if (--lightningDelay <= 0)
				{
					if (gamestate == GS_TITLELEVEL) //do not play with actual map in the background
					{
						S_StartSound("menu/thunder", CHAN_AUTO, flags:CHANF_UI|CHANF_LOCAL);
					}
					lightningPhase = LIGHT_FREQUENCY*random[tomMenu](4,6);
				}
			}
			
			// count down lightning phase:
			if (lightningPhase > 0)
			{
				lightningPhase--;
				if (lightningPhase % LIGHT_FREQUENCY == 0)
				{
					lightningAlpha = LIGHT_MAXALPHA;
				}
				else 
				{
					lightningAlpha = 0;
				}
				if (lightningPhase <= 0)
				{
					lightningAlpha = LIGHT_MAXALPHA;
					lightningDelay = TICRATE*random[tomMenu](3, 8);
				}
			}
			else if (lightningAlpha > 0.)
			{
				lightningAlpha -= LIGHT_FADESTEP;
			}
		}
	}
}

// This controls individual smoke elements
// for the handle shown on the main menu background:
class ToM_MenuCandleSmokeController ui
{
	int age;
	Vector2 pos;
	double scale;
	double alpha;
	double rotation;

	protected Vector2 pos_step;
	protected double scale_step;
	protected double alpha_step;
	protected double rotation_step;

	static ToM_MenuCandleSmokeController Create(vector2 pos, vector2 pos_step, double scale, double scale_step, double alpha, double alpha_step, double rotation, double rotation_step)
	{
		let csc = ToM_MenuCandleSmokeController(New("ToM_MenuCandleSmokeController"));
		if (csc)
		{
			csc.pos = pos;
			csc.scale = scale;
			csc.alpha = alpha;
			csc.rotation = rotation;
			
			csc.pos_step = pos_step;
			csc.rotation_step = rotation_step;
			// scale and alpha are additive:
			csc.scale_step = scale * scale_step;
			csc.alpha_step = alpha * alpha_step;
		}
		return csc;
	}

	void Ticker()
	{
		if (alpha < 0.)
		{
			Destroy();
			return;
		}

		age++;

		//pos.x = pos_step.x * sin(360.0 * age / (TICRATE*3));
		//pos_step.x *= 0.999;
		pos.x += pos_step.x;
		pos_step.x *= 0.82;

		pos.y += pos_step.y;
		pos_step.y *= 0.999;

		alpha += alpha_step;
		scale = Clamp(scale + scale_step, 0, 100);
		rotation += rotation_step;
	}
}