#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

//#define MAX_CALLS			1		// How many times to print each forward

#pragma newdecls required
#pragma semicolon 1

#define CLIENTS		0
#define EVENT			1
#define ROUND			2
#define TIMELEFT	3
#define TOTAL			4

#define GAMEDATA_FILE           "staggersolver"

#define PL_VERSION "1.0.2"
#define DEBUG		1

public Plugin myinfo =
{
  name        = "Execute Configs",
  author      = "Tsunami",
  description = "Execute configs on certain events.",
  version     = PL_VERSION,
  url         = "http://www.tsunami-productions.nl"
};



/**
 * Globals
 */
int g_iRound;
bool g_bSection;
SMCParser g_hConfigParser;
ConVar g_hEnabled;
ConVar g_hIncludeBots;
ConVar g_hIncludeSpec;
Handle g_hTimer;
Handle g_hTimers[TOTAL];
StringMap g_hTries[TOTAL];
StringMap g_hTypes;
char g_sConfigFile[PLATFORM_MAX_PATH + 1];
char g_sMap[32];
int animtest=0;

//new variables
int clientinpos1 = 0;
int clientinpos2 = 0;
bool g_bLeft4Dead2;
bool g_bLateLoad;
Handle hGameConf;
Handle hIsStaggering;
bool g_bStagger[MAXPLAYERS+1];

bool g_bLibraryActive;
bool g_bTestForwards =		true;	// To enable forwards testing
int g_iForwardsMax;					// Total forwards we expect to see
int g_iForwards;
Handle g_hTimerAnim;
Handle g_hTimerExecAMR; 

/**
 * Forwards
 */

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test == Engine_Left4Dead ) g_bLeft4Dead2 = false;
	else if( test == Engine_Left4Dead2 ) g_bLeft4Dead2 = true;
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}

	// (+2 for "L4D2_OnEndVersusModeRound_Post" and "L4D2_OnSelectTankAttackPre")
	if( g_bLeft4Dead2 )
		g_iForwardsMax = 43;
	else
		g_iForwardsMax = 33;
	g_bLateLoad = late;
	
	RegPluginLibrary("left4dhooks");


	return APLRes_Success;
}

public void OnLibraryAdded(const char[] name)
{
	if( strcmp(name, "left4dhooks") == 0 )
		g_bLibraryActive = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if( strcmp(name, "left4dhooks") == 0 )
		g_bLibraryActive = false;
}

public void OnAllPluginsLoaded()
{
	if( g_bLibraryActive == false )
		LogError("Required plugin left4dhooks is missing.");
}

void ResetPlugin()
{
	delete g_hTimer;
}


