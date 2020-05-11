#include <amxmodx>
#include <fakemeta>
#include <reapi>
#include <zombiemod_core>
#include <zombiemod_class_human>
#include <zombiemod_addon_freeze>

#pragma semicolon 1

#define PLUGIN_NAME			"[ZM] Item: Parachute"
#define PLUGIN_VERS			"1.1.4"
#define PLUGIN_AUTH			"CROCK"

#define BUTTON			IN_JUMP
#define OnGround(%1)		(get_entvar(%1, var_flags) & _flags)

const _flags = (FL_ONGROUND|FL_INWATER);

new const PARACHUTE_MODEL[] = "models/a4bd3_models/parachute.mdl";

enum PlayerData
{
	bool:HasPar,
	bool:Toggle,
	Entity
};

new g_PlayerData[MAX_PLAYERS +1][PlayerData];

public plugin_precache()
{
	precache_model(PARACHUTE_MODEL);
}

public plugin_init()
{
	register_plugin(PLUGIN_NAME, PLUGIN_VERS, PLUGIN_AUTH);
	
	RegisterHookChain(RG_CBasePlayer_Killed, "RG_CBasePlayer_Killed_Post", true);
	RegisterHookChain(RG_CBasePlayer_PreThink, "RG_CBasePlayer_PreThink_Pre", false);
	
	register_clcmd("say /p", "@ClCmd_para"); // test
}

@ClCmd_para(index) // test
{
	g_PlayerData[index][HasPar] = true;
}

public zm_infect_post(index, attacker)
{
	g_PlayerData[index][HasPar] = false;
}

public RG_CBasePlayer_Killed_Post(victim, attacker)
{
	g_PlayerData[victim][HasPar] = false;
}
			
public RG_CBasePlayer_PreThink_Pre(index)
{
	if(g_PlayerData[index][Toggle])
	{
		static Float:velocity[3]; get_entvar(index, var_velocity, velocity);
		if(velocity[2] < 0.0)
		{
			velocity[2] = (velocity[2] + 40.0 < -50.0) ? velocity[2] + 40.0 : -50.0;
			set_entvar(index, var_velocity, velocity);
		}
		/*
		if(get_member(index, m_afButtonPressed) & IN_MOVELEFT)
		{
			set_member(index, m_afButtonReleased, IN_MOVELEFT);
		}
		
		if(get_member(index, m_afButtonPressed) & IN_MOVERIGHT)
		{
			set_member(index, m_afButtonReleased, IN_MOVERIGHT);
		}
		*/
		if(!g_PlayerData[index][HasPar] || OnGround(index) || ad_get_freeze(index))
		{
			set_member(index, m_afButtonReleased, BUTTON);
		}
	}
	
	if((get_member(index, m_afButtonPressed) & BUTTON) && !g_PlayerData[index][Toggle] && !ad_get_freeze(index))
	{
		if(!g_PlayerData[index][HasPar] || OnGround(index))
		{
			return;
		}
		/*
		new Float:velocity[3]; get_entvar(index, var_velocity, velocity);
		velocity[2] = 10.0;
		
		set_entvar(index, var_velocity, velocity);*/
		set_entvar(index, var_gravity, 0.1);
		
		_setParachuteModel(index, PARACHUTE_MODEL);
		g_PlayerData[index][Toggle] = true;
	}
	
	if((get_member(index, m_afButtonReleased) & BUTTON) && g_PlayerData[index][Toggle])
	{
		if(!zm_is_zombie(index) )
		{
			set_entvar( index, var_gravity, zm_hclass_get_gravity(zm_class_index_human(index) ) );
		}
		
		_removeParachuteModel(index);
		g_PlayerData[index][Toggle] = false;
	}
}

_setParachuteModel(index, const model[])
{
	if(!g_PlayerData[index][Entity])
	{
		new ent = rg_create_entity("info_target");
		
		set_entvar(ent, var_classname, "parachute");
		set_entvar(ent, var_movetype, MOVETYPE_FOLLOW);
		set_entvar(ent, var_aiment, index);
		set_entvar(ent, var_owner, index);
		
		set_entvar(ent, var_sequence, 1);
		set_entvar(ent, var_framerate, 1.0);
		set_entvar(ent, var_animtime, get_gametime());
		
		engfunc(EngFunc_SetModel, ent, model);
		
		g_PlayerData[index][Entity] = ent;
	}
}

_removeParachuteModel(index)
{
	if(is_entity(g_PlayerData[index][Entity]))
	{
		engfunc(EngFunc_RemoveEntity, g_PlayerData[index][Entity]);
		g_PlayerData[index][Entity] = 0;
	}
}

public client_disconnected(index)
{
	_removeParachuteModel(index);
}