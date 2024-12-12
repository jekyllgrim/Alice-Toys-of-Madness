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
		if (mDesc && mDesc.mSelectedItem >= 0 && level.totaltime % 4 == 0)
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
			else if (level.totaltime % 4 == 0)
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
	ui bool mainMenuBackgroundStarted;
	ui TextureID tex_bg;
	ui TextureID tex_lightning;
	ui TextureID smokeTex;
	ui TextureID candleLighTex;

	ui int lightningDelay;
	ui int lightningPhase;
	ui double lightAlpha;
	const LIGHT_FREQUENCY = 5;
	const LIGHT_MAXALPHA = 1.0;
	const LIGHT_FADETIME = TICRATE / 2;
	const LIGHT_FADESTEP = LIGHT_MAXALPHA / LIGHT_FADETIME;

	ui double candleLightAlpha;
	ui double candleLightAlphaStep;
	ui double candleLightAlphaDir;
	ui double candleLightAlphaTarget;

	ui name prevSelectedControl;

	ui array < ToM_MenuCandleSmokeController > smokeElements;

	ui void MMD_Init()
	{
		lightningDelay = TICRATE*4;
		candleLightAlphaTarget = frandom[tomMenu](0.4, 0.6);
		candleLightAlphaDir = -1;
		candleLightAlpha = 1.0;
		mainMenuBackgroundStarted = true;
	}

	ui void MMD_Draw()
	{
		let mnu = Menu.GetCurrentMenu();
		// Draw the background at all times in a titlemap.
		// In non-titlemap, we will not draw it if there's
		// no menu (obviously):
		if (!mnu && gamestate != GS_TITLELEVEL) return;

		vector2 screenRes = (Screen.GetWidth(), screen.GetHeight());
		// Is this a quit menu?
		let quitmnu = MessageBoxMenu(mnu);
		// Yep, the only way to detect it's a quit message
		// is to literally compare its string to the quit
		// message string. Because otherwise it's a regular
		// MessageBoxMenu!
		if (quitmnu && quitmnu.mMessage && quitmnu.mMessage.StringAt(0) == StringTable.Localize("$TOM_MENU_QUITMESSAGE"))
		{
			Screen.Dim("000000", 1, 0, 0, int(screenRes.x), int(screenRes.y));
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
			TextureID texOpt = TexMan.CheckForTexture("graphics/menu/quitmenu_background.png");
			Vector2 size;
			[size.x, size.y] = TexMan.GetSize(texOpt);

			Screen.DrawTexture(texOpt,
				false,
				0, 0,
				DTA_VirtualWidthF, size.X,
				DTA_VirtualheightF, size.Y,
				DTA_FullScreenScale, FSMode_ScaleToFit43);
		}

		// Are we in titlemap and is this an option menu?
		else if (mnu is 'OptionMenu' || mnu is 'EnterKey')
		{
			Screen.Dim("000000", 1, 0, 0, int(screenRes.x), int(screenRes.y));
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
			else
			{
				controlItem = EnterKey(mnu).mOwner;
			}
			if (controlitem)
			{
				if (controlItem.GetAction() != prevSelectedControl)
				{
					prevSelectedControl = controlItem.GetAction();
					EventHandler.SendNetworkEvent(String.Format("StartAliceDollAnimation|%s", prevSelectedControl));
				}
			}
			else
			{
				prevSelectedControl = 'none';
				EventHandler.SendNetworkEvent("ResetAliceDollAnimation");
			}

			// The camera texture showing Alice:
			TextureID mirrorTex = TexMan.CheckForTexture("AlicePlayer.menuMirror");
			Vector2 camSize;
			[camSize.x, camSize.y] = TexMan.GetSize(mirrorTex);
			Screen.DrawTexture(mirrorTex,
				false,
				0, 0,
				DTA_VirtualWidthF, camSize.X,
				DTA_VirtualheightF, camSize.Y,
				DTA_FullScreenScale, FSMode_ScaleToFit43);

			// Now the foreground with a mirror:
			TextureID texOpt = TexMan.CheckForTexture("graphics/menu/optionmenu_background.png");
			Vector2 size;
			[size.x, size.y] = TexMan.GetSize(texOpt);
			Screen.DrawTexture(texOpt,
				false,
				0, 0,
				DTA_VirtualWidthF, size.X,
				DTA_VirtualheightF, size.Y,
				DTA_FullScreenScale, FSMode_ScaleToFit43);
			
			// Now process the canvas for the reflection behind Alice
			// (the reflection itself is an actor with a model spawned
			// behind her model):
			Canvas refCanvas = TexMan.GetCanvas("AlicePlayer.menuMirrorReflection");
			TextureID refTex = TexMan.CheckForTexture("Graphics/Menu/optionmenu_reflection.png");
			Vector2 rSize;
			[rSize.x, rSize.y] = TexMan.GetSize(refTex);
			refCanvas.Clear(0, 0, rSize.x, rSize.y, 0xff000000);
			refCanvas.DrawTexture(refTex, false,
				0, 0,
				DTA_FlipY, true,
				DTA_DestWidthF, rSize.x,
				DTA_DestHeightF, rSize.y);
			refCanvas.DrawTexture(TexMan.CheckForTexture("Graphics/Menu/optionmenu_reflection_lightning.png"),false,
				0, 0,
				DTA_FlipY, true,
				DTA_DestWidthF, rSize.x,
				DTA_DestHeightF, rSize.y,
				DTA_Alpha, lightAlpha);
		}

		// Otherwise, if it's a list menu, OR we're in a title level,
		// draw the main menu background:
		else if (gamestate == GS_TITLELEVEL || (mnu && mnu is 'ListMenu'))
		{
			Screen.Dim("000000", 1, 0, 0, int(screenRes.x), int(screenRes.y));
			// Textures for regular background, and another version of it
			// lit by a lightning strike, with different shadows and visible
			// window outlines:
			if (!tex_bg)
				tex_bg = TexMan.CheckForTexture("graphics/menu/menu_background.png");
			if (!tex_lightning)
				tex_lightning = TexMan.CheckForTexture("graphics/menu/menu_background_lit.png");

			vector2 size;
			[size.x, size.y] = TexMan.GetSize(tex_bg);

			vector2 scale = (screenRes.x / size.x, screenRes.y / size.y);

			// The base background is always drawn:
			Screen.DrawTexture(tex_bg, false,
				0, 0,
				DTA_VirtualWidthF, size.X,
				DTA_VirtualheightF, size.Y,
				DTA_FullscreenScale, FSMode_ScaleToFit43
			);

			// The lit background is drawn on top whenever
			// lightning triggers, and gradually fades out:
			Screen.DrawTexture(tex_lightning, false,
				0, 0,
				DTA_VirtualWidthF, size.X,
				DTA_VirtualheightF, size.Y,
				DTA_Alpha, lightAlpha,
				DTA_FullscreenScale, FSMode_ScaleToFit43
			);

			// Draw smoke elements rising above the candle:
			if (!smokeTex)
				smokeTex = TexMan.CheckForTexture("SMO2C0");
			vector2 smokePos = (-60, 46);
			for (int i = 0; i < smokeElements.Size(); i++)
			{
				let csc = smokeElements[i];
				if (!csc)
					continue;
				Screen.DrawTexture(smokeTex, false,
					size.X / 2 + (smokePos.x + csc.ofs.x),// * scale.x, 
					size.Y / 2 + (smokePos.y + csc.ofs.y),// * scale.y,
					DTA_VirtualWidthF, size.X,
					DTA_VirtualheightF, size.Y,
					DTA_ScaleX, csc.scale,
					DTA_ScaleY, csc.scale,
					DTA_Alpha, csc.alpha,
					DTA_FullscreenScale, FSMode_ScaleToFit43
				);
			}

			// Draw flickering light spot on top of
			// the candle's wick:
			if (!candleLighTex)
				candleLighTex = TexMan.CheckForTexture("graphics/menu/menu_background_candlelight.png");
			Screen.DrawTexture(candleLighTex, false,
				0, 0,
				DTA_VirtualWidthF, size.X,
				DTA_VirtualheightF, size.Y,
				DTA_Alpha, candleLightAlpha,
				DTA_FullscreenScale, FSMode_ScaleToFit43
			);
		}
	}

	ui void MMD_Tick()
	{
		let mnu = Menu.GetCurrentMenu();
		if (mnu && menuactive != Menu.OnNoPause && gamestate != GS_TITLELEVEL)
		{
			EventHandler.SendNetworkEvent("AnimatePlayerDoll");
		}
		// create a new smoke element:
		let csc = ToM_MenuCandleSmokeController.Create(
			//pos 
			(frandom[tomMenu](-2.5,2.5), frandom[tomMenu](-2,2)), 
			//ofs each step
			(frandom[tomMenu](-0.2,0.2), frandom[tomMenu](-0.4, -0.5)),
			// scale
			frandom[tomMenu](0.04, 0.08), -0.002,
			// alpha
			frandom[tomMenu](0.025, 0.1), -0.006,
			//rotation
			frandom[tomMenu](0, 360), frandom[tomMenu](-1, -4),
			//return steps
			random[tomMenu](30, 90)
		);
		if (csc)
		{
			smokeElements.Push(csc);
			//smoketime += 1;
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

		// count down lightning delay:
		if (lightningDelay > 0)
		{
			lightningDelay--;
			// after lightning countdown has ended, start
			// the lightning phase:
			if (lightningDelay <= 0)
			{
				lightningPhase = LIGHT_FREQUENCY*random[tomMenu](4,6);
			}
		}
		
		// count down lightning phase:
		if (lightningPhase > 0)
		{
			lightningPhase--;
			if (lightningPhase % LIGHT_FREQUENCY == 0)
			{
				lightAlpha = LIGHT_MAXALPHA;
			}
			else 
			{
				lightAlpha = 0;
			}
			if (lightningPhase <= 0)
			{
				lightAlpha = LIGHT_MAXALPHA;
				lightningDelay = TICRATE*random[tomMenu](3, 8);
			}
		}
		else if (lightAlpha > 0.)
		{
			lightAlpha -= LIGHT_FADESTEP;
		}
	}
}

