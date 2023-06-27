/********************************************************************************************
* Plugin	: L4D/L4D2 InfectedBots (Versus Coop/Coop Versus)
* Version	: 2.8.2  (2009-2023)
* Game		: Left 4 Dead 1 & 2
* Author	: djromero (SkyDavid, David) and MI 5 and Harry Potter
* Website	: https://forums.alliedmods.net/showpost.php?p=2699220&postcount=1371
*
* Purpose	: This plugin spawns infected bots in L4D1/2, and gives greater control of the infected bots in L4D1/L4D2.
* WARNING	: Please use sourcemod's latest 1.10 branch snapshot.
* REQUIRE	: left4dhooks  (https://forums.alliedmods.net/showthread.php?p=2684862)
* Version 2.8.2 (2023-5-27)
*	   - Add a convar, including dead survivors or not
*	   - Add a convar, disable infected bots spawning or not in versus/scavenge mode
********************************************************************************************/
#pragma semicolon 1
#pragma newdecls required //強制1.7以後的新語法
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <multicolors>
#undef REQUIRE_PLUGIN
#include <left4dhooks>
#define PLUGIN_VERSION "2.8.2-2023/5/27"
#define DEBUG 0

#define TEAM_SPECTATOR		1
#define TEAM_SURVIVORS 		2
#define TEAM_INFECTED 		3

#define ZOMBIECLASS_SMOKER	1
#define ZOMBIECLASS_BOOMER	2
#define ZOMBIECLASS_HUNTER	3
#define ZOMBIECLASS_SPITTER	4
#define ZOMBIECLASS_JOCKEY	5
#define ZOMBIECLASS_CHARGER	6

#define NUM_TYPES_INFECTED_MAX 7 // for spawning
int SI_SMOKER = 0;
int SI_BOOMER = 1;
int SI_HUNTER = 2;
int SI_SPITTER = 3;
int SI_JOCKEY = 4;
int SI_CHARGER = 5;
int SI_TANK = 6;

#define MAXENTITIES 2048
#define SUICIDE_TIME 10
// Infected models
#define MODEL_SMOKER "models/infected/smoker.mdl"
#define MODEL_BOOMER "models/infected/boomer.mdl"
#define MODEL_HUNTER "models/infected/hunter.mdl"
#define MODEL_SPITTER "models/infected/spitter.mdl"
#define MODEL_JOCKEY "models/infected/jockey.mdl"
#define MODEL_CHARGER "models/infected/charger.mdl"
#define MODEL_TANK "models/infected/hulk.mdl"
#define ZOMBIESPAWN_Attempts 7
#define IGNITE_TIME 3600.0

// l4d1/2 value
static char sSpawnCommand[32];
static int ZOMBIECLASS_TANK;
int NUM_INFECTED;


// Variables
int InfectedRealCount; // Holds the amount of real alive infected players
int InfectedRealQueue; // Holds the amount of real infected players that are going to spawn
int InfectedBotCount; // Holds the amount of infected bots in any gamemode
int InfectedBotQueue; // Holds the amount of bots that are going to spawn (including human infected player in coop/realism/survival)
int g_iCurrentMode = 0; // Holds the g_iCurrentMode, 1 for coop and realism, 2 for versus, teamversus, scavenge and teamscavenge, 3 for survival
int TanksPlaying; // Holds the amount of tanks on the playing field
int g_iSpawnWeights[NUM_TYPES_INFECTED_MAX];
int g_iSpawnLimits[NUM_TYPES_INFECTED_MAX];
int g_iSpawnCounts[NUM_TYPES_INFECTED_MAX];
int g_iMaxPlayerZombies; // Holds the amount of the maximum amount of special zombies on the field
int MaxPlayerTank; // Used for setting an additional slot for each tank that spawns
int g_iCoordinationBotReady; // Used to determine how many bots are ready, used only for the coordination feature
int iPlayersInSurvivorTeam;

// Booleans
bool b_HasRoundStarted; // Used to state if the round started or not
bool g_bHasRoundEnded; // States if the round has ended or not
bool g_bLeftSaveRoom; // States if the survivors have left the safe room
bool g_bFinaleStarted; // States whether the finale has started or not
bool TankReplacing; // Used only in coop, prevents the Sound hook event from triggering over and over again
bool PlayerLifeState[MAXPLAYERS+1]; // States whether that player has the lifestate changed from switching the gamemode
bool g_bInitialSpawn; // Related to the coordination feature, tells the plugin to let the infected spawn when the survivors leave the safe room
bool g_bL4D2Version = false; // Holds the version of L4D; false if its L4D, true if its L4D2
bool TempBotSpawned; // Tells the plugin that the tempbot has spawned
bool PlayerHasEnteredStart[MAXPLAYERS+1];
bool bDisableSurvivorModelGlow;
bool g_bSurvivalStart;
bool g_bIsCoordination;
bool g_bInfectedSpawnSameFrame, g_bScaleWeights, g_bIncludingDeadPlayers, g_bDisableInfectedBot;

// ConVar
ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog;
ConVar g_hSpawnWeights[NUM_TYPES_INFECTED_MAX];
ConVar g_hSpawnLimits[NUM_TYPES_INFECTED_MAX];
ConVar g_hScaleWeights;
ConVar h_MaxPlayerZombies; // Related to the max specials cvar
ConVar h_PlayerAddZombiesScale;
ConVar h_PlayerAddZombies;
ConVar h_PlayerAddTankHealthScale;
ConVar h_PlayerAddTankHealth;
ConVar h_InfectedSpawnTimeMax; // Related to the spawn time cvar
ConVar h_InfectedSpawnTimeMin; // Related to the spawn time cvar
ConVar h_CoopPlayableTank; // yup, same thing again
ConVar h_JoinableTeams; // Can you guess this one?
ConVar h_StatsBoard; // Oops, now we are
ConVar h_JoinableTeamsAnnounce;
ConVar h_Coordination;
ConVar h_Idletime_b4slay;
ConVar h_InitialSpawn;
ConVar h_HumanCoopLimit;
ConVar h_JoinInfectedAccess;
ConVar h_DisableSpawnsTank;
ConVar h_TankLimit, h_PlayerAddTankLimitScale, h_PlayerAddTankLimit;
ConVar h_WitchLimit;
ConVar h_VersusCoop;
ConVar h_AdjustSpawnTimes;
ConVar h_InfHUD;
ConVar h_Announce ;
ConVar h_TankHealthAdjust;
ConVar h_TankHealth;
ConVar h_Difficulty;
ConVar cvarZombieHP[7];				// Array of handles to the 4 cvars we have to hook to monitor HP changes
ConVar h_SafeSpawn;
ConVar h_SpawnDistanceMin;
ConVar h_WitchPeriodMax;
ConVar h_WitchPeriodMin;
ConVar h_WitchSpawnFinal;
ConVar h_TankSpawnFinal;
ConVar h_WitchKillTime;
ConVar h_ReducedSpawnTimesOnPlayer;
ConVar h_SpawnTankProbability;
ConVar h_ZSDisableGamemode;
ConVar h_CommonLimitAdjust, h_CommonLimit, h_PlayerAddCommonLimitScale, h_PlayerAddCommonLimit,h_common_limit_cvar;
ConVar h_CoopInfectedPlayerFlashLight;
ConVar h_StatusAnnouncementEnable;
ConVar h_CoopInfectedPlayerGhostState;
ConVar h_InfectedSpawnSameFrame, h_WhereToSpawnInfected, h_IncludingDeadPlayers, h_DisableInfectedBot;

ConVar sb_all_bot_game, allow_all_bot_survivor_team, sb_all_bot_team, vs_max_team_switches, versus_tank_bonus_health, z_max_player_zombies,
	director_no_specials, director_allow_infected_bots;
int vs_max_team_switches_default;
bool sb_all_bot_game_default, allow_all_bot_survivor_team_default, sb_all_bot_team_default, director_no_specials_bool;
bool g_bFirstRecord;
bool DisplayLock = false;

//Handle
Handle PlayerLeftStartTimer = null; //Detect player has left safe area or not
Handle infHUDTimer 		= null;	// The main HUD refresh timer
Panel pInfHUD = null;
Handle usrHUDPref 		= null;	// Stores the client HUD preferences persistently
Handle FightOrDieTimer[MAXPLAYERS+1] = {null}; // kill idle bots
Handle hSpawnWitchTimer = null;
Handle RestoreColorTimer[MAXPLAYERS+1] = {null};
Handle DisplayTimer, InitialSpawnResetTimer;

#define L4D_MAXPLAYERS 32
Handle SpawnInfectedBotTimer[L4D_MAXPLAYERS+1] = {null};

//signature call
static Handle hFlashLightTurnOn = null;
static Handle hCreateSmoker = null;
#define NAME_CreateSmoker "NextBotCreatePlayerBot<Smoker>"
static Handle hCreateBoomer = null;
#define NAME_CreateBoomer "NextBotCreatePlayerBot<Boomer>"
static Handle hCreateHunter = null;
#define NAME_CreateHunter "NextBotCreatePlayerBot<Hunter>"
static Handle hCreateSpitter = null;
#define NAME_CreateSpitter "NextBotCreatePlayerBot<Spitter>"
static Handle hCreateJockey = null;
#define NAME_CreateJockey "NextBotCreatePlayerBot<Jockey>"
static Handle hCreateCharger = null;
#define NAME_CreateCharger "NextBotCreatePlayerBot<Charger>"
static Handle hCreateTank = null;
#define NAME_CreateTank "NextBotCreatePlayerBot<Tank>"

// Stuff related to Durzel's HUD (Panel was redone)
int respawnDelay[MAXPLAYERS+1]; 			// Used to store individual player respawn delays after death
int hudDisabled[MAXPLAYERS+1];				// Stores the client preference for whether HUD is shown
int clientGreeted[MAXPLAYERS+1]; 			// Stores whether or not client has been shown the mod commands/announce
int zombieHP[7];					// Stores special infected max HP
bool roundInProgress 		= false;		// Flag that marks whether or not a round is currently in progress
float fPlayerSpawnEngineTime[MAXPLAYERS+1] = {0.0}; //time when real infected player spawns

int g_iClientColor[MAXPLAYERS+1], g_iClientIndex[MAXPLAYERS+1], g_iLightIndex[MAXPLAYERS+1];
int iPlayerTeam[MAXPLAYERS+1];
bool g_bCvarAllow, g_bMapStarted, g_bSafeSpawn, g_bTankHealthAdjust, g_bVersusCoop, g_bJoinableTeams, g_bCoopPlayableTank , g_bJoinableTeamsAnnounce,
	g_bCoordination, g_bInfHUD, g_bAnnounce, g_bDisableSpawnsTank, g_bAdjustSpawnTimes, g_bCommonLimitAdjust, 
	g_bCoopInfectedPlayerFlashLight, g_bStatusAnnouncementEnable, g_bCoopInfectedPlayerGhostState, g_bWitchSpawnFinal,
	g_bTankSpawnFinal;
int g_iZSDisableGamemode, g_iTankHealth, g_iInfectedSpawnTimeMax, g_iInfectedSpawnTimeMin, g_iHumanCoopLimit,
	g_iReducedSpawnTimesOnPlayer, g_iWitchPeriodMax, g_iWitchPeriodMin, g_iSpawnTankProbability, g_iCommonLimit,
	g_iTankLimit, g_iWitchLimit, g_iWhereToSpawnInfected;
int g_iPlayerSpawn, g_bSpawnWitchBride;
float g_fIdletime_b4slay, g_fInitialSpawn, g_fWitchKillTime;
int g_iModelIndex[MAXPLAYERS+1];			// Player Model entity reference
bool g_bAngry[MAXPLAYERS+1]; //tank is angry in coop/realism
char g_sJoinInfectedAccesslvl[16];

#define FUNCTION_PATCH "Tank::GetIntentionInterface::Intention"
#define FUNCTION_PATCH2 "Action<Tank>::FirstContainedResponder"
#define FUNCTION_PATCH3 "TankIdle::GetName"

int g_iIntentionOffset;
Handle g_hSDKFirstContainedResponder;
Handle g_hSDKGetName;
int lastHumanTankId;

