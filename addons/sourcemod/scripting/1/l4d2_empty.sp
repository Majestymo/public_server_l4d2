#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <dhooks>
#include <left4dhooks>

#define CVAR_FLAGS		FCVAR_NOTIFY

char chatFile[128];
bool bHibernating = true;

int    g_iEmptyLog, g_iEmptySwitch, g_iEmptyCrash, g_iEmptyType;
ConVar g_hEmptyLog, g_hEmptySwitch, g_hEmptyCrash, g_hEmptyType;

public Plugin myinfo =
{
	name = "[L4D2] Empty",
	author = "lakwsh",
	version = "1.0.1"
}

public void OnPluginStart()
{
	LoadGameCFG();
	g_hEmptyLog 	= CreateConVar("l4d2_empty_Log",	"1", "服务器无人后记录日志内容? 0=禁用, 1=启用.", CVAR_FLAGS);
	g_hEmptySwitch 	= CreateConVar("l4d2_empty_Switch",	"1", "服务器里没人时崩溃服务端? 0=禁用, 1=启用.", CVAR_FLAGS);
	g_hEmptyCrash 	= CreateConVar("l4d2_empty_crash",	"1", "允许什么系统的服务器崩溃? 1=linux, 2=windows, 3=两者.", CVAR_FLAGS);
	g_hEmptyType 	= CreateConVar("l4d2_empty_type",	"1", "允许什么类型的服务器崩溃? 1=专用服务器, 2=本地服务器, 3=两者.", CVAR_FLAGS);
	
	g_hEmptyLog.AddChangeHook(EmptyConVarChanged);
	g_hEmptySwitch.AddChangeHook(EmptyConVarChanged);
	g_hEmptyCrash.AddChangeHook(EmptyConVarChanged);
	g_hEmptyType.AddChangeHook(EmptyConVarChanged);
	AutoExecConfig(true, "l4d2_empty");
}

public void EmptyConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	EmptyCvars();
}

public void OnConfigsExecuted()
{
	EmptyCvars();
}

void EmptyCvars()
{
	g_iEmptyLog = g_hEmptyLog.IntValue;
	g_iEmptySwitch = g_hEmptySwitch.IntValue;
	g_iEmptyCrash = g_hEmptyCrash.IntValue;
	g_iEmptyType = g_hEmptyType.IntValue;
}

void LoadGameCFG()
{
	GameData hGameData = new GameData("l4d2_empty");
	if(!hGameData)
		SetFailState("Failed to load 'l4d2_empty.txt' gamedata.");
	DHookSetup hDetour = DHookCreateFromConf(hGameData,"SetHibernating");
	if(!hDetour || !DHookEnableDetour(hDetour, true, OnSetHibernating))
	{
		SetFailState("Failed to hook SetHibernating");
		CloseHandle(hGameData);
	}
}

public MRESReturn OnSetHibernating(DHookParam hParams)
{
	if(g_iEmptySwitch <= 0)
		return MRES_Handled;
	
	bool tmp = DHookGetParam(hParams, 1) == 1;//windows
	if (tmp && bHibernating != tmp)
	{
		int iGetServerOS = L4D_GetServerOS();//判断系统类型:0=windows,1=linux.
		IsDetermineSystemType(iGetServerOS);//判断系统类型.
	}
	bHibernating = tmp;
	return MRES_Handled;
}

//判断系统类型.
void IsDetermineSystemType(int iType)
{
	switch (iType)
	{
		case 0:
		{
			if(g_iEmptyCrash == 2 || g_iEmptyCrash == 3)
				IsDetermineTheServerType(iType);//判断服务器类型.
		}
		case 1:
		{
			if(g_iEmptyCrash == 1 || g_iEmptyCrash == 3)
				IsDetermineTheServerType(iType);//判断服务器类型.
		}
	}
}

//判断服务器类型.
void IsDetermineTheServerType(int iType)
{
	if(IsDedicatedServer())//判断服务器类型:true=专用服务器,false=本地服务器.
	{
		if(g_iEmptyType == 1 || g_iEmptyType == 3)
			IsLoggingAndExecutionCrashes(iType);//记录日志和执行崩溃服务器.
	}
	else
	{
		if(g_iEmptyType == 2 || g_iEmptyType == 3)
			IsLoggingAndExecutionCrashes(iType);//记录日志和执行崩溃服务器.
	}
}

//记录日志和执行崩溃服务器.
void IsLoggingAndExecutionCrashes(int iType)
{
	UnloadAccelerator();//卸载崩溃记录扩展.
	IsRecordLogContent(iType);//写入日志内容到文件.
	IsExecuteCrashServerCode();//执行崩溃服务端代码.
}

//卸载崩溃记录扩展.
void UnloadAccelerator()
{
	int Id = GetAcceleratorId();
	if (Id != -1)
	{
		ServerCommand("sm exts unload %i 0", Id);
		ServerExecute();//立即执行.
	}
}

//by sorallll
int GetAcceleratorId()
{
	char sBuffer[512];
	ServerCommandEx(sBuffer, sizeof(sBuffer), "sm exts list");
	int index = SplitString(sBuffer, "] Accelerator (", sBuffer, sizeof(sBuffer));
	if(index == -1)
		return -1;

	for(int i = strlen(sBuffer); i >= 0; i--)
	{
		if(sBuffer[i] == '[')
			return StringToInt(sBuffer[i + 1]);
	}

	return -1;
}

//写入日志内容到文件.
void IsRecordLogContent(int iType)
{
	//记录日志.
	if (g_iEmptyLog == 1)
	{
		char Msg[256], Time[32];
		IsCreateLogFile();//初始化日志文件,如果没有就创建.
		FormatTime(Time, sizeof(Time), "%Y-%m-%d %H:%M:%S", -1);
		Format(Msg, sizeof(Msg), "服务器没人了:[%s],系统类型:%s,服务器类型:%s", Time, iType == 0 ? "windows" : iType == 1 ? "linux" : "其它", IsDedicatedServer() ? "专用" : "本地");

		IsSaveMessage("--=============================================================--");
		IsSaveMessage(Msg);
		IsSaveMessage("--=============================================================--");
	}
}

//创建日志文件.
void IsCreateLogFile()
{
	char Date[32], logFile[128];
	FormatTime(Date, sizeof(Date), "%y%m%d", -1);
	Format(logFile, sizeof(logFile), "/logs/Empty%s.log", Date);
	BuildPath(Path_SM, chatFile, PLATFORM_MAX_PATH, logFile);
}

//把日志内容写入文本里.
void IsSaveMessage(const char[] Message)
{
	File fileHandle = OpenFile(chatFile, "a");  /* Append */
	fileHandle.WriteLine(Message);
	delete fileHandle;
}

//执行崩溃服务端代码.
void IsExecuteCrashServerCode()
{
	SetCommandFlags("crash", GetCommandFlags("crash") &~ FCVAR_CHEAT);
	ServerCommand("crash");
	SetCommandFlags("sv_crash", GetCommandFlags("sv_crash") &~ FCVAR_CHEAT);
	ServerCommand("sv_crash");
}