public void OnPluginStart()
{
	CreateConVar("sm_executeconfigs_version", PL_VERSION, "Execute configs on certain events.", FCVAR_NOTIFY);
	g_hEnabled      = CreateConVar("sm_executeconfigs_enabled",      "1", "Enable/disable executing configs");
	g_hIncludeBots  = CreateConVar("sm_executeconfigs_include_bots", "1", "Enable/disable including bots when counting number of clients");
	g_hIncludeSpec  = CreateConVar("sm_executeconfigs_include_spec", "1", "Enable/disable including spectators when counting number of clients");

	BuildPath(Path_SM, g_sConfigFile, sizeof(g_sConfigFile), "configs/executeconfigs.txt");
	RegServerCmd("sm_executeconfigs_reload", Command_Reload, "Reload the configs");
	RegServerCmd("sm_detectanim", Command_Anim, "Anim");
	RegAdminCmd("sm_prueba", ExecConfigCmd, ADMFLAG_ROOT, "PRobando.");


	g_hConfigParser = new SMCParser();
	g_hConfigParser.OnEnterSection = ReadConfig_NewSection;
	g_hConfigParser.OnKeyValue     = ReadConfig_KeyValue;
	g_hConfigParser.OnLeaveSection = ReadConfig_EndSection;

	g_hTypes        = new StringMap();
	g_hTypes.SetValue("clients",  CLIENTS);
	g_hTypes.SetValue("event",    EVENT);
	g_hTypes.SetValue("round",    ROUND);
	g_hTypes.SetValue("timeleft", TIMELEFT);

	for (int i = 0; i < TOTAL; i++)
		g_hTries[i] = new StringMap();

	char sGameDir[64];
	GetGameFolderName(sGameDir, sizeof(sGameDir));

	if (StrEqual(sGameDir, "insurgency"))
		HookEvent("game_newmap",            Event_GameStart,  EventHookMode_PostNoCopy);
	else
		HookEvent("game_start",             Event_GameStart,  EventHookMode_PostNoCopy);

	if (StrEqual(sGameDir, "dod"))
		HookEvent("dod_round_start",        Event_RoundStart, EventHookMode_PostNoCopy);
	else if (StrEqual(sGameDir, "tf"))
	{
		HookEvent("teamplay_restart_round", Event_GameStart,  EventHookMode_PostNoCopy);
		HookEvent("teamplay_round_start",   Event_RoundStart, EventHookMode_PostNoCopy);
	}
	else
		HookEvent("round_start",            Event_RoundStart, EventHookMode_PostNoCopy);
	
		//HookEvent("player_hurt_concise",verifyStagger, EventHookMode_Pre);
		//HookEvent("hegrenade_detonate",verifyStagger, EventHookMode_Pre);
		//HookEvent("charger_impact",verifyStagger, EventHookMode_Pre);
		//HookEvent("player_shoved",verifyStagger, EventHookMode_Pre);
		HookEvent("round_end",Event_RoundEnd);
		HookEvent("map_transition", 		Event_RoundEnd); //戰役過關到下一關的時候 (沒有觸發round_end)
		HookEvent("mission_lost", 			Event_RoundEnd); //戰役滅團重來該關卡的時候 (之後有觸發round_end)
		HookEvent("finale_vehicle_leaving", Event_RoundEnd); //救援載具離開之時  (沒有觸發round_end)
	
	for (int i = 1; i <= MaxClients; i++)
	{
		g_bStagger[i]=false;
	}
/*	
    // sdkhook
    hGameConf = LoadGameConfigFile(GAMEDATA_FILE);
    if (hGameConf == INVALID_HANDLE)
    SetFailState("[aidmgfix] Could not load game config file (staggersolver.txt).");

    StartPrepSDKCall(SDKCall_Player);

    if (!PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "IsStaggering"))
    SetFailState("[aidmgfix] Could not find signature IsStaggering.");
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    hIsStaggering = EndPrepSDKCall();
    if (hIsStaggering == INVALID_HANDLE)
    SetFailState("[aidmgfix] Failed to load signature IsStaggering");

    CloseHandle(hGameConf);
	*/
	
	if (g_bLateLoad)
	{
		g_bLateLoad = false;
	}
}

public Action L4D2_OnStagger(int target, int source)
{	
		return Plugin_Handled;
	//return Plugin_Continue;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for( int i = 1; i <= MaxClients; i++ )
	{
		AnimHookDisable(i, OnAnim, OnAnimPost);
	}

}

public void OnMapEnd()
{

	clientinpos1 = 0;
	clientinpos2 = 0;

}

public void OnMapStart()
{
	g_iRound = 0;
	g_hTimer = null;

	for (int i = 0; i < TOTAL; i++)
		g_hTimers[i] = null;

	GetCurrentMap(g_sMap, sizeof(g_sMap));
	ParseConfig();
}