public Plugin myinfo =
{
	name = "[L4D/L4D2] Infected Bots (Coop/Versus/Realism/Scavenge/Survival)",
	author = "djromero (SkyDavid), MI 5, Harry Potter",
	description = "Spawns infected bots in versus, allows playable special infected in coop/survival, and changable z_max_player_zombies limit",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showpost.php?p=2699220&postcount=1371"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();

	if( test == Engine_Left4Dead )
	{
		ZOMBIECLASS_TANK = 5;
		sSpawnCommand = "z_spawn";
		g_bL4D2Version = false;
		NUM_INFECTED = 3;
	}
	else if( test == Engine_Left4Dead2 )
	{
		ZOMBIECLASS_TANK = 8;
		sSpawnCommand = "z_spawn_old";
		g_bL4D2Version = true;
		NUM_INFECTED = 6;
	}
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("l4dinfectedbots.phrases");

	GetGameData();

	// Add a sourcemod command so players can easily join infected in coop/realism/survival
	RegConsoleCmd("sm_ji", JoinInfected, "(Coop/Realism/Survival only) Join Infected");
	RegConsoleCmd("sm_js", JoinSurvivors, "(Coop/Realism/Survival only) Join Survivors");
	RegConsoleCmd("sm_zs", ForceInfectedSuicide,"suicide myself (if infected get stuck or somthing)");
	RegAdminCmd("sm_zlimit", Console_ZLimit, ADMFLAG_SLAY,"control max special zombies limit");
	RegAdminCmd("sm_timer", Console_Timer, ADMFLAG_SLAY,"control special zombies spawn timer");
	#if DEBUG
	RegConsoleCmd("sm_sp", JoinSpectator);
	RegConsoleCmd("sm_gamemode", CheckGameMode);
	#endif
	RegConsoleCmd("sm_checkqueue", CheckQueue);

	// Hook "say" so clients can toggle HUD on/off for themselves
	RegConsoleCmd("sm_infhud", Command_Say, "(Infected only) Toggle HUD on/off for themselves");

	// We register the version cvar
	CreateConVar("l4d_infectedbots_version", PLUGIN_VERSION, "Version of L4D Infected Bots", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	// console variables
	g_hCvarAllow =						CreateConVar("l4d_infectedbots_allow",									"1",		"0=Plugin off, 1=Plugin on.", FCVAR_NOTIFY );
	g_hCvarModes =						CreateConVar("l4d_infectedbots_modes",									"",			"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", FCVAR_NOTIFY );
	g_hCvarModesOff =					CreateConVar("l4d_infectedbots_modes_off",								"",			"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", FCVAR_NOTIFY );
	g_hCvarModesTog =					CreateConVar("l4d_infectedbots_modes_tog",								"0",		"Turn on the plugin in these game modes. 0=All, 1=Coop/Realism, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", FCVAR_NOTIFY );
	
	g_hSpawnLimits[SI_BOOMER] = 		CreateConVar("l4d_infectedbots_boomer_limit", 							"2", 		"Sets the limit for boomers spawned by the plugin", FCVAR_NOTIFY, true, 0.0);
	g_hSpawnLimits[SI_SMOKER] = 		CreateConVar("l4d_infectedbots_smoker_limit", 							"2", 		"Sets the limit for smokers spawned by the plugin", FCVAR_NOTIFY, true, 0.0);
	g_hSpawnLimits[SI_HUNTER] = 		CreateConVar("l4d_infectedbots_hunter_limit", 							"2", 		"Sets the limit for hunters spawned by the plugin", FCVAR_NOTIFY, true, 0.0);
	if (g_bL4D2Version)
	{
		g_hSpawnLimits[SI_SPITTER] = 	CreateConVar("l4d_infectedbots_spitter_limit", 							"2", 		"Sets the limit for spitters spawned by the plugin", FCVAR_NOTIFY, true, 0.0);
		g_hSpawnLimits[SI_JOCKEY] =  	CreateConVar("l4d_infectedbots_jockey_limit", 							"2", 		"Sets the limit for jockeys spawned by the plugin", FCVAR_NOTIFY, true, 0.0);
		g_hSpawnLimits[SI_CHARGER] = 	CreateConVar("l4d_infectedbots_charger_limit", 							"2", 		"Sets the limit for chargers spawned by the plugin", FCVAR_NOTIFY, true, 0.0);
	}
	g_hSpawnWeights[SI_BOOMER] = 		CreateConVar("l4d_infectedbots_boomer_weight", 							"100", 		"The weight for a boomer spawning [0-100]", FCVAR_NOTIFY, true, 0.0, true, 100.0);
	g_hSpawnWeights[SI_SMOKER] = 		CreateConVar("l4d_infectedbots_smoker_weight", 							"100", 		"The weight for a smoker spawning [0-100]", FCVAR_NOTIFY, true, 0.0, true, 100.0);
	g_hSpawnWeights[SI_HUNTER] = 		CreateConVar("l4d_infectedbots_hunter_weight", 							"100", 		"The weight for a hunter spawning [0-100]", FCVAR_NOTIFY, true, 0.0, true, 100.0);
	if (g_bL4D2Version)
	{
		g_hSpawnWeights[SI_CHARGER] = 	CreateConVar("l4d_infectedbots_charger_weight", 						"100", 		"The weight for a charger spawning [0-100]", FCVAR_NOTIFY, true, 0.0, true, 100.0);
		g_hSpawnWeights[SI_JOCKEY] = 	CreateConVar("l4d_infectedbots_jockey_weight", 							"100", 		"The weight for a jockey spawning [0-100]", FCVAR_NOTIFY, true, 0.0, true, 100.0);
		g_hSpawnWeights[SI_SPITTER] = 	CreateConVar("l4d_infectedbots_spitter_weight", 						"100", 		"The weight for a spitter spawning [0-100]", FCVAR_NOTIFY, true, 0.0, true, 100.0);
	}
	g_hScaleWeights = 					CreateConVar("l4d_infectedbots_scale_weights", 							"0", 		"If 1, Scale spawn weights with the limits of corresponding SI", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	h_WitchLimit = 						CreateConVar("l4d_infectedbots_witch_max_limit", 						"6", 		"Sets the limit for witches spawned by the plugin (does not affect director witches)", FCVAR_NOTIFY, true, 0.0);
	
	h_TankLimit = 						CreateConVar("l4d_infectedbots_tank_limit", 							"1", 		"Sets the limit for tanks spawned by the plugin (does not affect director tanks)", FCVAR_NOTIFY, true, 0.0);
	h_PlayerAddTankLimitScale = 		CreateConVar("l4d_infectedbots_add_tanklimit_scale",					"3", 		"If server has more than 4+ alive players, how many tanks on the field = 'tank_limit' + [(alive players - 4) ÷ 'add_tanklimit_scale' × 'add_tanklimit'].", FCVAR_NOTIFY, true, 1.0);
	h_PlayerAddTankLimit = 				CreateConVar("l4d_infectedbots_add_tanklimit", 							"1", 		"If server has more than 4+ alive players, increase the certain value to 'l4d_infectedbots_tank_limit' each 'l4d_infectedbots_add_tanklimit_scale' players joins", FCVAR_NOTIFY, true, 0.0);
	h_TankSpawnFinal = 					CreateConVar("l4d_infectedbots_tank_spawn_final", 						"1", 		"If 1, still spawn tank in final stage rescue (does not affect director tanks)", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	h_MaxPlayerZombies = 				CreateConVar("l4d_infectedbots_max_specials", 							"2", 		"Defines how many special infected can be on the map on all gamemodes(does not count witch on all gamemodes, count tank in all gamemode)", FCVAR_NOTIFY, true, 0.0);
	h_PlayerAddZombiesScale = 			CreateConVar("l4d_infectedbots_add_specials_scale", 					"2", 		"If server has more than 4+ alive players, how many special infected = 'max_specials' + [(alive players - 4) ÷ 'add_specials_scale' × 'add_specials'].", FCVAR_NOTIFY, true, 1.0);
	h_PlayerAddZombies = 				CreateConVar("l4d_infectedbots_add_specials", 							"2", 		"If server has more than 4+ alive players, increase the certain value to 'l4d_infectedbots_max_specials' each 'l4d_infectedbots_add_specials_scale' players joins", FCVAR_NOTIFY, true, 0.0);

	h_TankHealthAdjust = 				CreateConVar("l4d_infectedbots_adjust_tankhealth_enable", 				"1", 		"If 1, adjust and overrides tank health by this plugin.", FCVAR_NOTIFY, true, 0.0,true, 1.0);
	h_TankHealth = 						CreateConVar("l4d_infectedbots_default_tankhealth", 					"4000", 	"Sets Default Health for Tank, Tank hp is affected by gamemode and difficulty (Example, Set Tank health 4000hp, but in Easy: 3000, Normal: 4000, Versus: 6000, Advanced/Expert: 8000)", FCVAR_NOTIFY, true, 1.0);
	h_PlayerAddTankHealthScale = 		CreateConVar("l4d_infectedbots_add_tankhealth_scale", 					"1", 		"If server has more than 4+ alive players, how many Tank Health = 'default_tankhealth' + [(alive players - 4) ÷ 'add_tankhealth_scale' × 'add_tankhealth'].", FCVAR_NOTIFY, true, 1.0);
	h_PlayerAddTankHealth = 			CreateConVar("l4d_infectedbots_add_tankhealth", 						"500", 		"If server has more than 4+ alive players, increase the certain value to 'l4d_infectedbots_default_tankhealth' each 'l4d_infectedbots_add_tankhealth_scale' players joins", FCVAR_NOTIFY, true, 0.0);
	h_InfectedSpawnTimeMax = 			CreateConVar("l4d_infectedbots_spawn_time_max", 						"60", 		"Sets the max spawn time for special infected spawned by the plugin in seconds.", FCVAR_NOTIFY, true, 1.0);
	h_InfectedSpawnTimeMin = 			CreateConVar("l4d_infectedbots_spawn_time_min", 						"40", 		"Sets the minimum spawn time for special infected spawned by the plugin in seconds.", FCVAR_NOTIFY, true, 1.0);
	h_CoopPlayableTank = 				CreateConVar("l4d_infectedbots_coop_versus_tank_playable", 				"0", 		"If 1, tank will always be controlled by human player in coop/survival/realism.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	h_JoinableTeams = 					CreateConVar("l4d_infectedbots_coop_versus", 							"1", 		"If 1, players can join the infected team in coop/survival/realism (!ji in chat to join infected, !js to join survivors)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	if (!g_bL4D2Version)
	{
		h_StatsBoard = 					CreateConVar("l4d_infectedbots_stats_board", 							"0", 		"If 1, the stats board will show up after an infected player dies (L4D1 ONLY)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	}
	h_JoinableTeamsAnnounce = 			CreateConVar("l4d_infectedbots_coop_versus_announce", 					"1", 		"If 1, clients will be announced to on how to join the infected team", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	h_Coordination = 					CreateConVar("l4d_infectedbots_coordination", 							"0", 		"If 1, bots will only spawn when all other bot spawn timers are at zero.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	h_InfHUD = 							CreateConVar("l4d_infectedbots_infhud_enable", 							"1", 		"Toggle whether Infected HUD is active or not.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	h_Announce = 						CreateConVar("l4d_infectedbots_infhud_announce", 						"1", 		"Toggle whether Infected HUD announces itself to clients.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	h_Idletime_b4slay = 				CreateConVar("l4d_infectedbots_lifespan", 								"30", 		"Amount of seconds before a special infected bot is kicked", FCVAR_NOTIFY, true, 1.0);
	h_InitialSpawn = 					CreateConVar("l4d_infectedbots_initial_spawn_timer", 					"10", 		"The spawn timer in seconds used when infected bots are spawned for the first time in a map", FCVAR_NOTIFY, true, 0.0);
	h_HumanCoopLimit = 					CreateConVar("l4d_infectedbots_coop_versus_human_limit", 				"2", 		"Sets the limit for the amount of humans that can join the infected team in coop/survival/realism.", FCVAR_NOTIFY, true, 0.0);
	h_JoinInfectedAccess = 				CreateConVar("l4d_infectedbots_coop_versus_join_access", 				"z", 		"Players with these flags have access to join infected team in coop/survival/realism. (Empty = Everyone, -1: Nobody)", FCVAR_NOTIFY);
	h_DisableSpawnsTank = 				CreateConVar("l4d_infectedbots_spawns_disabled_tank", 					"0", 		"If 1, Plugin will disable spawning infected bot when a tank is on the field.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	h_VersusCoop = 						CreateConVar("l4d_infectedbots_versus_coop", 							"0", 		"If 1, The plugin will force all players to the infected side against the survivor AI for every round and map in versus/scavenge", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	h_AdjustSpawnTimes = 				CreateConVar("l4d_infectedbots_adjust_spawn_times", 					"1", 		"If 1, The plugin will adjust spawn timers depending on the gamemode and human players on infected team", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	h_ReducedSpawnTimesOnPlayer = 		CreateConVar("l4d_infectedbots_adjust_reduced_spawn_times_on_player", 	"1", 		"Reduce certain value to maximum spawn timer based per alive player", FCVAR_NOTIFY, true, 0.0);
	h_SafeSpawn = 						CreateConVar("l4d_infectedbots_safe_spawn", 							"0", 		"If 1, spawn special infected before survivors leave starting safe room area.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	h_SpawnDistanceMin = 				CreateConVar("l4d_infectedbots_spawn_range_min", 						"350", 		"The minimum of spawn range for infected. (default: 550, coop/realism only)\nThis cvar will also affect common zombie spawn range and ghost infected player spawn range", FCVAR_NOTIFY, true, 0.0, true, 550.0);
	h_WitchPeriodMax = 					CreateConVar("l4d_infectedbots_witch_spawn_time_max", 					"120.0", 	"Sets the max spawn time for witch spawned by the plugin in seconds.", FCVAR_NOTIFY, true, 1.0);
	h_WitchPeriodMin = 					CreateConVar("l4d_infectedbots_witch_spawn_time_min", 					"90.0", 	"Sets the mix spawn time for witch spawned by the plugin in seconds.", FCVAR_NOTIFY, true, 1.0);
	h_WitchSpawnFinal = 				CreateConVar("l4d_infectedbots_witch_spawn_final", 						"0", 		"If 1, still spawn witch in final stage rescue", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	h_WitchKillTime = 					CreateConVar("l4d_infectedbots_witch_lifespan", 						"200", 		"Amount of seconds before a witch is kicked. (only remove witches spawned by this plugin)", FCVAR_NOTIFY, true, 1.0);
	h_SpawnTankProbability = 			CreateConVar("l4d_infectedbots_tank_spawn_probability", 				"5", 		"When each time spawn S.I., how much percent of chance to spawn tank", FCVAR_NOTIFY, true, 0.0, true, 100.0);
	h_ZSDisableGamemode = 				CreateConVar("l4d_infectedbots_sm_zs_disable_gamemode", 				"6", 		"Disable sm_zs in these gamemode (0: None, 1: coop/realism, 2: versus/scavenge, 4: survival, add numbers together)", FCVAR_NOTIFY, true, 0.0, true, 7.0);
	h_CommonLimitAdjust = 				CreateConVar("l4d_infectedbots_adjust_commonlimit_enable", 				"1", 		"If 1, adjust and overrides zombie common limit by this plugin.", FCVAR_NOTIFY, true, 0.0,true, 1.0);
	h_CommonLimit = 					CreateConVar("l4d_infectedbots_default_commonlimit", 					"30", 		"Sets Default zombie common limit.", FCVAR_NOTIFY, true, 0.0);
	h_PlayerAddCommonLimitScale = 		CreateConVar("l4d_infectedbots_add_commonlimit_scale", 					"1", 		"If server has more than 4+ alive players, zombie common limit = 'default_commonlimit' + [(alive players - 4) ÷ 'add_commonlimit_scale' × 'add_commonlimit'].", FCVAR_NOTIFY, true, 1.0);
	h_PlayerAddCommonLimit = 			CreateConVar("l4d_infectedbots_add_commonlimit", 						"2", 		"If server has more than 4+ alive players, increase the certain value to 'l4d_infectedbots_default_commonlimit' each 'l4d_infectedbots_add_commonlimit_scale' players joins", FCVAR_NOTIFY, true, 0.0);
	h_CoopInfectedPlayerFlashLight = 	CreateConVar("l4d_infectedbots_coop_versus_human_light", 				"1", 		"If 1, attaches red flash light to human infected player in coop/survival. (Make it clear which infected bot is controlled by player)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	h_StatusAnnouncementEnable = 		CreateConVar("l4d_infectedbots_announcement_enable", 					"1", 		"If 1, announce current plugin status when the number of alive survivors changes.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	h_CoopInfectedPlayerGhostState = 	CreateConVar("l4d_infectedbots_coop_versus_human_ghost_enable", 		"1", 		"If 1, human infected player will spawn as ghost state in coop/survival/realism.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	h_InfectedSpawnSameFrame = 			CreateConVar("l4d_infectedbots_spawn_on_same_frame", 					"0", 		"If 1, infected bots can spawn on the same game frame (careful, this could cause sever laggy)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	h_WhereToSpawnInfected = 			CreateConVar("l4d_infectedbots_spawn_where_method", 					"0", 		"Where to spawn infected? 0=Near the first ahead survivor. 1=Near the random survivor", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	h_IncludingDeadPlayers = 			CreateConVar("l4d_infectedbots_calculate_including_dead_player", 		"0", 		"If 1, including 4+ alive and dead players in the server.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	h_DisableInfectedBot = 				CreateConVar("l4d_infectedbots_disable_infected_bots", 					"0", 		"If 1, disable infected bots spawning in versus/scavenge mode. (Does not disable witch spawn and does not affect director boss spawn)", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarGameMode);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	h_Difficulty = FindConVar("z_difficulty");
	h_common_limit_cvar = FindConVar("z_common_limit");

	director_no_specials = FindConVar("director_no_specials");

	GetCvars();
	director_no_specials.AddChangeHook(ConVarChanged_Cvars);
	g_hSpawnLimits[SI_BOOMER].AddChangeHook(ConVarChanged_Cvars);
	g_hSpawnLimits[SI_SMOKER].AddChangeHook(ConVarChanged_Cvars);
	g_hSpawnLimits[SI_HUNTER].AddChangeHook(ConVarChanged_Cvars);
	if (g_bL4D2Version)
	{
		g_hSpawnLimits[SI_SPITTER].AddChangeHook(ConVarChanged_Cvars);
		g_hSpawnLimits[SI_JOCKEY].AddChangeHook(ConVarChanged_Cvars);
		g_hSpawnLimits[SI_CHARGER].AddChangeHook(ConVarChanged_Cvars);
	}
	g_hSpawnWeights[SI_BOOMER].AddChangeHook(ConVarChanged_Cvars);
	g_hSpawnWeights[SI_SMOKER].AddChangeHook(ConVarChanged_Cvars);
	g_hSpawnWeights[SI_HUNTER].AddChangeHook(ConVarChanged_Cvars);
	if (g_bL4D2Version)
	{
		g_hSpawnWeights[SI_SPITTER].AddChangeHook(ConVarChanged_Cvars);
		g_hSpawnWeights[SI_JOCKEY].AddChangeHook(ConVarChanged_Cvars);
		g_hSpawnWeights[SI_CHARGER].AddChangeHook(ConVarChanged_Cvars);
	}
	g_hScaleWeights.AddChangeHook(ConVarChanged_Cvars);
	h_WitchLimit.AddChangeHook(ConVarChanged_Cvars);
	h_SafeSpawn.AddChangeHook(ConVarChanged_Cvars);
	h_TankHealth.AddChangeHook(ConVarChanged_Cvars);
	h_InfectedSpawnTimeMax.AddChangeHook(ConVarChanged_Cvars);
	h_InfectedSpawnTimeMin.AddChangeHook(ConVarChanged_Cvars);
	h_CoopPlayableTank.AddChangeHook(ConVarChanged_Cvars);
	h_JoinableTeamsAnnounce.AddChangeHook(ConVarChanged_Cvars);
	h_Coordination.AddChangeHook(ConVarChanged_Cvars);
	h_InfHUD.AddChangeHook(ConVarChanged_Cvars);
	h_Announce.AddChangeHook(ConVarChanged_Cvars);
	h_Idletime_b4slay.AddChangeHook(ConVarChanged_Cvars);
	h_InitialSpawn.AddChangeHook(ConVarChanged_Cvars);
	h_HumanCoopLimit.AddChangeHook(ConVarChanged_Cvars);
	h_JoinInfectedAccess.AddChangeHook(ConVarChanged_Cvars);
	h_DisableSpawnsTank.AddChangeHook(ConVarChanged_Cvars);
	h_AdjustSpawnTimes.AddChangeHook(ConVarChanged_Cvars);
	h_ReducedSpawnTimesOnPlayer.AddChangeHook(ConVarChanged_Cvars);
	h_ZSDisableGamemode.AddChangeHook(ConVarChanged_Cvars);
	h_WitchPeriodMax.AddChangeHook(ConVarChanged_Cvars);
	h_WitchPeriodMin.AddChangeHook(ConVarChanged_Cvars);
	h_WitchKillTime.AddChangeHook(ConVarChanged_Cvars);
	h_SpawnTankProbability.AddChangeHook(ConVarChanged_Cvars);
	h_CommonLimit.AddChangeHook(ConVarChanged_Cvars);
	h_CoopInfectedPlayerFlashLight.AddChangeHook(ConVarChanged_Cvars);
	h_StatusAnnouncementEnable.AddChangeHook(ConVarChanged_Cvars);
	h_CoopInfectedPlayerGhostState.AddChangeHook(ConVarChanged_Cvars);
	h_WitchSpawnFinal.AddChangeHook(ConVarChanged_Cvars);
	h_TankSpawnFinal.AddChangeHook(ConVarChanged_Cvars);
	h_InfectedSpawnSameFrame.AddChangeHook(ConVarChanged_Cvars);
	h_WhereToSpawnInfected.AddChangeHook(ConVarChanged_Cvars);
	h_IncludingDeadPlayers.AddChangeHook(ConVarChanged_Cvars);
	h_DisableInfectedBot.AddChangeHook(ConVarChanged_Cvars);

	g_iMaxPlayerZombies = h_MaxPlayerZombies.IntValue;
	g_bVersusCoop = h_VersusCoop.BoolValue;
	g_bJoinableTeams = h_JoinableTeams.BoolValue; bDisableSurvivorModelGlow = !g_bJoinableTeams;
	h_SpawnDistanceMin.AddChangeHook(ConVarDistanceChanged);
	h_MaxPlayerZombies.AddChangeHook(ConVarMaxPlayerZombies);
	h_VersusCoop.AddChangeHook(ConVarVersusCoop);
	h_JoinableTeams.AddChangeHook(ConVarCoopVersus);

	//----- Zombie HP hooks ---------------------
	//We store the special infected max HP values in an array and then hook the cvars used to modify them
	//just in case another plugin (or an admin) decides to modify them.  Whilst unlikely if we don't do
	//this then the HP percentages on the HUD will end up screwy, and since it's a one-time initialisation
	//when the plugin loads there's a trivial overhead.
	cvarZombieHP[0] = FindConVar("z_hunter_health");
	cvarZombieHP[1] = FindConVar("z_gas_health");
	cvarZombieHP[2] = FindConVar("z_exploding_health");
	if (g_bL4D2Version)
	{
		cvarZombieHP[3] = FindConVar("z_spitter_health");
		cvarZombieHP[4] = FindConVar("z_jockey_health");
		cvarZombieHP[5] = FindConVar("z_charger_health");
	}
	cvarZombieHP[6] = FindConVar("z_tank_health");
	zombieHP[0] = cvarZombieHP[0].IntValue;
	cvarZombieHP[0].AddChangeHook(cvarZombieHPChanged);
	zombieHP[1] = cvarZombieHP[1].IntValue;
	cvarZombieHP[1].AddChangeHook(cvarZombieHPChanged);
	zombieHP[2] = cvarZombieHP[2].IntValue;
	cvarZombieHP[2].AddChangeHook(cvarZombieHPChanged);
	if (g_bL4D2Version)
	{
		zombieHP[3] = cvarZombieHP[3].IntValue;
		cvarZombieHP[3].AddChangeHook(cvarZombieHPChanged);
		zombieHP[4] = cvarZombieHP[4].IntValue;
		cvarZombieHP[4].AddChangeHook(cvarZombieHPChanged);
		zombieHP[5] = cvarZombieHP[5].IntValue;
		cvarZombieHP[5].AddChangeHook(cvarZombieHPChanged);
	}
	g_bCommonLimitAdjust = h_CommonLimitAdjust.BoolValue;
	g_bTankHealthAdjust = h_TankHealthAdjust.BoolValue;
	TankHealthCheck();
	iPlayersInSurvivorTeam = 0;
	cvarZombieHP[6].AddChangeHook(ConVarChanged_BalanceUpdate);
	if(!g_bL4D2Version)
	{
		versus_tank_bonus_health = FindConVar("versus_tank_bonus_health");
		versus_tank_bonus_health.AddChangeHook(ConVarChanged_BalanceUpdate);
	}

	h_Difficulty.AddChangeHook(ConVarChanged_BalanceUpdate);
	h_CommonLimitAdjust.AddChangeHook(ConVarChanged_BalanceUpdate);
	h_CommonLimit.AddChangeHook(ConVarChanged_BalanceUpdate);
	h_PlayerAddCommonLimitScale.AddChangeHook(ConVarChanged_BalanceUpdate);
	h_PlayerAddCommonLimit.AddChangeHook(ConVarChanged_BalanceUpdate);
	h_TankHealthAdjust.AddChangeHook(ConVarChanged_BalanceUpdate);
	h_TankHealth.AddChangeHook(ConVarChanged_BalanceUpdate);
	h_PlayerAddTankHealthScale.AddChangeHook(ConVarChanged_BalanceUpdate);
	h_PlayerAddTankHealth.AddChangeHook(ConVarChanged_BalanceUpdate);

	h_TankLimit.AddChangeHook(ConVarChanged_TankLimitUpdate);
	h_PlayerAddTankLimitScale.AddChangeHook(ConVarChanged_TankLimitUpdate);
	h_PlayerAddTankLimit.AddChangeHook(ConVarChanged_TankLimitUpdate);

	// Removes the boundaries for z_max_player_zombies and notify flag
	z_max_player_zombies = FindConVar("z_max_player_zombies");
	int flags = z_max_player_zombies.Flags;
	SetConVarBounds(z_max_player_zombies, ConVarBound_Upper, false);
	SetConVarFlags(z_max_player_zombies, flags & ~FCVAR_NOTIFY);


	if(g_bL4D2Version)
	{
		sb_all_bot_game = FindConVar("sb_all_bot_game");
		allow_all_bot_survivor_team = FindConVar("allow_all_bot_survivor_team");
	}
	else
	{
		sb_all_bot_team = FindConVar("sb_all_bot_team");
	}
	vs_max_team_switches = FindConVar("vs_max_team_switches");

	director_allow_infected_bots = FindConVar("director_allow_infected_bots");

	//Autoconfig for plugin
	AutoExecConfig(true, "l4dinfectedbots");
}


public void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_iSpawnLimits[SI_BOOMER] = g_hSpawnLimits[SI_BOOMER].IntValue;
	g_iSpawnLimits[SI_SMOKER] = g_hSpawnLimits[SI_SMOKER].IntValue;
	g_iSpawnLimits[SI_HUNTER] = g_hSpawnLimits[SI_HUNTER].IntValue;
	if(g_bL4D2Version)
	{
		g_iSpawnLimits[SI_CHARGER] = g_hSpawnLimits[SI_CHARGER].IntValue;
		g_iSpawnLimits[SI_JOCKEY] = g_hSpawnLimits[SI_JOCKEY].IntValue;
		g_iSpawnLimits[SI_SPITTER] = g_hSpawnLimits[SI_SPITTER].IntValue;
	}
	g_iSpawnWeights[SI_BOOMER] = g_hSpawnWeights[SI_BOOMER].IntValue;
	g_iSpawnWeights[SI_SMOKER] = g_hSpawnWeights[SI_SMOKER].IntValue;
	g_iSpawnWeights[SI_HUNTER] = g_hSpawnWeights[SI_HUNTER].IntValue;
	if(g_bL4D2Version)
	{
		g_iSpawnWeights[SI_CHARGER] = g_hSpawnWeights[SI_CHARGER].IntValue;
		g_iSpawnWeights[SI_JOCKEY] = g_hSpawnWeights[SI_JOCKEY].IntValue;
		g_iSpawnWeights[SI_SPITTER] = g_hSpawnWeights[SI_SPITTER].IntValue;
	}
	g_bScaleWeights = g_hScaleWeights.BoolValue;
	g_iWitchLimit = h_WitchLimit.IntValue;
	g_bSafeSpawn = h_SafeSpawn.BoolValue;
	g_iTankHealth = h_TankHealth.IntValue;
	g_iInfectedSpawnTimeMax = h_InfectedSpawnTimeMax.IntValue;
	g_iInfectedSpawnTimeMin = h_InfectedSpawnTimeMin.IntValue;
	g_bCoopPlayableTank = h_CoopPlayableTank.BoolValue;
	g_bJoinableTeamsAnnounce = h_JoinableTeamsAnnounce.BoolValue;
	g_bCoordination = h_Coordination.BoolValue;
	g_bInfHUD = h_InfHUD.BoolValue;
	g_bAnnounce = h_Announce.BoolValue;
	g_fIdletime_b4slay = h_Idletime_b4slay.FloatValue;
	g_fInitialSpawn = h_InitialSpawn.FloatValue;
	g_iHumanCoopLimit = h_HumanCoopLimit.IntValue;
	h_JoinInfectedAccess.GetString(g_sJoinInfectedAccesslvl,sizeof(g_sJoinInfectedAccesslvl));
	g_bDisableSpawnsTank = h_DisableSpawnsTank.BoolValue;
	g_bAdjustSpawnTimes = h_AdjustSpawnTimes.BoolValue;
	g_iReducedSpawnTimesOnPlayer = h_ReducedSpawnTimesOnPlayer.IntValue;
	g_iZSDisableGamemode = h_ZSDisableGamemode.IntValue;
	g_iWitchPeriodMax = h_WitchPeriodMax.IntValue;
	g_iWitchPeriodMin = h_WitchPeriodMin.IntValue;
	g_fWitchKillTime = h_WitchKillTime.FloatValue;
	g_iSpawnTankProbability = h_SpawnTankProbability.IntValue;
	g_iCommonLimit = h_CommonLimit.IntValue;
	g_bCoopInfectedPlayerFlashLight = h_CoopInfectedPlayerFlashLight.BoolValue;
	g_bStatusAnnouncementEnable = h_StatusAnnouncementEnable.BoolValue;
	g_bCoopInfectedPlayerGhostState = h_CoopInfectedPlayerGhostState.BoolValue;
	g_bWitchSpawnFinal = h_WitchSpawnFinal.BoolValue;
	g_bTankSpawnFinal = h_TankSpawnFinal.BoolValue;
	g_bInfectedSpawnSameFrame = h_InfectedSpawnSameFrame.BoolValue;
	g_iWhereToSpawnInfected = h_WhereToSpawnInfected.IntValue;
	g_bIncludingDeadPlayers = h_IncludingDeadPlayers.BoolValue;
	g_bDisableInfectedBot = h_DisableInfectedBot.BoolValue;

	director_no_specials_bool = director_no_specials.BoolValue;
}

public void ConVarMaxPlayerZombies(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iMaxPlayerZombies = h_MaxPlayerZombies.IntValue;
	iPlayersInSurvivorTeam = -1;
	CreateTimer(0.1, MaxSpecialsSet);
	delete DisplayTimer;
	DisplayTimer = CreateTimer(1.0, Timer_CountSurvivor);
}

public void ConVarGameMode(ConVar convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();

	bDisableSurvivorModelGlow = true;
	if(g_bL4D2Version)
	{
		static char mode[64];
		g_hCvarMPGameMode.GetString(mode, sizeof(mode));
		for( int i = 1; i <= MaxClients; i++ )
		{
			RemoveSurvivorModelGlow(i);
			if(IsClientInGame(i) && !IsFakeClient(i)) SendConVarValue(i, g_hCvarMPGameMode, mode);
		}
	}

	TankHealthCheck();
	delete DisplayTimer;
	DisplayTimer = CreateTimer(1.0,Timer_CountSurvivor);

	if(g_bCvarAllow == false) return;

	//TweakSettings();

	if(g_bL4D2Version)
	{
		if(L4D_HasPlayerControlledZombies() == false && g_bJoinableTeams)
		{
			bDisableSurvivorModelGlow = false;
			for( int i = 1; i <= MaxClients; i++ )
			{
				CreateSurvivorModelGlow(i);
				if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == TEAM_INFECTED) SendConVarValue(i, g_hCvarMPGameMode, "versus");
			}
		}
	}

}
public void ConVarVersusCoop(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bVersusCoop = h_VersusCoop.BoolValue;
	if(L4D_HasPlayerControlledZombies() == true)
	{
		if (g_bVersusCoop)
		{
			SetConVarInt(vs_max_team_switches, 0);
			if (g_bL4D2Version)
			{
				SetConVarInt(sb_all_bot_game, 1);
				SetConVarInt(allow_all_bot_survivor_team, 1);
			}
			else
			{
				SetConVarInt(sb_all_bot_team, 1);
			}
		}
		else
		{
			vs_max_team_switches.SetInt(vs_max_team_switches_default);
			if (g_bL4D2Version)
			{
				sb_all_bot_game.SetBool(sb_all_bot_game_default);
				allow_all_bot_survivor_team.SetBool(allow_all_bot_survivor_team_default);
			}
			else
			{
				sb_all_bot_team.SetBool(sb_all_bot_team_default);
			}
		}
	}
}

public void ConVarDistanceChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetSpawnDisConvars();
}

public void ConVarCoopVersus(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bJoinableTeams = h_JoinableTeams.BoolValue;
	if(L4D_HasPlayerControlledZombies() == false)
	{
		if (g_bJoinableTeams)
		{
			if (g_bL4D2Version)
			{
				SetConVarInt(sb_all_bot_game, 1);
				SetConVarInt(allow_all_bot_survivor_team, 1);
			}
			else
			{
				SetConVarInt(sb_all_bot_team, 1);
			}

			bDisableSurvivorModelGlow = false;
			for( int i = 1; i <= MaxClients; i++ ) CreateSurvivorModelGlow(i);
		}
		else
		{
			if (g_bL4D2Version)
			{
				sb_all_bot_game.SetBool(sb_all_bot_game_default);
				allow_all_bot_survivor_team.SetBool(allow_all_bot_survivor_team_default);
			}
			else
			{
				sb_all_bot_team.SetBool(sb_all_bot_team_default);
			}
			if(g_bL4D2Version)
			{
				static char mode[64];
				g_hCvarMPGameMode.GetString(mode, sizeof(mode));
				bDisableSurvivorModelGlow = true;
				for( int i = 1; i <= MaxClients; i++ )
				{
					if(IsClientInGame(i) && !IsFakeClient(i)) SendConVarValue(i, g_hCvarMPGameMode, mode);
					RemoveSurvivorModelGlow(i);
				}
			}
		}
	}
}

void TweakSettings()
{
	// We tweak some settings ...

	// Some interesting things about this. There was a bug I discovered that in versions 1.7.8 and below, infected players would not spawn as ghosts in VERSUS. This was
	// due to the fact that the coop class limits were not being reset (I didn't think they were linked at all, but I should have known better). This bug has been fixed
	// with the coop class limits being reset on every gamemode except coop of course.

	// Reset the cvars
	ResetCvars();

	switch (g_iCurrentMode)
	{
		case 1: // Coop, We turn off the ability for the director to spawn the bots, and have the plugin do it while allowing the director to spawn tanks and witches,
		// MI 5
		{
			// If the game is L4D 2...
			if (g_bL4D2Version)
			{
				SetConVarInt(FindConVar("z_smoker_limit"), 0);
				SetConVarInt(FindConVar("z_boomer_limit"), 0);
				SetConVarInt(FindConVar("z_hunter_limit"), 0);
				SetConVarInt(FindConVar("z_spitter_limit"), 0);
				SetConVarInt(FindConVar("z_jockey_limit"), 0);
				SetConVarInt(FindConVar("z_charger_limit"), 0);
			}
			else
			{
				SetConVarInt(FindConVar("z_gas_limit"), 0);
				SetConVarInt(FindConVar("z_exploding_limit"), 0);
				SetConVarInt(FindConVar("z_hunter_limit"), 0);
			}
		}
		case 2: // Versus, Better Versus Infected AI
		{
			// If the game is L4D 2...
			if (g_bL4D2Version)
			{
				SetConVarInt(FindConVar("z_smoker_limit"), 0);
				SetConVarInt(FindConVar("z_boomer_limit"), 0);
				SetConVarInt(FindConVar("z_hunter_limit"), 0);
				SetConVarInt(FindConVar("z_spitter_limit"), 0);
				SetConVarInt(FindConVar("z_jockey_limit"), 0);
				SetConVarInt(FindConVar("z_charger_limit"), 0);
			}
			else
			{
				SetConVarInt(FindConVar("z_gas_limit"), 999);
				SetConVarInt(FindConVar("z_exploding_limit"), 999);
				SetConVarInt(FindConVar("z_hunter_limit"), 999);
			}

			if (g_bVersusCoop)
				vs_max_team_switches.SetInt(0);
		}
		case 3: // Survival, Turns off the ability for the director to spawn infected bots in survival, MI 5
		{
			if (g_bL4D2Version)
			{
				SetConVarInt(FindConVar("survival_max_smokers"), 0);
				SetConVarInt(FindConVar("survival_max_boomers"), 0);
				SetConVarInt(FindConVar("survival_max_hunters"), 0);
				SetConVarInt(FindConVar("survival_max_spitters"), 0);
				SetConVarInt(FindConVar("survival_max_jockeys"), 0);
				SetConVarInt(FindConVar("survival_max_chargers"), 0);
				//SetConVarInt(FindConVar("survival_max_specials"), g_iMaxPlayerZombies);
				SetConVarInt(FindConVar("survival_max_specials"), 0);
				SetConVarInt(FindConVar("survival_tank_stage_interval"), 9999999);
				SetConVarInt(FindConVar("survival_special_limit_increase"), 0);
				SetConVarInt(FindConVar("survival_special_spawn_interval"), 9999999);
				SetConVarInt(FindConVar("survival_special_stage_interval"), 9999999);

				SetConVarInt(FindConVar("z_smoker_limit"), 0);
				SetConVarInt(FindConVar("z_boomer_limit"), 0);
				SetConVarInt(FindConVar("z_hunter_limit"), 0);
				SetConVarInt(FindConVar("z_spitter_limit"), 0);
				SetConVarInt(FindConVar("z_jockey_limit"), 0);
				SetConVarInt(FindConVar("z_charger_limit"), 0);
			}
			else
			{
				SetConVarInt(FindConVar("holdout_max_smokers"), 0);
				SetConVarInt(FindConVar("holdout_max_boomers"), 0);
				SetConVarInt(FindConVar("holdout_max_hunters"), 0);
				//SetConVarInt(FindConVar("holdout_max_specials"), g_iMaxPlayerZombies);
				SetConVarInt(FindConVar("holdout_max_specials"), 0);
				SetConVarInt(FindConVar("holdout_tank_stage_interval"), 9999999);
				SetConVarInt(FindConVar("holdout_special_spawn_interval"), 9999999);
				SetConVarInt(FindConVar("holdout_special_stage_interval"), 9999999);

				SetConVarInt(FindConVar("z_gas_limit"), 0);
				SetConVarInt(FindConVar("z_exploding_limit"), 0);
				SetConVarInt(FindConVar("z_hunter_limit"), 0);
			}
		}
	}

	//Some cvar tweaks
	
	//SetConVarInt(FindConVar("z_attack_flow_range"), 50000);
	//SetConVarInt(FindConVar("director_spectate_specials"), 1);
	//SetConVarInt(FindConVar("z_spawn_flow_limit"), 50000);
	if (g_bL4D2Version)
	{
		SetConVarInt(director_allow_infected_bots, 0);
		//SetConVarInt(FindConVar("versus_special_respawn_interval"), 99999999);
	}
	#if DEBUG
	LogMessage("Tweaking Settings");
	#endif

}

void ResetCvars()
{
	#if DEBUG
	LogMessage("Plugin Cvars Reset");
	#endif

	if (g_iCurrentMode == 1)
	{
		if (g_bL4D2Version)
		{
			ResetConVar(FindConVar("survival_max_smokers"), true, true);
			ResetConVar(FindConVar("survival_max_boomers"), true, true);
			ResetConVar(FindConVar("survival_max_hunters"), true, true);
			ResetConVar(FindConVar("survival_max_spitters"), true, true);
			ResetConVar(FindConVar("survival_max_jockeys"), true, true);
			ResetConVar(FindConVar("survival_max_chargers"), true, true);
			ResetConVar(FindConVar("survival_max_specials"), true, true);
			ResetConVar(FindConVar("survival_tank_stage_interval"), true, true);
			ResetConVar(FindConVar("survival_special_limit_increase"), true, true);
			ResetConVar(FindConVar("survival_special_spawn_interval"), true, true);
			ResetConVar(FindConVar("survival_special_stage_interval"), true, true);
		}
		else
		{
			ResetConVar(FindConVar("holdout_max_smokers"), true, true);
			ResetConVar(FindConVar("holdout_max_boomers"), true, true);
			ResetConVar(FindConVar("holdout_max_hunters"), true, true);
			ResetConVar(FindConVar("holdout_max_specials"), true, true);
			ResetConVar(FindConVar("holdout_tank_stage_interval"), true, true);
			ResetConVar(FindConVar("holdout_special_spawn_interval"), true, true);
			ResetConVar(FindConVar("holdout_special_stage_interval"), true, true);
		}
	}
	else if (g_iCurrentMode == 2)
	{
		if (g_bL4D2Version)
		{
			ResetConVar(FindConVar("survival_max_smokers"), true, true);
			ResetConVar(FindConVar("survival_max_boomers"), true, true);
			ResetConVar(FindConVar("survival_max_hunters"), true, true);
			ResetConVar(FindConVar("survival_max_spitters"), true, true);
			ResetConVar(FindConVar("survival_max_jockeys"), true, true);
			ResetConVar(FindConVar("survival_max_chargers"), true, true);
			ResetConVar(FindConVar("survival_max_specials"), true, true);
			ResetConVar(FindConVar("survival_tank_stage_interval"), true, true);
			ResetConVar(FindConVar("survival_special_limit_increase"), true, true);
			ResetConVar(FindConVar("survival_special_spawn_interval"), true, true);
			ResetConVar(FindConVar("survival_special_stage_interval"), true, true);
		}
		else
		{
			ResetConVar(FindConVar("holdout_max_smokers"), true, true);
			ResetConVar(FindConVar("holdout_max_boomers"), true, true);
			ResetConVar(FindConVar("holdout_max_hunters"), true, true);
			ResetConVar(FindConVar("holdout_max_specials"), true, true);
			ResetConVar(FindConVar("holdout_tank_stage_interval"), true, true);
			ResetConVar(FindConVar("holdout_special_spawn_interval"), true, true);
			ResetConVar(FindConVar("holdout_special_stage_interval"), true, true);
		}
	}
	else if (g_iCurrentMode == 3)
	{
		if (g_bL4D2Version)
		{
			ResetConVar(FindConVar("z_smoker_limit"), true, true);
			ResetConVar(FindConVar("z_boomer_limit"), true, true);
			ResetConVar(FindConVar("z_hunter_limit"), true, true);
			ResetConVar(FindConVar("z_spitter_limit"), true, true);
			ResetConVar(FindConVar("z_jockey_limit"), true, true);
			ResetConVar(FindConVar("z_charger_limit"), true, true);
		}
		else
		{
			ResetConVar(FindConVar("z_gas_limit"), true, true);
			ResetConVar(FindConVar("z_exploding_limit"), true, true);
			ResetConVar(FindConVar("z_hunter_limit"), true, true);
		}
	}
}

public void evtRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bLeftSaveRoom = false;
	g_bSurvivalStart = false;

	if(!b_HasRoundStarted && g_iPlayerSpawn == 1)
	{
		CreateTimer(0.5, Timer_PluginStart, _, TIMER_FLAG_NO_MAPCHANGE);
	}

	b_HasRoundStarted = true;
}

public void Event_SurvivalRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(g_iCurrentMode == 3 && g_bSurvivalStart == false)
	{
		g_bLeftSaveRoom = true;
		GameStart();
		g_bSurvivalStart = true;
	}
}

public Action Timer_PluginStart(Handle timer)
{
	if (g_bCvarAllow == false)
		return Plugin_Continue;

	for (int i = 1; i <= MaxClients; i++)
	{
		respawnDelay[i] = 0;
		PlayerLifeState[i] = false;
	}

	//reset some variables
	InfectedBotQueue = 0;
	TanksPlaying = 0;
	g_iCoordinationBotReady = 0;
	g_bIsCoordination = false;
	g_bFinaleStarted = false;
	g_bInitialSpawn = true;
	TempBotSpawned = false;
	g_bLeftSaveRoom = false;
	g_bHasRoundEnded = false;
	TankReplacing = false;

	// Added a delay to setting MaxSpecials so that it would set correctly when the server first starts up
	CreateTimer(0.4, MaxSpecialsSet);

	// This little part is needed because some events just can't execute when another round starts.
	if (L4D_HasPlayerControlledZombies() && g_bVersusCoop)
	{
		for (int i=1; i<=MaxClients; i++)
		{
			// We check if player is in game
			if (!IsClientInGame(i)) continue;
			// Check if client is survivor ...
			if (GetClientTeam(i)==TEAM_SURVIVORS)
			{
				// If player is a real player ...
				if (!IsFakeClient(i))
				{
					ChangeClientTeam(i, TEAM_INFECTED);
				}
			}
		}

	}
	// Kill the player if they are infected and its not versus (prevents survival finale bug and player ghosts when there shouldn't be)
	if (L4D_HasPlayerControlledZombies() == false)
	{
		for (int i=1; i<=MaxClients; i++)
		{
			// We check if player is in game
			if (!IsClientInGame(i)) continue;
			// Check if client is infected ...
			if (GetClientTeam(i)==TEAM_INFECTED)
			{
				// If player is a real player ...
				if (!IsFakeClient(i))
				{
					// if (g_bJoinableTeams && g_bJoinableTeamsAnnounce)
					// {
					// 	CreateTimer(10.0, AnnounceJoinInfected, i, TIMER_FLAG_NO_MAPCHANGE);
					// }
					if (IsPlayerGhost(i))
					{
						L4D_State_Transition(i, STATE_DEATH_WAIT_FOR_KEY);
					}
				}
			}
		}
	}

	// Check the Tank's health to properly display it in the HUD
	TankHealthCheck();
	// Start up TweakSettings
	TweakSettings();

	roundInProgress = true;
	delete infHUDTimer;
	infHUDTimer = CreateTimer(1.0, showInfHUD, _, TIMER_REPEAT);

	#if DEBUG
		PrintToChatAll("[TS] PluginStart()!");
	#endif
	delete PlayerLeftStartTimer;
	PlayerLeftStartTimer = CreateTimer(1.0, Timer_PlayerLeftStart, _, TIMER_REPEAT);

	if (g_bJoinableTeams && L4D_HasPlayerControlledZombies() == false || g_bVersusCoop && L4D_HasPlayerControlledZombies())
	{
		if (g_bL4D2Version)
		{
			SetConVarInt(sb_all_bot_game, 1);
			SetConVarInt(allow_all_bot_survivor_team, 1);
		}
		else
		{
			SetConVarInt(sb_all_bot_team, 1);
		}
	}

	iPlayersInSurvivorTeam = -1;
	if(g_bCommonLimitAdjust == true) SetConVarInt(h_common_limit_cvar, 0);
	delete DisplayTimer;
	DisplayTimer = CreateTimer(1.0,Timer_CountSurvivor);

	return Plugin_Continue;
}

public void evtPlayerFirstSpawned(Event event, const char[] name, bool dontBroadcast)
{
	// This event's purpose is to execute when a player first enters the server. This eliminates a lot of problems when changing variables setting timers on clients, among fixing many sb_all_bot_team
	// issues.
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!client || IsFakeClient(client) || PlayerHasEnteredStart[client])
		return;

	#if DEBUG
		PrintToChatAll("[TS] Player has spawned for the first time");
	#endif

	// Versus Coop code, puts all players on infected at start, delay is added to prevent a weird glitch

	if (L4D_HasPlayerControlledZombies() && g_bVersusCoop)
		CreateTimer(0.1, Timer_VersusCoopTeamChanger, client, TIMER_FLAG_NO_MAPCHANGE);

	// Kill the player if they are infected and its not versus (prevents survival finale bug and player ghosts when there shouldn't be)
	if (L4D_HasPlayerControlledZombies() == false)
	{
		if (GetClientTeam(client)==TEAM_INFECTED)
		{
			if (IsPlayerGhost(client))
			{
				CreateTimer(0.1, Timer_InfectedKillSelf, client, TIMER_FLAG_NO_MAPCHANGE);
			}
		}
		if(g_bJoinableTeams && g_bJoinableTeamsAnnounce)
		{
			CreateTimer(10.0, AnnounceJoinInfected, client, TIMER_FLAG_NO_MAPCHANGE);
		}
	}

	PlayerHasEnteredStart[client] = true;
}

public Action Timer_VersusCoopTeamChanger(Handle Timer, int client)
{
	if(IsClientInGame(client))
	{
		CleanUpStateAndMusic(client);
		ChangeClientTeam(client, TEAM_INFECTED);
	}
	
	return Plugin_Continue;
}

public Action Timer_InfectedKillSelf(Handle Timer, int client)
{
	if(g_bCoopInfectedPlayerGhostState == true) return Plugin_Continue;

	if( client && IsClientInGame(client) && !IsFakeClient(client) )
	{
		PrintHintText(client,"[TS] %T","Not allowed to respawn",client);
		ForcePlayerSuicide(client);
	}
	return Plugin_Continue;
}

void TankHealthCheck()
{
	char difficulty[100];
	h_Difficulty.GetString(difficulty, sizeof(difficulty));

	zombieHP[6] = cvarZombieHP[6].IntValue;
	if (g_iCurrentMode == 2)
	{
		if(g_bL4D2Version)
			zombieHP[6] = RoundToFloor(zombieHP[6] * 1.5);	// Tank health is multiplied by 1.5x in VS
		else
			zombieHP[6] = RoundToFloor(zombieHP[6] * versus_tank_bonus_health.FloatValue);	// Tank health is multiplied by 1.5x in VS
	}
	else if (StrContains(difficulty, "easy", false) != -1)
	{
		zombieHP[6] = RoundToFloor(zombieHP[6] * 0.75);
	}
	else if (StrContains(difficulty, "normal", false) != -1)
	{
		zombieHP[6] = zombieHP[6];
	}
	else if (StrContains(difficulty, "hard", false) != -1 || StrContains(difficulty, "impossible", false) != -1)
	{
		zombieHP[6] = RoundToFloor(zombieHP[6] * 2.0);
	}
}

public Action MaxSpecialsSet(Handle Timer)
{
	SetConVarInt(z_max_player_zombies, g_iMaxPlayerZombies);
	#if DEBUG
	LogMessage("Max Player Zombies Set");
	#endif
	return Plugin_Continue;
}

public void evtRoundEnd (Event event, const char[] name, bool dontBroadcast)
{
	// If round has not been reported as ended ..
	if (!g_bHasRoundEnded)
	{
		for( int i = 1; i <= MaxClients; i++ )
			DeleteLight(i);

		// we mark the round as ended
		g_bHasRoundEnded = true;
		b_HasRoundStarted = false;
		g_bLeftSaveRoom = false;
		roundInProgress = false;
		g_iPlayerSpawn = 0;

		// This spawns a Survivor Bot so that the health bonus for the bots count (L4D only)
		if (!g_bL4D2Version && g_iCurrentMode == 2 && !RealPlayersOnSurvivors() && !AllSurvivorsDeadOrIncapacitated())
		{
			int bot = CreateFakeClient("Fake Survivor");
			ChangeClientTeam(bot,TEAM_SURVIVORS);
			DispatchKeyValue(bot,"classname","SurvivorBot");
			DispatchSpawn(bot);

			CreateTimer(0.1,kickbot, GetClientUserId(bot), TIMER_FLAG_NO_MAPCHANGE);
		}
		ResetTimer();
	}

}

public void OnMapStart()
{
	g_bMapStarted = true;
	CheckandPrecacheModel(MODEL_SMOKER);
	CheckandPrecacheModel(MODEL_BOOMER);
	CheckandPrecacheModel(MODEL_HUNTER);
	CheckandPrecacheModel(MODEL_SPITTER);
	CheckandPrecacheModel(MODEL_JOCKEY);
	CheckandPrecacheModel(MODEL_CHARGER);
	CheckandPrecacheModel(MODEL_TANK);

	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));
	if(StrEqual("c6m1_riverbank", sMap, false))
		g_bSpawnWitchBride = true;

	lastHumanTankId = 0;
}

public void OnMapEnd()
{
	b_HasRoundStarted = false;
	g_bHasRoundEnded = true;
	g_bLeftSaveRoom = false;
	g_iPlayerSpawn = 0;
	roundInProgress = false;
	g_bMapStarted = false;
	g_bSpawnWitchBride = false;
	iPlayersInSurvivorTeam = 0;
	ResetTimer();
}

public void OnConfigsExecuted()
{
	if(!g_bFirstRecord)
	{
		if(g_bL4D2Version)
		{
			sb_all_bot_game_default = sb_all_bot_game.BoolValue;
			allow_all_bot_survivor_team_default = allow_all_bot_survivor_team.BoolValue;
		}
		else
		{
			sb_all_bot_team_default = sb_all_bot_team.BoolValue;
		}
		vs_max_team_switches_default = vs_max_team_switches.IntValue;
		g_bFirstRecord = true;
	}

	IsAllowed();
}

public void ConVarChanged_Allow(ConVar convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		CreateTimer(1.0, Timer_PluginStart, _, TIMER_FLAG_NO_MAPCHANGE);
		g_bCvarAllow = true;

		// Create persistent storage for client HUD preferences
		usrHUDPref = CreateTrie();

		GetSpawnDisConvars();

		HookEvent("round_start", evtRoundStart,		EventHookMode_PostNoCopy);
		if(g_bL4D2Version) HookEvent("survival_round_start", Event_SurvivalRoundStart,		EventHookMode_PostNoCopy); //生存模式之下計時開始之時 (一代沒有此事件)
		else HookEvent("create_panic_event" , Event_SurvivalRoundStart,		EventHookMode_PostNoCopy); //一代生存模式之下計時開始觸發屍潮
		HookEvent("round_end",				evtRoundEnd,		EventHookMode_PostNoCopy); //trigger twice in versus mode, one when all survivors wipe out or make it to saferom, one when first round ends (second round_start begins).
		HookEvent("map_transition", 		evtRoundEnd,		EventHookMode_PostNoCopy); //all survivors make it to saferoom, and server is about to change next level in coop mode (does not trigger round_end) 
		HookEvent("mission_lost", 			evtRoundEnd,		EventHookMode_PostNoCopy); //all survivors wipe out in coop mode (also triggers round_end)
		HookEvent("finale_vehicle_leaving", evtRoundEnd,		EventHookMode_PostNoCopy); //final map final rescue vehicle leaving  (does not trigger round_end)
	
		HookEvent("player_death", evtPlayerDeath, EventHookMode_Pre);
		HookEvent("player_team", evtPlayerTeam);
		HookEvent("player_spawn", evtPlayerSpawn);
		HookEvent("finale_start", 			evtFinaleStart, EventHookMode_PostNoCopy); //final starts, some of final maps won't trigger
		HookEvent("finale_radio_start", 	evtFinaleStart, EventHookMode_PostNoCopy); //final starts, all final maps trigger
		if(g_bL4D2Version) HookEvent("gauntlet_finale_start", 	evtFinaleStart, EventHookMode_PostNoCopy); //final starts, only rushing maps trigger (C5M5, C13M4)
		HookEvent("player_death", evtInfectedDeath);
		HookEvent("player_spawn", evtInfectedSpawn);
		HookEvent("player_hurt", evtInfectedHurt);
		HookEvent("player_team", evtTeamSwitch);
		HookEvent("ghost_spawn_time", evtInfectedWaitSpawn);
		HookEvent("player_first_spawn", evtPlayerFirstSpawned);
		HookEvent("player_entered_start_area", evtPlayerFirstSpawned);
		HookEvent("player_entered_checkpoint", evtPlayerFirstSpawned);
		HookEvent("player_transitioned", evtPlayerFirstSpawned);
		HookEvent("player_left_start_area", evtPlayerFirstSpawned);
		HookEvent("player_left_checkpoint", evtPlayerFirstSpawned);
		HookEvent("player_incapacitated", Event_Incap);
		HookEvent("player_ledge_grab", Event_Incap);
		HookEvent("player_now_it", Event_GotVomit);
		HookEvent("revive_success", Event_revive_success);//救起倒地的or 懸掛的
		HookEvent("player_ledge_release", Event_ledge_release);//懸掛的玩家放開了
		HookEvent("player_bot_replace", evtBotReplacedPlayer);
		HookEvent("tank_frustrated", OnTankFrustrated, EventHookMode_Post);

		// Hook a sound
		AddNormalSoundHook(HookSound_Callback);

		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				OnClientPutInServer(i);
			}
		}
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		OnPluginEnd();
		g_bCvarAllow = false;
		UnhookEvent("round_start", evtRoundStart,		EventHookMode_PostNoCopy);
		if(g_bL4D2Version) UnhookEvent("survival_round_start", Event_SurvivalRoundStart,		EventHookMode_PostNoCopy); //生存模式之下計時開始之時 (一代沒有此事件)
		else UnhookEvent("create_panic_event" , Event_SurvivalRoundStart,		EventHookMode_PostNoCopy); //一代生存模式之下計時開始觸發屍潮
		UnhookEvent("round_end",				evtRoundEnd,		EventHookMode_PostNoCopy); //trigger twice in versus mode, one when all survivors wipe out or make it to saferom, one when first round ends (second round_start begins).
		UnhookEvent("map_transition", 		evtRoundEnd,		EventHookMode_PostNoCopy); //all survivors make it to saferoom, and server is about to change next level in coop mode (does not trigger round_end) 
		UnhookEvent("mission_lost", 			evtRoundEnd,		EventHookMode_PostNoCopy); //all survivors wipe out in coop mode (also triggers round_end)
		UnhookEvent("finale_vehicle_leaving", evtRoundEnd,		EventHookMode_PostNoCopy); //final map final rescue vehicle leaving  (does not trigger round_end)
	
		UnhookEvent("player_death", evtPlayerDeath, EventHookMode_Pre);
		UnhookEvent("player_team", evtPlayerTeam);
		UnhookEvent("player_spawn", evtPlayerSpawn);
		UnhookEvent("finale_start", 			evtFinaleStart, EventHookMode_PostNoCopy); //final starts, some of final maps won't trigger
		UnhookEvent("finale_radio_start", 	evtFinaleStart, EventHookMode_PostNoCopy); //final starts, all final maps trigger
		if(g_bL4D2Version) UnhookEvent("gauntlet_finale_start", 	evtFinaleStart, EventHookMode_PostNoCopy); //final starts, only rushing maps trigger (C5M5, C13M4)
		UnhookEvent("player_death", evtInfectedDeath);
		UnhookEvent("player_spawn", evtInfectedSpawn);
		UnhookEvent("player_hurt", evtInfectedHurt);
		UnhookEvent("player_team", evtTeamSwitch);
		UnhookEvent("ghost_spawn_time", evtInfectedWaitSpawn);
		UnhookEvent("player_first_spawn", evtPlayerFirstSpawned);
		UnhookEvent("player_entered_start_area", evtPlayerFirstSpawned);
		UnhookEvent("player_entered_checkpoint", evtPlayerFirstSpawned);
		UnhookEvent("player_transitioned", evtPlayerFirstSpawned);
		UnhookEvent("player_left_start_area", evtPlayerFirstSpawned);
		UnhookEvent("player_left_checkpoint", evtPlayerFirstSpawned);
		UnhookEvent("player_incapacitated", Event_Incap);
		UnhookEvent("player_ledge_grab", Event_Incap);
		UnhookEvent("player_now_it", Event_GotVomit);
		UnhookEvent("revive_success", Event_revive_success);//救起倒地的or 懸掛的
		UnhookEvent("player_ledge_release", Event_ledge_release);//懸掛的玩家放開了


		// Hook a sound
		RemoveNormalSoundHook(HookSound_Callback);

		for( int i = 1; i <= MaxClients; i++ ){
			if(IsClientInGame(i)) OnClientDisconnect(i);
		}
	}
}

int g_iCurrentModeFlag;
bool IsAllowedGameMode()
{
	if( g_bMapStarted == false )
		return false;

	if( g_hCvarMPGameMode == null )
		return false;

	int iCvarModesTog = g_hCvarModesTog.IntValue;
	g_iCurrentMode = 0;

	int entity = CreateEntityByName("info_gamemode");
	if( IsValidEntity(entity) )
	{
		DispatchSpawn(entity);
		HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
		ActivateEntity(entity);
		AcceptEntityInput(entity, "PostSpawnActivate");
		if( IsValidEntity(entity) ) // Because sometimes "PostSpawnActivate" seems to kill the ent.
			RemoveEdict(entity); // Because multiple plugins creating at once, avoid too many duplicate ents in the same frame
	}

	if( iCvarModesTog != 0 )
	{
		if( g_iCurrentModeFlag == 0 )
			return false;

		if( !(iCvarModesTog & g_iCurrentModeFlag) )
			return false;
	}

	char sGameModes[64], sGameMode[64];
	g_hCvarMPGameMode.GetString(sGameMode, sizeof(sGameMode));
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);

	g_hCvarModes.GetString(sGameModes, sizeof(sGameModes));
	if( sGameModes[0] )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) == -1 )
			return false;
	}

	g_hCvarModesOff.GetString(sGameModes, sizeof(sGameModes));
	if( sGameModes[0] )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) != -1 )
			return false;
	}

	return true;
}

