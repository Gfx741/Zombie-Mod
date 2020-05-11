#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>
#include <reapi>
#include <zombiemod_core>
#include <zombiemod_class_zombie>
#include <zombiemod_modes>
#include <zombiemod_addon_freeze>
#include <skillmanager>
#include <effects_util>

#pragma semicolon                    1

#define PLUGIN_NAME                  "[ZM] Class zombie: Light"
#define PLUGIN_VERS                  "1.1.0"
#define PLUGIN_AUTH                  "CROCK"

#define IsPlayer(%0)		(%0 && %0 <= MaxClients)
#define IsZombieLight(%1)	(zm_class_index_zombie(%1) == g_iClassLight)

#define R	224
#define G	102
#define B	255
#define A 	150
#define BallDamage		25.0
#define BallSpeed		1800.0
#define BallLifeTime	20.0
#define BallBodyWorld	1

new const BALL_CNAME[] = "ball";
new const BALL_MODEL[] = "models/a4bd3_models/ball.mdl";
new const BALL_SOUND[][] = {
	"weapons/electro4.wav",
	"weapons/gauss2.wav",
	"weapons/ric_conc-2.wav"
};

new Float:g_fNextCheckTime[MAX_PLAYERS+1];
new g_iClassLight;

public plugin_precache()
{
	g_iClassLight = zm_register_class_zombie
	(
		.Flag = FLAG_NONE,
		.Name = "Light",
		.PlayerModel = "a4bd3_0n",			/*"a4bd3_5l",*/
		.PlayerModelBody = 1,
		.ClawModel = "models/a4bd3_models/zmh/v_zmhand_v6_2.mdl",
		.ClawBody = 1,
		.ClawAnim = 0,
		.BombBody = 13,
		.BombAnim = 14,
		.Health = 3000.0,
		.Speed = 380.0,
		.Gravity = 0.6,
		.FactorDamage = 1.0,
		.BulletDefence = 1.0,
		.GrenadeDefence = 1.0,
		.Knockback = 1.0
	);
	
	precache_model(BALL_MODEL);
	precache_sound(BALL_SOUND[0]);
	precache_sound(BALL_SOUND[1]);
	precache_sound(BALL_SOUND[2]);
}

public plugin_init() {
	register_plugin(PLUGIN_NAME, PLUGIN_VERS, PLUGIN_AUTH);	

	register_touch(BALL_CNAME, "*", "Engine_TouchBall");
	register_think(BALL_CNAME, "Engine_ThinkBall");
}

public zm_infect_post(index, attacker) {
	if(IsZombieLight(index))
	{
		//test_set_view_body(iIndex, 0, 6, 1, 13);
		
		sm_set_skill(index, IN_ATTACK2, 0.5, 1, 1);
		client_print(index, print_chat, "Class: Light");
	}
}

public sm_skill_start(index, bool:bFirstFrame, bool:bSkillActivated/*, bool:bBarTimeStarted*/  )
{
	if(IsZombieLight(index))
	{
		if(get_member(index, m_afButtonPressed) & IN_ATTACK)
		{
			return 0;
		}
		
		/*
		if(bBarTimeStarted)
		{
			emit_sound(index, CHAN_WEAPON, BALL_SOUND[0], 1.0, ATTN_NORM, 0, PITCH_NORM);
		}
		*/
		
		new item = get_member(index, m_pActiveItem);
		if(WEAPON_KNIFE != get_member(item, m_iId))
		{
			return 0;
		}
		
		if(get_member(item, m_Weapon_flNextSecondaryAttack) <= 0.1)
		{
			set_member(item, m_Weapon_flNextSecondaryAttack, 1.05);
		}
		
		if(bSkillActivated)
		{
			if(!(get_member(index, m_afButtonReleased) & IN_ATTACK2))
			{
				static Float:gameTime; gameTime = get_gametime();
				
				if(gameTime < g_fNextCheckTime[index])
				{
					return 0;
				}
				else
				{
					g_fNextCheckTime[index] = gameTime + 0.1;
				}
				
				new Float:pos[coord]; get_entvar(index, var_origin, pos);
				_te_dlight(pos, .radius=15, .r=R, .g=G, .b=B, .life=3, .decayRate=1);
				
				return 0;
			}
			
			emit_sound(index, CHAN_BODY, BALL_SOUND[1], 1.0, ATTN_NORM, 0, PITCH_NORM);
			
			_player_anim(index, "ref_shoot_grenade");
			
			createBall(index);
		}
		return 1;
	}
	return 0;
}

