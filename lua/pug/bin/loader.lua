PUG.modules = PUG.modules or {}

local file, hook, timer = file, hook, timer
local path = "pug/modules/"
local modules = file.Find( path .. "*.lua", "LUA" )

for _, fileName in next, modules do
	if fileName then
		local niceName = string.gsub(fileName, "%.lua", "")
		PUG.modules[ niceName ] = {
			enabled = false,
			loaded = false,
			path = path .. fileName,
			data = {}
		}
	end
end

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
			for callerID, hookID in next, getTable do
				hook.Remove(callerID, hookID)
			end
		end

		if type( data.timers ) == "table" then
			for _, getTable in next, data.timers do
				for timerID in next, getTable do
					timer.Remove( timerID )
				end
			end
		end

		module.enabled = false
		module.loaded = false
	else
		local emsg = "The module " .. moduleName .. " doesn't exist or is "
		emsg = emsg .. "invalid."
		ErrorNoHalt( emsg )
	end
end

local function writeData()
	local data = {}
	local json = ""

	for k, v in next, PUG.modules do
		data[ k ] = {
			enabled = v.enabled,
			data = { settings = v.data.settings },
		}
	end

	json = util.TableToJSON( data )
	file.Write( "pug_settings.txt", json )
end

function PUG:saveConfig()
	local readFile = file.Read( "pug_settings.txt", "DATA" )

	if ( not readFile ) or ( readFile == "" ) then
		writeData()
	else
		local data = util.JSONToTable( readFile )

		if not data then
			local emsg = "Your custom settings have not been loaded "
			emsg = emsg .. "because you have a misconfigured settings file! "
			emsg = emsg .. "The default settings were used instead!"
			ErrorNoHalt( emsg )
			return
		end

		-- Look for saved data that does not actually exist and remove it.
		-- k is Key, v is Value, _ is Dropped/Unused.

		for k, _ in next, data do
			if not self.modules[ k ] then
				data[ k ] = nil
			end
		end

		-- Update data with new modules if new modules were added.
		for k, v in next, self.modules do
			if not data[ k ] then
				data[ k ] = v
			end
		end

		self.modules = table.Merge( self.modules, data )

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
			writeData()
		end)
	end
end

PUG:saveConfig()
include( "pug/bin/network.lua" )

if not PUG.hasLoaded then
	local loadTime = math.Round( ( SysTime() - PUG.InitAt ), 2 )
	loadTime = loadTime == 0 and "2fast4u" or loadTime

	print("PUG has hopped onto your server! Your physics are safe with PUG.")
	print("PUG took " .. loadTime .. " seconds to arrive!")
	print("-- [PUG] Ready! --")

	PUG.hasLoaded = true
else
	print("-- [PUG] ReLoaded! --")
end