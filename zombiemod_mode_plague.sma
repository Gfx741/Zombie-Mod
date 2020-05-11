#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>
#include <reapi>
#include <zombiemod_core>
#include <zombiemod_class_zombie>
#include <zombiemod_class_human>
#include <zombiemod_modes>
#include <skillmanager>
#include <effects_util>

#pragma semicolon 1

#define PLUGIN_NAME                  "[ZM] Mode: Plague"
#define PLUGIN_VERS                  "1.0.0"
#define PLUGIN_AUTH                  "CROCK"

#define IsPlayer(%0)		(%0 && %0 <= MaxClients)
#define ClassNemesis(%1)	(zm_class_index_zombie(%1) == g_iClassNemesis)
#define ClassSurvivor(%1)	(zm_class_index_human(%1) == g_iClassSurvivor)

#define StingDamage		100.0
#define StingSpeed		2000.0
#define StingLifeTime	5.0
#define StingBodyWorld	1

new const STING_CNAME[] = "sting";
new const STING_MODEL[] = "models/a4bd3_models/ball.mdl";
new const STING_SOUND[][] = {
	"a4bd3_s/nemesis/deimos_skill_start.wav",
	"a4bd3_s/nemesis/deimos_skill_hit.wav"
};

new g_iModePlague;
new g_iClassNemesis, g_iClassSurvivor;

new g_iSprFollow, g_iSprExplo;

public plugin_precache() {
	g_iClassSurvivor = zm_register_class_human
	(
		.Name = "Survivor",
		.PlayerModel = "a4bd3_01h",
		.PlayerModelBody = 17,
		.Health = 200.0,
		.Speed = 300.0,
		.Gravity = 0.8
	);
	
	g_iClassNemesis = zm_register_class_zombie
	(
		.Flag = FLAG_DONT_SHOW,
		.Name = "Nemesis",
		.PlayerModel = "a4bd3_0n",
		.PlayerModelBody = 0,
		.ClawModel = "models/a4bd3_models/zmh/v_zmhand_v1.mdl",
		.ClawBody = 9,
		.ClawAnim = 12,
		.BombBody = 43,
		.BombAnim = 22,
		.Health = 2000.0,
		.Speed = 300.0,
		.Gravity = 0.7,
		.FactorDamage = 2.5,
		.BulletDefence = 1.00,
		.GrenadeDefence = 1.0,
		.Knockback = 0.5
	);
	
	g_iSprFollow = precache_model("sprites/laserbeam.spr");
	g_iSprExplo = precache_model("sprites/a4bd3_sprites/stingexplosion.spr");
	
	precache_model(STING_MODEL);
	precache_sound(STING_SOUND[0]);
	precache_sound(STING_SOUND[1]);
}

public plugin_init() {
	register_plugin(PLUGIN_NAME, PLUGIN_VERS, PLUGIN_AUTH);	
    
	register_touch(STING_CNAME, "*", "Engine_TouchSting");
	register_think(STING_CNAME, "Engine_ThinkSting");
	
	RegisterHookChain(RG_CBasePlayer_Killed, "RG_CBasePlayer_Killed_Post", true);
	
	g_iModePlague = zm_register_mode
	(
		.Name = "ZM_MODE_PLAGUE",
		.Chance = 2,
		.MinPlayers = 8,
		.AllowInfection = 0,
		.DeathMatch = 1
	);
}

public zm_infect_post(index, attacker) {
	if(ClassNemesis(index))
	{
		sm_set_skill(index, IN_RELOAD, 0.0, 0, 5);
		client_print(index, print_chat, "Class: Light");
	}
}

public sm_skill_start(index, bool:bFirstFrame, bool:bSkillActivated/*, bool:bBarTimeStarted*/  )
{
	if(zm_is_zombie(index) && ClassNemesis(index))
	{
		if(bSkillActivated)
		{
			emit_sound(index, CHAN_BODY, STING_SOUND[0], 1.0, ATTN_NORM, 0, PITCH_NORM);
			
			_player_anim(index, "zbs_skill_idle");
			createSting(index);
		}
		return 1;
	}
	return 0;
}

createSting(index)
{
	new Float:vec_start[3]; get_entvar(index, var_origin, vec_start);
	new Float:view_ofs[3]; get_entvar(index, var_view_ofs, view_ofs);
	view_ofs[2] += 10;
	xs_vec_add(vec_start, view_ofs, vec_start);
	
	new end_of_view[3]; get_user_origin(index, end_of_view, 3);
	new Float:vec_end[3]; IVecFVec(end_of_view, vec_end);
	
	new Float:velocity[3]; xs_vec_sub(vec_end, vec_start, velocity);
	new Float:normal[3]; xs_vec_normalize(velocity, normal);
	xs_vec_mul_scalar(normal, StingSpeed, velocity);
	
	new ent = rg_create_entity("info_target");
	
	set_entvar(ent, var_classname, STING_CNAME);
	set_entvar(ent, var_owner, index);
	set_entvar(ent, var_movetype, MOVETYPE_BOUNCEMISSILE);
	set_entvar(ent, var_solid, SOLID_BBOX);
	set_entvar(ent, var_fuser1, get_gametime() + StingLifeTime);
	set_entvar(ent, var_nextthink, get_gametime() + 0.1);
	
	set_entvar(ent, var_body, StingBodyWorld);
	
	engfunc(EngFunc_SetModel, ent, STING_MODEL);
	engfunc(EngFunc_SetOrigin, ent, vec_start);
	engfunc(EngFunc_SetSize, ent, Float:{-3.0, -3.0, -3.0}, Float:{3.0, 3.0, 3.0});
	
	set_entvar(ent, var_velocity, velocity);
	
	_te_beamfollow
	(
		.entindex=ent,
		.sprite=g_iSprFollow,
		.life=3,
		.width=10,
		.r=200,
		.g=100,
		.b=0,
		.a=200
	);
}

