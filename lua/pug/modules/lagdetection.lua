local PUG = PUG
local u = PUG.util
local tableReduce = u.tableReduce

local hooks = {}
local timers = {}
local settings = {
	["skipCount"] = 8,
	["skipCountPanic"] = 16,
	["DetectionTolerance"] = 7,
	["DetectionTrigger"] = 13,
	["DetectionPanicTrigger"] = 42,
	["DetectionCooldown"] = 2,
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
}

local lag = {
	skips = settings["skipCount"],
	pSkips = settings["skipCountPanic"],
	tolerance = settings["DetectionTolerance"],
	trigger = settings["DetectionTrigger"],
	panic = settings["DetectionPanicTrigger"],
	cooldown = settings["DetectionCooldown"],
	timeout = 0,
	rate = 0,
	lastTick = 0,
}

local clean = include("pug/bin/cleanups.lua")

lag.fClean = clean[ settings[ "CleanupMethod" ] ]
lag.fPanic = clean[ settings[ "PanicMethod" ] ]

assert( type( lag.fClean ) == "function", "Invalid CleanupMethod variable" )
assert( type( lag.fPanic ) == "function", "Invalid PanicMethod variable" )

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
	sample.index = ( sample.index % 120 ) + 1
	sample.data[ sample.index ] = rate
	if ( sample.index % 10 ) == 0 then
		sample.mean = getMean()
	end
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
	lag.rate = 1 / ( sysTime - lag.lastTick )
	lag.lastTick = sysTime

	local tol = sample.mean - lag.tolerance
	local inTolerance = ( lag.rate > tol )
	local inTimeout = ( lag.timeout > sysTime )
	local isReady = ( sample.mean == 0 )

	if not isReady then
		addSample( lag.rate )
		return
	end

	if isReady and ( not inTimeout ) then
		if not inTolerance then
			skips = skips + 1
			if ( lag.rate > lag.trigger ) or ( skips > lag.skips ) then
				ServerLog( "LAG: ", lag.rate, "Th: ", lag.threshold )
				ServerLog( "Average: ", sample.mean, "Skips: ",
				skips, "/", lag.skips )

				lag.fClean()
				lag.timeout = sysTime + lag.cooldown

				PUG:Notify( "pug_lagdetected", 3, 5, nil )

				if ( lag.rate > lag.panic ) or ( skips > lag.pSkips )  then
					lag.fPanic()
					PUG:Notify( "pug_lagpanic", 3, 5, nil )
				end
			end
		else
			addSample( lag.rate )
		end
	end
end, hooks)

return {
	hooks = hooks,
	timers = timers,
	settings = settings,
}