local DB_HOST = ""
local DB_USERNAME = ""
local DB_PASSWORD = ""
local DB_DATABASE = ""
local SERVER_ID = "darkrp" -- EACH SERVER HAS TO HAVE THEIR OWN UNIQUE SERVERID

local CHAT_CMD_ENABLE = false
local CHAT_CMD_COMMANDS = {"!donate", "/donate"}
local CHAT_CMD_URL = "http://example.com/donate/"

----------------------------------------------------------------------------
-- !!! Don't touch anything bellow, unless you know what you're doing !!! --
----------------------------------------------------------------------------

DonationSystemCredit = { }
local DSC = DonationSystemCredit

DSC.DBCheckInterval = 60 -- Change it on your own risk, some databases don't like too frequent connections.

---- Logs -----------------------------------------------------

DSC.Logs = { }

local function addlog( str, ignorefile )
	DSC.Logs[ #DSC.Logs + 1 ] = { os.date( ), str }
	Msg( "[DonationSystemCredit] " .. tostring( str ) .. "\n" )
	if not ignorefile then
		file.Append( "dsc_logs.txt", os.date( ) .. "\t" .. str .. "\n" )
	end
end
addlog( "Initiating DonationSystemCredit v1.0", true )

---- Chat Commands --------------------------------------------

local function donateCommand( pl, text, teamonly )
	if table.HasValue( CHAT_CMD_COMMANDS, text ) then
		pl:SendLua([[gui.OpenURL("]] .. CHAT_CMD_URL .. [[")]])
		return ""
	end
end
if CHAT_CMD_ENABLE then
	hook.Add( "PlayerSay", "DonationSystemCreditChat", donateCommand )
end

---- Console Commands -----------------------------------------------

local function consolePrint( ply, msg )
	if IsValid(ply) then 
		ply:PrintMessage(HUD_PRINTCONSOLE, msg )
	else
		print(msg)
	end
end

concommand.Add( "dsc_printlogs",function( ply, cmd, args, str )
	if IsValid( ply ) and not ply:IsSuperAdmin() then return end
	consolePrint( ply, "DonationSystemCredit Logs:" )
	for i=1, #DSC.Logs do
		consolePrint( ply, table.concat( DSC.Logs[ i ], "\t" ) )
	end
end )

concommand.Add( "dsc_debuginfo",function( ply, cmd, args, str )
	if IsValid( ply ) and not ply:IsSuperAdmin() then return end
	consolePrint( ply, "DonationSystemCredit Debug Info:" )
	consolePrint( ply, "HOSTNAME:  (".. #DB_HOST.. ")\t" .. DB_HOST )
	consolePrint( ply, "USERNAME:  (".. #DB_USERNAME.. ")\t" .. DB_USERNAME )
	consolePrint( ply, "PASSWORD:  (".. #DB_PASSWORD.. ")\t" .. string.rep("*",#DB_PASSWORD) )
	consolePrint( ply, "DATABASE:  (".. #DB_DATABASE.. ")\t"  .. DB_DATABASE)
	consolePrint( ply, "SERVER_ID: (".. #SERVER_ID.. ")\t" .. SERVER_ID )
	consolePrint( ply, "MySQLOO:\t" .. (mysqloo and "LOADED" or "NOT LOADED") )
end )

concommand.Add( "ds_status", function( ply, cmd, args, str )
	if IsValid( ply ) and not ply:IsSuperAdmin() then return end
	consolePrint( ply, "Database Status: " .. DSC.Database:status( ) )
end )

concommand.Add( "dsc_forcecheck",function( ply, cmd, args, str )
	if IsValid( ply ) and not ply:IsSuperAdmin() then return end
	consolePrint( ply, "Force check initiated!" )
	DSC.Check()
end )

---- MySQLOO --------------------------------------------------
local succ, err = pcall(require, "mysqloo" )
if succ then
	addlog( "Successfully loaded MySQLOO module!", true )
else
	addlog( "Failed to load MySQLOO module: " .. err )
	return nil
end

DSC.Database = mysqloo.connect( DB_HOST, DB_USERNAME, DB_PASSWORD, DB_DATABASE, 3306 )
local db = DSC.Database
local queue = {}
local function query( sql, callback )
	local q = db:query( sql )
	if not q then	
		table.insert( queue, { sql, callback } )
		db:connect( )
		return
	end
	function q:onSuccess( data )
		if type( callback ) == "function" then
			callback( data, q )
		end
	end
	function q:onError( err )
		if db:status() == mysqloo.DATABASE_NOT_CONNECTED then
			table.insert( queue, { sql, callback } )
			db:connect( )
			return
		else
			DSC.DatabaseCheck( )
			addlog( "Query Error: " .. err .. " sql: " .. sql )
		end
	end
	q:start()
end

function db:onConnected( )	
	addlog( "Connected to database", true )
	DSC.DatabaseCheck( )
	for k, v in pairs( queue ) do
		query( v[ 1 ], v[ 2 ] )
	end
	queue = {}
end
 
function db:onConnectionFailed( err )
    addlog( "Connection to database failed! Error: " .. err )
end

db:connect( )

function DSC.DatabaseCheck( )
	query( [[
		CREATE TABLE IF NOT EXISTS `dsc_executes` (
			`cmd_id`					INT NOT NULL AUTO_INCREMENT,
			`cmd_status`				TINYINT DEFAULT '0',
			`cmd_status_info`			TEXT,
			`cmd_name`					VARCHAR(30) NOT NULL,
			`cmd_arguments`				TEXT NOT NULL,
			`cmd_server_id`				VARCHAR(40) NOT NULL,
			`cmd_cancel_id`				VARCHAR(40) NOT NULL,
			`cmd_activate_time`			INT UNSIGNED NOT NULL,
			`cmd_online`				TINYINT(1) UNSIGNED NOT NULL,
			`cmd_package_id`			INT UNSIGNED NOT NULL,
			`cmd_delay`					INT UNSIGNED NOT NULL,
			`cmd_transaction_id`		INT UNSIGNED NOT NULL,
			`cmd_transaction_amount`	INT NOT NULL,
			`user_steamid`				VARCHAR(25) NOT NULL,
			`user_name`					VARCHAR(40) NOT NULL,
			PRIMARY KEY ( `cmd_id` ) 
		)
	]] )
end


---- Commands -------------------------------------------------

util.AddNetworkString( "DonationSystemCreditColorChat" )
util.AddNetworkString( "DonationSystemCreditConCommand" )

hook.Add( "PlayerInitialSpawn", "DonationSystemCredit_PlayerInit", function(ply) -- Not worth it creating clientside files for few lines.
	ply:SendLua( [[ 
		net.Receive( "DonationSystemCreditColorChat", function( len ) chat.AddText( unpack( net.ReadTable() ) ) end ) 
		net.Receive( "DonationSystemCreditCmd", function( len ) RunConsoleCommand( unpack( net.ReadTable() ) ) end ) 
	]] )
end)

DSC.Commands = {
	[ "gforum_smf_usergroup" ] = function( data, args, ply )
		if Forum == nil then
			error( "gForum is not installed" )
		end
		local steamid = data.user_steamid
		local gid = args[1]
		if tonumber( gid ) == nil then
			error( "Invalid first argument. Got " .. type(gid) .. ", expected number.")
			return nil
		end
		if Forum == "smf" then
			local query1 = database:query("SELECT `id` FROM " .. Prefix .. "_link WHERE `steamid`='" .. steamid .. "'")
			query1.onError = function( err, sql )
				addlog( "Error executing gforum_smf_usergroup command.\nQuery1 errored!\nQuery:" .. sql .. "\nError: " .. err )
			end
			query1.onSuccess = function( query, data )
				local id = query:getData()[1]['id'] or nil
				if id then
					local query2 = database:query("SELECT `id_member`, `member_name`, `id_group`, `personal_text` FROM " .. Prefix .. "_members WHERE `id_member`='" .. id .. "'")
					query2.onError = function( err, sql )
						addlog( "Error executing gforum_smf_usergroup command.\nQuery2 errored!\nQuery:" .. sql .. "\nError: " .. err )
					end
					query2.onSuccess = function( _query )
						local Args1 = _query:getData()[1] or nil
						if Args1['id_member'] then
							database:query("UPDATE " .. Prefix .. "_members SET `id_group`='" .. gid .."' WHERE `id_member`='" ..Args1['id_member'] .. "'")
						end
					end
					query2:start()
				else
					ServerLog("[gForum] Tried to set rank on unlinked user.")
					addlog("[gForum] Tried to set rank on unlinked user.")
				end
			end
			query1:start()
		else
			error( "Forum is not smf" )
		end
	end,
	[ "darkrp_money" ] = function( data, args, ply )
		if not IsValid( ply ) then
			error( "Player is not valid" )
		end
		local succ, err = pcall( function( ) 
			local PLAYER = FindMetaTable( "Player" )
			if type( PLAYER.AddMoney ) == "function" then
				ply:AddMoney( tonumber( args[ 1 ] ) )
			elseif type( PLAYER.addMoney ) == "function" then
				ply:addMoney( tonumber( args[ 1 ] ) )
			else 
				error( "No functions were found" )
			end	
		end )
		if not succ then
			error( err )
		end	
	end,
	[ "pointshop_points" ] = function( data, args, ply )
		if not IsValid( ply ) then
			error( "Player is not valid" )
		end
		local succ, err = pcall( function() ply:PS_GivePoints( tonumber( args[ 1 ] ) ) end )
		if not succ then
			error( err )
		end	
	end,
	[ "pointshop2_points" ] = function( data, args, ply )
		if not IsValid( ply ) then
			error( "Player is not valid" )
		end
		local succ, err = pcall( function() ply:PS2_AddStandardPoints( tonumber( args[ 1 ] ) ) end )
		if not succ then
			error( err )
		end	
	end,
	[ "pointshop2_points_premium" ] = function( data, args, ply )
		if not IsValid( ply ) then
			error( "Player is not valid" )
		end
		local succ, err = pcall( function() ply:PS2_AddPremiumPoints( tonumber( args[ 1 ] ) ) end )
		if not succ then
			error( err )
		end	
	end,
	["print"] = function( data, args, ply )
		if not IsValid( ply ) then
			error( "Player is not valid" )
		end
		if type( args ) == "table" then
			for i=1, #args do
				if type( args[ i ] ) == "table" then
					args[ i ] = Color( args[ i ][ 1 ], args[ i ][ 2 ], args[ i ][ 3 ] )
				elseif type( args[ i ] ) == "string" then
					args[ i ] = string.Replace( args[ i ], "%name%", tostring( data.user_name ) )
					args[ i ] = string.Replace( args[ i ], "%commandid%", tostring( data.cmd_id ) )
					args[ i ] = string.Replace( args[ i ], "%transactionid%", tostring( data.cmd_transaction_id ) )
					args[ i ] = string.Replace( args[ i ], "%packageid%", tostring( data.cmd_package_id ) )
					args[ i ] = string.Replace( args[ i ], "%gamename%", tostring( ply:Name( ) ) )
					args[ i ] = string.Replace( args[ i ], "%steamid%", tostring( ply:SteamID( ) ) )
					args[ i ] = string.Replace( args[ i ], "%steamid64%", tostring( ply:SteamID64( ) ) )
					args[ i ] = string.Replace( args[ i ], "%uniqueid%", tostring( ply:UniqueID( ) ) )
					args[ i ] = string.Replace( args[ i ], "%userid%", tostring( ply:UserID( ) ) )
				end
			end
			net.Start( "DonationSystemCreditColorChat" )
				net.WriteTable( args )
			net.Send( ply )
		end
	end,
	[ "broadcast" ] = function( data, args, ply )
		if type( args ) == "table" then
			for i=1, #args do
				if type( args[ i ] ) == "table" then
					args[ i ] = Color( args[ i ][ 1 ], args[ i ][ 2 ], args[ i ][ 3 ] )
				elseif type( args[ i ] ) == "string" then
					args[ i ] = string.Replace( args[ i ], "%name%", tostring( data.user_name ) )
					args[ i ] = string.Replace( args[ i ], "%commandid%", tostring( data.cmd_id ) )
					args[ i ] = string.Replace( args[ i ], "%transactionid%", tostring( data.cmd_transaction_id ) )
					args[ i ] = string.Replace( args[ i ], "%packageid%", tostring( data.cmd_package_id ) )
					args[ i ] = string.Replace( args[ i ], "%steamid%", tostring( data.user_steamid ) )
					args[ i ] = string.Replace( args[ i ], "%uniqueid%", tostring( util.CRC( "gm_" .. data.user_steamid .. "_gm" ) ) )
					if IsValid( ply ) then
						args[ i ] = string.Replace( args[ i ], "%steamid64%", tostring( ply:SteamID64( ) ) )
						args[ i ] = string.Replace( args[ i ], "%gamename%", tostring( ply:Nick( ) ) )
						args[ i ] = string.Replace( args[ i ], "%userid%", tostring( ply:UserID( ) ) )
					end
				end
			end
			net.Start( "DonationSystemCreditColorChat" )
				net.WriteTable( args )
			net.Broadcast( )
		end
	end,
	[ "broadcast_omit" ] = function( data, args, ply )
		if type( args ) == "table" then
			for i=1, #args do
				if type( args[ i ] ) == "table" then
					args[ i ] = Color( args[ i ][ 1 ], args[ i ][ 2 ], args[ i ][ 3 ] )
				elseif type( args[ i ] ) == "string" then
					args[ i ] = string.Replace( args[ i ], "%name%", tostring( data.user_name ) )
					args[ i ] = string.Replace( args[ i ], "%commandid%", tostring( data.cmd_id ) )
					args[ i ] = string.Replace( args[ i ], "%transactionid%", tostring( data.cmd_transaction_id ) )
					args[ i ] = string.Replace( args[ i ], "%packageid%", tostring( data.cmd_package_id ) )
					args[ i ] = string.Replace( args[ i ], "%steamid%", tostring( data.user_steamid ) )
					args[ i ] = string.Replace( args[ i ], "%uniqueid%", tostring( util.CRC( "gm_" .. data.user_steamid .. "_gm" ) ) )
					if IsValid( ply ) then
						args[ i ] = string.Replace( args[ i ], "%steamid64%", tostring( ply:SteamID64( ) ) )
						args[ i ] = string.Replace( args[ i ], "%gamename%", tostring( ply:Nick( ) ) )
						args[ i ] = string.Replace( args[ i ], "%userid%", tostring( ply:UserID( ) ) )
					end
				end
			end
			net.Start( "DonationSystemCreditColorChat" )
				net.WriteTable( args )
				
			if IsValid(ply) then
				net.SendOmit( ply )
			else
				net.Broadcast( )
			end
		end
	end,
	[ "lua" ] = function( data, args, ply )
		local oldPLAYER, oldSTEAMID, oldCMDDATA, oldQUERY = PLAYER, STEAMID, CMDDATA, QUERY
		PLAYER, STEAMID, CMDDATA, QUERY = ply, data.user_steamid, data, query
	
		local func = CompileString( args[ 1 ], "[DonationSystemCredit] Lua", true )
		if type(func) == "function" then
			func()
		else
			error(func)
		end
		
		PLAYER, STEAMID, CMDDATA, QUERY = oldPLAYER, oldSTEAMID, oldCMDDATA, oldQUERY
	end,
	[ "sv_cmd" ] = function( data, args, ply )
		for i=1, #args do
			args[ i ] = string.Replace( args[ i ], "%name%", tostring( data.user_name ) )
			args[ i ] = string.Replace( args[ i ], "%commandid%", tostring( data.cmd_id ) )
			args[ i ] = string.Replace( args[ i ], "%transactionid%", tostring( data.cmd_transaction_id ) )
			args[ i ] = string.Replace( args[ i ], "%packageid%", tostring( data.cmd_package_id ) )
			args[ i ] = string.Replace( args[ i ], "%steamid%", tostring( data.user_steamid ) )
			args[ i ] = string.Replace( args[ i ], "%uniqueid%", tostring( util.CRC( "gm_" .. data.user_steamid .. "_gm" ) ) )
			if IsValid( ply ) then
				args[i] = string.Replace( args[i], "%steamid64%", tostring( ply:SteamID64( ) ) )
				args[i] = string.Replace( args[i], "%gamename%", tostring( ply:Nick( ) ) )
				args[i] = string.Replace( args[i], "%userid%", tostring( ply:UserID( ) ) )
			end
		end
		RunConsoleCommand( unpack( args ) )
	end,
	[ "disabled" ] = function( data, args, ply ) end,
	[ "cl_cmd" ] = function( data, args, ply )
		if not IsValid( ply ) then
			error( "Player is not valid" )
		end
		for i=1, #args do
			args[ i ] = string.Replace( args[ i ], "%name%", tostring( data.user_name ) )
			args[ i ] = string.Replace( args[ i ], "%commandid%", tostring( data.cmd_id ) )
			args[ i ] = string.Replace( args[ i ], "%transactionid%", tostring( data.cmd_transaction_id ) )
			args[ i ] = string.Replace( args[ i ], "%packageid%", tostring( data.cmd_package_id ) )
			args[ i ] = string.Replace( args[ i ], "%steamid%", tostring( data.user_steamid ) )
			args[ i ] = string.Replace( args[ i ], "%uniqueid%", tostring( util.CRC( "gm_" .. data.user_steamid .. "_gm" ) ) )
			
			args[ i ] = string.Replace( args[ i ], "%steamid64%", tostring( ply:SteamID64( ) ) )
			args[ i ] = string.Replace( args[ i ], "%gamename%", tostring( ply:Nick( ) ) )
			args[ i ] = string.Replace( args[ i ], "%userid%", tostring( ply:UserID( ) ) )
		end
		net.Start( "DonationSystemCreditCmd" )
			net.WriteTable( args )
		net.Send( ply )
	end,
	[ "sql" ] = function( data, args, ply )
		local querystring = args.query or args[ 1 ]
		querystring = string.Replace( querystring, "%name%", tostring( data.user_name ) )
		querystring = string.Replace( querystring, "%commandid%", tostring( data.cmd_id ) )
		querystring = string.Replace( querystring, "%transactionid%", tostring( data.cmd_transaction_id ) )
		querystring = string.Replace( querystring, "%packageid%", tostring( data.cmd_package_id ) )
		querystring = string.Replace( querystring, "%steamid%", tostring( data.user_steamid ) )
		querystring = string.Replace( querystring, "%uniqueid%", tostring( util.CRC( "gm_" .. data.user_steamid .. "_gm" ) ) )
		querystring = string.Replace( querystring, "%name_esc%", db:escape( tostring( data.user_name ) ) )
		querystring = string.Replace( querystring, "%ostime%", tostring( os.time( ) ) )
		
		if IsValid( ply ) then
			querystring = string.Replace( querystring, "%steamid64%", tostring( ply:SteamID64( ) ) )
			querystring = string.Replace( querystring, "%gamename%", tostring( ply:Nick( ) ) )
			querystring = string.Replace( querystring, "%gamename_esc%", db:escape( tostring( ply:Name( ) ) ) )
			querystring = string.Replace( querystring, "%userid%", tostring( ply:UserID( ) ) )
		end
		
		query( querystring )
	end,
	[ "sql_ext" ] = function( data, args,ply )
		local querystring = args.query
		querystring = string.Replace( querystring, "%name%", tostring( data.user_name ) )
		querystring = string.Replace( querystring, "%commandid%", tostring( data.cmd_id ) )
		querystring = string.Replace( querystring, "%transactionid%", tostring( data.cmd_transaction_id ) )
		querystring = string.Replace( querystring, "%packageid%", tostring( data.cmd_package_id ) )
		querystring = string.Replace( querystring, "%steamid%", tostring( data.user_steamid ) )
		querystring = string.Replace( querystring, "%uniqueid%", tostring( util.CRC( "gm_" .. data.user_steamid .. "_gm" ) ) )
		querystring = string.Replace( querystring, "%name_esc%", db:escape( tostring( data.user_name ) ) )
		querystring = string.Replace( querystring, "%ostime%", tostring( os.time( ) ) )
		
		if IsValid(ply) then
			querystring = string.Replace( querystring, "%steamid64%", tostring(ply:SteamID64()) )
			querystring = string.Replace( querystring, "%gamename%", tostring(ply:Nick()) )
			querystring = string.Replace( querystring, "%gamename_esc%", db:escape(tostring(ply:Name())) )
			querystring = string.Replace( querystring, "%userid%", tostring(ply:UserID()) )
		end
		
		local db = mysqloo.connect( args.host, args.database, args.username, args.password, 3306 )
		
		function db:onConnected( )
			local q = self:query( querystring )
			function q:onSuccess( data ) end
			function q:onError( err, sql )
				addlog( "Error executing 'sql_ext' command, error: " .. err .. " sql: " .. sql )
			end
			q:start( )
		end
		function db:onConnectionFailed( err )
			addlog( "Error executing 'sql_ext' command, error: ", err )
		end

		db:connect( )
	end,
	[ "cancel" ] = function( data, args, ply )
		local excludeself, serverid, packageid, online, delay, commandid
	
		cancelid = args[1]
		cancelself = args[2] or false
		
		local querystr = "UPDATE dsc_executes SET cmd_status = '2' WHERE cmd_cancel_id = \"" .. db:escape( cancelid ) .. "\" AND user_steamid = \"" .. db:escape( data.user_steamid ) .. "\""
		if not cancelself then 
			querystr = querystr .. " AND cmd_transaction_id <> \"" .. db:escape( tostring(data.cmd_transaction_id) ) .. "\""
		else
			querystr = querystr .. " AND cmd_transaction_id = \"" .. db:escape( tostring(data.cmd_transaction_id) ) .. "\""
		end
		
		query( querystr )
	end
}

local activated = {}
function DSC.Check()
	-- Store players to table, and add players conditions to sql query.
	local plyEnts = { }
	local sqlplayers = ""
	for _, ply in pairs( player.GetAll( ) ) do
		-- Making sure player is fully initialised
		local ok = false
		
		if Forum == "smf" then
			ok = ply.Registered
		else
			ok = ply:TimeConnected( ) > 60 -- Making sure player is fully initialised
		end
			
		if ok then
			plyEnts[ ply:SteamID( ) ] = ply
			sqlplayers = sqlplayers .. " OR user_steamid = \"" .. db:escape( ply:SteamID( ) ) .. "\""
		end
	end
	-- Get all commands that should be activated in next 60 seconds
	local querystr = "SELECT *, ( UNIX_TIMESTAMP() ) AS unixtime FROM `dsc_executes` WHERE cmd_server_id = '" .. db:escape( SERVER_ID ) .. "' AND cmd_status = 0 AND cmd_activate_time <= (UNIX_TIMESTAMP()+"..(DSC.DBCheckInterval-1)..") AND ( cmd_online = 0 " .. sqlplayers .. ")" -- " AND delay <= 76561198000622892 - 271"
	
	query( querystr, function( commands )
		for _, cmddata in pairs( commands ) do
			-- Delay the command
			local timeoffset = math.max( 1, cmddata.cmd_activate_time - cmddata.unixtime  )
			
			timer.Simple( timeoffset, function( )
				if cmddata.cmd_online == 0 or IsValid( plyEnts[ cmddata.user_steamid ] ) then  -- Check if player still on the server
					query("UPDATE `dsc_executes` SET cmd_status='1' WHERE cmd_id=" .. cmddata.cmd_id, function( data, q ) -- Activate it
						if q:affectedRows( ) > 0 and not activated[ cmddata.cmd_id ] then -- Making sure the command is not activated before to prevent duplicate execution
							if cmddata.cmd_online == 0 or IsValid( plyEnts[ cmddata.user_steamid ] ) then
								activated[ cmddata.cmd_id ] = true
								local command = cmddata.cmd_name
								local args = util.JSONToTable( cmddata.cmd_arguments )
								
								addlog( "Executing " .. ( cmddata.cmd_online == 1 and "online" or "offline" ) .. " command '" .. command .. "'(" .. cmddata.cmd_id .. ") for " .. cmddata.user_name .. "(" .. cmddata.user_steamid .. ")\nArguments:" .. cmddata.cmd_arguments)
								
								local succ, err = pcall( function( ) DSC.Commands[ command ]( cmddata, args, plyEnts[ cmddata.user_steamid ] ) end )
								if not succ then
									addlog( "Error while executing command '" .. command .. "'(" .. cmddata.cmd_id .. "). Error: " .. err )
									query("UPDATE `dsc_executes` SET cmd_status='-1', cmd_status_info='" .. db:escape(err) .. "'  WHERE cmd_id=" .. cmddata.cmd_id)
								end
							else
								query("UPDATE `dsc_executes` SET cmd_status='0' WHERE cmd_id=" .. cmddata.cmd_id) -- If player disconnect, we might want to deactivate the command
							end
						else
							addlog( "Error executing command (" .. cmddata.cmd_id .. "). Failed to mark command as activated. " .. tostring( IsValid( plyEnts[ cmddata.user_steamid ] ) ) )
						end
					end )
				end
			end )
		end
	end )
end

---- Main Timer -----------------------------------------------

timer.Create( "DonationSystemCreditCheck", DSC.DBCheckInterval, 0, function( ) -- Check database every 60 seconds
	DSC.Check()
end )