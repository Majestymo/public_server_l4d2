#pragma semicolon 1
#define DEBUG
#define PLUGIN_VERSION "1.6"
#include <sourcemod>
#include <sdktools>
#include <geoip>
#include <ripext>

#define VALVEURL "IPlayerService/GetOwnedGames/v0001/?format=json&appids_filter[0]=550"
#define VALVEKEY "16579B0017A905C6703DF0752418BABC"

int player_time[MAXPLAYERS+1];
char ClientIP[36];
char country[45];
char city[45];
char region[45];
new String:user_steamid[21];
new Handle:Timer = INVALID_HANDLE;

public Plugin:myinfo =
{
	name = "Connect & Disconnect Info",
	author = "Hoongdou",
	description = "Show SteamID 、Country and IP while Ccnnecting,when leaving the game would print the reasons.",
	version = PLUGIN_VERSION,
	url = ""
};

public OnPluginStart() {
	HookEvent("player_disconnect", playerDisconnect, EventHookMode_Pre);
	HookEvent("player_first_spawn", playerFirstSpwan, EventHookMode_Pre);
	RegConsoleCmd("sm_time", TimeDisplay, "Show time");
}

//显示时间
public OnMapStart()
{
		Timer = CreateTimer(240.0,ShowTimeAndMap,INVALID_HANDLE,TIMER_REPEAT);	
}

Action TimeDisplay(int client, int args)
{
		new String:map_name[46];
		GetCurrentMap(map_name,45);
		new String:time[46];
		FormatTime(time,45,NULL_STRING,GetTime());
		//PrintToChatAll("\x04当前地图：\x03[%s]",map_name);
		//PrintToChatAll("\x04北京时间：\x03[%s]",time);
		return Plugin_Continue;
}

public Action:ShowTimeAndMap(Handle:timer)
{
		new String:map_name[46];
		GetCurrentMap(map_name,45);
		new String:time[46];
		FormatTime(time,45,NULL_STRING,GetTime());
		//PrintToChatAll("\x04当前地图：\x03[%s]",map_name);
		//PrintToChatAll("\x04北京时间：\x03[%s]",time);
		return Plugin_Continue;
}

public OnMapEnd()
{
		KillTimer(Timer);		
}


//时长
public OnClientPostAdminCheck(int client)
{
	decl String:URL[1024];
	decl String:id64[64];
	decl String:id[64];
	GetClientAuthId(client,AuthId_SteamID64,id64,sizeof(id64));
	GetClientAuthId(client,AuthId_Steam2,id,sizeof(id));
	if(StrEqual(id, "BOT")) return;
	HTTPClient httpClient = new HTTPClient("http://api.steampowered.com");
	Format(URL,sizeof(URL),"%s&key=%s&steamid=%s",VALVEURL,VALVEKEY,id64);
	PrintToServer("%s",URL);
	httpClient.Get(URL,OnReceived,client);
}

public void OnReceived(HTTPResponse response, int client)
{
	if (response.Status != HTTPStatus_OK || response.Data == null)
	{
		PrintToServer("Invalid JSON response");
		player_time[client]=0;
		return;
	}
	// go to response body
	JSONObject dataObj = view_as<JSONObject>(view_as<JSONObject>(response.Data).Get("response"));
	
	// invalid json data due to privacy?
	if (!dataObj)
	{
		player_time[client]= 0;
		return;
	}
	if (!dataObj.Size || !dataObj.HasKey("games") || dataObj.IsNull("games"))
	{
		player_time[client]= 0;
		delete dataObj;
		return;
	}
	
	// jump to "games" array section
	JSONArray jsonArray = view_as<JSONArray>(dataObj.Get("games"));
	delete dataObj;
	
	// right here is the data requested
	dataObj = view_as<JSONObject>(jsonArray.Get(0));
	
	// playtime is formatted in minutes
	player_time[client] = dataObj.GetInt("playtime_forever");
	delete jsonArray;
	delete dataObj;
}

//玩家显示
public playerFirstSpwan(Handle:event, const String:name[], bool:dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	GetClientIP(client, ClientIP, 20, true);
	GetClientAuthId(client, AuthId_Steam2, user_steamid, sizeof(user_steamid));
	GeoipCountry(ClientIP, country, sizeof(country));
	GeoipRegion(ClientIP, region, sizeof(region));
	GeoipCity(ClientIP, city, sizeof(city));
	if(!IsFakeClient(client))
	{
	if(player_time[client] == 0)
	PrintToChatAll("\x05%N \x03<%s>\x01加入游戏.\n来自\x04[%s] \x03(%s %s)\x01.游戏时长 \x04未知 ", client, user_steamid, country, region, city);
	else
	PrintToChatAll("\x05%N \x03<%s>\x01加入游戏.\n来自\x04[%s] \x03(%s %s)\x01.游戏时长 \x04%d小时 ", client, user_steamid, country, region, city, player_time[client]/60);
	}
}

public playerDisconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
	SetEventBroadcast(event, true);
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client <= 0 || client > MaxClients) return;
	decl String:steamId[64];
	GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));
	//GetClientAuthString(client, steamId, sizeof(steamId));
	if (strcmp(steamId, "BOT") == 0) return;

	decl String:reason[128];
	GetEventString(event, "reason", reason, sizeof(reason));
	decl String:playerName[128];
	GetEventString(event, "name", playerName, sizeof(playerName));
	decl String:timedOut[256];
	Format(timedOut, sizeof(timedOut), "%s timed out", playerName);
	if (strcmp(reason, "No Steam logon") == 0)
	//PrintToChatAll("\x05%s \x03<%s> \x01离开游戏.\n\x05原因: \x04No Steam logon", playerName, steamId);
	else
	//PrintToChatAll("\x05%s \x03<%s> \x01离开游戏.\n\x05原因: \x04自己主动退出", playerName, steamId);
	/*LogMessage("[Connect Info] Player %s <%s> left the game: %s", playerName, steamId, reason);

	// If the leaving player crashed, pause.
	if (strcmp(reason, timedOut) == 0 || strcmp(reason, "No Steam logon") == 0)
	{
		PrintToChatAll("\x05%s \x01crashed.", playerName);
	}*/
	player_time[client]=0;
}

//no reason:just print disconnected.
/*public OnClientDisconnect(client)
{
	if (!IsFakeClient(client))
	{
		PrintToChatAll("\x05%N \x01disconnected.", client);
	}
}
*/

