#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>

#pragma semicolon                    1

#define PLUGIN_NAME                  "test"
#define PLUGIN_VERS                  "1.1.0"
#define PLUGIN_AUTH                  "CROCK"

#define MAX_ANIM 10
#define POSITION_NULL -1
#define POSITION_NONNULL 0

#define CSW_FIRST_WEAPON CSW_P228
#define CSW_LAST_WEAPON CSW_P90

new const drawAnim[] = {
	0, 6, 0, 4, 3, 6, 1, 2, 2, 3,
	15, 5, 2, 4, 2, 2, 6, 8, 5, 2,
	4, 6, 5, 2, 4, 3, 5, 2, 2, 3, 2
	/*
	14,	//	usp	unsil
	12	//	m4a1	unsil
	*/
};

new g_ViewBody[MAX_PLAYERS+1][CSW_LAST_WEAPON+1];
new g_ViewAnim[MAX_PLAYERS+1][CSW_LAST_WEAPON+1][MAX_ANIM];
new g_ViewModelsPosition[MAX_PLAYERS+1][CSW_LAST_WEAPON+1];
new Array:g_ViewModelsNames;
new g_ViewModelsCount;

public plugin_init()
{
	register_plugin(PLUGIN_NAME, PLUGIN_VERS, PLUGIN_AUTH);
	
	register_forward(FM_UpdateClientData, "FM_UpdateClientData_Post", true);
	
	for(new i = CSW_FIRST_WEAPON, weapon_name[32]; i <= CSW_LAST_WEAPON; i++)
	{
		if(get_weaponname(i, weapon_name, charsmax(weapon_name)))
		{
			RegisterHam(Ham_Item_Deploy, weapon_name, "Ham_Item_Deploy_Post", true);
			RegisterHam(Ham_CS_Weapon_SendWeaponAnim, weapon_name, "Ham_CS_Weapon_SendWeaponAnim_Post", true);
		}
	}
	
	g_ViewModelsNames = ArrayCreate(128, 1);
	
	for(new index = 1,  weaponIndex; index <= MaxClients; index++)
	{
		for(weaponIndex = CSW_FIRST_WEAPON; weaponIndex <= CSW_LAST_WEAPON; weaponIndex++)
		{
			g_ViewModelsPosition[index][weaponIndex] = POSITION_NULL;
		}
	}
}

public plugin_natives()
{
	register_library("cs_weap_models_api");
	register_native("cs_set_player_view_model", "native_set_player_view_model");
	register_native("cs_reset_player_view_model", "native_reset_player_view_model");
}

public native_set_player_view_model(plugin_id, num_params)
{
	enum
	{
		arg_index = 1,
		arg_weapon_index,
		arg_view_model,
		arg_view_body,
		arg_first_anim
	};
	
	new index = get_param(arg_index);
	if(!is_user_connected(index))
	{
		log_error(AMX_ERR_NATIVE, "[CS] Player is not in game (%d)", index);
		return false;
	}
	
	new weaponIndex = get_param(arg_weapon_index);
	
	if(weaponIndex < CSW_FIRST_WEAPON || weaponIndex > CSW_LAST_WEAPON)
	{
		log_error(AMX_ERR_NATIVE, "[CS] Invalid weapon index (%d)", weaponIndex);
		return false;
	}
	
	new view_model[128]; get_string(arg_view_model, view_model, charsmax(view_model));
	
	if(g_ViewModelsPosition[index][weaponIndex] == POSITION_NULL)
	{
		g_ViewModelsPosition[index][weaponIndex] = g_ViewModelsCount;
		ArrayPushString(g_ViewModelsNames, view_model);
		g_ViewModelsCount++;
	}
	else
	{
		ArraySetString(g_ViewModelsNames, g_ViewModelsPosition[index][weaponIndex], view_model);
	}
	
	g_ViewBody[index][weaponIndex] = get_param(arg_view_body);
	for(new i = 0, anim = get_param(arg_first_anim); i < MAX_ANIM; i++)
	{
		if(weaponIndex == CSW_KNIFE && (i == 1 || i == 2))
		{
			g_ViewAnim[index][weaponIndex][i] = 0;
		}
		else
		{
			g_ViewAnim[index][weaponIndex][i] = anim;
			anim++;
		}
	}
	
	new weaponEnt = get_member(index, m_pActiveItem);
	
	if(weaponEnt != NULLENT)
	{
		ExecuteHamB( Ham_Item_Deploy, weaponEnt );
	}
	
	return true;
}

public native_reset_player_view_model(plugin_id, num_params)
{
	enum
	{
		arg_index = 1,
		arg_weapon_index
	};
	
	new index = get_param(arg_index);
	
	if(!is_user_connected(index))
	{
		log_error(AMX_ERR_NATIVE, "[CS] Player is not in game (%d)", index);
		return false;
	}
	
	new weaponIndex = get_param(arg_weapon_index);
	
	if(weaponIndex < CSW_FIRST_WEAPON || weaponIndex > CSW_LAST_WEAPON)
	{
		log_error(AMX_ERR_NATIVE, "[CS] Invalid weapon index (%d)", weaponIndex);
		return false;
	}
	
	if(g_ViewModelsPosition[index][weaponIndex] == POSITION_NULL)
	{
		return true;
	}
	
	RemoveCustomViewModel(index, weaponIndex);
	
	new weaponEnt = get_member( index, m_pActiveItem);
	
	if(weaponEnt != NULLENT)
	{
		ExecuteHamB(Ham_Item_Deploy, weaponEnt);
	}
	
	return true;
}

