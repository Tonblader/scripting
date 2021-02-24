#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma semicolon 1
#pragma newdecls required
#define L4D2 Unstoppable Charger
#define PLUGIN_VERSION "1.2"

#define STRING_LENGTH								56
#define ZOMBIECLASS_CHARGER 						6

char GAMEDATA_FILENAME[] 			= "l4d2_viciousplugins";
char VELOCITY_ENTPROP[]				= "m_vecVelocity";
char CHARGER_WEAPON[]				= "weapon_charger_claw";
float SLAP_VERTICAL_MULTIPLIER			= 1.5;
int laggedMovementOffset = 0;

// ===========================================
// Charger Setup
// ===========================================

// =================================
// Broken Ribs
// =================================

//Bools
bool isBrokenRibs = false;

//Handles
Handle cvarBrokenRibs;
Handle cvarBrokenRibsChance;
Handle cvarBrokenRibsDamage;
Handle cvarBrokenRibsDuration;
Handle cvarBrokenRibsTimer[MAXPLAYERS + 1];

// =================================
// Extinguishing Wind
// =================================

//Bools
bool isExtinguishingWind = false;

//Handles
Handle cvarExtinguishingWind;

// =================================
// Intertia Vault
// =================================

//Bools
bool isInertiaVault = false;

//Handles
Handle cvarInertiaVault;
Handle cvarInertiaVaultPower;
int brokenribs[MAXPLAYERS+1];

// =================================
// Locomotive
// =================================

//Bools
bool isLocomotive = false;

//Handles
Handle cvarLocomotive;
Handle cvarLocomotiveDuration;
Handle cvarLocomotiveSpeed;

// =================================
// Meteor Fist
// =================================

//Bools
bool isMeteorFist = false;

//Handles
Handle cvarMeteorFist;
Handle cvarMeteorFistPower;
Handle cvarMeteorFistCooldown;

//Floats
float lastMeteorFist[MAXPLAYERS+1] = 0.0;

// =================================
// Snapped Leg
// =================================

//Bools
bool isSnappedLeg = false;

//Handles
Handle cvarSnappedLeg;
Handle cvarSnappedLegChance;
Handle cvarSnappedLegDuration;
Handle cvarSnappedLegTimer[MAXPLAYERS + 1];
Handle cvarSnappedLegSpeed;

// =================================
// Stowaway
// =================================

//Bools
bool isStowAway = false;

//Handles
Handle cvarStowaway;
Handle cvarStowawayDamage;
Handle cvarStowawayTimer[MAXPLAYERS + 1];
int stowaway[MAXPLAYERS+1];

// =================================
// Survivor Aegis
// =================================

//Bools
bool isSurvivorAegis = false;

//Handles
Handle cvarSurvivorAegis;
Handle cvarSurvivorAegisAmount;
Handle cvarSurvivorAegisDamage;

// =================================
// Void Chamber
// =================================

//Bools
bool isVoidChamber = false;

//Handles
Handle cvarVoidChamber;
Handle cvarVoidChamberPower;
Handle cvarVoidChamberDamage;
Handle cvarVoidChamberRange;


// ===========================================
// Generic Setup
// ===========================================

//Bools
bool isCarried[MAXPLAYERS+1] = false;
bool isCharging[MAXPLAYERS+1] = false;
bool isSlowed[MAXPLAYERS+1] = false;
bool buttondelay[MAXPLAYERS+1] = false;

//Handles
Handle PluginStartTimer;
Handle cvarResetDelayTimer[MAXPLAYERS+1];
Handle sdkCallFling;
Handle ConfigFile;

// ===========================================
// Plugin Info
// ===========================================

