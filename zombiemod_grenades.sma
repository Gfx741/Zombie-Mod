#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>
#include <reapi>
#include <zombiemod_core>
#include <zombiemod_addon_freeze>
#include <effects_util>

#pragma semicolon 1

#define PLUGIN_NAME                  "[ZM] Item: Grenades"
#define PLUGIN_VERS                  "1.0.6"
#define PLUGIN_AUTH                  "CROCK"

#define IsPlayer(%0)				(%0 && %0 <= MaxClients)

#define _set_nadetype(%0, %1)		set_entvar(%0, var_iuser1, %1)
#define _get_nadetype(%0)			get_entvar(%0, var_iuser1)
#define _set_nademode(%0, %1)		set_entvar(%0, var_iuser2, %1)
#define _get_nademode(%0)			get_entvar(%0, var_iuser2)

#define JumpGrenadeUn				100
#define JumpGrenadeDamage			10.0
#define JumpGrenadeRadius			250.0
#define JumpGrenadePushPower		800.0
#define JumpGrenadeRadiusDamage		100.0

#define ConcGrenadeUn				101
#define ConcGrenadeRadius			300.0

#define FireGrenadeUn				102
#define FireGrenadeDamage			10.0
#define FireGrenadeRadius			250.0
#define FireGrenadeDuration			10.0

#define FrostGrenadeUn				103
#define FrostGrenadeRadius			250.0
#define FrostGrenadeDuration		10.0
#define FrostGrenadeBody			1

#define PumpkinGrenadeUn			104
#define PumpkinGrenadeBody			3

enum /*_:DataNadeMode*/
{
	ModeNormal,
	ModeImpact
};

enum /*_:DataGrenade*/
{
	HeGrenade,
	Flashbang,
	SmokeGrenade
};

new const WEAPON_REFERANCE[][] =
{
	"weapon_hegrenade",
	"weapon_flashbang",
	"weapon_smokegrenade"
};

new const MODE_NAME[][] =
{
	"Normal",
	"Impact"
};

new const JUMP_MODEL[] = "models/a4bd3_models/w_jumpbomb.mdl";
new const NADE_MODEL[] = "models/a4bd3_models/w_grenade1.mdl";
new const JUMP_SOUND[][] = {
	"a4bd3_s/weapons/jumpbomb_1.wav",
	"a4bd3_s/weapons/jumpbomb_2.wav",
	"a4bd3_s/weapons/jump_explo.wav"
};
new const PUMP_SOUND[][] = {
	"a4bd3_s/weapons/g_bounce1.wav",
	"a4bd3_s/weapons/g_bounce2.wav"
};
new const FIRE_SOUND[] = "a4bd3_s/weapons/fire_explo.wav";
new const FROST_SOUND[][] = {
	"a4bd3_s/weapons/frost_explo.wav",
	"a4bd3_s/weapons/frost_go.wav",
	"a4bd3_s/weapons/frost_break.wav"
};

new g_PlayerData[MAX_PLAYERS+1];
new g_iSprFollow, g_iSprCylinder;

public plugin_precache()
{
	g_iSprFollow = precache_model("sprites/laserbeam.spr");
	g_iSprCylinder = precache_model("sprites/shadow_circle.spr");
	
	precache_model(JUMP_MODEL);
	precache_model(NADE_MODEL);
	
	precache_sound(JUMP_SOUND[0]);
	precache_sound(JUMP_SOUND[1]);
	precache_sound(JUMP_SOUND[2]);
	precache_sound(PUMP_SOUND[0]);
	precache_sound(PUMP_SOUND[1]);
	precache_sound(FIRE_SOUND);
	precache_sound(FROST_SOUND[0]);
	precache_sound(FROST_SOUND[1]);
	precache_sound(FROST_SOUND[2]);
}

public plugin_init()
{
	register_plugin(PLUGIN_NAME, PLUGIN_VERS, PLUGIN_AUTH);
	
	for(new i = 0, size = sizeof(WEAPON_REFERANCE); i < size; i++)
	{
		RegisterHam(Ham_Item_AddToPlayer, WEAPON_REFERANCE[i], "@Ham_Item_AddToPlayer_Post", false);
	}
	
	register_forward(FM_CmdStart, "@FM_CmdStart_Pre", false);
	
	RegisterHookChain(RG_CBasePlayer_ThrowGrenade, "@CBasePlayer_ThrowGrenade_Post", true);
	
	RegisterHookChain(RG_CGrenade_ExplodeHeGrenade, "@CGrenade_ExplodeGrenade_Pre", false);
	RegisterHookChain(RG_CGrenade_ExplodeFlashbang, "@CGrenade_ExplodeGrenade_Pre", false);
	RegisterHookChain(RG_CGrenade_ExplodeSmokeGrenade, "@CGrenade_ExplodeGrenade_Pre", false);
	
	RegisterHam(Ham_Touch, "grenade", "@Ham_TouchGrenade_Pre", false);
	RegisterHam(Ham_Think, "grenade", "@Ham_ThinkGrenade_Pre", false);
	
	register_forward(FM_EmitSound, "@FM_EmitSound_Pre", false);
	
	register_clcmd("say /j", "@grenade_j");
	register_clcmd("say /c", "@grenade_c");
	register_clcmd("say /n", "@grenade_n");
	register_clcmd("say /fr", "@grenade_fr");
	register_clcmd("say /he", "@grenade_he");
}