public void OnMapTimeLeftChanged()
{
	delete g_hTimer;

	int iTimeleft;
	if (GetMapTimeLeft(iTimeleft) && iTimeleft > 0)
		g_hTimer = CreateTimer(60.0, Timer_ExecTimeleftConfig, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}

public void OnClientPutInServer(int client)
{
	ExecClientsConfig(0);
}

public void OnClientDisconnect(int client)
{
	ExecClientsConfig(-1);
}


/**
 * Commands
 */
public Action Command_Reload(int args)
{
	ParseConfig();
}

public Action Command_Anim(int args)
{
		#if DEBUG
		PrintToChatAll("DetectAnim Iniciado %d",animtest);
		#endif
	delete g_hTimerAnim;
	g_hTimer = CreateTimer(2.0, Timer_DetectAnim, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	
}


/**
 * Events
 */
public void Event_GameStart(Event event, const char[] name, bool dontBroadcast)
{
	g_iRound = 0;
}

public void Event_Hook(Event event, const char[] name, bool dontBroadcast)
{
	if (g_hEnabled.BoolValue)
		ExecConfig(EVENT, name);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_iRound++;

	if (!g_hEnabled.BoolValue)
		return;

	char sRound[4];
	IntToString(g_iRound, sRound, sizeof(sRound));
	ExecConfig(ROUND, sRound);
}


/**
 * Timers
 */
public Action Timer_ExecConfig(Handle timer, DataPack pack)
{
	pack.Reset();

	char sConfig[32];
	int iType = pack.ReadCell();
	pack.ReadString(sConfig, sizeof(sConfig));	
	
	ServerCommand("exec \"%s\"", sConfig);
	g_hTimers[iType] = null;
}

public Action Timer_ExecTimeleftConfig(Handle timer)
{
	if (!g_hEnabled.BoolValue)
		return Plugin_Handled;

	int iTimeleft;
	if (!GetMapTimeLeft(iTimeleft) || iTimeleft < 0)
		return Plugin_Handled;

	char sTimeleft[4];
	IntToString(iTimeleft / 60, sTimeleft, sizeof(sTimeleft));
	ExecConfig(TIMELEFT, sTimeleft);

	return Plugin_Handled;
}


public Action Timer_ExecConfigCommand(Handle timer, DataPack pack)
{
	delete g_hTimerExecAMR;
	pack.Reset();
	char sConfig[32];
	int iType = pack.ReadCell();
	pack.ReadString(sConfig, sizeof(sConfig));
	if (isCorrectPositionsandHaveCorrectWeapons())
	{
		ServerCommand("sm_cvar st_mr_force_file default1");
		ServerCommand("sm_cvar st_mr_play \"%d\"",clientinpos1);
	
	if( clientinpos1 && IsClientInGame(clientinpos1) )
		AnimHookEnable(clientinpos1, OnAnim, OnAnimPost);
	
		ServerCommand("sm_cvar st_mr_force_file default2");
		ServerCommand("sm_cvar st_mr_play \"%d\"",clientinpos2);
		g_hTimerExecAMR = CreateTimer(1.0, Timer_ExecAMovementReader, clientinpos2, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	}
	else
	{	
		#if DEBUG
		PrintToChatAll("no cumple con posicion o armas o vida o zombies lejos");
		#endif
		PrintToServer("no cumple con posicion o armas o vida o zombies lejos");		
	}
	g_hTimers[iType] = null;
}

public void OnPlayEnd(int client, const char[] name)
{
	ServerCommand("sm_cvar l4d2_grenade_detonation_chance 5");
	delete g_hTimerExecAMR;
}

/*
public void OnPlayLine(int client, const char[] name,int ticks,int buttons)
{
	ServerCommand("sm_cvar l4d2_grenade_detonation_chance 5");
}
*/

public Action Timer_ExecAMovementReader(Handle timer,int target)
{
	#if DEBUG
	PrintToChatAll("Timer_ExecAMovementReader");
	#endif					
	float DISTANCESETTING = float(5);
	float DISTANCESETTINGINFECTED = float(100);
    float targetVector[3];
	float impact1[3];
	
	GetClientAbsOrigin(target, impact1);
	
	int infected = -1;	
	
	while( (infected = FindEntityByClassname(infected, "infected")) != INVALID_ENT_REFERENCE )
	{
		GetEntPropVector(infected, Prop_Data, "m_vecOrigin", targetVector);
		float distance = GetVectorDistance(targetVector, impact1);
		if (distance < DISTANCESETTINGINFECTED)
		{
			#if DEBUG
			PrintToChatAll("infectedinarea near target");
			#endif
			ServerCommand("st_mr_stop");
			delete g_hTimerExecAMR;
		}
	}		
	if (IsClientInGame(target) && GetClientTeam(target) == 2 && IsPlayerAlive(target) && !IsFakeClient(target) && !IsClientPinned(target) && !(GetEntProp(target, Prop_Send, "m_isIncapacitated")) )//&& !SDKCall(hIsStaggering, target))
	{
		#if DEBUG
		PrintToChatAll("condiciones de vivo 2");
		#endif	
		GetClientAbsOrigin(target, targetVector);
		float fHealth = GetEntPropFloat(target, Prop_Send, "m_healthBuffer");
		ConVar g_hCvarDecayRate = FindConVar("pain_pills_decay_rate");
		fHealth -= (GetGameTime() - GetEntPropFloat(target, Prop_Send, "m_healthBufferTime")) * g_hCvarDecayRate.FloatValue;
		if( fHealth < 0.0 )
			fHealth = 0.0;										
		if ((GetClientHealth(target)+RoundFloat(fHealth))>=40)
		{
			#if DEBUG
			PrintToChatAll("target tiene la vida necesaria.");
			#endif
		}else {
			ServerCommand("st_mr_stop");
			delete g_hTimerExecAMR;
			
		}
	
	}else {
			ServerCommand("st_mr_stop");
			delete g_hTimerExecAMR;
	}
}

bool isCorrectPositionsandHaveCorrectWeapons()
{
	#if DEBUG
	PrintToChatAll("isCorrectPositionsandHaveCorrectWeapons");
	#endif					
	float DISTANCESETTING = float(5);
	float DISTANCESETTINGINFECTED = float(100);
    float targetVector[3];
	float impact1[3];
    impact1[0] = -2894.811;
    impact1[1] = 3132.176;
    impact1[2] = 6.732;
	float impact2[3];
	impact2[0] = -3125.485;
    impact2[1] = 3138.832;
    impact2[2] = 10.905;
	clientinpos1=0;
	clientinpos2=0;
	//1ra posicion	
	int infected = -1;	
	bool infectedinarea=false;
	
	while( (infected = FindEntityByClassname(infected, "infected")) != INVALID_ENT_REFERENCE )
	{
		GetEntPropVector(infected, Prop_Data, "m_vecOrigin", targetVector);
		float distance = GetVectorDistance(targetVector, impact1);
		if (distance < DISTANCESETTINGINFECTED)
		{
			infectedinarea=true;
			#if DEBUG
			PrintToChatAll("infectedinarea 1");
			#endif		
			break;		
		}
	}	
	
	while( (infected = FindEntityByClassname(infected, "infected")) != INVALID_ENT_REFERENCE )
	{
		GetEntPropVector(infected, Prop_Data, "m_vecOrigin", targetVector);
		float distance = GetVectorDistance(targetVector, impact2);
		if (distance < DISTANCESETTINGINFECTED)
		{
			infectedinarea=true;
			#if DEBUG
			PrintToChatAll("infectedinarea 2");
			#endif
			break;	
		}
	}	
	
	if (!infectedinarea)
	{	
		#if DEBUG
		PrintToChatAll("no hay infectados");
		#endif					
		for (int target=1;target<=MaxClients;target++)
		{
				
			if (IsClientInGame(target) && GetClientTeam(target) == 2 && IsPlayerAlive(target) && !IsFakeClient(target) && !IsClientPinned(target) && !(GetEntProp(target, Prop_Send, "m_isIncapacitated")) )//&& !SDKCall(hIsStaggering, target))
			{
				#if DEBUG
				PrintToChatAll("condiciones de vivo 1");
				#endif	
				
				
				
				GetClientAbsOrigin(target, targetVector);
				float distance = GetVectorDistance(targetVector, impact1);
				if (distance < DISTANCESETTING)
				{
					#if DEBUG
					PrintToChatAll("Distancia Correcta %d",target);
					#endif
					static char sClass[25];
					int iWeapon = GetEntPropEnt(target, Prop_Send, "m_hActiveWeapon");
					if( iWeapon != -1 )
					{
						GetEdictClassname(iWeapon, sClass, sizeof(sClass));
						PrintToServer("Weapon si esta %d",iWeapon);
						if( strcmp(sClass[7], "grenade_launcher") == 0 )
						{
							#if DEBUG
							PrintToChatAll("Clase es grenade_launcher %s",sClass);
							#endif
							int iAmmoinClip = GetEntProp(iWeapon, Prop_Send, "m_iClip1");
							if( iAmmoinClip > 0 )
							{
								#if DEBUG
								PrintToChatAll("Si tiene balas %d",iAmmoinClip);
								#endif
								clientinpos1=target;
								/*
								int test;
								test=L4D2_OnStagger(clientinpos1,clientinpos2);
								if (test) PrintToChatAll("L4D2_OnStagger(target) test if %d",clientinpos1);
									else PrintToChatAll("L4D2_OnStagger(target) test else %d",clientinpos1);
								PrintToChatAll("L4D2_OnStagger(target) test %d",clientinpos1);		
								*/								
								//if (!g_bStagger[clientinpos1])
								//{
								#if DEBUG
								PrintToChatAll("clientinpos1 %d",clientinpos1);
								#endif							
								//}
								break;
							}
						}
					}
				}
			}
		}
	}
	if (clientinpos1!=0)
	{
		for (int target=1;target<=MaxClients;target++)
		{
						
			//if (SDKCall(hIsStaggering, target))
			//	PrintToChatAll("SDKCall(hIsStaggering, target)");
				
			if (IsClientInGame(target) && GetClientTeam(target) == 2 && IsPlayerAlive(target) && !IsFakeClient(target) && !IsClientPinned(target) && !(GetEntProp(target, Prop_Send, "m_isIncapacitated")) )//&& !SDKCall(hIsStaggering, target))
			{
				#if DEBUG
				PrintToChatAll("condiciones de vivo 2");
				#endif	
				if(target != clientinpos1)
				{
					GetClientAbsOrigin(target, targetVector);
					float distance = GetVectorDistance(targetVector, impact2);
					if (distance < DISTANCESETTING)
					{
						#if DEBUG
						PrintToChatAll("Distancia Correcta %d",target);
						#endif
						float fHealth = GetEntPropFloat(target, Prop_Send, "m_healthBuffer");
						ConVar g_hCvarDecayRate = FindConVar("pain_pills_decay_rate");
						fHealth -= (GetGameTime() - GetEntPropFloat(target, Prop_Send, "m_healthBufferTime")) * g_hCvarDecayRate.FloatValue;
						if( fHealth < 0.0 )
							fHealth = 0.0;										
						if ((GetClientHealth(target)+RoundFloat(fHealth))>=40)
						{
							clientinpos2=target;			
							#if DEBUG
							PrintToChatAll("clientinpos2 tiene la vida necesaria.");
							#endif
							//if (!g_bStagger[clientinpos2])
							//{
							#if DEBUG
							PrintToChatAll("clientinpos2 %d",clientinpos2);
							#endif							
							//}
							break;
						}
					}
				}
			}
		}
	}
	if ((clientinpos1!=0) && (clientinpos2!=0))
	{
		#if DEBUG
		PrintToChatAll("Cumplio condiciones");
		#endif
		return true;
	}
	return false;
}




/**
 * Config Parser
 */
public SMCResult ReadConfig_EndSection(SMCParser smc) {}

public SMCResult ReadConfig_KeyValue(SMCParser smc, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	if (!g_bSection || !key[0])
		return SMCParse_Continue;

	int iType;
	char sKeys[2][32];
	ExplodeString(key, ":", sKeys, sizeof(sKeys), sizeof(sKeys[]));
	if (!g_hTypes.GetValue(sKeys[0], iType))
		return SMCParse_Continue;

	g_hTries[iType].SetString(sKeys[1], value);
	if (iType == EVENT)
		HookEvent(sKeys[1], Event_Hook);

	return SMCParse_Continue;
}

public SMCResult ReadConfig_NewSection(SMCParser smc, const char[] name, bool opt_quotes)
{
	g_bSection = StrEqual(name, "*") || strncmp(g_sMap, name, strlen(name), false) == 0;
}


/**
 * Stocks
 */
void ExecClientsConfig(int iClients)
{
	if (!g_hEnabled.BoolValue)
		return;

	bool bIncludeBots = g_hIncludeBots.BoolValue;
	bool bIncludeSpec = g_hIncludeSpec.BoolValue;
	if (bIncludeBots && bIncludeSpec)
		iClients += GetClientCount();
	else
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i))
				continue;

			bool bBot  = IsFakeClient(i);
			bool bSpec = IsClientObserver(i);
			if ((!bBot && !bSpec) ||
				(bIncludeBots && bBot) ||
				(bIncludeSpec && bSpec))
				iClients++;
		}
	}

	char sClients[4];
	IntToString(iClients, sClients, sizeof(sClients));
	ExecConfig(CLIENTS, sClients);
}

