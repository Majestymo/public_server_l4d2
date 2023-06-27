/* -------------------CHANGELOG--------------------
4.3
 - Display difficulty if current game mode is in coop and is functioning with confogl (Confogl Vanilla)

4.2
 - Optimized some merged AnneHappy related codes

4.1
 - Fixed a issue the cvar "sn_hostname_format4" covers the effect of the cvar "sn_hostname_format1".

4.0
 - Added AnneHappy support.
   - Added new cvar sn_hostname_format4

3.4
 - Fixed previous support to allow setting separated text file.

3.3
 - Added support for UTF-8 characters via storing hostname from text file

3.2
 - Fixed a bug when the plugin didn`t correctly recognize Confogl availability
 
3.1
 - Removed "empty" field from keyvalues file
 - Added new ConVar: sn_hostname_format3
 
3.0
 - Removed sn_name_format ConVar
 - Removed sn_name_format ConVar
 - Code optimization
 - Added two new ConVars: sn_hostname_format1 and sn_hostname_format2
 
2.5
 - Fixed incorrect convar hook which caused the plugin stuck on vanilla on new Confogl installs
 
2.4
 - Added new requested formatting type
 - Added public version convar

2.3.1
 - Changed one of formatting types (5) as it didn`t look neat before
 - Some code optimizations

2.3
 - Added 3 more formatting types
 - server_namer.txt now only updates on plugin start
 - Fixed game mode not disappearing on empty servers while Confogl match is loaded
 - Some code optimizations

 2.2
 - Added 3 choosable formatting types

 2.1
 - General code clean up

 2.0
 - Initial release
 
 1.0
 - Some laggy buggy log-spammy codes
^^^^^^^^^^^^^^^^^^^^CHANGELOG^^^^^^^^^^^^^^^^^^^^ */
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#undef REQUIRE_PLUGIN
#include <confogl>
#include <sdktools>
//#include <left4dhooks>
#define REQUIRE_PLUGIN
#define PL_VERSION "4.3"

bool CustomName;
bool IsConfoglAvailable;
bool isempty;

ConVar cvarHostNum;
ConVar cvarMainName;
ConVar cvarMainNameFile;
ConVar cvarServerNameFormatCase1;
ConVar cvarServerNameFormatCase2;
ConVar cvarServerNameFormatCase3;
ConVar cvarServerNameFormatCase4;
ConVar cvarMpGameMin;
ConVar cvarSI;
ConVar cvarMpGameMode;
ConVar cvarZDifficulty;
ConVar cvarHostname;
ConVar cvarReadyUpCfgName;

char AnneHappy[128];

//float GetMapMaxFlow;

//int RoundFailCounts;

KeyValues kv;

public Plugin myinfo =
{
	name = "Server namer",
	version = PL_VERSION,
	description = "Changes server hostname according to the current game mode",
	author = "sheo, Forgetest, 东, merged and modified by blueblur",
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins/tree/master/The%20Last%20Stand/server_namer (Original) || https://github.com/fantasylidong/CompetitiveWithAnne/blob/master/addons/sourcemod/scripting/extend/server_name.sp (AnneHappy ServerName)"
};

