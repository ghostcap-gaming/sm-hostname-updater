#include <sourcemod>
#include <SteamWorks>

#pragma semicolon 1
#pragma newdecls required

#define DATABASE_ENTRY "hostname_updater" // Listed entry in 'databases.cfg'
#define MYSQL_TABLE_NAME "hostname_updater"

// String lengths declarations.
#define NAX_ADDRESS_LENGTH 22
#define NAX_HOSTNAME_LENGTH 128

// Used to change the hostname string mid-game.
ConVar hostname;

// MySQL db connection handle.
Database g_Database;

// Formatted string that contains the server address [ip:port] (e.g: 255.255.255.255:27015)
char g_ServerAddress[NAX_ADDRESS_LENGTH];

public Plugin myinfo = 
{
	name = "Hostname Updater", 
	author = "KoNLiG", 
	description = "Automatically fetches and updates server hostname from db.", 
	version = "1.0.0", 
	url = "https://steamcommunity.com/id/KoNLiG/ || KoNLiG#6417"
};

public void OnPluginStart()
{
	if (!(hostname = FindConVar("hostname")))
	{
		SetFailState("Failed to find convar 'hostname'");
	}
	
	Database.Connect(SQL_OnDatabaseConnected, DATABASE_ENTRY);
	
	// Triggers 'UpdateServerHostname()'
	RegServerCmd("hostname_update", Command_HostnameUpdate, "Manumal hostname update.");
}

// Overrides the hostname listed in server.cfg
public void OnMapStart()
{
	// Initialize the server address once.
	if (!g_ServerAddress[0] && !InitializeServerAddress(g_ServerAddress, sizeof(g_ServerAddress)))
	{
		SetFailState("Failed to properly initialize server address");
	}
	
	// If the plugin late loaded, g_Database will still be null here.
	// 'UpdateServerHostname()' will be called in 'SQL_OnTableCreated' after all verifies. 
	if (g_Database)
	{
		UpdateServerHostname();
	}
}

//================================[ Command Callbacks ]================================//

Action Command_HostnameUpdate(int args)
{
	UpdateServerHostname();
	return Plugin_Handled;
}

//================================[ Database ]================================//

void SQL_OnDatabaseConnected(Database db, const char[] error, any data)
{
	if (!db)
	{
		SetFailState("Unable to maintain connection to MySQL Server (%s)", error);
	}
	
	g_Database = db;
	
	char query[256];
	Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS `%s`(`server_address` VARCHAR(%d) NOT NULL, `hostname` VARCHAR(%d) NOT NULL, PRIMARY KEY(`server_address`))", MYSQL_TABLE_NAME, NAX_ADDRESS_LENGTH, NAX_HOSTNAME_LENGTH);
	g_Database.Query(SQL_OnTableCreated, query);
}

void SQL_OnTableCreated(Database db, DBResultSet results, const char[] error, any data)
{
	// An error has occurred
	if (!db || !results || error[0])
	{
		ThrowError("Couldn't create table (%s)", error);
	}
}

void SQL_UpdateServerHostname(Database db, DBResultSet results, const char[] error, any data)
{
	// An error has occurred
	if (!db || !results || error[0])
	{
		ThrowError("Couldn't fetch hostname (%s)", error);
	}
	
	if (results.FetchRow())
	{
		char hostname_str[NAX_HOSTNAME_LENGTH];
		results.FetchString(0, hostname_str, sizeof(hostname_str));
		
		hostname.SetString(hostname_str);
	}
}

//================================[ Functions ]================================//

void UpdateServerHostname()
{
	char query[256];
	Format(query, sizeof(query), "SELECT `hostname` FROM `%s` WHERE `server_address` = '%s'", MYSQL_TABLE_NAME, g_ServerAddress);
	g_Database.Query(SQL_UpdateServerHostname, query);
}

public void SteamWorks_SteamServersConnected()
{
	// Initialize the server address once.
	if (!InitializeServerAddress(g_ServerAddress, sizeof(g_ServerAddress)))
	{
		SetFailState("Failed to properly initialize server address");
	}
	
	UpdateServerHostname();
}

// Util function to retrieve the server address.
bool InitializeServerAddress(char[] buffer, int len)
{
	ConVar hostport = FindConVar("hostport");
	if (!hostport)
	{
		return false;
	}
	
	char hostport_str[6]; // Max address port length: 5 + null terminator
	hostport.GetString(hostport_str, sizeof(hostport_str));
	
	delete hostport;
	
	int octets[4];
	SteamWorks_GetPublicIP(octets);
	
	Format(buffer, len, "%d.%d.%d.%d:%s", octets[0], octets[1], octets[2], octets[3], hostport_str);
	LogMessage("g_ServerAddress: %s", buffer);
	return true;
} 