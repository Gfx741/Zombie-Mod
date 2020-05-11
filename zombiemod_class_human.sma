#include <amxmodx>
#include <hamsandwich>
#include <reapi>
#include <cs_weap_models_api>
#include <zombiemod_core>
#include <effects_util>

#pragma semicolon 1

#define PLUGIN_NAME                  "ZombieMod: Class human"
#define PLUGIN_VERS                  "1.0.0"
#define PLUGIN_AUTH                  "CROCK"

#define NONE_CLASS -1

#define DEFAULT_NAME				"Human"
#define DEFAULT_PLAYER_MODEL		"sas"
#define DEFAULT_BODY				0
#define DEFAULT_HEALTH				150.0
#define DEFAULT_SPEED				0.0
#define DEFAULT_GRAVITY				1.0

new const GRENADE_MODEL[][] =
{
	"models/a4bd3_models/weapons/v_model5_5.mdl",
	"models/a4bd3_models/weapons/v_model4_25.mdl"
};

enum _:ClassData
{
	c_Name[32],
	c_PlayerModel[32],
	c_PlayerModelBody,
	Float:c_Health,
	Float:c_Speed,
	Float:c_Gravity
};
new Array:g_aClass, g_iClassIndex;

enum _:PlayerData {
	Class = 0,
	NextClass,
	Float:Speed
};
new g_PlayerData[MAX_PLAYERS+1][PlayerData];

/*================================================================================
 [PLUGIN]
=================================================================================*/
public plugin_natives()	{
	g_aClass = ArrayCreate(ClassData);
	
	register_library("zombiemod_class_human");
	register_native("zm_register_class_human", "native_register_class");
	register_native("zm_class_index_human", "native_class_index");
	register_native("zm_set_next_class_human", "native_set_next_class");
	register_native("zm_hclass_get_speed", "native_hclass_get_speed");
	register_native("zm_hclass_get_gravity", "native_hclass_get_gravity");
	// register_native("zm_get_name_class_human", "native_get_name_class");
}

public plugin_precache() {
	new szPrecache[64];
	formatex(szPrecache, charsmax(szPrecache), "models/player/%s/%s.mdl", DEFAULT_PLAYER_MODEL, DEFAULT_PLAYER_MODEL);				
	precache_model(szPrecache);
	
	precache_model(GRENADE_MODEL[0]);
	precache_model(GRENADE_MODEL[1]);
}

public plugin_init() {
	register_plugin(PLUGIN_NAME, PLUGIN_VERS, PLUGIN_AUTH);
	
	RegisterHam(Ham_Item_PreFrame, "player", "HamHook_Item_PreFrame_Post", true);
}

public plugin_cfg() {
	if(g_iClassIndex < 1) {
		new class_info[ClassData];
		
		copy(class_info[c_Name], charsmax(class_info[c_Name]), DEFAULT_NAME);
		copy(class_info[c_PlayerModel], charsmax(class_info[c_PlayerModel]), DEFAULT_PLAYER_MODEL);
		class_info[c_PlayerModelBody] = DEFAULT_BODY;
		class_info[c_Health] = DEFAULT_HEALTH;
		class_info[c_Speed] = DEFAULT_SPEED;
		class_info[c_Gravity] = DEFAULT_GRAVITY;
		
		ArrayPushArray(g_aClass, class_info);
		g_iClassIndex++;
	}
}

public native_register_class(plugin, params) {
	enum {
		arg_name = 1,
		arg_player_model,
		arg_player_model_body,
		arg_health,
		arg_speed,
		arg_gravity
	};
	
	new class_info[ClassData];
	
	get_string(arg_name, class_info[c_Name], charsmax(class_info[c_Name]));
	get_string(arg_player_model, class_info[c_PlayerModel], charsmax(class_info[c_PlayerModel]));
	class_info[c_PlayerModelBody] = get_param(arg_player_model_body);
	class_info[c_Health] = get_param_f(arg_health);
	class_info[c_Speed] = get_param_f(arg_speed);
	class_info[c_Gravity] = get_param_f(arg_gravity);
	
	new szPrecache[64];
	formatex(szPrecache, charsmax(szPrecache), "models/player/%s/%s.mdl", class_info[c_PlayerModel], class_info[c_PlayerModel]);				
	precache_model(szPrecache);
	
	ArrayPushArray(g_aClass, class_info);
	g_iClassIndex++;
	return g_iClassIndex - 1;
}

