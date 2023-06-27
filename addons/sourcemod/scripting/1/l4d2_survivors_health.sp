#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

Handle hRoundRespawn;

bool SurvivorsHealth, SurvivorsDefaults = false;

ConVar g_Enabled, g_Defaults;
int hEnabled, hDefaults;

#define NAME_RoundRespawn "CTerrorPlayer::RoundRespawn"
#define SIG_RoundRespawn_LINUX "@_ZN13CTerrorPlayer12RoundRespawnEv"
#define SIG_RoundRespawn_WINDOWS "\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\xE8\\x2A\\x2A\\x2A\\x2A\\x84\\x2A\\x75\\x2A\\x8B\\x2A\\xE8\\x2A\\x2A\\x2A\\x2A\\xC6\\x86"

Address g_pStatsCondition;

public void OnPluginStart() 
{
	l4d2_ResetSurvivors_LoadGameCFG();
	
	RegConsoleCmd("sm_hp", Command_ResetSurvivors, "幸存者过关时自动满血或复活.");
	
	g_Enabled	= CreateConVar("l4d2_survivors_health_Enabled",		"1", "启用过关时幸存者自动满血或复活? 0=禁用, 1=启用.", FCVAR_NOTIFY);
	g_Defaults	= CreateConVar("l4d2_survivors_health_defaults",	"1", "默认开启或关闭幸存者过关时自动满血或复活? 0=关闭, 1=开启.", FCVAR_NOTIFY);
	
	g_Enabled.AddChangeHook(l4d2survivorsConVarChanged);
	g_Defaults.AddChangeHook(l4d2survivorsConVarChanged);
	
	HookEvent("map_transition", Event_ResetSurvivors, EventHookMode_PostNoCopy);
	
	AutoExecConfig(true, "l4d2_survivors_health");//生成指定文件名的CFG.
}

public void OnPluginEnd()
{
	vStatsConditionPatch(false);
}

public void OnMapStart()
{
	l4d2_cvar_survivors();
}

public void l4d2survivorsConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	l4d2_cvar_survivors();
}

void l4d2_cvar_survivors()
{
	hEnabled	= g_Enabled.IntValue;
	hDefaults	= g_Defaults.IntValue;
}

public Action Command_ResetSurvivors(int client, int args)
{
	if(bCheckClientAccess(client) && iGetClientImmunityLevel(client) >= 98)
	{
		if (SurvivorsHealth)
		{
			SurvivorsHealth = false;
			SurvivorsDefaults = true;
			PrintToChat(client, "\x04[提示]\x03已关闭\x05幸存者过关时自动满血.");
		}
		else
		{
			SurvivorsHealth = true;
			SurvivorsDefaults = true;
			PrintToChat(client, "\x04[提示]\x03已开启\x05幸存者过关时自动满血.");
		}
	}
	else
		PrintToChat(client, "\x04[提示]\x05你无权使用此指令.");
	return Plugin_Handled;
}
	
bool bCheckClientAccess(int client)
{
	if(GetUserFlagBits(client) & ADMFLAG_ROOT)
		return true;
	return false;
}

int iGetClientImmunityLevel(int client)
{
	char sSteamID[32];
	GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));
	AdminId admin = FindAdminByIdentity(AUTHMETHOD_STEAM, sSteamID);
	if(admin == INVALID_ADMIN_ID)
		return -999;

	return admin.ImmunityLevel;
}

public void OnConfigsExecuted()
{
	l4d2_ResetSurvivors_LoadGameCFG();
	
	if(!SurvivorsDefaults)
	{
		switch (hDefaults)
		{
			case 0:
				SurvivorsHealth = false;
			case 1:
				SurvivorsHealth = true;
		}
	}
}