@grenade_j(index)
{
	if(zm_is_zombie(index))
	{
		rg_give_custom_item(index, WEAPON_REFERANCE[HeGrenade], GT_APPEND, JumpGrenadeUn);
	}
}
@grenade_c(index)
{
	if(zm_is_zombie(index))
	{
		rg_give_custom_item(index, WEAPON_REFERANCE[Flashbang], GT_APPEND, ConcGrenadeUn);
	}
}
@grenade_n(index)
{
	if(!zm_is_zombie(index))
	{
		rg_give_custom_item(index, WEAPON_REFERANCE[SmokeGrenade], GT_APPEND, FireGrenadeUn);
	}
}
@grenade_fr(index)
{
	if(!zm_is_zombie(index))
	{
		rg_give_custom_item(index, WEAPON_REFERANCE[Flashbang], GT_APPEND, FrostGrenadeUn);
	}
}
@grenade_he(index)
{
	if(!zm_is_zombie(index))
	{
		rg_give_custom_item(index, WEAPON_REFERANCE[HeGrenade], GT_APPEND, PumpkinGrenadeUn);
	}
}

@FM_CmdStart_Pre(index, uc_handle, seed)
{
	if(!is_user_alive(index))
	{
		return FMRES_IGNORED;
	}
	
	new item = get_member(index, m_pActiveItem);
	switch(get_entvar(item, var_impulse))
	{
		case JumpGrenadeUn..PumpkinGrenadeUn:
		{
			static bool:key[MAX_PLAYERS + 1] = {false, ...};
			if(get_uc(uc_handle, UC_Buttons) & IN_ATTACK2)
			{
				if(!key[index])
				{
					switch(g_PlayerData[index])
					{
						case ModeNormal:
						{
							g_PlayerData[index] = ModeImpact;
						}
						case ModeImpact:
						{
							g_PlayerData[index] = ModeNormal;
						}
					}
					client_print(index, print_chat, "[NADE MODE] %s", MODE_NAME[g_PlayerData[index]]);
				}
				
				key[index] = true;
			}
			else
			{
				key[index] = false;
			}
		}
	}
	return FMRES_IGNORED;
}

@Ham_Item_AddToPlayer_Post(const item, const player)
{
	switch(get_entvar(item, var_impulse))
	{
		case JumpGrenadeUn:
		{
			/*
			SendWeaponList
			(
				player,
				"weapon_jumpbomb",
				get_member(item, m_Weapon_iPrimaryAmmoType),
				rg_get_iteminfo(item, ItemInfo_iMaxAmmo1),
				-1,
				-1,
				3,
				4,
				get_member(item, m_iId),,
				0
			);
			*/
		}
		case ConcGrenadeUn:
		{
		}
		case FireGrenadeUn:
		{
		}
		case FrostGrenadeUn:
		{
		}
		case PumpkinGrenadeUn:
		{
		}
	}
}

@CBasePlayer_ThrowGrenade_Post(const index)
{
	new ent = GetHookChainReturn(ATYPE_INTEGER);
	if(is_nullent(ent))
	{
		return HC_CONTINUE;
	}
	
	new item = get_member(index, m_pActiveItem);
	switch(get_entvar(item, var_impulse))
	{
		case JumpGrenadeUn: ChangeNadeAttrib(ent,		JumpGrenadeUn, 		g_PlayerData[index], 1,	0, 0,0,0, JUMP_MODEL);
		case ConcGrenadeUn: ChangeNadeAttrib(ent,		ConcGrenadeUn, 		g_PlayerData[index], 1,	0, 0,0,0, JUMP_MODEL);
		case FireGrenadeUn: ChangeNadeAttrib(ent,		FireGrenadeUn, 		g_PlayerData[index], 1,	0, 200, 50, 0, NADE_MODEL);
		case FrostGrenadeUn: ChangeNadeAttrib(ent,		FrostGrenadeUn, 	g_PlayerData[index], 1, FrostGrenadeBody, 0, 100, 200, NADE_MODEL);
		case PumpkinGrenadeUn: ChangeNadeAttrib(ent,	PumpkinGrenadeUn,	g_PlayerData[index], 0,	PumpkinGrenadeBody, 200, 200, 0, NADE_MODEL);
	}
	return HC_CONTINUE;
}