public void OnGamemode(const char[] output, int caller, int activator, float delay)
{
	if( strcmp(output, "OnCoop") == 0 )
	{
		g_iCurrentModeFlag = 1;
		g_iCurrentMode = 1;
	}
	else if( strcmp(output, "OnSurvival") == 0 )
	{
		g_iCurrentModeFlag = 2;
		g_iCurrentMode = 3;
	}
	else if( strcmp(output, "OnVersus") == 0 )
	{
		g_iCurrentModeFlag = 4;
		g_iCurrentMode = 2;
	}
	else if( strcmp(output, "OnScavenge") == 0 )
	{
		g_iCurrentModeFlag = 8;
		g_iCurrentMode = 2;
	}
}
public Action Timer_PlayerLeftStart(Handle Timer)
{
	if( g_bCvarAllow == false || g_iCurrentMode == 3 )//生存模式之下 always true
	{
		PlayerLeftStartTimer = null;
		return Plugin_Stop;
	}

	if (L4D_HasAnySurvivorLeftSafeArea() || g_bSafeSpawn ) 
	{
		g_bLeftSaveRoom = true;
		
		GameStart();
		
		PlayerLeftStartTimer = null;
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public void evtUnlockVersusDoor(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bL4D2Version || g_bLeftSaveRoom || g_iCurrentMode != 2 || RealPlayersOnInfected() || TempBotSpawned)
		return;

	#if DEBUG
		PrintToChatAll("[TS] Attempting to spawn tempbot");
	#endif
	int bot = CreateFakeClient("tempbot");
	if (bot != 0)
	{
		ChangeClientTeam(bot,TEAM_INFECTED);
		CreateTimer(0.1,kickbot,GetClientUserId(bot), TIMER_FLAG_NO_MAPCHANGE);
		TempBotSpawned = true;
	}
	else
	{
		LogError("Temperory Infected Bot was not spawned for the Versus Door Unlocker!");
	}
}

public Action InfectedBotBooterVersus(Handle Timer)
{
	//This is to check if there are any extra bots and boot them if necessary, excluding tanks, versus only
	if (L4D_HasPlayerControlledZombies())
	{
		// current count ...
		int total;

		for (int i=1; i<=MaxClients; i++)
		{
			// if player is ingame ...
			if (IsClientInGame(i))
			{
				// if player is on infected's team
				if (GetClientTeam(i) == TEAM_INFECTED)
				{
					// We count depending on class ...
					if (!IsPlayerTank(i) || (IsPlayerTank(i) && !IsPlayerAlive(i)))
					{
						total++;
					}
				}
			}
		}
		if (total + InfectedBotQueue > g_iMaxPlayerZombies)
		{
			int kick = total + InfectedBotQueue - g_iMaxPlayerZombies;
			int kicked = 0;

			// We kick any extra bots ....
			for (int i=1;(i<=MaxClients)&&(kicked < kick);i++)
			{
				// If player is infected and is a bot ...
				if (IsClientInGame(i) && IsFakeClient(i))
				{
					//  If bot is on infected ...
					if (GetClientTeam(i) == TEAM_INFECTED)
					{
						// If player is not a tank
						if (!IsPlayerTank(i) || ((IsPlayerTank(i) && !IsPlayerAlive(i))))
						{
							// timer to kick bot
							CreateTimer(0.1,kickbot,GetClientUserId(i), TIMER_FLAG_NO_MAPCHANGE);

							// increment kicked count ..
							kicked++;
							#if DEBUG
							LogMessage("Kicked a Bot");
							#endif
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

// This code, combined with Durzel's code, announce certain messages to clients when they first enter the server

public void OnClientPutInServer(int client)
{
	if(g_bCvarAllow == false) return;

	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);

	// If is a bot, skip this function
	if (IsFakeClient(client))
		return;

	iPlayerTeam[client] = 1;

	// Durzel's code ***********************************************************************************
	char clientSteamID[32];
	int doHideHUD;

//	GetClientAuthString(client, clientSteamID, 32);

	// Try and find their HUD visibility preference
	int foundKey = GetTrieValue(usrHUDPref, clientSteamID, doHideHUD);
	if (foundKey)
	{
		if (doHideHUD)
		{
			// This user chose not to view the HUD at some point in the game
			hudDisabled[client] = 1;
		}
	}
	//else hudDisabled[client] = 1;
	// End Durzel's code **********************************************************************************
}

public Action CheckGameMode(int client, int args)
{
	if (client)
	{
		PrintToChat(client, "[TS] g_iCurrentMode = %i, L4D_HasPlayerControlledZombies(): %d", g_iCurrentMode, L4D_HasPlayerControlledZombies());
	}

	return Plugin_Handled;
}

public Action CheckQueue(int client, int args)
{
	if( g_bCvarAllow == false) return Plugin_Handled;

	if (client)
	{
		if (L4D_HasPlayerControlledZombies())
			CountInfected();
		else
			CountInfected_Coop();

		CPrintToChat(client, "[TS] InfectedBotQueue = {green}%i{default}, InfectedBotCount = {green}%i{default}, InfectedRealCount = {green}%i{default}, InfectedRealQueue = {green}%i{default}", InfectedBotQueue, InfectedBotCount, InfectedRealCount, InfectedRealQueue);
	}

	return Plugin_Handled;
}

public Action JoinInfected(int client, int args)
{
	if( g_bCvarAllow == false) return Plugin_Handled;

	if (client && L4D_HasPlayerControlledZombies() == false && g_bJoinableTeams)
	{
		if(HasAccess(client, g_sJoinInfectedAccesslvl) == true)
		{
			if (HumansOnInfected() < g_iHumanCoopLimit)
			{
				CleanUpStateAndMusic(client);
				ChangeClientTeam(client, TEAM_INFECTED);
				iPlayerTeam[client] = TEAM_INFECTED;
			}
			else
				PrintHintText(client, "[TS] The Infected Team is full.");
		}
		else
		{
			PrintHintText(client, "[TS] %T", "Access", client);
		}
	}

	return Plugin_Handled;
}

public Action JoinSurvivors(int client, int args)
{
	if( g_bCvarAllow == false) return Plugin_Handled;

	if (client && L4D_HasPlayerControlledZombies() == false)
	{
		SwitchToSurvivors(client);
	}

	return Plugin_Handled;
}

public Action ForceInfectedSuicide(int client, int args)
{
	if( g_bCvarAllow == false) return Plugin_Handled;

	if (client && GetClientTeam(client) == 3 && !IsFakeClient(client) && IsPlayerAlive(client) && !IsPlayerGhost(client))
	{
		int bGameMode = g_iCurrentMode;
		if(bGameMode == 3) bGameMode = 4;
		if(bGameMode & g_iZSDisableGamemode)
		{
			PrintHintText(client,"[TS] %T","Not allowed to suicide during current mode",client);
			return Plugin_Handled;
		}

		if(GetEngineTime() - fPlayerSpawnEngineTime[client] < SUICIDE_TIME)
		{
			PrintHintText(client,"[TS] %T","Not allowed to suicide so quickly",client);
			return Plugin_Handled;
		}

		if( L4D_GetSurvivorVictim(client) != -1 )
		{
			PrintHintText(client,"[TS] %T","Not allowed to suicide",client);
			return Plugin_Handled;
		}

		ForcePlayerSuicide(client);
	}

	return Plugin_Handled;
}

public Action Console_ZLimit(int client, int args)
{
	if( g_bCvarAllow == false) return Plugin_Handled;

	if (client == 0)
	{
		PrintToServer("[TS] sm_zlimit cannot be used by server.");
		return Plugin_Handled;
	}
	if(args > 1)
	{
		ReplyToCommand(client, "[TS] %T","Usage: sm_zlimit",client);
		return Plugin_Handled;
	}
	if(args < 1)
	{
		ReplyToCommand(client, "[TS] %T\n%T","Current Special Infected Limit",client, g_iMaxPlayerZombies,"Usage: sm_zlimit",client);
		return Plugin_Handled;
	}

	char arg1[64];
	GetCmdArg(1, arg1, 64);
	if(IsInteger(arg1))
	{
		int newlimit = StringToInt(arg1);
		if(newlimit>30)
		{
			ReplyToCommand(client, "[TS] %T","why you need so many special infected?",client);
		}
		else if (newlimit<0)
		{
			ReplyToCommand(client, "[TS] %T","Usage: sm_zlimit",client);
		}
		else if(newlimit!=g_iMaxPlayerZombies)
		{
			g_iMaxPlayerZombies = newlimit;
			CreateTimer(0.1, MaxSpecialsSet);
			C_PrintToChatAll("[{olive}TS{default}] {lightgreen}%N{default}: %t", client, "Special Infected Limit has been changed",newlimit);
			
			CheckIfBotsNeeded2();
		}
		else
		{
			ReplyToCommand(client, "[TS] %T","Special Infected Limit is already",client, g_iMaxPlayerZombies);
		}
		return Plugin_Handled;
	}
	else
	{
		ReplyToCommand(client, "[TS] %T","Usage: sm_zlimit",client);
		return Plugin_Handled;
	}
}

public Action Console_Timer(int client, int args)
{
	if( g_bCvarAllow == false) return Plugin_Handled;

	if (client == 0)
	{
		PrintToServer("[TS] sm_timer cannot be used by server.");
		return Plugin_Handled;
	}

	if(args > 2)
	{
		ReplyToCommand(client, "[TS] %T","Usage: sm_timer",client);
		return Plugin_Handled;
	}
	if(args < 1)
	{
		ReplyToCommand(client, "[TS] %T\n%T","Current Spawn Timer",client,g_iInfectedSpawnTimeMin,g_iInfectedSpawnTimeMax,"Usage: sm_timer",client );
		return Plugin_Handled;
	}

	if(args == 1)
	{
		char arg1[64];
		GetCmdArg(1, arg1, 64);
		if(IsInteger(arg1))
		{
			int DD = StringToInt(arg1);

			if(DD<=0)
			{
				ReplyToCommand(client, "[TS] %T","Failed to set timer!",client);
			}
			else if (DD > 180)
			{
				ReplyToCommand(client, "[TS] %T","why so long?",client);
			}
			else
			{
				h_InfectedSpawnTimeMin.SetInt(DD);
				h_InfectedSpawnTimeMax.SetInt(DD);
				C_PrintToChatAll("[{olive}TS{default}] {lightgreen}%N{default}: %t",client,"Bot Spawn Timer has been changed",DD,DD);
			}
			return Plugin_Handled;
		}
		else
		{
			ReplyToCommand(client, "[TS] %T","Usage: sm_timer",client);
			return Plugin_Handled;
		}
	}
	else
	{
		char arg1[64];
		GetCmdArg(1, arg1, 64);
		char arg2[64];
		GetCmdArg(2, arg2, 64);
		if(IsInteger(arg1) && IsInteger(arg2))
		{
			int Max = StringToInt(arg2);
			int Min = StringToInt(arg1);
			if(Min>Max)
			{
				int temp = Max;
				Max = Min;
				Min = temp;
			}

			if(Max>180)
			{
				ReplyToCommand(client, "[TS] %T","why so long?",client);
			}
			else
			{
				h_InfectedSpawnTimeMin.SetInt(Min);
				h_InfectedSpawnTimeMax.SetInt(Max);
				C_PrintToChatAll("[{olive}TS{green}] {lightgreen}%N{default}: %t",client,"Bot Spawn Timer has been changed",Min,Max);
			}
			return Plugin_Handled;
		}
		else
		{
			ReplyToCommand(client, "[TS] %T","Usage: sm_timer",client);
			return Plugin_Handled;
		}
	}
}

// Joining spectators is for developers only, commented in the final

public Action JoinSpectator(int client, int args)
{
	if( g_bCvarAllow == false) return Plugin_Handled;

	if ((client) && (g_bJoinableTeams))
	{
		ChangeClientTeam(client, TEAM_SPECTATOR);
	}

	return Plugin_Handled;
}

public Action AnnounceJoinInfected(Handle timer, int client)
{
	if (IsClientInGame(client) && (!IsFakeClient(client)))
	{
		if (g_bJoinableTeamsAnnounce && g_bJoinableTeams && L4D_HasPlayerControlledZombies() == false)
		{
			C_PrintToChat(client,"[{olive}TS{default}] %T","Join infected team in coop/survival/realism",client);
			C_PrintToChat(client,"%T","Join survivor team",client);
		}
	}
	return Plugin_Continue;
}

//playerspawn is triggered even when bot or human takes over each other (even they are already dead state) or a survivor is spawned
public void evtPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	// We get the client id and time
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	// If client is valid
	if (!client || !IsClientInGame(client)) return;

	if(b_HasRoundStarted && g_iPlayerSpawn == 0)
	{
		CreateTimer(0.5, Timer_PluginStart, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	g_iPlayerSpawn = 1;

	if(GetClientTeam(client) == TEAM_SURVIVORS)
	{
		RemoveSurvivorModelGlow(client);
		CreateTimer(0.3, tmrDelayCreateSurvivorGlow, userid, TIMER_FLAG_NO_MAPCHANGE);
		delete DisplayTimer;
		DisplayTimer = CreateTimer(1.0, Timer_CountSurvivor);
	}

	if (GetClientTeam(client) != TEAM_INFECTED)
		return;

	if (IsPlayerTank(client))
	{
		char clientname[256];
		GetClientName(client, clientname, sizeof(clientname));
		if (g_iCurrentMode == 1 && IsFakeClient(client) && RealPlayersOnInfected() && StrContains(clientname, "Bot", false) == -1)
		{
			CreateTimer(0.1, TankBugFix, client, TIMER_FLAG_NO_MAPCHANGE);
		}
		if (g_bLeftSaveRoom)
		{
			#if DEBUG
			LogMessage("Tank Event Triggered");
			#endif

			TanksPlaying = 0;
			MaxPlayerTank = 0;
			for (int i=1;i<=MaxClients;i++)
			{
				// We check if player is in game
				if (!IsClientInGame(i)) continue;

				// Check if client is infected ...
				if (GetClientTeam(i)==TEAM_INFECTED)
				{
					// If player is a tank
					if (IsPlayerTank(i) && IsPlayerAlive(i))
					{
						TanksPlaying++;
						MaxPlayerTank++;
					}
				}
			}

			MaxPlayerTank = MaxPlayerTank + g_iMaxPlayerZombies;
			SetConVarInt(z_max_player_zombies, MaxPlayerTank);
			#if DEBUG
			LogMessage("Incremented Max Zombies from Tank Spawn EVENT");
			#endif

			if (g_iCurrentMode == 3)
			{
				if (IsFakeClient(client) && RealPlayersOnInfected())
				{
					if ( (!AreTherePlayersWhoAreNotTanks() && g_bCoopPlayableTank && StrContains(clientname, "Bot", false) == -1) || (!g_bCoopPlayableTank && StrContains(clientname, "Bot", false) == -1) )
					{
						CreateTimer(0.1, TankBugFix, client, TIMER_FLAG_NO_MAPCHANGE);
					}
					else if (g_bCoopPlayableTank && AreTherePlayersWhoAreNotTanks())
					{
						CreateTimer(0.5, TankSpawner, client, TIMER_FLAG_NO_MAPCHANGE);
						CreateTimer(1.0, kickbot, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
					}
				}
			}
			else
			{
				MaxPlayerTank = g_iMaxPlayerZombies;
				SetConVarInt(z_max_player_zombies, g_iMaxPlayerZombies);
			}
		}
	}
	else if (IsFakeClient(client))
	{
		delete FightOrDieTimer[client];
		FightOrDieTimer[client] = CreateTimer(g_fIdletime_b4slay, DisposeOfCowards, client);
	}

	// Turn on Flashlight for Infected player
	TurnFlashlightOn(client);
}

public Action DisposeOfCowards(Handle timer, int coward)
{
	if( g_bCvarAllow == false)
	{
		FightOrDieTimer[coward] = null;
		return Plugin_Stop;
	}

	if (coward && IsClientInGame(coward) && IsFakeClient(coward) && GetClientTeam(coward) == TEAM_INFECTED && !IsPlayerTank(coward) && IsPlayerAlive(coward))
	{
		// Check to see if the infected can be seen by the survivors. If so, kill the timer and make a new one.
		if (CanBeSeenBySurvivors(coward) || IsTooClose(coward, h_SpawnDistanceMin.FloatValue) || L4D_GetSurvivorVictim(coward) > 0)
		{
			FightOrDieTimer[coward] = null;
			FightOrDieTimer[coward] = CreateTimer(g_fIdletime_b4slay, DisposeOfCowards, coward);
			return Plugin_Continue;
		}
		else
		{
			CreateTimer(0.1, kickbot, GetClientUserId(coward), TIMER_FLAG_NO_MAPCHANGE);
			//PrintToChatAll("[TS] Kicked bot %N for not attacking", coward);
		}
	}
	FightOrDieTimer[coward] = null;
	return Plugin_Continue;
}

public void evtPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	// We get the client id and time
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client) DeleteLight(client); // Delete attached flashlight

	if(client && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVORS)
	{
		RemoveSurvivorModelGlow(client);
		delete DisplayTimer;
		DisplayTimer = CreateTimer(1.0,Timer_CountSurvivor);
	}

	delete FightOrDieTimer[client];
	delete RestoreColorTimer[client];

	if (!client || !IsClientInGame(client) || GetClientTeam(client) != TEAM_INFECTED ) return;

	// Removes Sphere bubbles in the map when a player dies
	if (!IsFakeClient(client) && L4D_HasPlayerControlledZombies() == false)
	{
		CreateTimer(0.1, ScrimmageTimer, client, TIMER_FLAG_NO_MAPCHANGE);
	}

	// If round has ended .. we ignore this
	if (g_bHasRoundEnded || g_bInitialSpawn) return;

	// if victim was a bot, we setup a timer to spawn a int bot ...
	if (L4D_HasPlayerControlledZombies())
	{
		if (IsFakeClient(client))
		{
			if(g_bDisableInfectedBot) return;
			
			int SpawnTime = GetRandomInt(g_iInfectedSpawnTimeMin, g_iInfectedSpawnTimeMax);
			if (g_bAdjustSpawnTimes && g_iMaxPlayerZombies != HumansOnInfected())
				SpawnTime = SpawnTime  - (TrueNumberOfAliveSurvivors() * g_iReducedSpawnTimesOnPlayer);

			if(SpawnTime < 0)
				SpawnTime = 1;
			#if DEBUG
				PrintToChatAll("[TS] playerdeath");
			#endif
			respawnDelay[client] = SpawnTime;
			InfectedBotQueue++;

			if( g_bCoordination && IsPlayerTank(client)) respawnDelay[client] = 0;
			
			for(int i = 1; i <= L4D_MAXPLAYERS; i++)
			{
				if(SpawnInfectedBotTimer[i] == null)
				{
					SpawnInfectedBotTimer[i] = CreateTimer(float(SpawnTime)+0.1, Timer_Spawn_InfectedBot, i);
					break;
				}
			}
		}
		else
		{
			//真人玩家的復活時間是根據官方指令設定
			//z_ghost_delay_min 20
			//z_ghost_delay_max 30 
		}

		#if DEBUG
			PrintToChatAll("[TS] An infected bot has been added to the spawn queue...");
		#endif
	}
	// This spawns a bot in coop/survival regardless if the special that died was controlled by a player, MI 5
	else
	{
		int SpawnTime = GetRandomInt(g_iInfectedSpawnTimeMin, g_iInfectedSpawnTimeMax);
		if(g_bAdjustSpawnTimes)
		{
			if(IsFakeClient(client))
			{
				SpawnTime = SpawnTime - (TrueNumberOfAliveSurvivors() * g_iReducedSpawnTimesOnPlayer) + (HumansOnInfected() * 3);
				if(SpawnTime <= 0) SpawnTime = 1;
			}
			else
			{
				SpawnTime = g_iInfectedSpawnTimeMin - TrueNumberOfAliveSurvivors() * g_iReducedSpawnTimesOnPlayer + (HumansOnInfected() * 3);
				if(SpawnTime <= 6) SpawnTime = 6;
			}
		}
		respawnDelay[client] = SpawnTime;
		InfectedBotQueue++;

		if( g_bCoordination && IsPlayerTank(client)) respawnDelay[client] = 0;

		for(int i = 1; i <= L4D_MAXPLAYERS; i++)
		{
			if(SpawnInfectedBotTimer[i] == null)
			{
				SpawnInfectedBotTimer[i] = CreateTimer(float(SpawnTime)+0.1, Timer_Spawn_InfectedBot, i);
				break;
			}
		}

		#if DEBUG
			PrintToChatAll("[TS] An infected bot has been added to the spawn queue...");
		#endif
	}

	//This will prevent the stats board from coming up if the cvar was set to 1 (L4D 1 only)
	if (!g_bL4D2Version && !IsFakeClient(client) && h_StatsBoard.BoolValue == false && g_iCurrentMode != 2)
	{
		CreateTimer(1.0, ZombieClassTimer, client, TIMER_FLAG_NO_MAPCHANGE);
	}

	// This fixes the spawns when the spawn timer is set to 5 or below and fixes the spitter spit glitch
	if (IsFakeClient(client) && !IsPlayerSpitter(client))
		CreateTimer(1.0, kickbot, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);

	if (!clientGreeted[client] && g_bAnnounce)
	{
		CreateTimer(3.0, TimerAnnounce, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action ZombieClassTimer(Handle timer, int client)
{
	if (client)
	{
		SetEntProp(client, Prop_Send, "m_zombieClass", 0);
	}
	return Plugin_Continue;
}

public void evtPlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	RemoveSurvivorModelGlow(client);
	CreateTimer(0.1, tmrDelayCreateSurvivorGlow, userid, TIMER_FLAG_NO_MAPCHANGE);

	CreateTimer(0.5, PlayerChangeTeamCheck, userid, TIMER_FLAG_NO_MAPCHANGE);//延遲一秒檢查

	// We get some data needed ...
	int oldteam = event.GetInt("oldteam");

	// We get the client id and time
	if(client) DeleteLight(client);

	DataPack pack = new DataPack();
	pack.WriteCell(userid);
	pack.WriteCell(oldteam);
	CreateTimer(0.5, PlayerChangeTeamCheck2, pack, TIMER_FLAG_NO_MAPCHANGE | TIMER_DATA_HNDL_CLOSE);//延遲一秒檢查
}

public Action PlayerChangeTeamCheck(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (client && IsClientInGame(client) && !IsFakeClient(client))
	{
		delete DisplayTimer;
		DisplayTimer = CreateTimer(1.0,Timer_CountSurvivor);

		if(L4D_HasPlayerControlledZombies() == false)
		{
			int iTeam = GetClientTeam(client);
			if(iTeam == TEAM_INFECTED)
			{
				if(iPlayerTeam[client] != TEAM_INFECTED)
				{
					ChangeClientTeam(client,TEAM_SPECTATOR);
					FakeClientCommand(client,"sm_js");
					return Plugin_Continue;
				}

				if(g_bJoinableTeams)
				{
					if(HasAccess(client, g_sJoinInfectedAccesslvl) == true)
					{
						if (HumansOnInfected() <= g_iHumanCoopLimit)
						{
							if(g_bL4D2Version)
							{
								SendConVarValue(client, g_hCvarMPGameMode, "versus");
								if(bDisableSurvivorModelGlow == true)
								{
									bDisableSurvivorModelGlow = false;
									for( int i = 1; i <= MaxClients; i++ )
									{
										CreateSurvivorModelGlow(i);
									}
								}
							}
							return Plugin_Continue;
						}
					}
					else
					{
						ChangeClientTeam(client,TEAM_SPECTATOR);
					}
				}
				else
				{
					PrintHintText(client, "%T", "Can't Join The Infected Team.", client);
				}
				ChangeClientTeam(client,TEAM_SPECTATOR);
			}
			else
			{
				iPlayerTeam[client] = iTeam;
				if(g_bL4D2Version)
				{
					static char mode[64];
					g_hCvarMPGameMode.GetString(mode, sizeof(mode));
					SendConVarValue(client, g_hCvarMPGameMode, mode);

					if(bDisableSurvivorModelGlow == false)
					{
						if(!RealPlayersOnInfected())
						{
							bDisableSurvivorModelGlow = true;
							for( int i = 1; i <= MaxClients; i++ )
							{
								RemoveSurvivorModelGlow(i);
							}
						}
						else
						{
							for( int i = 1; i <= MaxClients; i++ )
							{
								RemoveSurvivorModelGlow(i);
								CreateSurvivorModelGlow(i);
							}
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action PlayerChangeTeamCheck2(Handle timer, DataPack pack)
{
	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());
	int oldteam = pack.ReadCell();
	if (client && IsClientInGame(client) && !IsFakeClient(client))
	{
		int newteam = GetClientTeam(client);
		if (L4D_HasPlayerControlledZombies())
		{
			if(g_bHasRoundEnded || !g_bLeftSaveRoom) return Plugin_Continue;
			if(g_bDisableInfectedBot) return Plugin_Continue;
			
			if (oldteam == 3)
			{
				CheckIfBotsNeeded(-1);
			}
			if (newteam == 3)
			{
				CheckIfBotsNeeded(-1);
				//Kick Timer
				CreateTimer(1.0, InfectedBotBooterVersus, _, TIMER_FLAG_NO_MAPCHANGE);
				#if DEBUG
				LogMessage("A player switched to infected, attempting to boot a bot");
				#endif
			}
		}
		else
		{
			if(newteam == 3 || newteam == 1)
			{
				// Removes Sphere bubbles in the map when a player joins the infected team, or spectator team
				CreateTimer(0.1, ScrimmageTimer, client, TIMER_FLAG_NO_MAPCHANGE);
			}

			if(oldteam == 3 || newteam == 3)
			{
				CheckIfBotsNeeded2();
			}
		}
	}

	return Plugin_Continue;
}

public Action Timer_CountSurvivor(Handle timer)
{
	int iAliveSurplayers = CheckAliveSurvivorPlayers_InSV();

	if(iAliveSurplayers >= 0 && (iAliveSurplayers != iPlayersInSurvivorTeam))
	{
		DisplayLock = true;
		int addition = iAliveSurplayers - 4;
		if(addition < 0) addition = 0;

		g_iTankLimit = h_TankLimit.IntValue + (h_PlayerAddTankLimit.IntValue * (addition/h_PlayerAddTankLimitScale.IntValue));

		if(h_PlayerAddZombies.IntValue > 0)
		{
			g_iMaxPlayerZombies = h_MaxPlayerZombies.IntValue + (h_PlayerAddZombies.IntValue * (addition/h_PlayerAddZombiesScale.IntValue));
			CreateTimer(0.1, MaxSpecialsSet);

			CheckIfBotsNeeded2();
		}

		if(g_bTankHealthAdjust)
		{
			SetConVarInt(cvarZombieHP[6], g_iTankHealth + (h_PlayerAddTankHealth.IntValue * (addition/h_PlayerAddTankHealthScale.IntValue)));
			if(g_bCommonLimitAdjust)
			{
				SetConVarInt(h_common_limit_cvar, g_iCommonLimit + (h_PlayerAddCommonLimit.IntValue * (addition/h_PlayerAddCommonLimitScale.IntValue)));
				if(g_bStatusAnnouncementEnable) C_PrintToChatAll("[{olive}TS{default}] %t","Current status1",iAliveSurplayers,g_iMaxPlayerZombies,zombieHP[6],h_common_limit_cvar.IntValue);
			}
			else
			{
				if(g_bStatusAnnouncementEnable) C_PrintToChatAll("[{olive}TS{default}] %t","Current status3",iAliveSurplayers,g_iMaxPlayerZombies,zombieHP[6]);
			}
		}
		else
		{
			if(g_bCommonLimitAdjust)
			{
				SetConVarInt(h_common_limit_cvar, g_iCommonLimit + h_PlayerAddCommonLimit.IntValue * (addition/h_PlayerAddCommonLimitScale.IntValue));
				if(g_bStatusAnnouncementEnable) C_PrintToChatAll("[{olive}TS{default}] %t","Current status2",iAliveSurplayers,g_iMaxPlayerZombies,h_common_limit_cvar.IntValue);
			}
			else
			{
				if(g_bStatusAnnouncementEnable) C_PrintToChatAll("[{olive}TS{default}] %t","Current status4",iAliveSurplayers,g_iMaxPlayerZombies);
			}
		}
		iPlayersInSurvivorTeam = iAliveSurplayers;
	}

	DisplayLock = false;
	DisplayTimer = null;
	return Plugin_Continue;
}

public void OnClientDisconnect(int client)
{
	if(!IsClientInGame(client)) return;

	iPlayerTeam[client] = 1;
	// When a client disconnects we need to restore their HUD preferences to default for when
	// a int client joins and fill the space.
	hudDisabled[client] = 0;
	clientGreeted[client] = 0;

	// Reset all other arrays
	PlayerLifeState[client] = false;
	PlayerHasEnteredStart[client] = false;

	delete FightOrDieTimer[client];
	delete RestoreColorTimer[client];

	RemoveSurvivorModelGlow(client);

	if(g_bCvarAllow == false) return;

	if(!IsFakeClient(client) && L4D_HasPlayerControlledZombies() == false && CheckRealPlayers_InSV(client) == false)
	{
		if (!g_bL4D2Version)
		{
			sb_all_bot_team.SetBool(sb_all_bot_team_default);
		}
		else
		{
			sb_all_bot_game.SetBool(sb_all_bot_game_default);
			allow_all_bot_survivor_team.SetBool(allow_all_bot_survivor_team_default);
		}
	}

	if(roundInProgress == false) { respawnDelay[client] = 0; return;}

	if(GetClientTeam(client) == TEAM_SURVIVORS)
	{
		delete DisplayTimer;
		DisplayTimer = CreateTimer(1.0,Timer_CountSurvivor);
	}

	if(!g_bHasRoundEnded && !g_bInitialSpawn)
	{
		if (GetClientTeam(client) == TEAM_INFECTED && IsPlayerAlive(client))
		{
			int SpawnTime = 0;
			if (L4D_HasPlayerControlledZombies())
			{
				if (IsFakeClient(client))
				{
					if(g_bDisableInfectedBot) return;

					SpawnTime = GetRandomInt(g_iInfectedSpawnTimeMin, g_iInfectedSpawnTimeMax);
					if (g_bAdjustSpawnTimes && g_iMaxPlayerZombies != HumansOnInfected())
						SpawnTime = SpawnTime  - (TrueNumberOfAliveSurvivors() * g_iReducedSpawnTimesOnPlayer);

					if(SpawnTime<=0)
						SpawnTime = 1;
				}
				else
				{
					return;
				}
			}
			else
			{
				SpawnTime = GetRandomInt(g_iInfectedSpawnTimeMin, g_iInfectedSpawnTimeMax);
				if(g_bAdjustSpawnTimes)
				{
					if(IsFakeClient(client))
					{
						SpawnTime = SpawnTime - (TrueNumberOfAliveSurvivors() * g_iReducedSpawnTimesOnPlayer) + (HumansOnInfected() * 3);
						if(SpawnTime <= 0) SpawnTime = 1;
					}
					else
					{
						SpawnTime = g_iInfectedSpawnTimeMin - TrueNumberOfAliveSurvivors() * g_iReducedSpawnTimesOnPlayer + (HumansOnInfected() * 2);
						if(SpawnTime <= 6) SpawnTime = 6;
					}
				}		
			}

			#if DEBUG
				PrintToChatAll("[TS] OnClientDisconnect");
			#endif
			respawnDelay[client] = SpawnTime;
			InfectedBotQueue++;

			if( g_bCoordination && IsPlayerTank(client)) respawnDelay[client] = 0;
			
			for(int i = 1; i <= L4D_MAXPLAYERS; i++)
			{
				if(SpawnInfectedBotTimer[i] == null)
				{
					SpawnInfectedBotTimer[i] = CreateTimer(float(SpawnTime)+0.1, Timer_Spawn_InfectedBot, i);
					break;
				}
			}
		}
	}
}

public Action ScrimmageTimer (Handle timer, int client)
{
	if (client && IsClientInGame(client) && !IsFakeClient(client))
	{
		SetEntProp(client, Prop_Send, "m_scrimmageType", 0);
	}

	return Plugin_Continue;
}

public Action CheckIfBotsNeededLater (Handle timer, int spawn_type)
{
	CheckIfBotsNeeded(spawn_type);

	return Plugin_Continue;
}

void CheckIfBotsNeeded(int spawn_type)
{
	if (g_bHasRoundEnded || !g_bLeftSaveRoom ) return;

	#if DEBUG
		LogMessage("[TS] Checking bots");
	#endif

	// First, we count the infected
	if (L4D_HasPlayerControlledZombies())
	{
		CountInfected();
		// PrintToChatAll("InfectedRealCount: %d, InfectedRealQueue: %d, InfectedBotCount: %d, InfectedBotQueue: %d, g_iMaxPlayerZombies: %d", InfectedRealCount, InfectedRealQueue, InfectedBotCount, InfectedBotQueue, g_iMaxPlayerZombies);
		if ( (InfectedRealCount + InfectedRealQueue + InfectedBotCount + InfectedBotQueue) >= g_iMaxPlayerZombies ) return;
	}
	else
	{
		CountInfected_Coop();
		// PrintToChatAll("InfectedRealCount: %d, InfectedBotCount: %d, InfectedBotQueue: %d, g_iMaxPlayerZombies: %d", InfectedRealCount, InfectedBotCount, InfectedBotQueue, g_iMaxPlayerZombies);
		if ( (InfectedRealCount + InfectedBotCount + InfectedBotQueue) >= g_iMaxPlayerZombies ) return;
	}

	// We need more infected bots
	if (spawn_type == 1)
	{
		#if DEBUG
			LogMessage("[TS] spawn_immediately");
		#endif

		InfectedBotQueue++;
		CreateTimer(0.0, Timer_Spawn_InfectedBot, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	else if (spawn_type == 2 && g_bInitialSpawn) //round start first spawn
	{
		#if DEBUG
			LogMessage("[TS] initial_spawn %.1f", g_fInitialSpawn);
		#endif

		if(g_bInfectedSpawnSameFrame)
		{
			for(int i = 1; i <= g_iMaxPlayerZombies; i++)
			{
				InfectedBotQueue++;
				delete SpawnInfectedBotTimer[i];
				SpawnInfectedBotTimer[i] = CreateTimer(g_fInitialSpawn, Timer_Spawn_InfectedBot, i);
			}
		}
		else
		{
			InfectedBotQueue++;
			delete SpawnInfectedBotTimer[0];
			SpawnInfectedBotTimer[0] = CreateTimer(g_fInitialSpawn, Timer_Spawn_InfectedBot, 0);
		}

		InitialSpawnResetTimer = CreateTimer(g_fInitialSpawn + 5.0, Timer_InitialSpawnReset, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	else if (spawn_type == 0) // server can't find a valid position or director stop
	{
		int SpawnTime = 10;

		#if DEBUG
			LogMessage("[TS] InfectedBotQueue + 1, %d spawntime", SpawnTime);
		#endif

		InfectedBotQueue++;
		for(int i = 0; i <= L4D_MAXPLAYERS; i++)
		{
			if(SpawnInfectedBotTimer[i] == null)
			{
				SpawnInfectedBotTimer[i] = 	CreateTimer(float(SpawnTime), Timer_Spawn_InfectedBot, i);
				break;
			}
		}
	}
	else if (spawn_type == -1) // player change team from infected or switch team to infected
	{
		int SpawnTime = 0;
		if (L4D_HasPlayerControlledZombies())
		{
			SpawnTime = GetRandomInt(g_iInfectedSpawnTimeMin, g_iInfectedSpawnTimeMax);
			if (g_bAdjustSpawnTimes && g_iMaxPlayerZombies != HumansOnInfected()) SpawnTime = SpawnTime  - (TrueNumberOfAliveSurvivors() * g_iReducedSpawnTimesOnPlayer);
		}
		else
		{
			SpawnTime = GetRandomInt(g_iInfectedSpawnTimeMin, g_iInfectedSpawnTimeMax);
			if(g_bAdjustSpawnTimes) SpawnTime = SpawnTime - (TrueNumberOfAliveSurvivors() * g_iReducedSpawnTimesOnPlayer) + (HumansOnInfected() * 3);
		}
		if(SpawnTime < 3) SpawnTime = 3;

		InfectedBotQueue++;
		for(int i = 0; i <= L4D_MAXPLAYERS; i++)
		{
			if(SpawnInfectedBotTimer[i] == null)
			{
				SpawnInfectedBotTimer[i] = 	CreateTimer(float(SpawnTime), Timer_Spawn_InfectedBot, i);
				break;
			}
		}
	}
}

Action Timer_InitialSpawnReset(Handle timer)
{
	g_bInitialSpawn = false;

	InitialSpawnResetTimer = null;
	return Plugin_Continue;
}

void CheckIfBotsNeeded2()
{
	if(!g_bHasRoundEnded && !g_bInitialSpawn && SpawnInfectedBotTimer[0] == null)
	{
		if (L4D_HasPlayerControlledZombies())
		{
			CountInfected();
			if ( (InfectedRealCount + InfectedRealQueue + InfectedBotCount + InfectedBotQueue) < g_iMaxPlayerZombies)
			{
				int SpawnTime = GetRandomInt(g_iInfectedSpawnTimeMin, g_iInfectedSpawnTimeMax);
				if (g_bAdjustSpawnTimes && g_iMaxPlayerZombies != HumansOnInfected()) SpawnTime = SpawnTime  - (TrueNumberOfAliveSurvivors() * g_iReducedSpawnTimesOnPlayer);
				if(SpawnTime < 3) SpawnTime = 3;
				InfectedBotQueue++;

				delete SpawnInfectedBotTimer[0];
				SpawnInfectedBotTimer[0] = CreateTimer(float(SpawnTime), Timer_Spawn_InfectedBot, 0);
			}
		}
		else
		{
			CountInfected_Coop();
			if ( (InfectedRealCount + InfectedBotCount + InfectedBotQueue) < g_iMaxPlayerZombies )
			{
				int SpawnTime = GetRandomInt(g_iInfectedSpawnTimeMin, g_iInfectedSpawnTimeMax);
				if (g_bAdjustSpawnTimes) SpawnTime = SpawnTime  - (TrueNumberOfAliveSurvivors() * g_iReducedSpawnTimesOnPlayer) + (HumansOnInfected() * 3);
				if(SpawnTime < 3) SpawnTime = 3;
				InfectedBotQueue++;

				delete SpawnInfectedBotTimer[0];
				SpawnInfectedBotTimer[0] = CreateTimer(float(SpawnTime), Timer_Spawn_InfectedBot, 0);
			}
		}
	}
}

void CountInfected()
{
	// reset counters
	InfectedBotCount = 0;
	InfectedRealCount = 0;
	InfectedRealQueue = 0;

	// First we count the ammount of infected real players and bots
	for (int i=1;i<=MaxClients;i++)
	{
		// We check if player is in game
		if (!IsClientInGame(i)) continue;

		// Check if client is infected ...
		if (GetClientTeam(i) == TEAM_INFECTED)
		{
			// If player is a bot ...
			if (IsFakeClient(i))
			{
				InfectedBotCount++;
			}
			else
			{
				if(IsPlayerAlive(i)) InfectedRealCount++;
				else InfectedRealQueue++;
			}
		}
	}

}

// Note: This function is also used for coop/survival.
void CountInfected_Coop()
{
	// reset counters
	InfectedBotCount = 0;
	InfectedRealCount = 0;
	InfectedRealQueue = 0;

	// First we count the ammount of infected real players and bots

	for (int i=1;i<=MaxClients;i++)
	{
		// We check if player is in game
		if (!IsClientInGame(i)) continue;

		// Check if client is infected ...
		if (GetClientTeam(i) == TEAM_INFECTED)
		{
			// If player is a bot ...
			if (IsFakeClient(i))
			{
				InfectedBotCount++;
			}
			else
			{
				if(IsPlayerAlive(i)) InfectedRealCount++;
				else InfectedRealQueue++;
			}
		}
	}
}

public void Event_Incap(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!client && !IsClientInGame(client) && GetClientTeam(client) != TEAM_SURVIVORS) return;

	int entity = g_iModelIndex[client];
	if( IsValidEntRef(entity) )
	{
		SetEntProp(entity, Prop_Send, "m_glowColorOverride", 180 + (0 * 256) + (0 * 65536)); //Red
	}
}

public void Event_revive_success(Event event, const char[] name, bool dontBroadcast)
{
	int subject = GetClientOfUserId(event.GetInt("subject"));//被救的那位
	if(!subject && !IsClientInGame(subject) && GetClientTeam(subject) != TEAM_SURVIVORS) return;

	int entity = g_iModelIndex[subject];
	if( IsValidEntRef(entity) )
	{
		SetEntProp(entity, Prop_Send, "m_glowColorOverride", 0 + (180 * 256) + (0 * 65536)); //Green
	}
}

public void Event_ledge_release(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!client && !IsClientInGame(client) && GetClientTeam(client) != TEAM_SURVIVORS) return;

	int entity = g_iModelIndex[client];
	if( IsValidEntRef(entity) )
	{
		SetEntProp(entity, Prop_Send, "m_glowColorOverride", 0 + (180 * 256) + (0 * 65536)); //Green
	}
}

public void Event_GotVomit(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!client && !IsClientInGame(client) && GetClientTeam(client) != TEAM_SURVIVORS) return;

	int entity = g_iModelIndex[client];
	if( IsValidEntRef(entity) )
	{
		SetEntProp(entity, Prop_Send, "m_glowColorOverride", 155 + (0 * 256) + (180 * 65536)); //Purple

		delete RestoreColorTimer[client]; RestoreColorTimer[client] = CreateTimer(20.0, Timer_RestoreColor, client);
	}
}

public Action Timer_RestoreColor(Handle timer, int client)
{
	int entity = g_iModelIndex[client];
	if( IsValidEntRef(entity) )
	{
		if(IsplayerIncap(client)) SetEntProp(entity, Prop_Send, "m_glowColorOverride", 180 + (0 * 256) + (0 * 65536)); //RGB
		else SetEntProp(entity, Prop_Send, "m_glowColorOverride", 0 + (180 * 256) + (0 * 65536)); //RGB
	}
	RestoreColorTimer[client] = null;

	return Plugin_Continue;
}

Action KickWitch_Timer(Handle timer, int ref)
{
	if( g_bCvarAllow == false) return Plugin_Continue;

	if(IsValidEntRef(ref))
	{
		int entity = EntRefToEntIndex(ref);
		bool bKill = true;
		float clientOrigin[3];
		float witchOrigin[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", witchOrigin);
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS && IsPlayerAlive(i))
			{
				GetClientAbsOrigin(i, clientOrigin);
				if (GetVectorDistance(clientOrigin, witchOrigin, true) < Pow(1500.0, 2.0))
				{
					bKill = false;
					break;
				}
			}
		}

		if(bKill) AcceptEntityInput(ref, "kill"); //remove witch
		else CreateTimer(g_fWitchKillTime,KickWitch_Timer,EntIndexToEntRef(entity),TIMER_FLAG_NO_MAPCHANGE);
	}

	return Plugin_Continue;
}
// The main Tank code, it allows a player to take over the tank when if allowed, and adds additional tanks if the tanks per spawn cvar was set.
public Action TankSpawner(Handle timer, int tank)
{
	if( g_bCvarAllow == false)
	{
		TankReplacing = false;
		return Plugin_Continue;
	}

	#if DEBUG
	LogMessage("Tank Spawner Triggred");
	#endif
	int Index[9];
	int IndexCount = 0;
	bool tankonfire;

	if (tank && IsClientInGame(tank))
	{
		if (GetEntProp(tank, Prop_Data, "m_fFlags") & FL_ONFIRE && IsPlayerAlive(tank))
			tankonfire = true;
	}
	else return Plugin_Continue;

	for (int t=1;t<=MaxClients;t++)
	{
		// We check if player is in game
		if (!IsClientInGame(t)) continue;

		// Check if client is infected ...
		if (GetClientTeam(t)!=TEAM_INFECTED) continue;

		if (IsFakeClient(t)) continue;

		if (IsPlayerTank(t)) continue;

		Index[IndexCount++] = t; //save target to index
		#if DEBUG
			PrintToChatAll("[TS] Client %i found to be valid Tank Choice", Index[IndexCount]);
		#endif
	}

	if (IndexCount > 0 )
	{
		int target = Index[GetRandomInt(0, IndexCount-1)];  // pick someone from the valid targets

		if(IsPlayerAlive(target) && !IsPlayerGhost(target))
		{
			if (g_bL4D2Version && IsPlayerJockey(target))
			{
				// WE NEED TO DISMOUNT THE JOCKEY OR ELSE BAAAAAAAAAAAAAAAD THINGS WILL HAPPEN
				CheatCommand(target, "dismount");
			}
			L4D_ReplaceWithBot(target);
		}

		if (!g_bL4D2Version) //hunter tank bug in l4d1
		{
			ChangeClientTeam(target, TEAM_SPECTATOR);
			ChangeClientTeam(target, TEAM_INFECTED);
		}

		L4D_ReplaceTank(tank, target);

		if (tankonfire)
			IgniteEntity(target, IGNITE_TIME);
	}

	TankReplacing = false;
	return Plugin_Continue;
}

public void evtBotReplacedPlayer(Event event, const char[] name, bool dontBroadcast) 
{
	if(L4D_HasPlayerControlledZombies() == false) //not versus
	{
		int bot = GetClientOfUserId(event.GetInt("bot"));
		int playerid = event.GetInt("player");
		int player = GetClientOfUserId(playerid);

		if (bot > 0 && bot <= MaxClients && IsClientInGame(bot) && 
			player > 0 && player <= MaxClients && IsClientInGame(player)) 
		{
			if(IsPlayerTank(bot) && IsFakeClient(bot) && !IsFakeClient(player) && playerid == lastHumanTankId)
			{
				ForcePlayerSuicide(player);
				KickClient(bot, "Pass Tank to AI");

				PrintHintText(player, "[TS] %T", "You don't attack survivors", player);
			}
		}
	}
}

void OnTankFrustrated(Event event, const char[] name, bool dontBroadcast)
{
	lastHumanTankId = event.GetInt("userid");
	RequestFrame(OnNextFrame_Reset);
}

void OnNextFrame_Reset()
{
	lastHumanTankId = 0;
}

public Action L4D_OnEnterGhostStatePre(int client)
{
	if (lastHumanTankId && GetClientUserId(client) == lastHumanTankId)
	{
		lastHumanTankId = 0;
		L4D_State_Transition(client, STATE_DEATH_ANIM);
		
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action TankBugFix(Handle timer, int client)
{
	#if DEBUG
	LogMessage("Tank BugFix Triggred");
	#endif

	if (IsClientInGame(client) && IsFakeClient(client) && GetClientTeam(client) == 3)
	{
		int lifestate = GetEntData(client, FindSendPropInfo("CTerrorPlayer", "m_lifeState"));
		if (lifestate == 0)
		{
			int bot = SDKCall(hCreateTank, "Tank Bot"); //召喚坦克
			if (bot > 0 && IsValidClient(bot))
			{
				#if DEBUG
					PrintToChatAll("[TS] Ghost BugFix");
				#endif
				SetEntityModel(bot, MODEL_TANK);
				ChangeClientTeam(bot, TEAM_INFECTED);
				//SDKCall(hRoundRespawn, bot);
				SetEntProp(bot, Prop_Send, "m_usSolidFlags", 16);
				SetEntProp(bot, Prop_Send, "movetype", 2);
				SetEntProp(bot, Prop_Send, "deadflag", 0);
				SetEntProp(bot, Prop_Send, "m_lifeState", 0);
				//SetEntProp(bot, Prop_Send, "m_fFlags", 129);
				SetEntProp(bot, Prop_Send, "m_iObserverMode", 0);
				SetEntProp(bot, Prop_Send, "m_iPlayerState", 0);
				SetEntProp(bot, Prop_Send, "m_zombieState", 0);
				DispatchSpawn(bot);
				ActivateEntity(bot);

				float Origin[3], Angles[3];
				GetClientAbsOrigin(client, Origin);
				GetClientAbsAngles(client, Angles);
				KickClient(client);
				TeleportEntity(bot, Origin, Angles, NULL_VECTOR); //移動到相同位置
			}
		}
	}

	return Plugin_Continue;
}

public Action PutTankOnFireTimer(Handle Timer, int client)
{
	if(client && IsClientInGame(client) && GetClientTeam(client) == TEAM_INFECTED)
		IgniteEntity(client, 9999.0);

	return Plugin_Continue;
}

public Action HookSound_Callback(int Clients[64], int &NumClients, char StrSample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level,
	int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if (g_iCurrentMode != 1 || !g_bCoopPlayableTank)
		return Plugin_Continue;

	//to work only on tank steps, its Tank_walk
	if (StrContains(StrSample, "Tank_walk", false) == -1) return Plugin_Continue;

	for (int i=1;i<=MaxClients;i++)
	{
		// We check if player is in game
		if (!IsClientInGame(i)) continue;

		// Check if client is infected ...
		if (GetClientTeam(i)==TEAM_INFECTED)
		{
			// If player is a tank
			if (IsPlayerTank(i) && IsPlayerAlive(i) && IsFakeClient(i) && TankReplacing == false)
			{
				if (AreTherePlayersWhoAreNotTanks())
				{
					TankReplacing = true;
					CreateTimer(0.1, TankSpawner, i, TIMER_FLAG_NO_MAPCHANGE);
					CreateTimer(0.5, kickbot, GetClientUserId(i), TIMER_FLAG_NO_MAPCHANGE);
				}
			}
		}
	}
	return Plugin_Continue;
}


// This event serves to make sure the bots spawn at the start of the finale event. The director disallows spawning until the survivors have started the event, so this was
// definitely needed.
public void evtFinaleStart(Event event, const char[] name, bool dontBroadcast)
{
	if(g_bFinaleStarted) return;

	g_bFinaleStarted = true;
	CreateTimer(1.0, CheckIfBotsNeededLater, 2, TIMER_FLAG_NO_MAPCHANGE);
}

int BotTypeNeeded()
{
	// current count ...
	for (int i = 0; i < NUM_TYPES_INFECTED_MAX; i++)
		g_iSpawnCounts[i] = 0;

	for (int i=1;i<=MaxClients;i++)
	{
		// if player is connected and ingame ...
		if (IsClientInGame(i))
		{
			// if player is on infected's team
			if (GetClientTeam(i) == TEAM_INFECTED && IsPlayerAlive(i))
			{
				// We count depending on class ...
				if (IsPlayerSmoker(i))
					g_iSpawnCounts[SI_SMOKER]++;
				else if (IsPlayerBoomer(i))
					g_iSpawnCounts[SI_BOOMER]++;
				else if (IsPlayerHunter(i))
					g_iSpawnCounts[SI_HUNTER]++;
				else if (IsPlayerTank(i))
					g_iSpawnCounts[SI_TANK]++;
				else if (g_bL4D2Version && IsPlayerSpitter(i))
					g_iSpawnCounts[SI_SPITTER]++;
				else if (g_bL4D2Version && IsPlayerJockey(i))
					g_iSpawnCounts[SI_JOCKEY]++;
				else if (g_bL4D2Version && IsPlayerCharger(i))
					g_iSpawnCounts[SI_CHARGER]++;
			}
		}
	}

	if  (g_bL4D2Version)
	{
		if ( ( (g_bFinaleStarted && g_bTankSpawnFinal == true) || !g_bFinaleStarted ) &&
			g_iSpawnCounts[SI_TANK] < g_iTankLimit &&
			GetRandomInt(1, 100) <= g_iSpawnTankProbability) 
		{
			#if DEBUG
			LogMessage("Bot type returned Tank");
			#endif
			return 7;
		}
		else //spawn other S.I.
		{
			/*int random = GetRandomInt(1, 6);
			int i=0;
			while(i++<5)
			{
				if (random == 1)
				{
					if (smokers < g_iSmokerLimit)
					{
						#if DEBUG
						LogMessage("Bot type returned Smoker");
						#endif
						return 1;
					}
					random++;
				}
				if (random == 2)
				{
					if (boomers < g_iBoomerLimit)
					{
						#if DEBUG
						LogMessage("Bot type returned Boomer");
						#endif
						return 2;
					}
					random++;
				}
				if (random == 3)
				{
					if (hunters < g_iHunterLimit)
					{
						#if DEBUG
						LogMessage("Bot type returned Hunter");
						#endif
						return 3;
					}
					random++;
				}
				if (random == 4)
				{
					if (spitters < g_iSpitterLimit)
					{
						#if DEBUG
						LogMessage("Bot type returned Spitter");
						#endif
						return 4;
					}
					random++;
				}
				if (random == 5)
				{
					if (jockeys < g_iJockeyLimit)
					{
						#if DEBUG
						LogMessage("Bot type returned Jockey");
						#endif
						return 5;
					}
					random++;
				}
				if (random == 6)
				{
					if (chargers < g_iChargerLimit)
					{
						#if DEBUG
						LogMessage("Bot type returned Charger");
						#endif
						return 6;
					}
					random = 1;
				}
			}*/

			return GenerateIndex()+1;
		}
	}
	else
	{
		if ( ( (g_bFinaleStarted && g_bTankSpawnFinal == true) || !g_bFinaleStarted ) &&
			g_iSpawnCounts[SI_TANK] < g_iTankLimit) 
		{
			#if DEBUG
			LogMessage("Bot type returned Tank");
			#endif
			return 7;
		}
		else
		{
			/*int random = GetRandomInt(1, 3);

			int i=0;
			while(i++<10)
			{
				if (random == 1)
				{
					if (smokers < g_iSmokerLimit)
					{
						#if DEBUG
						LogMessage("Returning Smoker");
						#endif
						return 1;
					}
					random++;
				}
				if (random == 2)
				{
					if (boomers < g_iBoomerLimit)
					{
						#if DEBUG
						LogMessage("Bot type returned Boomer");
						#endif
						return 2;
					}
					random++;
				}
				if (random == 3)
				{
					if (hunters < g_iHunterLimit)
					{
						#if DEBUG
						LogMessage("Bot type returned Hunter");
						#endif
						return 3;
					}
					random=1;
				}
			}
			*/
			return GenerateIndex()+1;
		}
	}
}

public Action Timer_Spawn_InfectedBot(Handle timer, int index)
{
	// If round has ended, we ignore this request ...
	if (g_bCvarAllow == false || g_bHasRoundEnded || !g_bLeftSaveRoom )
	{
		if(InfectedBotQueue > 0) InfectedBotQueue--;

		SpawnInfectedBotTimer[index] = null;
		return Plugin_Continue;
	}

	//PrintToChatAll("[TS] Spawn_InfectedBot(Handle timer)");

	if (g_bCoordination && !g_bInitialSpawn && g_bIsCoordination == false)
	{
		g_iCoordinationBotReady++;

		if(g_iCoordinationBotReady < g_iMaxPlayerZombies)
		{
			for (int i=1;i<=MaxClients;i++)
			{
				if(respawnDelay[i] > 0)
				{
					if(InfectedBotQueue > 0) InfectedBotQueue--;

					SpawnInfectedBotTimer[index] = null;
					return Plugin_Continue;
				}
			}
		}

		g_bIsCoordination = true;
	}

	// First we get the infected count
	if (L4D_HasPlayerControlledZombies())
	{
		if(g_bDisableInfectedBot)
		{
			if(InfectedBotQueue > 0) InfectedBotQueue--;

			SpawnInfectedBotTimer[index] = null;
			return Plugin_Continue;
		}

		CountInfected();

		// PrintToChatAll("InfectedRealCount: %d, InfectedRealQueue: %d, InfectedBotCount: %d, g_iMaxPlayerZombies: %d", InfectedRealCount, InfectedRealQueue, InfectedBotCount, g_iMaxPlayerZombies);
		if ((InfectedRealCount + InfectedRealQueue + InfectedBotCount) >= g_iMaxPlayerZombies)
		{
			#if DEBUG
				LogMessage("versus team is already full, don't spawn a bot");
			#endif
			InfectedBotQueue = 0;

			SpawnInfectedBotTimer[index] = null;
			return Plugin_Continue;
		}
	}
	else
	{
		CountInfected_Coop();

		//PrintToChatAll("InfectedRealCount: %d, InfectedBotCount: %d, g_iMaxPlayerZombies: %d", InfectedRealCount, InfectedBotCount, g_iMaxPlayerZombies);
		if ((InfectedRealCount + InfectedBotCount) >= g_iMaxPlayerZombies)
		{
			#if DEBUG
				LogMessage("coop team is already full, don't spawn a bot");
			#endif
			InfectedBotQueue = 0;

			SpawnInfectedBotTimer[index] = null;
			return Plugin_Continue;
		}
	}

	// If there is a tank on the field and l4d_infectedbots_spawns_disable_tank is set to 1, the plugin will check for
	// any tanks on the field

	if (g_bDisableSpawnsTank)
	{
		for (int i=1;i<=MaxClients;i++)
		{
			// We check if player is in game
			if (!IsClientInGame(i)) continue;

			// Check if client is infected ...
			if (GetClientTeam(i)==TEAM_INFECTED)
			{
				// If player is a tank
				if (IsPlayerTank(i) && IsPlayerAlive(i) && ( g_iCurrentMode != 1 || !IsFakeClient(i) || (IsFakeClient(i) && g_bAngry[i]) ) )
				{
					if(InfectedBotQueue>0) InfectedBotQueue--;

					SpawnInfectedBotTimer[index] = null;
					return Plugin_Continue;
				}
			}
		}

	}

	// Official Cvar: director_no_specials is 1 => Disable PZ spawns
	if(director_no_specials_bool == true)
	{
		PrintToServer("[TS] Couldn't spawn due to director_no_specials 1.");
		CreateTimer(20.0, CheckIfBotsNeededLater, 0, TIMER_FLAG_NO_MAPCHANGE);

		if(InfectedBotQueue > 0) InfectedBotQueue--;
		
		SpawnInfectedBotTimer[index] = null;
		return Plugin_Continue;
	}

	// Before spawning the bot, we determine if an real infected player is dead, since the int infected bot will be controlled by this player
	bool resetGhost[MAXPLAYERS+1];
	bool resetLife[MAXPLAYERS+1];
	bool binfectedfreeplayer = false;
	int human = 0;
	for (int i=1;i<=MaxClients;i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i)) // player is connected and is not fake and it's in game ...
		{
			// If player is on infected's team and is dead ..
			if (GetClientTeam(i) == TEAM_INFECTED)
			{
				// If player is a ghost ....
				if (IsPlayerGhost(i))
				{
					resetGhost[i] = true;
					SetGhostStatus(i, false);
				}
				else if (!IsPlayerAlive(i) && L4D_HasPlayerControlledZombies()) // if player is just dead
				{
					resetLife[i] = true;
					SetLifeState(i, false);
				}
				else if (!IsPlayerAlive(i) && respawnDelay[i] > 0)
				{
					resetLife[i] = true;
					SetLifeState(i, false);
				}
				else if (!IsPlayerAlive(i) && respawnDelay[i] <= 0 && human == 0)
				{
					SetLifeState(i, true);
					binfectedfreeplayer = true;
					human = i;
				}
			}
		}
	}

	// We get client ....
	int anyclient;
	if(g_iWhereToSpawnInfected == 0) anyclient = GetAheadSurvivor();
	else anyclient = GetRandomAliveSurvivor();
	if(anyclient == 0)
	{
		PrintToServer("[TS] Couldn't find a valid alive survivor to spawn S.I. at this moment.",ZOMBIESPAWN_Attempts);
		CreateTimer(1.0, CheckIfBotsNeededLater, g_bInitialSpawn ? 2: g_bIsCoordination? 1: 0, TIMER_FLAG_NO_MAPCHANGE);

		if(InfectedBotQueue > 0) InfectedBotQueue--;
		
		SpawnInfectedBotTimer[index] = null;
		return Plugin_Continue;
	}

	int loop_max = 1;
	if(g_bIsCoordination && g_bInfectedSpawnSameFrame)
	{
		loop_max = g_iMaxPlayerZombies;
	}

	for(int loop = 1; loop <= loop_max; loop++)
	{
		// Determine the bot class needed ...
		int bot_type = BotTypeNeeded();

		if (binfectedfreeplayer)
		{
			// We spawn the bot ...
			if(g_bCoopInfectedPlayerGhostState)
			{
				switch (bot_type)
				{
					case 0: // Nothing
					{
					}
					case 1: // Smoker
					{
						L4D_SetClass(human, ZOMBIECLASS_SMOKER);
						L4D_State_Transition(human, STATE_GHOST);
					}
					case 2: // Boomer
					{
						L4D_SetClass(human, ZOMBIECLASS_BOOMER);
						L4D_State_Transition(human, STATE_GHOST);
					}
					case 3: // Hunter
					{
						L4D_SetClass(human, ZOMBIECLASS_HUNTER);
						L4D_State_Transition(human, STATE_GHOST);
					}
					case 4: // Spitter
					{
						L4D_SetClass(human, ZOMBIECLASS_SPITTER);
						L4D_State_Transition(human, STATE_GHOST);
					}
					case 5: // Jockey
					{
						L4D_SetClass(human, ZOMBIECLASS_JOCKEY);
						L4D_State_Transition(human, STATE_GHOST);
					}
					case 6: // Charger
					{
						L4D_SetClass(human, ZOMBIECLASS_CHARGER);
						L4D_State_Transition(human, STATE_GHOST);
					}
					case 7: // Tank
					{
						CheatCommand(anyclient, sSpawnCommand, "tank auto");
					}
				}
			}
			else
			{
				switch (bot_type)
				{
					case 0: // Nothing
					{
					}
					case 1: // Smoker
					{
						CheatCommand(anyclient, sSpawnCommand, "smoker auto");
					}
					case 2: // Boomer
					{
						CheatCommand(anyclient, sSpawnCommand, "boomer auto");
					}
					case 3: // Hunter
					{
						CheatCommand(anyclient, sSpawnCommand, "hunter auto");
					}
					case 4: // Spitter
					{
						CheatCommand(anyclient, sSpawnCommand, "spitter auto");
					}
					case 5: // Jockey
					{
						CheatCommand(anyclient, sSpawnCommand, "jockey auto");
					}
					case 6: // Charger
					{
						CheatCommand(anyclient, sSpawnCommand, "charger auto");
					}
					case 7: // Tank
					{
						CheatCommand(anyclient, sSpawnCommand, "tank auto");
					}
				}
			}

			if(IsPlayerAlive(human))
			{
				if(g_iCoordinationBotReady > 0) g_iCoordinationBotReady--;
				CreateTimer(0.0, CheckIfBotsNeededLater, 1, TIMER_FLAG_NO_MAPCHANGE);
			}
			else
			{
				CreateTimer(0.1, CheckIfBotsNeededLater, 0, TIMER_FLAG_NO_MAPCHANGE);
			}
		}
		else
		{
			bool bSpawnSuccessful = false;
			float vecPos[3];
			// We spawn the bot ...
			int bot;
			switch (bot_type)
			{
				case 0: // Nothing
				{
				}
				case 1: // Smoker
				{
					if(L4D_GetRandomPZSpawnPosition(anyclient,ZOMBIECLASS_SMOKER,ZOMBIESPAWN_Attempts,vecPos) == true)
					{
						bot = SDKCall(hCreateSmoker, "Smoker Bot");
						if (IsValidClient(bot))
						{
							SetEntityModel(bot, MODEL_SMOKER);
							bSpawnSuccessful = true;
						}
					}
					else
					{
						PrintToServer("[TS] Couldn't find a Smoker Spawn position in %d tries",ZOMBIESPAWN_Attempts);
					}
				}
				case 2: // Boomer
				{
					if(L4D_GetRandomPZSpawnPosition(anyclient,ZOMBIECLASS_BOOMER,ZOMBIESPAWN_Attempts,vecPos) == true)
					{
						bot = SDKCall(hCreateBoomer, "Boomer Bot");
						if (IsValidClient(bot))
						{
							SetEntityModel(bot, MODEL_BOOMER);
							bSpawnSuccessful = true;
						}
					}
					else
					{
						PrintToServer("[TS] Couldn't find a Boomer Spawn position in %d tries",ZOMBIESPAWN_Attempts);
					}
				}
				case 3: // Hunter
				{
					if(L4D_GetRandomPZSpawnPosition(anyclient,ZOMBIECLASS_HUNTER,ZOMBIESPAWN_Attempts,vecPos) == true)
					{
						bot = SDKCall(hCreateHunter, "Hunter Bot");
						if (IsValidClient(bot))
						{
							SetEntityModel(bot, MODEL_HUNTER);
							bSpawnSuccessful = true;
						}
					}
					else
					{
						PrintToServer("[TS] Couldn't find a Hunter Spawn position in %d tries",ZOMBIESPAWN_Attempts);
					}
				}
				case 4: // Spitter
				{
					if(L4D_GetRandomPZSpawnPosition(anyclient,ZOMBIECLASS_SPITTER,ZOMBIESPAWN_Attempts,vecPos) == true)
					{
						bot = SDKCall(hCreateSpitter, "Spitter Bot");
						if (IsValidClient(bot))
						{
							SetEntityModel(bot, MODEL_SPITTER);
							bSpawnSuccessful = true;
						}
					}
					else
					{
						PrintToServer("[TS] Couldn't find a Spitter Spawn position in %d tries",ZOMBIESPAWN_Attempts);
					}
				}
				case 5: // Jockey
				{
					if(L4D_GetRandomPZSpawnPosition(anyclient,ZOMBIECLASS_JOCKEY,ZOMBIESPAWN_Attempts,vecPos) == true)
					{
						bot = SDKCall(hCreateJockey, "Jockey Bot");
						if (IsValidClient(bot))
						{
							SetEntityModel(bot, MODEL_JOCKEY);
							bSpawnSuccessful = true;
						}
					}
					else
					{
						PrintToServer("[TS] Couldn't find a Jockey Spawn position in %d tries",ZOMBIESPAWN_Attempts);
					}
				}
				case 6: // Charger
				{
					if(L4D_GetRandomPZSpawnPosition(anyclient,ZOMBIECLASS_CHARGER,ZOMBIESPAWN_Attempts,vecPos) == true)
					{
						bot = SDKCall(hCreateCharger, "Charger Bot");
						if (IsValidClient(bot))
						{
							SetEntityModel(bot, MODEL_CHARGER);
							bSpawnSuccessful = true;
						}
					}
					else
					{
						PrintToServer("[TS] Couldn't find a Charger Spawn position in %d tries",ZOMBIESPAWN_Attempts);
					}
				}
				case 7: // Tank
				{
					if(L4D_GetRandomPZSpawnPosition(anyclient,ZOMBIECLASS_TANK,ZOMBIESPAWN_Attempts,vecPos) == true)
					{
						bot = SDKCall(hCreateTank, "Tank Bot");
						if (IsValidClient(bot))
						{
							SetEntityModel(bot, MODEL_TANK);
							bSpawnSuccessful = true;
						}
					}
					else
					{
						PrintToServer("[TS] Couldn't find a Tank Spawn position in %d tries",ZOMBIESPAWN_Attempts);
					}
				}
			}

			if (bSpawnSuccessful && IsValidClient(bot))
			{
				ChangeClientTeam(bot, 3);
				SetEntProp(bot, Prop_Send, "m_usSolidFlags", 16);
				SetEntProp(bot, Prop_Send, "movetype", 2);
				SetEntProp(bot, Prop_Send, "deadflag", 0);
				SetEntProp(bot, Prop_Send, "m_lifeState", 0);
				SetEntProp(bot, Prop_Send, "m_iObserverMode", 0);
				SetEntProp(bot, Prop_Send, "m_iPlayerState", 0);
				SetEntProp(bot, Prop_Send, "m_zombieState", 0);
				DispatchSpawn(bot);
				ActivateEntity(bot);
				TeleportEntity(bot, vecPos, NULL_VECTOR, NULL_VECTOR); //移動到相同位置

				if(g_iCoordinationBotReady > 0) g_iCoordinationBotReady--;
				CreateTimer(0.05, CheckIfBotsNeededLater, 1, TIMER_FLAG_NO_MAPCHANGE);
			}
			else
			{
				CreateTimer(0.1, CheckIfBotsNeededLater, 0, TIMER_FLAG_NO_MAPCHANGE);
			}
		}

		if(g_iCoordinationBotReady == 0) g_bIsCoordination = false;

		// We restore the player's status
		for (int i=1;i<=MaxClients;i++)
		{
			if (resetGhost[i] == true)
				SetGhostStatus(i, true);
			if (resetLife[i] == true)
				SetLifeState(i, true);
		}

		// Debug print
		#if DEBUG
			PrintToChatAll("[TS] Spawning an infected bot. Type = %i ", bot_type);
		#endif

		// We decrement the infected queue
		if(InfectedBotQueue>0) InfectedBotQueue--;
	}

	SpawnInfectedBotTimer[index] = null;
	return Plugin_Continue;
}

public Action kickbot(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (client && IsClientInGame(client) && IsFakeClient(client) && !IsClientInKickQueue(client) )
	{
		KickClient(client);
	}

	return Plugin_Continue;
}

bool IsPlayerGhost (int client)
{
	if (GetEntProp(client, Prop_Send, "m_isGhost"))
		return true;
	return false;
}

bool IsPlayerSmoker (int client)
{
	if(GetEntProp(client,Prop_Send,"m_zombieClass") == ZOMBIECLASS_SMOKER)
		return true;
	return false;
}

bool IsPlayerHunter (int client)
{
	if(GetEntProp(client,Prop_Send,"m_zombieClass") == ZOMBIECLASS_HUNTER)
		return true;
	return false;
}

bool IsPlayerBoomer (int client)
{
	if(GetEntProp(client,Prop_Send,"m_zombieClass") == ZOMBIECLASS_BOOMER)
		return true;
	return false;
}

bool IsPlayerSpitter (int client)
{
	if(GetEntProp(client,Prop_Send,"m_zombieClass") == ZOMBIECLASS_SPITTER)
		return true;
	return false;
}

bool IsPlayerJockey (int client)
{
	if(GetEntProp(client,Prop_Send,"m_zombieClass") == ZOMBIECLASS_JOCKEY)
		return true;
	return false;
}

bool IsPlayerCharger (int client)
{
	if(GetEntProp(client,Prop_Send,"m_zombieClass") == ZOMBIECLASS_CHARGER)
		return true;
	return false;
}

bool IsPlayerTank (int client)
{
	if(GetEntProp(client,Prop_Send,"m_zombieClass") == ZOMBIECLASS_TANK)
		return true;
	return false;
}

void SetGhostStatus (int client, bool ghost)
{
	if (ghost)
		SetEntProp(client, Prop_Send, "m_isGhost", 1, 1);
	else
		SetEntProp(client, Prop_Send, "m_isGhost", 0, 1);
}

void SetLifeState (int client, bool ready)
{
	if (ready)
		SetEntProp(client, Prop_Send,  "m_lifeState", 1, 1);
	else
		SetEntProp(client, Prop_Send, "m_lifeState", 0, 1);
}

bool RealPlayersOnSurvivors ()
{
	for (int i=1;i<=MaxClients;i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
			if (GetClientTeam(i) == TEAM_SURVIVORS)
				return true;
		}
	return false;
}

int TrueNumberOfSurvivors ()
{
	int TotalSurvivors;
	for (int i=1;i<=MaxClients;i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS)
				TotalSurvivors++;
	}
	return TotalSurvivors;
}

int TrueNumberOfAliveSurvivors ()
{
	int TotalSurvivors;
	for (int i=1;i<=MaxClients;i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS && IsPlayerAlive(i))
				TotalSurvivors++;
	}
	return TotalSurvivors;
}

int HumansOnInfected ()
{
	int TotalHumans;
	for (int i=1;i<=MaxClients;i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED && !IsFakeClient(i))
			TotalHumans++;
	}
	return TotalHumans;
}

bool AllSurvivorsDeadOrIncapacitated ()
{
	int PlayerIncap;
	int PlayerDead;

	for (int i=1;i<=MaxClients;i++)
	{
		if (IsClientInGame(i) && IsFakeClient(i))
			if (GetClientTeam(i) == TEAM_SURVIVORS)
		{
			if (GetEntProp(i, Prop_Send, "m_isIncapacitated"))
			{
				PlayerIncap++;
			}
			else if (!IsPlayerAlive(i))
			{
				PlayerDead++;
			}
		}
	}

	if (PlayerIncap + PlayerDead == TrueNumberOfSurvivors())
	{
		return true;
	}
	return false;
}

bool RealPlayersOnInfected ()
{
	for (int i=1;i<=MaxClients;i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
			if (GetClientTeam(i) == TEAM_INFECTED)
				return true;
		}
	return false;
}

bool AreTherePlayersWhoAreNotTanks ()
{
	for (int i=1;i<=MaxClients;i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			if (GetClientTeam(i) == TEAM_INFECTED)
			{
				if (!IsPlayerTank(i) || IsPlayerTank(i) && !IsPlayerAlive(i))
					return true;
			}
		}
	}
	return false;
}

stock bool BotsAlive ()
{
	for (int i=1;i<=MaxClients;i++)
	{
		if (IsClientInGame(i) && IsFakeClient(i))
			if (GetClientTeam(i) == TEAM_INFECTED)
				return true;
		}
	return false;
}

int  FindBotToTakeOver()
{
	// First we find a survivor bot
	for (int i=1;i<=MaxClients;i++)
	{
		// We check if player is in game
		if (!IsClientInGame(i)) continue;

		// Check if client is survivor ...
		if (GetClientTeam(i) == TEAM_SURVIVORS)
		{
			// If player is a bot and is alive...
			if (IsFakeClient(i) && IsPlayerAlive(i))
			{
				return i;
			}
		}
	}
	return 0;
}

//---------------------------------------------Durzel's HUD------------------------------------------

public void OnPluginEnd()
{
	g_bFirstRecord = false;

	g_iPlayerSpawn = 0;

	for( int i = 1; i <= MaxClients; i++ )
	{
		RemoveSurvivorModelGlow(i);
		DeleteLight(i);
	}

	if (g_bL4D2Version)
	{
		ResetConVar(FindConVar("survival_max_smokers"), true, true);
		ResetConVar(FindConVar("survival_max_boomers"), true, true);
		ResetConVar(FindConVar("survival_max_hunters"), true, true);
		ResetConVar(FindConVar("survival_max_spitters"), true, true);
		ResetConVar(FindConVar("survival_max_jockeys"), true, true);
		ResetConVar(FindConVar("survival_max_chargers"), true, true);
		ResetConVar(FindConVar("survival_max_specials"), true, true);
		ResetConVar(FindConVar("survival_tank_stage_interval"), true, true);
		ResetConVar(FindConVar("survival_special_limit_increase"), true, true);
		ResetConVar(FindConVar("survival_special_spawn_interval"), true, true);
		ResetConVar(FindConVar("survival_special_stage_interval"), true, true);

		ResetConVar(FindConVar("z_smoker_limit"), true, true);
		ResetConVar(FindConVar("z_boomer_limit"), true, true);
		ResetConVar(FindConVar("z_hunter_limit"), true, true);
		ResetConVar(FindConVar("z_spitter_limit"), true, true);
		ResetConVar(FindConVar("z_jockey_limit"), true, true);
		ResetConVar(FindConVar("z_charger_limit"), true, true);
	}
	else
	{
		ResetConVar(FindConVar("holdout_max_smokers"), true, true);
		ResetConVar(FindConVar("holdout_max_boomers"), true, true);
		ResetConVar(FindConVar("holdout_max_hunters"), true, true);
		ResetConVar(FindConVar("holdout_max_specials"), true, true);
		ResetConVar(FindConVar("holdout_tank_stage_interval"), true, true);
		ResetConVar(FindConVar("holdout_special_spawn_interval"), true, true);
		ResetConVar(FindConVar("holdout_special_stage_interval"), true, true);

		ResetConVar(FindConVar("z_gas_limit"), true, true);
		ResetConVar(FindConVar("z_exploding_limit"), true, true);
		ResetConVar(FindConVar("z_hunter_limit"), true, true);
	}
	//ResetConVar(FindConVar("z_attack_flow_range"), true, true);
	//ResetConVar(FindConVar("director_spectate_specials"), true, true);
	ResetConVar(FindConVar("z_spawn_safety_range"), true, true);
	//ResetConVar(FindConVar("z_spawn_range"), true, true);
	if(g_bL4D2Version)
	{
		//ResetConVar(FindConVar("z_finale_spawn_tank_safety_range"), true, true);
		//ResetConVar(FindConVar("z_finale_spawn_mob_safety_range"), true, true);
		ResetConVar(director_allow_infected_bots, true, true);
	}
	//ResetConVar(FindConVar("z_spawn_flow_limit"), true, true);
	if(g_bTankHealthAdjust) ResetConVar(cvarZombieHP[6], true, true);
	if(g_bCommonLimitAdjust) ResetConVar(h_common_limit_cvar, true, true);
	vs_max_team_switches.SetInt(vs_max_team_switches_default);
	if (!g_bL4D2Version)
	{
		sb_all_bot_team.SetBool(sb_all_bot_team_default);
	}
	else
	{
		sb_all_bot_game.SetBool(sb_all_bot_game_default);
		allow_all_bot_survivor_team.SetBool(allow_all_bot_survivor_team_default);
	}
	if(g_bL4D2Version)
	{
		static char mode[64];
		g_hCvarMPGameMode.GetString(mode, sizeof(mode));
		for( int i = 1; i <= MaxClients; i++ )
			if(IsClientInGame(i) && !IsFakeClient(i)) SendConVarValue(i, g_hCvarMPGameMode, mode);
	}
	// Destroy the persistent storage for client HUD preferences
	delete usrHUDPref;
}

public int Menu_InfHUDPanel(Menu menu, MenuAction action, int param1, int param2) { return 0; }

public Action TimerAnnounce(Handle timer, int client)
{
	if (IsClientInGame(client))
	{
		if (GetClientTeam(client) == TEAM_INFECTED)
		{
			// Show welcoming instruction message to client
			PrintHintText(client, "%t","Hud INFO", PLUGIN_VERSION);

			// This client now knows about the mod, don't tell them again for the rest of the game.
			clientGreeted[client] = 1;
		}
	}

	return Plugin_Continue;
}

public Action TimerAnnounce2(Handle timer, int client)
{
	if (IsClientInGame(client))
	{
		if (GetClientTeam(client) == TEAM_INFECTED && IsPlayerAlive(client) && !IsPlayerGhost(client))
		{
			C_PrintToChat(client, "[{olive}TS{default}] %T","sm_zs",client);
		}
	}

	return Plugin_Continue;
}

public void cvarZombieHPChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	// Handle a sysadmin modifying the special infected max HP cvars
	char cvarStr[255],difficulty[100];
	convar.GetName(cvarStr, sizeof(cvarStr));
	h_Difficulty.GetString(difficulty, sizeof(difficulty));

	#if DEBUG
	PrintToChatAll("\x01\x04[infhud]\x01 [%f] cvarZombieHPChanged(): Infected HP cvar '%s' changed from '%s' to '%s'", GetGameTime(), cvarStr, oldValue, newValue);
	#endif

	if (StrEqual(cvarStr, "z_hunter_health", false))
	{
		zombieHP[0] = StringToInt(newValue);
	}
	else if (StrEqual(cvarStr, "z_smoker_health", false))
	{
		zombieHP[1] = StringToInt(newValue);
	}
	else if (StrEqual(cvarStr, "z_boomer_health", false))
	{
		zombieHP[2] = StringToInt(newValue);
	}
	else if (g_bL4D2Version && StrEqual(cvarStr, "z_spitter_health", false))
	{
		zombieHP[3] = StringToInt(newValue);
	}
	else if (g_bL4D2Version && StrEqual(cvarStr, "z_jockey_health", false))
	{
		zombieHP[4] = StringToInt(newValue);
	}
	else if (g_bL4D2Version && StrEqual(cvarStr, "z_charger_health", false))
	{
		zombieHP[5] = StringToInt(newValue);
	}
}

public void queueHUDUpdate(int src)
{
	// Don't bother with infected HUD updates if the round has ended.
	if (!roundInProgress) return;

	ShowInfectedHUD(src);
}

public Action showInfHUD(Handle timer)
{
	if( g_bCvarAllow == false)
	{
		infHUDTimer = null;
		return Plugin_Stop;
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (respawnDelay[i] > 0)
		{
			//PrintToChatAll("respawnDelay[%d] = %d", i, respawnDelay[i]);
			respawnDelay[i]--;
		}
	}

	ShowInfectedHUD(1);
	return Plugin_Continue;
}

public Action Command_Say(int client, int args)
{
	if( g_bCvarAllow == false) return Plugin_Handled;

	char clientSteamID[32];
	//GetClientAuthString(client, clientSteamID, 32);

	if (g_bInfHUD)
	{
		if (!hudDisabled[client])
		{
			PrintToChat(client, "\x01\x04[infhud]\x01 %T","Hud Disable",client);
			SetTrieValue(usrHUDPref, clientSteamID, 1);
			hudDisabled[client] = 1;
		}
		else
		{
			PrintToChat(client, "\x01\x04[infhud]\x01 %T","Hud Enable",client);
			RemoveFromTrie(usrHUDPref, clientSteamID);
			hudDisabled[client] = 0;
		}
	}
	else
	{
		// Server admin has disabled Infected HUD server-wide
		PrintToChat(client, "\x01\x04[infhud]\x01 %T","Infected HUD is currently DISABLED",client);
	}
	return Plugin_Handled;
}

public void ShowInfectedHUD(int src)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && IsPlayerAlive(i))
		{
			if ( (GetClientTeam(i) == TEAM_INFECTED))
			{
				if(IsPlayerTank(i) && L4D_HasPlayerControlledZombies() == false)
				{
					int fus = 100 - GetFrustration(i);
					if(fus <= 75)
					{
						PrintHintText(i, "[TS] Tank Control: %d%%%%", fus);
					}
					
					if(fus <= 5)
					{
						PrintHintText(i, "[TS] %T","You don't attack survivors",i);
						SetTankFrustration(i, 100);
						ForcePlayerSuicide(i);
						continue;
					}
				}
			}
		}
	}

	if (!g_bInfHUD || IsVoteInProgress())
	{
		return;
	}

	// If no bots are alive, no point in showing the HUD
	// if (L4D_HasPlayerControlledZombies() && !BotsAlive())
	// {
	// 	return;
	// }

	#if DEBUG
		char calledFunc[255];
		switch (src)
		{
			case 1: strcopy(calledFunc, sizeof(calledFunc), "showInfHUD");
			case 2: strcopy(calledFunc, sizeof(calledFunc), "monitorRespawn");
			case 3: strcopy(calledFunc, sizeof(calledFunc), "delayedDmgUpdate");
			case 4: strcopy(calledFunc, sizeof(calledFunc), "doomedTankCountdown");
			case 10: strcopy(calledFunc, sizeof(calledFunc), "queueHUDUpdate - client join");
			case 11: strcopy(calledFunc, sizeof(calledFunc), "queueHUDUpdate - team switch");
			case 12: strcopy(calledFunc, sizeof(calledFunc), "queueHUDUpdate - spawn");
			case 13: strcopy(calledFunc, sizeof(calledFunc), "queueHUDUpdate - death");
			case 14: strcopy(calledFunc, sizeof(calledFunc), "queueHUDUpdate - menu closed");
			case 15: strcopy(calledFunc, sizeof(calledFunc), "queueHUDUpdate - player kicked");
			case 16: strcopy(calledFunc, sizeof(calledFunc), "evtRoundEnd");
			default: strcopy(calledFunc, sizeof(calledFunc), "UNKNOWN");
		}

		PrintToChatAll("\x01\x04[infhud]\x01 [%f] ShowInfectedHUD() called by [\x04%i\x01] '\x03%s\x01'", GetGameTime(), src, calledFunc);
	#endif

	int iHP;
	char iClass[100],lineBuf[100],iStatus[25];

	// Display information panel to infected clients
	pInfHUD = new Panel(GetMenuStyleHandle(MenuStyle_Radio));
	char information[32];
	if (L4D_HasPlayerControlledZombies())
		Format(information, sizeof(information), "INFECTED BOTS(%s):", PLUGIN_VERSION);
	else
		Format(information, sizeof(information), "INFECTED TEAM(%s):", PLUGIN_VERSION);

	pInfHUD.SetTitle(information);
	pInfHUD.DrawItem(" ",ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);

	if (roundInProgress)
	{
		#if !DEBUG
		// Loop through infected players and show their status
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i)) continue;
			if (GetClientTeam(i) == TEAM_INFECTED)
			{
				// Work out what they're playing as
				if (IsPlayerHunter(i))
				{
					strcopy(iClass, sizeof(iClass), "Hunter");
					iHP = RoundFloat((float(GetClientHealth(i)) / zombieHP[0]) * 100);
				}
				else if (IsPlayerSmoker(i))
				{
					strcopy(iClass, sizeof(iClass), "Smoker");
					iHP = RoundFloat((float(GetClientHealth(i)) / zombieHP[1]) * 100);
				}
				else if (IsPlayerBoomer(i))
				{
					strcopy(iClass, sizeof(iClass), "Boomer");
					iHP = RoundFloat((float(GetClientHealth(i)) / zombieHP[2]) * 100);
				}
				else if (g_bL4D2Version && IsPlayerSpitter(i))
				{
					strcopy(iClass, sizeof(iClass), "Spitter");
					iHP = RoundFloat((float(GetClientHealth(i)) / zombieHP[3]) * 100);
				}
				else if (g_bL4D2Version && IsPlayerJockey(i))
				{
					strcopy(iClass, sizeof(iClass), "Jockey");
					iHP = RoundFloat((float(GetClientHealth(i)) / zombieHP[4]) * 100);
				}
				else if (g_bL4D2Version && IsPlayerCharger(i))
				{
					strcopy(iClass, sizeof(iClass), "Charger");
					iHP = RoundFloat((float(GetClientHealth(i)) / zombieHP[5]) * 100);
				}
				else if (IsPlayerTank(i))
				{
					strcopy(iClass, sizeof(iClass), "Tank");
					iHP = RoundFloat((float(GetClientHealth(i)) / zombieHP[6]) * 100);
				}

				if (IsPlayerAlive(i))
				{
					// Check to see if they are a ghost or not
					if (IsPlayerGhost(i))
					{
						strcopy(iStatus, sizeof(iStatus), "GHOST");
					}
					else
					{
						if(IsPlayerTank(i) && !IsFakeClient(i)) Format(iStatus, sizeof(iStatus), "%i%% - %d%%", iHP,100-GetFrustration(i));
						else Format(iStatus, sizeof(iStatus), "%i%%", iHP);
					}
				}
				else
				{
					if (respawnDelay[i] > 0)
					{
						Format(iStatus, sizeof(iStatus), "DEAD (%i)", respawnDelay[i]);
						strcopy(iClass, sizeof(iClass), "");
						// As a failsafe if they're dead/waiting set HP to 0
						iHP = 0;
					}
					else if (respawnDelay[i] == 0 && L4D_HasPlayerControlledZombies() == false)
					{
						Format(iStatus, sizeof(iStatus), "READY");
						strcopy(iClass, sizeof(iClass), "");
						// As a failsafe if they're dead/waiting set HP to 0
						iHP = 0;
					}
					else
					{
						Format(iStatus, sizeof(iStatus), "DEAD");
						strcopy(iClass, sizeof(iClass), "");
						// As a failsafe if they're dead/waiting set HP to 0
						iHP = 0;
					}
				}

				if (IsFakeClient(i))
				{
					Format(lineBuf, sizeof(lineBuf), "%N-%s", i, iStatus);
					pInfHUD.DrawItem(lineBuf);
				}
				else
				{
					Format(lineBuf, sizeof(lineBuf), "%N-%s-%s", i, iClass, iStatus);
					pInfHUD.DrawItem(lineBuf);
				}
			}
		}

		pInfHUD.DrawItem(" ",ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
		pInfHUD.DrawText("Close HUD: !infhud");
		#endif

		#if DEBUG
		for(int i = 0; i <= L4D_MAXPLAYERS; i++)
		{
			if(SpawnInfectedBotTimer[i] != null)
			{
				Format(lineBuf, sizeof(lineBuf), "%d - Timer Cout Downing", i);
				pInfHUD.DrawItem(lineBuf);
			}
		}
		#endif
	}

	// Output the current team status to all infected clients
	// Technically the below is a bit of a kludge but we can't be 100% sure that a client status doesn't change
	// between building the panel and displaying it.
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			if ( GetClientTeam(i) == TEAM_INFECTED /*|| GetClientTeam(i) == TEAM_SPECTATOR*/ )
			{
				if( hudDisabled[i] == 0 && (GetClientMenu(i) == MenuSource_RawPanel || GetClientMenu(i) == MenuSource_None))
				{
					pInfHUD.Send(i, Menu_InfHUDPanel, 3);
				}
			}
		}
	}
	delete pInfHUD;
}

public void evtTeamSwitch(Event event, const char[] name, bool dontBroadcast)
{
	// Check to see if player joined infected team and if so refresh the HUD
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client)
	{
		if (GetClientTeam(client) == TEAM_INFECTED)
		{
			queueHUDUpdate(11);
		}
		else
		{
			// If player teamswitched to survivor, remove the HUD from their screen
			// immediately to stop them getting an advantage
			if (GetClientMenu(client) == MenuSource_RawPanel)
			{
				CancelClientMenu(client);
			}
		}
	}
}

public void evtInfectedSpawn(Event event, const char[] name, bool dontBroadcast)
{
	// Infected player spawned, so refresh the HUD
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client && IsClientInGame(client))
	{
		if (GetClientTeam(client) == TEAM_INFECTED)
		{
			respawnDelay[client] = 0;
			queueHUDUpdate(12);
			// If player joins server and doesn't have to wait to spawn they might not see the announce
			// until they next die (and have to wait).  As a fallback we check when they spawn if they've
			// already seen it or not.
			if (!clientGreeted[client] && g_bAnnounce)
			{
				CreateTimer(3.0, TimerAnnounce, client, TIMER_FLAG_NO_MAPCHANGE);
			}
			if(!IsFakeClient(client) && IsPlayerAlive(client))
			{
				CreateTimer(1.0, TimerAnnounce2, client, TIMER_FLAG_NO_MAPCHANGE);
				fPlayerSpawnEngineTime[client] = GetEngineTime();
			}

			if(IsFakeClient(client) && IsPlayerTank(client))
			{
				g_bAngry[client] = false;

				CreateTimer(1.0, Timer_CheckAngry, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

			}
		}
	}
}

public Action Timer_CheckAngry(Handle timer, int UserId)
{
	int client = GetClientOfUserId(UserId);
	if (client && IsClientInGame(client) && 
		IsFakeClient(client) && 
		GetClientTeam(client) == TEAM_INFECTED && 
		IsPlayerAlive(client) && 
		IsPlayerTank(client))
	{
		if (!L4D_IsPlayerGhost(client) && !bIsTankIdle(client))
		{
			g_bAngry[client] = true;
			return Plugin_Stop;
		}

		return Plugin_Continue;
	}

	return Plugin_Stop;
}

public void evtInfectedDeath(Event event, const char[] name, bool dontBroadcast)
{
	// Infected player died, so refresh the HUD
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client && IsClientInGame(client))
	{
		if (GetClientTeam(client) == TEAM_INFECTED)
		{
			queueHUDUpdate(13);

			if(!IsFakeClient(client) && L4D_HasPlayerControlledZombies() == false)
			{
				CleanUpStateAndMusic(client);
			}
		}
	}
}

public void evtInfectedHurt(Event event, const char[] name, bool dontBroadcast)
{
	// The life of a regular special infected is pretty transient, they won't take many shots before they
	// are dead (unlike the survivors) so we can afford to refresh the HUD reasonably quickly when they take damage.
	// The exception to this is the Tank - with 5000 health the survivors could be shooting constantly at it
	// resulting in constant HUD refreshes which is not efficient.  So, we check to see if the entity being
	// shot is a Tank or not and adjust the non-repeating timer accordingly.

	// Don't bother with infected HUD update if the round has ended
	if (!roundInProgress) return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));

	delete FightOrDieTimer[client];
	FightOrDieTimer[client] = CreateTimer(g_fIdletime_b4slay, DisposeOfCowards, client);

	delete FightOrDieTimer[attacker];
	FightOrDieTimer[attacker] = CreateTimer(g_fIdletime_b4slay, DisposeOfCowards, attacker);
}