void ExecConfig(int iType, const char[] sKey)
{
	char sValue[64];
	if (!g_hTries[iType].GetString(sKey, sValue, sizeof(sValue)))
		return;

	char sValues[2][32];
	ExplodeString(sValue, ":", sValues, sizeof(sValues), sizeof(sValues[]));

	DataPack hPack = new DataPack();
	hPack.WriteCell(iType);
	hPack.WriteString(sValues[1]);
	g_hTimers[iType] = CreateTimer(StringToFloat(sValues[0]), Timer_ExecConfig, hPack, TIMER_DATA_HNDL_CLOSE|TIMER_FLAG_NO_MAPCHANGE);
}

public Action ExecConfigCmd(int client, int args)
{

	//if( client == 0 )
	//{
		//PrintToConsole(client, "[Prueba] Command can only be used %s", IsDedicatedServer() ? "in game on a dedicated server." : "in chat on a Listen server.");
	//	return Plugin_Handled;
	//}

	char sCmd[256];
	GetCmdArgString(sCmd, sizeof(sCmd));

	StripQuotes(sCmd);

	
	
	//char sValue[64];
	//if (!g_hTries[iType].GetString(sKey, sValue, sizeof(sValue)))
	//	return;

	//char sValues[2][32];
	//ExplodeString(sValue, ":", sValues, sizeof(sValues), sizeof(sValues[]));
	int iType=EVENT;
	DataPack hPack = new DataPack();
	hPack.WriteCell(iType);
	hPack.WriteString(sCmd);
	g_hTimers[iType] = CreateTimer(0.1, Timer_ExecConfigCommand, hPack, TIMER_DATA_HNDL_CLOSE|TIMER_FLAG_NO_MAPCHANGE);
	
	
	return Plugin_Handled;
}

