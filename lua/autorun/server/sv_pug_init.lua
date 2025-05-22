AddCSLuaFile("pug/cl_pug.lua")
AddCSLuaFile("pug/client/rndx.lua")
AddCSLuaFile("pug/client/language.lua")
AddCSLuaFile("pug/client/menu_struct.lua")
CreateConVar("pug_lang", "en", FCVAR_ARCHIVE, "Set PUGs current language, falls back to default.")

PUG = {}

function start()
	local langCvar = GetConVar("pug_lang")
	local loaded = PUG.hasLoaded or false
	local lang = langCvar:GetString()
	lang = (not lang or lang == "") and "en" or lang
	
	PUG = next(PUG) and PUG or { 
		hasLoaded = loaded,
		InitAt = SysTime(),
	}

	if loaded then
		print("[PUG] Reloading PUG! ~")
	else
		print("[PUG] Starting PUG! ~")
	end

	lang = lang:lower():gsub("[^a-z%-]", ""):sub(1, 7)
	lang = string.format("pug/language/%s.lua", lang)
	PUG.lang = include(lang)

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
