Material mat;

void SetupMaterial(inout Material mat)
{
	vec2 texCoord = vTexCoord.st;
	mat.Base = getTexel(texCoord);
	vec4 addEnv = texture(tex_envmap, (normalize(uCameraPos.xyz - pixelpos.xyz).xy));
	mat.Base = (mat.Base*0.7) + (addEnv*0.3);
	mat.Bright = texture(brighttexture, texCoord);
}