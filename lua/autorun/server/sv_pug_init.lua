AddCSLuaFile("pug/cl_pug.lua")

PUG = {}

function start()
	local loaded = PUG.hasLoaded
	
	PUG = { hasLoaded = loaded }
	PUG.InitAt = SysTime()

	if loaded then
		print("[PUG] Reloading PUG! ~")
	else
		print("[PUG] Starting PUG! ~")
	end

	include("pug/sv_pug.lua")
end

hook.Add("InitPostEntity", "PUG_Startup", function()
	timer.Simple(0, function()
		start()
	end)
end)

concommand.Add("pug_reload", function( ply, cmd )
	if cmd ~= "pug_reload" then return end
	if game.IsDedicated() and ply then return end
	start()
end, nil, nil, FCVAR_SERVER_CAN_EXECUTE)