public Plugin myinfo = 
{
    name = "[L4D2] Unstoppable Charger",
    author = "Mortiegama",
    description = "Allows for unique Charger abilities to bring fear to this titan.",
    version = PLUGIN_VERSION,
    url = "https://forums.alliedmods.net/showthread.php?p=2092125#post2092125"
}

	//Special Thanks:
	//AtomicStryker - Boomer Bit** Slap:
	//https://forums.alliedmods.net/showthread.php?t=97952
	
	//AtomicStryker - Damage Mod (SDK Hooks):
	//https://forums.alliedmods.net/showthread.php?p=1184761
	
	//Karma - Tank Skill Roar
	//https://forums.alliedmods.net/showthread.php?t=126919

// ===========================================
// Plugin Start
// ===========================================

public void OnPluginStart()
{
	CreateConVar("l4d_ucm_version", PLUGIN_VERSION, "Unstoppable Charger Version", FCVAR_SPONLY|FCVAR_DONTRECORD|FCVAR_NOTIFY);

	// ======================================
	// Charger Ability: Broken Ribs
	// ======================================
	cvarBrokenRibs = CreateConVar("l4d_ucm_brokenribs", "1", "Enables Broken Ribs ability: Due to the Charger's crushing grip, Survivors may have their ribs broken as a result of pummeling. (Def 1)");
	cvarBrokenRibsChance = CreateConVar("l4d_ucm_brokenribschance", "100", "Chance that after a pummel ends the Survivor takes damage over time (100 = 100%). (Def 100)");
	cvarBrokenRibsDuration = CreateConVar("l4d_ucm_brokenribsduration", "10", "For how many seconds should the Broken Ribs cause damage. (Def 10)");
	cvarBrokenRibsDamage = CreateConVar("l4d_ucm_brokenribsdamage", "1", "How much damage is inflicted by Broken Ribs each second. (Def 1)");

	// ======================================
	// Charger Ability: Extinguishing Wind
	// ======================================
	cvarExtinguishingWind = CreateConVar("l4d_ucm_extinguishingwind", "1", "Enables Extinguish Wind ability: The force of wind the Charger creates while charging is capable of extinguishing flames on his body. (Def 1)");
	
	// ======================================
	// Charger Ability: Inertia Vault
	// ======================================
	cvarInertiaVault = CreateConVar("l4d_ucm_inertiavault", "1", "Enables Inertia Vault ability: While charging the Charger has the ability to leap into the air and travel a short distance. (Def 1)");
	cvarInertiaVaultPower = CreateConVar("l4d_ucm_inertiavaultpower", "400.0", "Power behind the Charger's jump. (Def 400.0)");
	
	// ======================================
	// Charger Ability: Locomotive
	// ======================================
	cvarLocomotive = CreateConVar("l4d_ucm_locomotive", "1", "Enables Locomotive ability: While charging, the Charger is able to increase speed and duration the longer it doesn't hit anything. (Def 1)");
	cvarLocomotiveSpeed = CreateConVar("l4d_ucm_locomotivespeed", "1.4", "Multiplier for increase in Charger speed. (Def 1.4)");
	cvarLocomotiveDuration = CreateConVar("l4d_ucm_locomotiveduration", "4.0", "Amount of time for which the Charger continues to run. (Def 4.0)");

	// ======================================
	// Charger Ability: Meteor Fist
	// ======================================
	cvarMeteorFist = CreateConVar("l4d_ucm_meteorfist", "1", "Enables Meteor Fist ability: Utilizing his overally muscular arm, when the Charger strikes a Survivor while charging or with his fist, they are sent flying. (Def 1)");
	cvarMeteorFistPower = CreateConVar("l4d_ucm_meteorfistpower", "200.0", "Power behind the Charger's Meteor Fist. (Def 200.0)");
	cvarMeteorFistCooldown = CreateConVar("l4d_ucm_meteorfistcooldown", "10.0", "Amount of time between Meteor Fists. (Def 10.0)");
	
	// ======================================
	// Charger Ability: Snapped Leg
	// ======================================
	cvarSnappedLeg = CreateConVar("l4d_ucm_snappedleg", "1", "Enables Snapped Leg ability: When the Charger collides with a Survivor, it snaps their leg causing them to move slower. (Def 1)");
	cvarSnappedLegChance = CreateConVar("l4d_ucm_snappedlegchance", "100", "Chance that after a charger collision movement speed is reduced. (Def 1)");
	cvarSnappedLegDuration = CreateConVar("l4d_ucm_snappedlegduration", "5", "For how many seconds will the Snapped Leg reduce movement speed (100 = 100%). (Def 100)");
	cvarSnappedLegSpeed = CreateConVar("l4d_ucm_snappedlegspeed", "0.5", "How much does Snapped Leg reduce movement speed. (Def 0.5)");
	
	// ======================================
	// Charger Ability: Stowaway
	// ======================================
	cvarStowaway = CreateConVar("l4d_ucm_stowaway", "1", "Enables Stowaway ability: The longer the Charger has a Survivor, the more damage adds the Charger will deal when the charge comes to an end. (Def 1)");
	cvarStowawayDamage = CreateConVar("l4d_ucm_stowawaydamage", "5", "How much damage is inflicted by Stowaway for each second carried. (Def 5)");
	
	// ======================================
	// Charger Ability: Survivor Aegis
	// ======================================
	cvarSurvivorAegis = CreateConVar("l4d_ucm_survivoraegis", "1", "Enables Survivor Aegis ability: While charging, the Charger will use the Survivor as an Aegis to absorb damage it would receive.  (Def 1)");
	cvarSurvivorAegisAmount = CreateConVar("l4d_ucm_survivoraegisamount", "0.2", "Percent of damage the Charger avoids using a Survivor as an Aegis. (Def 0.2)");
	cvarSurvivorAegisDamage = CreateConVar("l4d_ucm_survivoraegisdamage", "5", "How much damage is inflicted to the Survivor being used as an Aegis. (Def 5)");
	
	// ======================================
	// Charger Ability: Void Chamber
	// ======================================
	cvarVoidChamber = CreateConVar("l4d_ucm_voidchamber", "1", "Enables Void Chamber ability: When starting a charge, the force is so powerful it sucks nearby Survivors in the void left behind. (Def 1)");
	cvarVoidChamberPower = CreateConVar("l4d_ucm_voidchamberpower", "150.0", "Power behind the inner range of Methane Blast. (Def 150.0)");
	cvarVoidChamberDamage = CreateConVar("l4d_ucm_voidchamberdamage", "10", "Damage the force of the roar causes to nearby survivors. (Def 10)");
	cvarVoidChamberRange = CreateConVar("l4d_ucm_voidchamberrange", "200.0", "Area around the Tank the bellow will reach. (Def 200.0)");

	// ======================================
	// Hook Events
	// ======================================
	HookEvent("charger_pummel_end", Event_ChargerPummelEnd);
	HookEvent("charger_impact", Event_ChargerImpact);
	HookEvent("charger_carry_start", Event_ChargerCarryStart);
	HookEvent("charger_carry_end", Event_ChargerCarryEnd);
	HookEvent("charger_charge_start", Event_ChargeStart);
	HookEvent("charger_charge_end", Event_ChargeEnd);	
	AutoExecConfig(true, "plugin.L4D2.UnstoppableCharger");
	PluginStartTimer = CreateTimer(3.0, OnPluginStart_Delayed);
	ConfigFile = LoadGameConfigFile(GAMEDATA_FILENAME);
	
	// ======================================
	// Prep SDK Calls
	// ======================================
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(ConfigFile, SDKConf_Signature, "CTerrorPlayer_Fling");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	sdkCallFling = EndPrepSDKCall();
	if (sdkCallFling == null)
	{
		SetFailState("Cant initialize Fling SDKCall");
	}
}

