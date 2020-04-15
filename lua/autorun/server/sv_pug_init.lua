AddCSLuaFile("pug/client/pug.lua")
AddCSLuaFile("pug/client/language.lua")

PUG = PUG or {}

hook.Add("InitPostEntity", "PUG_Startup", function()
	timer.Simple(0, function()
		PUG.InitAt = SysTime()
		print("[PUG] Starting PUG! ~")
		include("pug/sv_pug.lua")
	end)
end)