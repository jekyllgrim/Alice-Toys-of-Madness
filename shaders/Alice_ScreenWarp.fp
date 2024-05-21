const float Strength = 0.2;
void main()
{
    FragColor = texture(InputTexture, TexCoord + (texture(NormalTexture, TexCoord).xy * 2.0 - 1.0) * Strength);
}