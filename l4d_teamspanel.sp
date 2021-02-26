#include <sourcemod>
#include <sdktools>

//Define CVARS
#define MAX_SURVIVORS GetConVarInt(FindConVar("survivor_limit"))
#define MAX_INFECTED GetConVarInt(FindConVar("z_max_player_zombies"))
#define PLUGIN_VERSION "1.6.1"

// Sdk calls
new Handle:gConf = INVALID_HANDLE;
new Handle:fSHS = INVALID_HANDLE;
new Handle:fTOB = INVALID_HANDLE;

//Handles
new Handle:cc_plpOnConnect = INVALID_HANDLE;
new Handle:cc_plpTimer = INVALID_HANDLE;
new Handle:cc_plpAutoRefreshPanel = INVALID_HANDLE;
new Handle:cc_plpPaSTimer = INVALID_HANDLE;
new Handle:cc_plpPaShowscores = INVALID_HANDLE;
new Handle:cc_plpAnnounce = INVALID_HANDLE;
new Handle:cc_plpSelectTeam = INVALID_HANDLE;
new Handle:cc_plpHintStatic = INVALID_HANDLE;
new Handle:cc_plpSpectatorSelect = INVALID_HANDLE;
new Handle:cc_plpSurvivorSelect = INVALID_HANDLE;
new Handle:cc_plpInfectedSelect = INVALID_HANDLE;
new Handle:cc_plpShowBots = INVALID_HANDLE;

//Strings
new String:hintText[2048];

//CVARS
new plpOnConnect;
new plpTimer;
new plpPaSTimer;
new plpAutoRefreshPanel;
new plpPaShowscores;
new plpAnnounce;
new plpSelectTeam;
new plpHintStatic;
new plpSpectatorSelect;
new plpSurvivorSelect;
new plpInfectedSelect;
new plpShowBots;
new ClientAutoRefreshPanel[33];
new wantedrefresh[33];
new hintstatic[33];
new maxcl;

//Plugin Info Block
public Plugin:myinfo =
{
	name = "Playerlist Panel",
	author = "OtterNas3",
	description = "Shows Panel for Teams on Server",
	version = PLUGIN_VERSION,
	url = "http://www.sourcemod.net/"
};

//Plugin start
public OnPluginStart()
{
	//Load Translation file
	LoadTranslations("l4d_teamspanel.phrases");
	
	//SDK Calls (copied, credits to L4DSwitchPlayers)
	gConf = LoadGameConfigFile("l4dteamspanel");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gConf, SDKConf_Signature, "SetHumanSpec");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	fSHS = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gConf, SDKConf_Signature, "TakeOverBot");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	fTOB = EndPrepSDKCall();
	

	//Reg Commands
	RegConsoleCmd("sm_teams", PrintTeamsToClient);

	//Reg Cvars
	CreateConVar("l4d_plp_version", PLUGIN_VERSION, "Playerlist Panel Display Version", FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	cc_plpOnConnect = CreateConVar("l4d_plp_onconnect", "1", "Show Playerlist Panel on connect?");
	cc_plpTimer = CreateConVar("l4d_plp_timer", "20", "How long, in seconds, the Playerlist Panel stay before it close automatic");
	cc_plpAutoRefreshPanel = CreateConVar("l4d_plp_autorefreshpanel", "0", "Should the Panel be static & refresh itself every second?");
	cc_plpPaShowscores = CreateConVar("l4d_plp_pashowscores", "0", "Show Playerlist Panel after Showscores? NO REFRESH!");
	cc_plpPaSTimer = CreateConVar("l4d_plp_pastimer", "5", "How long, in seconds, the Playerlist Panel stay after Showscores \nIf l4d_plp_pashowscores is = 1");
	cc_plpAnnounce = CreateConVar("l4d_plp_announce", "1", "Show Hint-Message about the command to players on Spectator?");
	cc_plpSelectTeam = CreateConVar ("l4d_plp_select_team", "1", "Should the user be able to select a team on Playerlist Panel?");
	cc_plpHintStatic = CreateConVar ("l4d_plp_hint_static", "0", "Should the Hint for Panel options be Static?");
	cc_plpSpectatorSelect = CreateConVar ("l4d_plp_select_team_spectator", "1", "If l4d_plp_select_team = 1 \nShould the Spectator selection be functional?");
	cc_plpSurvivorSelect = CreateConVar ("l4d_plp_select_team_survivor", "1", "If l4d_plp_select_team = 1 \nShould the Survivor selection be functional?");
	cc_plpInfectedSelect = CreateConVar ("l4d_plp_select_team_infected", "1", "If l4d_plp_select_team = 1 \nShould the Infected selection be functional?");
	cc_plpShowBots = CreateConVar ("l4d_plp_show_bots", "1", "Should bots be listed in Panel?");
	
	//Execute the config file
	AutoExecConfig(true, "l4d_teamspanel");

	//Hook Cvars
	HookConVarChange(cc_plpOnConnect, ConVarChanged);
	HookConVarChange(cc_plpTimer, ConVarChanged);
	HookConVarChange(cc_plpAutoRefreshPanel, ConVarChanged);
	HookConVarChange(cc_plpPaSTimer, ConVarChanged);
	HookConVarChange(cc_plpPaShowscores, ConVarChanged);
	HookConVarChange(cc_plpAnnounce, ConVarChanged);
	HookConVarChange(cc_plpSelectTeam, ConVarChanged);
	HookConVarChange(cc_plpHintStatic, ConVarChanged);
	HookConVarChange(cc_plpSpectatorSelect, ConVarChanged);
	HookConVarChange(cc_plpSurvivorSelect, ConVarChanged);
	HookConVarChange(cc_plpInfectedSelect, ConVarChanged);
	HookConVarChange(cc_plpShowBots, ConVarChanged);
	
	//Build Hint Text depending on cvars
	HintText();
	
	//Checking !REAL! MaxClients
	maxcl = maxclToolzDowntownCheck();
	
	//Re read CVARS
	ReadCvars();
}

