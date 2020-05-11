#include <amxmodx>
#include <hamsandwich>
#include <reapi>
#include <cs_weap_models_api>
#include <zombiemod_core>
#include <effects_util>

#pragma semicolon 1

#define PLUGIN_NAME                  "ZombieMod: Class zombie"
#define PLUGIN_VERS                  "1.0.0"
#define PLUGIN_AUTH                  "CROCK"

#define NONE_CLASS -1

#define DEFAULT_NAME				"Zombie"
#define DEFAULT_PLAYER_MODEL		"zombie"
#define DEFAULT_BODY				0
#define DEFAULT_CLAW_MODEL			"models/v_knife.mdl"
#define DEFAULT_CLAW_BODY				0
#define DEFAULT_CLAW_ANIM				0
#define DEFAULT_BOMB_BODY				0
#define DEFAULT_BOMB_ANIM				0
#define DEFAULT_HEALTH				3000.0
#define DEFAULT_SPEED				270.0
#define DEFAULT_GRAVITY				0.8
#define DEFAULT_FACTOR_DAMAGE		1.0
#define DEFAULT_BULLET_DEFENCE		1.0
#define DEFAULT_GRENADE_DEFENCE		1.0
#define DEFAULT_KNOCKBACK			1.0

// for test
#define VIP				ADMIN_RCON
#define IsVIP(%1)		(get_user_flags(%1) & VIP)

enum {
	FLAG_NONE = 0,
	FLAG_DONT_SHOW,
	FLAG_VIP
};

enum _:ClassData
{
	c_Flag = 0,
	c_Name[32],
	c_PlayerModel[32],
	c_PlayerModelBody,
	c_ClawModel[64],
	c_ClawBody,
	c_ClawAnim,
	c_BombBody,
	c_BombAnim,
	Float:c_Health,
	Float:c_Speed,
	Float:c_Gravity,
	Float:c_FactorDamage,
	Float:c_BulletDefence,
	Float:c_GrenadeDefence,
	Float:c_Knockback
};
new Array:g_aClass, g_iClassIndex;

enum _:PlayerData {
	Class = 0,
	NextClass,
	Float:Speed,
	ClawModel[64],
	MenuPage
};
new g_PlayerData[MAX_PLAYERS+1][PlayerData];

/*================================================================================
 [PLUGIN]
=================================================================================*/
public plugin_natives()	{
	g_aClass = ArrayCreate(ClassData);
	
	register_library("zombiemod_class_zombie");
	register_native("zm_register_class_zombie", "native_register_class");
	register_native("zm_class_index_zombie", "native_class_index");
	register_native("zm_set_next_class_zombie", "native_set_next_class");
	register_native("zm_zclass_get_speed", "native_class_speed");
	register_native("zm_zclass_get_gravity", "native_class_gravity");
	register_native("zm_class_factor_damage_zombie", "native_class_factor_damage");
	register_native("zm_class_bullet_defence_zombie", "native_class_bullet_defence");
	register_native("zm_class_grenade_defence_zombie", "native_class_grenade_defence");
	register_native("zm_class_knockback_zombie", "native_class_knockback");
}

public plugin_precache() {
	new szPrecache[64];
	formatex(szPrecache, charsmax(szPrecache), "models/player/%s/%s.mdl", DEFAULT_PLAYER_MODEL, DEFAULT_PLAYER_MODEL);				
	precache_model(szPrecache);
	precache_model(DEFAULT_CLAW_MODEL);
}

public plugin_init() {
	register_plugin(PLUGIN_NAME, PLUGIN_VERS, PLUGIN_AUTH);
	
	RegisterHam(Ham_Item_PreFrame, "player", "HamHook_Item_PreFrame_Post", true);
	
	register_clcmd("say /class", "ClCmd_ShowClass");
}

