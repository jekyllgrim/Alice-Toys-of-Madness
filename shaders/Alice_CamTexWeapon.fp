void SetupMaterial(inout Material matid)
{
    vec2 texCoord = vTexCoord.xy;
    texCoord.y = 1.0 - texCoord.y;
	
	vec4 camTexColor;
	float nrmStrength = 0.2;
	#if defined(normalStrength)
		nrmStrength = normalStrength;
	#endif
	// apply normal map if defined:
	#if defined(normalTex)
		vec4 nrm = texture(normalTex, vTexCoord.xy);
		camTexColor = texture(camTex, texCoord + (nrm.xy * 2.0 - 1.0) * nrmStrength);
	#else
		camTexColor = texture(camTex, texCoord);
	#endif
	
    matid.Base = camTexColor;
    matid.Bright = texture(brighttexture, texCoord);

	// multiply alpha by external black and white texture:
	#if defined(maskTex)
		vec4 mask = texture(maskTex, vTexCoord.xy);
		matid.Base.a = mask.r;
		matid.Base.a = clamp(matid.Base.a, 0., 1.);
	#endif
}