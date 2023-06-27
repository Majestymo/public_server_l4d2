#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION "1.0"

public Plugin:myinfo=
{
	name = "禁止玩家在游戏内改名",
	author = "star",
	description = "禁止玩家在游戏内改名",
	version = PLUGIN_VERSION,
	url = ""
};

new String:PlayerName[MAXPLAYERS+1][MAX_NAME_LENGTH];

public OnPluginStart()
{
	//读取游戏名称
	decl String:game[12];
	GetGameFolderName(game, sizeof(game));
	if (StrContains(game, "left4dead") == -1)
		SetFailState("只能在 Left 4 Dead 1 or 2 运行!"); 
	
	//HOOK事件
	HookEvent("player_changename",		Event_PlayerChangename,	EventHookMode_Pre);	//玩家改名
	//隐藏玩家更名信息
	HookUserMessage(GetUserMessageId("SayText2"), Re_UserName, true, MsgPostHook:INVALID_FUNCTION);
}

/************************************************************************
*
*											服务器读取相关参数
*
************************************************************************/
public OnClientPutInServer(Client)
{
	decl String:user_name[MAX_NAME_LENGTH];
	if (IsValidPlayer(Client, false))
	{
		GetClientName(Client, user_name, sizeof(user_name));
		Format(PlayerName[Client], sizeof(PlayerName), user_name);
	}
}

/************************************************************************
*
*											Event事件相关参数设置
*
************************************************************************/
/* 玩家更改名字*/
public Action:Event_PlayerChangename(Handle:event, String:event_name[], bool:dontBroadcast)
{
	decl String:NewName[256];
	new Client = GetClientOfUserId(GetEventInt(event, "userid"));
	GetEventString(event, "NewName", NewName, sizeof(NewName));
	
	if (!StrEqual(NewName, PlayerName[Client]))
	{
		CreateTimer(0.1, ResetName, Client);
		PrintToChatAll("\x04[提示]\x03%N\x05已被禁止改名!", Client);
		PrintHintTextToAll("[提示] %N 已被禁止改名!", Client);
	}
	return Plugin_Handled;
}

public Action:ResetName(Handle:timer, any:Client)
{
	SetClientInfo(Client, "name", PlayerName[Client]);
	return Plugin_Handled;
}

public Action:Re_UserName(UserMsg:msg_id, Handle:Name, players[], playersNum, bool:reliable, bool:init)
{
	decl String:UserMess[128];
	BfReadString(Name, UserMess, sizeof(UserMess), false);
	BfReadString(Name, UserMess, sizeof(UserMess), false);
	if (StrContains(UserMess, "Name_Change", true) != -1)
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

/************************************************************************
*
*											服务器检测相关参数设置
*
************************************************************************/
/* 判断玩家是否有效 */
stock bool:IsValidPlayer(Client, bool:AllowBot = true, bool:AllowDeath = true)
{
	if (Client < 1 || Client > MaxClients)
		return false;
	if (!IsClientConnected(Client) || !IsClientInGame(Client))
		return false;
	if (!AllowBot)
	{
		if (IsFakeClient(Client))
			return false;
	}
	if (!AllowDeath)
	{
		if (!IsPlayerAlive(Client))
			return false;
	}	
	return true;
}