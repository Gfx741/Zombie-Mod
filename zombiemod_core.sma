#include <amxmodx>
#include <fakemeta>
//#include <hamsandwich>
#include <reapi>

#pragma semicolon 1

#define PLUGIN_NAME                  "ZombieMod: Core"
#define PLUGIN_VERS                  "1.0.0"
#define PLUGIN_AUTH                  "Timhunk"

enum _:Forwards {
	INFECT_PRE = 0,
	INFECT,
	INFECT_POST,
	CURE_PRE,
	CURE,
	CURE_POST,
	CHOOSE_MODE
};

enum (+= 35)	{
	TASK_ID_INFECT,

	TASK_ID_RESTART_GAME,
	TASK_ID_SCORE
};

new g_iFakeMetaFwd_Spawn;

new g_iTimeRestartGame;

new g_iAliveHumans,
	g_iAliveZombies;

new bool: g_bRoundEnd,
	bool: g_bRestartGame,
	bool: g_bInfectionBegan;

new g_iCvar_TimeRestartGame;

new Float: g_fCvar_TimeInfections;

new Trie: g_tRemoveEntities;

new bool:g_bIsZombie[MAX_PLAYERS+1],
	bool:g_bRespawnAsZombie[MAX_PLAYERS+1];

new g_iForwards[Forwards],
	g_iReturn;

/*================================================================================
 [PLUGIN]
=================================================================================*/
public plugin_natives()	{
	RegisterNatives();
}

public plugin_precache() {
	FakeMeta_RemoveEntities();
}

public plugin_init() {
	register_plugin(PLUGIN_NAME, PLUGIN_VERS, PLUGIN_AUTH);

	Event_Init();
	//Message_Init();

	ReAPI_Init();
	//Engine_Init();
	FakeMeta_Init();
	//Hamsandwich_Init();

	//ClCmd_Init();

	Forwards_Init();
}

public plugin_cfg() {
	Cvars_Cfg();
}

/*================================================================================
 [NATIVES]
=================================================================================*/
RegisterNatives()	{
	register_library("zombiemod_core");
	register_native("zm_get_alive_zombies", "native_get_alive_zombies");
	register_native("zm_get_alive_humans", "native_get_alive_humans");

	register_native("zm_is_zombie", "native_is_zombie");
	register_native("zm_is_last_zombie", "native_is_last_zombie");
	register_native("zm_is_last_human", "native_is_last_human");

	register_native("zm_set_infect", "native_set_infect");
	register_native("zm_set_cure", "native_set_cure");

	register_native("zm_respawn_as_zombie", "native_respawn_as_zombie");

	register_native("zm_get_round_started", "native_zm_get_round_started");
}

public native_get_alive_zombies(plugin, params) {
	return g_iAliveZombies;
}

public native_get_alive_humans(plugin, params) {
	return g_iAliveHumans;
}

public native_is_zombie(plugin, params) {
	enum { arg_index = 1 };

	new iIndex = get_param(arg_index);

	if(!is_user_connected(iIndex))
	{
		log_error(AMX_ERR_NATIVE, "[ZM] Invalid Player (%d)", iIndex);
		return -1;
	}

	return g_bIsZombie[iIndex];
}

public native_is_last_zombie(plugin, params) {
	enum { arg_index = 1 };

	new iIndex = get_param(arg_index);

	if(!is_user_connected(iIndex))
	{
		log_error(AMX_ERR_NATIVE, "[ZM] Invalid Player (%d)", iIndex);
		return -1;
	}

	return (g_iAliveZombies == 1 && g_bIsZombie[iIndex]);
}

public native_is_last_human(plugin, params) {
	enum { arg_index = 1 };

	new iIndex = get_param(arg_index);

	if(!is_user_connected(iIndex))
	{
		log_error(AMX_ERR_NATIVE, "[ZM] Invalid Player (%d)", iIndex);
		return -1;
	}

	return (g_iAliveHumans == 1 && !g_bIsZombie[iIndex]);
}

public native_set_infect(plugin, params) {
	enum { arg_index = 1,
		arg_attacker
	};

	new iIndex = get_param(arg_index);

	if(!is_user_alive(iIndex))
	{
		log_error(AMX_ERR_NATIVE, "[ZM] Invalid Player (%d)", iIndex);
		return false;
	}

	new iAttacker = get_param(arg_attacker);

	if(iAttacker && is_user_connected(iAttacker))
	{
		setInfectPlayer(iIndex, iAttacker);
		return true;
	}

	setInfectPlayer(iIndex);
	return true;
}