public void evtInfectedWaitSpawn(Event event, const char[] name, bool dontBroadcast)
{
	// Don't bother with infected HUD update if the round has ended
	if (!roundInProgress) return;

	// Store this players respawn time in an array so we can present it to other clients
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client && IsClientInGame(client))
	{
		if (L4D_HasPlayerControlledZombies() && !IsFakeClient(client))
		{
			respawnDelay[client] = event.GetInt("spawntime");
		}
	}
}

void CheatCommand(int client,  char[] command, char[] arguments = "")
{
	int userFlags = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	int flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arguments);
	SetCommandFlags(command, flags);
	if(IsClientInGame(client)) SetUserFlagBits(client, userFlags);
}


void TurnFlashlightOn(int client)
{
	if (L4D_HasPlayerControlledZombies()) return;
	if (!IsClientInGame(client)) return;
	if (GetClientTeam(client) != TEAM_INFECTED) return;
	if (!IsPlayerAlive(client)) return;
	if (IsFakeClient(client)) return;

	SetEntProp(client, Prop_Send, "m_iTeamNum", 2);
	SDKCall(hFlashLightTurnOn, client);
	SetEntProp(client, Prop_Send, "m_iTeamNum", 3);

	if(g_bCoopInfectedPlayerFlashLight && !IsPlayerGhost(client))
	{
		DeleteLight(client);

		// Declares
		int entity;
		float vOrigin[3], vAngles[3];

		// Position light
		vOrigin = view_as<float>(  { 0.5, -1.5, 50.0 });
		vAngles = view_as<float>(  { -45.0, -45.0, 90.0 });

		// Light_Dynamic
		entity = MakeLightDynamic(vOrigin, vAngles, client);
		if(entity == 0) return;

		g_iLightIndex[client] = EntIndexToEntRef(entity);

		if( g_iClientIndex[client] == GetClientUserId(client) )
		{
			SetEntProp(entity, Prop_Send, "m_clrRender", g_iClientColor[client]);
			AcceptEntityInput(entity, "TurnOff");
		}
		else
		{
			g_iClientIndex[client] = GetClientUserId(client);
			g_iClientColor[client] = GetEntProp(entity, Prop_Send, "m_clrRender");
			AcceptEntityInput(entity, "TurnOff");
		}

		entity = g_iLightIndex[client];
		if( !IsValidEntRef(entity) )
			return;

		// Specified colors
		char sTempL[12];
		Format(sTempL, sizeof(sTempL), "185 51 51");

		SetVariantEntity(entity);
		SetVariantString(sTempL);
		AcceptEntityInput(entity, "color");
		AcceptEntityInput(entity, "toggle");

		int color = GetEntProp(entity, Prop_Send, "m_clrRender");
		if( color != g_iClientColor[client] )
			AcceptEntityInput(entity, "turnon");
		g_iClientColor[client] = color;
	}
}