//Search for running L4DToolz and/or L4Downtown (or none of them) to get correct Max Clients
maxclToolzDowntownCheck()
{
	new Handle:invalid = INVALID_HANDLE;
	new Handle:downtownrun = FindConVar("l4d_maxplayers");
	new Handle:toolzrun = FindConVar("sv_maxplayers");
	
	//Downtown is running!
	if (downtownrun != (invalid))
	{
		//Is Downtown used for slot patching? if yes use it for Max Players
		new downtown = (GetConVarInt(FindConVar("l4d_maxplayers")));
		if (downtown >= 1)
		{
			maxcl = (GetConVarInt(FindConVar("l4d_maxplayers")));
		}
	}

	//L4DToolz is running!
	if (toolzrun != (invalid))
	{
		//Is L4DToolz used for slot patching? if yes use it for Max Players
		new toolz = (GetConVarInt(FindConVar("sv_maxplayers")));
		if (toolz >= 1)
		{
			maxcl = (GetConVarInt(FindConVar("sv_maxplayers")));
		}
	}

	//No Downtown or L4DToolz running using fallback (possible x/32)
	if (downtownrun == (invalid) && toolzrun == (invalid))
	{
		maxcl = (MaxClients);
	}
	return maxcl;
}

//Prepare & Print Playerlist Panel
public BuildPrintPanel(client)
{
	//Get correct Max Clients
	maxcl = maxclToolzDowntownCheck();

	//Build panel
	new Handle:TeamPanel = CreatePanel();
	SetPanelTitle(TeamPanel, "\x04Playerlist Panel");
	DrawPanelText(TeamPanel, " \n");
	new count;
	new i, sumall, sumspec, sumsurv, suminf;
	new String:text[64];

	//Counting
	sumall = CountAllHumanPlayers();
	sumspec = CountPlayersTeam(1);
	sumsurv = CountPlayersTeam(2);
	suminf = CountPlayersTeam(3)
	
	
	//Draw Spectators count line
	Format(text, sizeof(text), "\x04Spectators \x03(%d of %d) \x01\n", sumspec, sumall);
	
	//Slectable Spectators or not
	if (plpSelectTeam == 1)
	{
		DrawPanelItem(TeamPanel, text);
	}
	if (plpSelectTeam == 0)
	{
		DrawPanelText(TeamPanel, text);
	}

	//Get & Draw Spectator Player Names
	count = 1;
	for (i=1;i<=MaxClients;i++)
	{
		if (IsValidPlayer(i) && GetClientTeam(i) == 1)
		{
			Format(text, sizeof(text), "%d. %N", count, i);
			DrawPanelText(TeamPanel, text);
			count++;
		}
	}
	DrawPanelText(TeamPanel, " \n");
	
	//Draw Survivors count line
	Format(text, sizeof(text), "\x04Survivors \x03(%d of %d) \x01\n", sumsurv, MAX_SURVIVORS);

	//Selectable Survivors or not
	if (plpSelectTeam == 1)
	{
		DrawPanelItem(TeamPanel, text);
	}
	if (plpSelectTeam == 0)
	{
		DrawPanelText(TeamPanel, text);
	}

	//Get & Draw Survivor Player Names
	count = 1;
	for (i=1;i<=MaxClients;i++)
	{
		if (plpShowBots > 0)
		{
			if (IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == 2)
			{
				Format(text, sizeof(text), "%d. %N", count, i);
				DrawPanelText(TeamPanel, text);
				count++;
			}
		}
		else
		{
			if (IsValidPlayer(i) && GetClientTeam(i) == 2)
			{
				Format(text, sizeof(text), "%d. %N", count, i);
				DrawPanelText(TeamPanel, text);
				count++;
			}
		}
	}
	DrawPanelText(TeamPanel, " \n");

	//Draw Infected part depending on gamemode
	//
	//Gamemode is Versus
	if (GameModeCheck() == 2)
	{
		//Draw Infected count line
		Format(text, sizeof(text), "\x04Infected \x03(%d of %d) \x01\n", suminf, MAX_INFECTED);

		//Get & Draw Infected Player Names
		if (plpSelectTeam == 1)
		{
			DrawPanelItem(TeamPanel, text);
		}
		if (plpSelectTeam == 0)
		{
			DrawPanelText(TeamPanel, text);
		}
		count = 1;
		for (i=1;i<=MaxClients;i++)
		{
			if (plpShowBots > 0)
			{
				if (IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == 3)
				{
					Format(text, sizeof(text), "%d. %N", count, i);
					DrawPanelText(TeamPanel, text);
					count++;
				}
			}
			else
			{
				if (IsValidPlayer(i) && GetClientTeam(i) == 3)
				{
					Format(text, sizeof(text), "%d. %N", count, i);
					DrawPanelText(TeamPanel, text);
					count++;
				}
			}
		}
		//Draw Total connected Players & Draw Final
		DrawPanelText(TeamPanel, " \n");
		Format(text, sizeof(text), "\x04Connected: %d/%d", sumall, maxcl);
		DrawPanelText(TeamPanel, text);
	}

	//Gamemode is Coop
	if (GameModeCheck() == 1)
	{
		//Draw Total connected Players & Draw Final
		Format(text, sizeof(text), "\x04Connected: %d/%d", sumsurv, maxcl);
		DrawPanelText(TeamPanel, text);
	}

	//Send Panel to client
	if (plpSelectTeam == 1)
	{
		SendPanelToClient(TeamPanel, client, TeamPanelHandlerB, plpTimer);
		CloseHandle(TeamPanel);
	}
	if (plpSelectTeam == 0)
	{
		SendPanelToClient(TeamPanel, client, TeamPanelHandler, plpTimer);
		CloseHandle(TeamPanel);
	}
}

