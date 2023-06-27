//kill_sound
#pragma semicolon 1
#pragma newdecls required

// 头文件
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

public Plugin myinfo = 
{
	name 			= "击杀/爆头提示音",
	author 			= "夜羽真白",
	description 	= "When killed a common infected or special infected then will announce by a sound, when headshot will display a special sound",
	version 		= "1.0.1.0",
	url 			= "https://steamcommunity.com/id/saku_ra/"
}

#define Team_Survivor 2
#define Team_Infected 3
#define Kill_Sound1 "level/bell_normal.wav"

ConVar g_cEnable;
int g_iEnable;

public void OnPluginStart(){
	g_cEnable = CreateConVar("kill_sound_enable", "1", "是否启用击杀提示音：0 = 关闭， 1 = 启用", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cEnable.AddChangeHook(ConVarChanged_Cvars);
	g_iEnable = g_cEnable.IntValue;

	AutoExecConfig(true, "kill_sound");

	HookEvent("player_death", evt_PlayerDeath);
}

// 地图开始时加载声音文件
public void OnMapStart(){
	PrecacheSound(Kill_Sound1, true);
}

// 杀死特感
public Action evt_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if (0 < attacker <= MaxClients && victim !=0 && !IsFakeClient(attacker) && IsClientInGame(attacker) && GetClientTeam(attacker) == Team_Survivor){
		int ZombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
		if (ZombieClass != 7 && ZombieClass != 8){
			if (g_iEnable == 1)
				EmitSoundToClient(attacker, Kill_Sound1, _, SNDCHAN_AUTO, SNDLEVEL_CONVO, _, SNDVOL_NORMAL);}}
	return Plugin_Handled;
}

public void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue){
	g_iEnable = g_cEnable.IntValue;
}