void DeleteLight(int client)
{
	int entity = g_iLightIndex[client];
	g_iLightIndex[client] = 0;
	DeleteEntity(entity);
}

void DeleteEntity(int entity)
{
	if( IsValidEntRef(entity) )
		AcceptEntityInput(entity, "Kill");
}

int MakeLightDynamic(const float vOrigin[3], const float vAngles[3], int client)
{
	int entity = CreateEntityByName("light_dynamic");
	if( entity == -1)
	{
		LogError("Failed to create 'light_dynamic'");
		return 0;
	}

	char sTemp[16];
	Format(sTemp, sizeof(sTemp), "255 51 51 155");
	DispatchKeyValue(entity, "_light", sTemp);
	DispatchKeyValue(entity, "brightness", "1");
	DispatchKeyValueFloat(entity, "spotlight_radius", 0.0);
	DispatchKeyValueFloat(entity, "distance", 450.0);
	DispatchKeyValue(entity, "style", "0");
	DispatchSpawn(entity);
	AcceptEntityInput(entity, "TurnOn");

	// Attach to survivor
	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", client);

	TeleportEntity(entity, vOrigin, vAngles, NULL_VECTOR);
	return entity;
}

void SwitchToSurvivors(int client)
{
	if (L4D_HasPlayerControlledZombies()) return;
	if (!IsClientInGame(client)) return;
	if (GetClientTeam(client) == 2) return;
	if (IsFakeClient(client)) return;

	int bot = FindBotToTakeOver();

	if (bot == 0)
	{
		PrintHintText(client, "[TS] No alive survivor bots to take over.");
		return;
	}
	L4D_SetHumanSpec(bot, client);
	L4D_TakeOverBot(client);
	return;
}

