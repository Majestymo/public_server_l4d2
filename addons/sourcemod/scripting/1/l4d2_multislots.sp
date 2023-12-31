#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <dhooks>

#define NAME_RoundRespawn "CTerrorPlayer::RoundRespawn"
#define SIG_RoundRespawn_LINUX "@_ZN13CTerrorPlayer12RoundRespawnEv"
#define SIG_RoundRespawn_WINDOWS "\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\xE8\\x2A\\x2A\\x2A\\x2A\\x84\\x2A\\x75\\x2A\\x8B\\x2A\\xE8\\x2A\\x2A\\x2A\\x2A\\xC6\\x86"

#define NAME_SetHumanSpectator "SurvivorBot::SetHumanSpectator"
#define SIG_SetHumanSpectator_LINUX "@_ZN11SurvivorBot17SetHumanSpectatorEP13CTerrorPlayer"
#define SIG_SetHumanSpectator_WINDOWS "\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x83\\xBE\\x2A\\x2A\\x2A\\x2A\\x2A\\x7E\\x2A\\x32\\x2A\\x5E\\x5D\\xC2\\x2A\\x2A\\x8B\\x0D"

#define NAME_SetObserverTarget "CTerrorPlayer::SetObserverTarget"
#define SIG_SetObserverTarget_LINUX "@_ZN11SurvivorBot17SetHumanSpectatorEP13CTerrorPlayer"
#define SIG_SetObserverTarget_WINDOWS "\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x83\\xBE\\x2A\\x2A\\x2A\\x2A\\x2A\\x7E\\x2A\\x32\\x2A\\x5E\\x5D\\xC2\\x2A\\x2A\\x8B\\x0D"

#define NAME_TakeOverBot "CTerrorPlayer::TakeOverBot"
#define SIG_TakeOverBot_LINUX "@_ZN13CTerrorPlayer11TakeOverBotEb"
#define SIG_TakeOverBot_WINDOWS "\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\xA1\\x2A\\x2A\\x2A\\x2A\\x33\\x2A\\x89\\x2A\\x2A\\x53\\x56\\x8D"

#define NAME_SetModel "CBasePlayer::SetModel"
#define SIG_SetModel_LINUX "@_ZN11CBasePlayer8SetModelEPKc"
#define SIG_SetModel_WINDOWS "\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x56\\x57\\x50\\x8B\\x2A\\xE8\\x2A\\x2A\\x2A\\x2A\\x8B\\x3D"

#define NAME_GoAwayFromKeyboard "CTerrorPlayer::GoAwayFromKeyboard"
#define SIG_GoAwayFromKeyboard_LINUX "@_ZN13CTerrorPlayer18GoAwayFromKeyboardEv"
#define SIG_GoAwayFromKeyboard_WINDOWS "\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x53\\x56\\x57\\x8B\\xF1\\x8B\\x06\\x8B\\x90\\xC8\\x08\\x00\\x00"

#define NAME_GiveDefaultItems "CTerrorPlayer::GiveDefaultItems"
#define SIG_GiveDefaultItems_LINUX "@_ZN13CTerrorPlayer16GiveDefaultItemsEv"
#define SIG_GiveDefaultItems_WINDOWS "\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x2A\\x50\\xE8\\x2A\\x2A\\x2A\\x2A\\x83\\x2A\\x2A\\x84\\x2A\\x0F\\x84\\x2A\\x2A\\x2A\\x2A\\xA1\\x2A\\x2A\\x2A\\x2A\\x8B\\x88"

#define TEAM_SPECTATOR	1
#define TEAM_SURVIVOR	2
#define TEAM_INFECTED   3
#define TEAM_PASSING	4

#define PLUGIN_VERSION	"1.0"
#define CVAR_FLAGS		FCVAR_NOTIFY

ConVar g_hSLimit, g_hgive0, g_hgive1, g_hgive2, g_hgive3, g_hgive4, g_hgive5;
ConVar g_check, g_haway, g_hdaze, g_hkick, g_hsset, g_hmaxs, g_hLimit, g_hTeam, g_hSteam, g_hBanId;

int g_iSurvivorBot, userids, maxplayers;
int hgive0, hgive1, hgive2, hgive3, hgive4, hgive5;
int hcheck, hdaze, haway, hkick, hsset, hmaxs, hLimit, hTeam, hSteam, hBanId;

Handle g_TimerSpecCheck = null, g_hBotsUpdateTimer = null;

bool g_bShouldFixAFK = false, g_bShouldIgnore = false, g_bRoundStarted, gbVehicleLeaving, g_aSteamIDsFinaleVehicleLeaving, gbFirstItemPickedUp, l4d2_sv_maxplayers, l4d2_Check_Interval;

char g_Models[MAXPLAYERS+1][128];

Handle hRoundRespawn, hTakeOverBot, hSetHumanSpec, hSetObserverTarget, hGoAwayFromKeyboard;

bool MenuFunc_SpecNext[MAXPLAYERS+1], BoolKickClient[MAXPLAYERS+1], ClientTakeOverBot[MAXPLAYERS+1], l4d2_button[MAXPLAYERS+1];

int g_iBotPlayer[MAXPLAYERS+1], ClientSpawnMaxTimer[MAXPLAYERS+1], VariableSurvivor[MAXPLAYERS+1], numPrinted[MAXPLAYERS+1];
Handle ClientTimer_Index[MAXPLAYERS+1], ClientTimerDaze[MAXPLAYERS+1], CheckAFKTimer[MAXPLAYERS+1];

float LastEyeAngles [MAXPLAYERS+1][3], CurrEyeAngles [MAXPLAYERS+1][3];

Address g_pStatsCondition;
StringMap g_aSteamIDs;

public Plugin myinfo = 
{
	name 		= "L4D2 MultiSlots",
	author 		= "SwiftReal, MI 5",
	description 	= "Allows additional survivor/infected players in coop, versus, and survival",
	version 		= PLUGIN_VERSION,
	url 			= "N/A"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) 
{
	char GameName[64];
	GetGameFolderName(GameName, sizeof(GameName));
	if (StrContains(GameName, "left4dead", false) == -1)
		return APLRes_Failure; 
	
	return APLRes_Success; 
}

