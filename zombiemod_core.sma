#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>

#pragma semicolon 1

#define PLUGIN_NAME                  "ZombieMod: Core"
#define PLUGIN_VERS                  "1.0.0"
#define PLUGIN_AUTH                  "CROCK"

enum (+= 35)
{
	TASK_START,
	TASK_SCORE
};

enum Forwards
{
	InfectPlayerPre = 0,
	InfectPlayerPost,
	CurePlayerPre,
	CurePlayerPost,
	LastZombieDisconnected,
	LastHumanDisconnected,
	ModeChoose,
	RoundEnd
};
new g_Forwards[Forwards], g_iReturn;

new Trie:g_tRemoveEntities, g_iFMForwardSpawn;

new bool:g_bGameStarted, bool:g_bGameFinished;
new bool:g_bZombie[MAX_PLAYERS+1], bool:g_bRespawnAsZombie[MAX_PLAYERS+1], g_iLeaver, g_iAliveZombies, g_iAliveHumans;

public plugin_precache()
{
	new const szRemoveEntities[][] = {
		"func_hostage_rescue",
		"info_hostage_rescue",
		"func_bomb_target",
		"info_bomb_target",
		"func_vip_safetyzone",
		"info_vip_start",
		"func_escapezone",
		"hostage_entity",
		"monster_scientist",
		"func_buyzone"
	};
	g_tRemoveEntities = TrieCreate();
	for(new i = 0, size = sizeof(szRemoveEntities); i < size; i++)
	{
		TrieSetCell(g_tRemoveEntities, szRemoveEntities[i], i);
	}
	rg_create_entity("func_buyzone");
	g_iFMForwardSpawn = register_forward(FM_Spawn, "FM_Spawn_Post", true);
}

public plugin_natives()
{
	register_library("zombiemod_core");
	register_native("zm_is_zombie", "native_is_zombie");
	register_native("zm_respawn_as_zombie", "native_respawn_as_zombie");
	
	register_native("zm_set_infect", "native_set_infect");
	register_native("zm_set_cure", "native_set_cure");
	
	register_native("zm_get_alive_zombies", "native_get_alive_zombies");
	register_native("zm_get_alive_humans", "native_get_alive_humans");
	
	register_native("zm_round_started", "native_zm_round_started");
	register_native("zm_round_finished", "native_zm_round_finished");
}

public plugin_init() {
	register_plugin(PLUGIN_NAME, PLUGIN_VERS, PLUGIN_AUTH);
	
	register_event("HLTV", "EventHook_HLTV", "a", "1=0", "2=0");
	
	register_logevent("LogEventHook_RoundEnd", 2, "1=Round_End");
	register_logevent("LogEventHook_RoundStart", 2, "1=Round_Start");
	register_logevent("LogEventHook_RestartGame", 2, "1=Game_Commencing", "1&Restart_Round_");
	
	unregister_forward(FM_Spawn, g_iFMForwardSpawn, true);
	TrieDestroy(g_tRemoveEntities);
	register_forward(FM_ClientKill, "FM_ClientKill_Pre", false);
	
	RegisterHookChain(RG_CBasePlayer_Spawn, "HC_CBasePlayer_Spawn_Post", true);
	RegisterHookChain(RG_CBasePlayer_Killed, "HC_CBasePlayer_Killed_Post", true);
	
	g_Forwards[InfectPlayerPre] = CreateMultiForward("zm_infect_pre", ET_CONTINUE, FP_CELL, FP_CELL);
	g_Forwards[InfectPlayerPost] = CreateMultiForward("zm_infect_post", ET_IGNORE, FP_CELL, FP_CELL);
	g_Forwards[CurePlayerPre] = CreateMultiForward("zm_cure_pre", ET_CONTINUE, FP_CELL, FP_CELL);
	g_Forwards[CurePlayerPost] = CreateMultiForward("zm_cure_post", ET_IGNORE, FP_CELL, FP_CELL);
	g_Forwards[LastZombieDisconnected] = CreateMultiForward("zm_last_zombie_disconnected", ET_CONTINUE, FP_CELL, FP_CELL);
	g_Forwards[LastHumanDisconnected] = CreateMultiForward("zm_last_huamn_disconnected", ET_CONTINUE, FP_CELL, FP_CELL);
	g_Forwards[ModeChoose] = CreateMultiForward("zm_mode_choose", ET_IGNORE);
	g_Forwards[RoundEnd] = CreateMultiForward("zm_round_end", ET_IGNORE);
}

public plugin_cfg() {
	
}

/*================================================================================
 [CLIENT]
=================================================================================*/
public client_putinserver(index)
{
	if(!is_user_hltv(index))
	{
		if(!is_user_bot(index))
		{
			set_task(1.0, "taskScore", TASK_SCORE + index, .flags = "b");
		}
	}
}

