util.AddNetworkString( "pug.menu" )
util.AddNetworkString( "pug.menu.close" )
util.AddNetworkString( "pug.send" )
util.AddNetworkString( "pug.take" )
util.AddNetworkString( "pug.notify" )
util.AddNetworkString( "pug.PhysicsPing" )
util.AddNetworkString( "pug.cleanup.request" )

local sendTime = RealTime() + (FrameTime() * 2)
local clean = include("pug/bin/cleanups.lua")
local playersInMenu = {}
local sf = string.format
local l = PUG.lang.get
local antiFlood = {}
local size = 0

local function openMenu( ply )
	net.Start("pug.menu")
	net.Send( ply )
	for k = 1, #playersInMenu + 1 do
		if playersInMenu[k] == nil then
			playersInMenu[k] = ply
			break
		end
	end
end

local function timeInTicks(ticks)
	ticks = ticks or 1
	return FrameTime() * ticks
end

local function printPlayer(ply)
	print("Bad Net Request from Player.")
	print("SteamID: ", ply:SteamID64())
	ply:DebugInfo()
	print("---")
end

concommand.Add("pug_cl_menu", function( ply, cmd )
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

local physLag = { [0] = 0 }
hook.Add( "Think", "PUG.PhysicsPing", function()
	local rt = RealTime()
	if rt > sendTime then
		local users = {}
		local t = math.min(math.ceil(physenv.GetLastSimulationTime() * 1000), 127)
		sendTime = rt + timeInTicks(2)

		for _, v in ipairs(playersInMenu) do
			if v:IsSuperAdmin() then
				users[#users + 1] = v
			end
		end

		net.Start("pug.PhysicsPing")
		net.WriteUInt(t, 7)
		net.Send( users )
	end
end)

local function log( msg )
	ServerLog( msg .. "\n" )
	if epoe and type( epoe.PushMsgC ) == "function" then
		epoe.PushMsgC( Color(255,255,255), "[PUG] " .. msg .. "\n" )
	end
end

net.Receive("pug.send", function( len, ply )
	if not IsValid( ply ) then return end

	if not ply:IsSuperAdmin() then
		printPlayer(ply)
		ply:Kick()
		return
	end

	local nFlood = antiFlood[ ply:SteamID() ] or 0
	nFlood = nFlood < CurTime()

	if nFlood then
		antiFlood[ ply:SteamID() ] = CurTime() + 1
		if len > 0 then return end

		local readFile = file.Read( "pug_settings.json", "DATA" )
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
		printPlayer(ply)
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


local callCleaner = {
	[1] = {call = clean.unfrozen, name = "unfrozen"},
	[2] = {call = clean.nonContraptions, name = "loose"},
	[3] = {call = clean.clusters, name = "clusters"},
	[4] = {call = clean.reset, name = "reset"},
	[5] = {call = clean.custom, name = "custom"},
	[6] = {call = clean.dry, name = "dry"},
}

setmetatable(callCleaner, {
	__index = function()
		return (function() return false end)
	end,
})

net.Receive("pug.cleanup.request", function( len, ply )
	if not IsValid(ply) then return end

	if not ply:IsSuperAdmin() then
		printPlayer(ply)
		ply:Kick()
		return
	end

	local _type = net.ReadInt(5) or 0
	local cleaner = callCleaner[_type]
	if response ~= false then
		local msg = sf(l("pug.cleanup"), string.upper(cleaner.name))
		cleaner.call()
		PUG:Notify(msg, 4, 5, nil)
	end
end)

net.Receive("pug.menu.close", function( len, ply )
	if not IsValid(ply) then return end

	if not ply:IsSuperAdmin() then
		printPlayer(ply)
		ply:Kick()
		return
	end

	for k, v in ipairs(playersInMenu) do
		if v == ply then
			playersInMenu[k] = nil
		end
	end
end)