public void OnPluginStart()
{
	l4d2_multislots_LoadGameCFG();
	
	CreateConVar("l4d_multislots_version", PLUGIN_VERSION, "多人插件的版本.(注意:由于三方图可能限制某种近战刷出,请安装解除限制的插件)", CVAR_FLAGS|FCVAR_SPONLY|FCVAR_REPLICATED);
	SetConVarString(FindConVar("l4d_multislots_version"), PLUGIN_VERSION);
	
	RegConsoleCmd("sm_afk", GoAwayFromKeyboard, "幸存者快速休息指令.");
	RegConsoleCmd("sm_away", GoAFK, "幸存者强制加入旁观者.");
	RegConsoleCmd("sm_jg", JoinTeam_Type, "加入幸存者.");
	RegConsoleCmd("sm_join", JoinTeam_Type, "加入幸存者.");
	
	RegConsoleCmd("sm_addbot", AddBot, "管理员添加电脑幸存者.");
	RegConsoleCmd("sm_sset", Command_sset, "更改服务器人数.");
	RegConsoleCmd("sm_kb", Command_kickbot, "踢出所有电脑幸存者.");
	RegConsoleCmd("sm_bot", Command_BotSet, "设置电脑幸存者数量.");
	
	g_hSLimit		= FindConVar("survivor_limit");
	g_hgive0		= CreateConVar("l4d2_multislots_Survivor_spawn0",				"1",		"启用给予玩家武器和物品? 0=禁用, 1=启用.", CVAR_FLAGS);
	g_hgive1		= CreateConVar("l4d2_multislots_Survivor_spawn1",				"1",		"启用给予主武器? 0=禁用, 1=启用(随机获得:冲锋枪,消音冲锋枪)(开局时都没有主武器则不给).", CVAR_FLAGS);
	g_hgive2		= CreateConVar("l4d2_multislots_Survivor_spawn2",				"1",		"启用给予副武器? 1=随机获得副武器(小手枪,马格南,斧头, 2=斧头).", CVAR_FLAGS);
	g_hgive3		= CreateConVar("l4d2_multislots_Survivor_spawn3",				"0",		"启用给予投掷武器? 0=禁用, 1=启用(随机获得:胆汁罐,燃烧瓶,土制炸弹).", CVAR_FLAGS);
	g_hgive4		= CreateConVar("l4d2_multislots_Survivor_spawn4",				"0",		"启用给予医疗物品? 0=禁用, 1=启用(随机获得:电击器,医疗包).", CVAR_FLAGS);
	g_hgive5		= CreateConVar("l4d2_multislots_Survivor_spawn5",				"0",		"启用给予急救物品? 0=禁用, 1=启用(随机获得:止痛药,肾上腺素).", CVAR_FLAGS);
	g_check		= CreateConVar("l4d2_multislots_enabled_afk_check",			"10",	"设置幸存者发呆多长时间后提示 !afk 闲置指令可用/秒(最小值:10).", CVAR_FLAGS);
	g_haway		= CreateConVar("l4d2_multislots_enabled_away",				"2",		"启用指令 !away 强制加入旁观者? 0=禁用, 1=启用(公共), 2=启用(只限管理员).", CVAR_FLAGS);
	g_hdaze		= CreateConVar("l4d2_multislots_enabled_away_daze",			"8",		"设置幸存者在复活门被营救或被电击器救活后多少秒无操作自动闲置? 0=禁用.", CVAR_FLAGS);
	g_hkick		= CreateConVar("l4d2_multislots_enabled_kick",				"1",		"启用指令 !kb 踢出所有电脑幸存者?(包括闲置玩家的电脑幸存者) 0=禁用, 1=启用.", CVAR_FLAGS);
	g_hLimit		= CreateConVar("l4d2_multislots_enabled_Sv_Limit",			"4",		"设置开局时的幸存者数量(请注意:幸存者+感染者最大不能超过32).", CVAR_FLAGS);
	g_hsset		= CreateConVar("l4d2_multislots_enabled_Sv_Sset",				"1",		"启用指令 !sset 设置服务器人数? 0=禁用(不影响设置最大人数), 1=启用.", CVAR_FLAGS);
	g_hmaxs		= CreateConVar("l4d2_multislots_enabled_Sv_maxs",				"8",		"设置服务器的默认最大人数. (使用指令 !sset 更改过人数后这里失效)", CVAR_FLAGS);
	g_hTeam		= CreateConVar("l4d2_multislots_enabled_player_Team",			"1",		"启用玩家转换队伍提示? 0=禁用 1=启用.", CVAR_FLAGS);
	g_hSteam		= CreateConVar("l4d2_multislots_enabled_player_steamID",		"60",	"设置玩家手动离开游戏后禁止重新加入的时间/秒. 0=禁用.", CVAR_FLAGS);
	g_hBanId		= CreateConVar("l4d2_multislots_enabled_player_steamID_Ban",	"0",		"自动封禁被踢出的玩家多长时间/分钟. 0=禁用.", CVAR_FLAGS);
	
	g_hSLimit.Flags &= ~FCVAR_NOTIFY; //移除ConVar变动提示
	g_hSLimit.SetBounds(ConVarBound_Upper, true, 31.0);
	
	g_hgive0.AddChangeHook(l4d2OtherConVarChanged);
	g_hgive1.AddChangeHook(l4d2OtherConVarChanged);
	g_hgive2.AddChangeHook(l4d2OtherConVarChanged);
	g_hgive3.AddChangeHook(l4d2OtherConVarChanged);
	g_hgive4.AddChangeHook(l4d2OtherConVarChanged);
	g_hgive5.AddChangeHook(l4d2OtherConVarChanged);
	
	g_check.AddChangeHook(l4d2OtherConVarChanged);
	g_haway.AddChangeHook(l4d2OtherConVarChanged);
	g_hdaze.AddChangeHook(l4d2OtherConVarChanged);
	g_hkick.AddChangeHook(l4d2OtherConVarChanged);
	g_hLimit.AddChangeHook(l4d2OtherConVarChanged);
	g_hsset.AddChangeHook(l4d2OtherConVarChanged);
	g_hmaxs.AddChangeHook(l4d2OtherConVarChanged);
	g_hTeam.AddChangeHook(l4d2OtherConVarChanged);
	g_hSteam.AddChangeHook(l4d2OtherConVarChanged);
	g_hBanId.AddChangeHook(l4d2OtherConVarChanged);
	
	HookEvent("defibrillator_used", Event_DefibrillatorUsed);//幸存者使用电击器救活队友.
	HookEvent("survivor_rescued", Event_SurvivorRescued);//幸存者再营救门复活.
	HookEvent("item_pickup", Event_ItemPickup);//玩家拾取武器或物品.
	HookEvent("round_start", Event_RoundStart);//回合开始.
	HookEvent("round_end", Event_RoundEnd);//回合结束.
	HookEvent("finale_vehicle_leaving", Event_FinaleVehicleLeaving, EventHookMode_Pre);//救援离开.
	HookEvent("player_connect", Event_Playerconnect);//玩家连接.
	HookEvent("player_disconnect", Event_Playerdisconnect);//玩家离开.
	HookEvent("player_team", Event_PlayerTeam);//玩家转换队伍.
	HookEvent("player_disconnect", Event_PlayerdisConnect, EventHookMode_Pre);//玩家离开.
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	
	//幸存者5+身份修复.
	HookEvent("player_bot_replace", Event_PlayerToBot);
	HookEvent("bot_player_replace", Event_BotToPlayer);
	
	//玩家在旁观者按鼠标左键自动加入幸存者.
	AddCommandListener(CommandListener_SpecNext, "spec_next");
	//禁用游戏自带的闲置提示.
	HookUserMessage(GetUserMessageId("TextMsg"), TextMsg, true);

	AutoExecConfig(true, "l4d2_multislots");
	
	g_aSteamIDs = new StringMap();
}

public void OnPluginEnd()
{
	vStatsConditionPatch(false);
}

public void OnConfigsExecuted()
{
	l4d2_multislots_LoadGameCFG();
}