// This controls individual smoke elements
// for the handle shown on the main menu background:
class ToM_MenuCandleSmokeController ui
{
	int age;
	vector2 ofs;
	double scale;
	double alpha;
	double rotation;
	int returnsteps;

	protected vector2 ofs_step;
	protected double scale_step;
	protected double alpha_step;
	protected double rotation_step;

	static ToM_MenuCandleSmokeController Create(vector2 ofs, vector2 ofs_step, double scale, double scale_step, double alpha, double alpha_step, double rotation, double rotation_step, int returnsteps)
	{
		let csc = ToM_MenuCandleSmokeController(New("ToM_MenuCandleSmokeController"));
		if (csc)
		{
			csc.ofs = ofs;
			csc.scale = scale;
			csc.alpha = alpha;
			csc.rotation = rotation;
			csc.returnsteps = returnsteps;
			
			csc.ofs_step = ofs_step;
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
		// horizontal movement (removed):
		/*if (age >= returnsteps)
		{
			ofs.x *= 0.95;
		}
		else 
		{
			ofs.x += ofs_step.x;
		}*/
		ofs.y += ofs_step.y;
		ofs_step *= 0.999;

		alpha += alpha_step;
		scale = Clamp(scale + scale_step, 0, 100);
		rotation += rotation_step;
	}
}