/**
 * vim: set ts=4 :
 * =============================================================================
 * Left 4 Downtown SourceMod Extension
 * Copyright (C) 2009 Igor "Downtown1" Smirnov.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */
#if defined _l4do_included
 #endinput
#endif
#define _l4do_included

#include <sourcemod>

/**
 * @brief Called whenever ZombieManager::SpawnTank(Vector&,QAngle&) is invoked
 * @remarks Not invoked if z_spawn tank is used and it gives a ghosted/dead player tank
 *
 * @param vector	Vector coordinate where tank is spawned
 * @param qangle	QAngle where tank will be facing
 * @return 		Pl_Handled to block tank from spawning, Pl_Continue otherwise.
 */
forward Action:L4D_OnSpawnTank(const Float:vector[3], const Float:qangle[3]);

/**
 * @brief Called whenever ZombieManager::SpawnWitch(Vector&,QAngle&) is invoked
 *
 * @param vector	Vector coordinate where witch is spawned
 * @param qangle	QAngle where witch will be facing
 * @return 		Pl_Handled to block witch from spawning, Pl_Continue otherwise.
 */
forward Action:L4D_OnSpawnWitch(const Float:vector[3], const Float:qangle[3]);

/**
 * @brief Called whenever CTerrorGameRules::ClearTeamScores(bool) is invoked
 * @remarks 	This resets the map score at the beginning of a map, and by checking 
 *                the campaign scores on a small timer you can see if they were reset as well.
 * 
 * @param newCampaign  if true then this is a new campaign, if false a new chapter
 * @return 		Pl_Handled to block scores from being cleared, Pl_Continue otherwise.
 */
forward Action:L4D_OnClearTeamScores(bool:newCampaign);

/**
 * @brief Called whenever CTerrorGameRules::SetCampaignScores(int,int) is invoked
 * @remarks The campaign scores are updated after the 2nd round is completed
 * 
 * @param scoreA  score of logical team A
 * @param scoreB  score of logical team B
 * @return 		Pl_Handled to block campaign scores from being set, Pl_Continue otherwise.
 */
forward Action:L4D_OnSetCampaignScores(&scoreA, &scoreB);

/**
 * @brief Called whenever CDirector::OnFirstSurvivorLeftSafeArea is invoked
 * @remarks A versus round is started when survivors leave the safe room, or force started
 *          after 90 seconds regardless.
 * 
 * @param client  the survivor that left the safe area first
 * 
 * @return 		Pl_Handled to block round from being started, Pl_Continue otherwise.
 */
forward Action:L4D_OnFirstSurvivorLeftSafeArea(client);

/**
 * @brief Called whenever CDirector::GetScriptValue(const char*, int) is invoked
 * @remarks A script value is map specific
 * 
 * @param key     the script's key name
 * @param retVal  what to override the return value with
 * 
 * @return 		Pl_Handled to override return value, Pl_Continue otherwise.
 */
forward Action:L4D_OnGetScriptValueInt(const String:key[], &retVal);

/**
 * @brief Called whenever CTerrorPlayer::OnEnterGhostState(CTerrorPlayer*) is invoked
 * @remarks This happens when a player enters ghost mode (or in finales auto-materialized)
 * 
 * @param client  the client that has entered ghost mode
 */
forward L4D_OnEnterGhostState(client);

/**
 * @brief Called whenever CDirector::TryOfferingTankBot is invoked
 * @remarks Is used for displaying the "X gets Tank" window and transferring Tank control
 * 
 * @return 		Pl_Handled to block window from showing and to keep Tank Bot, Pl_Continue otherwise
 */
forward Action:L4D_OnTryOfferingTankBot();

/**
 * @brief Called whenever CDirector::OnMobRushStart(void) is invoked
 * @remarks called on random hordes, mini- and finale hordes, and boomer hordes
 * @remarks not called on "z_spawn mob", hook the console command and check arguments to catch plugin mobs
 * 
 * @return 		Pl_Handled to block, Pl_Continue otherwise
 */