/// 初始化
public void l4d2_multislots_LoadGameCFG()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/l4d2_multislots.txt");
	
	//判断是否有文件
	if (FileExists(sPath))
	{
		GameData hGameData = new GameData("l4d2_multislots");
		if(hGameData == null) 
			SetFailState("Failed to load gamedata/l4d2_multislots.txt");
			
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
		
		StartPrepSDKCall(SDKCall_Player);
		if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "SurvivorBot::SetHumanSpectator") == false)
			SetFailState("Failed to find signature: SurvivorBot::SetHumanSpectator");
		else
		{
			PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
			hSetHumanSpec = EndPrepSDKCall();
			if(hSetHumanSpec == null)
				SetFailState("Failed to create SDKCall: SurvivorBot::SetHumanSpectator");
		}
		StartPrepSDKCall(SDKCall_Player);
		if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::TakeOverBot") == false)
			SetFailState("Failed to find signature: CTerrorPlayer::TakeOverBot");
		else
		{
			PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
			hTakeOverBot = EndPrepSDKCall();
			if(hTakeOverBot == null)
				SetFailState("Failed to create SDKCall: CTerrorPlayer::TakeOverBot");
		}
		StartPrepSDKCall(SDKCall_Player);
		if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CTerrorPlayer::SetObserverTarget") == false)
			SetFailState("Failed to find offset: CTerrorPlayer::SetObserverTarget");
		else
		{
			PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
			hSetObserverTarget = EndPrepSDKCall();
			if(hSetObserverTarget == null)
				SetFailState("Failed to create SDKCall: CTerrorPlayer::SetObserverTarget");
		}
		StartPrepSDKCall(SDKCall_Player);
		if(PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::GoAwayFromKeyboard") == false)
			SetFailState("Failed to find signature: CTerrorPlayer::GoAwayFromKeyboard");
		else
		{
			PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
			hGoAwayFromKeyboard = EndPrepSDKCall();
			if(hGoAwayFromKeyboard == null)
				SetFailState("Failed to create SDKCall: CTerrorPlayer::GoAwayFromKeyboard");
		}
		
		vSetupDetours(hGameData);
		
		delete hGameData;
	}
	else
	{
		File hFile = OpenFile(sPath, "w", false);
	
		hFile.WriteLine("\"Games\"");
		hFile.WriteLine("{");

		hFile.WriteLine("	\"left4dead2\"");
		hFile.WriteLine("	{");
		
		hFile.WriteLine("		\"Functions\"");
		hFile.WriteLine("		{");
		
		hFile.WriteLine("			\"SurvivorBot::SetHumanSpectator\"");
		hFile.WriteLine("			{");
		hFile.WriteLine("				\"signature\"	\"SurvivorBot::SetHumanSpectator\"");
		hFile.WriteLine("				\"callconv\"	\"thiscall\"");
		hFile.WriteLine("				\"return\"	\"void\"");
		hFile.WriteLine("				\"this\"	\"entity\"");
		hFile.WriteLine("				\"arguments\"");
		hFile.WriteLine("				{");
		hFile.WriteLine("					\"AFKPlayer\"");
		hFile.WriteLine("					{");
		hFile.WriteLine("						\"type\"	\"cbaseentity\"");
		hFile.WriteLine("					}");
		hFile.WriteLine("				}");
		hFile.WriteLine("			}");
		
		hFile.WriteLine("			\"CTerrorPlayer::GoAwayFromKeyboard\"");
		hFile.WriteLine("			{");
		hFile.WriteLine("				\"signature\"	\"CTerrorPlayer::GoAwayFromKeyboard\"");
		hFile.WriteLine("				\"callconv\"	\"thiscall\"");
		hFile.WriteLine("				\"return\"	\"void\"");
		hFile.WriteLine("				\"this\"	\"entity\"");
		hFile.WriteLine("			}");
		
		hFile.WriteLine("			\"CBasePlayer::SetModel\"");
		hFile.WriteLine("			{");
		hFile.WriteLine("				\"signature\"	\"CBasePlayer::SetModel\"");
		hFile.WriteLine("				\"callconv\"	\"thiscall\"");
		hFile.WriteLine("				\"return\"	\"void\"");
		hFile.WriteLine("				\"this\"	\"entity\"");
		hFile.WriteLine("				\"arguments\"");
		hFile.WriteLine("				{");
		hFile.WriteLine("					\"modelname\"");
		hFile.WriteLine("					{");
		hFile.WriteLine("						\"type\"	\"charptr\"");
		hFile.WriteLine("					}");
		hFile.WriteLine("				}");
		hFile.WriteLine("			}");
		
		hFile.WriteLine("			\"CTerrorPlayer::TakeOverBot\"");
		hFile.WriteLine("			{");
		hFile.WriteLine("				\"signature\"	\"CTerrorPlayer::TakeOverBot\"");
		hFile.WriteLine("				\"callconv\"	\"thiscall\"");
		hFile.WriteLine("				\"return\"	\"void\"");
		hFile.WriteLine("				\"this\"	\"entity\"");
		hFile.WriteLine("				\"arguments\"");
		hFile.WriteLine("				{");
		hFile.WriteLine("					\"a1\"");
		hFile.WriteLine("					{");
		hFile.WriteLine("						\"type\"	\"bool\"");
		hFile.WriteLine("					}");
		hFile.WriteLine("				}");
		hFile.WriteLine("			}");
		
		hFile.WriteLine("			\"CTerrorPlayer::GiveDefaultItems\"");
		hFile.WriteLine("			{");
		hFile.WriteLine("				\"signature\"	\"CTerrorPlayer::GiveDefaultItems\"");
		hFile.WriteLine("				\"callconv\"	\"thiscall\"");
		hFile.WriteLine("				\"return\"	\"void\"");
		hFile.WriteLine("				\"this\"	\"entity\"");
		hFile.WriteLine("			}");
		
		hFile.WriteLine("		}");
		
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
		
		hFile.WriteLine("			\"CTerrorPlayer::SetObserverTarget\"");
		hFile.WriteLine("			{");
		hFile.WriteLine("				\"linux\"	\"403\"");
		hFile.WriteLine("				\"windows\"	\"402\"");
		hFile.WriteLine("			}");
		
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
		
		hFile.WriteLine("			\"%s\"", NAME_SetHumanSpectator);
		hFile.WriteLine("			{");
		hFile.WriteLine("				\"library\"	\"server\"");
		hFile.WriteLine("				\"linux\"	\"%s\"", SIG_SetHumanSpectator_LINUX);
		hFile.WriteLine("				\"windows\"	\"%s\"", SIG_SetObserverTarget_WINDOWS);
		hFile.WriteLine("			}");
		
		hFile.WriteLine("			\"%s\"", NAME_TakeOverBot);
		hFile.WriteLine("			{");
		hFile.WriteLine("				\"library\"	\"server\"");
		hFile.WriteLine("				\"linux\"	\"%s\"", SIG_TakeOverBot_LINUX);
		hFile.WriteLine("				\"windows\"	\"%s\"", SIG_TakeOverBot_WINDOWS);
		hFile.WriteLine("			}");
		
		hFile.WriteLine("			\"%s\"", NAME_SetModel);
		hFile.WriteLine("			{");
		hFile.WriteLine("				\"library\"	\"server\"");
		hFile.WriteLine("				\"linux\"	\"%s\"", SIG_SetModel_LINUX);
		hFile.WriteLine("				\"windows\"	\"%s\"", SIG_SetModel_WINDOWS);
		hFile.WriteLine("			}");
		
		hFile.WriteLine("			\"%s\"", NAME_GoAwayFromKeyboard);
		hFile.WriteLine("			{");
		hFile.WriteLine("				\"library\"	\"server\"");
		hFile.WriteLine("				\"linux\"	\"%s\"", SIG_GoAwayFromKeyboard_LINUX);
		hFile.WriteLine("				\"windows\"	\"%s\"", SIG_GoAwayFromKeyboard_WINDOWS);
		hFile.WriteLine("			}");
		
		hFile.WriteLine("			\"%s\"", NAME_GiveDefaultItems);
		hFile.WriteLine("			{");
		hFile.WriteLine("				\"library\"	\"server\"");
		hFile.WriteLine("				\"linux\"	\"%s\"", SIG_GiveDefaultItems_LINUX);
		hFile.WriteLine("				\"windows\"	\"%s\"", SIG_GiveDefaultItems_WINDOWS);
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

void vSetupDetours(GameData hGameData = null)
{
	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, "SurvivorBot::SetHumanSpectator");
	if(dDetour == null)
		SetFailState("Failed to find signature: SurvivorBot::SetHumanSpectator");
		
	if(!dDetour.Enable(Hook_Pre, OnSetHumanSpectatorPre))
		SetFailState("Failed to detour pre: SurvivorBot::SetHumanSpectator");

	dDetour = DynamicDetour.FromConf(hGameData, "CTerrorPlayer::GoAwayFromKeyboard");
	if(dDetour == null)
		SetFailState("Failed to find signature: CTerrorPlayer::GoAwayFromKeyboard");
		
	if(!dDetour.Enable(Hook_Pre, OnGoAFKPre))
		SetFailState("Failed to detour pre: CTerrorPlayer::GoAwayFromKeyboard");

	if(!dDetour.Enable(Hook_Post, OnGoAFKPost))
		SetFailState("Failed to detour post: CTerrorPlayer::GoAwayFromKeyboard");

	dDetour = DynamicDetour.FromConf(hGameData, "CBasePlayer::SetModel");
	if(dDetour == null)
		SetFailState("Failed to find signature: CBasePlayer::SetModel");
		
	if(!dDetour.Enable(Hook_Pre, mrePlayerSetModelPre))
		SetFailState("Failed to detour pre: CBasePlayer::SetModel");
		
	if(!dDetour.Enable(Hook_Post, mrePlayerSetModelPost))
		SetFailState("Failed to detour post: CBasePlayer::SetModel");
		
	dDetour = DynamicDetour.FromConf(hGameData, "CTerrorPlayer::TakeOverBot");
	if(dDetour == null)
		SetFailState("Failed to find signature: CTerrorPlayer::TakeOverBot");
		
	if(!dDetour.Enable(Hook_Pre, mreTakeOverBotPre))
		SetFailState("Failed to detour pre: CTerrorPlayer::TakeOverBot");

	if(!dDetour.Enable(Hook_Post, mreTakeOverBotPost))
		SetFailState("Failed to detour post: CTerrorPlayer::TakeOverBot");
		
	dDetour = DynamicDetour.FromConf(hGameData, "CTerrorPlayer::GiveDefaultItems");
	if(dDetour == null)
		SetFailState("Failed to find signature: CTerrorPlayer::GiveDefaultItems");
		
	if(!dDetour.Enable(Hook_Post, mreGiveDefaultItemsPost))
		SetFailState("Failed to detour post: CTerrorPlayer::GiveDefaultItems");
}

public void OnMapStart()
{
	l4d2GetOtherCvars();
	g_bRoundStarted = true;
	gbFirstItemPickedUp = false;
	//清除储存的全部玩家SteamID.
	if(g_aSteamIDsFinaleVehicleLeaving)
	{
		g_aSteamIDs.Clear();
		g_aSteamIDsFinaleVehicleLeaving = false;
	}
	ServerCommand("exec banned_user.cfg");//加载服务器封禁列表.
	
	SetConVarInt(FindConVar("sv_consistency"), 0);//关闭模型一致性检查? (普通战役服必备参数,建议保持关闭)   0=关闭  1=开启.
	SetConVarInt(FindConVar("z_spawn_flow_limit"), 50000);
	
	//修复女巫模型没预载而引起的游戏闪退,必备.
	if (!IsModelPrecached("models/infected/witch.mdl")) 				PrecacheModel("models/infected/witch.mdl", false);
	if (!IsModelPrecached("models/infected/witch_bride.mdl")) 			PrecacheModel("models/infected/witch_bride.mdl", false);
	
	//修复幸存者模型没预载而引起的游戏闪退,必备.
	if (!IsModelPrecached("models/survivors/survivor_teenangst.mdl"))	PrecacheModel("models/survivors/survivor_teenangst.mdl", false);
	if (!IsModelPrecached("models/survivors/survivor_biker.mdl"))		PrecacheModel("models/survivors/survivor_biker.mdl", false);
	if (!IsModelPrecached("models/survivors/survivor_manager.mdl"))	PrecacheModel("models/survivors/survivor_manager.mdl", false);
	if (!IsModelPrecached("models/survivors/survivor_namvet.mdl"))		PrecacheModel("models/survivors/survivor_namvet.mdl", false);
	if (!IsModelPrecached("models/survivors/survivor_gambler.mdl"))	PrecacheModel("models/survivors/survivor_gambler.mdl", false);
	if (!IsModelPrecached("models/survivors/survivor_coach.mdl"))		PrecacheModel("models/survivors/survivor_coach.mdl", false);
	if (!IsModelPrecached("models/survivors/survivor_mechanic.mdl"))	PrecacheModel("models/survivors/survivor_mechanic.mdl", false);
	if (!IsModelPrecached("models/survivors/survivor_producer.mdl"))	PrecacheModel("models/survivors/survivor_producer.mdl", false);
}

//地图结束.
public void OnMapEnd()
{
	StopTimers();
	l4d2_killtimer();
	
	g_bRoundStarted = false;
	gbVehicleLeaving = false;
	gbFirstItemPickedUp = false;
}

public void l4d2OtherConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	l4d2GetOtherCvars();
}