// ===========================================
// Plugin Start Delayed
// ===========================================

public Action OnPluginStart_Delayed(Handle timer)
{	
	if (GetConVarInt(cvarBrokenRibs))
	{
		isBrokenRibs = true;
	}
	if (GetConVarInt(cvarExtinguishingWind))
	{
		isExtinguishingWind = true;
	}
	if (GetConVarInt(cvarInertiaVault))
	{
		isInertiaVault = true;
	}
	if (GetConVarInt(cvarLocomotive))
	{
		isLocomotive = true;
		float duration = GetConVarFloat(cvarLocomotiveDuration);
		SetConVarFloat(FindConVar("z_charge_duration"), duration, false, false);
	}		
	if (GetConVarInt(cvarMeteorFist))
	{
		isMeteorFist = true;
	}
	if (GetConVarInt(cvarSnappedLeg))
	{
		isSnappedLeg = true;
	}
	if (GetConVarInt(cvarStowaway))
	{
		isStowAway = true;
	}
	if (GetConVarInt(cvarSurvivorAegis))
	{
		isSurvivorAegis = true;
	}
	if (GetConVarInt(cvarVoidChamber))
	{
		isVoidChamber = true;
	}
	laggedMovementOffset = FindSendPropInfo("CTerrorPlayer", "m_flLaggedMovementValue");
	if (PluginStartTimer != null)
	{
 		KillTimer(PluginStartTimer);
		PluginStartTimer = null;
	}
	return Plugin_Stop;
}