//TeamPanelHandler
public TeamPanelHandler(Handle:TeamPanel, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		if (wantedrefresh[param1] == 0)
		{
			ClientAutoRefreshPanel[param1] = 0;
			hintstatic[param1] = 0;
		}
	}
	else if (action == MenuAction_Select)
	{
		if (param2 >= 1)
		{
			ClientAutoRefreshPanel[param1] = 0;
			hintstatic[param1] = 0;
		}
	}
}

//TeamPanelHandlerB
public TeamPanelHandlerB(Handle:TeamPanel, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		if (param2 == 1)
		{
			if (plpSpectatorSelect == 1)
			{
				PerformSwitch(param1, 1);
			}
			ClientAutoRefreshPanel[param1] = 0;
			hintstatic[param1] = 0;
		}
		else if (param2 == 2)
		{
			if (plpSurvivorSelect == 1)
			{
				PerformSwitch(param1, 2);
			}
			ClientAutoRefreshPanel[param1] = 0;
			hintstatic[param1] = 0;
		}
		else if (param2 == 3)
		{
			if (plpInfectedSelect == 1)
			{
				PerformSwitch(param1, 3);
			}
			ClientAutoRefreshPanel[param1] = 0;
			hintstatic[param1] = 0;
		}
	}
	else if (action == MenuAction_Cancel)
	{
		ClientAutoRefreshPanel[param1] = 0;
		hintstatic[param1] = 0;
	}
}