public plugin_cfg() {
	if(g_iClassIndex < 1) {
		new class_info[ClassData];
		
		class_info[c_Flag] = FLAG_NONE;
		copy(class_info[c_Name], charsmax(class_info[c_Name]), DEFAULT_NAME);
		copy(class_info[c_PlayerModel], charsmax(class_info[c_PlayerModel]), DEFAULT_PLAYER_MODEL);
		class_info[c_PlayerModelBody] = DEFAULT_BODY;
		copy(class_info[c_ClawModel], charsmax(class_info[c_ClawModel]), DEFAULT_CLAW_MODEL);
		class_info[c_ClawBody] =  DEFAULT_CLAW_BODY;
		class_info[c_ClawAnim] =  DEFAULT_CLAW_ANIM;
		class_info[c_BombBody] =  DEFAULT_BOMB_BODY;
		class_info[c_BombAnim] =  DEFAULT_BOMB_ANIM;
		class_info[c_Health] = DEFAULT_HEALTH;
		class_info[c_Speed] = DEFAULT_SPEED;
		class_info[c_Gravity] = DEFAULT_GRAVITY;
		class_info[c_FactorDamage] = DEFAULT_FACTOR_DAMAGE;
		class_info[c_BulletDefence] = DEFAULT_BULLET_DEFENCE;
		class_info[c_GrenadeDefence] = DEFAULT_GRENADE_DEFENCE;
		class_info[c_Knockback] = DEFAULT_KNOCKBACK;
		
		ArrayPushArray(g_aClass, class_info);
		g_iClassIndex++;
	}
}