void l4d2GetOtherCvars()
{
	hgive0 = g_hgive0.IntValue;
	hgive1 = g_hgive1.IntValue;
	hgive2 = g_hgive2.IntValue;
	hgive3 = g_hgive3.IntValue;
	hgive4 = g_hgive4.IntValue;
	hgive5 = g_hgive5.IntValue;
	
	hcheck	= g_check.IntValue;
	if (hcheck < 10)
		hcheck = 10;
	
	hdaze	= g_hdaze.IntValue;
	haway	= g_haway.IntValue;
	hkick	= g_hkick.IntValue;
	hsset	= g_hsset.IntValue;
	hmaxs	= g_hmaxs.IntValue;
	hTeam	= g_hTeam.IntValue;
	hSteam	= g_hSteam.IntValue;
	hBanId	= g_hBanId.IntValue;
	
	g_hSLimit.IntValue = hLimit = g_hLimit.IntValue;
	
	if (hmaxs < 1)
		hmaxs = 1;
	
	if (!l4d2_sv_maxplayers)
	{
		SetConVarInt(FindConVar("sv_maxplayers"), hmaxs, false, false);
		SetConVarInt(FindConVar("sv_visiblemaxplayers"), hmaxs, false, false);
	}
	else
	{
		SetConVarInt(FindConVar("sv_maxplayers"), maxplayers, false, false);
		SetConVarInt(FindConVar("sv_visiblemaxplayers"), maxplayers, false, false);
	}
}

void l4d2_killtimer()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		delete CheckAFKTimer[i];
		delete ClientTimerDaze[i];
		delete ClientTimer_Index[i];
	}
}

//玩家连接成功.
public void OnClientPutInServer(int client)
{
	if(IsFakeClient(client))
		return;
	
	numPrinted[client] = 0;
	delete CheckAFKTimer[client];
	CheckAFKTimer[client] = CreateTimer(1.0, l4d2_AFK_Check, GetClientUserId(client), TIMER_REPEAT);
}

public Action l4d2_AFK_Check(Handle timer, any client)
{
	if ((client = GetClientOfUserId(client)))
	{
		if (!IsClientInGame(client) || GetClientTeam(client) == 1) 
			return Plugin_Continue;
		
		if (GetClientTeam(client) == 3)
		{
			CheckAFKTimer[client] = null;
			numPrinted[client] = 0;
			return Plugin_Stop;
		}
		else if (GetClientTeam(client) == 2)
		{
			if (GazeMovement(client) && l4d2_button[client])
			{
				numPrinted[client]++;
				
				if (numPrinted[client] >= hcheck) 
				{
					DirectorHint(client,"[提示] 请勿发呆,可输入 !afk 休息.");//特殊类提示.
					numPrinted[client] = 0;
				}
			}
			else
				numPrinted[client] = 0;
		}
	}
	return Plugin_Continue;
}

void DirectorHint(int client, const char[] sHintCaption)
{
	int iEntity = CreateEntityByName("env_instructor_hint"); 
	if(iEntity < 1)
		return;
	
	static char sValues[128];
	FormatEx(sValues, sizeof(sValues), "hint%d", client);
	DispatchKeyValue(client, "targetname", sValues);
	DispatchKeyValue(iEntity, "hint_target", sValues);
	
	DispatchKeyValue(iEntity, "hint_range", "0");
	DispatchKeyValue(iEntity, "hint_icon_onscreen", "icon_alert");
	
	FormatEx(sValues, sizeof(sValues), "%f", hcheck - 2.0);
	DispatchKeyValue(iEntity, "hint_timeout", sValues);
	
	FormatEx(sValues, sizeof(sValues), "%s", sHintCaption);
	DispatchKeyValue(iEntity, "hint_caption", sValues);
	DispatchKeyValue(iEntity, "hint_color", "255 255 0");
	DispatchSpawn(iEntity);
	AcceptEntityInput(iEntity, "ShowHint", client);
	
	FormatEx(sValues, sizeof(sValues), "OnUser1 !self:Kill::%f:1", hcheck - 1.0);
	SetVariantString(sValues);
	AcceptEntityInput(iEntity, "AddOutput");
	AcceptEntityInput(iEntity, "FireUser1");
}

//检测玩家是不是在发呆或按下某些按键.
public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if(!IsValidClientRunCmd(client))
		return Plugin_Continue;
		
	if(vel[0] != 0 || vel[1] != 0 || vel[2] != 0)
		l4d2_button[client] = false;
	else
	{
		if(buttons & IN_ATTACK || buttons & IN_JUMP || buttons & IN_DUCK 
		|| buttons & IN_USE || buttons & IN_ATTACK2 || buttons & IN_SCORE 
		|| buttons & IN_SPEED || buttons & IN_ZOOM || buttons & IN_RELOAD)
		{
			l4d2_button[client] = false;
			if(numPrinted[client] > 0)
				numPrinted[client] = 0;
			return Plugin_Continue;
		}
		l4d2_button[client] = true;
	}
	return Plugin_Continue;
}

bool IsValidClientRunCmd(int client)
{
	return client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client);
}

public void Event_DefibrillatorUsed(Event event, const char[] name, bool dontBroadcast)
{
	int subject = GetClientOfUserId(event.GetInt("subject"));
	
	if(hdaze > 0)
	{
		if(subject && IsClientConnected(subject) && IsClientInGame(subject) && !IsFakeClient(subject) && GetClientTeam(subject) == TEAM_SURVIVOR)
		{
			VariableSurvivor[subject] = 0;
			delete ClientTimerDaze[subject];
			ClientTimerDaze[subject] = CreateTimer(1.0, ClientSurvivorDaze, GetClientUserId(subject), TIMER_REPEAT);
		}
	}
}

public void Event_SurvivorRescued(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("victim"));
	
	if(hdaze > 0)
	{
		if(victim && IsClientConnected(victim) && IsClientInGame(victim) && !IsFakeClient(victim) && GetClientTeam(victim) == TEAM_SURVIVOR)
		{
			VariableSurvivor[victim] = 0;
			delete ClientTimerDaze[victim];
			ClientTimerDaze[victim] = CreateTimer(1.0, ClientSurvivorDaze, GetClientUserId(victim), TIMER_REPEAT);
		}
	}
}

public Action ClientSurvivorDaze(Handle timer, any client)
{
	if((client = GetClientOfUserId(client)))
	{
		if (!IsClientInGame(client))
			return Plugin_Continue;
		
		if (GetClientTeam(client) != 2 || !IsPlayerAlive(client))
		{
			VariableSurvivor[client] = 0;
			ClientTimerDaze[client] = null;
			return Plugin_Stop;
		}
		if (GetClientTeam(client) == 2)
		{
			VariableSurvivor[client]++;
			
			if (GazeMovement(client) && l4d2_button[client])
			{
				if (VariableSurvivor[client] >= hdaze) 
				{
					SDKCall(hGoAwayFromKeyboard, client);
					VariableSurvivor[client] = 0;
					ClientTimerDaze[client] = null;
					return Plugin_Stop;
				}
			}
			else
			{
				if (VariableSurvivor[client] == 1)
					return Plugin_Continue;
				
				VariableSurvivor[client] = 0;
				ClientTimerDaze[client] = null;
				return Plugin_Stop;
			}
		}
	}
	return Plugin_Continue;
}

//只是检测幸存者视线移动.
bool GazeMovement(int client)
{
	GetClientEyeAngles(client, CurrEyeAngles[client]);
	if (LastEyeAngles[client][0] == CurrEyeAngles[client][0] && LastEyeAngles[client][1] == CurrEyeAngles[client][1] && LastEyeAngles[client][2] == CurrEyeAngles[client][2])
	{
		return true;
	}
	else
	{
		LastEyeAngles[client] = CurrEyeAngles[client];
		return false;
	}
}

bool g_bTakingOverBot[MAXPLAYERS + 1];
public MRESReturn mreTakeOverBotPre(int pThis, DHookParam hParams)
{
	g_bTakingOverBot[pThis] = true;
}

public MRESReturn mreTakeOverBotPost(int pThis, DHookParam hParams)
{
	g_bTakingOverBot[pThis] = false;
}

//给予玩家武器或物品.
public MRESReturn mreGiveDefaultItemsPost(int pThis)
{
	if(!hgive0 || g_bShouldFixAFK || g_bTakingOverBot[pThis])
		return MRES_Ignored;

	if(!IsClientInGame(pThis) || GetClientTeam(pThis) != TEAM_SURVIVOR || !IsPlayerAlive(pThis))
		return MRES_Ignored;

	vGiveDefaultItems(pThis);
	return MRES_Ignored;
}

void vGiveDefaultItems(int client)
{
	vRemovePlayerWeapons(client);

	if(!hgive0)
		BypassAndExecuteCommand(client, "give", "pistol");//给予一把小手枪.
	else if(vGiveWeaponCount())//当前没有任何幸存者有主武器.
	{
		switch(hgive2)
		{
			case 1:
				l4d2_GiveWeapon_pistol_2(client);
			case 2:
				BypassAndExecuteCommand(client, "give", "fireaxe");//斧头.
		}
	}
	else
		vGivePresetPrimary(client);
}

bool vGiveWeaponCount()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClientGive(i))
		{
			int weapon = GetPlayerWeaponSlot(i, 0);
			
			if(weapon > 0)
				return false;
		}
	}
	return true;
}

bool IsValidClientGive(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2);
}