// ====================================================================================================================
// ===========================================                              =========================================== 
// ===========================================           CHARGER            =========================================== 
// ===========================================                              =========================================== 
// ====================================================================================================================

// ===========================================
// Charger Setup Events
// ===========================================

public void OnClientPostAdminCheck(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action Event_ChargeStart(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	// =====================================
	// Charger Ability: Extinguishing Wind
	// =====================================
	if (isExtinguishingWind)
	{
		ChargerAbility_ExtinguishingWind(client);
	}
	// =====================================
	// Charger Ability: Locomotive
	// =====================================
	if (isLocomotive)
	{
		ChargerAbility_LocomotiveStart(client);
	}
	// =====================================
	// Charger Ability: Void Chamber
	// =====================================	
	if (isVoidChamber)
	{
		ChargerAbility_VoidChamber(client);
	}
	if (IsValidClient(client))
	{
		isCharging[client] = true;
	}
}

public Action Event_ChargerCarryStart(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event,"victim"));
	// =====================================
	// Charger Ability: Stow Away
	// =====================================
	if (isStowAway)
	{
		ChargerAbility_StowawayStart(victim);
	}	
}

public Action Event_ChargerImpact(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(GetEventInt(event,"userid"));
	int victim = GetClientOfUserId(GetEventInt(event,"victim"));
	// =====================================
	// Charger Ability: Meteor Fist
	// =====================================
	if (isMeteorFist)
	{
		ChargerAbility_MeteorFist(victim, attacker);
	}
	// =====================================
	// Charger Ability: Snapped Leg
	// =====================================
	if (isSnappedLeg)
	{
		ChargerAbility_SnappedLeg(victim);
	}
}

public Action Event_ChargeEnd(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	// =====================================
	// Charger Ability: Locomotive
	// =====================================
	if (isLocomotive)
	{
		ChargerAbility_LocomotiveFinish(client);
	}
	if (IsValidClient(client))
	{
		isCharging[client] = false;
	}
}

public Action Event_ChargerCarryEnd(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event,"victim"));
	int attacker = GetClientOfUserId(GetEventInt(event,"userid"));
	// =====================================
	// Charger Ability: Stow Away
	// =====================================
	if (isStowAway)
	{
		ChargerAbility_StowawayFinish(victim, attacker);
	}
}

