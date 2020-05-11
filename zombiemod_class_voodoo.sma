#include <amxmodx>
#include <engine>
#include <hamsandwich>
#include <reapi>
#include <zombiemod_core>
#include <zombiemod_class_zombie>
#include <zombiemod_modes>
#include <effects_util>
#include <skillmanager>

#pragma semicolon	1

#define PLUGIN_NAME		"[ZM] Class zombie: Voodoo"
#define PLUGIN_VERS		"1.0.0"
#define PLUGIN_AUTH		"CROCK"

#define WAVE_DAMAGE		10.0
#define WAVE_RADIUS		300.0
#define WAVE_LIFETIME	2.0

#define IsZombieVoodoo(%1) (zm_class_index_zombie(%1) == g_iClassVoodoo)

new const WAVE_CLASSNAME[] = "wave";
new const WAVE_SOUND[] = "a4bd3_s/zm_ability/voodoo_scream.wav";

new g_iClassVoodoo;
new g_iSprCylinder;

public plugin_precache() {
	g_iClassVoodoo = zm_register_class_zombie
	(
		.Flag = FLAG_NONE,
		.Name = "Voodoo",
		.PlayerModel = "a4bd3_2v",
		.PlayerModelBody = 0,
		.ClawModel = "models/a4bd3_models/zmh/v_zmhand_v1.mdl",
		.ClawBody = 7,
		.ClawAnim = 6,
		.BombBody = 64,
		.BombAnim = 26,
		.Health = 3000.0,
		.Speed = 280.0,
		.Gravity = 1.0,
		.FactorDamage = 2.0,
		.BulletDefence = 0.80,
		.GrenadeDefence = 1.0,
		.Knockback = 1.0
	);
	
	precache_sound(WAVE_SOUND);
	g_iSprCylinder = precache_model("sprites/shadow_circle.spr");
}

public plugin_init() {
	register_plugin(PLUGIN_NAME, PLUGIN_VERS, PLUGIN_AUTH);	
	
	register_think(WAVE_CLASSNAME, "Engine_ThinkWave");
}

public zm_infect_post(index, attacker) {
	if(IsZombieVoodoo(index))
	{
		sm_set_skill(index, IN_RELOAD, 0.0, 1, 15);
		client_print(index, print_chat, "Class: Voodooo");
	}
}

public sm_skill_start(index, bool:bFirstFrame, bool:bSkillActivated)
{
	if(IsZombieVoodoo(index))
	{
		if(bSkillActivated)
		{
			createWave(index);
		}
		return 1;
	}
	return 0;
}

createWave(index)
{
	new ent = rg_create_entity("info_target");
	
	set_entvar(ent, var_classname, WAVE_CLASSNAME);
	set_entvar(ent, var_movetype, MOVETYPE_FOLLOW);
	set_entvar(ent, var_aiment, index);
	set_entvar(ent, var_owner, index);
	
	set_entvar(ent, var_fuser1, get_gametime() + WAVE_LIFETIME);
	set_entvar(ent, var_nextthink, get_gametime() + 0.1);
}

public Engine_ThinkWave(ent)
{
	new Float:gametime = get_gametime();
	new owner = get_entvar(ent, var_owner);
	
	if( ( gametime >= get_entvar(ent, var_fuser1) ) || !is_user_alive(owner) || !zm_is_zombie(owner) || !zm_round_started())
	{
		set_entvar(ent, var_flags, get_entvar(ent, var_flags) | FL_KILLME);
		return;
	}
	
	enum posData
	{
		voodoo = 0,
		target
	};
	new Float:pos[posData][3]; get_entvar(owner, var_origin, pos[voodoo]);
	
	_te_beamcylinder
	(
		pos[voodoo],
		.radius = WAVE_RADIUS,
		.sprite = g_iSprCylinder,
		.startFrame = 0,
		.frameRate = 0, 
		.life = 4,
		.width = 60,
		.noise = 60,
		.r = 200,
		.g = 10,
		.b = 0,
		.a = 200,
		.scrollSpeed=0
	);
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(!is_user_alive(i) || zm_is_zombie(i))
		{
			continue;
		}
		
		get_entvar(i, var_origin, pos[target]);
		if(get_distance_f(pos[voodoo], pos[target]) > WAVE_RADIUS)
		{
			continue;
		}
		
		if(zm_get_alive_humans() > 1 && zm_allow_infection() && get_entvar(i, var_health) <= WAVE_DAMAGE)
		{
			zm_set_infect(i, owner);
		}
		
		ExecuteHam(Ham_TakeDamage, i, ent, owner, WAVE_DAMAGE, 0);
	}
	
	set_entvar(ent, var_nextthink, gametime + 0.1);
}