public bool IsInteger(char[] buffer)
{
    int len = strlen(buffer);
    for (int i = 0; i < len; i++)
    {
        if ( !IsCharNumeric(buffer[i]) )
            return false;
    }

    return true;
}

int CheckAliveSurvivorPlayers_InSV()
{
	int iPlayersInAliveSurvivors=0;
	for (int i = 1; i < MaxClients+1; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS)
		{
			if(IsPlayerAlive(i)) iPlayersInAliveSurvivors++;
			else if(g_bIncludingDeadPlayers && !IsPlayerAlive(i)) iPlayersInAliveSurvivors++;
		}
	}
	return iPlayersInAliveSurvivors;
}

bool CheckRealPlayers_InSV(int client = 0)
{
	for (int i = 1; i < MaxClients+1; i++)
		if(IsClientConnected(i) && !IsFakeClient(i) && i != client)
			return true;

	return false;
}

stock bool IsWitch(int entity)
{
    if (entity > 0 && IsValidEntity(entity) && IsValidEdict(entity))
    {
        char strClassName[64];
        GetEdictClassname(entity, strClassName, sizeof(strClassName));
        return strcmp(strClassName, "witch", false) == 0;
    }
    return false;
}
// ====================================================================================================
//					SDKHOOKS TRANSMIT
// ====================================================================================================

