// Material shader for the Rage Box model texture
// Draws the input material directly, then draws
// another texture below it and moves/scales it.
// Huge thanks to themistercat and Gutawer!

void SetupMaterial(inout Material matid)
{
	vec2 texCoord = vTexCoord.xy;
	// This is REQUIRED  to be able to utilize the actual input texture:
	SetMaterialProps(matid, texCoord);
	// Figure out scroll and scale for the bottom texture:
	vec2 botCoord = texCoord + timer*0.2;
	//vec2 curbotscale = texCoord * (0.5 + 0.5*sin(timer));
	//vec2 curbotscaleDelta = delta(curbotscale, 1.0 - curbotscale);
	//vec2 botCoord = curbotscale + curbotscaleDelta;
	// Bottom texture:
	vec4 botcol = texture(bottomTex, botCoord);
	// Get the input texture colors to draw them on top:
	vec4 topcol = matid.Base;
	// Get mask from the input texture's alpha channel:
	float mask = topcol.a + botcol.a * (1.0f - topcol.a);
	matid.Base = vec4((topcol.rgb * topcol.a + botcol.rgb * botcol.a * (1.0f - topcol.a)) / mask, mask);
	matid.Bright = texture(brighttexture, texCoord);
}