void vGivePresetPrimary(int client)
{
	switch(hgive2)
	{
		case 1:
			l4d2_GiveWeapon_pistol_2(client);
		case 2:
			BypassAndExecuteCommand(client, "give", "fireaxe");//斧头.
	}
	switch(hgive3)
	{
		case 1:
			l4d2_GiveWeapon_pistol_3(client);
	}
	switch(hgive4)
	{
		case 1:
			l4d2_GiveWeapon_pistol_4(client);
	}
	switch(hgive5)
	{
		case 1:
			l4d2_GiveWeapon_pistol_5(client);
	}
	switch(hgive1)
	{
		case 1:
			l4d2_GiveWeapon_pistol_1(client);
	}
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int oldteam = event.GetInt("oldteam");
	int team = event.GetInt("team");
	
	if(client && !IsFakeClient(client))
	{
		if(hTeam != 0 && hTeam == 1)
		{
			if(oldteam != 0)
			{
				if(team == 1)
					PrintToChatAll("\x04[提示]\x03%N\x05加入了观察者.", client);
				else if(team == 2)
					PrintToChatAll("\x04[提示]\x03%N\x05加入了幸存者.", client);
				else if(team == 3)
					PrintToChatAll("\x04[提示]\x03%N\x05加入了感染者.", client);
			}
		}
		if(oldteam == 0)
		{
			if(team == 1)
			{
				if(ClientTimer_Index[client] == null)
				{
					ClientSpawnMaxTimer[client] = 1;
					ClientTakeOverBot[client] = false;
					ClientTimer_Index[client] = CreateTimer(1.0, CheckClientState, GetClientUserId(client), TIMER_REPEAT);
				}
			}
		}
		if(oldteam == 2)
		{
			if(team != 2)
				RequestFrame(l4d2_kick_SurvivorBot);
		}
	}
}

public Action JoinTeam_Type(int client, int args)
{
	if(!IsClientConnected(client))
		return Plugin_Handled;
	
	if(GetClientTeam(client) == 2)
	{
		if(DispatchKeyValue(client, "classname", "player") == true)
		{
			PrintHintText(client, "[提示] 你已经加入了幸存者.");
			return Plugin_Handled;
		}
	}
	if (IsClientInGame(client) && !IsFakeClient(client))
	{
		if (GetClientTeam(client) == 1 && !iGetBotOfIdle(client))
		{
			if(ClientTimer_Index[client] == null)
			{
				ClientSpawnMaxTimer[client] = 1;
				ClientTakeOverBot[client] = true;
				ClientTimer_Index[client] = CreateTimer(0.1, CheckClientState, GetClientUserId(client), TIMER_REPEAT);
			}
		}
		else if (GetClientTeam(client) == 1 && iGetBotOfIdle(client))
			PrintHintText(client, "[提示] 请按下鼠标左键加入幸存者.");
	}
	return Plugin_Handled;
}

public Action CheckClientState(Handle timer, any client)
{
	if((client = GetClientOfUserId(client)))
	{
		if(!IsClientInGame(client))
			return Plugin_Continue;
		
		if(TotalFreeBots() > 0)
		{
			int bot = FindBotToTakeOver();
			
			if (bot == 0)
				MGetTakeOverTarget();
			
			if (ClientTakeOverBot[client])
				TakeOverBot(client, true);//更改为 true 加入时自动加入幸存者.
			else
				TakeOverBot(client, false);//更改为 false 加入时是闲置状态.
			ClientSpawnMaxTimer[client] = 0;
		}
		if(!client || ClientSpawnMaxTimer[client] >= 60 || !IsClientConnected(client) || !ClientSpawnMaxTimer[client] || (GetClientTeam(client) == 1 && iGetBotOfIdle(client)))
		{
			ClientSpawnMaxTimer[client] = 0;
			ClientTimer_Index[client] = null;
			return Plugin_Stop;
		}
		
		ClientSpawnMaxTimer[client]++;

		if(IsClientInGame(client) && GetClientTeam(client) == 1 && !iGetBotOfIdle(client))
			JoinTeam(client, false);
	}
	return Plugin_Continue;
}

public Action JoinTeam(int client, int args)
{
	if(!IsClientConnected(client))
		return Plugin_Handled;
	
	if(IsClientInGame(client))
	{
		if(TotalFreeBots() > 0)
		{
			ClientSpawnMaxTimer[client] = 0;
			if (GetClientTeam(client) == 1 && !iGetBotOfIdle(client))
			{
				int bot = FindBotToTakeOver();
				
				if (bot == 0)
					MGetTakeOverTarget();
			
				if (ClientTakeOverBot[client])
					TakeOverBot(client, true);//更改为 true 加入时自动加入幸存者.
				else
					TakeOverBot(client, false);//更改为 false 加入时是闲置状态.
			}
			return Plugin_Handled;
		}
		if(GetClientTeam(client) == 2)
		{	
			if(DispatchKeyValue(client, "classname", "player") == true)
				PrintHintText(client, "[提示] 你已经加入了幸存者.");
			else if((DispatchKeyValue(client, "classname", "info_survivor_position") == true) && !IsAlive(client))
				PrintHintText(client, "[提示] 请等待复活或营救.");
		}
		else if(iGetBotOfIdle(client))
			PrintHintText(client, "[提示] 请按鼠标左键加入幸存者.");
		else
		{			
			if(TotalFreeBots() == 0)
				vSpawnFakeSurvivorClient();
			else
				if (ClientTakeOverBot[client])
					TakeOverBot(client, true);//更改为 true 加入时自动加入幸存者.
				else
					TakeOverBot(client, false);//更改为 false 加入时是闲置状态.
		}
	}
	return Plugin_Handled;
}

void MGetTakeOverTarget()
{
	int iTakget = GetTakeOverTarget();
	
	if(iTakget != -1)
	{
		//如果玩家加入时电脑幸存者是死亡的则复活.
		if(!IsAlive(iTakget))
		{
			vRoundRespawn(iTakget);
			//电脑幸存者复活后传送.
			TeleportClient(iTakget);
		}
	}
}

int GetTakeOverTarget()
{
	int iAlive, iDeath;
	int[] iAliveBots = new int[MaxClients];
	int[] iDeathBots = new int[MaxClients];
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 2 && !iHasIdlePlayer(i))
		{
			if(IsPlayerAlive(i))
				iAliveBots[iAlive++] = i;
			else
				iDeathBots[iDeath++] = i;
		}
	}
	return (iAlive == 0) ? (iDeath == 0 ? -1 : iDeathBots[GetRandomInt(0, iDeath - 1)]) : iAliveBots[GetRandomInt(0, iAlive - 1)];
}

int TakeOverBot(int client, bool completely)
{
	if (!IsClientInGame(client))
		return;
	if (GetClientTeam(client) == 2)
		return;
	if (IsFakeClient(client))
		return;
	
	int bot = FindBotToTakeOver();
	
	if (bot==0)
	{
		PrintHintText(client, "[提示] 目前没有存活的电脑接管.");
		return;
	}
	
	if(completely)
	{
		SDKCall(hSetHumanSpec, bot, client);
		SDKCall(hSetObserverTarget, client, bot);
		SDKCall(hTakeOverBot, client, true);
	}
	else
	{
		SDKCall(hSetHumanSpec, bot, client);
		SDKCall(hSetObserverTarget, client, bot);
		SetEntProp(client, Prop_Send, "m_iObserverMode", 5);
	}
}

//开局提示.
public void OnClientPostAdminCheck(int client)
{
	if(IsFakeClient(client))
		return;
		
	BoolKickClient[client] = false;
	
	if (hSteam > 0)
	{
		float fTime;
		char sSteamID[32], sRunTime[32];
		GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));
		
		if(g_aSteamIDs.GetValue(sSteamID, fTime))
		{
			if (fTime)
			{
				float fromTime = GetEngineTime() - fTime;
			
				if (fromTime < hSteam)
				{
					BoolKickClient[client] = true;
					StandardizeTime(hSteam - fromTime, sRunTime);
					KickClient(client, "[提示] 请等待 %s 后再加入游戏", sRunTime);
				}
			}
		}
	}

	if(g_bRoundStarted == true)
	{
		delete g_hBotsUpdateTimer;
		g_hBotsUpdateTimer = CreateTimer(1.0, Timer_BotsUpdate);
	}
}

//https://forums.alliedmods.net/showthread.php?t=288686
void StandardizeTime(float time, char str[32])
{
	float remainder = time;
	
	int m = RoundToFloor(remainder / 60.0);
	remainder = remainder - float(m * 60);
	int s = RoundToFloor(remainder);
	
	if (m == 0)
		FormatEx(str, sizeof(str), "%d秒", s);
	else
		if (s == 0)
			FormatEx(str, sizeof(str), "%d分钟", m);
		else
			FormatEx(str, sizeof(str), "%d分%d秒", m, s);
}

//玩家离开.
public Action Event_PlayerdisConnect(Event event, const char[] name, bool dontBroadcast)
{
	//禁用游戏自带的玩家离开提示.
	SetEventBroadcast(event, true);
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(client && IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client))
	{
		char sReason[128], sName[MAX_NAME_LENGTH];
		event.GetString("reason", sReason, sizeof(sReason));
		event.GetString("name", sName, sizeof(sName));
		
		char sSteamID[32];
		GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));
		
		//LogError("[提示] %s 离开了游戏,原因: %s .", sName, sReason);
		if (StrEqual(sReason, "Disconnect by user.", false))	//玩家手动断开连接.
		{
			if (hSteam > 0)
				g_aSteamIDs.SetValue(sSteamID, GetEngineTime(), true);
		}
		else if(IsClientInKickQueue(client))	//自动封禁被踢出的玩家.
		{
			if (hBanId > 0 && !BoolKickClient[client])
				BanIdentity(sSteamID, hBanId, BANFLAG_AUTHID, "l4d2_multislots.smx auto ban", "Banned");
		}
	}
}

//玩家连接.
public void Event_Playerconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(client && !IsFakeClient(client))
		MenuFunc_SpecNext[client] = false;
}