void ParseConfig()
{
	if (!FileExists(g_sConfigFile))
		SetFailState("File Not Found: %s", g_sConfigFile);

	for (int i = 0; i < TOTAL; i++)
		g_hTries[i].Clear();

	SMCError iError = g_hConfigParser.ParseFile(g_sConfigFile);
	if (iError)
	{
		char sError[64];
		if (g_hConfigParser.GetErrorString(iError, sError, sizeof(sError)))
			LogError(sError);
		else
			LogError("Fatal parse error");
		return;
	}
}


bool IsClientPinned(int client)
{
	if( GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0 ||
		GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0
	) return true;

	if( g_bLeft4Dead2 &&
	(
		GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0 ||
		GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0 ||
		GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0
	)) return true;

	return false;
}



public Action verifyStagger (Event event, const char[] name, bool dontBroadcast)
{
	int id = GetClientOfUserId(event.GetInt("userid"));
	#if DEBUG
	PrintToChatAll("verifyStagger evento %s, jugador %d",name,id);
	#endif
	g_bStagger[id]=true;
	RequestFrame(Stagger,id);
	
	if( id && IsClientInGame(id) )
		AnimHookEnable(id, OnAnim, OnAnimPost);
	

	//ServerCommand("st_mr_stop");
}



void Stagger(int i)
{
	if (g_bStagger[i])
	{		
		g_bStagger[i]=false;
		#if DEBUG
		PrintToChatAll("Staggereado, pasar a no staggereado %d",i);
		#endif
	}
	else
	{
		g_bStagger[i]=true;
		#if DEBUG
		PrintToChatAll("No Staggereado, pasar a staggereado %d",i);
		#endif
	}
}