forward Action:L4D_OnMobRushStart();

/**
 * @brief Get the current campaign scores stored in the Director
 * @remarks The campaign scores are updated after L4D_OnSetCampaignScores
 * 
 * @deprecated This will set the scores to -1 for both sides on L4D2,
 *               this function is no longer supported.
 * 
 * @param scoreA  score of logical team A
 * @param scoreB  score of logical team B
 * @return 		1 always
 */
native L4D_GetCampaignScores(&scoreA, &scoreB);

/**
 * @brief Get the team scores for the current map
 * @remarks The campaign scores are not set until the end of round 2,
 *           use L4D_GetCampaignScores to get them earlier.
 *
 * @deprecated This function can be called through SDKTools using CTerrorGameRules,
 *          and so you should switch off to using SDKTools instead of this native.
 * 
 * @param logical_team  0 for A, 1 for B
 * @param campaign_score  true to get campaign score instead of map score
 * @return 		the logical team's map score 
 *                      or -1 if the team hasn't played the round yet,
 *                or the team's campaign score if campaign_score = true
 */
native L4D_GetTeamScore(logical_team, campaign_score=false);

/**
 * @brief Restarts the setup timer (when in scavenge mode)
 * @remarks If game has already started, the setup timer will show,
 *           but it still won't go back into setup.
 */
native L4D_ScavengeBeginRoundSetupTime();

/**
 * @brief Restarts the round, switching the map if necessary
 * @remarks Set the map to the current map to restart the round
 * 
 * @param map  the mapname it should go to after the round restarts
 * @return     1 always
 */
native L4D_RestartScenarioFromVote(const String:map[]);

/**
 * @brief Removes lobby reservation from a server
 * @remarks Sets the reservation cookie to 0,
 *           it is safe to call this even if it's unreserved.
 */
native L4D_LobbyUnreserve();

/**
 * @brief Checks if the server is currently reserved for a lobby
 * @remarks Server is automatically unreserved if it hibernates or
 *          if all players leave.
 *
 * @deprecated This will always return false on L4D2 or on Linux.
 *
 * @return     true if reserved, false if not reserved
 */
native bool:L4D_LobbyIsReserved();

/**
 * @brief Gets the max versus completion score for the map
 * @remarks Requires GameRules to be initialized--map must be loaded
 * 		Seems to be updated before OnMapStart
 *
 *
 * @return     The map's max completion distance (map distance score)
 */
native L4D_GetVersusMaxCompletionScore();

/**
 * @brief Sets the max versus completion score for the map
 * @remarks Requires GameRules to be initialized--map must be loaded
 * 		Seems to be updated before OnMapStart and checked on round_start
 *
 * @param	score	The versus max completion score to set for the round
 */
native L4D_SetVersusMaxCompletionScore(score);

/**
 * @brief Tells if the Mission (map) is the final map of the campaign
 *
 * @return		true if the map is the last map of the campaign (finale)
 */
native bool:L4D_IsMissionFinalMap();

/**
 * @brief Resets the natural mob (horde) timer
 * @remarks	Requires the Director to be available--map must be started
 *
 * @noreturn
 */
native bool:L4D_ResetMobTimer();

/**
 * @brief Notifies the CGameRulesProxy that the game state has been changed
 * @remarks Use this function before changing networked members of GameRules,
 * 		like with L4D_SetVersusMaxCompletionScore()
 *
 * @noreturn
 */
native L4D_NotifyNetworkStateChanged();

/*
Makes the extension required by the plugins, undefine REQUIRE_EXTENSIONS
if you want to use it optionally before including this .inc file
*/
public Extension:__ext_left4downtown = 
{
	name = "Left 4 Downtown",
	file = "left4downtown.ext",
#if defined AUTOLOAD_EXTENSIONS
	autoload = 1,
#else
	autoload = 0,
#endif
#if defined REQUIRE_EXTENSIONS
	required = 1,
#else
	required = 0,
#endif
};
