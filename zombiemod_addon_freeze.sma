#include <amxmodx>
#include <fakemeta>
#include <engine>
#include <hamsandwich>
#include <reapi>
#include <zombiemod_core>
#include <zombiemod_class_zombie>
#include <zombiemod_class_human>
#include <effects_util>

#pragma semicolon 1

#define PLUGIN_NAME			"[ZM] Skill manager"
#define PLUGIN_VERS			"1.0.6"
#define PLUGIN_AUTH			"CROCK"

new const FLAME_CLASSNAME[] = "flame";
new const FLAME_MODEL[]	= "sprites/a4bd3_sprites/flameplayer.spr";

enum (+= 314)
{
	TASK_BURN = 122,
	TASK_FLAME
};

enum _:PlayerData
{
	Switch = 0,
	Float:CheckTime,
	Float:FreezeTime,
	Motion,
	Duration,
	BurnDamage
};

new g_PlayerData[MAX_PLAYERS+1][PlayerData];

new g_iSprSmoke;

public plugin_natives()
{
	register_library("zombiemod_addon_freeze");
	register_native("ad_set_freeze", "native_set_freeze");
	register_native("ad_get_freeze", "native_get_freeze");
	register_native("ad_set_fire", "native_set_fire");
	register_native("ad_get_fire", "native_get_fire");
}

public plugin_precache()
{
	g_iSprSmoke = precache_model("sprites/black_smoke3.spr");
	
	precache_model(FLAME_MODEL);
}

public plugin_init()
{
	register_plugin(PLUGIN_NAME, PLUGIN_VERS, PLUGIN_AUTH);
	
	RegisterHam(Ham_Item_PreFrame, "player", "Ham_Item_PreFrame_Post", true);
	RegisterHookChain(RG_CBasePlayer_Killed, "RG_CBasePlayer_Killed_Post", true);
	RegisterHookChain(RG_CBasePlayer_PreThink, "RG_CBasePlayer_PreThink_Pre", false);
	
	register_think(FLAME_CLASSNAME, "Engine_ThinkFlamePlayer");
}

public client_dissconnected(index)
{
	remove_task(TASK_FLAME + index);
	remove_task(TASK_BURN + index);
}

public zm_infect_pre(index, attacker)
{
	remove_task(TASK_FLAME + index);
	remove_task(TASK_BURN + index);
	g_PlayerData[index][Switch] = 0;
}

public zm_cure_pre(index, attacker)
{
	remove_task(TASK_FLAME + index);
	remove_task(TASK_BURN + index);
	g_PlayerData[index][Switch] = 0;
}

public RG_CBasePlayer_Killed_Post(index)
{
	remove_task(TASK_FLAME + index);
	remove_task(TASK_BURN + index);
	g_PlayerData[index][Switch] = 0;
}

public native_set_freeze(plugin, params)
{
	enum
	{
		arg_index = 1,
		arg_freeze_time,
		arg_gravity,
		arg_motion,
		arg_fire,
		arg_r,
		arg_g,
		arg_b
	};
	
	new index = get_param(arg_index);
	if(!is_user_alive(index) || !zm_round_started() || g_PlayerData[index][Switch])
	{
		return false;
	}
	
	g_PlayerData[index][Switch] = 1;
	
	g_PlayerData[index][FreezeTime] = get_param_f(arg_freeze_time);
	
	new gravity = get_param(arg_gravity);
	if(gravity)
	{
		if(get_entvar(index, var_flags) & FL_ONGROUND)
		{
			set_entvar(index, var_gravity, 999999.9);
		}
		else
		{
			set_entvar(index, var_gravity, 0.000001);
		}
	}
	
	g_PlayerData[index][Motion] = get_param(arg_motion);
	
	new fire = get_param(arg_fire);
	if(fire)
	{
		// 
	}
	
	ExecuteHamB(Ham_Item_PreFrame, index);
	
	new color[3];
	color[0] = get_param(arg_r);
	color[1] = get_param(arg_g);
	color[2] = get_param(arg_b);
	_set_rendering(index, kRenderFxGlowShell, color[0], color[1], color[2], kRenderNormal, 16);
	
	return true;
}

public native_get_freeze(plugin, params)
{
	enum
	{
		arg_index = 1
	};
	
	new index = get_param(arg_index);
	if(!is_user_alive(index))
	{
		return false;
	}
	
	return g_PlayerData[index][Switch];
}

public native_set_fire(plugin, params)
{
	enum
	{
		arg_index = 1,
		arg_duration,
		arg_damage
	};
	
	new index = get_param(arg_index);
	if(!is_user_alive(index) || !zm_round_started())
	{
		return false;
	}
	
	if(!task_exists(TASK_BURN + index))
	{
		new param[1];
		for(new i = 0; i < 3; i++)
		{
			param[0] = i;
			set_task(float(i)-(0.5*i), "taskFlame", TASK_FLAME + index, param, sizeof(param));
		}
	}
	
	g_PlayerData[index][Duration] = get_param(arg_duration);
	g_PlayerData[index][BurnDamage] = get_param(arg_damage);
	
	remove_task(TASK_BURN + index);
	set_task(1.0, "taskDuration", TASK_BURN + index, .flags = "b");
	
	ExecuteHamB(Ham_Item_PreFrame, index);
	return true;
}

