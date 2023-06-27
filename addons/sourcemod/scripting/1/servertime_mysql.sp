//玩家服务器时长统计，mysql数据库
#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <colors>
#include <float>
#include <adt_array> 
#define PLUGIN_VERSION "2.0"
#define DB_CONF_NAME "l4d2"
//Plugin_Continue
//业务逻辑：
// connect--->初始化(读取MYSQL数据，为空则添加)---离开游戏(更新玩家数据UPDATE)
new String:Init[]="INSERT INTO `l4d2`(`steam_id`, `steam_name`, `time_DATA`, `STATUS`) VALUES (?,?,0,1)"; 
new String:Select[]="select * from l4d2 l where l.steam_id=?";
new String:Update[]="update l4d2 l set l.steam_name=?,l.STATUS=1 where l.steam_id=?"; //这个是过图或者重启关卡的时候更新一次，不更新游戏时间
new String:Update_Disconnect[]="update l4d2 l set l.steam_name=?,l.time_DATA=l.time_DATA+?,l.STATUS=0 where l.steam_id=?";//这个是离开游戏，然后更新一下所有数据以及游戏时间
enum data
{
	time,
	res
};
int player_data[MAXPLAYERS+1][data];

public Plugin:myinfo =  
{
	name = "服务器、资料游戏时长",
	author = "star",  
	description = "服务器、资料游戏时长",
	version = PLUGIN_VERSION,
	url = ""
};

public OnMapEnd()
{
decl String:id[30];
for (new i=1;i<=MaxClients;i++)
{
	if (IsClientConnected(i) && IsClientInGame(i))
	{
	
		GetClientAuthId(i,AuthId_Steam2,id,sizeof(id));
		if (!StrEqual(id, "BOT"))
				Update_DATA(i,false);
	}
}
}

public OnPluginStart() 
{
	RegAdminCmd("sm_init",Player_init,ADMFLAG_ROOT);
	RegAdminCmd("sm_initall",Player_initALL,ADMFLAG_ROOT);
	RegAdminCmd("sm_dist",Player_Dis,ADMFLAG_ROOT);
	RegConsoleCmd("sm_stats", Player_Stats);
	HookEvent("round_start", EvtRoundStart);
	HookEvent("player_disconnect", Event_PlayerDisconnect,EventHookMode_Pre);  
	CreateTimer(33.0, STATS_Timer);
}

public Action:EvtRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
decl String:id[30];
for (new i=1;i<=MaxClients;i++)
{
	if (IsClientConnected(i) && IsClientInGame(i))
	{
	
		GetClientAuthId(i,AuthId_Steam2,id,sizeof(id));
		if (!StrEqual(id, "BOT"))
		{
			if(!Update_DATA(i,false)) return;
			CPrintToChat(i,"{red}【提示】:{green}从数据库获取数据成功,记录的游戏时间为:{red}%d{green}小时{red}%d{green}分钟",(player_data[i][time])/60/60,(player_data[i][time])/60%60);	
		}
	}
}
CPrintToChatAll("{red}【提示】:与服务器同步数据成功");
}

public OnClientPostAdminCheck(client)
{
	decl String:id[32];
	if (IsClientConnected(client))
	GetClientAuthId(client,AuthId_Steam2,id,sizeof(id));
	if ((StrEqual(id, "BOT")))	 return ;
	if(MYSQL_INIT(client,id))
	{
	CPrintToChat(client,"{red}【提示】:{green}从数据库获取数据成功,你已经玩了:{red}%d{green}小时{red}%d{green}分钟",player_data[client][time]/60/60,player_data[client][time]/60%60);
	}
}

public Action:Event_PlayerDisconnect(Handle:event, String:event_name[], bool:dontBroadcast)
{
	decl String:id[40];
	int client=GetClientOfUserId(GetEventInt(event,"userid"));
	GetClientAuthId(client,AuthId_Steam2,id,sizeof(id));
	if ((StrEqual(id, "BOT"))) return Plugin_Continue;
	//CPrintToChatAll("%N %s离开游戏",client,id);
	Update_DATA(client,true);	
	return Plugin_Continue;
}