//Send the Panel to the Client
public Action:PrintTeamsToClient(client, args)
{
	if (plpAutoRefreshPanel == 1 && plpSelectTeam == 0)
	{
		wantedrefresh[client] = 1;
		ClientAutoRefreshPanel[client] = 1;
		if (plpHintStatic == 1)
		{
			hintstatic[client] = 1;
			CreateTimer(3.0, HintStaticTimer, client, TIMER_REPEAT);
		}
		CreateTimer(3.0, RefreshPanel, client, TIMER_REPEAT);
	}
	if (plpAutoRefreshPanel == 0)	
	{
		wantedrefresh[client] = 0;
		plpTimer = GetConVarInt(cc_plpTimer);
		if (plpSelectTeam == 1)
		{
			if (IsValidPlayer(client)) PrintHintText(client, "%s", hintText);
		}
		if (plpSelectTeam == 0)
		{
			if (IsValidPlayer(client)) PrintHintText(client, "Press '0' \nTo close the Panel!");
		}
		BuildPrintPanel(client);
	}
	if (plpAutoRefreshPanel == 1 && plpSelectTeam == 1)
	{
		wantedrefresh[client] = 0;
		plpTimer = GetConVarInt(cc_plpTimer);
		if (plpSelectTeam == 1)
		{
			if (IsValidPlayer(client)) PrintHintText(client, "%s", hintText);
		}
		if (plpSelectTeam == 0)
		{
			if (IsValidPlayer(client)) PrintHintText(client, "Press '0' \nTo close the Panel!");
		}
		BuildPrintPanel(client);
	}
	
}

//Show Announcement for !teams Command
public Action:AnnounceCommand(Handle:timer)
{
	if (plpAnnounce >0)
	{
		for(new i=1; i<=32; i++)
		{
			if (IsValidPlayer(i) && GetClientTeam(i) == 1)
			{
				PrintHintText(i, "Say !teams to see a list of Players \nThen 2 for Survivor \nOr 3 for Infected");
			}
		}
		return Plugin_Continue;
	}
	return Plugin_Stop;
}