public Action Timer_DetectAnim(Handle timer,int target)
{
	
		#if DEBUG
		PrintToChatAll("Anim %d",animtest);
		#endif
	
}
// Uses "Activity" numbers, which means 1 animation number is the same for all Survivors.
Action OnAnim(int client, int &anim)
{
	// /*
	//if( g_bCrawling )
	//{	
	animtest = anim;	
	//anim = g_bLeft4Dead2 ? 696 : 1197;
	//#if DEBUG
	//PrintToChatAll("anim after %d",anim);
	//#endif
	return Plugin_Continue;
	//}
	// */

	//return Plugin_Continue;
}

// Uses "m_nSequence" animation numbers, which are different for each model.
Action OnAnimPost(int client, int &anim)
{
	/*
	if( g_bCrawling )
	{
		static char model[40];
		GetEntPropString(client, Prop_Data, "m_ModelName", model, sizeof(model));

		switch( model[29] )
		{
			// case 'c': { Format(model, sizeof(model), "coach");		anim = -1; }
			case 'b': { Format(model, sizeof(model), "gambler");	anim = 631; }
			case 'h': { Format(model, sizeof(model), "mechanic");	anim = 636; }
			case 'd': { Format(model, sizeof(model), "producer");	anim = 639; }
			case 'v': { Format(model, sizeof(model), "NamVet");		anim = 539; }
			case 'e': { Format(model, sizeof(model), "Biker");		anim = 542; }
			case 'a': { Format(model, sizeof(model), "Manager");	anim = 539; }
			case 'n': { Format(model, sizeof(model), "TeenGirl");	anim = 529; }
		}

		return Plugin_Changed;
	}
	// */

	return Plugin_Continue;
}