public native_get_fire(plugin, params)
{
	enum
	{
		arg_index = 1
	};
	
	new index = get_param(arg_index);
	if(!is_user_alive(index))
	{
		return false;
	}
	
	return task_exists(TASK_BURN + index);
}

public RG_CBasePlayer_PreThink_Pre(index)
{
	static Float:gameTime; gameTime = get_gametime();
	
	switch(g_PlayerData[index][Switch])
	{
		case 1:
		{
			g_PlayerData[index][Switch] = 2;
			g_PlayerData[index][CheckTime] = gameTime + g_PlayerData[index][FreezeTime];
		}
		case 2:
		{
			if(get_entvar(index, var_flags) & FL_ONGROUND || g_PlayerData[index][Motion])
			{
				set_entvar(index, var_velocity, Float:{ 0.0, 0.0, 0.0 });
			}
			
			if(gameTime >= g_PlayerData[index][CheckTime] || !zm_round_started())
			{
				g_PlayerData[index][Switch] = 0;
				
				if(zm_is_zombie(index))
				{
					set_entvar( index, var_gravity, zm_zclass_get_gravity(zm_class_index_zombie(index)));
				}
				else
				{
					set_entvar( index, var_gravity, zm_hclass_get_gravity(zm_class_index_human(index) ) );
				}
				
				ExecuteHamB(Ham_Item_PreFrame, index);
				
				_set_rendering(index);
			}
		}
	}
}

public taskFlame(param[1], index)
{
	index -= TASK_FLAME;
	createFlame(index, param[0]);
}

public taskDuration(index)
{
	index -= TASK_BURN;
	
	if(!g_PlayerData[index][Duration] || get_entvar(index, var_flags) & FL_INWATER)
	{
		remove_task(TASK_BURN + index);
		
		new Float:pos[coord]; get_entvar(index, var_origin, pos);
		_te_smoke(pos, g_iSprSmoke, random_num(15, 20), random_num(10, 20));
		
		ExecuteHamB(Ham_Item_PreFrame, index);
		return;
	}
	
	sendMsgDamage(index, g_PlayerData[index][BurnDamage], DMG_BURN);
	
	g_PlayerData[index][Duration]--;
}

public Ham_Item_PreFrame_Post(const index)
{
	if(is_user_alive(index))
	{
		if(g_PlayerData[index][Switch])
		{
			set_entvar(index, var_maxspeed, 1.0);
		}
		else if(task_exists(TASK_BURN + index))
		{
			if(zm_is_zombie(index))
			{
				set_entvar(index, var_maxspeed, zm_zclass_get_speed(zm_class_index_zombie(index)) * 0.5);
			}
			else
			{
				set_entvar(index, var_maxspeed, zm_hclass_get_speed(zm_class_index_human(index)) * 0.5);
			}
		}
	}
}

createFlame(index, attachments)
{
	new ent = rg_create_entity("env_sprite");
	
	set_entvar(ent, var_classname, FLAME_CLASSNAME);
	set_entvar(ent, var_movetype, MOVETYPE_FOLLOW);
	set_entvar(ent, var_flags, FL_SKIPLOCALHOST);
	set_entvar(ent, var_aiment, index);
	set_entvar(ent, var_owner, index);
	
	set_entvar(ent, var_body, attachments + 1);
	set_entvar(ent, var_skin, index | 0x10000);
	
	set_entvar(ent, var_rendermode, kRenderTransAdd);
	set_entvar(ent, var_renderfx, kRenderFxNone);
	set_entvar(ent, var_renderamt, 150.0);
	
	set_entvar(ent, var_scale, 0.5);
	set_entvar(ent, var_framerate, 10.0);
	set_entvar(ent, var_animtime, get_gametime());
	
	engfunc(EngFunc_SetModel, ent, FLAME_MODEL);
	
	set_entvar(ent, var_spawnflags, SF_SPRITE_STARTON);
	dllfunc(DLLFunc_Spawn, ent);
	
	set_entvar(ent, var_nextthink, get_gametime() + 0.1);
}

public ThinkFlame(ent)
{
	static owner; owner = get_entvar(ent, var_owner);
	if(!task_exists(TASK_BURN + owner))
	{
		set_entvar(ent, var_flags, get_entvar(ent, var_flags) | FL_KILLME);
		return;
	}
	
	set_entvar(ent, var_nextthink, get_gametime() + 0.1);
}

sendMsgDamage(index, damageTake, damageType)
{
	static msg; if(!msg) msg = get_user_msgid("Damage");
		
	message_begin(MSG_ONE_UNRELIABLE, msg, _, index);
	write_byte(0); // damage save
	write_byte(damageTake); // damage take
	write_long(damageType); // damage type
	write_coord(0); // x
	write_coord(0); // y
	write_coord(0); // z
	message_end();
}