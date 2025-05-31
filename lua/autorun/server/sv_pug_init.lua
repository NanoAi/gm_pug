local include = include
local print = print

local eStr = "The language file for \"%s\" was either invalid or not found"
eStr = string.format("\n[PUG][WARNING] %s; falling back to \"en\".\n", eStr)
local conDesc = "Set PUGs current language, falls back to default."

AddCSLuaFile("pug/cl_pug.lua")
AddCSLuaFile("pug/client/menu/menu.lua")
AddCSLuaFile("pug/client/menu/build.lua")
AddCSLuaFile("pug/client/rndx.lua")
AddCSLuaFile("pug/client/language.lua")
CreateConVar("pug_lang", "en", FCVAR_ARCHIVE, conDesc)

PUG = {}

local function isValidLanguageInclude(data)
	if not istable(data) then return false end
	if not next(data) then return false end
	if data["mt2BC8cVRk"] ~= "i6SDIQhX9t" then
		return false
	end
	data["mt2BC8cVRk"] = nil -- Cleanup.
	return true
end

local function setLanguage(lang)
	local fileName = lang:lower():gsub("[^a-z%-]", ""):sub(1, 7)
	fileName = string.format("pug/language/%s.lua", fileName)
	PUG.lang = nil -- Clear the variable.

	local tryInclude = CompileFile(fileName, false)
	if isfunction(tryInclude) then
		PUG.lang = tryInclude()
	end

	if not isValidLanguageInclude(PUG.lang) then
		print(string.format(eStr, lang))
		PUG.lang = include("pug/language/en.lua")
	end

	return PUG.lang
end

function start()
	local langCvar = GetConVar("pug_lang")
	local loaded = PUG.hasLoaded or false
	local lang = langCvar:GetString()
	lang = (not lang or lang == "") and "en" or lang
	
	PUG = next(PUG) and PUG or { 
		setLanguage = setLanguage,
		hasLoaded = loaded,
		InitAt = SysTime(),
	}

	if loaded then
		print("[PUG] Reloading PUG! ~")
	else
		print("[PUG] Starting PUG! ~")
	end

	PUG.lang = setLanguage(lang)
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

cvars.AddChangeCallback("pug_lang", function(_, _, new) 
	PUG.lang = setLanguage(new)
end, "PUG.ChangeLanguage")