public Action Event_ChargerPummelEnd(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event,"victim"));
	int attacker = GetClientOfUserId(GetEventInt(event,"userid"));
	// =====================================
	// Charger Ability: Broken Ribs
	// =====================================
	if (isBrokenRibs)
	{
		ChargerAbility_BrokenRibs(victim, attacker);
	}	
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	// =====================================
	// Charger Ability: Survivor Aegis
	// =====================================
	if (isSurvivorAegis && IsValidCharger(victim) && IsValidClient(attacker) && isCharging[victim])
	{
		float damagemod = GetConVarFloat(cvarSurvivorAegisAmount);	
		if (FloatCompare(damagemod, 1.0) != 0)
		{
			damage = damage * damagemod;
		}
		ChargerAbility_SurvivorAegis(victim, attacker);
	}
	// =====================================
	// Charger Ability: Meteor Fist
	// =====================================
	if (IsValidCharger(attacker))
	{
		char classname[STRING_LENGTH];
		GetClientWeapon(attacker, classname, sizeof(classname));
		if (isMeteorFist && StrEqual(classname, CHARGER_WEAPON))
		{
			ChargerAbility_MeteorFist(victim, attacker);
			lastMeteorFist[attacker] = GetEngineTime();
		}
	}
	return Plugin_Changed;
}
// ===========================================
// Charger Ability: Broken Ribs
// ===========================================
// Description: Due to the Charger's crushing grip, Survivors may have their ribs broken as a result of pummeling.
public Action ChargerAbility_BrokenRibs(int victim, int attacker)
{
	if (IsValidClient(victim) && GetClientTeam(victim) == 2)
	{
		int BrokenRibsChance = GetRandomInt(0, 99);
		int BrokenRibsPercent = (GetConVarInt(cvarBrokenRibsChance));
		if (BrokenRibsChance < BrokenRibsPercent)
		{
			PrintHintText(victim, "The Charger broke your ribs!");
			if (brokenribs[victim] <= 0)
			{
				brokenribs[victim] = (GetConVarInt(cvarBrokenRibsDuration));
				Handle dataPack = CreateDataPack();
				cvarBrokenRibsTimer[victim] = CreateDataTimer(1.0, Timer_BrokenRibs, dataPack, TIMER_REPEAT);
				WritePackCell(dataPack, victim);
				WritePackCell(dataPack, attacker);
			}
		}
	}
}

public Action Timer_BrokenRibs(Handle timer, any dataPack) 
{
	ResetPack(dataPack);
	int victim = ReadPackCell(dataPack);
	int attacker = ReadPackCell(dataPack);
	if (IsValidClient(victim))
	{
		if (brokenribs[victim] <= 0)
		{
			if (cvarBrokenRibsTimer[victim] != null)
			{
				KillTimer(cvarBrokenRibsTimer[victim]);
				cvarBrokenRibsTimer[victim] = null;
			}
			return Plugin_Stop;
		}
		int damage = GetConVarInt(cvarBrokenRibsDamage);
		DamageHook(victim, attacker, damage);
		if (brokenribs[victim] > 0) 
		{
			brokenribs[victim] -= 1;
		}
	}
	return Plugin_Continue;
}
// ===========================================
// Charger Ability: Extinguishing Wind
// ===========================================
// Description: The force of wind the Charger creates while charging is capable of extinguishing flames on his body.
public Action ChargerAbility_ExtinguishingWind(int client)
{
	if (IsPlayerOnFire(client))
	{
		ExtinguishEntity(client);
	}
}
// ===========================================
// Charger Ability: Inertia Vault
// ===========================================
// Description: While charging the Charger has the ability to leap into the air and travel a short distance.
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (buttons & IN_JUMP && IsValidClient(client) && isCharging[client])
	{
		if (isInertiaVault && !buttondelay[client] && IsPlayerOnGround(client))
		{
			buttondelay[client] = true;
			float vec[3];
			float power = GetConVarFloat(cvarInertiaVaultPower);
			vec[0] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[0]");
			vec[1] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[1]");
			vec[2] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[2]") + power;
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vec);
			cvarResetDelayTimer[client] = CreateTimer(1.0, ResetDelay, client);
		}
	}
}