bool Update_DATA(client,bool:IsDisconnect=false,bool:IsMapStart=false) 
{
	decl String:id[40];
	new String:error[256];
	new String:NAMES[256];
	GetClientName(client,NAMES,sizeof(NAMES));
	GetClientAuthId(client,AuthId_Steam2,id,sizeof(id));
	if ((StrEqual(id, "BOT"))) return false;
	// kill,
	// hurt,
	// time,
	// res
	// steam_id steam_name KILL_DATA hurt_DATA time_DATA res_DATA

	if (!SQL_CheckConfig(DB_CONF_NAME))
	{
		LogError("Databases.cfg missing '%s' entry!", DB_CONF_NAME);
		return false;
	}
	new Database:db = SQL_Connect(DB_CONF_NAME, true, error, sizeof(error));
	//db = SQL_Connect(DB_CONF_NAME, true, error, sizeof(error));
	if (db == null) {
		PrintToServer("【严重错误】:无法连接到MySQL数据库，错误信息：%s", error);
		CPrintToChatAll("{red}【严重错误】:无法连接到MySQL数据库，错误信息：%s", error);
		return false;
	}
	if(!SQL_FastQuery(db, "SET NAMES 'UTF8'"))
	{
		if(SQL_GetError(db,error,sizeof(error)))
			CPrintToChatAll("{red}【严重错误】:无法更改为UTF-8编码，错误信息：%s", error);
		else
			CPrintToChatAll("{red}【严重错误】:无法更改为UTF-8编码，错误信息：未知");
	}	
	if(IsMapStart)
	{
		SQL_FastQuery(db, "update l4d2 l set l.STATUS=0");	
	}	
	DBStatement hAddQuery;
	if(IsDisconnect){
		if ((hAddQuery = SQL_PrepareQuery(db, Update_Disconnect, error, sizeof(error))) == null)
		{
			PrintToServer("SQL_PrepareQuery出现错误");
			delete db;
			return false;
		}
	}else{
		if ((hAddQuery = SQL_PrepareQuery(db, Update, error, sizeof(error))) == null)
		{
			PrintToServer("SQL_PrepareQuery出现错误");
			delete db;
			return false;
		}
	}
	//下面是参数绑定
	//行数sizeof(args)/sizeof(args[0])
	//SQL_BindParamInt
	SQL_BindParamString(hAddQuery,1,NAMES,true);
	if(IsDisconnect)
	{
		SQL_BindParamFloat(hAddQuery,2,GetClientTime(client));
		SQL_BindParamString(hAddQuery,0,id,true);
	}else{
		SQL_BindParamString(hAddQuery,0,id,true);
	}
	if (!SQL_Execute(hAddQuery))
	{
		PrintToServer("SQL_Execute出现错误1");
		if(SQL_GetError(db,error,sizeof(error)))
			CPrintToChatAll("{red}【严重错误】:无法提交信息，错误信息：%s", error);
		else
			CPrintToChatAll("{red}【严重错误】:无法提交信息，错误信息：未知");		
	}
	db.Close();
	return true; 
}

public bool MYSQL_INIT(client,String:id[])
{
//全插件只有这个地方是查询
	new String:error[256];
	new String:NAMES[256];
	//ArrayList array=CreateArray(40,1);
	ArrayList array=CreateArray(4,1);
	//if(GetClientTime(client)>0.0) return true; //已经在游戏则不用查询了
	new Database:db = SQL_Connect(DB_CONF_NAME, true, error, sizeof(error));
	if (db == null) {
		PrintToServer("【严重错误】:无法连接到MySQL数据库，错误信息：%s", error);
		CPrintToChatAll("{red}【严重错误】:无法连接到MySQL数据库，错误信息：%s", error);
		return false;
	}
	DBStatement hAddQuery;
	if ((hAddQuery = SQL_PrepareQuery(db, Select, error, sizeof(error))) == null)
	{
		PrintToServer("SQL_PrepareQuery出现错误%s",error);
		CPrintToChatAll("SQL_PrepareQuery出现错误%s",error);
		delete db;
		return false;
	}
	//下面是参数绑定
	//行数sizeof(args)/sizeof(args[0])
	SQL_BindParamString(hAddQuery,0,id,true);
	if (!SQL_Execute(hAddQuery))
	{
		PrintToServer("SQL_Execute出现错误2");
	}
	if(!SQL_FetchRow(hAddQuery))
	{
		CPrintToChat(client,"{red}[注意]:您初次登录本服务器，即将为您初始化数据");
	// enum data
	// {
	// kill,
	// hurt,
	// time,
	// res
	// };
		CloseHandle(hAddQuery);
		db.Close();
		GetClientName(client,NAMES,sizeof(NAMES));
		SetArrayString(array,0,id);
		ResizeArray(array,GetArraySize(array)+1);
		// 每增加一条数据都要进行ResizeArray(array,GetArraySize(array)+1)操作
		SetArrayString(array,1,NAMES);
		//SetArrayInt(array,2,GetClientTime(client));
		//SetArrayString(array,1,NAMES);
		MySQLTransaction(Init,array);		
		return true;
	}else{
	//查询到数据了
	//SQL_FetchInt(hQuery, 1);
	//SQL_FetchString
	player_data[client][time]=SQL_FetchInt(hAddQuery, 2);
	}
	db.Close();
	return true;	
}

