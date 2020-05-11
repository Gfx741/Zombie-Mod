#include <amxmodx>
#include <hamsandwich>
#include <reapi>
#include <zombiemod_core>
#include <zombiemod_class_zombie>
#include <zombiemod_modes>

#pragma semicolon 1

#define PLUGIN_NAME                  "ZombieMod: Modes"
#define PLUGIN_VERS                  "1.0.0"
#define PLUGIN_AUTH                  "CROCK"

enum (+= 931)
{
	TASK_RESPAWN = 211
};

enum _:ModeData
{
	m_Name[32],
	m_Chance,
	m_MinPlayers,
	m_AllowInfection,
	m_DeathMatch
};
new Array:g_aModes, g_iModesNum;
new g_iAllowInfection, g_iDeathMatch;

new Float:g_fRespawnDelay = 5.0;

enum Forwards
{
	SELECTED_MODE
};
new g_Forwards[Forwards], g_iReturn;

/*================================================================================
 [PLUGIN]
=================================================================================*/
public plugin_natives()	{
	g_aModes = ArrayCreate(ModeData);
	
	register_library("zombiemod_modes");
	register_native("zm_register_mode", "native_register_mode");
	register_native("zm_allow_infection", "native_allow_infection");
}

public plugin_init() {
	register_plugin(PLUGIN_NAME, PLUGIN_VERS, PLUGIN_AUTH);
	
	register_logevent("LogEventHook_RestartGame", 2, "1=Game_Commencing", "1&Restart_Round_");
	
	RegisterHookChain(RG_CBasePlayer_Killed, "HC_CBasePlayer_Killed_Post", true);
	RegisterHookChain(RG_CBasePlayer_TraceAttack,  "HC_CBasePlayer_TraceAttack_Pre", false);
	
	g_Forwards[SELECTED_MODE] = CreateMultiForward("zm_selected_mode", ET_IGNORE, FP_CELL);
	
	register_clcmd("say /inf", "@ClCmd_inf");
	register_clcmd("say /cur", "@ClCmd_cur");
}
@ClCmd_inf(index) {
	if(is_user_alive(index) && zm_round_started() && !zm_is_zombie(index))
		zm_set_infect(index);
}
@ClCmd_cur(index) {
	if(is_user_alive(index) && zm_round_started() && zm_is_zombie(index))
		zm_set_cure(index);		
}

public native_register_mode(plugin, params){
	enum {
		arg_name = 1,
		arg_chance,
		arg_min_players,
		arg_allow_infection,
		arg_death_match
	};
	
	new mode_info[ModeData];
	
	get_string(arg_name, mode_info[m_Name], charsmax(mode_info[m_Name]));
	mode_info[m_Chance] = get_param(arg_chance);
	mode_info[m_MinPlayers] = get_param(arg_min_players);
	mode_info[m_AllowInfection] = get_param(arg_allow_infection);
	mode_info[m_DeathMatch] = get_param(arg_death_match);
	
	ArrayPushArray(g_aModes, mode_info);
	g_iModesNum++;
	return g_iModesNum - 1;
}

public native_allow_infection(plugin, params) {
	return g_iAllowInfection;
}

public client_putinserver(index)
{
	if( deathMatch() )
	{
		zm_respawn_as_zombie(index, 1);
		set_task(g_fRespawnDelay, "taskRespawn", TASK_RESPAWN + index);
	}
}

public client_disconnected(index) {
	remove_task(TASK_RESPAWN + index);
}

public LogEventHook_RestartGame()
{
	zm_round_end();
}

public HC_CBasePlayer_Killed_Post(victim, attacker)
{
	if( !zm_round_finished() )
	{
		if( !zm_round_started() )
		{
			set_task(0.5, "taskRespawn", TASK_RESPAWN + victim);
		}
		else
		{
			if( deathMatch() )
			{
				zm_respawn_as_zombie(victim, 1);
				
				rg_send_bartime(victim, floatround(g_fRespawnDelay));
				set_task(g_fRespawnDelay, "taskRespawn", TASK_RESPAWN + victim);
			}
		}
	}
	
	return HC_CONTINUE;
}

deathMatch()
{
	if( zm_round_started() && g_iDeathMatch )
	{
		new playersArray[MAX_PLAYERS], playersNum = _get_players(playersArray, true, true);
		new huamnRatio = floatround(playersNum * 0.30, floatround_ceil);
		
		if( zm_get_alive_humans() <= huamnRatio )
		{
			return 0;
		}
		
		return 1;
	}
	
	return 0;
}