public void OnPluginStart()
{
	//Check if l4d2
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		SetFailState("Plugin supports Left 4 dead 2 only!");
	}
	
	//Check if s_n.txt exists
	kv = CreateKeyValues("GameMods");
	char filepath[64];
	BuildPath(Path_SM, filepath, sizeof(filepath), "configs/server_namer.txt");
	if (!FileToKeyValues(kv, filepath))
	{
		SetFailState("configs/server_namer.txt not found!");
	}

	//Reg cmds/cvars
	RegAdminCmd("sn_hostname", Cmd_Hostname, ADMFLAG_KICK);
	cvarHostNum = CreateConVar("sn_host_num", "0", "Server number, usually set at lauch command line.");
	cvarMainName = CreateConVar("sn_main_name", "Hostname", "Main server name.");
	cvarMainNameFile = CreateConVar("sn_main_name_path", "", "Path to text file where main server name is (for using UTF-8 characters) (bases \"sourcemod/configs/\").");
	cvarServerNameFormatCase1 = CreateConVar("sn_hostname_format1", "[{hostname} #{servernum}] {gamemode}", "Hostname format. Case: Confogl or Vanilla without difficulty levels, such as Versus.");
	cvarServerNameFormatCase2 = CreateConVar("sn_hostname_format2", "[{hostname} #{servernum}] {gamemode} - {difficulty}", "Hostname format. Case: Vanilla with difficulty levels, such as Campaign.");
	cvarServerNameFormatCase3 = CreateConVar("sn_hostname_format3", "[{hostname} #{servernum}]", "Hostname format. Case: empty server.");
	cvarServerNameFormatCase4 = CreateConVar("sn_hostname_format4", "[{hostname} #{servernum}] {hardcoop}{AnneHappy}{Full}", "Hostname format. Case: AnneHappy Special.");
	CreateConVar("l4d2_server_namer_version", PL_VERSION, "Server namer version", FCVAR_NOTIFY);
	cvarMpGameMode = FindConVar("mp_gamemode");
	cvarHostname = FindConVar("hostname");
	cvarZDifficulty = FindConVar("z_difficulty");

	//Hooks
	HookConVarChange(cvarMpGameMode, OnCvarChanged);
	HookConVarChange(cvarZDifficulty, OnCvarChanged);
	//HookConVarChange(cvarMainName, OnCvarChanged);
	HookConVarChange(cvarHostNum, OnCvarChanged);
	HookConVarChange(cvarServerNameFormatCase1, OnCvarChanged);
	HookConVarChange(cvarServerNameFormatCase2, OnCvarChanged);
	HookConVarChange(cvarServerNameFormatCase3, OnCvarChanged);
	HookConVarChange(cvarServerNameFormatCase4, OnCvarChanged);
	IsConfoglAvailable = LibraryExists("confogl");
	SetName();
}

public void OnPluginEnd()
{
	cvarMpGameMode = null;
	cvarMpGameMin = null;
}

public void OnMapStart()
{
	FindConVar("sv_hibernate_when_empty").SetInt(0);
}

public void OnClientConnected(int client)
{
	SetName();
}

public void OnAllPluginsLoaded()
{
	cvarSI = FindConVar("l4d_infected_limit");
	cvarMpGameMin = FindConVar("versus_special_respawn_interval");
}

public void OnConfigsExecuted()
{
	IsConfoglAvailable = LibraryExists("confogl");
	if(cvarSI != null)
	{
		cvarSI.AddChangeHook(OnCvarChanged);
	}
	else if(FindConVar("l4d_infected_limit") != null)
	{
		cvarSI = FindConVar("l4d_infected_limit");
		cvarSI.AddChangeHook(OnCvarChanged);
	}
	if(cvarMpGameMin != null)
	{
		cvarMpGameMin.AddChangeHook(OnCvarChanged);
	}
	else if(FindConVar("versus_special_respawn_interval") != null)
	{
		cvarMpGameMin = FindConVar("versus_special_respawn_interval");
		cvarMpGameMin.AddChangeHook(OnCvarChanged);
	}
	//	GetMapMaxFlow = L4D2Direct_GetMapMaxFlowDistance();
	
	SetName();
}

public void OnClientDisconnect_Post(int client)
{
	SetName();
}

public void OnCvarChanged(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	SetName();
}

public Action Cmd_Hostname(int client, int args)
{
	if (args == 0)
	{
		CustomName = false;
		SetName();
	}
	else
	{
		CustomName = true;
		char arg1[128];
		GetCmdArg(1, arg1, sizeof(arg1));
		SetConVarString(cvarHostname, arg1, false, false);
	}
	
	return Plugin_Handled;
}

void SetName()
{
	if (CustomName)
	{
		return;
	}
	StoreMainNameFromFile();
	isempty = ServerIsEmpty();
	if (IsConfoglAvailable)
	{
		if (cvarReadyUpCfgName == INVALID_HANDLE)
		{
			cvarReadyUpCfgName = FindConVar("l4d_ready_cfg_name");
		}
		if (cvarReadyUpCfgName != INVALID_HANDLE)
		{
			SetConfoglName();
		}
		else
		{
			SetVanillaName();
		}
	}
	else
	{
		SetVanillaName();
	}
}