ChangeNadeAttrib(ent, nadetype, nademode, sequence, body, r, g , b, const model[])
{
	set_entvar(ent, var_iuser1,		nadetype);
	set_entvar(ent, var_iuser2,		nademode);
	
	if(sequence) {
		set_entvar(ent, var_sequence, sequence);
	}
	
	if(body) {
		set_entvar(ent, var_body, body);
	}
	
	engfunc(EngFunc_SetModel, ent, model);
	
	if(r || g || b)
	{
		_set_rendering(ent, kRenderFxGlowShell, r, g, b, kRenderNormal, 16);
		
		_te_beamfollow
		(
		.entindex=ent,
		.sprite=g_iSprFollow,
		.life=10,
		.width=5,
		.r=r,
		.g=g,
		.b=b,
		.a=200
		);
	}
}

@CGrenade_ExplodeGrenade_Pre(const ent)
{
	new owner = get_entvar(ent, var_owner);
	switch(_get_nadetype(ent))
	{
		case JumpGrenadeUn:jumpExplode(ent, owner);
		case ConcGrenadeUn: jumpExplode(ent, owner, true);
		case FireGrenadeUn: customExplode(ent, owner, .fire = true);
		case FrostGrenadeUn: customExplode(ent, owner, .fire = false);
		default: return HC_CONTINUE;
	}
	
	set_entvar(ent, var_flags, get_entvar(ent, var_flags) | FL_KILLME);
	return HC_SUPERCEDE;
}

bool:is_solid(ent)
{
	return ( ent ? ( (get_entvar(ent, var_solid) > SOLID_TRIGGER) ? true : false ) : true );
}

@Ham_TouchGrenade_Pre(ent, toucher)
{
	if(_get_nademode(ent) == ModeImpact)
	{
		if(is_solid(toucher))
		{
			set_entvar(ent, var_dmgtime, 0.0);
			set_entvar(ent, var_nextthink, get_gametime() + 0.001);
			
			if(_get_nadetype(ent) == FireGrenadeUn)
			{
				set_entvar(ent, var_flags, get_entvar(ent, var_flags) | FL_ONGROUND);
			}
		}
	}
	return HAM_IGNORED;
}

@Ham_ThinkGrenade_Pre(const ent)
{
	if(is_nullent(ent))
	{
		return HAM_IGNORED;
	}
	
	new owner = get_entvar(ent, var_owner);
	if(!IsPlayer(owner) || !is_user_alive(owner))
	{
		set_entvar(ent, var_flags, get_entvar(ent, var_flags) | FL_KILLME);
		return HAM_IGNORED;
	}
	
	if(get_entvar(ent, var_waterlevel) != 0)
	{/*
		if(get_entvar(ent, var_sequence) != 0)
		{
			set_entvar(ent, var_sequence, 0);
		}*/
		return HAM_IGNORED;
	}
	
	if(get_entvar(ent, var_dmgtime) > get_gametime())
	{
		set_entvar(ent, var_nextthink, get_gametime() + 0.1);
		return HAM_SUPERCEDE;
	}
	return HAM_IGNORED;
}

@FM_EmitSound_Pre(const ent, const channel, const sample[], const Float:volume, const Float:attn, const flags, const pitch)
{
	if(is_nullent(ent))
	{
		return HAM_IGNORED;
	}
	
	if(sample[14] == 'n' && sample[15] == 'c' && sample[16] == 'e')
	{
		switch(_get_nadetype(ent))
		{
			case JumpGrenadeUn: emit_sound(ent, channel, JUMP_SOUND[random_num(0, 1)], volume, attn, flags, pitch);
			case PumpkinGrenadeUn: emit_sound(ent, channel, PUMP_SOUND[random_num(0, 1)], volume, attn, flags, pitch);
			default: return FMRES_IGNORED;
		}
		return FMRES_SUPERCEDE;
	}
	return FMRES_IGNORED;
}

