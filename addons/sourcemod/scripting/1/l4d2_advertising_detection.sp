#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

#define PLUGIN_VERSION	"1.0.0"
#define SIZEOF			128

//在线免费主播国产嫂子乱伦网址网站
//这里根据格式填写关键字.
char g_sDetection[][] =
{
	"在线",
	"免费",
	"主播",
	"国产",
	"嫂子",
	"乱伦",
	"网址",
	"网站",
	"rpg",
	"RPG",
	"buy",
	"rygive",
	"",
	"",
	"",
	"",
	""
};

public Plugin myinfo = 
{
	name        = "l4d2_advertising_detection",
	author      = "豆瓣酱な",
	description = "关键字检测(预防麦片哥).",
	version     = "PLUGIN_VERSION",
	url         = "N/A"
};

public Action OnClientSayCommand(int client, const char[] commnad, const char[] args)
{
	if(GetPlayerChatContent(client, g_sDetection, sizeof(g_sDetection), args, SIZEOF))
		return Plugin_Handled;//阻止玩家输入的内容显示出来.
	return Plugin_Continue;
}

bool GetPlayerChatContent(int client, char[][] sContent, int iContent, const char[] args, int value)
{
	int count;
	char g_sData[128];
	char[][] g_sInfo = new char[iContent][value];//更改为动态大小的数组.
	for (int i = 0; i < iContent; i++)
	{
		if(sContent[i][0] == '\0')//关键字等于空.
			continue;//跳过这个循环执行下一个循环.
			
		if(StrContains(args, sContent[i]) != -1)//聊天窗内容里有关键字.
		{
			strcopy(g_sInfo[count], value, sContent[i]);//把关键字写入数组用于显示.
			count += 1;//玩家一句话里有多少个关键字.
		}
	}
	if(count > 0)
	{
		char g_sDisplay[128];
		ImplodeStrings(g_sInfo, count, "|", g_sData, sizeof(g_sData));//打包字符串.
		//PrintToChat(client, "\x04[提示]\x05触发关键字(%s).", g_sData);
		FormatEx(g_sDisplay, sizeof(g_sDisplay), "检测到疑似发布违反法例法规的内容.\n触发关键字(%s)", g_sData);
		//BanClient(client, time, BANFLAG_AUTO, g_sDisplay, g_sDisplay);//封禁触发关键字的玩家.
		KickClient(client, g_sDisplay);//踢出触发关键字的玩家.
		return true;
	}
	return false;
}