//玩家离开.
public void Event_Playerdisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(client && !IsFakeClient(client))
	{
		delete CheckAFKTimer[client];
		delete ClientTimerDaze[client];
		delete ClientTimer_Index[client];
		MenuFunc_SpecNext[client] = false;
		RequestFrame(l4d2_kick_SurvivorBot);
	}
}

//回合结束.
public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	StopTimers();
	l4d2_killtimer();
	
	g_bRoundStarted = false;
	gbFirstItemPickedUp = false;
	
	if(!l4d2_Check_Interval)
		l4d2_Check_Interval = true;
		
	for(int i = 1; i <= MaxClients; i++)
		vTakeOver(i);
}

//回合开始.
public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundStarted = true;
	
	if(l4d2_Check_Interval)
	{
		l4d2_Check_Interval = false;
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
			{
				delete CheckAFKTimer[i];
				CheckAFKTimer[i] = CreateTimer(1.0, l4d2_AFK_Check, GetClientUserId(i), TIMER_REPEAT);
			}
		}
	}
}

public Action Timer_BotsUpdate(Handle timer)
{
	g_hBotsUpdateTimer = null;

	if(AreAllInGame() == true)
		vSpawnCheck();
	else
		g_hBotsUpdateTimer = CreateTimer(1.0, Timer_BotsUpdate);
}

//检查所有玩家是否加载完成.
bool AreAllInGame()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && !IsClientInGame(i) && !IsFakeClient(i))
			return false;
	}
	return true;
}

void vSpawnCheck()
{
	if(g_bRoundStarted == false)
		return;

	int iSurvivor			= iGetTeamPlayers(TEAM_SURVIVOR, true);
	int iHumanSurvivor		= iGetTeamPlayers(TEAM_SURVIVOR, false);
	int iSurvivorLimit		= hLimit;
	int iSurvivorMax		= iHumanSurvivor > iSurvivorLimit ? iHumanSurvivor : iSurvivorLimit;

	if(iSurvivor > iSurvivorMax)
		PrintToConsoleAll("Kicking %d bot(s)", iSurvivor - iSurvivorMax);

	if(iSurvivor < iSurvivorLimit)
		PrintToConsoleAll("Spawning %d bot(s)", iSurvivorLimit - iSurvivor);

	for(; iSurvivorMax < iSurvivor; iSurvivorMax++)
		vKickUnusedSurvivorBot();
	
	for(; iSurvivor < iSurvivorLimit; iSurvivor++)
		vSpawnFakeSurvivorClient();
}

static int iGetTeamPlayers(int team, bool bIncludeBots)
{
	static int i;
	static int iPlayers;

	iPlayers = 0;
	for(i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == team)
		{
			if(!bIncludeBots && IsFakeClient(i) && !iHasIdlePlayer(i))
				continue;

			iPlayers++;
		}
	}
	return iPlayers;
}

int iGetBotOfIdle(int client)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == TEAM_SURVIVOR && (iHasIdlePlayer(i) == client))
			return i;
	}
	return 0;
}

static int iHasIdlePlayer(int client)
{
	char sNetClass[64];
	if(!GetEntityNetClass(client, sNetClass, sizeof(sNetClass)))
		return 0;

	if(FindSendPropInfo(sNetClass, "m_humanSpectatorUserID") < 1)
		return 0;

	client = GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));			
	if(client && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == TEAM_SPECTATOR)
		return client;

	return 0;
}

void vKickUnusedSurvivorBot()
{
	int client = iGetAnyValidSurvivorBot();
	if(client)
	{
		vRemovePlayerWeapons(client);
		KickClient(client, "[提示] 自动踢出多余电脑");
	}
}

int iGetAnyValidSurvivorBot()
{
	int iSurvivor, iHasPlayer, iNotPlayer;
	int[] iHasPlayerBots = new int[MaxClients];
	int[] iNotPlayerBots = new int[MaxClients];
	for(int i = MaxClients; i >= 1; i--)
	{
		if(bIsValidSurvivorBot(i))
		{
			if((iSurvivor = GetClientOfUserId(g_iBotPlayer[i])) && IsClientInGame(iSurvivor) && !IsFakeClient(iSurvivor) && GetClientTeam(iSurvivor) != 2)
				iHasPlayerBots[iHasPlayer++] = i;
			else
				iNotPlayerBots[iNotPlayer++] = i;
		}
	}
	return (iNotPlayer == 0) ? (iHasPlayer == 0 ? 0 : iHasPlayerBots[0]) : iNotPlayerBots[0];
}

bool bIsValidSurvivorBot(int client)
{
	return IsClientInGame(client) && !IsClientInKickQueue(client) && IsFakeClient(client) && GetClientTeam(client) == TEAM_SURVIVOR && !iHasIdlePlayer(client);
}

public Action AddBot(int client, int args)
{
	if(bCheckClientAccess(client) && iGetClientImmunityLevel(client) >= 98)
	{
		if (TotalSurvivors() < l4d2_GetPlayerCount())
		{
			vSpawnFakeSurvivorClient();
			PrintToChat(client, "\x04[提示]\x05添加电脑成功.");
		}
		else
		{
			if (TotalSurvivors() < hLimit)
			{
				vSpawnFakeSurvivorClient();
				PrintToChat(client, "\x04[提示]\x05添加电脑成功.");
			}
			else
				PrintToChat(client, "\x04[提示]\x05当前无需添加电脑.");
		}
	}
	else
		PrintToChat(client, "\x04[提示]\x05你无权使用此指令.");
	return Plugin_Handled;
}

int l4d2_GetPlayerCount()
{
	int intt = 0;
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
			intt++;
	
	return intt;
}

public void Event_ItemPickup(Event event, const char[] name, bool dontBroadcast)
{
	if(!gbFirstItemPickedUp)
	{
		if(g_TimerSpecCheck == INVALID_HANDLE)
			g_TimerSpecCheck = CreateTimer(15.0, Timer_SpecCheck, _, TIMER_REPEAT);
		
		gbFirstItemPickedUp = true;
	}
}

public Action Timer_SpecCheck(Handle timer)
{
	if(gbVehicleLeaving)
	{
		g_TimerSpecCheck = null;
		return Plugin_Stop;
	}
	
	for (int i = 1; i <= MaxClients; i++)
		if(IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
			if(GetClientTeam(i) == 1 && !iGetBotOfIdle(i))
			{
				char PlayerName[32];
				GetClientName(i, PlayerName, sizeof(PlayerName));
				if(l4d2_gamemode()!=2)
					if(!MenuFunc_SpecNext[i])
						PrintToChat(i, "\x04[提示]\x03%s\x04,\x05输入\x03!jg\x05或\x03!join\x05或\x03按鼠标左键\x05加入幸存者.", PlayerName);
					else
						PrintToChat(i, "\x04[提示]\x03%s\x04,\x05聊天窗输入\x03!jg\x05或\x03!join\x05加入幸存者.", PlayerName);
			}
		
	return Plugin_Continue;
}

//救援离开时.
public void Event_FinaleVehicleLeaving(Event event, const char[] name, bool dontBroadcast)
{
	for(int i = 1; i <= MaxClients; i++)
		vTakeOver(i);
	
	StopTimers();
	gbVehicleLeaving = true;
	g_aSteamIDsFinaleVehicleLeaving = true;
	
	int entity = FindEntityByClassname(MaxClients + 1, "info_survivor_position");
	if(entity != INVALID_ENT_REFERENCE)
	{
		int iPlayer;
		float vOrigin[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vOrigin);
		for(int i = 1; i <= MaxClients; i++)
		{
			if(iPlayer++ < 4)
				continue;

			if(IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR)
			{
				entity = CreateEntityByName("info_survivor_position");
				DispatchSpawn(entity);
				TeleportEntity(entity, vOrigin, NULL_VECTOR, NULL_VECTOR);
			}
		}
	}
}

void StopTimers()
{
	delete g_TimerSpecCheck;
}

void BypassAndExecuteCommand(int client, char[] strCommand, char[] strParam1)
{
	int flags = GetCommandFlags(strCommand);
	SetCommandFlags(strCommand, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", strCommand, strParam1);
	SetCommandFlags(strCommand, flags);
}

int FindBotToTakeOver()
{
	for (int i = 1; i <= MaxClients; i++)
		if(IsClientConnected(i) && IsClientInGame(i))
				if (IsFakeClient(i) && GetClientTeam(i) == TEAM_SURVIVOR && IsAlive(i) && !iHasIdlePlayer(i))
					return i;
	return 0;
}

//玩家离开游戏时踢出多余电脑.
void l4d2_kick_SurvivorBot()
{
	//幸存者数量必须大于设置的开局时的幸存者数量.
	if (TotalSurvivors() > hLimit)
		for (int i =1; i <= MaxClients; i++)
			if (IsClientConnected(i) && IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == TEAM_SURVIVOR)
				if (!HasIdlePlayer(i))
				{
					vRemovePlayerWeapons(i);
					KickClient(i, "[提示] 自动踢出多余电脑");
					break;
				}
}

bool HasIdlePlayer(int bot)
{
	if(IsValidEntity(bot))
	{
		char sNetClass[12];
		GetEntityNetClass(bot, sNetClass, sizeof(sNetClass));

		if( strcmp(sNetClass, "SurvivorBot") == 0 )
		{
			if( !GetEntProp(bot, Prop_Send, "m_humanSpectatorUserID") )
				return false;

			int client = GetClientOfUserId(GetEntProp(bot, Prop_Send, "m_humanSpectatorUserID"));
			if(client)
			{
				if(IsClientInGame(client) && !IsFakeClient(client) && (GetClientTeam(client) != TEAM_SURVIVOR))
					return true;
			}
			else
				return false;
		}
	}
	return false;
}

int TotalSurvivors()
{
	int intt = 0;
	for (int i = 1; i <= MaxClients; i++)
		if(IsClientConnected(i))
			if(IsClientInGame(i) && (GetClientTeam(i) == TEAM_SURVIVOR))
				intt++;
	return intt;
}

int TotalFreeBots()
{
	int intt = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsValidEntity(i))continue;
		if(IsClientConnected(i) && IsClientInGame(i))
			if(IsFakeClient(i) && GetClientTeam(i) == TEAM_SURVIVOR)
				if(!iHasIdlePlayer(i))
					intt++;
	}
	return intt;
}