public native_register_class(plugin, params) {
	enum {
		arg_flag = 1,
		arg_name,
		//arg_info,
		arg_player_model,
		arg_player_model_body,
		arg_claw_model,
		arg_claw_body,
		arg_claw_anim,
		arg_bomb_body,
		arg_bomb_anim,
		arg_health,
		arg_speed,
		arg_gravity,
		arg_factor_damage,
		arg_bullet_defence,
		arg_grenade_defence,
		arg_knockback
	};
	
	new class_info[ClassData];
	
	class_info[c_Flag] = get_param(arg_flag);
	get_string(arg_name, class_info[c_Name], charsmax(class_info[c_Name]));
	get_string(arg_player_model, class_info[c_PlayerModel], charsmax(class_info[c_PlayerModel]));
	class_info[c_PlayerModelBody] = get_param(arg_player_model_body);
	get_string(arg_claw_model, class_info[c_ClawModel], charsmax(class_info[c_ClawModel]));
	class_info[c_ClawBody] =  get_param(arg_claw_body);
	class_info[c_ClawAnim] =  get_param(arg_claw_anim);
	class_info[c_BombBody] =  get_param(arg_bomb_body);
	class_info[c_BombAnim] =  get_param(arg_bomb_anim);
	class_info[c_Health] = get_param_f(arg_health);
	class_info[c_Speed] = get_param_f(arg_speed);
	class_info[c_Gravity] = get_param_f(arg_gravity);
	class_info[c_FactorDamage] = get_param_f(arg_factor_damage);
	class_info[c_BulletDefence] = get_param_f(arg_bullet_defence);
	class_info[c_GrenadeDefence] = get_param_f(arg_grenade_defence);
	class_info[c_Knockback] = get_param_f(arg_knockback);
	
	new szPrecache[64];
	formatex(szPrecache, charsmax(szPrecache), "models/player/%s/%s.mdl", class_info[c_PlayerModel], class_info[c_PlayerModel]);				
	precache_model(szPrecache);
	
	precache_model(class_info[c_ClawModel]);
	
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

public Float:native_class_speed(plugin, params) {
	enum {
		arg_class_index = 1
	};
	
	new class_index = get_param(arg_class_index);
	
	if(class_index < 0 || class_index >= g_iClassIndex) {
		log_error(AMX_ERR_NATIVE, "[ZM] Invalid zombie class index (%d)", class_index);
		return DEFAULT_GRAVITY;
	}
	
	new class_info[ClassData]; ArrayGetArray(g_aClass, class_index, class_info);
	return class_info[c_Speed];
}

public Float:native_class_gravity(plugin, params) {
	enum {
		arg_class_index = 1
	};
	
	new class_index = get_param(arg_class_index);
	
	if(class_index < 0 || class_index >= g_iClassIndex) {
		log_error(AMX_ERR_NATIVE, "[ZM] Invalid zombie class index (%d)", class_index);
		return DEFAULT_GRAVITY;
	}
	
	new class_info[ClassData]; ArrayGetArray(g_aClass, class_index, class_info);
	return class_info[c_Gravity];
}

public Float:native_class_factor_damage(plugin, params) {
	enum {
		arg_class_index = 1
	};
	
	new class_index = get_param(arg_class_index);
	
	if(class_index < 0 || class_index >= g_iClassIndex) {
		log_error(AMX_ERR_NATIVE, "[ZM] Invalid zombie class index (%d)", class_index);
		return DEFAULT_FACTOR_DAMAGE;
	}
	
	new class_info[ClassData]; ArrayGetArray(g_aClass, class_index, class_info);
	return class_info[c_FactorDamage];
}

public Float:native_class_bullet_defence(plugin, params) {
	enum {
		arg_class_index = 1
	};
	
	new class_index = get_param(arg_class_index);
	
	if (class_index < 0 || class_index >= g_iClassIndex) {
		log_error(AMX_ERR_NATIVE, "[ZM] Invalid zombie class index (%d)", class_index);
		return DEFAULT_BULLET_DEFENCE;
	}
	
	new class_info[ClassData]; ArrayGetArray(g_aClass, class_index, class_info);
	return class_info[c_BulletDefence];
}

public Float:native_class_grenade_defence(plugin, params) {
	enum {
		arg_class_index = 1
	};
	
	new class_index = get_param(arg_class_index);
	
	if (class_index < 0 || class_index >= g_iClassIndex) {
		log_error(AMX_ERR_NATIVE, "[ZM] Invalid zombie class index (%d)", class_index);
		return DEFAULT_GRENADE_DEFENCE;
	}
	
	new class_info[ClassData]; ArrayGetArray(g_aClass, class_index, class_info);
	return class_info[c_GrenadeDefence];
}

public Float:native_class_knockback(plugin_id, num_params) {
	enum {
		arg_class_index = 1
	};
	
	new class_index = get_param(arg_class_index);
	
	if (class_index < 0 || class_index >= g_iClassIndex) {
		log_error(AMX_ERR_NATIVE, "[ZM] Invalid zombie class index (%d)", class_index);
		return DEFAULT_KNOCKBACK;
	}
	
	new class_info[ClassData]; ArrayGetArray(g_aClass, class_index, class_info);
	return class_info[c_Knockback];
}

public client_putinserver(index) {
	g_PlayerData[index][Class] = NONE_CLASS;
	g_PlayerData[index][NextClass] = NONE_CLASS;
}

public HamHook_Item_PreFrame_Post(const index)	{
	if(is_user_alive(index) && zm_is_zombie(index)) {
		if(g_PlayerData[index][Speed]) {
			set_entvar(index, var_maxspeed, g_PlayerData[index][Speed]);
		}
	}
}

public zm_infect_pre(index) {
	cs_reset_player_view_model(index, CSW_KNIFE);
	cs_reset_player_view_model(index, CSW_HEGRENADE);
	cs_reset_player_view_model(index, CSW_FLASHBANG);
	cs_reset_player_view_model(index, CSW_SMOKEGRENADE);
}

public zm_infect_post(index) {
	if(g_PlayerData[index][NextClass] == NONE_CLASS) {
		(g_iClassIndex > 1) ? ShowMenu_ZombieClass(index) : (g_PlayerData[index][NextClass] = 0);
	}
	
	g_PlayerData[index][Class] = g_PlayerData[index][NextClass];
	
	if(g_PlayerData[index][Class] == NONE_CLASS) {
		g_PlayerData[index][Class] = 0;
	}
	
	new class_info[ClassData]; ArrayGetArray(g_aClass, g_PlayerData[index][Class], class_info);
	
	//copy(g_PlayerData[index][ClawModel], charsmax(g_PlayerData[][ClawModel]), class_info[c_ClawModel]);
	
	rg_set_user_team(index, TEAM_TERRORIST, MODEL_UNASSIGNED);
	rg_set_user_model(index, class_info[c_PlayerModel], true);
	
	set_entvar(index, var_body, class_info[c_PlayerModelBody]);
	set_entvar(index, var_health, class_info[c_Health]);
	set_entvar(index, var_gravity, class_info[c_Gravity]);
	
	g_PlayerData[index][Speed] = class_info[c_Speed];
	
	cs_set_player_view_model(index, CSW_KNIFE, class_info[c_ClawModel], class_info[c_ClawBody], class_info[c_ClawAnim]);
	cs_set_player_view_model(index, CSW_HEGRENADE, class_info[c_ClawModel], class_info[c_BombBody], class_info[c_BombAnim]);
	cs_set_player_view_model(index, CSW_FLASHBANG, class_info[c_ClawModel], class_info[c_BombBody], class_info[c_BombAnim]);
	cs_set_player_view_model(index, CSW_SMOKEGRENADE, class_info[c_ClawModel], class_info[c_BombBody], class_info[c_BombAnim]);
	
	ExecuteHamB(Ham_Item_PreFrame, index);
	
 	rg_drop_items_by_slot(index, PRIMARY_WEAPON_SLOT);
	rg_drop_items_by_slot(index, PISTOL_SLOT);
	rg_remove_items_by_slot(index, GRENADE_SLOT);
	
	new Float:pos[coord]; get_entvar(index, var_origin, pos);
	_te_particlebust(pos, .radius=50, .color=70, .life=3);
	_te_dlight(pos, .radius=20, .r=200, .g=0, .b=0, .life=2, .decayRate=0);
	
	_set_rendering(index);
}

public zm_cure_pre(index) {
	if(zm_is_zombie(index)) {
		rg_remove_items_by_slot(index, GRENADE_SLOT);
	}
}

public ClCmd_ShowClass(index) {
	ShowMenu_ZombieClass(index);
}

public ShowMenu_ZombieClass(index) {
	if(!is_user_connected(index)) {
		return;
	}
	
	new class_info[ClassData];
	if(is_user_bot(index)) {
		new randomClass; g_PlayerData[index][NextClass] = NONE_CLASS;
		
		while(g_PlayerData[index][NextClass] == NONE_CLASS) {
			randomClass = random_num(0, g_iClassIndex - 1);
			ArrayGetArray(g_aClass, randomClass, class_info);
			
			if(class_info[c_Flag] == FLAG_DONT_SHOW) {
				continue;
			}
			g_PlayerData[index][NextClass] = randomClass;
		}
		return;
	}
	
	new text[128];
	formatex(text, charsmax(text), "%L\r", index, "MENU_ZCLASS_TITLE");
	new menu = menu_create(text, "menu_zclass");
	
	for(new i = 0, item[2]; i < g_iClassIndex; i++) {
		ArrayGetArray(g_aClass, i, class_info);
		
		if(class_info[c_Flag] == FLAG_DONT_SHOW) {
			continue;
		}
		
		if(i == g_PlayerData[index][NextClass])
		{
			formatex(text, charsmax(text), "\d%s", class_info[c_Name]);
		}
		else
		{
			if(class_info[c_Flag] == FLAG_VIP && !IsVIP(index)) {
				formatex(text, charsmax(text), "%s\r [V.I.P]", class_info[c_Name]);
			}
			else {
				formatex(text, charsmax(text), "%s", class_info[c_Name]);
			}
		}
		
		item[0] = i;
		menu_additem(menu, text, item);
	}
	
	formatex(text, charsmax(text), "%L", index, "MENU_BACK");
	menu_setprop(menu, MPROP_BACKNAME, text);
	formatex(text, charsmax(text), "%L", index, "MENU_NEXT");
	menu_setprop(menu, MPROP_NEXTNAME, text);
	formatex(text, charsmax(text), "%L", index, "MENU_EXIT");
	menu_setprop(menu, MPROP_EXITNAME, text);
	
	g_PlayerData[index][MenuPage] = min(g_PlayerData[index][MenuPage], menu_pages(menu)-1);
	menu_display(index, menu, g_PlayerData[index][MenuPage]);
}

public menu_zclass(index, menu, item) {
	if(item == MENU_EXIT) {
		g_PlayerData[index][MenuPage] = 0;
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	g_PlayerData[index][MenuPage] = item / 7;
	
	new access, info[2];
	menu_item_getinfo(menu, item, access, info, charsmax(info), _, _, access);
	menu_destroy(menu);
	
	new classid = info[0];
	new class_info[ClassData]; ArrayGetArray(g_aClass, classid, class_info);
	
	if(class_info[c_Flag] == FLAG_VIP && !IsVIP(index)) {
		return PLUGIN_HANDLED;
	}
	
	g_PlayerData[index][NextClass] = classid;
	
	client_print(index, print_chat, "%L: %s", index, "ZOMBIE_SELECT", class_info[c_Name]);
	client_print(index, print_chat, "Health: %.2f | Speed: %.2f | Gravity: %.2f | Knockback: %.2f",
	class_info[c_Health], class_info[c_Speed], class_info[c_Gravity],  class_info[c_Knockback]);
	
	return PLUGIN_HANDLED;
}