public Action ResetDelay(Handle timer, any client)
{
	buttondelay[client] = false;
	if (cvarResetDelayTimer[client] != null)
	{
		KillTimer(cvarResetDelayTimer[client]);
		cvarResetDelayTimer[client] = null;
	}
	return Plugin_Stop;
}
// ===========================================
// Charger Ability: Locomotive
// ===========================================
// Description: While charging, the Charger is able to increase speed and duration the longer it doesn't hit anything.
public Action ChargerAbility_LocomotiveStart(int client)
{
	if (IsValidCharger(client))
	{
		SetEntDataFloat(client, laggedMovementOffset, 1.0*GetConVarFloat(cvarLocomotiveSpeed), true);
	}
}

public Action ChargerAbility_LocomotiveFinish(int client)
{
	if (IsValidCharger(client))
	{
		SetEntDataFloat(client, laggedMovementOffset, 1.0, true);
	}
}
// ===========================================
// Charger Ability: Meteor Fist
// ===========================================
// Description: Utilizing his overally muscular arm, when the Charger strikes a Survivor while charging or with his fist, they are sent flying.
public Action ChargerAbility_MeteorFist(int victim, int attacker)
{
	if (IsValidCharger(attacker) && MeteorFist(attacker) && IsValidClient(victim) && GetClientTeam(victim) == 2 && !IsSurvivorPinned(victim))
	{
		float power = GetConVarFloat(cvarMeteorFistPower);
		FlingHook(victim, attacker, power);
	}
}
// ===========================================
// Charger Ability: Snapped Leg
// ===========================================
// Description: When the Charger collides with a Survivor, it snaps their leg causing them to move slower.
public Action ChargerAbility_SnappedLeg(int victim)
{
	if (IsValidClient(victim) && GetClientTeam(victim) == 2 && !isSlowed[victim])
	{
		int SnappedLegChance = GetRandomInt(0, 99);
		int SnappedLegPercent = (GetConVarInt(cvarSnappedLegChance));
		if (SnappedLegChance < SnappedLegPercent)
		{
			isSlowed[victim] = true;
			PrintHintText(victim, "The Charger's impact has broken your leg!");
			SetEntDataFloat(victim, laggedMovementOffset, GetConVarFloat(cvarSnappedLegSpeed), true);
			cvarSnappedLegTimer[victim] = CreateTimer(GetConVarFloat(cvarSnappedLegDuration), Timer_SnappedLeg, victim);
		}
	}
}

public Action Timer_SnappedLeg(Handle timer, any victim)
{
	if (IsValidClient(victim) && GetClientTeam(victim) == 2)
	{
		SetEntDataFloat(victim, laggedMovementOffset, 1.0, true);
		PrintHintText(victim, "Your leg is starting to feel better.");
		isSlowed[victim] = false;
	}
	if (cvarSnappedLegTimer[victim] != null)
	{
		KillTimer(cvarSnappedLegTimer[victim]);
		cvarSnappedLegTimer[victim] = null;
	}		
	return Plugin_Stop;	
}
// ===========================================
// Charger Ability: Stowaway
// ===========================================
// Description: The longer the Charger has a Survivor, the more damage adds the Charger will deal when the charge comes to an end.
public Action ChargerAbility_StowawayStart(int victim)
{
	if (IsValidClient(victim) && GetClientTeam(victim) == 2)
	{
		stowaway[victim] = 1;
		isCarried[victim] = true;
		cvarStowawayTimer[victim] = CreateTimer(0.5, Timer_Stowaway, victim, TIMER_REPEAT);
	}
}

public Action Timer_Stowaway(Handle timer, any client) 
{
	if (IsValidClient(client))
	{
		if (isCarried[client])
		{
			stowaway[client] += 1;
		}
		if (!isCarried[client])
		{
			if (cvarStowawayTimer[client] != null)
			{
				KillTimer(cvarStowawayTimer[client]);
				cvarStowawayTimer[client] = null;
			}
			return Plugin_Stop;	
		}
	}
	return Plugin_Continue;	
}