public HC_CBasePlayer_TraceAttack_Pre(victim, attacker, Float:fDamage, Float:fDirection[3])	{
	if(!zm_round_started()) {
		SetHookChainReturn(ATYPE_INTEGER, 0);
		
		return HC_SUPERCEDE;
	}
	
	if(zm_is_zombie(attacker) && !zm_is_zombie(victim)) {
		fDamage *= zm_class_factor_damage_zombie(zm_class_index_zombie(attacker));
		
		static Float: fArmor; fArmor = get_entvar(victim, var_armorvalue);
		
		if(fArmor > 0.0) {
			fArmor -= fDamage;
			
			set_entvar(victim, var_armorvalue, fArmor);
		}
		else {
			if((zm_get_alive_humans() == 1) || !(g_iAllowInfection)) {
				SetHookChainArg(3, ATYPE_FLOAT, fDamage);
				
				return HC_CONTINUE;
			}
			else {
				zm_set_infect(victim, attacker);
			}
		}
		SetHookChainArg(3, ATYPE_FLOAT, 0.0);
	}
	return HC_CONTINUE;
}

public zm_mode_choose() {
	new playersArray[MAX_PLAYERS], playersNum = _get_players(playersArray, true);
	new mode_info[ModeData];
	for(new i = 0; i < g_iModesNum; i++) {
		ArrayGetArray(g_aModes, i, mode_info);
		
		if(random_num(1, mode_info[m_Chance]) != 1) {
			continue;
		}
		
		if(playersNum < mode_info[m_MinPlayers]) {
			continue;
		}
		
		g_iAllowInfection = mode_info[m_AllowInfection];
		g_iDeathMatch = mode_info[m_DeathMatch];
		
		ExecuteForward(g_Forwards[SELECTED_MODE], g_iReturn, i);
		return;
	}
	
	g_iDeathMatch = 1;
	g_iAllowInfection = 1;
	
	new maxZombies = floatround(playersNum * /*g_fCvar_ZombieRatio*/ 0.15, floatround_ceil);
	new randomIndex;
	
	while(maxZombies) {
		randomIndex = playersArray[random(playersNum)];
		
		if(!zm_is_zombie(randomIndex)) {
			zm_set_infect(randomIndex);
			
			maxZombies--;
		}
	}
	
	for(new i = 0, index; i < playersNum; i++) {
		index = playersArray[i];
		
		if(!zm_is_zombie(index)) {
			rg_set_user_team(index, TEAM_CT, MODEL_UNASSIGNED);
		}
	}
}

public zm_infect_pre(index, attacker) {
	if(is_user_connected(attacker) && attacker != index) {
		make_deathmsg(attacker, index, 0, "teammate");
		
		set_entvar(attacker, var_frags, get_entvar(attacker, var_frags) + 1);
	}
}

public zm_round_end()
{
	client_print(0, print_chat, "[TEST RESPAWN] Round finished!");
	for(new i = 1; i <= MaxClients; i++)
	{
		if(!is_user_connected(i) || !task_exists( TASK_RESPAWN + i) )
		{
			continue;
		}
		client_print(i, print_chat, "[TEST RESPAWN] Task removed!");
		
		remove_task(TASK_RESPAWN + i);
		rg_send_bartime(i, 0);
		
		/*
		if(task_exists( TASK_RESPAWN + i) )
		{
		
			remove_task(TASK_RESPAWN + i);
			
			rg_send_bartime(i, 0);
		}*/
	}
}

/*================================================================================
 [Tasks]
=================================================================================*/
public taskRespawn(index)
{
	index -= TASK_RESPAWN;
	if(!is_user_alive(index))
	{
		client_print(index, print_chat, "[TEST RESPAWN] You are respawn!");
		
		ExecuteHamB(Ham_CS_RoundRespawn, index);
	}
}

/*================================================================================
 [Stock]
=================================================================================*/
stock _get_players(players[MAX_PLAYERS], bool:alive = false, bool:task = false) {
	new TeamName: team, count;
	
	for(new i = 1; i <= MaxClients; i++) {
		if(!is_user_connected(i)) {
			continue;
		}
		
		if(alive && !is_user_alive(i) || task && task_exists(TASK_RESPAWN + i)) {
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