public native_set_cure(plugin, params) {
	enum { arg_index = 1,
		arg_attacker
	};

	new iIndex = get_param(arg_index);
	
	if(!is_user_alive(iIndex))
	{
		log_error(AMX_ERR_NATIVE, "[ZM] Invalid Player (%d)", iIndex);
		return false;
	}

	new iAttacker = get_param(arg_attacker);

	if(iAttacker && is_user_connected(iAttacker))
	{
		setCurePlayer(iIndex, iAttacker);
		return true;
	}

	setCurePlayer(iIndex);
	return true;
}

public native_respawn_as_zombie(plugin, params) {
	enum {
		arg_index = 1,
		arg_respawn_as_zombie
	};

	new iIndex = get_param(arg_index);

	if(!is_user_connected(iIndex))
	{
		log_error(AMX_ERR_NATIVE, "[ZM] Invalid Player (%d)", iIndex);
		return false;
	}
	
	new respawnAsZombie = get_param(arg_respawn_as_zombie);
	g_bRespawnAsZombie[iIndex] = respawnAsZombie ? true : false;

	return true;
}

public native_zm_get_round_started(plugin, params) {
	return g_bInfectionBegan;
}

/*================================================================================
 [PRECACHE]
=================================================================================*/

// code

/*================================================================================
 [CVARS]
=================================================================================*/
Cvars_Cfg()	{
	new iCvarId_TimeInfections;

	g_iCvar_TimeRestartGame         = register_cvar("zmb_time_restart_game",            "5");
	iCvarId_TimeInfections          = register_cvar("zmb_time_infections",              "10.0");

	g_iCvar_TimeRestartGame         = get_pcvar_num(g_iCvar_TimeRestartGame);
	g_fCvar_TimeInfections          = get_pcvar_float(iCvarId_TimeInfections);
/*
	g_fCvar_ZombieRatio             = get_pcvar_float(iCvarId_ZombieRatio);
	g_fCvar_MaxDistanceKnockback    = get_pcvar_float(iCvarId_MaxDistanceKnockback);
*/
}

/*================================================================================
 [CLIENT]
=================================================================================*/
public client_putinserver(iIndex) {
	if(is_user_hltv(iIndex)) {
		return PLUGIN_HANDLED;
	}

	//code

	if(!is_user_bot(iIndex))
	{
		set_task(1.0, "taskScore", TASK_ID_SCORE + iIndex, .flags = "b");
	}

	if(g_bInfectionBegan && _get_alive_players()) {
		set_member(iIndex, m_iNumSpawns, 1);
	}

	return PLUGIN_CONTINUE;
}
public taskScore(iIndex)	{
	iIndex -= TASK_ID_SCORE;
	
	set_hudmessage(255, 25, 0, -1.0, 0.02, 0, 0.0, 0.9, 0.15, 0.15, -1);
	show_hudmessage(0, "Zombies: %d -- Humans: %d", g_iAliveZombies, g_iAliveHumans);
}

public client_disconnected(iIndex) {

	remove_task(TASK_ID_SCORE + iIndex);
	if(is_user_alive(iIndex)) {
		if(g_bIsZombie[iIndex])
		{
			g_iAliveZombies--;
	
			if(g_bInfectionBegan)
			{
				if(g_iAliveZombies == 0)
				{
					if(g_iAliveHumans == 1)
					{
						rg_round_end(1.0, WINSTATUS_CTS, ROUND_CTS_WIN);
					}
					else if(g_iAliveHumans > 1)
					{
						setRandomPlayerTurn(true);
					}
				}
			}
		}
		else
		{
			g_iAliveHumans--;
			
			if(g_bInfectionBegan)
			{
				if(g_iAliveHumans == 0)
				{
					if(g_iAliveZombies == 1)
					{
						rg_round_end(1.0, WINSTATUS_TERRORISTS, ROUND_TERRORISTS_WIN);
					}
					else if(g_iAliveZombies > 1)
					{
						setRandomPlayerTurn(false);
					}
				}
			}
			else if(g_iAliveZombies < 2)
			{
				remove_task(TASK_ID_INFECT);
			}
		}
	}
	return PLUGIN_CONTINUE;
}

/*================================================================================
 [EVENT]
=================================================================================*/
Event_Init()	{
	g_bRestartGame = true;

	register_event("HLTV", "EventHook_HLTV", "a", "1=0", "2=0");
	
	register_logevent("LogEventHook_RoundEnd", 2, "1=Round_End");
	register_logevent("LogEventHook_RoundStart", 2, "1=Round_Start");
	register_logevent("LogEventHook_RestartGame", 2, "1=Game_Commencing", "1&Restart_Round_");
}

