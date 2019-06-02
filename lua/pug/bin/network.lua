util.AddNetworkString( "pug.menu" )
util.AddNetworkString( "pug.send" )
util.AddNetworkString( "pug.take" )
util.AddNetworkString( "pug.notify" )

local function openMenu( ply )
	net.Start("pug.menu")
	net.Send( ply )
end

local antiFlood = {}
local size = 0

concommand.Add("pug", function( ply, cmd )
	if cmd ~= "pug" then return end
	if IsValid( ply ) and ply:IsSuperAdmin() then
		openMenu( ply )
	end
end, nil, nil, FCVAR_CLIENTCMD_CAN_EXECUTE)

hook.Add( "PlayerSay", "PUG.openMenu", function( ply, text, public )
	text = string.lower( text )
	if ply:IsSuperAdmin() and text:match( '^%ppug' ) then
		openMenu( ply )
		return ""
	end
end)

local function log( msg )
	ServerLog( msg )
	if epoe and type( epoe.PushMsgC ) == "function" then
		epoe.PushMsgC( Color(255,255,255), "[PUG] " .. msg .. "\n" )
	end
end

net.Receive("pug.send", function( len, ply )
	if not IsValid( ply ) then return end

	if not ply:IsSuperAdmin() then
		ply:Kick()
		return
	end

	local nFlood = antiFlood[ ply:SteamID() ] or 0
	nFlood = nFlood < CurTime()

	if nFlood then
		antiFlood[ ply:SteamID() ] = CurTime() + 1
		if len > 0 then return end

		local readFile = file.Read( "pug_settings.txt", "DATA" )
		if readFile and readFile ~= "" then
			local data = util.Compress( readFile )
			net.Start("pug.send")
			net.WriteData( data, #data )
			net.Send( ply )

			log( ply:SteamID() .. " requested PUG Data!" )
		end
	end
end)

function PUG:Notify( str, msgType, length, who )
	local players = player.GetAll()
	local targets = {}

	if who == "admins" then
		for _, v in next, players do
			if IsValid( v ) and v:IsAdmin() then
				table.insert( targets, v )
			end
		end
		who = targets
		log( str )
	end

	if who == "supers" then
		for _, v in next, players do
			if IsValid( v ) and v:IsSuperAdmin() then
				table.insert( targets, v )
			end
		end
		who = targets
		log( str )
	end

	net.Start("pug.notify")

	net.WriteString( str )
	net.WriteInt( msgType, 4 )
	net.WriteInt( length, 4 )

	if who then
		net.Send( who )
	else
		net.Broadcast()
	end
end

net.Receive("pug.take", function( len, ply )
	if not IsValid( ply ) then return end

	if not ply:IsSuperAdmin() then
		ply:Kick()
		return
	end

	local steamid = ply:SteamID()
	local nFlood = antiFlood[ steamid ] or 0
	nFlood = nFlood < CurTime()

	if nFlood then
		antiFlood[ steamid ] = CurTime() + 1

		if len < 100 then return end
		local data = net.ReadData( len )

		if data then
			data = util.Decompress( data, len )

			local msg = "PUG Settings Updated "
			msg = msg .. "by " .. steamid .. "!"

			PUG:Notify( msg, 0, 4, "supers" )
			PUG:saveConfig( data )
		end
	end
end)