bool vSpawnFakeSurvivorClient()
{
	int client = CreateFakeClient("FakeClient");
	if(client == 0)
		return;

	ChangeClientTeam(client, TEAM_SURVIVOR);

	if(DispatchKeyValue(client, "classname", "SurvivorBot") == false)
		return;

	if(DispatchSpawn(client) == false)
		return;

	//如果创建的电脑幸存者是死亡的则复活.
	if(!IsAlive(client))
		vRoundRespawn(client);
		
	if(hgive0 != 0 && hgive0 == 1)
	{
		vRemovePlayerWeapons(client);
		vGiveDefaultItems(client);
	}
	
	//创建电脑幸存者后传送.
	TeleportClient(client);

	KickClient(client, "[提示] 自动踢出电脑.");
}

//随机传送新加入的幸存者到其他幸存者身边.
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
		if(i != client && IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR && IsAlive(i))
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

//排除死亡的
bool IsAlive(int client)
{
	if(!GetEntProp(client, Prop_Send, "m_lifeState"))
		return true;
	return false;
}

void l4d2_GiveWeapon_pistol_2(int client)
{
	switch(GetRandomInt(0,2))
	{
		case 0:
			BypassAndExecuteCommand(client, "give", "fireaxe");//斧头.
		case 1:
			BypassAndExecuteCommand(client, "give", "pistol");//小手枪
		case 2:
			BypassAndExecuteCommand(client, "give", "pistol_magnum");//马格南
	}
}

void l4d2_GiveWeapon_pistol_3(int client)
{
	switch(GetRandomInt(0,2))
	{
		case 0:
			BypassAndExecuteCommand(client, "give", "pipe_bomb");//土制炸弹
		case 1:
			BypassAndExecuteCommand(client, "give", "molotov ");//燃烧瓶
		case 2:
			BypassAndExecuteCommand(client, "give", "vomitjar");//胆汁
	}
}

void l4d2_GiveWeapon_pistol_4(int client)
{
	switch(GetRandomInt(0,1))
	{
		case 0:
			BypassAndExecuteCommand(client, "give", "first_aid_kit");//医疗包
		case 1:
			BypassAndExecuteCommand(client, "give", "defibrillator");//电击器
	}
}

void l4d2_GiveWeapon_pistol_5(int client)
{
	switch(GetRandomInt(0,1))
	{
		case 0:
			BypassAndExecuteCommand(client, "give", "adrenaline");//肾上腺素
		case 1:
			BypassAndExecuteCommand(client, "give", "pain_pills");//止痛药
	}
}

void l4d2_GiveWeapon_pistol_1(int client)
{
	switch(GetRandomInt(0,1))
	{
		case 0:
			BypassAndExecuteCommand(client, "give", "smg");//冲锋枪
		case 1:
			BypassAndExecuteCommand(client, "give", "smg_silenced");//消声器冲锋枪
	}	
}

public Action GoAFK(int client, int args)
{ 
	switch(haway)
	{
		case 0:
			PrintToChat(client, "\x04[提示]\x05加入旁观者指令已禁用,请在CFG中设为1启用.");
		case 1,2:
		{
			if(GetClientTeam(client) == 1)
				PrintToChat(client, "\x04[提示]\x05你已经是观察者.");
			else if(GetClientTeam(client) == TEAM_SURVIVOR)
			{
				if(haway == 1)
					ChangeClientTeam(client, 1);
				else if(haway == 2)
				{
					if(bCheckClientAccess(client) && iGetClientImmunityLevel(client) >= 98)
						ChangeClientTeam(client, 1);
					else
						ReplyToCommand(client, "\x04[提示]\x05加入旁观者指令只限管理员使用.");
				}
			}
		}
	}
	return Plugin_Handled;
}

public Action Command_kickbot(int client, int args) 
{
	if(bCheckClientAccess(client) && iGetClientImmunityLevel(client) >= 98)
	{
		switch (hkick)
		{
			case 0:
				PrintToChat(client, "\x04[提示]\x05踢出全部电脑幸存者指令已禁用,请在CFG中设为1启用.");
			case 1:
			{
				for (int i = 1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == TEAM_SURVIVOR)
					{
						vRemovePlayerWeapons(i);
						KickClient(i, "[提示] 指令踢出所有电脑幸存者");
					}
				}
				PrintToChat(client, "\x04[提示]\x05已踢出所有电脑.");//此提示使用指令的玩家可见.
			}
		}
	}
	else
		PrintToChat(client, "\x04[提示]\x05你无权使用此指令.");
	return Plugin_Handled;
}

public Action Command_sset(int client, int args)
{
	if(bCheckClientAccess(client) && iGetClientImmunityLevel(client) >= 98)
	{
		switch (hsset)
		{
			case 0:
				PrintToChat(client, "\x04[提示]\x05设置服务器人数指令已禁用,请在CFG中设为1启用.");
			case 1:
				DisplaySLMenu(client);
		}
	}
	else
		PrintToChat(client, "\x04[提示]\x05你无权使用此指令.");
	return Plugin_Handled;
}

void DisplaySLMenu(int client)
{
	char namelist[32];
	char nameno[4];
	Menu menu = new Menu(SLMenuHandler);
	menu.SetTitle("设置服务器人数:");
	
	int i = 1;
	while (i <= 32)
	{
		Format(namelist, sizeof(namelist), "%d", i);
		Format(nameno, sizeof(nameno), "%i", i);
		menu.AddItem(nameno, namelist);
		i++;
	}
	menu.ExitBackButton = true;
	menu.Display(client, 15);
}

public Action Command_BotSet(int client, int args)
{
	if(args == 1)
	{
		char sNumber[4];
		GetCmdArg(1, sNumber, sizeof(sNumber));
		int iNumber = StringToInt(sNumber);
		if(1 <= iNumber <= 24)
		{
			hLimit = iNumber;

			delete g_hBotsUpdateTimer;
			g_hBotsUpdateTimer = CreateTimer(1.0, Timer_BotsUpdate);
	
			ReplyToCommand(client, "\x04[提示]\x05已设置幸存者数量为\x04:\x04%d\x05.", iNumber);
		}
		else
			ReplyToCommand(client, "\x04[提示]\x05请输入1 ~ 24范围内的整数.");
	}
	else
		ReplyToCommand(client, "\x04[提示]\x05用法!botset/sm_botset 空格+<数量>.");

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

public int SLMenuHandler(Handle menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char clientinfos[12];
			GetMenuItem(menu, itemNum, clientinfos, sizeof(clientinfos));
			userids = StringToInt(clientinfos);
			maxplayers = userids;

			SetConVarInt(FindConVar("sv_maxplayers"), userids, false, false);
			SetConVarInt(FindConVar("sv_visiblemaxplayers"), userids, false, false);
			
			PrintToChatAll("\x04[提示]\x05更改服务器的最大人数为\x04:\x03%i\x05人.", userids);
			l4d2_sv_maxplayers = true;
		}
		case MenuAction_End:
			delete menu;
	}
}

public Action GoAwayFromKeyboard(int client, int args)
{
	if (client && IsClientInGame(client))
	{
		if (IsPlayerAlive(client) && GetClientTeam(client) == 2)
		{
			if(!hFileExistsBuildPath())
				FakeClientCommand(client, "go_away_from_keyboard");
			else
			{
				if (IsPlayerFallen(client))
					PrintToChat(client,"\x04[提示]\x05倒地时无法使用休息指令.");
				else if (IsPlayerFalling(client))
					PrintToChat(client,"\x04[提示]\x05挂边时无法使用休息指令.");
				else
				{
					if(gGoAwayFromKeyboard() > 1)
						FakeClientCommand(client, "go_away_from_keyboard");
					else
						PrintToChat(client,"\x04[提示]\x05只有一名真实幸存者时无法使用休息指令.");
				}
			}
		}
		else if(GetClientTeam(client) == 1)
			PrintToChat(client,"\x04[提示]\x05你当前已加入了旁观者.");
		else if(!IsPlayerAlive(client))
			PrintToChat(client,"\x04[提示]\x05死亡状态无权使用休息指令.");
		else
			PrintToChat(client,"\x04[提示]\x05休息指令只限幸存者使用.");
	}
	return Plugin_Handled;
}

//判断真实幸存者数量.
int gGoAwayFromKeyboard()
{
	int count = 0;
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR && !IsFakeClient(i))
			count++;

	return count;
}

//判断这个插件是否存在(如果改名了就会检测不准).
bool hFileExistsBuildPath()
{
	char OldPlugin[128];
	BuildPath(Path_SM, OldPlugin, sizeof(OldPlugin), "plugins/l4d2_go_away_from_keyboard.smx");
	if(FileExists(OldPlugin))
		return false;
	return true;
}

