#include <amxmodx>
#include <zombiemod_class_human>

#pragma semicolon 1

#define PLUGIN_NAME                  "[ZM] Class human: Human"
#define PLUGIN_VERS                  "1.0.0"
#define PLUGIN_AUTH                  "CROCK"

new g_iClassHuman;

public plugin_precache() {
	g_iClassHuman = zm_register_class_human
	(
		.Name = "Survivor",
		.PlayerModel = "a4bd3_01h",
		.PlayerModelBody = 15,
		.Health = 50.0,
		.Speed = 0.0,
		.Gravity = 1.0
	);
}

public plugin_init() {
	register_plugin(PLUGIN_NAME, PLUGIN_VERS, PLUGIN_AUTH);	
}