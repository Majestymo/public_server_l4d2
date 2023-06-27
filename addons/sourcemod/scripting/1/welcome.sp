#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>   
#include <colors>
#include <l4d2_playtime_interface>
#include <geoip>

char
    authId[65],
    country[3],
    city[32],
    Admin[32],
    Player[32],
    ip[32];

ConVar
    EnablePlugin,
    ShowPlayTime,
    ShowCountry,
    ShowCity,
    ShowIdentity;

public Plugin myinfo =    
{   
    name = "Show Your PlayTime",   
    author = "A1R, blueblur",   
    description = "Show the players real play time and their region.",   
    version = "3.0",   
    url = "https://github.com/A1oneR/AirMod/blob/main/addons/sourcemod/scripting/Welcome.sp (Original version)"
};
/*
  1.0
    - Initial version from A1R.
  2.0
    - Optimized Codes, added conutry display, added translations supports.
  2.1
    - Optimized Codes, added more expression.
  2.2
    - Fix codes, added city expression.
  2.2.1
    - Fiexes.
  3.0
    - Add Cvars to control the output.
*/

public void OnPluginStart()
{   
    EnablePlugin = CreateConVar("l4d2_enable_welcome", "1", "Enable plugin or not", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    ShowPlayTime = CreateConVar("l4d2_show_welcome_playtime", "1", "Enable playtime output", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    ShowCountry = CreateConVar("l4d2_show_welcome_country", "1", "Enable country output", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    ShowCity = CreateConVar("l4d2_show_welcome_city", "1", "Enable city output", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    ShowIdentity = CreateConVar("l4d2_show_welcome_identity", "1", "Enable Identity output", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    RegConsoleCmd("sm_playerinfo", Player_Time_Country);
    LoadTranslations("welcome.phrases");
    CheckEnableStatus();
} 

public Action CheckEnableStatus()
{
    if (!GetConVarBool(EnablePlugin))
    {
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public void OnClientConnected(int client)   
{       
    int playtime = L4D2_GetTotalPlaytime(authId, true) / 60 / 60;
    bool b_PlayerIdentity = !PlayerIdentity();
    Format(Admin, sizeof(Admin), "%t", "Admin");
    Format(Player, sizeof(Player), "%t", "Player");
    if(!IsFakeClient(client))
    {
        if(playtime > 0 && GetConVarBool(ShowPlayTime))
        {
            CPrintToChatAll("%t", "ConnectingWithHours", (b_PlayerIdentity ? Player : Admin), client, playtime);           //[{orange}!{default}] %s{olive} %N [{olive}%iHours{default}] is connecting...
        }
        else
        {
            CPrintToChatAll("%t", "Connecting", (b_PlayerIdentity ? Player : Admin), client);             //[{orange}!{default}] %s{olive} %N {default}正在连接中...
        }
    }
}

public void OnClientPutInServer(int client)
{
    int playtime;
    bool b_PlayerIdentity = !PlayerIdentity();
    if(GetConVarBool(ShowPlayTime))
    {
        playtime = L4D2_GetTotalPlaytime(authId, true) / 60 / 60;
    }
    else
    {
        playtime = 0;
    }

    GetClientIP(client, ip, sizeof(ip));
    GetClientAuthId(client, AuthId_Steam2, authId, sizeof(authId));
    GeoipCode2(ip, country);
    GeoipCity(ip, city, sizeof(city));
    Format(Admin, sizeof(Admin), "%t", "Admin");
    Format(Player, sizeof(Player), "%t", "Player");
    if(!IsFakeClient(client))
    {
        if(playtime > 0)
        {
            if(GetConVarBool(ShowCountry) && GetConVarBool(ShowCity))
            {
                if(GeoipCode2(ip, country) && GeoipCity(ip, city, sizeof(city)))
                {
                    CPrintToChatAll("%t", "ConnectedWithHours_City_Country", (b_PlayerIdentity ? Player : Admin), client, playtime, country, city);            //[{orange}!{default}] %s{olive} %N {default} [{olive}%i 小时{default}] 进入了服务器, 来自[{olive}%s{default}, {olive}%s{default}].
                }
                else
                {
                    CPrintToChatAll("%t", "ConnectedWithHours", (b_PlayerIdentity ? Player : Admin), client, playtime);             //[{orange}!{default}] %s{olive} %N {default}[{olive}%i 小时{default}] 进入了服务器.
                }
            }
            else if(GetConVarBool(ShowCountry))
            {
                if(GeoipCode2(ip, country))
                {
                    CPrintToChatAll("%t", "ConnectedWithHours_City_Or_Country", (b_PlayerIdentity ? Player : Admin), client, playtime, country);          //[{orange}!{default}] %s{olive} %N {default}[{olive}%i 小时{default}] 进入了服务器, 来自[{olive}%s{default}].
                }
                else
                {
                    CPrintToChatAll("%t", "ConnectedWithHours", (b_PlayerIdentity ? Player : Admin), client, playtime);             //[{orange}!{default}] %s{olive} %N {default}[{olive}%i 小时{default}] 进入了服务器.
                }
            }
            else if(GetConVarBool(ShowCity))
            {
                if(GeoipCity(ip, city, sizeof(city)))
                {
                    CPrintToChatAll("%t", "ConnectedWithHours_City_Or_Country", (b_PlayerIdentity ? Player : Admin), client, playtime, city);         //[{orange}!{default}] %s{olive} %N {default}[{olive}%i 小时{default}] 进入了服务器, 来自 [{olive}%s{default}].
                }
                else
                {
                    CPrintToChatAll("%t", "ConnectedWithHours", (b_PlayerIdentity ? Player : Admin), client, playtime);             //[{orange}!{default}] %s{olive} %N {default}[{olive}%i 小时{default}] 进入了服务器.
                }
            }
            else
            {
                CPrintToChatAll("%t", "ConnectedWithHours", (b_PlayerIdentity ? Player : Admin), client, playtime);             //[{orange}!{default}] %s{olive} %N {default}[{olive}%i 小时{default}] 进入了服务器.
            }
        }
        else
        {
            if(GetConVarBool(ShowCountry) && GetConVarBool(ShowCity))
            {
                if(GeoipCode2(ip, country) && GeoipCity(ip, city, sizeof(city)))
                {
                    CPrintToChatAll("%t", "ConnectedWithCountry_City", (b_PlayerIdentity ? Player : Admin), client, country, city);            //[{orange}!{default}] %s{olive} %N {default}进入了服务器, 来自[{olive}%s{default}, {olive}%s{default}].
                }
                else
                {
                    CPrintToChatAll("%t", "Connected", (b_PlayerIdentity ? Player : Admin), client);             //[{orange}!{default}] %s{olive} %N {default} 进入了服务器.
                }
            }
            else if(GetConVarBool(ShowCountry))
            {
                if(GeoipCode2(ip, country))
                {
                    CPrintToChatAll("%t", "ConnectedWith_City_Or_Country", (b_PlayerIdentity ? Player : Admin), client, country);          //[{orange}!{default}] %s{olive} %N {default}进入了服务器, 来自[{olive}%s{default}].
                }
                else
                {
                    CPrintToChatAll("%t", "Connecte", (b_PlayerIdentity ? Player : Admin), client);             //[{orange}!{default}] %s{olive} %N {default} 进入了服务器.
                }
            }
            else if(GetConVarBool(ShowCity))
            {
                if(GeoipCity(ip, city, sizeof(city)))
                {
                    CPrintToChatAll("%t", "ConnectedWith_City_Or_Country", (b_PlayerIdentity ? Player : Admin), client, city);         //[{orange}!{default}] %s{olive} %N {default}进入了服务器, 来自 [{olive}%s{default}].
                }
                else
                {
                    CPrintToChatAll("%t", "Connected", (b_PlayerIdentity ? Player : Admin), client);             //[{orange}!{default}] %s{olive} %N {default} 进入了服务器.
                }
            }
            else
            {
                CPrintToChatAll("%t", "Connected", (b_PlayerIdentity ? Player : Admin), client);             //[{orange}!{default}] %s{olive} %N {default} 进入了服务器.
            }
        }
    }
}

public Action Player_Time_Country(int client, int args)
{
    char id[64];
    for (int i = 1 ; i <= MaxClients ; i++)
    {
        GetClientAuthId(i, AuthId_Steam2, id, sizeof(id));
        if(IsClientConnected(i) && IsClientInGame(i))
	    {
            int playtime = L4D2_GetTotalPlaytime(authId, true) / 60 / 60;
            GetClientIP(client, ip, sizeof(ip));
            GeoipCode2(ip, country);
            GeoipCity(ip, city, sizeof(city));
            GetClientAuthId(i, AuthId_Steam2, authId, sizeof(authId));
	        if(!StrEqual(id, "BOT"))
            {
	            if(playtime > 0 && GeoipCode2(ip, country))
                {
                    CPrintToChat(client, "%t", "RequestTimeAndRegion", i, playtime, country, city);            //[{orange}!{default}] 玩家{olive} %N {default}已游玩 [{olive}%i{default}] 小时, 来自 [{olive}%s{default}, {olive}%s{default}] 地区.
                    return Plugin_Handled;
                }
                else if(playtime > 0)
                {
                    CPrintToChat(client, "%t", "RequestTime", i, playtime);          //[{orange}!{default}] 玩家{olive} %N {default}已游玩 [{olive}%i{default}] 小时, 来自 [{red}未知{default}] 地区.
                    return Plugin_Handled;
                }
                else if(GeoipCode2(ip, country))
                {
                    CPrintToChat(client, "%t", "RequestRegion", i, country, city);                //[{orange}!{default}] 玩家{olive} %N {default}已游玩 [{red}未知{default}] 小时, 来自 [{olive}%s{default}, {olive}%s{default}] 地区.
                    return Plugin_Handled;
                }
	            else
                {
	                CPrintToChat(client, "%t", "RequestFailed", i);             //[{orange}!{default}] 玩家{olive} %N {default}已游玩 [{red}未知{default}] 小时, 来自 [{red}未知{default}] 地区.
                }
            }
        }
    }
    return Plugin_Handled;
}

stock bool PlayerIdentity()
{
    int client;
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientConnected(i) && IsClientInGame(i))
        {
            if(GetConVarBool(ShowIdentity))
            {
                /*
                *
                *   This Part is from readyup.sp
                */

                // Check if admin always allowed to do so
		        AdminId id = GetUserAdmin(client);
		        if (id != INVALID_ADMIN_ID && GetAdminFlag(id, Admin_Ban)) // Check for specific admin flag
		        {
			        return true;
		        }
            }
        }
    }
    return false;
}
