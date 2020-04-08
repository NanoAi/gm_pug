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

local maxRate = 1 / engine.TickInterval()
local sampleTime = 1.5 -- time in seconds to average
local sampleSize = sampleTime * maxRate

local function addSample( rate )
    rate = math.Clamp( rate, 0, maxRate )

	sample.index = math.ceil( sample.index % sampleSize ) + 1

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
	local isReady = ( sample.mean ~= 0 )

	lag.rate = 1 / ( sysTime - lag.lastTick )
	lag.lastTick = sysTime

	if not isReady then
		addSample( lag.rate )
		return
	end

	local tol = sample.mean - lag.tolerance
	local inTolerance = ( lag.rate > tol )
	local inTimeout = ( lag.timeout > sysTime )

	if inTimeout then return end

	if not inTolerance then
		skips = skips + 1

		-- IF there's casual lag
		if ( sample.mean <= lag.trigger ) or ( skips >= lag.skips ) then
			print( "LAG!", "Rate: ", lag.rate, "Trigger: ", lag.trigger )
			print( "Average: ", sample.mean, "Skips: ", skips, "/", lag.skips ) 

			lag.fClean()
			lag.timeout = sysTime + lag.cooldown

			PUG:Notify( "pug_lagdetected", 3, 5, nil )

        end

        -- If there's a panic
        if ( sample.mean <= lag.panic ) or ( skips >= lag.pSkips )  then
            lag.fPanic()
            PUG:Notify( "pug_lagpanic", 3, 5, nil )
		end
    end

    addSample( lag.rate )

end, hooks)

return {
	hooks = hooks,
	timers = timers,
	settings = settings,
}