//倒地的.
bool IsPlayerFallen(int client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated") && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}

//挂边的
bool IsPlayerFalling(int client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated") && GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}

void vRemovePlayerWeapons(int client)
{
	int iWeapon;
	for(int i; i < 5; i++)
	{
		iWeapon = GetPlayerWeaponSlot(client, i);
		if(iWeapon > MaxClients && IsValidEntity(iWeapon))
		{
			if(RemovePlayerItem(client, iWeapon))
				RemoveEdict(iWeapon);
		}
	}
}

int l4d2_gamemode()
{
	char gmode[32];
	GetConVarString(FindConVar("mp_gamemode"), gmode, sizeof(gmode));

	if (StrEqual(gmode, "coop", false) || StrEqual(gmode, "realism", false))
		return 1; 
	else if (StrEqual(gmode, "versus", false) || StrEqual(gmode, "teamversus", false))
		return 2;
	if (StrEqual(gmode, "survival", false))
		return 3;
	if (StrEqual(gmode, "scavenge", false) || StrEqual(gmode, "teamscavenge", false))
		return 4; 
	else
		return 0;
}

//玩家在旁观者按鼠标左键自动加入幸存者.
public Action CommandListener_SpecNext(int client, char[] command, int argc)
{
	if(client == 0 || !IsClientInGame(client) || GetClientTeam(client) != 1 || iGetBotOfIdle(client) || MenuFunc_SpecNext[client])
		return Plugin_Continue;
	
	CommandSpecNextMenu(client);
	
	return Plugin_Continue;
}

void CommandSpecNextMenu(int client)
{
	Menu menu = new Menu(MenuHandler_JoinTeam);
	menu.SetTitle("加入幸存者?");
	menu.AddItem("0", "确认");
	menu.AddItem("1", "取消");
	menu.AddItem("2", "不再提示");
	menu.Display(client, 10);
}

public int MenuHandler_JoinTeam(Menu menu, MenuAction action, int client, int param)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			switch (param)
			{
				case 0:
				{
					if (IsValidClientMenu(client))
						JoinTeam_Type(client, false);
				}
				case 1:{}
				case 2:
				{
					if (IsValidClientMenu(client))
						MenuFunc_SpecNext[client] = true;
				}
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

bool IsValidClientMenu(int client)
{
	return (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 1 && !iGetBotOfIdle(client));
}

//禁用游戏自带的闲置提示.
public Action TextMsg(UserMsg msg_id, Handle bf, int[] players, int playersNum, bool reliable, bool init)
{
	static char sUserMess[96];
	
	if (GetUserMessageType() == UM_Protobuf)
		PbReadString(bf, "params", sUserMess, sizeof(sUserMess), 0);
	else
		BfReadString(bf, sUserMess, sizeof(sUserMess));

	if (StrContains(sUserMess, "L4D_idle_spectator", false) != -1)
		return Plugin_Handled;
	
	return Plugin_Continue;
}

//幸存者身份修复.
// 1.7
//[L4D1/2] Survivor Identity Fix for 5+ Survivors
//https://forums.alliedmods.net/showthread.php?p=2403731#post2403731
// ------------------------------------------------------------------------
//  Stores the client of each survivor each time it is changed
//  Needed because when Event_PlayerToBot fires, it's hunter model instead
// ------------------------------------------------------------------------
public MRESReturn mrePlayerSetModelPre(int pThis, DHookParam hParams)
{ } // We need this pre hook even though it's empty, or else the post hook will crash the game.

public MRESReturn mrePlayerSetModelPost(int pThis, DHookParam hParams)
{
	if(pThis < 1 || pThis > MaxClients || !IsClientInGame(pThis))
		return MRES_Ignored;
		
	if(GetClientTeam(pThis) != TEAM_SURVIVOR)
	{
		g_Models[pThis][0] = '\0';
		return MRES_Ignored;
	}
	
	char model[128];
	hParams.GetString(1, model, sizeof(model));
	if (StrContains(model, "survivors", false) >= 0)
		strcopy(g_Models[pThis], 128, model);
	
	return MRES_Ignored;
}

// ------------------------------------------------------------------------
//  Models & survivor names so bots can be renamed
// ------------------------------------------------------------------------
char survivor_names[8][] = { "Nick", "Rochelle", "Coach", "Ellis", "Bill", "Zoey", "Francis", "Louis"};
char survivor_models[8][] =
{
	"models/survivors/survivor_gambler.mdl",
	"models/survivors/survivor_producer.mdl",
	"models/survivors/survivor_coach.mdl",
	"models/survivors/survivor_mechanic.mdl",
	"models/survivors/survivor_namvet.mdl",
	"models/survivors/survivor_teenangst.mdl",
	"models/survivors/survivor_biker.mdl",
	"models/survivors/survivor_manager.mdl"
};

// --------------------------------------
// Bot replaced by player
// --------------------------------------
public void Event_BotToPlayer(Event event, const char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("player"));
	if(player == 0 || !IsClientInGame(player) || IsFakeClient(player) || GetClientTeam(player) != TEAM_SURVIVOR)	// ignore fake players (side product of creating bots)
		return;

	int bot = GetClientOfUserId(event.GetInt("bot"));

	char sModel[128];
	GetClientModel(bot, sModel, sizeof(sModel));
	SetEntityModel(player, sModel);
	SetEntProp(player, Prop_Send, "m_survivorCharacter", GetEntProp(bot, Prop_Send, "m_survivorCharacter"));
}

// --------------------------------------
// Player -> Bot
// --------------------------------------
public void Event_PlayerToBot(Event event, const char[] name, bool dontBroadcast)
{
	int player	= GetClientOfUserId(GetEventInt(event, "player"));

	if(player == 0 || !IsClientInGame(player) || IsFakeClient(player) || GetClientTeam(player) != TEAM_SURVIVOR)	// ignore fake players (side product of creating bots)
		return;
		
	int bot		= GetClientOfUserId(GetEventInt(event, "bot")); 
	
	if (g_Models[player][0] == '\0')
		return;
	
	SetEntProp(bot, Prop_Send, "m_survivorCharacter", GetEntProp(player, Prop_Send, "m_survivorCharacter"));
	SetEntityModel(bot, g_Models[player]); // Restore saved model. Player model is hunter at this point
	for (int i = 0; i < 8; i++)
	{
		if (StrEqual(g_Models[player], survivor_models[i]))
			SetClientInfo(bot, "name", survivor_names[i]);
	}
}

//幸存者5+闲置修复.
public MRESReturn OnGoAFKPre(int pThis, Handle hReturn)
{
	g_bShouldFixAFK = true;
	return MRES_Ignored;
}

//pThis should only be CTerrorPlayer class and real players only not going to check for it
public MRESReturn OnGoAFKPost(int pThis, Handle hReturn)
{
	if(g_bShouldFixAFK && g_iSurvivorBot > 0 && IsFakeClient(g_iSurvivorBot))
	{
		g_bShouldIgnore = true;
		
		SDKCall(hSetHumanSpec, g_iSurvivorBot, pThis);
		SDKCall(hSetObserverTarget, pThis, g_iSurvivorBot);
		
		WriteTakeoverPanel(pThis, g_iSurvivorBot);
		
		g_bShouldIgnore = false;
	}
	
	g_iSurvivorBot = 0;
	g_bShouldFixAFK = false;
	return MRES_Ignored;
}

//Only thing we need is the bot single threaded logic means we use the call order
public void OnEntityCreated(int entity, const char[] classname)
{
	if(!g_bShouldFixAFK)
		return;
	
	if(classname[0] != 's' || !StrEqual(classname, "survivor_bot", false))
		return;
	
	g_iSurvivorBot = entity;
}

public MRESReturn OnSetHumanSpectatorPre(int pThis, Handle hParams)
{
	if(g_bShouldIgnore)
		return MRES_Ignored;
	
	if(!g_bShouldFixAFK)
		return MRES_Ignored;
	
	if(g_iSurvivorBot < 1)
		return MRES_Ignored;
	
	return MRES_Supercede;
}

//Thanks Leonardo for helping me with the vgui keyvalue layout
//This is for rare case sometimes the takeover panel don't show.
void WriteTakeoverPanel(int client, int bot)
{
	char buf[2];
	int character = GetEntProp(bot, Prop_Send, "m_survivorCharacter", 1);
	IntToString(character, buf, sizeof(buf));
	BfWrite msg = view_as<BfWrite>(StartMessageOne("VGUIMenu", client));
	msg.WriteString("takeover_survivor_bar"); //type
	msg.WriteByte(true); //hide or show panel type
	msg.WriteByte(1); //amount of keys
	msg.WriteString("character"); //key name
	msg.WriteString(buf); //key value
	EndMessage();
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	vTakeOver(GetClientOfUserId(event.GetInt("userid")));
}

void vTakeOver(int bot)
{
	int iIdlePlayer;
	if(bot && IsClientInGame(bot) && IsFakeClient(bot) && GetClientTeam(bot) == TEAM_SURVIVOR && (iIdlePlayer = iHasIdlePlayer(bot)))
	{
		SDKCall(hSetHumanSpec, bot, iIdlePlayer);
		SDKCall(hSetObserverTarget, iIdlePlayer, bot);
		SDKCall(hTakeOverBot, iIdlePlayer, true);
	}
}