public EventHook_HLTV()	{
	g_bRoundEnd = false;

	if(g_bRestartGame)
	{
		if(task_exists(TASK_ID_RESTART_GAME))
		{
			return PLUGIN_HANDLED;
		}
		
		if(g_iCvar_TimeRestartGame <= 0)
		{
			g_bRestartGame = false;
		}
		else
		{
			set_task(1.0, "taskRestartGame", TASK_ID_RESTART_GAME, .flags = "a", .repeat = (g_iTimeRestartGame = g_iCvar_TimeRestartGame));
		}
	}

	g_iAliveHumans = 0;
	g_iAliveZombies = 0;

	return PLUGIN_CONTINUE;
}

public LogEventHook_RoundStart() {
	if(g_bRestartGame)
	{
		return PLUGIN_HANDLED;
	}
	
	if(!(g_bRoundEnd) && !(g_bInfectionBegan))
	{
		set_task(g_fCvar_TimeInfections, "taskInfect", TASK_ID_INFECT);
	}
	
	return PLUGIN_CONTINUE;
}

public LogEventHook_RoundEnd()	{
	g_bRoundEnd = true;
	g_bInfectionBegan = false;
	
	remove_task(TASK_ID_INFECT);
}

public LogEventHook_RestartGame()	{
	LogEventHook_RoundEnd();
}

/*================================================================================
 [ReAPI]
=================================================================================*/
ReAPI_Init()	{
	RegisterHookChain(RG_CBasePlayer_Spawn,        "HC_CBasePlayer_Spawn_Post",       true);
	RegisterHookChain(RG_CBasePlayer_Killed,       "HC_CBasePlayer_Killed_Post",      true);
/*
	RegisterHookChain(RG_CBasePlayer_TakeDamage,   "HC_CBasePlayer_TakeDamage_Pre",	  false);
	RegisterHookChain(RG_CBasePlayer_TakeDamage,   "HC_CBasePlayer_TakeDamage_Post",  true);
	RegisterHookChain(RG_CBasePlayer_TraceAttack,  "HC_CBasePlayer_TraceAttack_Pre",  false);
*/
}

public HC_CBasePlayer_Spawn_Post(const iIndex)	{
	if(is_user_alive(iIndex))
	{
		if(g_bRespawnAsZombie[iIndex])
		{
			setInfectPlayer(iIndex, 0, false);

			g_bRespawnAsZombie[iIndex] = false;
		}
		else
		{
			setCurePlayer(iIndex, 0, false);
		}
	}
}

public HC_CBasePlayer_Killed_Post(const iVictim, const iAttacker) {
	if(g_bIsZombie[iVictim])
	{
		g_iAliveZombies--;
	}
	else
	{
		g_iAliveHumans--;
	}

	return HC_CONTINUE;
}
/*
public HC_CBasePlayer_TakeDamage_Pre(const iVictim, const iWeaponId, const iAttacker, Float: fDamage, const bitsDamageType) {
	return HC_CONTINUE;
}

public HC_CBasePlayer_TakeDamage_Post(const iVictim)	{
	return HC_CONTINUE;
}

public HC_CBasePlayer_TraceAttack_Pre(const iVictim, const iAttacker, Float: fDamage, Float: fDirection[3]) {
	if(!(g_bInfectionBegan))
	{
		SetHookChainReturn(ATYPE_INTEGER, 0);
		
		return HC_SUPERCEDE;
	}
	
	return HC_CONTINUE;
}*/
/*================================================================================
 [FakeMeta]
=================================================================================*/
FakeMeta_Init()	{
	unregister_forward(FM_Spawn, g_iFakeMetaFwd_Spawn, true);
	
	//register_forward(FM_EmitSound,  "FakeMetaHook_EmitSound_Pre",  false);
	register_forward(FM_ClientKill, "FakeMetaHook_ClientKill_Pre", false);
	
	TrieDestroy(g_tRemoveEntities);
}