void GetSpawnDisConvars()
{
	if(g_iCurrentMode != 1) return;

	/*
	if(g_bMapStarted && L4D_IsMissionFinalMap())
	{
		if(g_bL4D2Version)
		{
			// Removes the boundaries for z_finale_spawn_tank_safety_range and notify flag
			int flags2 = FindConVar("z_finale_spawn_tank_safety_range").Flags;
			SetConVarBounds(FindConVar("z_finale_spawn_tank_safety_range"), ConVarBound_Upper, false);
			SetConVarFlags(FindConVar("z_finale_spawn_tank_safety_range"), flags2 & ~FCVAR_NOTIFY);
			SetConVarInt(FindConVar("z_finale_spawn_tank_safety_range"),h_SpawnDistanceFinal.IntValue);

			// Add The last stand new convar "z_finale_spawn_mob_safety_range"
			int flags3 = FindConVar("z_finale_spawn_mob_safety_range").Flags;
			SetConVarBounds(FindConVar("z_finale_spawn_mob_safety_range"), ConVarBound_Upper, false);
			SetConVarFlags(FindConVar("z_finale_spawn_mob_safety_range"), flags3 & ~FCVAR_NOTIFY);
			SetConVarInt(FindConVar("z_finale_spawn_mob_safety_range"),h_SpawnDistanceFinal.IntValue);
		}
	}

	// Removes the boundaries for z_spawn_range and notify flag
	int flags3 = (FindConVar("z_spawn_range")).Flags;
	SetConVarBounds(FindConVar("z_spawn_range"), ConVarBound_Upper, false);
	SetConVarFlags(FindConVar("z_spawn_range"), flags3 & ~FCVAR_NOTIFY);
	SetConVarInt(FindConVar("z_spawn_range"),h_SpawnDistanceMax.IntValue);
	*/

	// Removes the boundaries for z_spawn_safety_range and notify flag
	int flags4 = FindConVar("z_spawn_safety_range").Flags;
	SetConVarBounds(FindConVar("z_spawn_safety_range"), ConVarBound_Upper, false);
	SetConVarFlags(FindConVar("z_spawn_safety_range"), flags4 & ~FCVAR_NOTIFY);
	SetConVarInt(FindConVar("z_spawn_safety_range"),h_SpawnDistanceMin.IntValue);
}

public Action SpawnWitchAuto(Handle timer)
{
	if( g_bCvarAllow == false || (g_bFinaleStarted && g_bWitchSpawnFinal == false))
	{
		hSpawnWitchTimer = null;
		return Plugin_Continue;
	}

	float vecPos[3];
	int witches=0;
	int entity = -1;
	while ( ((entity = FindEntityByClassname(entity, "witch")) != -1) )
	{
		witches++;
	}

	int anyclient = GetAheadSurvivor();
	int witch;
	if(anyclient == 0)
	{
		PrintToServer("[TS] Couldn't find a valid alive survivor to spawn witch at this moment.",ZOMBIESPAWN_Attempts);
	}
	else if (witches < g_iWitchLimit)
	{
		if(L4D_GetRandomPZSpawnPosition(anyclient,7,ZOMBIESPAWN_Attempts,vecPos) == true)
		{
			if( g_bSpawnWitchBride )
			{
				witch = L4D2_SpawnWitchBride(vecPos,NULL_VECTOR);
				if(witch > 0) CreateTimer(g_fWitchKillTime,KickWitch_Timer,EntIndexToEntRef(witch),TIMER_FLAG_NO_MAPCHANGE);
			}
			else
			{
				witch = L4D2_SpawnWitch(vecPos,NULL_VECTOR);
				if(witch > 0) CreateTimer(g_fWitchKillTime,KickWitch_Timer,EntIndexToEntRef(witch),TIMER_FLAG_NO_MAPCHANGE);
			}
		}
		else
		{
			PrintToServer("[TS] Couldn't find a Witch Spawn position in %d tries", ZOMBIESPAWN_Attempts);
		}
	}

	int SpawnTime = GetRandomInt(g_iWitchPeriodMin, g_iWitchPeriodMax);
	hSpawnWitchTimer = CreateTimer(float(SpawnTime), SpawnWitchAuto);

	return Plugin_Continue;
}

int L4D_GetSurvivorVictim(int client)
{
	int victim;

	if(g_bL4D2Version)
	{
		/* Charger */
		victim = GetEntPropEnt(client, Prop_Send, "m_pummelVictim");
		if (victim > 0)
		{
			return victim;
		}

		victim = GetEntPropEnt(client, Prop_Send, "m_carryVictim");
		if (victim > 0)
		{
			return victim;
		}

		/* Jockey */
		victim = GetEntPropEnt(client, Prop_Send, "m_jockeyVictim");
		if (victim > 0)
		{
			return victim;
		}
	}

    /* Hunter */
	victim = GetEntPropEnt(client, Prop_Send, "m_pounceVictim");
	if (victim > 0)
	{
		return victim;
 	}

    /* Smoker */
 	victim = GetEntPropEnt(client, Prop_Send, "m_tongueVictim");
	if (victim > 0)
	{
		return victim;
	}

	return -1;
}

public void L4D_OnEnterGhostState(int client)
{
	if(L4D_HasPlayerControlledZombies() == false)
	{
		DeleteLight(client);
		if(g_bCoopInfectedPlayerGhostState == true)
			TurnFlashlightOn(client);
		else
			CreateTimer(0.2, Timer_InfectedKillSelf, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

bool IsValidClient(int client, bool replaycheck = true)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client)) return false;
	//if (GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
	if (replaycheck)
	{
		if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
	}
	return true;
}

void ResetTimer()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		PlayerHasEnteredStart[i] = false;
		delete FightOrDieTimer[i];
		delete RestoreColorTimer[i];
	}

	delete hSpawnWitchTimer;
	delete PlayerLeftStartTimer;
	delete infHUDTimer;
	delete DisplayTimer; DisplayLock = false;
	delete InitialSpawnResetTimer;

	for(int i = 0; i <= L4D_MAXPLAYERS; i++)
	{
		delete SpawnInfectedBotTimer[i];
	}
}

// prevent infecetd fall damage on coop
public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damageType)
{
	if(L4D_HasPlayerControlledZombies() || victim <= 0 || victim > MaxClients || !IsClientInGame(victim) || IsFakeClient(victim)) return Plugin_Continue;
	if(attacker <= 0 || attacker > MaxClients || !IsClientInGame(attacker) ) return Plugin_Continue;

	if(attacker == victim && GetClientTeam(attacker) == TEAM_INFECTED && !IsPlayerTank(attacker))
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action tmrDelayCreateSurvivorGlow(Handle timer, any client)
{
	CreateSurvivorModelGlow(GetClientOfUserId(client));

	return Plugin_Continue;
}

public void CreateSurvivorModelGlow(int client)
{
	if (!g_bL4D2Version ||
	!client ||
	!IsClientInGame(client) ||
	GetClientTeam(client) != TEAM_SURVIVORS ||
	!IsPlayerAlive(client) ||
	IsValidEntRef(g_iModelIndex[client]) == true ||
	L4D_HasPlayerControlledZombies() ||
	g_bJoinableTeams == false ||
	bDisableSurvivorModelGlow == true ||
	g_bMapStarted == false) return;

	///////設定發光物件//////////
	// Get Client Model
	char sModelName[64];
	GetEntPropString(client, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));

	// Spawn dynamic prop entity
	int entity = CreateEntityByName("prop_dynamic_ornament");
	if (entity == -1) return;

	// Set new fake model
	SetEntityModel(entity, sModelName);
	DispatchSpawn(entity);

	// Set outline glow color
	SetEntProp(entity, Prop_Send, "m_CollisionGroup", 0);
	SetEntProp(entity, Prop_Send, "m_nSolidType", 0);
	SetEntProp(entity, Prop_Send, "m_nGlowRange", 4500);
	SetEntProp(entity, Prop_Send, "m_iGlowType", 3);
	if(IsplayerIncap(client)) SetEntProp(entity, Prop_Send, "m_glowColorOverride", 180 + (0 * 256) + (0 * 65536)); //RGB
	else SetEntProp(entity, Prop_Send, "m_glowColorOverride", 0 + (180 * 256) + (0 * 65536)); //RGB
	AcceptEntityInput(entity, "StartGlowing");

	// Set model invisible
	SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
	SetEntityRenderColor(entity, 0, 0, 0, 0);

	// Set model attach to client, and always synchronize
	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", client);
	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetAttached", client);
	///////發光物件完成//////////

	g_iModelIndex[client] = EntIndexToEntRef(entity);

	//model 只能給誰看?
	SDKHook(entity, SDKHook_SetTransmit, Hook_SetTransmit);
}

public Action Hook_SetTransmit(int entity, int client)
{
	if( GetClientTeam(client) != TEAM_INFECTED)
		return Plugin_Handled;

	return Plugin_Continue;
}

void RemoveSurvivorModelGlow(int client)
{
	int entity = g_iModelIndex[client];
	g_iModelIndex[client] = 0;

	if( IsValidEntRef(entity) )
		AcceptEntityInput(entity, "kill");
}

bool IsValidEntRef(int entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}

bool IsplayerIncap(int client)
{
	if(GetEntProp(client, Prop_Send, "m_isHangingFromLedge") || GetEntProp(client, Prop_Send, "m_isIncapacitated"))
		return true;

	return false;
}

int GetFrustration(int tank_index)
{
	return GetEntProp(tank_index, Prop_Send, "m_frustration");
}

stock void SetTankFrustration(int client, int iFrustration)
{
	SetEntProp(client, Prop_Send, "m_frustration", 100 - iFrustration);
}

int GetAheadSurvivor()
{
	float max_flow = 0.0;
	float tmp_flow, origin[3];
	int iAheadSurvivor = 0, iTemp;
	Address pNavArea;
	for (int client = 1; client <= MaxClients; client++) {
		if(IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
		{
			iTemp = client;
			GetClientAbsOrigin(client, origin);
			pNavArea = L4D2Direct_GetTerrorNavArea(origin);
			if (pNavArea == Address_Null) continue;
			
			tmp_flow = L4D2Direct_GetTerrorNavAreaFlow(pNavArea);
			if(tmp_flow >= max_flow)
			{
				max_flow = tmp_flow;
				iAheadSurvivor = iTemp;
			}
		}
	}

	return (iAheadSurvivor == 0) ? iTemp : iAheadSurvivor;
}

int GetRandomAliveSurvivor()
{
	int iClientCount, iClients[MAXPLAYERS+1];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS && IsPlayerAlive(i))
		{
			iClients[iClientCount++] = i;
		}
	}
	return (iClientCount == 0) ? 0 : iClients[GetRandomInt(0, iClientCount - 1)];
}

void CheckandPrecacheModel(const char[] model)
{
	if (!IsModelPrecached(model))
	{
		PrecacheModel(model, true);
	}
}

static bool IsVisibleTo(int player1, int player2)
{
	// check FOV first
	// if his origin is not within a 60 degree cone in front of us, no need to raytracing.
	float pos1_eye[3], pos2_eye[3], eye_angle[3], vec_diff[3], vec_forward[3];
	GetClientEyePosition(player1, pos1_eye);
	GetClientEyeAngles(player1, eye_angle);
	GetClientEyePosition(player2, pos2_eye);
	MakeVectorFromPoints(pos1_eye, pos2_eye, vec_diff);
	NormalizeVector(vec_diff, vec_diff);
	GetAngleVectors(eye_angle, vec_forward, NULL_VECTOR, NULL_VECTOR);
	if (GetVectorDotProduct(vec_forward, vec_diff) < 0.5) // cos 60
	{
		return false;
	}

	// in FOV
	Handle hTrace;
	bool ret = false;
	float pos2_feet[3], pos2_chest[3];
	GetClientAbsOrigin(player2, pos2_feet);
	pos2_chest[0] = pos2_feet[0];
	pos2_chest[1] = pos2_feet[1];
	pos2_chest[2] = pos2_feet[2] + 45.0;

	if (GetEntProp(player2, Prop_Send, "m_zombieClass") != ZOMBIECLASS_JOCKEY)
	{
		hTrace = TR_TraceRayFilterEx(pos1_eye, pos2_eye, MASK_VISIBLE, RayType_EndPoint, TraceFilter, player1);
		if (!TR_DidHit(hTrace) || TR_GetEntityIndex(hTrace) == player2)
		{
			CloseHandle(hTrace);
			return true;
		}
		CloseHandle(hTrace);
	}

	hTrace = TR_TraceRayFilterEx(pos1_eye, pos2_feet, MASK_VISIBLE, RayType_EndPoint, TraceFilter, player1);
	if (!TR_DidHit(hTrace) || TR_GetEntityIndex(hTrace) == player2)
	{
		CloseHandle(hTrace);
		return true;
	}
	CloseHandle(hTrace);

	hTrace = TR_TraceRayFilterEx(pos1_eye, pos2_chest, MASK_VISIBLE, RayType_EndPoint, TraceFilter, player1);
	if (!TR_DidHit(hTrace) || TR_GetEntityIndex(hTrace) == player2)
	{
		CloseHandle(hTrace);
		return true;
	}
	CloseHandle(hTrace);

	return ret;
}