/// 初始化
public void l4d2_ResetSurvivors_LoadGameCFG()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/l4d2_survivors_health.txt");
	
	//判断是否有文件
	if (FileExists(sPath))
	{
		GameData hGameData = new GameData("l4d2_survivors_health");
		if(hGameData == null) 
			SetFailState("Failed to load gamedata/l4d2_survivors_health.txt");
			
		StartPrepSDKCall(SDKCall_Player);
		if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::RoundRespawn") == false)
			SetFailState("Failed to find signature: CTerrorPlayer::RoundRespawn");
		else
		{
			hRoundRespawn = EndPrepSDKCall();
			if(hRoundRespawn == null)
				SetFailState("Failed to create SDKCall: CTerrorPlayer::RoundRespawn");
		}
		
		vRegisterStatsConditionPatch(hGameData);
		
		delete hGameData;
	}
	else
	{
		//创建偏移文件.
		PrintToServer("[提示] 未发现%s文件,创建中...", sPath);
		File hFile = OpenFile(sPath, "w", false);
	
		hFile.WriteLine("\"Games\"");
		hFile.WriteLine("{");

		hFile.WriteLine("	\"left4dead2\"");
		hFile.WriteLine("	{");
		
		hFile.WriteLine("		\"Addresses\"");
		hFile.WriteLine("		{");
		
		hFile.WriteLine("			\"CTerrorPlayer::RoundRespawn\"");
		hFile.WriteLine("			{");
		hFile.WriteLine("				\"linux\"");
		hFile.WriteLine("				{");
		hFile.WriteLine("					\"signature\"	\"CTerrorPlayer::RoundRespawn\"");
		hFile.WriteLine("				}");
		hFile.WriteLine("				\"windows\"");
		hFile.WriteLine("				{");
		hFile.WriteLine("					\"signature\"	\"CTerrorPlayer::RoundRespawn\"");
		hFile.WriteLine("				}");
		hFile.WriteLine("			}");
		
		hFile.WriteLine("		}");
		
		hFile.WriteLine("		\"Offsets\"");
		hFile.WriteLine("		{");
		
		hFile.WriteLine("			\"RoundRespawn_Offset\"");
		hFile.WriteLine("			{");
		hFile.WriteLine("				\"linux\"	\"25\"");
		hFile.WriteLine("				\"windows\"	\"15\"");
		hFile.WriteLine("			}");
		
		hFile.WriteLine("			\"RoundRespawn_Byte\"");
		hFile.WriteLine("			{");
		hFile.WriteLine("				\"linux\"	\"117\"");
		hFile.WriteLine("				\"windows\"	\"117\"");
		hFile.WriteLine("			}");
		
		hFile.WriteLine("		}");
		
		hFile.WriteLine("		\"Signatures\"");
		hFile.WriteLine("		{");
		
		hFile.WriteLine("			\"%s\"", NAME_RoundRespawn);
		hFile.WriteLine("			{");
		hFile.WriteLine("				\"library\"	\"server\"");
		hFile.WriteLine("				\"linux\"	\"%s\"", SIG_RoundRespawn_LINUX);
		hFile.WriteLine("				\"windows\"	\"%s\"", SIG_RoundRespawn_WINDOWS);
		hFile.WriteLine("			}");
		
		hFile.WriteLine("		}");
			
		hFile.WriteLine("	}");
		hFile.WriteLine("}");
		
		FlushFile(hFile);
		delete hFile;
	}
}

void vRegisterStatsConditionPatch(GameData hGameData = null)
{
	int iOffset = hGameData.GetOffset("RoundRespawn_Offset");
	if(iOffset == -1)
		SetFailState("Failed to find offset: RoundRespawn_Offset");

	int iByteMatch = hGameData.GetOffset("RoundRespawn_Byte");
	if(iByteMatch == -1)
		SetFailState("Failed to find byte: RoundRespawn_Byte");

	g_pStatsCondition = hGameData.GetAddress("CTerrorPlayer::RoundRespawn");
	if(!g_pStatsCondition)
		SetFailState("Failed to find address: CTerrorPlayer::RoundRespawn");
	
	g_pStatsCondition += view_as<Address>(iOffset);
	
	int iByteOrigin = LoadFromAddress(g_pStatsCondition, NumberType_Int8);
	if(iByteOrigin != iByteMatch)
		SetFailState("Failed to load 'CTerrorPlayer::RoundRespawn', byte mis-match @ %d (0x%02X != 0x%02X)", iOffset, iByteOrigin, iByteMatch);
}