public native_class_index(plugin, params) {
	enum {
		arg_index = 1
	};

	new index = get_param(arg_index);
	
	if(!is_user_connected(index)) {
		log_error(AMX_ERR_NATIVE, "[ZM] Invalid Player (%d)", index);
		return NONE_CLASS;
	}
	return g_PlayerData[index][Class];
}

public native_set_next_class(plugin, params) {
	enum {
		arg_index = 1,
		arg_class_index
	};
	
	new index = get_param(arg_index);
	
	if(!is_user_connected(index)) {
		log_error(AMX_ERR_NATIVE, "[ZM] Invalid Player (%d)", index);
		return false;
	}
	
	g_PlayerData[index][NextClass] = get_param(arg_class_index);
	return true;
}

public Float:native_hclass_get_speed(plugin, params)
{
	enum
	{
		arg_class_index = 1
	};
	
	new class_index = get_param(arg_class_index);
	
	if(class_index < 0 || class_index >= g_iClassIndex)
	{
		log_error(AMX_ERR_NATIVE, "[ZM] Invalid human class index (%d)", class_index);
		return DEFAULT_GRAVITY;
	}
	
	new class_info[ClassData]; ArrayGetArray(g_aClass, class_index, class_info);
	return class_info[c_Speed];
}

public Float:native_hclass_get_gravity(plugin, params)
{
	enum
	{
		arg_class_index = 1
	};
	
	new class_index = get_param(arg_class_index);
	
	if(class_index < 0 || class_index >= g_iClassIndex)
	{
		log_error(AMX_ERR_NATIVE, "[ZM] Invalid human class index (%d)", class_index);
		return DEFAULT_GRAVITY;
	}
	
	new class_info[ClassData]; ArrayGetArray(g_aClass, class_index, class_info);
	return class_info[c_Gravity];
}
/*
public native_get_name_class(plugin, params) {
	enum {
		arg_class_index = 1
		
	};
	
	new class_index = get_param(arg_class_index);
	
	if(class_index < 0 || class_index >= g_iClassIndex) {
		log_error(AMX_ERR_NATIVE, "[ZM] Invalid human class index (%d)", class_index);
		return false;
	}
	
	new class_info[ClassData]; ArrayGetArray(g_aClass, class_index, class_info);
	set_array(arg_info, mode_info, ModeData);
	return true;
}
*/
public client_putinserver(index) {
	g_PlayerData[index][Class] = NONE_CLASS;
	g_PlayerData[index][NextClass] = NONE_CLASS;
}

public HamHook_Item_PreFrame_Post(const index)	{
	if(is_user_alive(index) && !zm_is_zombie(index)) {
		if(g_PlayerData[index][Speed]) {
			set_entvar(index, var_maxspeed, g_PlayerData[index][Speed]);
		}
	}
}

public zm_cure_pre(index) {
	cs_reset_player_view_model(index, CSW_KNIFE);
	cs_reset_player_view_model(index, CSW_HEGRENADE);
	cs_reset_player_view_model(index, CSW_FLASHBANG);
	cs_reset_player_view_model(index, CSW_SMOKEGRENADE);
}

public zm_cure_post(index) {
	if(g_iClassIndex < 1) {
		g_PlayerData[index][NextClass] = 0;
	}
	
	g_PlayerData[index][Class] = g_PlayerData[index][NextClass];
	
	if(g_PlayerData[index][Class] == NONE_CLASS) {
		g_PlayerData[index][Class] = 0;
	}
	
	new class_info[ClassData]; ArrayGetArray(g_aClass, g_PlayerData[index][Class], class_info);
	
	if(zm_round_started()) {
		rg_set_user_team(index, TEAM_CT, MODEL_UNASSIGNED);
	}
	rg_set_user_model(index, class_info[c_PlayerModel], true);

	set_entvar(index, var_body, class_info[c_PlayerModelBody]);
	set_entvar(index, var_health, class_info[c_Health]);
	set_entvar(index, var_gravity, class_info[c_Gravity]);
	
	g_PlayerData[index][Speed] = class_info[c_Speed];
	
	cs_set_player_view_model(index, CSW_HEGRENADE, GRENADE_MODEL[0], 10, 0);
	cs_set_player_view_model(index, CSW_FLASHBANG, GRENADE_MODEL[1], 13, 94);
	cs_set_player_view_model(index, CSW_SMOKEGRENADE, GRENADE_MODEL[1], 12, 94);
	
	ExecuteHamB(Ham_Item_PreFrame, index);
	_set_rendering(index);
}