void SetVanillaName()
{
	char GameMode[128];
	char FinalHostname[128];
	if (isempty || IsGameModeEmpty())
	{
		GetConVarString(cvarServerNameFormatCase3, FinalHostname, sizeof(FinalHostname));
		ParseNameAndSendToMainConVar(FinalHostname);
	}
	else
	{
		char CurGamemode[128];
		GetConVarString(cvarMpGameMode, CurGamemode, sizeof(CurGamemode));
		KvRewind(kv);
		if (KvJumpToKey(kv, CurGamemode))
		{
			KvGetString(kv, "name", GameMode, sizeof(GameMode));
			if (KvGetNum(kv, "difficulty") == 1)
			{
				char CurDiff[32];
				GetConVarString(cvarZDifficulty, CurDiff, sizeof(CurDiff));
				KvRewind(kv);
				KvJumpToKey(kv, "difficulties");
				char CurDiffBuffer[32];
				KvGetString(kv, CurDiff, CurDiffBuffer, sizeof(CurDiffBuffer));
				GetConVarString(cvarServerNameFormatCase2, FinalHostname, sizeof(FinalHostname));
				ReplaceString(FinalHostname, sizeof(FinalHostname), "{gamemode}", GameMode);
				ReplaceString(FinalHostname, sizeof(FinalHostname), "{difficulty}", CurDiffBuffer);
				ParseNameAndSendToMainConVar(FinalHostname);
			}
			else
			{
				GetConVarString(cvarServerNameFormatCase1, FinalHostname, sizeof(FinalHostname));
				ReplaceString(FinalHostname, sizeof(FinalHostname), "{gamemode}", GameMode);
				ParseNameAndSendToMainConVar(FinalHostname);
			}
		}
		else
		{
			GetConVarString(cvarServerNameFormatCase1, FinalHostname, sizeof(FinalHostname));
			ReplaceString(FinalHostname, sizeof(FinalHostname), "{gamemode}", CurGamemode);
			ParseNameAndSendToMainConVar(FinalHostname);
		}
	}
}

public void SetConfoglName()
{
	char GameMode[128];
	char FinalHostname[128];
	char buffer[128];
	bool IsAnne = false;
	
	if (isempty)
	{
		GetConVarString(cvarServerNameFormatCase3, FinalHostname, sizeof(FinalHostname));
		ParseNameAndSendToMainConVar(FinalHostname);
	}
	else
	{
		GetConVarString(cvarReadyUpCfgName, AnneHappy, sizeof(AnneHappy));
		GetConVarString(cvarServerNameFormatCase4,FinalHostname, sizeof(FinalHostname));
		if(StrContains(AnneHappy, "AnneHappy", false)!=-1)
		{
			ReplaceString(FinalHostname, sizeof(FinalHostname), "{hardcoop}","[普通药役]");
			ParseNameAndSendToMainConVar(FinalHostname);
			IsAnne = true;
		}	
		else 
		{
		if(StrContains(AnneHappy, "AllCharger", false)!=-1)
			{
				ReplaceString(FinalHostname, sizeof(FinalHostname), "{hardcoop}","[牛牛冲刺]");
				ParseNameAndSendToMainConVar(FinalHostname);
				IsAnne = true;
			}	
			else 
			{
				if(StrContains(AnneHappy, "AnneHunters", false)!=-1)
				{
				ReplaceString(AnneHappy, sizeof(FinalHostname), "{hardcoop}","[HT训练]");
				ParseNameAndSendToMainConVar(FinalHostname);
				IsAnne = true;
				}
				else 
				{
					if(StrContains(AnneHappy, "WitchPartyAnne", false)!=-1)
					{
						ReplaceString(FinalHostname, sizeof(FinalHostname), "{hardcoop}","[女巫派对]");
						ParseNameAndSendToMainConVar(FinalHostname);
						IsAnne = true;
					}
					else 
					{
						if(StrContains(AnneHappy, "Alone", false)!=-1)
						{
							ReplaceString(FinalHostname, sizeof(FinalHostname), "{hardcoop}","[单人装逼]");
							ParseNameAndSendToMainConVar(FinalHostname);
							IsAnne = true;
						}
						else
						{
							char CurGamemode[128];
							GetConVarString(cvarReadyUpCfgName, GameMode, sizeof(GameMode));
							GetConVarString(cvarServerNameFormatCase1, FinalHostname, sizeof(FinalHostname));
							ReplaceString(FinalHostname, sizeof(FinalHostname), "{gamemode}", GameMode);
							if (StrContains("l4d_ready_cfg_name", "Coop", false)!=-1)
							{
								SetConVarString(cvarServerNameFormatCase1, "[{hostname} #{servernum}] {gamemode} - {difficulty}");
								GetConVarString(cvarMpGameMode, CurGamemode, sizeof(CurGamemode));
								KvRewind(kv);
								if (KvJumpToKey(kv, CurGamemode))
								{
									KvGetString(kv, "name", GameMode, sizeof(GameMode));
									if (KvGetNum(kv, "difficulty") == 1)
									{
										char CurDiff[32];
										GetConVarString(cvarZDifficulty, CurDiff, sizeof(CurDiff));
										KvRewind(kv);
										KvJumpToKey(kv, "difficulties");
										char CurDiffBuffer[32];
										KvGetString(kv, CurDiff, CurDiffBuffer, sizeof(CurDiffBuffer));
										ReplaceString(FinalHostname, sizeof(FinalHostname), "{difficulty}", CurDiffBuffer);
										ParseNameAndSendToMainConVar(FinalHostname);
									}
								}
							}
							ParseNameAndSendToMainConVar(FinalHostname);
						}
					}
				}
			}
		}
	}
	if(cvarSI != null && IsAnne)
	{
		Format(buffer, sizeof(buffer),"[%d特%d秒]", GetConVarInt(cvarSI), GetConVarInt(cvarMpGameMin));
		ReplaceString(FinalHostname, sizeof(FinalHostname), "{AnneHappy}",buffer);
		ParseNameAndSendToMainConVar(FinalHostname);
	}
	else
	{
		ReplaceString(FinalHostname, sizeof(FinalHostname), "{AnneHappy}","");
		ParseNameAndSendToMainConVar(FinalHostname);
	}
	if(IsTeamFull(IsAnne))
	{
		ReplaceString(FinalHostname, sizeof(FinalHostname), "{Full}", "");
		ParseNameAndSendToMainConVar(FinalHostname);
	}
	else
	{
		ReplaceString(FinalHostname, sizeof(FinalHostname), "{Full}", "[缺人]");
		ParseNameAndSendToMainConVar(FinalHostname);
	}
}