public Action:Player_init(client,args)
{
	decl String:id[32];
	if (IsClientConnected(client))
	GetClientAuthId(client,AuthId_Steam2,id,sizeof(id));
	else return ;
	if ((StrEqual(id, "BOT")))	 return ;
	if(MYSQL_INIT(client,id))
	{
	CPrintToChat(client,"{red}【提示】:{green}从数据库获取数据成功,你已经玩了:{red}%d{green}小时{red}%d{green}分钟",player_data[client][time]/60/60,player_data[client][time]/60%60);
	}
}

public Action:Player_initALL(client,args)
{
decl String:id[30];
for (new i=1;i<=MaxClients;i++)
{
	if (IsClientConnected(i) && IsClientInGame(i))
	{
	
		GetClientAuthId(i,AuthId_Steam2,id,sizeof(id));
		if (!StrEqual(id, "BOT"))
				MYSQL_INIT(i,id);
	}
}
}

public Action:STATS_Timer(Handle:timer)
{
	CPrintToChatAll("{red}[提示]:{green}服务器加入玩家信息记录系统，可以使用 {red}!stats{green} 查看");
	CreateTimer(33.0, STATS_Timer);
}
public Action:Player_Dis(client,args)
{
Update_DATA(client,false);
}
public Action:Player_Stats(client,args)
{
CPrintToChat(client,"{red}【提示】:{green}玩家数据为：{green}玩家数据为:\n{red}%.2f小时", player_data[client][time]/60/60);	
}

public bool MySQLTransaction(char[] query,ArrayList  array)
{
	
	new String:error[256];
	new String:buffer[256];
	new Database:db = SQL_Connect(DB_CONF_NAME, true, error, sizeof(error));
	if (db == null) {
		PrintToServer("【严重错误】:无法连接到MySQL数据库，错误信息：%s", error);
		CPrintToChatAll("{red}【严重错误】:无法连接到MySQL数据库，错误信息：%s", error);
		return false;
	}
	if(!SQL_FastQuery(db, "SET NAMES 'UTF8'"))
	{
		if(SQL_GetError(db,error,sizeof(error)))
			CPrintToChatAll("{red}【严重错误】:无法更改为UTF-8编码，错误信息：%s", error);
		else
			CPrintToChatAll("{red}【严重错误】:无法更改为UTF-8编码，错误信息：未知");
	}	
	DBStatement hAddQuery;
	if ((hAddQuery = SQL_PrepareQuery(db, query, error, sizeof(error))) == null)
	{
		PrintToServer("SQL_PrepareQuery出现错误");
		delete db;
		return false;
	}
	//下面是参数绑定
	//行数sizeof(args)/sizeof(args[0])
	for(int i=0;i<GetArraySize(array);i++)
	{
		GetArrayString(array,i,buffer,sizeof(buffer));
		SQL_BindParamString(hAddQuery,i,buffer,true);
		PrintToServer("位置%d绑定值为%s\n",i,buffer);
	}
	if (!SQL_Execute(hAddQuery))
	{
		PrintToServer("SQL_Execute出现错误3");
		if(SQL_GetError(db,error,sizeof(error)))
			CPrintToChatAll("{red}【严重错误】:无法提交信息，错误信息：%s", error);
		else
			CPrintToChatAll("{red}【严重错误】:无法提交信息，错误信息：未知");		
	}
	db.Close();
	return true;
}

