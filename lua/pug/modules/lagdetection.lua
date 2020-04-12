local PUG = PUG
local u = PUG.util
local tableReduce = u.tableReduce

local hooks = {}
local timers = {}
local settings = {
	["SkipCount"] = 8,
	["SkipCountPanic"] = 16,
	["DetectionTolerance"] = 5,
	["DetectionTrigger"] = 64,
	["DetectionPanicTrigger"] = 59,
	["DetectionCooldown"] = 2,
	["SampleSize"] = 132,
	["ServerTickRate"] = 66,
	["CleanupMethod"] = "unfrozen",
	["PanicMethod"] = "reset",
}

settings = u.getSettings( settings )

local halt = true
local skips = 0

local sample = {
	data = {},
	index = 0,
	mean = 0,
	ready = false,
	timeout = 0,
	tickRate = 0,
	lastTick = 0,
}

local getSettings = {
	skips = settings["SkipCount"],
	pSkips = settings["SkipCountPanic"],
	tolerance = settings["DetectionTolerance"],
	trigger = settings["DetectionTrigger"],
	panic = settings["DetectionPanicTrigger"],
	cooldown = settings["DetectionCooldown"],
	sampleSize = settings["SampleSize"],
	definedTickRate = settings["ServerTickRate"] + 0.66,
	--^ The value `tickrate` is usually rounded down, so we are adding
	-- 0.66 to account for that as per the Garry's Mod wiki entry.
	-- ref: https://wiki.facepunch.com/gmod/engine.TickInterval
}

local clean = include("pug/bin/cleanups.lua")

getSettings.fClean = clean[ settings[ "CleanupMethod" ] ]
getSettings.fPanic = clean[ settings[ "PanicMethod" ] ]

assert( type( getSettings.fClean ) == "function", "Invalid CleanupMethod variable" )
assert( type( getSettings.fPanic ) == "function", "Invalid PanicMethod variable" )

--[[ TODO: Rebuild Lag Detection
	Server FPS = 1/(SysTime - lastTick)
	Sample the FPS and find the average rate.
	Compare new rates against the average. (Test ZScore vs Subtraction.)
]]

local function getMean()
	local x = tableReduce( function(a, b) return a + b end, sample.data )
	return ( x / #sample.data )
end

local function addSample( rate )
	rate = math.min( rate, getSettings.definedTickRate )
	--^ We only want to sample dips in the tick rate.
	sample.index = ( sample.index % getSettings.sampleSize ) + 1

	sample.data[ sample.index ] = rate
	if ( sample.index % 10 ) == 0 then
		sample.mean = getMean()
		sample.ready = true
	end
end

local function notifyAdminsAboutSettings()
	PUG:Notify( "pug_lagsettings", 1, 5, "supers" )
	notifyAdminsAboutSettings = nil
end

u.addTimer("LagDetection", 1, 0, function()
	halt = false
	skips = skips - 1
	if skips < 0 then
		skips = 0
	end
end, timers)

u.addHook("Tick", "LagDetection", function()
	if halt then return end

	local sysTime = SysTime()
	sample.tickRate = 1 / ( sysTime - sample.lastTick )
	sample.lastTick = sysTime

	if not sample.ready then
		addSample( sample.tickRate )
		return
	else
		if notifyAdminsAboutSettings then
			local comp = math.abs(getSettings.definedTickRate - sample.mean)
			local outOfBounds = comp > 1
			if outOfBounds then
				notifyAdminsAboutSettings()
			end
		end
	end

	local tol = sample.mean + getSettings.tolerance
	local inTolerance = ( sample.tickRate > tol )
	local inTimeout = ( sample.timeout > sysTime )

	if inTimeout then return end

	if not inTolerance then
		skips = skips + 1

		local skipsOverLimit = ( skips >= getSettings.skips )
		local skipsOverPanic = ( skips >= getSettings.pSkips )
		local rateOverLimit = ( sample.tickRate <= getSettings.trigger )
		local rateOverPanic = ( sample.tickRate <= getSettings.panic )

		if rateOverLimit or skipsOverLimit then
			print( "LAG: ", sample.tickRate, "Th: ", getSettings.tolerance )
			print( "Average: ", sample.mean, "Skips: ",
			skips, "/", getSettings.skips )

			getSettings.fClean()
			sample.timeout = sysTime + getSettings.cooldown

			PUG:Notify( "pug_lagdetected", 3, 5, nil )

			if rateOverPanic or skipsOverPanic then
				getSettings.fPanic()
				PUG:Notify( "pug_lagpanic", 3, 5, nil )
			end
		end
	end

	addSample( sample.tickRate )
end, hooks)

return {
	hooks = hooks,
	timers = timers,
	settings = settings,
}