public Action ChargerAbility_StowawayFinish(int victim, int attacker)
{
	if (IsValidClient(victim) && GetClientTeam(victim) == 2)
	{
		isCarried[victim] = false;
		int damage = (stowaway[victim] * GetConVarInt(cvarStowawayDamage));
		DamageHook(victim, attacker, damage);
	}
}
// ===========================================
// Charger Ability: Survivor Aegis
// ===========================================
// Description: While charging, the Charger will use the Survivor as an Aegis to absorb damage it would receive. 
public Action ChargerAbility_SurvivorAegis(int victim, int attacker)
{
	int aegis = GetEntPropEnt(victim, Prop_Send, "m_carryVictim");
	if (IsValidClient(aegis))
	{
		int damage = GetConVarInt(cvarSurvivorAegisDamage);
		DamageHook(aegis, victim, damage);
	}
}
// ===========================================
// Charger Ability: Void Chamber
// ===========================================
// Description: Damages Survivor based upon amount of time carried.
public Action ChargerAbility_VoidChamber(int attacker)
{
	if (IsValidCharger(attacker))
	{
		for (int victim=1; victim<=MaxClients; victim++)
		if (IsValidClient(victim) && GetClientTeam(victim) == 2  && !IsSurvivorPinned(victim))
		{
			float chargerPos[3];
			float survivorPos[3];
			float distance;
			float range = GetConVarFloat(cvarVoidChamberRange);
			GetClientEyePosition(attacker, chargerPos);
			GetClientEyePosition(victim, survivorPos);
			distance = GetVectorDistance(survivorPos, chargerPos);
			if (distance < range)
			{
				char sRadius[256];
				char sPower[256];
				int magnitude;
				magnitude = GetConVarInt(cvarVoidChamberPower) * -1;
				IntToString(GetConVarInt(cvarVoidChamberRange), sRadius, sizeof(sRadius));
				IntToString(magnitude, sPower, sizeof(sPower));
				int exPhys = CreateEntityByName("env_physexplosion");
				DispatchKeyValue(exPhys, "radius", sRadius);
				DispatchKeyValue(exPhys, "magnitude", sPower);
				DispatchSpawn(exPhys);
				TeleportEntity(exPhys, chargerPos, NULL_VECTOR, NULL_VECTOR);
				AcceptEntityInput(exPhys, "Explode");
				float traceVec[3];
				float resultingVec[3];
				float currentVelVec[3];
				float power = GetConVarFloat(cvarVoidChamberPower);
				MakeVectorFromPoints(chargerPos, survivorPos, traceVec);
				GetVectorAngles(traceVec, resultingVec);
				resultingVec[0] = Cosine(DegToRad(resultingVec[1])) * power;
				resultingVec[1] = Sine(DegToRad(resultingVec[1])) * power;
				resultingVec[2] = power * SLAP_VERTICAL_MULTIPLIER;
				GetEntPropVector(victim, Prop_Data, "m_vecVelocity", currentVelVec);
				resultingVec[0] += currentVelVec[0];
				resultingVec[1] += currentVelVec[1];
				resultingVec[2] += currentVelVec[2];
				resultingVec[0] = resultingVec[0] * -1;
				resultingVec[1] = resultingVec[1] * -1;
				float incaptime = 3.0;
				SDKCall(sdkCallFling, victim, resultingVec, 76, attacker, incaptime);
				int damage = GetConVarInt(cvarVoidChamberDamage);
				DamageHook(victim, attacker, damage);
			}
		}
	}
}
// ====================================================================================================================
// ===========================================                              =========================================== 
// ===========================================        GENERIC CALLS         =========================================== 
// ===========================================                              =========================================== 
// ====================================================================================================================
public Action DamageHook(int victim, int attacker, int damage)
{
	float victimPos[3];
	char strDamage[16];
	char strDamageTarget[16];	
	GetClientEyePosition(victim, victimPos);
	IntToString(damage, strDamage, sizeof(strDamage));
	Format(strDamageTarget, sizeof(strDamageTarget), "hurtme%d", victim);
	int entPointHurt = CreateEntityByName("point_hurt");
	if (!entPointHurt)
	{
		return;
	}
	DispatchKeyValue(victim, "targetname", strDamageTarget);
	DispatchKeyValue(entPointHurt, "DamageTarget", strDamageTarget);
	DispatchKeyValue(entPointHurt, "Damage", strDamage);
	DispatchKeyValue(entPointHurt, "DamageType", "0");
	DispatchSpawn(entPointHurt);
	TeleportEntity(entPointHurt, victimPos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(entPointHurt, "Hurt", (attacker && attacker < MaxClients && IsClientInGame(attacker)) ? attacker : -1);
	DispatchKeyValue(entPointHurt, "classname", "point_hurt");
	DispatchKeyValue(victim, "targetname", "null");
	AcceptEntityInput(entPointHurt, "kill");
}

public Action FlingHook(int victim, int attacker, float power)
{
	float HeadingVector[3];
	float AimVector[3];
	GetClientEyeAngles(attacker, HeadingVector);	
	AimVector[0] = FloatMul(Cosine(DegToRad(HeadingVector[1])), power);
	AimVector[1] = FloatMul(Sine(DegToRad(HeadingVector[1])), power);	
	float current[3];
	GetEntPropVector(victim, Prop_Data, VELOCITY_ENTPROP, current);		
	float resulting[3];
	resulting[0] = FloatAdd(current[0], AimVector[0]);	
	resulting[1] = FloatAdd(current[1], AimVector[1]);
	resulting[2] = power * SLAP_VERTICAL_MULTIPLIER;
	float incaptime = 3.0;
	SDKCall(sdkCallFling, victim, resulting, 76, attacker, incaptime);
}

public void OnMapEnd()
{
    for (int client=1; client<=MaxClients; client++)
	{
		if (IsValidClient(client))
		{
			isCharging[client] = false;
		}
	}
}
// ====================================================================================================================
// ===========================================                              =========================================== 
// ===========================================          BOOL CALLS          =========================================== 
// ===========================================                              =========================================== 
// ====================================================================================================================
bool IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client));
}

