void SetupMaterial(inout Material matid)
{
	vec2 texCoord = vTexCoord.xy;
	texCoord.y = 1.0 - texCoord.y;
	vec4 camTexColor = texture(camTex, texCoord);
	matid.Base = camTexColor;
	matid.Bright = texture(brighttexture, texCoord);

#if defined(maskTex)
	// multiply alpha by external black and white texture
	vec4 mask = texture(maskTex, vTexCoord.xy);
	matid.Base.a = mask.r;
	matid.Base.a = clamp(matid.Base.a, 0., 1.);
#endif
}
