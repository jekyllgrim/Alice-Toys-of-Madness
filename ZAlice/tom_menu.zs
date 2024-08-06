class ToM_SkillMenu : ListMenu 
{
	override void Drawer()
	{
		Screen.Dim(0x000000, 1.0, 0, 0, Screen.GetWidth(), Screen.GetHeight());

		int vHeight = mDesc.mVirtHeight;
		int vWidth = mDesc.mVirtWidth / 2; //center of the menu
		int y = vHeight / 4;
		let mFont = mDesc.mFont;

		for (int i = 0; i < mDesc.mItems.Size(); ++i)
		{
			let mItem = mDesc.mItems[i];
			if (!mItem)
				continue;
	
			// Draw the title at the top:
			let title = ListMenuItemStaticText(mItem);
			if (title)
			{
				string text = StringTable.Localize(title.mText);
				vector2 textpos = ( (vWidth / 2) - (mFont.StringWidth(text) / 2), y / 2);
				// draw the actual text:
				Screen.DrawText(
					mFont, 
					Font.CR_Untranslated,
					textpos.x, textpos.y, 
					text, 
					DTA_VirtualWidth, vWidth,
					DTA_VirtualHeight, vHeight,
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
				double textwidth = mFont.StringWidth(text);
				vector2 textpos = ( (vWidth / 2) - (mFont.StringWidth(text) / 2), y);
				
				// Draw the skill text:
				Screen.DrawText(
					mFont, 
					mDesc.mSelectedItem == i ? item.mColorSelected : mDesc.mFontColor,
					textpos.x, textpos.y, 
					text,
					DTA_VirtualWidth, vWidth,
					DTA_VirtualHeight, vHeight,
					DTA_FullscreenScale, FSMode_ScaleToFit43
				);

				y += mDesc.mLinespacing;
			}
		}
	}
}

class ListMenuItemToM_DrawMainMenuBackground : ListMenuItem 
{
	mixin ToM_MainMenuDrawer;

	void Init(ListMenuDescriptor desc, double x, double y)
	{
		Super.Init(x, y);
		MMD_Init();
	}

	override void Draw(bool selected, ListMenuDescriptor desc)
	{
		if (gamestate == GS_LEVEL)
		{
			MMD_Draw();
		}
	}

	override void Ticker()
	{
		super.Ticker();
		if (gamestate == GS_LEVEL)
		{
			MMD_Tick();
		}
	}
}

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

class ToM_MenuBackGroundHandler : EventHandler
{
	mixin ToM_MainMenuDrawer;

	override void UiTick()
	{
		if (!started)
			MMD_Init();
		else
			MMD_Tick();
		
		/*let mnu = OptionMenu(Menu.GetCurrentMenu());
		if (mnu)
		{
			console.printf("options menu open (%d)", mnu.MenuTime());
		}*/
	}

	override void RenderOverlay(RenderEvent e)
	{
		MMD_Draw();
	}
}


mixin class ToM_MainMenuDrawer
{
	ui bool started;
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

	ui array < ToM_MenuCandleSmokeController > smokeElements;

	ui void MMD_Init()
	{
		lightningDelay = TICRATE*4;
		candleLightAlphaTarget = frandom[tomMenu](0.4, 0.6);
		candleLightAlphaDir = -1;
		candleLightAlpha = 1.0;
		started = true;
	}

	ui void MMD_Draw()
	{
		if (!tex_bg)
			tex_bg = TexMan.CheckForTexture("graphics/menu/menu_background.png");
		if (!tex_lightning)
			tex_lightning = TexMan.CheckForTexture("graphics/menu/menu_background_lit.png");

		vector2 size;
		[size.x, size.y] = TexMan.GetSize(tex_bg);

		vector2 baseRes = (ToM_StatusBarScreen.statscr_base_width, ToM_StatusBarScreen.statscr_base_height);
		vector2 screenRes = (Screen.GetWidth(), screen.GetHeight());
		vector2 scale = (screenRes.x / size.x, screenRes.y / size.y);

		Screen.Dim("000000", 1, 0, 0, int(screenRes.x), int(screenRes.y));

		
		Screen.DrawTexture(tex_bg, false,
			0, 0,
			DTA_VirtualWidthF, size.X,
			DTA_VirtualheightF, size.Y,
			DTA_FullscreenScale, FSMode_ScaleToFit43
		);

		Screen.DrawTexture(tex_lightning, false,
			0, 0,
			DTA_VirtualWidthF, size.X,
			DTA_VirtualheightF, size.Y,
			DTA_Alpha, lightAlpha,
			DTA_FullscreenScale, FSMode_ScaleToFit43
		);

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

	//ui double smoketime;
	ui void MMD_Tick()
	{
		// smoke:
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