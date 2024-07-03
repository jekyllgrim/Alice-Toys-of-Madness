void SetupMaterial(inout Material matid)
{
    vec2 texCoord = vTexCoord.xy;
	vec2 flippedCoord = texCoord;
    flippedCoord.y = 1.0 - texCoord.y; //camera tex needs flipped coords
	
	vec4 camTexColor;

	#ifndef normalStrength
		#define normalStrength 0.1
	#endif
	#ifndef glowStrength
		#define glowStrength 0.5
	#endif

	// apply normal map if defined:
	#if defined(normalTex)
		vec4 nrm = texture(normalTex, texCoord);
		camTexColor = texture(camTex, flippedCoord + (nrm.xy * 2.0 - 1.0) * normalStrength);
	#else
		camTexColor = texture(camTex, flippedCoord);
	#endif
	

	float mask = 1.0;
	// multiply alpha by external black and white texture:
	#if defined(maskTex)
		mask = texture(maskTex, texCoord).r;
	#endif

	vec4 finalcol = camTexColor;

	#if defined(glowTex)
		vec4 glow = texture(glowTex, texCoord);
		finalcol = finalcol + (glow * glowStrength);
	#endif
	
	// draw topTex texture on top if defined:
	#if defined(topTex)
		vec4 topCol = texture(topTex, texCoord);
		matid.Base = mix(topCol, finalcol, mask);
	#else
		matid.Base = finalcol;
		matid.Base.a = mask;
	#endif

	matid.Base.a = clamp(matid.Base.a, 0.0, 1.0);
	matid.Bright = texture(brighttexture, texCoord);
}