createBall(index)
{
	new Float:vec_start[3]; get_entvar(index, var_origin, vec_start);
	new Float:view_ofs[3]; get_entvar(index, var_view_ofs, view_ofs);
	xs_vec_add(vec_start, view_ofs, vec_start);
	
	new end_of_view[3]; get_user_origin(index, end_of_view, 3);
	new Float:vec_end[3]; IVecFVec(end_of_view, vec_end);
	
	new Float:velocity[3]; xs_vec_sub(vec_end, vec_start, velocity);
	new Float:normal[3]; xs_vec_normalize(velocity, normal);
	xs_vec_mul_scalar(normal, BallSpeed, velocity);
	
	new ent = rg_create_entity("info_target");
	
	set_entvar(ent, var_classname, BALL_CNAME);
	set_entvar(ent, var_owner, index);
	set_entvar(ent, var_movetype, MOVETYPE_BOUNCEMISSILE);
	set_entvar(ent, var_solid, SOLID_BBOX);
	set_entvar(ent, var_fuser1, get_gametime() + BallLifeTime);
	set_entvar(ent, var_nextthink, get_gametime() + 0.1);
	
	set_entvar(ent, var_body, BallBodyWorld);
	
	engfunc(EngFunc_SetModel, ent, BALL_MODEL);
	engfunc(EngFunc_SetOrigin, ent, vec_start);
	engfunc(EngFunc_SetSize, ent, Float:{-3.0, -3.0, -3.0}, Float:{3.0, 3.0, 3.0});
	
	_set_rendering(ent, kRenderFxGlowShell, R, G, B, kRenderNormal, A);
	
	set_entvar(ent, var_velocity, velocity);
}
public Engine_TouchBall(ent, toucher)
{
	if(is_nullent(ent))
	{
		return PLUGIN_CONTINUE;
	}
	
	if(IsPlayer(toucher) && BallTakeDamage(ent, toucher))
	{
		return PLUGIN_CONTINUE;
	}
	
	emit_sound(ent, CHAN_WEAPON, BALL_SOUND[2], 1.0, ATTN_NORM, 0, PITCH_NORM);
	
	new Float:velocity[3]; get_entvar(ent, var_velocity, velocity);
	xs_vec_mul_scalar(velocity, 0.85, velocity);
	set_entvar(ent, var_velocity, velocity);
	
	return PLUGIN_CONTINUE;
}

BallTakeDamage(ball, player)
{
	new owner = get_entvar(ball, var_owner);
	if(is_user_connected(owner))
	{
		if(is_user_alive(player))
		{
			new Float:pos[coord]; get_entvar(player, var_origin, pos);
			_te_particlebust(pos, .radius=50, .color=70, .life=3);
			
			new Float:velocity[3]; get_entvar(ball, var_velocity, velocity);
			set_pev(player, pev_velocity, velocity);
			
			if(zm_is_zombie(player))
			{
				return 0;
			}
			
			if(zm_get_alive_humans() > 1 && zm_allow_infection() && get_entvar(player, var_health) <= BallDamage)
			{
				zm_set_infect(player, owner);
				return 0;
			}
			
			ExecuteHamB(Ham_TakeDamage, player, ball, owner, BallDamage, 0);
			
			// drop weapon
			
			ad_set_freeze(player, 10.0, 0, 0, 0, R, G, B);
			
			engfunc(EngFunc_RemoveEntity, ball);
			return 1;
		}
	}
	return 0;
}

public Engine_ThinkBall(ent)
{
	new Float:gametime = get_gametime();
	if(gametime >= get_entvar(ent, var_fuser1) || !zm_round_started())
	{
		new Float:pos[coord]; get_entvar(ent, var_origin, pos);
		_te_explosion2(pos);
		
		set_entvar(ent, var_flags, get_entvar(ent, var_flags) | FL_KILLME);
		return;
	}
	
	set_entvar(ent, var_nextthink, gametime + 0.1);
}