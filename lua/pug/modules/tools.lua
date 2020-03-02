local u = PUG.util

local hooks = {}
local settings = {
	["AddFadingDoorHooks"] = true,
	["BlockToolUseOnWorld"] = true,
	["BlockToolSpam"] = true,
	["BlockObjSpam"] = true,
	["ToolFreezes"] = false,
	["SpamToolDelay"] = 1,
	["SpamToolRate"] = 7,
	["SpamObjDelay"] = 1,
	["SpamObjRate"] = 8,
}

settings = u.getSettings( settings )

local addFadingDoorHooks 	= settings[ "AddFadingDoorHooks" ]
local blockToolWorld 		= settings[ "BlockToolUseOnWorld" ]
local blockToolSpam 		= settings[ "BlockToolSpam" ]
local blockObjSpam 			= settings[ "BlockObjSpam" ]
local toolFreezes 			= settings[ "ToolFreezes" ]
local toolDelay 			= settings[ "SpamToolDelay" ]
local toolRate 				= settings[ "SpamToolRate" ]
local objDelay 				= settings[ "SpamObjDelay" ]
local objRate 				= settings[ "SpamObjRate" ]

local function usage( data, delay, rate )
	local diff = 0

	data.curTime = CurTime()
	data.delay = data.delay or 0
	data.useTimes = data.useTimes or 0

	diff = data.curTime - data.delay

	if data.useTimes <= 0 or diff > delay then
		data.useTimes = 0
		data.delay = 0
		data.wasNotified = false
	end

	if diff > 0 then
		data.useTimes = data.useTimes - 1
		if data.useTimes < 0 then
			data.useTimes = 0
		end
	else
		data.useTimes = data.useTimes + 1

		if data.useTimes >= toolRate then
			data.useTimes = toolRate
			data.delay = data.curTime + delay
			return data, true
		end
	end

	if data.delay == 0 then
		data.delay = data.curTime + delay
	end

	return data, false
end

u.addHook("PUG.PostCanTool", "ToolSpamControl", function( ply, _, _, canTool )
	if not canTool then return end
	if not blockToolSpam then return end

	ply.PUG_toolCTRL = ply.PUG_toolCTRL or {}
	local data, shouldBlock = usage( ply.PUG_toolCTRL, toolDelay, toolRate )

	if shouldBlock then
		if not data.wasNotified then
			data.wasNotified = true
			PUG:Notify( "pug_tool2fast", 1, 5, ply )
		end
		return false
	end
end, hooks)

u.addHook("PlayerSpawnObject", "ObjectSpamControl", function( ply )
	if not blockObjSpam then return end

	ply.PUG_objSpawnCTRL = ply.PUG_objSpawnCTRL or {}
	local data, shouldBlock = usage( ply.PUG_objSpawnCTRL, objDelay, objRate )

	if shouldBlock then
		if not data.wasNotified then
			data.wasNotified = true
			PUG:Notify( "pug_spawn2fast", 1, 5, ply )
		end
		return false
	end
end, hooks)

u.addHook("CanTool", "ToolWorldControl", function(ply, tr)
	if blockToolWorld and tr.HitWorld then
		PUG:Notify( "pug_toolworld", 1, 5, ply )
		return false
	end
end, hooks)

u.addHook("PUG.PostCanTool", "ToolUnfreezeControl", function(ply, tr, _, canTool)
	if not canTool then return end
	if not toolFreezes then return end

	timer.Simple(0.003, function()
		local ent = tr.Entity
		local phys = NULL

		if IsValid(ent) then
			phys = ent:GetPhysicsObject()
			if IsValid(phys) and phys:IsMotionEnabled() then
				phys:EnableMotion( false )
				PUG:Notify( "pug_entfrozen", 1, 1, ply )
			end
		end
	end)
end, hooks)

u.addHook("PUG.PostCanTool", "FadingDoors", function(ply, tr)
	if not addFadingDoorHooks then return end

	local ent = tr.Entity
	local enum = COLLISION_GROUP_INTERACTIVE_DEBRIS

	if IsValid( ent ) then
		ent:SetCollisionGroup( enum )
		ent._PUGForceCollision = enum
	end

	u.addJob(function()
		if IsValid(ent) then
			if not ent.isFadingDoor then return end
			local state = ent.fadeActive

			if state then
				ent:fadeDeactivate()
			end

			ent.oldFadeActivate = ent.oldFadeActivate or ent.fadeActivate
			ent.oldFadeDeactivate = ent.oldFadeDeactivate or ent.fadeDeactivate

			function ent:fadeActivate()
				if hook.Run("PUG.FadingDoorToggle", self, true, ply) then
					return
				end

				ent:oldFadeActivate()
			end

			function ent:fadeDeactivate()
				if hook.Run("PUG.FadingDoorToggle", self, false, ply) then
					return
				end

				ent:oldFadeDeactivate()
				ent:SetCollisionGroup( enum )
			end

			if state then
				ent:fadeActivate()
			end
		end
	end)
end, hooks)

return {
	hooks = hooks,
	settings = settings,
}