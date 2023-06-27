#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION	"1.0.2"

bool is_valid_client_index(int client)
{
	return client >= 1 && client <= MaxClients;
}

bool is_valid_client_at_team(int client, int team)
{
	return is_valid_client_index(client) && IsClientInGame(client) && GetClientTeam(client) == team;
}

bool is_get_staggerd(int client)
{
	return GetEntPropFloat(client, Prop_Send, "m_staggerTimer", 1) > -1.0;
}

public Action OnPlayerRunCmd(int client, int& buttons)
{
    if(is_valid_client_at_team(client, 3) && IsPlayerAlive(client) && IsFakeClient(client) && is_get_staggerd(client))
    {
        buttons &= ~IN_ATTACK2;
    }
    return Plugin_Continue;
}

public void OnPluginStart()
{
    CreateConVar("special_intecteds_stagger_attack_fix_version", PLUGIN_VERSION, "version of \"special_intecteds_stagger_attack_fix\"", FCVAR_DONTRECORD);
}