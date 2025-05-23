PUG.modules = PUG.modules or {}

local ErrorNoHaltWithStack = ErrorNoHaltWithStack
local file, hook, timer = file, hook, timer
local path = "pug/modules"
local modules = file.Find( path .. "/*.lua", "LUA" )
local clientFiles = file.Find( "pug/client/*.lua", "LUA" )

for _, v in next, clientFiles do
	AddCSLuaFile("lua/pug/client/" .. v)
end
clientFiles = nil

-- Detect and Prepare Modules on Run.
local function prepare(path, modules, drop)
	local container = {}
	for _, fileName in next, modules do
		if fileName then
			local niceName = string.gsub(fileName, "%.lua", "")
			container[ niceName ] = {
				enabled = false,
				loaded = false,
				path = string.format( "%s/%s", path, fileName),
				data = {},
				key = niceName,
			}
		end
	end
	return container
end

PUG.modules = prepare(path, modules, false)

function PUG:load( moduleName )
	local module = self.modules[ moduleName ]
	if module then
		self.currentModule = module
		module.data = include( module.path )
		module.enabled = true
		module.loaded = true
	end
end

function PUG:unLoad( moduleName )
	local module = self.modules[ moduleName ]
	if module and next( module.data ) then
		local data = module.data

		for _, getTable in next, data.hooks do
			for callerID, hookData in next, getTable do
				hook.Remove(callerID, hookData.id)
			end
		end

		if type( data.timers ) == "table" then
			for _, getTable in next, data.timers do
				for timerData in next, getTable do
					timer.Remove( timerData.id )
				end
			end
		end

		module.enabled = false
		module.loaded = false
	else
		local emsg = "The module " .. moduleName .. " doesn't exist or is "
		emsg = emsg .. "invalid."
		ErrorNoHaltWithStack( emsg )
	end
end

local function writeData( modules )
	local data = {}
	local json = ""

	for k, v in next, modules do
		if (v and v.data) then
			data[ k ] = {
				enabled = v.enabled,
				data = { settings = v.data.settings },
			}
		else
			print("[PUGLoader] Could not write data for module: \"" .. (k or "UNKNOWN") .. "\"" )
		end
	end

	modules[0] = nil
	json = util.TableToJSON( data )
	file.Write( "pug_settings.json", json )
end

function PUG:saveConfig( data )
	local readFile = file.Read( "pug_settings.json", "DATA" )

	if ( not readFile ) or ( readFile == "" ) then
		writeData( self.modules )
	else
		if type( data ) == "string" then
			data = util.JSONToTable( data )
		else
			data = util.JSONToTable( readFile )
		end

		if not data then
			local emsg = "Your custom settings have not been loaded "
			emsg = emsg .. "because you have a misconfigured settings file! "
			emsg = emsg .. "The default settings were used instead!"
			ErrorNoHaltWithStack( emsg )
			return
		end

		data[0] = nil -- Clear the [0] table of the data.
		self.modules = table.Merge( self.modules, data ) -- Inject saved data.

		for k, v in next, self.modules do
			if v.enabled then
				self:load( k )
				print("[PUGLoader] ", k, " has been loaded!")
			else
				if v.loaded and not v.enabled then
					self:unLoad( k )
					print("[PUGLoader] ", k, " has been removed!")
				end
			end
		end

		timer.Simple(0, function()
			writeData( self.modules )
		end)
	end
end

PUG:saveConfig()
include( "pug/bin/network.lua" )

if not PUG.hasLoaded then
	local loadTime = math.Round( ( SysTime() - PUG.InitAt ), 3 )
	loadTime = loadTime == 0 and "2fast4u" or loadTime

	print("PUG has hopped onto your server! Your physics are safe with PUG.")
	print("PUG took " .. loadTime .. " seconds to arrive!")
	print("-- [PUG] Ready! --")

	PUG.hasLoaded = true
else
	print("-- [PUG] Refreshed! --")
end