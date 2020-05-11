#include <amxmodx>
#include <reapi>
#include <zombiemod_core>
#include <zombiemod_modes>

#pragma semicolon 1

#define PLUGIN_NAME                  "[ZM] Mode: Swarm"
#define PLUGIN_VERS                  "1.0.0"
#define PLUGIN_AUTH                  "CROCK"

new g_iModeSwarm, g_iCurMode;

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERS, PLUGIN_AUTH);	
    
    g_iModeSwarm = zm_register_mode
    (
        .Name = "ZM_MODE_SWARM",
        .Chance = 5,
        .MinPlayers = 8,
        .AllowInfection = 0,
		.DeathMatch = 2
    );
}

public zm_selected_mode(mode)
{
	g_iCurMode = mode;
    
	if(mode == g_iModeSwarm) {
		new playersArray[MAX_PLAYERS], playersNum = _get_players(playersArray, true);

		new maxZombies = floatround(playersNum * 0.5, floatround_ceil);
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

		set_dhudmessage(0, 150, 0, -1.0, 0.17, 0, 0.0, 5.0, 1.0, 1.0);
		show_dhudmessage(0, "Swarm Round!");

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