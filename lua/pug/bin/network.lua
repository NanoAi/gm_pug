util.AddNetworkString( "pug.menu" )
util.AddNetworkString( "pug.send" )
util.AddNetworkString( "pug.take" )

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
		end
	end
end)

net.Receive("pug.take", function( len, ply )
	if not IsValid( ply ) then return end

	if not ply:IsSuperAdmin() then
		ply:Kick()
		return
	end

	local nFlood = antiFlood[ ply:SteamID() ] or 0
	nFlood = nFlood < CurTime()

	if nFlood then
		antiFlood[ ply:SteamID() ] = CurTime() + 1

		if len < 100 then return end
		local data = net.ReadData( len )

		if data then
			data = util.Decompress( data, len )
			file.Write( "pug_settings.txt", data )
			timer.Simple(0, function()
				PUG:saveConfig()
			end)
		end
	end
end)