//Dow we Show Panel On Connect? (on by default)
public Action:OnConnect(Handle:timer, any:client)
{
	if (plpOnConnect == 1 && ClientAutoRefreshPanel[client] == 1)
	{
		if (plpSelectTeam == 1)
		{
			hintstatic[client] = 0;
			plpTimer = GetConVarInt(cc_plpTimer);
		}
		else
		{
			plpTimer = 0;
		}
		CreateTimer(3.0, RefreshPanel, client, TIMER_REPEAT);
		if (plpSelectTeam == 0 && plpHintStatic == 1)
		{
			hintstatic[client] = 1;
			CreateTimer(4.0, HintStaticTimer, client, TIMER_REPEAT);
		}
		if (plpHintStatic == 0)
		{
			hintstatic[client] = 0;
			CreateTimer(4.0, HintStaticTimer, client, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	if (plpOnConnect == 1 && ClientAutoRefreshPanel[client] == 0)
	{
		hintstatic[client] = 0;
		wantedrefresh[client] = 0;
		plpTimer = GetConVarInt(cc_plpTimer);
		if (plpSelectTeam == 1)
		{
			if (IsValidPlayer(client)) PrintHintText(client, "%s", hintText);
		}
		if (plpSelectTeam == 0)
		{
			if (IsValidPlayer(client)) PrintHintText(client, "Press '0' \nTo close the Panel!");
		}
		BuildPrintPanel(client);
	}
}

//HintStatic Timer
public Action:HintStaticTimer(Handle:Timer, any:client)
{
	if (hintstatic[client] == 1)
	{
		if (IsValidPlayer(client)) PrintHintText(client, "Press '0' \nTo close the Panel!");
	}
	return Plugin_Stop;
}

//Refreshing Panel Timer
public Action:RefreshPanel(Handle:Timer, any:client)
{
	if (ClientAutoRefreshPanel[client] == 1)
	{
		if (plpSelectTeam == 1)
		{
			plpTimer = GetConVarInt(cc_plpTimer);
		}
		else
		{
			plpTimer = 0;
		}
		BuildPrintPanel(client);
		return Plugin_Continue;
	}
	return Plugin_Stop;
}

//Check if Player fresh connected
public OnClientPostAdminCheck(client)
{
	if (IsValidPlayer(client) && plpAutoRefreshPanel == 1)
	{
		ClientAutoRefreshPanel[client] = 1;
		wantedrefresh[client] = 1;
	}
	if (IsValidPlayer(client) && plpAutoRefreshPanel == 0)
	{
		ClientAutoRefreshPanel[client] = 0;
		wantedrefresh[client] = 0;
	}
	//Only show Playerlist Panel to "new" connected Players
	if (IsValidPlayer(client) && GetClientTime(client) <= 120)
	{
		CreateTimer(5.0, OnConnect, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

//Client Disconnects
public OnClientDisconnect(client)
{
	if (IsValidPlayer(client))
	{
		ClientAutoRefreshPanel[client] = 0;
		wantedrefresh[client] = 0;
		hintstatic[client] = 0;
	}
}

//Gamemode Check
GameModeCheck()
{
	new GameMode = 0;
	new String:gamemodecvar[16];
	GetConVarString(FindConVar("mp_gamemode"), gamemodecvar, sizeof(gamemodecvar));
	if (StrContains(gamemodecvar, "versus", false) != -1 || StrContains(gamemodecvar, "mutation12", false) != -1 || StrContains(gamemodecvar, "scavenge", false) != -1)
	{
		GameMode = 2;
		return GameMode;
	}
	if (StrContains(gamemodecvar, "coop", false) != -1 || StrContains(gamemodecvar, "survival", false) != -1)
	{
		GameMode = 1;
		return GameMode;
	}
	return GameMode;
}

//Cvar changed check
public ConVarChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	ReadCvars();
}

//Re-Read Cvars
public ReadCvars()
{
	plpAutoRefreshPanel=GetConVarInt(cc_plpAutoRefreshPanel);
	plpHintStatic=GetConVarInt(cc_plpHintStatic);
	plpSelectTeam=GetConVarInt(cc_plpSelectTeam);
	plpSpectatorSelect=GetConVarInt(cc_plpSpectatorSelect);
	plpSurvivorSelect=GetConVarInt(cc_plpSurvivorSelect);
	plpInfectedSelect=GetConVarInt(cc_plpInfectedSelect);
	plpOnConnect=GetConVarInt(cc_plpOnConnect);
	plpPaSTimer=GetConVarInt(cc_plpPaSTimer);
	plpAnnounce=GetConVarInt(cc_plpAnnounce);
	plpPaShowscores=GetConVarInt(cc_plpPaShowscores);
	plpTimer=GetConVarInt(cc_plpTimer);
	plpShowBots=GetConVarInt(cc_plpShowBots);
	HintText();
}

//Show Playerlist Panel after Scoreboard
public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3])
{
	//Check if its a valid player
	if (!IsValidPlayer(client)) return;
	if (plpPaShowscores == 1)
	{
		if (buttons & IN_SCORE)
		{
			wantedrefresh[client] = 0;
			ClientAutoRefreshPanel[client] = 0;
			plpTimer = plpPaSTimer;
			if (plpSelectTeam == 1)
			{
				if (IsValidPlayer(client)) PrintHintText(client, "%s", hintText);
			}
			if (plpSelectTeam == 0)
			{
				if (IsValidPlayer(client)) PrintHintText(client, "Press '0' \nTo close the Panel!");
			}
			if (IsValidPlayer(client))
			{
				BuildPrintPanel(client);
			}
		}
	}  
}  

//Check of Full Teams (copied, credits to L4DSwitchPlayers)
bool:IsTeamFull (team)
{
	// Spectator's team is never full :P
	if (team == 1)
		return false;
	
	new max;
	new count;
	new i;
	
	// we count the players in the survivor's team
	if (team == 2)
	{
		max = MAX_SURVIVORS;
		count = 0;
		for (i=1;i<=MaxClients;i++)
			if (IsValidPlayer(i) && GetClientTeam(i)==2)
				count++;
		}
	else if (team == 3) // we count the players in the infected's team
	{
		max = MAX_INFECTED;
		count = 0;
		for (i=1;i<=MaxClients;i++)
			if (IsValidPlayer(i) && GetClientTeam(i)==3)
				count++;
		}
	
	// If full ...
	if (count >= max)
		return true;
	else
	return false;
}

//Do switching of Client (copied and edited, credits to L4DSwitchPlayers)
PerformSwitch (client, team)
{
	if (!IsValidPlayer(client))
	{
		return;
	}
	
	// If teams are the same ...
	if (GetClientTeam(client) == team)
	{
		PrintToChat(client, "Hello? You are already on that team!");
		return;
	}
	
	// If we should check if teams are fulll ...
	// We check if target team is full...
	if (IsTeamFull(team))
	{
		if (team == 2)
		{
			PrintToChat(client, "The \x03Survivor\x01's team is already full.");
		}
		if (team == 3)
		{
			PrintToChat(client, "The \x03Infected\x01's team is already full.");
		}
		return;
	}
	
	// If player was on infected .... 
	if (GetClientTeam(client) == 3)
	{
		// ... and he wasn't a tank ...
		new String:iClass[100];
		GetClientModel(client, iClass, sizeof(iClass));
		if (StrContains(iClass, "hulk", false) == -1)
			ForcePlayerSuicide(client);	// we kill him
	}
	
	// If target is survivors .... we need to do a little trick ....
	if (team == 1 || team == 3)// We change it's team ...
	{
		ChangeClientTeam(client, team);
	}
	if (team == 2)
	{
		// first we switch to spectators ..
		ChangeClientTeam(client, 1); 
		
		// Search for an empty bot
		for (new bot=0;bot<=32;bot++)
		{
			if (bot && IsClientConnected(bot) && IsFakeClient(bot) && (GetClientTeam(bot) == 2))
			{
				// force player to spec humans
				SDKCall(fSHS, bot, client); 
		
				// force player to take over bot
				SDKCall(fTOB, client, true);
				return;
			}
		}	
	}
}

//Hint Text
public HintText()
{
	//Define text parts
	new String:specTextOn[] = "1 to join Spectator";
	new String:specTextOff[] = "Spec = !spectate";
	new String:survTextOn[] = "2 to join Survivor";
	new String:survTextOff[] = "Survivor = !jointeam2";
	new String:infTextOn[] = "3 to join Infected";
	new String:infTextOff[] = "Infected = !jointeam3";
	new String:secondLine[] = "\nPress '0' to just close the Panel!"
	
	//Check selectable switches and format text
	if (plpSpectatorSelect == 1 && plpSurvivorSelect == 1 && plpInfectedSelect == 1)
	{
		Format(hintText, 255, "%s | %s | %s%s", specTextOn, survTextOn, infTextOn, secondLine);
	}
	if (plpSpectatorSelect == 1 && plpSurvivorSelect == 0 && plpInfectedSelect == 0)
	{
		Format(hintText, 255, "%s | %s | %s%s", specTextOn, survTextOff, infTextOff, secondLine);
	}
	if (plpSpectatorSelect == 1 && plpSurvivorSelect == 1 && plpInfectedSelect == 0)
	{
		Format(hintText, 255, "%s | %s | %s%s", specTextOn, survTextOn, infTextOff, secondLine);
	}
	if (plpSpectatorSelect == 1 && plpSurvivorSelect == 0 && plpInfectedSelect == 1)
	{
		Format(hintText, 255, "%s | %s | %s%s", specTextOn, survTextOff, infTextOn, secondLine);
	}
	if (plpSpectatorSelect == 0 && plpSurvivorSelect == 1 && plpInfectedSelect == 1)
	{
		Format(hintText, 255, "%s | %s | %s%s", specTextOff, survTextOn, infTextOn, secondLine);
	}
	if (plpSpectatorSelect == 0 && plpSurvivorSelect == 1 && plpInfectedSelect == 0)
	{
		Format(hintText, 255, "%s | %s | %s%s", specTextOff, survTextOn, infTextOff, secondLine);
	}
	if (plpSpectatorSelect == 0 && plpSurvivorSelect == 0 && plpInfectedSelect == 1)
	{
		Format(hintText, sizeof(hintText), "%s | %s | %s %s", specTextOff, survTextOff, infTextOn, secondLine);
	}
}

//Event Map Start
public OnMapStart()
{
	if (plpAnnounce >= 1)
	{
		CreateTimer(15.0, AnnounceCommand, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

//Is Valid Player
public IsValidPlayer(client)
{
	if (!IsValidClient(client))
		return false;
	
	if (IsFakeClient(client))
		return false;
	
	return true;
}

bool IsValidClient(int client)
{
    return (1 <= client <= MaxClients && IsClientInGame(client));
}

//Count all Players
public CountAllHumanPlayers()
{
	new Count = 0;
	for (new i=1;i<=MaxClients;i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
		{
			Count++;
		}
	}
	return Count;
}

//Count Players Team
public CountPlayersTeam(team)
{
	new Count = 0;
	for (new i=1;i<=MaxClients;i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == team)
		{
			Count++;
		}
	}
	return Count;
}

//End of Plugin