public client_disconnected(index)
{
	remove_task(TASK_SCORE + index);
	
	if(is_user_alive(index))
	{
		if(g_bZombie[index])
		{
			g_iAliveZombies--;
		}
		else
		{
			g_iAliveHumans--;
		}
	}
	
	if(	g_bGameStarted )
	{
		if(g_iAliveZombies == 0)
		{
			if(g_iAliveHumans == 1)
			{
					rg_round_end(1.0, WINSTATUS_CTS, ROUND_CTS_WIN);
			}
			else if(g_iAliveHumans > 1)
			{
					setRandomPlayerTurn(index, .zombie = true);
			}
		}
		
		if(g_iAliveHumans == 0)
		{
			if(g_iAliveZombies == 1)
			{
				rg_round_end(1.0, WINSTATUS_TERRORISTS, ROUND_TERRORISTS_WIN);
			}
			else if(g_iAliveZombies > 1)
			{
				setRandomPlayerTurn(index, .zombie = false);
			}
		}
	}
}

/*================================================================================
 [NATIVES]
=================================================================================*/
public native_is_zombie(plugin, params)
{
	enum
	{
		arg_index = 1
	};
	
	new index = get_param(arg_index);
	
	if(!is_user_connected(index))
	{
		log_error(AMX_ERR_NATIVE, "[ZM] Invalid Player (%d)", index);
		return -1;
	}
	
	return g_bZombie[index];
}

public native_respawn_as_zombie(plugin, params)
{
	enum
	{
		arg_index = 1,
		arg_respawn_as_zombie
	};
	
	new index = get_param(arg_index);
	
	if(!is_user_connected(index))
	{
		log_error(AMX_ERR_NATIVE, "[ZM] Invalid Player (%d)", index);
		return false;
	}
	
	new respawnAsZombie = get_param(arg_respawn_as_zombie);
	g_bRespawnAsZombie[index] = respawnAsZombie ? true : false;
	return true;
}

public native_set_infect(plugin, params)
{
	enum
	{
		arg_index = 1,
		arg_attacker,
		arg_count_humans,
		arg_count_infected
	};

	new index = get_param(arg_index);

	if(!is_user_alive(index))
	{
		log_error(AMX_ERR_NATIVE, "[ZM] Invalid Player (%d)", index);
		return false;
	}
	
	new attacker = get_param(arg_attacker);
	
	if(attacker && is_user_connected(attacker))
	{
		setInfectPlayer(index, attacker);
		return true;
	}
	
	new countHumans = get_param(arg_count_humans);
	new countInfected = get_param(arg_count_infected);
	
	setInfectPlayer(index, 0, countHumans, countInfected);
	return true;
}


public native_set_cure(plugin, params)
{
	enum
	{
		arg_index = 1,
		arg_attacker,
		arg_count_infected,
		arg_count_humans
	};
	
	new index = get_param(arg_index);
	
	if(!is_user_alive(index))
	{
		log_error(AMX_ERR_NATIVE, "[ZM] Invalid Player (%d)", index);
		return false;
	}
	
	new attacker = get_param(arg_attacker);
	
	if(attacker && is_user_connected(attacker))
	{
		setCurePlayer(index, attacker);
		return true;
	}
	
	new countInfected = get_param(arg_count_infected);
	new countHumans = get_param(arg_count_humans);
	
	setCurePlayer(index, 0, countInfected, countHumans);
	return true;
}

public native_get_alive_zombies(plugin, params)
{
	return g_iAliveZombies;
}

public native_get_alive_humans(plugin, params)
{
	return g_iAliveHumans;
}

public native_zm_round_started(plugin, params)
{
	return g_bGameStarted;
}

public native_zm_round_finished(plugin, params)
{
	return g_bGameFinished;
}

/*================================================================================
 [EVENT]
=================================================================================*/
public EventHook_HLTV()
{
	g_bGameFinished = false;
	
	g_iAliveHumans = 0;
	g_iAliveZombies = 0;
	
	return PLUGIN_CONTINUE;
}

public LogEventHook_RoundStart()
{
	if(!g_bGameStarted && !g_bGameFinished)
	{
		set_task(10.0, "taskStart", TASK_START);
	}
}

public LogEventHook_RoundEnd()
{
	g_bGameFinished = true;
	g_bGameStarted = false;
	
	ExecuteForward(g_Forwards[RoundEnd], g_iReturn);
}

public LogEventHook_RestartGame()
{
	remove_task(TASK_START);
	g_bGameStarted = false;
}

/*================================================================================
 [FakeMeta]
=================================================================================*/
public FM_Spawn_Post(ent)
{
	if(!(is_entity(ent)))
	{
		return FMRES_IGNORED;
	}
	
	new entityClassName[20];
	get_entvar(ent, var_classname, entityClassName, charsmax(entityClassName));
	
	if(TrieKeyExists(g_tRemoveEntities, entityClassName))
	{
		set_entvar(ent, var_flags, FL_KILLME);
	}
	
	return FMRES_IGNORED;
}