public Engine_TouchSting(ent, toucher)
{
	if(is_nullent(ent))
	{
		return PLUGIN_CONTINUE;
	}
	
	if(IsPlayer(toucher))
	{
		new owner = get_entvar(ent, var_owner);
		if(is_user_connected(owner))
		{
			if(is_user_alive(toucher))
			{
				if(!zm_is_zombie(toucher))
				{
					ExecuteHamB(Ham_TakeDamage, toucher, ent, owner, StingDamage, 0);
					// drop weapon
				}
			}
		}
	}
	
	new Float:pos[coord]; get_entvar(ent, var_origin, pos);
	_te_explosion(pos, .sprite=g_iSprExplo, .scale=30, .frameRate=15, .flags=14);
	emit_sound(ent, CHAN_WEAPON, STING_SOUND[1], 1.0, ATTN_NORM, 0, PITCH_NORM);
	
	engfunc(EngFunc_RemoveEntity, ent);
	return PLUGIN_CONTINUE;
}

public Engine_ThinkSting(ent)
{
	new Float:gametime = get_gametime();
	if(gametime >= get_entvar(ent, var_fuser1))
	{
		new Float:pos[coord]; get_entvar(ent, var_origin, pos);
		_te_explosion2(pos);
		
		set_entvar(ent, var_flags, get_entvar(ent, var_flags) | FL_KILLME);
		return;
	}
	
	set_entvar(ent, var_nextthink, gametime + 0.1);
}

public zm_last_zombie_disconnected(index, randomHuamnIndex) {
	if(ClassNemesis(index)) {
		new old_class = zm_class_index_zombie(randomHuamnIndex);
		
		zm_set_next_class_zombie(randomHuamnIndex, g_iClassNemesis);
		zm_set_infect(randomHuamnIndex);
		zm_set_next_class_zombie(randomHuamnIndex, old_class);
		
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}

public zm_last_huamn_disconnected(index, randomZombieIndex) {
	if(ClassSurvivor(index)) {
		new old_class = zm_class_index_human(randomZombieIndex);
		
		zm_set_next_class_human(randomZombieIndex, g_iClassSurvivor);
		zm_set_cure(randomZombieIndex);
		zm_set_next_class_human(randomZombieIndex, old_class);
		
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}

public zm_selected_mode(mode)
{
	if(mode == g_iModePlague)
	{
		new playersArray[MAX_PLAYERS], playersNum = _get_players(playersArray, true);
		new randomIndex;
		
		new survivor_count = 1; // add cvar
		new nemesis_count = 1; // add cvar
		new old_class = -1;
		
		new maxNemesis = nemesis_count;
		while(maxNemesis)
		{
			randomIndex = playersArray[random(playersNum)];
			
			if(zm_is_zombie(randomIndex)) {
				continue;
			}
			
			old_class = zm_class_index_zombie(randomIndex);
			zm_set_next_class_zombie(randomIndex, g_iClassNemesis);
			zm_set_infect(randomIndex);
			zm_set_next_class_zombie(randomIndex, old_class);
			
			maxNemesis--;
		}
		
		new maxSurvivors = survivor_count;
		while(maxSurvivors)
		{
			randomIndex = playersArray[random(playersNum)];
			
			if(zm_is_zombie(randomIndex) || ClassSurvivor(randomIndex)) {
				continue;
			}
			
			old_class = zm_class_index_human(randomIndex);
			
			zm_set_next_class_human(randomIndex, g_iClassSurvivor);
			zm_set_cure(randomIndex, 0, .countInfected = 0, .countHumans = 0);
			zm_set_next_class_human(randomIndex, old_class);
			maxSurvivors--;
		}
		
		new maxZombies = floatround(playersNum * 0.5, floatround_ceil);
		while(maxZombies)
		{
			randomIndex = playersArray[random(playersNum)];
							
			if(zm_is_zombie(randomIndex) || ClassSurvivor(randomIndex)) {
				continue;
			}
			
			zm_set_infect(randomIndex);
			maxZombies--;
		}
		
		for(new i = 0, index; i < playersNum; i++)
		{
			index = playersArray[i];
			
			if(zm_is_zombie(index) || ClassSurvivor(index)) {
				continue;
			}
				
			rg_set_user_team(index, TEAM_CT, MODEL_UNASSIGNED);
		}
		set_dhudmessage(0, 100, 200, -1.0, 0.17, 0, 0.0, 5.0, 1.0, 1.0);
		show_dhudmessage(0, "Plague Round!");
	}
}

public RG_CBasePlayer_Killed_Post(victim, attacker) {
	if(victim == attacker || !is_user_alive(attacker)) {
		return;
	}
	
	if(ClassNemesis(victim)) {
		client_print(0, print_chat, "Nemesis zdoh!");
	}
	else if(ClassSurvivor(victim)) {
		client_print(0, print_chat, "Survivor zdoh!");
	}
	
	if(ClassNemesis(attacker) || ClassSurvivor(attacker)) {
		new Float:pos[coord]; get_entvar(victim, var_origin, pos);
		_te_lavasplash(pos);
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