void vRoundRespawn(int client)
{
	vStatsConditionPatch(true);
	SDKCall(hRoundRespawn, client);
	vStatsConditionPatch(false);
}

void vStatsConditionPatch(bool bPatch)
{
	static bool bPatched;
	if(!bPatched && bPatch)
	{
		bPatched = true;
		StoreToAddress(g_pStatsCondition, 0x79, NumberType_Int8);
	}
	else if(bPatched && !bPatch)
	{
		bPatched = false;
		StoreToAddress(g_pStatsCondition, 0x75, NumberType_Int8);
	}
}

public void Event_ResetSurvivors(Event event, const char[] name, bool dontBroadcast)
{
	if (hEnabled != 0 && hEnabled == 1 && SurvivorsHealth)
		ResetSurvivorsiMaxHealth();
}

void ResetSurvivorsiMaxHealth()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			if (!IsAlive(i))
			{
				vRoundRespawn(i);//复活死亡的幸存者.
				TeleportClient(i);//复活后随机传送到其他幸存者身边.
			}
			else if (IsPlayerFallen(i) || IsPlayerFalling(i))//倒地或挂边.
				iMaxHealth(i);//加满血量.
			else
			{
				int Attackerhealth = GetClientHealth(i);
				int health = GetEntProp(i, Prop_Data, "m_iMaxHealth");
				
				if (Attackerhealth < health)
					iMaxHealth(i);//加满血量.
			}
		}
	}
}

//加满血量.
void iMaxHealth(int client)
{
	CheatCommand(client, "give", "health");//加满血量.
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);//设置虚血为:0
	//SetEntProp(client, Prop_Send, "m_currentReviveCount", 0);//重置倒地次数.
	//SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 0);//取消黑白状态.
	//StopSound(client, SNDCHAN_STATIC, "player/heartbeatloop.wav");//去除黑白时的心跳声.
}

//死亡的.
bool IsAlive(int client)
{
	return !GetEntProp(client, Prop_Send, "m_lifeState");
}

//挂边的
bool IsPlayerFalling(int client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated") && GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}

//倒地的.
bool IsPlayerFallen(int client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated") && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}

void CheatCommand(int client, char[] strCommand, char[] strParam1)
{
	int flags = GetCommandFlags(strCommand);
	SetCommandFlags(strCommand, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", strCommand, strParam1);
	SetCommandFlags(strCommand, flags);
}

//随机传送幸存者到其他幸存者身边.
void TeleportClient(int client)
{
	int iTarget = GetTeleportTarget(client);
	
	if(iTarget != -1)
	{
		//传送时强制蹲下防止卡住.
		ForceCrouch(client);
		
		float vPos[3];
		GetClientAbsOrigin(iTarget, vPos);
		TeleportEntity(client, vPos, NULL_VECTOR, NULL_VECTOR);
	}
}

int GetTeleportTarget(int client)
{
	int iNormal, iIncap, iHanging;
	int[] iNormalSurvivors = new int[MaxClients];
	int[] iIncapSurvivors = new int[MaxClients];
	int[] iHangingSurvivors = new int[MaxClients];
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(i != client && IsClientInGame(i) && GetClientTeam(i) == 2 && IsAlive(i))
		{
			if(GetEntProp(i, Prop_Send, "m_isIncapacitated") > 0)
			{
				if(GetEntProp(i, Prop_Send, "m_isHangingFromLedge") > 0)
					iHangingSurvivors[iHanging++] = i;
				else
					iIncapSurvivors[iIncap++] = i;
			}
			else
				iNormalSurvivors[iNormal++] = i;
		}
	}
	return (iNormal == 0) ? (iIncap == 0 ? (iHanging == 0 ? -1 : iHangingSurvivors[GetRandomInt(0, iHanging - 1)]) : iIncapSurvivors[GetRandomInt(0, iIncap - 1)]) :iNormalSurvivors[GetRandomInt(0, iNormal - 1)];
}

void ForceCrouch(int client)
{
	SetEntProp(client, Prop_Send, "m_bDucked", 1);
	SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags") | FL_DUCKING);
}

