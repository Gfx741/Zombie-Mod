#include <amxmodx>
#include <reapi>
#include <zombiemod_core>

#pragma semicolon 1

#define PLUGIN_NAME			"[ZM] Skill manager"
#define PLUGIN_VERS			"1.0.6"
#define PLUGIN_AUTH			"CROCK"

enum (+= 213)
{
	TASK_COOLDOWN = 145
}

enum Forwards
{
	Started = 0,
};

new g_Forwards[Forwards], g_iReturn;

enum _:PlayerData
{
	Skill,
	Button,
	Float:PreTime,
	BarTime,
	Cooldown,
	ReloadTime,
	Float:CheckTime
};

new g_PlayerData[MAX_PLAYERS +1 ][PlayerData];
new g_iSyncHudCooldown;

public plugin_natives()
{
	register_library("skillmanager");
	register_native("sm_set_skill", "native_set_skill");
}

public plugin_init()
{
	register_plugin(PLUGIN_NAME, PLUGIN_VERS, PLUGIN_AUTH);
	
	RegisterHookChain(RG_CBasePlayer_PreThink, "RG_CBasePlayer_PreThink_Pre", false);
	
	g_Forwards[Started] = CreateMultiForward("sm_skill_start", ET_CONTINUE, FP_CELL, FP_CELL, FP_CELL);
	
	g_iSyncHudCooldown = CreateHudSyncObj();
}

public native_set_skill(plugin, params)
{
	enum
	{
		arg_index = 1,
		arg_button,
		arg_pre_time,
		arg_bar_time,
		arg_cooldown
	};
	
	new index = get_param(arg_index);
	if(!is_user_connected(index))
	{
		return false;
	}
	
	g_PlayerData[index][Button] = get_param(arg_button);
	g_PlayerData[index][PreTime] = get_param_f(arg_pre_time);
	g_PlayerData[index][BarTime] = get_param(arg_bar_time);
	g_PlayerData[index][ReloadTime] = get_param(arg_cooldown);
	
	return true;
}

public client_dissconnected(index)
{
	remove_task(TASK_COOLDOWN + index);
}

public RG_CBasePlayer_PreThink_Pre(index)
{
	new Float:fGameTime = get_gametime();
	
	switch(g_PlayerData[index][Skill])
	{
		case 1:
		{
			if(fGameTime >= g_PlayerData[index][CheckTime])
			{
				g_PlayerData[index][Skill] = 2;
				rg_send_bartime(index, g_PlayerData[index][BarTime]);
				g_PlayerData[index][CheckTime] = fGameTime + float(g_PlayerData[index][BarTime]);
			}
		}
		case 2:
		{
			ExecuteForward(g_Forwards[Started], g_iReturn, index, false, false);
			if(g_iReturn <= 0 || !is_user_alive(index) || !zm_is_zombie(index) || !zm_round_started())
			{
				g_PlayerData[index][Skill] = 0;
				rg_send_bartime(index, 0);
			}
			
			if(fGameTime >= g_PlayerData[index][CheckTime])
			{
				ExecuteForward(g_Forwards[Started], g_iReturn, index, false, true);
				if(g_iReturn <= 0)
				{
					return HC_CONTINUE;
				}
				
				g_PlayerData[index][Cooldown] = g_PlayerData[index][ReloadTime];
				if(g_PlayerData[index][Cooldown])
				{
					set_task(1.0, "taskCooldown", TASK_COOLDOWN + index, .flags = "b");
				}
				
				g_PlayerData[index][Skill] = 0;
			}
		}
	}
	
	if((get_member(index, m_afButtonPressed) & g_PlayerData[index][Button]) && is_user_alive(index)
		&& zm_is_zombie(index) && !g_PlayerData[index][Skill] && !task_exists(TASK_COOLDOWN + index) && zm_round_started())
	{
		ExecuteForward(g_Forwards[Started], g_iReturn, index, true, false);
		if(g_iReturn <= 0)
		{
			return HC_CONTINUE;
		}
		
		if(g_PlayerData[index][PreTime])
		{
			g_PlayerData[index][CheckTime] = fGameTime + g_PlayerData[index][PreTime];
			g_PlayerData[index][Skill] = 1;
		}
		else
		{
			rg_send_bartime(index, g_PlayerData[index][BarTime]);
			g_PlayerData[index][CheckTime] = fGameTime + g_PlayerData[index][BarTime];
			g_PlayerData[index][Skill] = 2;
		}
	}
	
	if( (get_member(index, m_afButtonReleased) & g_PlayerData[index][Button]) && g_PlayerData[index][Skill] )
	{
		rg_send_bartime(index, 0);
		g_PlayerData[index][Skill] = 0;
	}
	
	return HC_CONTINUE;
}

public taskCooldown(index)
{
	index -= TASK_COOLDOWN;
	
	set_hudmessage(200, 100, 0, -1.0, 0.7, 0, 0.0, 0.9, 0.15, 0.15, -1);

	if(!g_PlayerData[index][Cooldown] || !is_user_alive(index) || !zm_is_zombie(index))
	{
		remove_task(TASK_COOLDOWN + index);
		
		if(!g_PlayerData[index][Cooldown])
		{
			ShowSyncHudMsg(index, g_iSyncHudCooldown, "Ability ready!");
		}
		return;
	}
	ShowSyncHudMsg(index, g_iSyncHudCooldown, "Ability reload: %d", g_PlayerData[index][Cooldown]);
	g_PlayerData[index][Cooldown]--;
}