FakeMeta_RemoveEntities()	{
	new const szRemoveEntities[][] =
	{
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

	for(new iCount = 0, iSize = sizeof(szRemoveEntities); iCount < iSize; iCount++)
	{
		TrieSetCell(g_tRemoveEntities, szRemoveEntities[iCount], iCount);
	}
	
	rg_create_entity("func_buyzone");

	g_iFakeMetaFwd_Spawn = register_forward(FM_Spawn, "FakeMetaHook_Spawn_Post", true);
}

public FakeMetaHook_Spawn_Post(const iEntity)	{
	if(!(is_entity(iEntity)))
	{
		return FMRES_IGNORED;
	}

	static szBuyZoneClassName[20];
	get_entvar(iEntity, var_classname, szBuyZoneClassName, charsmax(szBuyZoneClassName));

	if(TrieKeyExists(g_tRemoveEntities, szBuyZoneClassName))
	{
		set_entvar(iEntity, var_flags, FL_KILLME);
	}

	return FMRES_IGNORED;
}

public FakeMetaHook_ClientKill_Pre()	{
	return FMRES_SUPERCEDE;
}

/*================================================================================
 [Forwards]
=================================================================================*/
Forwards_Init()	{
	g_iForwards[INFECT_PRE] = CreateMultiForward("zm_infect_pre", ET_CONTINUE, FP_CELL, FP_CELL);
	g_iForwards[INFECT] = CreateMultiForward("zm_infect", ET_IGNORE, FP_CELL, FP_CELL);
	g_iForwards[INFECT_POST] = CreateMultiForward("zm_infect_post", ET_IGNORE, FP_CELL, FP_CELL);

	g_iForwards[CURE_PRE] = CreateMultiForward("zm_cure_pre", ET_CONTINUE, FP_CELL, FP_CELL);
	g_iForwards[CURE] = CreateMultiForward("zm_cure", ET_IGNORE, FP_CELL, FP_CELL);
	g_iForwards[CURE_POST] = CreateMultiForward("zm_cure_post", ET_IGNORE, FP_CELL, FP_CELL);

	g_iForwards[CHOOSE_MODE] = CreateMultiForward("zm_shoose_mode", ET_IGNORE);
}

/*================================================================================
 [ZombieMod]
=================================================================================*/

setInfectPlayer(iIndex, iAttacker = 0, bool:bCountHumans = true) {
	ExecuteForward(g_iForwards[INFECT_PRE], g_iReturn, iIndex, iAttacker);

	if(g_iReturn >= PLUGIN_HANDLED)
		return;

	ExecuteForward(g_iForwards[INFECT], g_iReturn, iIndex, iAttacker);

	g_bIsZombie[iIndex] = true;

	ExecuteForward(g_iForwards[INFECT_POST], g_iReturn, iIndex, iAttacker);

	if( bCountHumans )
	{
		g_iAliveHumans--;
	}

	g_iAliveZombies++;
}

setCurePlayer(iIndex, iAttacker = 0, bool:bCountInfected = true) {
	ExecuteForward(g_iForwards[CURE_PRE], g_iReturn, iIndex, iAttacker);

	if(g_iReturn >= PLUGIN_HANDLED)
		return;

	ExecuteForward(g_iForwards[CURE], g_iReturn, iIndex, iAttacker);

	g_bIsZombie[iIndex] = false;

	ExecuteForward(g_iForwards[CURE_POST], g_iReturn, iIndex, iAttacker);

	if( bCountInfected )
	{
		g_iAliveZombies--;
	}

	g_iAliveHumans++;
}

setRandomPlayerTurn(bool:zombie = true)	{
	new playersArray[MAX_PLAYERS];
	new playersNum = _get_players(playersArray, true);

	new randomIndex = playersArray[random(playersNum)];
	zombie ? setInfectPlayer(randomIndex) : setCurePlayer(randomIndex);
}

/*================================================================================
 [TASK]
=================================================================================*/
public taskInfect()	{
	g_bInfectionBegan = true;

	ExecuteForward(g_iForwards[CHOOSE_MODE], g_iReturn);
}

public taskRestartGame() {
	if(--g_iTimeRestartGame == 0) {
		server_cmd("sv_restart 1");

		g_bRestartGame = false;
	}
	else {
		set_dhudmessage(0, 150, 0, 0.1, 0.2, 0, 0.0, 0.9, 0.15, 0.15);
		show_dhudmessage(0, "Restart: %d", g_iTimeRestartGame);
	}
}

/*================================================================================
 [Stock]
=================================================================================*/
stock _get_players(players[MAX_PLAYERS], bool:alive = false) {
	new TeamName: team, count;

	for(new i = 1; i <= MaxClients; i++) {
		if(!is_user_connected(i) || alive && !is_user_alive(i)) {
			continue;
		}

        	team = get_member(i, m_iTeam);
		if(team == TEAM_UNASSIGNED || team == TEAM_SPECTATOR) {
			continue;
		}
		players[count++] = i;
	}
	return count;
}

stock _get_alive_players()
{
    new players[MAX_PLAYERS], pnum;
    get_players(players, pnum, "a");
    return pnum;
}