public FM_ClientKill_Pre()
{
	return FMRES_SUPERCEDE;
}

/*================================================================================
 [ReAPI]
=================================================================================*/
public HC_CBasePlayer_Spawn_Post(index)
{
	if(is_user_alive(index))
	{
		if(g_bGameStarted && g_bRespawnAsZombie[index])
		{
			setInfectPlayer(index, 0, 0);
			g_bRespawnAsZombie[index] = false;
		}
		else 
		{
			setCurePlayer(index, 0, 0);
		}
	}
}

public HC_CBasePlayer_Killed_Post(victim, attacker)
{
	if(g_bZombie[victim])
	{
		g_iAliveZombies--;
	}
	else
	{
		g_iAliveHumans--;
	}
}


/*================================================================================
 [TASK]
=================================================================================*/
public taskStart()
{
	new playersArray[MAX_PLAYERS], playersNum = _get_players(playersArray, true);
	if(playersNum < 2)
	{
		set_task(3.0, "taskStart", TASK_START);
		return;
	}
	
	g_bGameStarted = true;
	
	ExecuteForward(g_Forwards[ModeChoose], g_iReturn);
}

public taskScore(index)
{
	index -= TASK_SCORE;
	
	set_hudmessage(255, 25, 0, -1.0, 0.02, 0, 0.0, 0.9, 0.15, 0.15, -1);
	show_hudmessage(0, "Zombies: %d -- Humans: %d", g_iAliveZombies, g_iAliveHumans);
}

/*================================================================================
 [ZombieMod]
=================================================================================*/
setInfectPlayer(index, attacker = 0, countHumans = 1, countZombies = 1)
{
	ExecuteForward(g_Forwards[InfectPlayerPre], g_iReturn, index, attacker);
	if(g_iReturn >= PLUGIN_HANDLED)
	{
		return;
	}
	
	g_bZombie[index] = true;
	
	ExecuteForward(g_Forwards[InfectPlayerPost], g_iReturn, index, attacker);
	
	if( countHumans )
	{
		g_iAliveHumans--;
	}
	
	if( countZombies )
	{
		g_iAliveZombies++;
	}
}

setCurePlayer(index, attacker = 0, countZombies = 1, countHumans = 1)
{
	ExecuteForward(g_Forwards[CurePlayerPre], g_iReturn, index, attacker);
	if(g_iReturn >= PLUGIN_HANDLED)
	{
		return;
	}
	
	g_bZombie[index] = false;
	
	ExecuteForward(g_Forwards[CurePlayerPost], g_iReturn, index, attacker);
	
	if( countZombies )
	{
		g_iAliveZombies--;
	}
	
	if( countHumans )
	{
		g_iAliveHumans++;
	}
}

setRandomPlayerTurn(leaver, bool:zombie = true)
{
	g_iLeaver = leaver;
	
	new playersArray[MAX_PLAYERS], playersNum = _get_players(playersArray, true, true);
	new randomIndex = playersArray[random(playersNum)];
	
	new name[32]; get_user_name(g_iLeaver, name, charsmax(name));
	new name2[32]; get_user_name(randomIndex, name, charsmax(name2));
	
	client_print(0, print_chat, "%s is out now %s is a %s", name, name2, zombie ? "zombie" : "human");
	
	new Float:health = get_entvar(g_iLeaver, var_health);
	set_entvar(randomIndex, var_health, health);
	
	if(zombie)
	{
		ExecuteForward(g_Forwards[LastZombieDisconnected], g_iReturn, g_iLeaver, randomIndex);
		if(g_iReturn >= PLUGIN_HANDLED)
		{
			return;
		}
		
		setInfectPlayer(randomIndex);
	}
	else
	{
		ExecuteForward(g_Forwards[LastHumanDisconnected], g_iReturn, g_iLeaver, randomIndex);
		if(g_iReturn >= PLUGIN_HANDLED)
		{
			return;
		}
		
		setCurePlayer(randomIndex);
	}
}

/*================================================================================
 [Stock]
=================================================================================*/
stock _get_players(players[MAX_PLAYERS], bool:alive = false, bool:leaver = false)
{
	new TeamName: team, count;
	for(new i = 1; i <= MaxClients; i++)
	{
		if(leaver && i == g_iLeaver || !is_user_connected(i) || alive && !is_user_alive(i))
		{
			continue;
		}
		
		team = get_member(i, m_iTeam);
		if(team == TEAM_UNASSIGNED || team == TEAM_SPECTATOR)
		{
			continue;
		}
		players[count++] = i;
	}
	return count;
}