bool MeteorFist(int slapper)
{
	return ((GetEngineTime() - lastMeteorFist[slapper]) > GetConVarFloat(cvarMeteorFistCooldown));
}

bool IsPlayerOnGround(int client)
{
	if (GetEntProp(client, Prop_Send, "m_fFlags") & FL_ONGROUND)
	{
		return true;
	}
	return false;
}

bool IsValidCharger(int client)
{
	if (IsValidClient(client))
	{
		int class = GetEntProp(client, Prop_Send, "m_zombieClass");
		if (class == ZOMBIECLASS_CHARGER)
		{
			return true;
		}
	}
	return false;
}

bool IsPlayerOnFire(int client)
{
	if (IsValidClient(client))
	{
		if (GetEntProp(client, Prop_Data, "m_fFlags") & FL_ONFIRE)
		{
			return true;
		}
	}
	return false;
}

bool IsSurvivorPinned(int client)
{
	int attacker = GetEntPropEnt(client, Prop_Send, "m_pummelAttacker");
	int attacker2 = GetEntPropEnt(client, Prop_Send, "m_carryAttacker");
	int attacker3 = GetEntPropEnt(client, Prop_Send, "m_pounceAttacker");
	int attacker4 = GetEntPropEnt(client, Prop_Send, "m_tongueOwner");
	int attacker5 = GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker");
	if ((attacker > 0 && attacker != client) || (attacker2 > 0 && attacker2 != client) || (attacker3 > 0 && attacker3 != client) || (attacker4 > 0 && attacker4 != client) || (attacker5 > 0 && attacker5 != client))
	{
		return true;
	}
	return false;
}