static bool TraceFilter(int entity, int mask, int self)
{
	return entity != self;
}

// instead of Netprops "m_hasVisibleThreats", GetEntProp(i, Prop_Send, "m_hasVisibleThreats")
bool CanBeSeenBySurvivors(int infected)
{
	for (int client = 1; client <= MaxClients; ++client)
	{
		if (IsAliveSurvivor(client) && IsVisibleTo(client, infected))
		{
			return true;
		}
	}
	return false;
}

bool IsAliveSurvivor(int client)
{
    return IsClientInGame(client)
        && GetClientTeam(client) == TEAM_SURVIVORS
        && IsPlayerAlive(client);
}

GameData hGameData;
void GetGameData()
{
	hGameData = LoadGameConfigFile("l4dinfectedbots");
	if( hGameData != null )
	{
		PrepSDKCall();
	}
	else
	{
		SetFailState("Unable to find l4dinfectedbots.txt gamedata file.");
	}
	delete hGameData;
}

void PrepSDKCall()
{
	if(g_bL4D2Version)
	{
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "FlashLightTurnOn");
		hFlashLightTurnOn = EndPrepSDKCall();
	}
	else
	{
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "FlashlightIsOn");
		hFlashLightTurnOn = EndPrepSDKCall();
	}
	if (hFlashLightTurnOn == null)
		SetFailState("FlashLightTurnOn Signature broken");

	//find create bot signature
	Address replaceWithBot = GameConfGetAddress(hGameData, "NextBotCreatePlayerBot.jumptable");
	if (replaceWithBot != Address_Null && LoadFromAddress(replaceWithBot, NumberType_Int8) == 0x68) {
		// We're on L4D2 and linux
		PrepWindowsCreateBotCalls(replaceWithBot);
	}
	else
	{
		if (g_bL4D2Version)
		{
			PrepL4D2CreateBotCalls();
		}
		else
		{
			delete hCreateSpitter;
			delete hCreateJockey;
			delete hCreateCharger;
		}

		PrepL4D1CreateBotCalls();
	}

	g_iIntentionOffset = hGameData.GetOffset(FUNCTION_PATCH);
	if (g_iIntentionOffset == -1)
	{
		SetFailState("Failed to load offset: %s", FUNCTION_PATCH);
	}

	int iOffset = hGameData.GetOffset(FUNCTION_PATCH2);
	if (g_iIntentionOffset == -1)
	{
		SetFailState("Failed to load offset: %s", FUNCTION_PATCH2);
	}
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetVirtual(iOffset);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKFirstContainedResponder = EndPrepSDKCall();
	if (g_hSDKFirstContainedResponder == null)
	{
		SetFailState("Your \"%s\" offsets are outdated.", FUNCTION_PATCH2);
	}

	iOffset = hGameData.GetOffset(FUNCTION_PATCH3);
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetVirtual(iOffset);
	PrepSDKCall_SetReturnInfo(SDKType_String, SDKPass_Plain);
	g_hSDKGetName = EndPrepSDKCall();
	if (g_hSDKGetName == null)
	{
		SetFailState("Your \"%s\" offsets are outdated.", FUNCTION_PATCH3);
	}

	delete hGameData;
}

void LoadStringFromAdddress(Address addr, char[] buffer, int maxlength) {
	int i = 0;
	while(i < maxlength) {
		char val = LoadFromAddress(addr + view_as<Address>(i), NumberType_Int8);
		if(val == 0) {
			buffer[i] = 0;
			break;
		}
		buffer[i] = val;
		i++;
	}
	buffer[maxlength - 1] = 0;
}

Handle PrepCreateBotCallFromAddress(Handle hSiFuncTrie, const char[] siName) {
	Address addr;
	StartPrepSDKCall(SDKCall_Static);
	if (!GetTrieValue(hSiFuncTrie, siName, addr) || !PrepSDKCall_SetAddress(addr))
	{
		SetFailState("Unable to find NextBotCreatePlayer<%s> address in memory.", siName);
		return null;
	}
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
	return EndPrepSDKCall();
}

void PrepWindowsCreateBotCalls(Address jumpTableAddr) {
	Handle hInfectedFuncs = CreateTrie();
	// We have the address of the jump table, starting at the first PUSH instruction of the
	// PUSH mem32 (5 bytes)
	// CALL rel32 (5 bytes)
	// JUMP rel8 (2 bytes)
	// repeated pattern.

	// Each push is pushing the address of a string onto the stack. Let's grab these strings to identify each case.
	// "Hunter" / "Smoker" / etc.
	for(int i = 0; i < 7; i++) {
		// 12 bytes in PUSH32, CALL32, JMP8.
		Address caseBase = jumpTableAddr + view_as<Address>(i * 12);
		Address siStringAddr = view_as<Address>(LoadFromAddress(caseBase + view_as<Address>(1), NumberType_Int32));
		static char siName[32];
		LoadStringFromAdddress(siStringAddr, siName, sizeof(siName));

		Address funcRefAddr = caseBase + view_as<Address>(6); // 2nd byte of call, 5+1 byte offset.
		int funcRelOffset = LoadFromAddress(funcRefAddr, NumberType_Int32);
		Address callOffsetBase = caseBase + view_as<Address>(10); // first byte of next instruction after the CALL instruction
		Address nextBotCreatePlayerBotTAddr = callOffsetBase + view_as<Address>(funcRelOffset);
		//PrintToServer("Found NextBotCreatePlayerBot<%s>() @ %08x", siName, nextBotCreatePlayerBotTAddr);
		SetTrieValue(hInfectedFuncs, siName, nextBotCreatePlayerBotTAddr);
	}

	hCreateSmoker = PrepCreateBotCallFromAddress(hInfectedFuncs, "Smoker");
	if (hCreateSmoker == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateSmoker); return; }

	hCreateBoomer = PrepCreateBotCallFromAddress(hInfectedFuncs, "Boomer");
	if (hCreateBoomer == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateBoomer); return; }

	hCreateHunter = PrepCreateBotCallFromAddress(hInfectedFuncs, "Hunter");
	if (hCreateHunter == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateHunter); return; }

	hCreateTank = PrepCreateBotCallFromAddress(hInfectedFuncs, "Tank");
	if (hCreateTank == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateTank); return; }

	hCreateSpitter = PrepCreateBotCallFromAddress(hInfectedFuncs, "Spitter");
	if (hCreateSpitter == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateSpitter); return; }

	hCreateJockey = PrepCreateBotCallFromAddress(hInfectedFuncs, "Jockey");
	if (hCreateJockey == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateJockey); return; }

	hCreateCharger = PrepCreateBotCallFromAddress(hInfectedFuncs, "Charger");
	if (hCreateCharger == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateCharger); return; }
}

void PrepL4D2CreateBotCalls() {
	StartPrepSDKCall(SDKCall_Static);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, NAME_CreateSpitter))
	{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateSpitter); return; }
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
	hCreateSpitter = EndPrepSDKCall();
	if (hCreateSpitter == null)
	{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateSpitter); return; }

	StartPrepSDKCall(SDKCall_Static);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, NAME_CreateJockey))
	{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateJockey); return; }
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
	hCreateJockey = EndPrepSDKCall();
	if (hCreateJockey == null)
	{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateJockey); return; }

	StartPrepSDKCall(SDKCall_Static);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, NAME_CreateCharger))
	{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateCharger); return; }
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
	hCreateCharger = EndPrepSDKCall();
	if (hCreateCharger == null)
	{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateCharger); return; }
}

void PrepL4D1CreateBotCalls() {
	StartPrepSDKCall(SDKCall_Static);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, NAME_CreateSmoker))
	{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateSmoker); return; }
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
	hCreateSmoker = EndPrepSDKCall();
	if (hCreateSmoker == null)
	{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateSmoker); return; }

	StartPrepSDKCall(SDKCall_Static);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, NAME_CreateBoomer))
	{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateBoomer); return; }
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
	hCreateBoomer = EndPrepSDKCall();
	if (hCreateBoomer == null)
	{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateBoomer); return; }

	StartPrepSDKCall(SDKCall_Static);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, NAME_CreateHunter))
	{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateHunter); return; }
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
	hCreateHunter = EndPrepSDKCall();
	if (hCreateHunter == null)
	{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateHunter); return; }

	StartPrepSDKCall(SDKCall_Static);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, NAME_CreateTank))
	{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateTank); return; }
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
	hCreateTank = EndPrepSDKCall();
	if (hCreateTank == null)
	{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateTank); return; }
}

bool IsTooClose(int client, float distance)
{
	float fInfLocation[3], fSurvLocation[3], fVector[3];
	GetClientAbsOrigin(client, fInfLocation);

	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i)==2 && IsPlayerAlive(i))
		{
			GetClientAbsOrigin(i, fSurvLocation);
			MakeVectorFromPoints(fInfLocation, fSurvLocation, fVector);
			if (GetVectorLength(fVector, true) < Pow(distance, 2.0)) return true;
		}
	}
	return false;
}

stock int GetInfectedAttacker(int client)
{
	int attacker;

	if(g_bL4D2Version)
	{
		/* Charger */
		attacker = GetEntPropEnt(client, Prop_Send, "m_pummelAttacker");
		if (attacker > 0)
		{
			return attacker;
		}

		attacker = GetEntPropEnt(client, Prop_Send, "m_carryAttacker");
		if (attacker > 0)
		{
			return attacker;
		}
		/* Jockey */
		attacker = GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker");
		if (attacker > 0)
		{
			return attacker;
		}
	}

	/* Hunter */
	attacker = GetEntPropEnt(client, Prop_Send, "m_pounceAttacker");
	if (attacker > 0)
	{
		return attacker;
	}

	/* Smoker */
	attacker = GetEntPropEnt(client, Prop_Send, "m_tongueOwner");
	if (attacker > 0)
	{
		return attacker;
	}

	return -1;
}

public void ConVarChanged_BalanceUpdate(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bCommonLimitAdjust = h_CommonLimitAdjust.BoolValue;
	g_bTankHealthAdjust = h_TankHealthAdjust.BoolValue;
	TankHealthCheck();
	iPlayersInSurvivorTeam = 0;
	if(DisplayLock == false)
	{
		delete DisplayTimer;
		DisplayTimer = CreateTimer(1.0,Timer_CountSurvivor);
	}
}

public void ConVarChanged_TankLimitUpdate(ConVar convar, const char[] oldValue, const char[] newValue)
{
	int iAliveSurplayers = CheckAliveSurvivorPlayers_InSV();

	if(iAliveSurplayers >= 0)
	{
		int addition = iAliveSurplayers - 4;
		if(addition < 0) addition = 0;

		g_iTankLimit = h_TankLimit.IntValue + (h_PlayerAddTankLimit.IntValue * (addition/h_PlayerAddTankLimitScale.IntValue));
	}
}

bool HasAccess(int client, char[] g_sAcclvl)
{
	// no permissions set
	if (strlen(g_sAcclvl) == 0)
		return true;

	else if (StrEqual(g_sAcclvl, "-1"))
		return false;

	// check permissions
	int userFlags = GetUserFlagBits(client);
	if ( (userFlags & ReadFlagString(g_sAcclvl)) || (userFlags & ADMFLAG_ROOT))
	{
		return true;
	}

	return false;
}

void GameStart()
{
	// We don't care who left, just that at least one did
	if(g_iCurrentMode == 3)
	{
		if(g_bL4D2Version)
		{
			SetConVarInt(FindConVar("survival_max_smokers"), 0);
			SetConVarInt(FindConVar("survival_max_boomers"), 0);
			SetConVarInt(FindConVar("survival_max_hunters"), 0);
			SetConVarInt(FindConVar("survival_max_jockeys"), 0);
			SetConVarInt(FindConVar("survival_max_spitters"), 0);
			SetConVarInt(FindConVar("survival_max_chargers"), 0);
			SetConVarInt(FindConVar("survival_max_specials"), 0);
		}
		else
		{
			SetConVarInt(FindConVar("holdout_max_smokers"), 0);
			SetConVarInt(FindConVar("holdout_max_boomers"), 0);
			SetConVarInt(FindConVar("holdout_max_hunters"), 0);
			SetConVarInt(FindConVar("holdout_max_specials"), 0);
		}
	}

	GetSpawnDisConvars();

	// We check if we need to spawn bots
	CheckIfBotsNeeded(2);
	#if DEBUG
	LogMessage("Checking to see if we need bots");
	#endif
	if(g_iCurrentMode != 3)
	{
		delete hSpawnWitchTimer;
		hSpawnWitchTimer = CreateTimer(float(GetRandomInt(g_iWitchPeriodMin, g_iWitchPeriodMax)), SpawnWitchAuto);
	}
}

// The type of idle mode to check for.
// Note: It is recommended to set this to "2" on non-finale maps and "0" on finale maps.
// Note: There is a rare bug where a Tank spawns with no behavior even though they look "idle" to survivors. Set this setting to "0" or "2" to detect this bug.
// Note: Do not change this setting if you are unsure of how it works.
// Note: This setting can be used for standard Tanks.
// --
// 0: Both
// 1: Only check for idle Tanks.
// 2: Only check for Tanks with no behavior (rare bug).
bool bIsTankIdle(int tank, int type = 0)
{
	Address adTank = GetEntityAddress(tank);
	if (adTank == Address_Null)
	{
		return false;
	}

	Address adIntention = LoadFromAddress((adTank + view_as<Address>(g_iIntentionOffset)), NumberType_Int32);
	if (adIntention == Address_Null)
	{
		return false;
	}

	Address adBehavior = view_as<Address>(SDKCall(g_hSDKFirstContainedResponder, adIntention));
	if (adBehavior == Address_Null)
	{
		return false;
	}

	Address adAction = view_as<Address>(SDKCall(g_hSDKFirstContainedResponder, adBehavior));
	if (adAction == Address_Null)
	{
		return false;
	}

	Address adChildAction = Address_Null;
	while ((adChildAction = view_as<Address>(SDKCall(g_hSDKFirstContainedResponder, adAction))) != Address_Null)
	{
		adAction = adChildAction;
	}

	char sAction[64];
	SDKCall(g_hSDKGetName, adAction, sAction, sizeof sAction);
	return (type != 2 && StrEqual(sAction, "TankIdle")) || (type != 1 && (StrEqual(sAction, "TankBehavior") || adAction == adBehavior));
}

void CleanUpStateAndMusic(int client)
{
	if(IsFakeClient(client)) return;

	// Resets a players state equivalent to when they die
	// does stuff like removing any pounces, stops reviving, stops healing, resets hang lighting, resets heartbeat and other sounds.
	L4D_CleanupPlayerState(client);

	// This fixes the music glitch thats been bothering me and many players for a long time. The music keeps playing over and over when it shouldn't. Doesn't execute
	// on versus.
	if(g_iCurrentMode != 2)
	{
		if (!g_bL4D2Version)
		{
			L4D_StopMusic(client, "Event.MissionStart_BaseLoop_Hospital");
			L4D_StopMusic(client, "Event.MissionStart_BaseLoop_Airport");
			L4D_StopMusic(client, "Event.MissionStart_BaseLoop_Farm");
			L4D_StopMusic(client, "Event.MissionStart_BaseLoop_Small_Town");
			L4D_StopMusic(client, "Event.MissionStart_BaseLoop_Garage");
			L4D_StopMusic(client, "Event.CheckPointBaseLoop_Hospital");
			L4D_StopMusic(client, "Event.CheckPointBaseLoop_Airport");
			L4D_StopMusic(client, "Event.CheckPointBaseLoop_Small_Town");
			L4D_StopMusic(client, "Event.CheckPointBaseLoop_Farm");
			L4D_StopMusic(client, "Event.CheckPointBaseLoop_Garage");
			L4D_StopMusic(client, "Event.Zombat");
			L4D_StopMusic(client, "Event.Zombat_A2");
			L4D_StopMusic(client, "Event.Zombat_A3");
			L4D_StopMusic(client, "Event.Tank");
			L4D_StopMusic(client, "Event.TankMidpoint");
			L4D_StopMusic(client, "Event.TankBrothers");
			L4D_StopMusic(client, "Event.WitchAttack");
			L4D_StopMusic(client, "Event.WitchBurning");
			L4D_StopMusic(client, "Event.WitchRage");
			L4D_StopMusic(client, "Event.HunterPounce");
			L4D_StopMusic(client, "Event.SmokerChoke");
			L4D_StopMusic(client, "Event.SmokerDrag");
			L4D_StopMusic(client, "Event.VomitInTheFace");
			L4D_StopMusic(client, "Event.LedgeHangTwoHands");
			L4D_StopMusic(client, "Event.LedgeHangOneHand");
			L4D_StopMusic(client, "Event.LedgeHangFingers");
			L4D_StopMusic(client, "Event.LedgeHangAboutToFall");
			L4D_StopMusic(client, "Event.LedgeHangFalling");
			L4D_StopMusic(client, "Event.Down");
			L4D_StopMusic(client, "Event.BleedingOut");
			L4D_StopMusic(client, "Event.Down");
		}
		else
		{
			// Music when Mission Starts
			L4D_StopMusic(client, "Event.MissionStart_BaseLoop_Mall");
			L4D_StopMusic(client, "Event.MissionStart_BaseLoop_Fairgrounds");
			L4D_StopMusic(client, "Event.MissionStart_BaseLoop_Plankcountry");
			L4D_StopMusic(client, "Event.MissionStart_BaseLoop_Milltown");
			L4D_StopMusic(client, "Event.MissionStart_BaseLoop_BigEasy");
			
			// Checkpoints
			L4D_StopMusic(client, "Event.CheckPointBaseLoop_Mall");
			L4D_StopMusic(client, "Event.CheckPointBaseLoop_Fairgrounds");
			L4D_StopMusic(client, "Event.CheckPointBaseLoop_Plankcountry");
			L4D_StopMusic(client, "Event.CheckPointBaseLoop_Milltown");
			L4D_StopMusic(client, "Event.CheckPointBaseLoop_BigEasy");
			
			// Zombat
			L4D_StopMusic(client, "Event.Zombat_1");
			L4D_StopMusic(client, "Event.Zombat_A_1");
			L4D_StopMusic(client, "Event.Zombat_B_1");
			L4D_StopMusic(client, "Event.Zombat_2");
			L4D_StopMusic(client, "Event.Zombat_A_2");
			L4D_StopMusic(client, "Event.Zombat_B_2");
			L4D_StopMusic(client, "Event.Zombat_3");
			L4D_StopMusic(client, "Event.Zombat_A_3");
			L4D_StopMusic(client, "Event.Zombat_B_3");
			L4D_StopMusic(client, "Event.Zombat_4");
			L4D_StopMusic(client, "Event.Zombat_A_4");
			L4D_StopMusic(client, "Event.Zombat_B_4");
			L4D_StopMusic(client, "Event.Zombat_5");
			L4D_StopMusic(client, "Event.Zombat_A_5");
			L4D_StopMusic(client, "Event.Zombat_B_5");
			L4D_StopMusic(client, "Event.Zombat_6");
			L4D_StopMusic(client, "Event.Zombat_A_6");
			L4D_StopMusic(client, "Event.Zombat_B_6");
			L4D_StopMusic(client, "Event.Zombat_7");
			L4D_StopMusic(client, "Event.Zombat_A_7");
			L4D_StopMusic(client, "Event.Zombat_B_7");
			L4D_StopMusic(client, "Event.Zombat_8");
			L4D_StopMusic(client, "Event.Zombat_A_8");
			L4D_StopMusic(client, "Event.Zombat_B_8");
			L4D_StopMusic(client, "Event.Zombat_9");
			L4D_StopMusic(client, "Event.Zombat_A_9");
			L4D_StopMusic(client, "Event.Zombat_B_9");
			L4D_StopMusic(client, "Event.Zombat_10");
			L4D_StopMusic(client, "Event.Zombat_A_10");
			L4D_StopMusic(client, "Event.Zombat_B_10");
			L4D_StopMusic(client, "Event.Zombat_11");
			L4D_StopMusic(client, "Event.Zombat_A_11");
			L4D_StopMusic(client, "Event.Zombat_B_11");
			
			// Zombat specific maps
			
			// C1 Mall
			L4D_StopMusic(client, "Event.Zombat2_Intro_Mall");
			L4D_StopMusic(client, "Event.Zombat3_Intro_Mall");
			L4D_StopMusic(client, "Event.Zombat3_A_Mall");
			L4D_StopMusic(client, "Event.Zombat3_B_Mall");
			
			// A2 Fairgrounds
			L4D_StopMusic(client, "Event.Zombat_Intro_Fairgrounds");
			L4D_StopMusic(client, "Event.Zombat_Fairgrounds");
			L4D_StopMusic(client, "Event.Zombat_A_Fairgrounds");
			L4D_StopMusic(client, "Event.Zombat_B_Fairgrounds");
			L4D_StopMusic(client, "Event.Zombat_B_Fairgrounds");
			L4D_StopMusic(client, "Event.Zombat2_Intro_Fairgrounds");
			L4D_StopMusic(client, "Event.Zombat3_Intro_Fairgrounds");
			L4D_StopMusic(client, "Event.Zombat3_A_Fairgrounds");
			L4D_StopMusic(client, "Event.Zombat3_B_Fairgrounds");
			
			// C3 Plankcountry
			L4D_StopMusic(client, "Event.Zombat_PlankCountry");
			L4D_StopMusic(client, "Event.Zombat_A_PlankCountry");
			L4D_StopMusic(client, "Event.Zombat_B_PlankCountry");
			L4D_StopMusic(client, "Event.Zombat2_Intro_Plankcountry");
			L4D_StopMusic(client, "Event.Zombat3_Intro_Plankcountry");
			L4D_StopMusic(client, "Event.Zombat3_A_Plankcountry");
			L4D_StopMusic(client, "Event.Zombat3_B_Plankcountry");
			
			// A2 Milltown
			L4D_StopMusic(client, "Event.Zombat2_Intro_Milltown");
			L4D_StopMusic(client, "Event.Zombat3_Intro_Milltown");
			L4D_StopMusic(client, "Event.Zombat3_A_Milltown");
			L4D_StopMusic(client, "Event.Zombat3_B_Milltown");
			
			// C5 BigEasy
			L4D_StopMusic(client, "Event.Zombat2_Intro_BigEasy");
			L4D_StopMusic(client, "Event.Zombat3_Intro_BigEasy");
			L4D_StopMusic(client, "Event.Zombat3_A_BigEasy");
			L4D_StopMusic(client, "Event.Zombat3_B_BigEasy");
			
			// A2 Clown
			L4D_StopMusic(client, "Event.Zombat3_Intro_Clown");
			
			// Death
			
			// ledge hang
			L4D_StopMusic(client, "Event.LedgeHangTwoHands");
			L4D_StopMusic(client, "Event.LedgeHangOneHand");
			L4D_StopMusic(client, "Event.LedgeHangFingers");
			L4D_StopMusic(client, "Event.LedgeHangAboutToFall");
			L4D_StopMusic(client, "Event.LedgeHangFalling");
			
			// Down
			// Survivor is down and being beaten by infected
			
			L4D_StopMusic(client, "Event.Down");
			L4D_StopMusic(client, "Event.BleedingOut");
			
			// Survivor death
			// This is for the death of an individual survivor to be played after the health meter has reached zero
			
			L4D_StopMusic(client, "Event.SurvivorDeath");
			L4D_StopMusic(client, "Event.ScenarioLose");
			
			// Bosses
			
			// Tank
			L4D_StopMusic(client, "Event.Tank");
			L4D_StopMusic(client, "Event.TankMidpoint");
			L4D_StopMusic(client, "Event.TankBrothers");
			L4D_StopMusic(client, "C2M5.RidinTank1");
			L4D_StopMusic(client, "C2M5.RidinTank2");
			L4D_StopMusic(client, "C2M5.BadManTank1");
			L4D_StopMusic(client, "C2M5.BadManTank2");
			
			// Witch
			L4D_StopMusic(client, "Event.WitchAttack");
			L4D_StopMusic(client, "Event.WitchBurning");
			L4D_StopMusic(client, "Event.WitchRage");
			L4D_StopMusic(client, "Event.WitchDead");
			
			// mobbed
			L4D_StopMusic(client, "Event.Mobbed");
			
			// Hunter
			L4D_StopMusic(client, "Event.HunterPounce");
			
			// Smoker
			L4D_StopMusic(client, "Event.SmokerChoke");
			L4D_StopMusic(client, "Event.SmokerDrag");
			
			// Boomer
			L4D_StopMusic(client, "Event.VomitInTheFace");
			
			// Charger
			L4D_StopMusic(client, "Event.ChargerSlam");
			
			// Jockey
			L4D_StopMusic(client, "Event.JockeyRide");
			
			// Spitter
			L4D_StopMusic(client, "Event.SpitterSpit");
			L4D_StopMusic(client, "Event.SpitterBurn");
		}
	}
}


int GenerateIndex()
{
	int TotalSpawnWeight, StandardizedSpawnWeight;
	
	//temporary spawn weights factoring in SI spawn limits
	int[] TempSpawnWeights = new int[NUM_INFECTED];
	float[] IntervalEnds = new float[NUM_INFECTED];
	for(int i = 0; i < NUM_INFECTED; i++)
	{
		if(g_iSpawnCounts[i] < g_iSpawnLimits[i])
		{
			if(g_bScaleWeights)
				TempSpawnWeights[i] = (g_iSpawnLimits[i] - g_iSpawnCounts[i]) * g_iSpawnWeights[i];
			else
				TempSpawnWeights[i] = g_iSpawnWeights[i];
		}
		else
		{
			TempSpawnWeights[i] = 0;
		}
		
		TotalSpawnWeight += TempSpawnWeights[i];
	}
	
	//calculate end intervals for each spawn
	float unit = 1.0/TotalSpawnWeight;
	for (int i = 0; i < NUM_INFECTED; i++)
	{
		if (TempSpawnWeights[i] >= 0)
		{
			StandardizedSpawnWeight += TempSpawnWeights[i];
			IntervalEnds[i] = StandardizedSpawnWeight * unit;
		}
	}
	
	float r = GetRandomFloat(0.0, 1.0); //selector r must be within the ith interval for i to be selected
	for (int i = 0; i < NUM_INFECTED; i++)
	{
		//negative and 0 weights are ignored
		if (TempSpawnWeights[i] <= 0) continue;
		//r is not within the ith interval
		if (IntervalEnds[i] < r) continue;
		//selected index i because r is within ith interval
		return i;
	}

	return -1; //no selection because all weights were negative or 0
}
///////////////////////////////////////////////////////////////////////////