jumpExplode(ent, owner, bool:conc = false)
{
	enum dataGreande
	{
		grenade = 0,
		target
	};
	
	new Float:velocity[dataGreande][3], Float:pushPower, Float:radius;
	new Float:pos[dataGreande][3]; get_entvar(ent, var_origin, pos[grenade]);
	
	if(conc)
	{
		_te_beamcylinder
		(
			pos[grenade],
			.radius = ConcGrenadeRadius,
			.sprite = g_iSprCylinder,
			.startFrame = 0,
			.frameRate = 0, 
			.life = 4,
			.width = 60,
			.noise = 60,
			.r = 224,
			.g = 102,
			.b = 102,
			.a = 200,
			.scrollSpeed=0
		);
	}
	
	_te_particlebust(pos[grenade]);
	emit_sound(ent, CHAN_WEAPON, JUMP_SOUND[2], 1.0, ATTN_NORM, 0, PITCH_NORM);
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(!is_user_alive(i))
		{
			continue;
		}
		
		get_entvar(i, var_origin, pos[target]);
		radius = get_distance_f(pos[grenade], pos[target]);
		
		if(radius > JumpGrenadeRadius)
		{
			continue;
		}
		
		if(radius <= JumpGrenadeRadiusDamage)
		{
			if(!zm_is_zombie(i))
			{
				new Float:vangles[3]; get_entvar(i, var_v_angle, vangles);
				
				vangles[0] += random_float(-30.0, 30.0);
				vangles[1] += random_float(-30.0, 30.0);
				
				set_entvar(i, var_v_angle, vangles);
				set_entvar(i, var_angles, vangles);
				set_entvar(i, var_fixangle, 1);
				
				set_member(i, m_flVelocityModifier, 0.5);
				
				ExecuteHam(Ham_TakeDamage, i, ent, owner, JumpGrenadeDamage, 0);
				
				continue;
			}
			
			if(i == owner)
			{
				// set screenshake
			}
		}
		
		if(i != owner && zm_is_zombie(i))
		{
			continue;
		}
		
		if(conc)
		{
			// set shock
		}
		
		pushPower = JumpGrenadePushPower * (1.0 - (radius / JumpGrenadeRadius));
		
		xs_vec_sub(pos[target], pos[grenade], velocity[grenade]);
		xs_vec_normalize(velocity[grenade], velocity[grenade]);
		xs_vec_mul_scalar(velocity[grenade], pushPower, velocity[grenade]);
		
		get_entvar(i, var_velocity, velocity[target]);
		xs_vec_add(velocity[target], velocity[grenade], velocity[target]);
		
		set_entvar(i, var_velocity, velocity[target]);
	}
}

customExplode(ent, owner, bool:fire)
{
	enum dataGreande
	{
		grenade = 0,
		target
	};
	new Float:pos[dataGreande][3]; get_entvar(ent, var_origin, pos[grenade]);
	new Float:radius, color[3];
	
	if(fire)
	{
		color[0] = 200;
		color[1] = 50;
		color[2] = 0;
		
		radius = FireGrenadeRadius;
		emit_sound(ent, CHAN_WEAPON, FIRE_SOUND, 1.0, ATTN_NORM, 0, PITCH_NORM);
	}
	else
	{
		color[0] = 0;
		color[1] = 100;
		color[2] = 200;
		
		radius = FrostGrenadeRadius;
		emit_sound(ent, CHAN_WEAPON, FROST_SOUND[0], 1.0, ATTN_NORM, 0, PITCH_NORM);
	}
	
	_te_beamcylinder
	(
		pos[grenade],
		.radius = radius,
		.sprite = g_iSprCylinder,
		.startFrame = 0,
		.frameRate = 0, 
		.life = 4,
		.width = 60,
		.noise = 60,
		.r = color[0],
		.g = color[1],
		.b = color[2],
		.a = 200,
		.scrollSpeed=0
	);
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(!is_user_alive(i) || !zm_is_zombie(i))
		{
			continue;
		}
		
		get_entvar(i, var_origin, pos[target]);
		if(get_distance_f(pos[grenade], pos[target]) > radius)
		{
			continue;
		}
		
		if(fire)
		{
			ad_set_fire(.index =i, .duration=10, .damageTake=100);
		}
		else
		{
			emit_sound(i, CHAN_BODY, FROST_SOUND[1], 1.0, ATTN_NORM, 0, PITCH_NORM);
			
			ad_set_freeze(.index =i, .freezeTime=10.0, .gravity=1, .motion=1, .fire=0, .r=0, .g=100, .b=200);
		}
	}
}

stock SendWeaponList(index, const name[], ammo1, maxAmmo1, ammo2, maxAmmo2, slot, position, any:weaponId, flags)
{
	static msg;
	if(!msg)
	{
		msg = get_user_msgid("WeaponList");
	}
	
    message_begin(MSG_ONE, msg, _, index);
    write_string(name);
    write_byte(ammo1);
    write_byte(maxAmmo1);
    write_byte(ammo2);
    write_byte(maxAmmo2);
    write_byte(slot);
    write_byte(position);
    write_byte(weaponId);
    write_byte(flags);
    message_end();
}