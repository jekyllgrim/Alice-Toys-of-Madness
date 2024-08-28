enum ToMChannels
{
	CH_TPOTHEAT = 10,
	CH_TPOTCHARGE,
	CH_EYECHARGE,
}

enum ToM_ParticlesQuality
{
	TOMPART_MIN = 0,
	TOMPART_MED = 1,
	TOMPART_MAX = 2,
}

enum ToM_PSprite_Layers
{
	APSP_Legs 			= -999,
	APSP_KickDo 		= -501,
	APSP_Kick 			= -500,
	APSP_BottomParticle	= -300,
	APSP_UnderLayer 	= -10,
	APSP_LeftHand		= 3,
	APSP_Overlayer		= 5,
	APSP_CARD1			= 21,
	APSP_CARD2			= 22,
	APSP_CARD3			= 20,
	APSP_TopFX			= 50,
	APSP_TopParticle	= 300,
}

enum EParticleBeamStyle
{
	PBS_Solid			= 1 << 0,
	PBS_Fade			= 1 << 1,
	PBS_Shrink			= 1 << 2,
	PBS_Fullbright		= 1 << 3,
	PBS_Untextured		= 1 << 4,
	PBS_MoveToNext		= 1 << 5,
}

const ToM_MaxMoveInput = 12800;