bool IsTeamFull(bool IsAnne = false)
{
	int sum = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsPlayer(i) && !IsFakeClient(i))
		{
			sum ++;
		}
	}
	if(sum == 0)
	{
		return true;
	}
	if(IsAnne)
	{
		return sum >= (GetConVarInt(FindConVar("survivor_limit")));
	}else
	{
		return sum >= (GetConVarInt(FindConVar("survivor_limit")) + GetConVarInt(FindConVar("z_max_player_zombies")));
	}
	
}
bool IsPlayer(int client)
{
	if(IsValidClient(client) && (GetClientTeam(client) == 2 || GetClientTeam(client) == 3))
	{
		return true;
	}
	else
	{
		return false;
	}
}

void ParseNameAndSendToMainConVar(char[] sBuffer)
{
	char tBuffer[128];
	GetConVarString(cvarMainName, tBuffer, sizeof(tBuffer));
	ReplaceString(sBuffer, 128, "{hostname}", tBuffer);
	GetConVarString(cvarHostNum, tBuffer, sizeof(tBuffer));
	ReplaceString(sBuffer, 128, "{servernum}", tBuffer);
	SetConVarString(cvarHostname, sBuffer, false, false);
}

void StoreMainNameFromFile()
{
	char sPath[PLATFORM_MAX_PATH];
	GetConVarString(cvarMainNameFile, sPath, sizeof sPath);
	if (!strlen(sPath)) return;
	
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/%s", sPath);
	
	File file = OpenFile(sPath, "r");
	if (file != INVALID_HANDLE)
	{
		char readData[256];
		if(!IsEndOfFile(file) && ReadFileLine(file, readData, sizeof(readData)))
		{
			SetConVarString(cvarMainName, readData);
		}
		return;
	}
}

bool ServerIsEmpty()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i))
		{
			return false;
		}
	}

	return true;
}

bool IsGameModeEmpty()
{
	char GameMode[128];
	char CurGamemode[128];

	GetConVarString(cvarMpGameMode, CurGamemode, sizeof(CurGamemode));

	KvRewind(kv);
	if (KvJumpToKey(kv, CurGamemode))
	{
		KvGetString(kv, "name", GameMode, sizeof(GameMode));

		if (GameMode[0] == '\0') return true;
	}

	return false;
}

public bool IsValidClient(int client)
{
   return (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client));
}
