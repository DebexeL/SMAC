#pragma semicolon 1

/* SM Includes */
#include <sourcemod>
#include <smac>
#pragma newdecls required
#include <sdkhooks>

/* Plugin Info */
public Plugin myinfo =
{
	name = "SMAC L4D2 Exploit Fixes",
	author = SMAC_AUTHOR,
	description = "Blocks general Left 4 Dead 2 cheats & exploits",
	version = SMAC_VERSION,
	url = SMAC_URL
};

#define L4D2_ZOMBIECLASS_TANK 8
#define TEAM_INFECTED 3
#define RECENT_TEAM_CHANGE_TIME 1.0

bool g_didRecentlyChangeTeam[MAXPLAYERS + 1];
bool IsBlockPunchRock;

ConVar g_hBlockPunchRock;

/* Plugin Functions */
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead2) {
		strcopy(error, err_max, SMAC_MOD_ERROR);
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_hBlockPunchRock = CreateConVar("smac_block_punch_rock", "1", "Block tanks from punching and throwing a rock at the same time, disable this if you are using other plugins (Example - l4d2_tank_attack_control.smx).", _, true, 0.0, true, 1.0);
	
	IsBlockPunchRock = g_hBlockPunchRock.BoolValue;
	g_hBlockPunchRock.AddChangeHook(BlockPunchRock_Changed);
	
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Post);
}

public void BlockPunchRock_Changed(ConVar convar, const char[] oldValue, const char[] newValue)
{
	IsBlockPunchRock = g_hBlockPunchRock.BoolValue;
}

public void OnAllPluginsLoaded()
{
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			OnClientPutInServer(i);
		}
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
}

public void Event_PlayerTeam(Event hEvent, const char[] name, bool dontBroadcast)
{
	if (hEvent.GetBool("disconnect")) return;

	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	
	if (client > 0 && IsClientInGame(client) && !IsFakeClient(client))
	{
		g_didRecentlyChangeTeam[client] = true;
		CreateTimer(RECENT_TEAM_CHANGE_TIME, Timer_ResetRecentTeamChange, client);
	}
}

public Action Timer_ResetRecentTeamChange(Handle hTimer, any client)
{
	g_didRecentlyChangeTeam[client] = false;
	return Plugin_Stop;
}

public Action Hook_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	// Prevent infected players from killing survivor bots by changing teams in trigger_hurt areas
	if (IS_CLIENT(victim) && g_didRecentlyChangeTeam[victim])
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if (!IsBlockPunchRock) {
		return Plugin_Continue;
	}
	
	/* Block tank double-attack. */
	if ((buttons & IN_ATTACK) && (buttons & IN_ATTACK2) && 
		GetClientTeam(client) == TEAM_INFECTED && IsPlayerAlive(client) && 
		GetEntProp(client, Prop_Send, "m_zombieClass") == L4D2_ZOMBIECLASS_TANK)
	{
		buttons ^= IN_ATTACK2;
	}

	return Plugin_Continue;
}
