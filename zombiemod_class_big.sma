#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <reapi>
#include <zombiemod_core>
#include <zombiemod_class_zombie>
#include <zombiemod_addon_freeze>
#include <skillmanager>

#pragma semicolon	1

#define PLUGIN_NAME		"[ZM] Class zombie: Big"
#define PLUGIN_VERS		"1.0.0"
#define PLUGIN_AUTH		"CROCK"

#define IsPlayer(%0)		(%0 && %0 <= MaxClients)
#define IsZombieBig(%1) 	(zm_class_index_zombie(%1) == g_iClassBig)

#define TRAP_LIFETIME 5.0

new const TRAP_CNAME_MODEL[] = "trapSpr";
new const TRAP_CNAME_SPRITE[] = "trapMdl";

new const TRAP_MODEL[] = "models/a4bd3_models/zombietrap.mdl";
new const TRAP_SPRITE[] = "sprites/a4bd3_sprites/zombietrap.spr";

new g_iClassBig;
new bool:g_bCheckTouch[MAX_PLAYERS+1];

public plugin_precache()
{
	g_iClassBig = zm_register_class_zombie
	(
		.Flag = FLAG_VIP,
		.Name = "Big",
		.PlayerModel = "a4bd3_3b",
		.PlayerModelBody = 0,
		.ClawModel = "models/a4bd3_models/zmh/v_zmhand_v1.mdl",
		.ClawBody = 9,
		.ClawAnim = 12,
		.BombBody = 43,
		.BombAnim = 22,
		.Health = 3000.0,
		.Speed = 280.0,
		.Gravity = 1.0,
		.FactorDamage = 2.0,
		.BulletDefence = 0.80,
		.GrenadeDefence = 1.0,
		.Knockback = 1.0
	);
	
	precache_model(TRAP_MODEL);
	precache_model(TRAP_SPRITE);
}

public plugin_init() {
	register_plugin(PLUGIN_NAME, PLUGIN_VERS, PLUGIN_AUTH);
	
	register_touch(TRAP_CNAME_SPRITE, "*", "Engine_TouchTrap");
	register_think(TRAP_CNAME_MODEL, "Engine_ThinkTrap");
}

public zm_infect_post(index, attacker)
{
	if(IsZombieBig(index))
	{
		sm_set_skill(index, IN_RELOAD, 0.0, 1, 0);
		client_print(index, print_chat, "Class: Big");
	}
}

public zm_infect_pre(index)
{
	g_bCheckTouch[index] = false;
}
public zm_cure_pre(index)
{
	g_bCheckTouch[index] = false;
}

public sm_skill_start(index, bool:bFirstFrame, bool:bSkillActivated)
{
	if(IsZombieBig(index))
	{
		if(bFirstFrame)
		{
			g_bCheckTouch[index] = false;
			
			if( !(get_entvar(index, var_flags) & FL_ONGROUND) )
			{
				client_print_color(index, print_chat, "Nelzya!");
				return 0;
			}
			
			set_entvar(index, var_velocity, Float:{ 0.0, 0.0, 0.0 } );
		}
		
		if(g_bCheckTouch[index])
		{
			client_print_color(index, print_chat, "Nelzya tak blizko!");
			return 0;
		}
		
		if(_rg_get_speed(index) > 0)
		{
			client_print_color(index, print_chat, "Ne dvygaysya!");
			return 0;
		}
		
		if(bSkillActivated)
		{
			new Float:origin[3]; get_entvar(index, var_origin, origin);
			
			new entSprite = rg_create_entity("env_sprite");
			
			set_entvar(entSprite, var_classname, TRAP_CNAME_SPRITE);
			set_entvar(entSprite, var_owner, index);
			set_entvar(entSprite, var_movetype, MOVETYPE_TOSS);
			set_entvar(entSprite, var_solid, SOLID_TRIGGER);
			
			set_entvar(entSprite, var_rendermode, kRenderTransAdd);
			set_entvar(entSprite, var_renderamt, 250.0);
			
			set_entvar(entSprite, var_scale, 0.3);
			
			engfunc(EngFunc_SetModel, entSprite, TRAP_SPRITE);
			engfunc(EngFunc_SetOrigin, entSprite, origin);
			engfunc(EngFunc_SetSize, entSprite, Float:{-30.0, -30.0, -20.0}, Float:{30.0, 30.0, 20.0});
			
			client_print_color(index, print_chat, "Trap active!");
		}
		
		return 1;
	}
	
	return 0;
}

public Engine_TouchTrap(ent, toucher)
{
	if(is_nullent(ent))
	{
		return PLUGIN_CONTINUE;
	}
	
	if(!IsPlayer(toucher) || !is_user_alive(toucher))
	{
		return PLUGIN_CONTINUE;
	}
	
	if(!g_bCheckTouch[toucher])
	{
		g_bCheckTouch[toucher] = true;
	}
	
	if(zm_is_zombie(toucher))
	{
		return PLUGIN_CONTINUE;
	}
	
	/*
	if(get_entvar(ent, var_owner) == toucher)
	{
		return PLUGIN_CONTINUE;
	}
	*/
	
	engfunc(EngFunc_RemoveEntity, ent);
	
	new Float:origin[3]; get_entvar(toucher, var_origin, origin);
	new entModel = rg_create_entity("info_target");
	
	set_entvar(entModel, var_classname, TRAP_CNAME_MODEL);
	set_entvar(entModel, var_owner, toucher);
	set_entvar(entModel, var_movetype, MOVETYPE_TOSS);
	set_entvar(entModel, var_solid, SOLID_TRIGGER);
	set_entvar(entModel, var_fuser1, get_gametime() + TRAP_LIFETIME);
	set_entvar(entModel, var_nextthink, get_gametime() + 0.1);
	
	set_entvar(entModel, var_sequence, 1);
	set_entvar(entModel, var_framerate, 1.0);
	set_entvar(entModel, var_animtime, get_gametime());
	
	engfunc(EngFunc_SetModel, entModel, TRAP_MODEL);
	engfunc(EngFunc_SetOrigin, entModel, origin);
	engfunc(EngFunc_SetSize, entModel, Float:{-30.0, -30.0, -10.0}, Float:{30.0, 30.0, 10.0});
	
	ad_set_freeze(.index=toucher, .freezeTime=TRAP_LIFETIME, .gravity=0, .motion=1, .fire=0, .r=0, .g=0, .b=0);
	
	return PLUGIN_CONTINUE;
}

public Engine_ThinkTrap(ent)
{
	new Float:gametime = get_gametime();
	new owner = get_entvar(ent, var_owner);
	
	if(gametime >= get_entvar(ent, var_fuser1) || !is_user_alive(owner) || zm_is_zombie(owner) || !zm_round_started())
	{
		set_entvar(ent, var_flags, get_entvar(ent, var_flags) | FL_KILLME);
		return;
	}
	
	set_entvar(ent, var_nextthink, gametime + 0.1);
}

stock _rg_get_speed(index) {
	new Float:velocity[3];
	get_entvar(index, var_velocity, velocity);
	
	return floatround(vector_length(velocity));
}