RemoveCustomViewModel(index, weaponIndex)
{
	new pos_delete = g_ViewModelsPosition[index][weaponIndex];
	
	ArrayDeleteItem(g_ViewModelsNames, pos_delete);
	g_ViewModelsPosition[index][weaponIndex] = POSITION_NULL;
	g_ViewModelsCount--;
	
	// Fix view models array positions
	for(index = 1; index <= MaxClients; index++)
	{
		for(weaponIndex = CSW_FIRST_WEAPON; weaponIndex <= CSW_LAST_WEAPON; weaponIndex++)
		{
			if(g_ViewModelsPosition[index][weaponIndex] > pos_delete)
			{
				g_ViewModelsPosition[index][weaponIndex]--;
			}
		}
	}
}

public client_disconnected(index)
{
	for(new weaponIndex = CSW_FIRST_WEAPON; weaponIndex <= CSW_LAST_WEAPON; weaponIndex++)
	{
		if(g_ViewModelsPosition[index][weaponIndex] != POSITION_NULL)
		{
			RemoveCustomViewModel(index, weaponIndex);
		}
	}
}

public Ham_Item_Deploy_Post(item)
{
	new player = get_member(item, m_pPlayer );
	
	new weaponIndex = get_member(item, m_iId);
	
	if(g_ViewModelsPosition[player][weaponIndex] != POSITION_NULL)
	{
		new view_model[128];
		ArrayGetString(g_ViewModelsNames, g_ViewModelsPosition[player][weaponIndex], view_model, charsmax(view_model));
		set_pev(player, pev_viewmodel2, view_model);
		
		set_member(item, m_flLastEventCheck, get_gametime() + 0.2);
		SendWeaponAnim(player, 0, 0);
	}
}

public Ham_CS_Weapon_SendWeaponAnim_Post(item, anim)
{
	new player = get_member(item, m_pPlayer);
	
	new weaponIndex = get_member(item, m_iId);
	
	if(g_ViewModelsPosition[player][weaponIndex] != POSITION_NULL)
	{
		SendWeaponAnim(player, g_ViewAnim[player][weaponIndex][anim], g_ViewBody[player][weaponIndex]);
	}
	
	return HAM_IGNORED;
}

public FM_UpdateClientData_Post(player, sendWeapons, CD_Handle)
{
	enum
	{
		SPEC_MODE,
		SPEC_TARGET
	};
	
	static specInfo[33][3];
	static Float:gameTime;
	static Float:lastEventCheck;
	
	static target;
	static specMode;
	static weaponEnt;
	static weaponIndex;
	
	target = (specMode = get_entvar( player, var_iuser1 ) ) ? get_entvar( player, var_iuser2 ) : player;
	
	if(!pev_valid(target)) // pev_valid(target) != 2
	{
		return FMRES_IGNORED;
	}
	
	weaponEnt = get_member(target, m_pActiveItem);
	
	if(weaponEnt == NULLENT)
	{
		return FMRES_IGNORED;
	}
	
	gameTime = get_gametime();
	
	lastEventCheck = get_member(weaponEnt, m_flLastEventCheck);
	
	weaponIndex = get_member(weaponEnt, m_iId);
	
	if(g_ViewModelsPosition[target][weaponIndex] != POSITION_NULL)
	{
		if(specMode)
		{
			if(specInfo[player][SPEC_MODE] != specMode)
			{
				specInfo[player][SPEC_MODE] = specMode;
				specInfo[player][SPEC_TARGET] = 0;
			}
			
			if(specMode == OBS_IN_EYE && specInfo[player][SPEC_TARGET] != target)
			{
				specInfo[player][SPEC_TARGET] = target;
				SendWeaponAnim(target, g_ViewAnim[target][weaponIndex][0], g_ViewBody[target][weaponIndex]);
			}
			
			return FMRES_IGNORED;
		}
		
		if(!lastEventCheck)
		{
			set_cd(CD_Handle, CD_flNextAttack, gameTime + 0.001);
			set_cd(CD_Handle, CD_WeaponAnim, 0);
			
			return FMRES_HANDLED;
		}
		
		if(lastEventCheck <= gameTime)
		{
			SendWeaponAnim(target, g_ViewAnim[target][weaponIndex][3/*drawAnim(weaponIndex)*/], g_ViewBody[target][weaponIndex]);
			set_member(weaponEnt, m_flLastEventCheck, 0.0);
		}
	}
	
	return FMRES_IGNORED;
}

stock SendWeaponAnim(index, anim, body)
{
	set_entvar(index, var_weaponanim, anim);
	
	message_begin(MSG_ONE, SVC_WEAPONANIM, _, index);
	write_byte(anim);
	write_byte(body);
	message_end();
	
	if(get_entvar(index, var_iuser1))
	{
		return;
	}
	
	static i, count, player, players[MAX_PLAYERS];
	
	get_players(players, count, "bch");
	
	for(i = 0; i < count; i++)
	{
		player = players[i];
		
		if(get_entvar(player, var_iuser1) != OBS_IN_EYE)
		{
			continue;
		}
		
		if(get_entvar(player, var_iuser2) != index)
		{
			continue;
		}
		
		set_entvar(player, var_weaponanim, anim);
		
		message_begin( MSG_ONE, SVC_WEAPONANIM, _, player);
		write_byte(anim);
		write_byte(body);
		message_end();
	}
}